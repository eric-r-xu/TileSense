"""Overfit a bounded batch of real replay decisions; not a full training run."""

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
from .checkpoint import load_checkpoint, save_checkpoint
from .data import read_game, replay_samples, stack_rows
from .encoding import engine_provenance
from .inference import react_local
from .model import INPUT_NAMES, ModelConfig, build_model
from .smoke import export_and_verify


def extract(ruleset, root, split, games, samples, rng):
    files = sorted((root / split).glob('*.json.gz'))[:games]
    if len(files) != games:
        raise ValueError('not enough games for bounded extraction')
    rows = []
    checked = 0
    provenance = []
    for path in files:
        game_rows, updates = replay_samples(ruleset, read_game(path))
        rows.extend(row for row in game_rows if row['inputs'][-1].sum() > 1)
        checked += updates
        provenance.append({'split': split, 'file': path.name, 'sha256': sha256(path)})
    if len(rows) < samples:
        raise ValueError('not enough nonforced decisions')
    chosen = [rows[index] for index in rng.permutation(len(rows))[:samples]]
    return stack_rows(chosen), {'games': provenance, 'seat_event_updates': checked,
                               'available_nonforced_samples': len(rows), 'selected_samples': samples,
                               'label_counts': dict(Counter(str(row['label']) for row in chosen))}


def metrics(model, inputs, labels):
    with torch.no_grad():
        q, _ = model(*inputs)
        return {'loss': nn.functional.cross_entropy(q, labels).item(),
                'accuracy': (q.argmax(-1) == labels).float().mean().item()}


def verify_real_onnx(model, inputs, out):
    import onnxruntime as ort

    options = ort.SessionOptions()
    options.intra_op_num_threads = 1
    session = ort.InferenceSession(str(out / 'prototype.onnx'), options, providers=['CPUExecutionProvider'])
    batch = tuple(value[:8].cpu() for value in inputs)
    with torch.no_grad():
        expected, _ = model(*batch)
    actual = session.run(None, {name: value.numpy() for name, value in zip(INPUT_NAMES, batch)})[0]
    mask = batch[-1].numpy()
    np.testing.assert_allclose(actual[mask], expected.numpy()[mask], rtol=1e-4, atol=1e-5)
    np.testing.assert_array_equal(actual.argmax(-1), expected.numpy().argmax(-1))
    np.testing.assert_array_equal(np.isneginf(actual), ~mask)
    return {'decisions': len(actual),
            'max_legal_q_difference': float(np.abs(actual[mask] - expected.numpy()[mask]).max()),
            'same_action_fraction': 1.0}


def check_local_reactions(config, out, root):
    events = read_game(sorted((root / 'val').glob('*.json.gz'))[0])
    rows, _ = replay_samples(config.ruleset, events)
    by_action = {}
    for row in rows:
        if not row['kan_select']:
            by_action.setdefault(row['label'], row)
    fixtures = list(by_action.values())[:8]
    results = []
    for row in fixtures:
        result = react_local(config, out / 'prototype.onnx', row['seat'],
                             events[:row['event_index'] + 1])
        if result['reaction'] is None or result['network_decisions'] < 1:
            raise AssertionError('local adapter did not produce a neural reaction')
        # Validate decoded actions against a separately replayed engine state.
        from .encoding import VisibleEncoder
        encoder = VisibleEncoder(config.ruleset, row['seat'])
        for event in events[:row['event_index'] + 1]:
            encoder.update(event)
        encoder.state.validate_reaction(json.dumps(result['reaction']))
        if result['riichi_discard'] is not None:
            encoder.update({'type': 'reach', 'actor': row['seat']})
            encoder.state.validate_reaction(json.dumps(result['riichi_discard']))
        results.append({'logged_label': row['label'], 'reaction_type': result['reaction']['type'],
                        'network_decisions': result['network_decisions']})
    return {'validated_fixtures': len(results), 'results': results,
            'scope': 'local decoded reactions on validation prefixes; not complete games'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ruleset', choices=['sanma', 'nagomi'], required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--data-parent', type=Path, default=Path.home() / 'Documents')
    parser.add_argument('--device', choices=['cpu', 'mps'], default='mps')
    parser.add_argument('--steps', type=int, default=200)
    parser.add_argument('--samples', type=int, default=64)
    args = parser.parse_args()
    if not 1 <= args.steps <= 1000 or not 8 <= args.samples <= 128:
        parser.error('bounded smoke requires 1–1000 updates and 8–128 samples')
    if args.out.exists():
        parser.error('output already exists')
    if args.device == 'mps' and not torch.backends.mps.is_available():
        parser.error('MPS is unavailable')
    args.out.mkdir(parents=True, exist_ok=False)
    random.seed(7)
    np.random.seed(7)
    torch.manual_seed(7)
    torch.set_num_threads(1)
    rng = np.random.default_rng(7)
    folder, variant, _ = DATASETS[args.ruleset]
    root = args.data_parent / folder / 'mjai' / variant
    started = time.perf_counter()
    (train_np, labels_np), train_info = extract(args.ruleset, root, 'train', 2, args.samples, rng)
    (val_np, val_labels_np), val_info = extract(args.ruleset, root, 'val', 1, args.samples, rng)
    if {g['sha256'] for g in train_info['games']} & {g['sha256'] for g in val_info['games']}:
        raise ValueError('train/validation games overlap')
    extraction_seconds = time.perf_counter() - started
    config = ModelConfig(**json.loads((ROOT / 'model_training/configs' / f'{args.ruleset}.json').read_text()))
    if config.observation_schema_id != 'tilesense-visible-v1':
        raise ValueError('real replay requires the visible-v1 schema')
    model = build_model(config).to(args.device)
    inputs = tuple(torch.from_numpy(value).to(args.device) for value in train_np)
    labels = torch.from_numpy(labels_np).to(args.device)
    val_inputs = tuple(torch.from_numpy(value).to(args.device) for value in val_np)
    val_labels = torch.from_numpy(val_labels_np).to(args.device)
    optimizer = torch.optim.AdamW(model.parameters(), lr=1e-3, weight_decay=0.01)
    before = metrics(model, inputs, labels)
    started = time.perf_counter()
    updates = 0
    for step in range(args.steps):
        optimizer.zero_grad(set_to_none=True)
        q, _ = model(*inputs)
        loss = nn.functional.cross_entropy(q, labels)
        if not torch.isfinite(loss):
            raise ValueError('nonfinite loss')
        loss.backward()
        nn.utils.clip_grad_norm_(model.parameters(), 1)
        optimizer.step()
        updates = step + 1
        if updates % 20 == 0:
            current = metrics(model, inputs, labels)
            print(json.dumps({'updates': updates, **current}), flush=True)
            if current['accuracy'] >= 0.98 and current['loss'] < 0.1:
                break
    seconds = time.perf_counter() - started
    after = metrics(model, inputs, labels)
    validation = metrics(model, val_inputs, val_labels)
    overfit_passed = after['accuracy'] >= 0.95 and after['loss'] < before['loss'] * 0.3
    source_hashes = {path.relative_to(ROOT).as_posix(): sha256(path)
                     for path in sorted((ROOT / 'model_training').glob('*.py'))}
    provenance = {'purpose': 'bounded real-data imitation overfit; not a release model',
                  'seed': 7, 'engine': engine_provenance(args.ruleset),
                  'train': train_info, 'validation': val_info, 'source_sha256': source_hashes,
                  'objective': 'cross entropy on outcome-aware nonforced action labels; no rank/return/teacher loss'}
    checkpoint = args.out / 'real_smoke.pth'
    save_checkpoint(checkpoint, model, optimizer, updates, provenance)
    restored = build_model(config).to(args.device)
    load_checkpoint(checkpoint, restored)
    with torch.no_grad():
        for actual, expected in zip(restored(*inputs), model(*inputs)):
            torch.testing.assert_close(actual, expected, rtol=0, atol=0)
    memory = {}
    if args.device == 'mps':
        memory = {'allocated_bytes_at_end': torch.mps.current_allocated_memory(),
                  'driver_allocated_bytes_at_end': torch.mps.driver_allocated_memory(),
                  'scope': 'snapshot after training; not a peak measurement'}
    onnx = export_and_verify(restored, args.out)
    report = {'purpose': provenance['purpose'], 'config': config.to_dict(),
              'device': args.device, 'torch_version': str(torch.__version__),
              'parameters': sum(p.numel() for p in model.parameters()),
              'updates': updates, 'samples': args.samples, 'initial_train': before,
              'final_train': after, 'validation': validation, 'overfit_passed': overfit_passed,
              'train_seconds': seconds, 'examples_per_second': updates * args.samples / seconds,
              'extraction_seconds': extraction_seconds, 'mps_memory': memory,
              'checkpoint_restoration_exact': True, 'onnx_synthetic_parity': onnx,
              'onnx_real_parity': verify_real_onnx(restored, inputs, args.out),
              'local_integration': check_local_reactions(config, args.out, root),
              'provenance': provenance,
              'limitations': ['tiny sample; validation metrics are not strength estimates',
                              'unobservable interrupted choices are censored',
                              'rank head and action-value calibration are not trained by imitation',
                              'local adapter only; no production deployment']}
    (args.out / 'summary.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({k: v for k, v in report.items() if k != 'provenance'}, indent=2))
    return 0 if overfit_passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
