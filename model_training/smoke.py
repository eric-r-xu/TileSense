"""Train synthetic fixtures, check resume and export parity. Not model training."""

import argparse
import json
from pathlib import Path
import random
import time

import numpy as np
import torch
from torch import nn

from .checkpoint import load_checkpoint, save_checkpoint
from .model import INPUT_NAMES, ModelConfig, build_model, synthetic_batch


def export_and_verify(model, out):
    import onnx
    import onnxruntime as ort

    model = model.to('cpu').eval()
    fixture = synthetic_batch(model.config, 2)
    path = out / 'prototype.onnx'
    with torch.no_grad():
        torch.onnx.export(
            model, fixture, path, input_names=list(INPUT_NAMES), output_names=['q', 'rank'],
            opset_version=17, dynamo=False,
            dynamic_axes={name: {0: 'batch'} for name in (*INPUT_NAMES, 'q', 'rank')})
    onnx.checker.check_model(str(path))
    options = ort.SessionOptions()
    options.intra_op_num_threads = 1
    session = ort.InferenceSession(str(path), options, providers=['CPUExecutionProvider'])
    differences = []
    for batch_size in (1, 3):
        inputs = synthetic_batch(model.config, batch_size)
        # Include the empty-history edge case in parity checks.
        inputs[3][0] = False
        with torch.no_grad():
            expected_q, expected_rank = [x.numpy() for x in model(*inputs)]
        actual_q, actual_rank = session.run(None, {k: v.numpy() for k, v in zip(INPUT_NAMES, inputs)})
        mask = inputs[-1].numpy()
        np.testing.assert_allclose(actual_q[mask], expected_q[mask], rtol=1e-4, atol=1e-5)
        np.testing.assert_allclose(actual_rank, expected_rank, rtol=1e-4, atol=1e-5)
        np.testing.assert_array_equal(np.isneginf(actual_q), ~mask)
        np.testing.assert_array_equal(actual_q.argmax(-1), expected_q.argmax(-1))
        differences.append(float(np.abs(actual_q[mask] - expected_q[mask]).max()))
    return {'batch_sizes_checked': [1, 3], 'max_legal_q_difference': max(differences),
            'file_bytes': path.stat().st_size}


def run(config, out, device, steps=12, batch_size=8):
    if steps < 2 or batch_size < 1:
        raise ValueError('smoke run requires at least two steps and one sample')
    out.mkdir(parents=True, exist_ok=False)
    random.seed(7)
    np.random.seed(7)
    torch.manual_seed(7)
    torch.set_num_threads(1)
    model = build_model(config).to(device)
    optimizer = torch.optim.AdamW(model.parameters(), lr=1e-3)
    inputs = synthetic_batch(config, batch_size, device)
    targets = torch.zeros(batch_size, dtype=torch.long, device=device)
    ranks = torch.arange(batch_size, device=device) % config.players
    losses = []
    started = time.perf_counter()
    for _ in range(steps):
        optimizer.zero_grad(set_to_none=True)
        q, rank = model(*inputs)
        loss = nn.functional.cross_entropy(q, targets) + 0.2 * nn.functional.cross_entropy(rank, ranks)
        if not torch.isfinite(loss):
            raise ValueError('non-finite training loss')
        loss.backward()
        nn.utils.clip_grad_norm_(model.parameters(), 1)
        optimizer.step()
        losses.append(loss.item())
    elapsed = time.perf_counter() - started
    if losses[-1] >= losses[0]:
        raise AssertionError('tiny synthetic fixture did not learn')
    checkpoint = out / 'smoke.pth'
    save_checkpoint(checkpoint, model, optimizer, steps,
                    {'purpose': 'synthetic smoke only', 'device': device, 'seed': 7})
    restored = build_model(config).to(device)
    restored_optimizer = torch.optim.AdamW(restored.parameters(), lr=1e-3)
    load_checkpoint(checkpoint, restored, restored_optimizer, restore_rng=True)
    with torch.no_grad():
        for expected, actual in zip(model(*inputs), restored(*inputs)):
            torch.testing.assert_close(actual, expected, rtol=0, atol=0)
    # One real optimizer step on both copies verifies optimizer state restoration.
    for candidate, opt in ((model, optimizer), (restored, restored_optimizer)):
        opt.zero_grad(set_to_none=True)
        q, rank = candidate(*inputs)
        loss = nn.functional.cross_entropy(q, targets) + 0.2 * nn.functional.cross_entropy(rank, ranks)
        loss.backward()
        nn.utils.clip_grad_norm_(candidate.parameters(), 1)
        opt.step()
    for expected, actual in zip(model.parameters(), restored.parameters()):
        # MPS reductions may differ at the final bit across repeated updates.
        torch.testing.assert_close(actual, expected, rtol=1e-5, atol=1e-7)
    report = {'purpose': 'synthetic smoke only; no learned mahjong ability',
              'config': config.to_dict(), 'device': device, 'torch_version': str(torch.__version__),
              'parameters': sum(p.numel() for p in model.parameters()), 'steps': steps,
              'batch_size': batch_size, 'first_loss': losses[0], 'last_loss': losses[-1],
              'seconds': elapsed, 'synthetic_examples_per_second': steps * batch_size / elapsed,
              'checkpoint_and_next_optimizer_step_match': True,
              'next_step_tolerance': {'rtol': 1e-5, 'atol': 1e-7},
              'onnx': export_and_verify(restored, out)}
    (out / 'summary.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    selection = parser.add_mutually_exclusive_group(required=True)
    selection.add_argument('--ruleset', choices=['sanma', 'nagomi'])
    selection.add_argument('--config', type=Path, help='versioned JSON model configuration')
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--device', choices=['cpu', 'mps'], default='mps')
    parser.add_argument('--steps', type=int, default=12)
    parser.add_argument('--batch-size', type=int, default=8)
    args = parser.parse_args()
    config = ModelConfig(**json.loads(args.config.read_text())) if args.config else ModelConfig(args.ruleset)
    run(config, args.out, args.device, args.steps, args.batch_size)


if __name__ == '__main__':
    main()
