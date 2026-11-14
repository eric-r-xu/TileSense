"""Read-only inventory of existing models and whole-game data splits.

Run with `python -m model_training.audit --help`. No ML dependencies required.
"""

import argparse
from collections import Counter
import gzip
import hashlib
import json
from pathlib import Path
import platform
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
DATASETS = {
    'sanma': ('mortal-sanma-data', 'sanma-hanchan', 3),
    'nagomi': ('mortal-4p-data', 'hanchan', 4),
}


def sha256(path):
    digest = hashlib.sha256()
    with path.open('rb') as source:
        for block in iter(lambda: source.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def game_identity(path, num_players):
    """Hash gameplay, ignoring names/annotations; never emit player identities."""
    digest = hashlib.sha256()
    events = 0
    rounds = 0
    ended = False
    with gzip.open(path, 'rt', encoding='utf-8') as source:
        for line in source:
            event = json.loads(line)
            if not isinstance(event, dict) or not isinstance(event.get('type'), str):
                raise ValueError('event must be an object with a type')
            kind = event['type']
            if kind == 'start_kyoku':
                rounds += 1
                if len(event['tehais']) != num_players or len(event['scores']) != num_players:
                    raise ValueError('wrong number of seats')
            ended |= kind == 'end_game'
            # Metadata and display names do not distinguish game trajectories.
            gameplay = {k: v for k, v in event.items() if k not in ('meta', 'names')}
            digest.update(json.dumps(gameplay, sort_keys=True, separators=(',', ':')).encode())
            digest.update(b'\n')
            events += 1
    if not rounds or not ended:
        raise ValueError('missing round or end_game')
    return digest.hexdigest(), events


def audit_dataset(root, num_players, manifest_path):
    """Detect repeated identities/content within and between frozen splits."""
    seen_ids = {}
    seen_games = {}
    counts = Counter()
    issues = []
    manifest_hash = hashlib.sha256()
    with manifest_path.open('x', encoding='utf-8') as output:
        for split in ('train', 'val', 'test'):
            for path in sorted((root / split).glob('*.json.gz')):
                relative = path.relative_to(root).as_posix()
                game_id = path.name.removesuffix('.json.gz')
                counts[split] += 1
                row = {'path': relative, 'split': split, 'game_id': game_id,
                       'file_sha256': sha256(path)}
                try:
                    identity, events = game_identity(path, num_players)
                    row.update(gameplay_sha256=identity, events=events)
                    for label, key, seen in [('game_id', game_id, seen_ids),
                                             ('gameplay', identity, seen_games)]:
                        if key in seen:
                            previous = seen[key]
                            issues.append({'kind': label, 'path': relative, 'other': previous,
                                           'cross_split': previous.split('/')[0] != split})
                        else:
                            seen[key] = relative
                except (ValueError, KeyError, TypeError, OSError, EOFError) as error:
                    # Do not copy log contents or player names into error reports.
                    row['error'] = type(error).__name__
                    issues.append({'kind': 'invalid_log', 'path': relative,
                                   'error': type(error).__name__})
                line = json.dumps(row, sort_keys=True) + '\n'
                output.write(line)
                manifest_hash.update(line.encode())
                total = sum(counts.values())
                if total % 5000 == 0:
                    print(f'{root.name}: {total:,} games audited', file=sys.stderr, flush=True)
    for split in ('train', 'val'):
        if not counts[split]:
            issues.append({'kind': 'empty_split', 'split': split})
    return {'counts': dict(counts), 'split_manifest_sha256': manifest_hash.hexdigest(),
            'issues': issues, 'passed': not issues,
            'validation_scope': 'JSON structure, seat counts, completion, game IDs and gameplay hashes; '
                                'not rules-engine replay validation',
            'test_usage_history': 'unverified',
            'test_present': counts['test'] > 0}


def baseline_inventory():
    result = {}
    for name, manifest_name in [('base_298k', 'model.json'), ('sanma', 'model_sanma.json'),
                                 ('nagomi', 'model_nagomi.json')]:
        manifest = json.loads((ROOT / 'mortal_sidecar' / manifest_name).read_text())
        artifact = ROOT / 'mortal_sidecar' / manifest['url'].rsplit('/', 1)[-1]
        actual = sha256(artifact) if artifact.exists() else None
        result[name] = {'manifest': f'mortal_sidecar/{manifest_name}', **manifest,
                        'local_sha256': actual, 'matches_release_manifest': actual == manifest['sha256']}
    return result


def hardware_inventory():
    result = {'machine': platform.machine(), 'system': platform.system()}
    if platform.system() == 'Darwin':
        result['memory_bytes'] = int(subprocess.check_output(['sysctl', '-n', 'hw.memsize']))
        result['chip'] = subprocess.check_output(
            ['sysctl', '-n', 'machdep.cpu.brand_string'], text=True).strip()
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--data-parent', type=Path, default=Path.home() / 'Documents')
    parser.add_argument('--out', type=Path, required=True, help='new directory, never overwrite an audit')
    args = parser.parse_args()
    # Check all roots before creating any audit artifacts.
    for folder, variant, _ in DATASETS.values():
        root = args.data_parent / folder / 'mjai' / variant
        if not (root / 'train').is_dir() or not (root / 'val').is_dir():
            parser.error(f'missing train/val directories in {root}')
    args.out.mkdir(parents=True, exist_ok=False)
    report = {'schema_version': 1, 'hardware': hardware_inventory(),
              'baselines': baseline_inventory(), 'datasets': {}}
    for name, (folder, variant, players) in DATASETS.items():
        report['datasets'][name] = audit_dataset(
            args.data_parent / folder / 'mjai' / variant, players, args.out / f'{name}.jsonl')
    report['passed'] = (all(b['matches_release_manifest'] for b in report['baselines'].values())
                        and all(d['passed'] for d in report['datasets'].values()))
    (args.out / 'inventory.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
