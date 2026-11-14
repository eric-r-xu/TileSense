"""Build bounded per-game shards from frozen splits, verifying engine labels."""

import argparse
from collections import Counter
import json
from pathlib import Path
import time

import numpy as np

from .audit import DATASETS, ROOT, sha256
from .data import EXTRACTOR_VERSION, read_game, replay_samples, stack_rows
from .encoding import engine_provenance
from .model import INPUT_NAMES, ModelConfig


def extraction_sources():
    return {name: sha256(ROOT / 'model_training' / name) for name in ('data.py', 'encoding.py')}


def build_cache(ruleset, root, audit_dir, out, train_games=128, val_games=32, seed=7):
    if out.exists():
        raise FileExistsError('cache output already exists')
    inventory = json.loads((audit_dir / 'inventory.json').read_text())
    audit_path = audit_dir / f'{ruleset}.jsonl'
    if (not inventory['datasets'][ruleset]['passed']
            or sha256(audit_path) != inventory['datasets'][ruleset]['split_manifest_sha256']):
        raise ValueError('frozen audit is invalid')
    frozen = {}
    with audit_path.open() as source:
        for line in source:
            row = json.loads(line)
            frozen[row['path']] = row
    rng = np.random.default_rng(seed)
    chosen = {}
    for split, count in (('train', train_games), ('val', val_games)):
        files = sorted((root / split).glob('*.json.gz'))
        if not 1 <= count <= len(files):
            raise ValueError('not enough games for requested cache')
        chosen[split] = [files[i] for i in rng.choice(len(files), count, replace=False)]
    identities = set()
    for split, files in chosen.items():
        for path in files:
            row = frozen.get(path.relative_to(root).as_posix())
            if row is None or sha256(path) != row['file_sha256']:
                raise ValueError('game changed since frozen split audit')
            if row['gameplay_sha256'] in identities:
                raise ValueError('duplicate game in selected splits')
            identities.add(row['gameplay_sha256'])
    config = ModelConfig.visible(ruleset)
    manifest = {'format_version': 1, 'config': config.to_dict(), 'seed': seed,
                'extractor_version': EXTRACTOR_VERSION, 'sources': extraction_sources(),
                'audit_sha256': sha256(audit_path), 'engine': engine_provenance(ruleset),
                'splits': {}, 'target': 'engine GRP final rank, stable absolute-seat tie order'}
    out.mkdir(parents=True)
    started = time.perf_counter()
    for split, files in chosen.items():
        (out / split).mkdir()
        entries = []
        decisions, labels, nonforced_labels, reference = Counter(), Counter(), Counter(), Counter()
        for index, path in enumerate(files):
            stats = {}
            rows, _ = replay_samples(ruleset, read_game(path), include_outcomes=True,
                                     verify_reference=True, stats=stats)
            if stats['decisions'].get('unresolved_continuation', 0):
                raise ValueError('unresolved action continuation; inspect before training')
            inputs, targets = stack_rows(rows)
            ranks = np.array([row['final_rank'] for row in rows], dtype=np.int64)
            shard_path = out / split / f'{index:05}.npz'
            np.savez_compressed(shard_path, **dict(zip(INPUT_NAMES, inputs)), labels=targets, ranks=ranks)
            nonforced = inputs[-1].sum(-1) > 1
            entries.append({'path': shard_path.relative_to(out).as_posix(),
                            'sha256': sha256(shard_path), 'game': path.name,
                            'game_sha256': sha256(path), 'samples': len(rows),
                            'nonforced_samples': int(nonforced.sum())})
            decisions.update(stats['decisions'])
            labels.update(stats['labels'])
            nonforced_labels.update(str(label) for label in targets[nonforced])
            reference.update(stats['reference'])
            if (index + 1) % 8 == 0 or index + 1 == len(files):
                print(json.dumps({'split': split, 'games': index + 1, 'of': len(files),
                                  'seconds': round(time.perf_counter() - started, 1)}), flush=True)
        manifest['splits'][split] = {'shards': entries, 'decisions': dict(decisions),
                                     'labels': dict(labels), 'nonforced_labels': dict(nonforced_labels),
                                     'reference': dict(reference),
                                     'samples': sum(e['samples'] for e in entries),
                                     'nonforced_samples': sum(e['nonforced_samples'] for e in entries)}
    manifest['build_seconds'] = time.perf_counter() - started
    (out / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    return manifest


def load_manifest(path):
    manifest = json.loads(path.read_text())
    if manifest.get('format_version') != 1 or manifest['extractor_version'] != EXTRACTOR_VERSION:
        raise ValueError('unsupported cache contract')
    if manifest['sources'] != extraction_sources():
        raise ValueError('encoder/extractor changed; build a new cache')
    config = ModelConfig(**manifest['config'])
    if manifest['engine'] != engine_provenance(config.ruleset):
        raise ValueError('engine changed since extraction')
    return manifest


def load_shard(root, entry):
    path = (root / entry['path']).resolve()
    if not path.is_relative_to(root.resolve()) or path.suffix != '.npz':
        raise ValueError('invalid shard path')
    if sha256(path) != entry['sha256']:
        raise ValueError('cache shard checksum mismatch')
    with np.load(path, allow_pickle=False) as source:
        arrays = tuple(source[name] for name in (*INPUT_NAMES, 'labels', 'ranks'))
    if any(len(array) != entry['samples'] for array in arrays):
        raise ValueError('cache sample count mismatch')
    return arrays


def iter_batches(root, manifest, split, batch_size, seed=7, cursor=None, epochs=1):
    """Deterministic per-game shuffle; a cursor identifies the next unseen row."""
    start = cursor or {'epoch': 0, 'shard': 0, 'row': 0}
    shards = manifest['splits'][split]['shards']
    for epoch in range(start['epoch'], epochs):
        order = np.random.default_rng(seed + epoch).permutation(len(shards)) if split == 'train' else np.arange(len(shards))
        for position in range(start['shard'] if epoch == start['epoch'] else 0, len(order)):
            arrays = load_shard(root, shards[order[position]])
            valid = np.flatnonzero(arrays[4].sum(-1) > 1)
            if split == 'train':
                np.random.default_rng(np.random.SeedSequence([seed, epoch, int(order[position])])).shuffle(valid)
            begin = start['row'] if epoch == start['epoch'] and position == start['shard'] else 0
            for offset in range(begin, len(valid), batch_size):
                selected = valid[offset:offset + batch_size]
                next_cursor = {'epoch': epoch, 'shard': position, 'row': offset + len(selected)}
                if next_cursor['row'] == len(valid):
                    next_cursor = {'epoch': epoch, 'shard': position + 1, 'row': 0}
                    if position + 1 == len(order):
                        next_cursor = {'epoch': epoch + 1, 'shard': 0, 'row': 0}
                yield tuple(array[selected] for array in arrays), next_cursor


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ruleset', choices=['sanma', 'nagomi'], required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--train-games', type=int, default=128)
    parser.add_argument('--val-games', type=int, default=32)
    parser.add_argument('--audit-dir', type=Path,
                        default=ROOT / 'model_training/runs/baseline-audit-20261108-v2')
    parser.add_argument('--data-parent', type=Path, default=Path.home() / 'Documents')
    args = parser.parse_args()
    folder, variant, _ = DATASETS[args.ruleset]
    build_cache(args.ruleset, args.data_parent / folder / 'mjai' / variant,
                args.audit_dir, args.out, args.train_games, args.val_games)


if __name__ == '__main__':
    main()
