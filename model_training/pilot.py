"""Bounded streaming imitation/rank pilot on frozen, engine-checked shards."""

import argparse
from collections import Counter
import json
from pathlib import Path
import random
import time

import numpy as np
import torch
from torch import nn

from .audit import DATASETS, ROOT, sha256
from .cache import iter_batches, load_manifest
from .checkpoint import load_checkpoint, save_checkpoint
from .model import ModelConfig, build_model
from .real_smoke import check_local_reactions, verify_real_onnx
from .smoke import export_and_verify


def action_kind(label):
    if label <= 36:
        return 'discard_or_kan_tile'
    return {37: 'riichi', 38: 'chi', 39: 'chi', 40: 'chi', 41: 'pon', 42: 'kan',
            43: 'agari', 44: 'abortive_draw', 45: 'pass', 46: 'kita'}[int(label)]


def as_tensors(arrays, device):
    return tuple(torch.from_numpy(value).to(device) for value in arrays)


def evaluate(model, root, manifest, device, batch_size=64):
    model.eval()
    count = correct = blind_correct = rank_correct = 0
    action_loss = rank_loss = 0.0
    kinds, agreements = Counter(), Counter()
    with torch.no_grad():
        for arrays, _ in iter_batches(root, manifest, 'val', batch_size):
            *inputs, labels, ranks = as_tensors(arrays, device)
            q, rank = model(*inputs)
            size = len(labels)
            matches = q.argmax(-1) == labels
            count += size
            correct += matches.sum().item()
            rank_correct += (rank.argmax(-1) == ranks).sum().item()
            action_loss += nn.functional.cross_entropy(q, labels, reduction='sum').item()
            rank_loss += nn.functional.cross_entropy(rank, ranks, reduction='sum').item()
            masks = arrays[4]
            # Simple reference: pass whenever legal, otherwise first legal ID.
            blind = np.where(masks[:, 45], 45, masks.argmax(-1))
            blind_correct += int((blind == arrays[5]).sum())
            match_cpu = matches.cpu().numpy()
            for label, matched in zip(arrays[5], match_cpu):
                kind = action_kind(label)
                kinds[kind] += 1
                agreements[kind] += int(matched)
    if not count:
        raise ValueError('empty nonforced validation set')
    return {'samples': count, 'action_loss': action_loss / count,
            'action_accuracy': correct / count, 'final_rank_loss': rank_loss / count,
            'final_rank_accuracy': rank_correct / count, 'pass_else_first_legal_accuracy': blind_correct / count,
            'by_kind': {kind: {'samples': n, 'accuracy': agreements[kind] / n}
                        for kind, n in sorted(kinds.items())}}


def training_contract(config, manifest_path, device, batch_size, seed, lr, rank_weight):
    names = ('pilot.py', 'cache.py', 'checkpoint.py', 'data.py', 'encoding.py', 'model.py')
    return {'purpose': 'bounded imitation plus final-rank pilot; not a release',
            'config': config.to_dict(), 'manifest_sha256': sha256(manifest_path),
            'device': device, 'torch_version': str(torch.__version__), 'batch_size': batch_size,
            'seed': seed, 'learning_rate': lr, 'rank_weight': rank_weight,
            'weight_decay': 0.01, 'max_grad_norm': 1.0,
            'sources': {name: sha256(ROOT / 'model_training' / name) for name in names}}


def run(manifest_path, out, *, device='mps', epochs=2, max_steps=3000, batch_size=64,
        seed=7, lr=3e-4, rank_weight=0.1, resume=None, save_every=500):
    if out.exists():
        raise FileExistsError('pilot output already exists')
    if min(epochs, max_steps, batch_size, save_every) < 1 or lr <= 0 or rank_weight < 0:
        raise ValueError('invalid pilot bounds')
    if device == 'mps' and not torch.backends.mps.is_available():
        raise ValueError('MPS unavailable')
    manifest = load_manifest(manifest_path)
    config = ModelConfig(**manifest['config'])
    root = manifest_path.parent
    provenance = training_contract(config, manifest_path, device, batch_size, seed, lr, rank_weight)
    out.mkdir(parents=True)
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    torch.set_num_threads(1)
    model = build_model(config).to(device)
    optimizer = torch.optim.AdamW(model.parameters(), lr=lr, weight_decay=0.01)
    cursor = {'epoch': 0, 'shard': 0, 'row': 0}
    steps = examples = 0
    if resume is not None:
        state = load_checkpoint(resume, model, optimizer, restore_rng=True,
                                expected_provenance=provenance)
        if state.get('trainer_state') is None:
            raise ValueError('checkpoint has no streaming cursor')
        cursor = state['trainer_state']['cursor']
        examples = state['trainer_state']['examples']
        steps = state['steps']
        if steps >= max_steps or cursor['epoch'] >= epochs:
            raise ValueError('resume bounds do not permit more training')
    initial_steps, initial_examples = steps, examples
    initial = evaluate(model, root, manifest, device, batch_size)
    history = [{'steps': steps, **initial}]
    (out / 'initial_validation.json').write_text(json.dumps(initial, indent=2) + '\n')
    print(json.dumps({'stage': 'initial_validation', 'steps': steps,
                      'loss': initial['action_loss'], 'accuracy': initial['action_accuracy']}), flush=True)
    started = time.perf_counter()
    training_seconds = 0.0
    losses = []
    stopped_at_limit = False
    for arrays, next_cursor in iter_batches(root, manifest, 'train', batch_size, seed, cursor, epochs):
        batch_started = time.perf_counter()
        *inputs, labels, ranks = as_tensors(arrays, device)
        model.train()
        optimizer.zero_grad(set_to_none=True)
        q, rank = model(*inputs)
        loss = nn.functional.cross_entropy(q, labels) + rank_weight * nn.functional.cross_entropy(rank, ranks)
        if not torch.isfinite(loss):
            raise ValueError('nonfinite pilot loss')
        loss.backward()
        nn.utils.clip_grad_norm_(model.parameters(), 1)
        optimizer.step()
        losses.append(loss.item())
        training_seconds += time.perf_counter() - batch_started
        steps += 1
        examples += len(labels)
        cursor = next_cursor
        if steps % 100 == 0:
            print(json.dumps({'steps': steps, 'epoch': cursor['epoch'], 'examples': examples,
                              'mean_recent_loss': sum(losses[-100:]) / len(losses[-100:])}), flush=True)
        if steps % save_every == 0:
            save_checkpoint(out / f'step_{steps:06}.pth', model, optimizer, steps, provenance,
                            {'cursor': cursor, 'examples': examples})
            validation = evaluate(model, root, manifest, device, batch_size)
            history.append({'steps': steps, **validation})
            print(json.dumps({'stage': 'validation', 'steps': steps,
                              'loss': validation['action_loss'], 'accuracy': validation['action_accuracy']}), flush=True)
        if steps >= max_steps:
            stopped_at_limit = True
            break
    if not stopped_at_limit:
        cursor = {'epoch': epochs, 'shard': 0, 'row': 0}
    total_seconds = time.perf_counter() - started
    final = evaluate(model, root, manifest, device, batch_size)
    history.append({'steps': steps, **final})
    save_checkpoint(out / 'final.pth', model, optimizer, steps, provenance,
                    {'cursor': cursor, 'examples': examples})
    restored = build_model(config).to(device)
    load_checkpoint(out / 'final.pth', restored, expected_provenance=provenance)
    arrays, _ = next(iter_batches(root, manifest, 'val', 8))
    fixture = as_tensors(arrays[:5], device)
    with torch.no_grad():
        for actual, expected in zip(restored(*fixture), model(*fixture)):
            torch.testing.assert_close(actual, expected, rtol=0, atol=0)
    memory = {}
    if device == 'mps':
        memory = {'allocated_at_end': torch.mps.current_allocated_memory(),
                  'driver_allocated_at_end': torch.mps.driver_allocated_memory(), 'peak_measured': False}
    onnx = export_and_verify(restored, out)
    folder, variant, _ = DATASETS[config.ruleset]
    report = {'provenance': provenance, 'resumed': resume is not None,
              'steps': steps, 'new_steps': steps - initial_steps, 'examples': examples,
              'new_examples': examples - initial_examples, 'cursor': cursor,
              'completed_epochs': cursor['epoch'], 'max_steps': max_steps, 'planned_epochs': epochs,
              'initial_validation': initial, 'final_validation': final, 'validation_history': history,
              'training_update_seconds': training_seconds, 'wall_seconds_including_periodic_validation': total_seconds,
              'update_examples_per_second': (examples - initial_examples) / max(training_seconds, 1e-9),
              'mps_memory': memory, 'checkpoint_restoration_exact': True,
              'onnx': onnx, 'onnx_real': verify_real_onnx(restored, fixture, out),
              'local_integration': check_local_reactions(config, out, Path.home() / 'Documents' / folder / 'mjai' / variant),
              'dataset': {split: {key: value for key, value in info.items() if key != 'shards'}
                          for split, info in manifest['splits'].items()},
              'limitations': ['small pilot, one seed, no strength evaluation',
                              'unobservable interrupted choices censored',
                              'human imitation scores are not calibrated returns',
                              'validation used for iteration; final test split unused',
                              'no production deployment']}
    (out / 'summary.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'stage': 'complete', 'steps': steps, 'epochs': cursor['epoch'],
                      'initial_accuracy': initial['action_accuracy'], 'final_accuracy': final['action_accuracy'],
                      'final_loss': final['action_loss']}), flush=True)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--manifest', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--resume', type=Path)
    parser.add_argument('--device', choices=['cpu', 'mps'], default='mps')
    parser.add_argument('--epochs', type=int, default=2)
    parser.add_argument('--max-steps', type=int, default=3000)
    parser.add_argument('--batch-size', type=int, default=64)
    args = parser.parse_args()
    run(args.manifest, args.out, device=args.device, epochs=args.epochs, max_steps=args.max_steps,
        batch_size=args.batch_size, resume=args.resume)


if __name__ == '__main__':
    main()
