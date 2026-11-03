"""Summarize paired sanma games; run with mortal_sidecar/.venv/bin/python.

Usage: python reports/sanma_comparison_stats.py RESULTS.csv EXPECTED_PAIRS
Writes RESULTS.stats.json and RESULTS.md. Uses the sidecar's existing NumPy.
"""
import csv
import json
import sys
from pathlib import Path

import numpy as np


def analyze(path, expected_pairs):
    rows = list(csv.DictReader(path.open()))
    pairs = {}
    for row in rows:
        seed, arm = int(row['seed']), row['brain']
        if arm not in ('guide', 'model'):
            raise ValueError(f'Unknown arm: {arm}')
        if int(row['failures']) or int(row['fallbacks']):
            raise ValueError(f'Invalid game: seed {seed}, arm {arm}')
        pair = pairs.setdefault(seed, {})
        if arm in pair:
            raise ValueError(f'Duplicate game: seed {seed}, arm {arm}')
        pair[arm] = row
    if len(pairs) != expected_pairs or any(len(p) != 2 for p in pairs.values()):
        raise ValueError('Incomplete paired sample')
    ordered = [pairs[s] for s in sorted(pairs)]
    for pair in ordered:
        if pair['guide']['dealer'] != pair['model']['dealer']:
            raise ValueError('Mismatched starting dealers')
    dealers = np.array([int(p['guide']['dealer']) for p in ordered])
    metrics = ['place', 'points']
    guide = np.array([[float(p['guide'][m]) for m in metrics] for p in ordered])
    model = np.array([[float(p['model'][m]) for m in metrics] for p in ordered])
    diffs = model - guide
    observed = diffs.mean(axis=0)
    rng = np.random.default_rng(20261103)

    # Swap arm labels independently within each seed pair. This tests the
    # paired exchangeability null, using absolute mean differences (two-sided).
    permutations = 100000
    extremes = np.zeros(2, dtype=int)
    for _ in range(permutations // 1000):
        signs = rng.choice([-1, 1], size=(1000, expected_pairs))
        permuted = signs @ diffs / expected_pairs
        extremes += (np.abs(permuted) >= np.abs(observed) - 1e-10).sum(axis=0)
    pvals = (extremes + 1) / (permutations + 1)
    # Holm correction across the two prespecified outcomes.
    order = np.argsort(pvals)
    adjusted = np.empty(2)
    running = 0.0
    for rank, idx in enumerate(order):
        running = max(running, float(pvals[idx]) * (2 - rank))
        adjusted[idx] = min(1.0, running)

    # Resample whole pairs within starting-dealer strata, retaining balance.
    bootstrap = np.zeros((20000, 2))
    for dealer in sorted(set(dealers)):
        indices = np.flatnonzero(dealers == dealer)
        sampled = rng.choice(indices, size=(20000, len(indices)), replace=True)
        bootstrap += diffs[sampled].sum(axis=1) / expected_pairs
    intervals = np.quantile(bootstrap, [0.025, 0.975], axis=0)
    result = {
        'pairs': expected_pairs, 'seed_min': min(pairs), 'seed_max': max(pairs),
        'dealer_counts': {str(d): int((dealers == d).sum()) for d in set(dealers)},
        'permutations': permutations, 'bootstrap_resamples': len(bootstrap),
        'resampling_seed': 20261103, 'invalid_games': 0,
        'total_hands': sum(int(r['hands']) for r in rows),
        'model_requests': sum(int(r['requests']) for r in rows),
        'arms': {}, 'model_minus_guide': {},
    }
    for name, data in [('guide', guide), ('model', model)]:
        result['arms'][name] = {
            'mean_place': float(data[:, 0].mean()),
            'mean_points': float(data[:, 1].mean()),
            'placements': {str(p): int((data[:, 0] == p).sum()) for p in (1, 2, 3)},
            'tied_placements': int((data[:, 0] % 1 != 0).sum()),
        }
    for col, metric in enumerate(metrics):
        result['model_minus_guide'][metric] = {
            'mean': float(observed[col]), 'ci95': intervals[:, col].tolist(),
            'p_two_sided': float(pvals[col]), 'p_holm': float(adjusted[col]),
            'positive_pairs': int((diffs[:, col] > 0).sum()),
            'zero_pairs': int((diffs[:, col] == 0).sum()),
            'negative_pairs': int((diffs[:, col] < 0).sum()),
        }
    return result


def main():
    path = Path(sys.argv[1])
    result = analyze(path, int(sys.argv[2]))
    path.with_suffix('.stats.json').write_text(json.dumps(result, indent=2) + '\n')
    lines = [
        '# Sanma Model vs TileSense guide: 60-pair follow-up', '',
        f"Fixed sample: {result['pairs']} fresh paired East–South games "
        f"({2 * result['pairs']} games), seeds {result['seed_min']}–{result['seed_max']}. "
        'The original 12 pilot pairs are excluded. Both opponents use Model; '
        'starting dealers are balanced across active seats 0, 1 and 3. '
        'The tested seat uses Model or the guide with default automatic dials '
        '(not a fixed points-only EV setting). Starting points: 35,000.', '',
        'FP32 model SHA-256: '
        '`e9863274c2972d15742fd3f46718bd2dff8ccc82e7a676aff25b44cbb63658c1` '
        '(the deployed 104k model). Game code: f9dd6cb; '
        'harness: flutter_client/test/sanma_model_comparison_test.dart.', '',
        '| Engine | Mean placement ↓ | Mean final points | 1st / 2nd / 3rd |',
        '|---|---:|---:|---|',
    ]
    for arm, s in result['arms'].items():
        places = ' / '.join(str(s['placements'][str(p)]) for p in (1, 2, 3))
        lines.append(f"| {arm} | {s['mean_place']:.3f} | {s['mean_points']:,.0f} | {places} |")
    lines += ['', '| Model minus guide | Mean difference | Paired 95% CI | Two-sided p | Holm-adjusted p |',
              '|---|---:|---|---:|---:|']
    for metric, s in result['model_minus_guide'].items():
        digits = 3 if metric == 'place' else 0
        lo, hi = s['ci95']
        lines.append(f"| {metric} | {s['mean']:+,.{digits}f} | "
                     f"[{lo:+,.{digits}f}, {hi:+,.{digits}f}] | "
                     f"{s['p_two_sided']:.5f} | {s['p_holm']:.5f} |")
    lines += ['', 'Methods: paired label-swap permutation test (100,000 resamples, '
              'two-sided absolute mean statistic, plus-one correction). Holm correction '
              'controls the family-wise 5% threshold for the two outcomes. '
              '95% percentile bootstrap intervals resample whole pairs within '
              'starting-dealer strata (20,000 resamples); intervals are marginal, '
              'not adjusted for multiple comparisons. Resampling RNG seed: 20261103.', '',
              f"All {result['pairs']} pairs are valid: zero model request failures or "
              f"fallback moves over {result['model_requests']:,} requests and "
              f"{result['total_hands']:,} hands.", '',
              'Limitations: inference assumes seed pairs represent the relevant game '
              'population; the permutation test assumes paired arm exchangeability under '
              'the null. These results describe play against two Model opponents using '
              'this specific model and guide configuration. Shared seeds do not force '
              'identical later positions, dealer repeats, or game lengths. A nonsignificant '
              'result does not establish equal strength.', '',
              'Reproduction, from the repository root with the sanma sidecar on port 18891:', '',
              '```sh', 'cd flutter_client',
              'SANMA_COMPARE_GAMES=60 SANMA_COMPARE_SEED=100000 SANMA_COMPARE_OUT=../reports/sanma_model_comparison_60.csv flutter test --dart-define=MP_ENDPOINT=ws://127.0.0.1:9 test/sanma_model_comparison_test.dart',
              'cd ..', 'mortal_sidecar/.venv/bin/python reports/sanma_comparison_stats.py reports/sanma_model_comparison_60.csv 60', '```']
    path.with_suffix('.md').write_text('\n'.join(lines) + '\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
