"""Diagnostic of a pure tenpai-probability-maximizing search hypothesis.

This intentionally separate experiment must not be used as the replacement
encoder: the oracle may choose future discards using a different objective.
"""

import argparse
from functools import lru_cache
import json
from pathlib import Path

import numpy as np

from nagomi_compat.efficiency import analyze, improving_tiles
from nagomi_compat.hand import shanten
from nagomi_compat.state import VisibleState
from nagomi_compat.visibility import visible_counts
from nagomi_compat.yaku import counts_for, own_melds
from .audit import ROOT, sha256


def hypothesis(counts, seen, melds, horizon):
    unseen = 136 - sum(seen)

    @lru_cache(maxsize=30000)
    def search(hand, public):
        distance = shanten(hand, melds)
        if distance == 0:
            return np.array([1.] * horizon + [0.] * (17 - horizon))
        if distance >= 4:
            return np.zeros(17)
        required = tuple(tile for tile in improving_tiles(hand, melds) if public[tile] < 4)
        live = sum(4 - public[tile] for tile in required)
        result = np.zeros(17)
        if distance == 1:
            for elapsed in reversed(range(horizon)):
                draw_probability = live / (unseen - elapsed)
                following = result[elapsed + 1] if elapsed + 1 < horizon else 0.
                result[elapsed] = draw_probability + (1. - draw_probability) * following
            return result
        children = []
        for tile in required:
            drawn = list(hand)
            drawn[tile] += 1
            next_public = list(public)
            next_public[tile] += 1
            variants = []
            for discard, amount in enumerate(drawn):
                if not amount:
                    continue
                drawn[discard] -= 1
                if shanten(drawn, melds) == distance - 1:
                    variants.append(search(tuple(drawn), tuple(next_public)))
                drawn[discard] += 1
            if variants:
                children.append((4 - public[tile], np.max(variants, axis=0)))
        for elapsed in reversed(range(horizon - 1)):
            result[elapsed] = sum(weight / (unseen - elapsed) * child[elapsed + 1]
                                  for weight, child in children)
            result[elapsed] += (1. - live / (unseen - elapsed)) * result[elapsed + 1]
        return result

    return search(tuple(counts), tuple(seen))


def probe(corpus):
    manifest = json.loads((corpus / 'manifest.json').read_text())
    for filename, key in (('frames.npz', 'frames_sha256'), ('cases.jsonl', 'cases_sha256')):
        if sha256(corpus / filename) != manifest[key]:
            raise ValueError('oracle fixture checksum mismatch')
    with np.load(corpus / 'frames.npz', allow_pickle=False) as source:
        observations = source['obs']
    cases = [json.loads(line) for line in (corpus / 'cases.jsonl').read_text().splitlines()]
    if len(cases) != len(observations) or len(cases) != manifest['cases']:
        raise ValueError('oracle fixture count mismatch')
    errors, examples = [], []
    by_distance = {distance: [] for distance in range(4)}
    for case, observation in zip(cases, observations):
        state = VisibleState(case['seat'])
        for event in case['prefix']:
            state.apply(event)
        analysis = analyze(state)
        options = [(option.tile, option.shanten) for option in analysis.discards]
        if not options:
            options = [(None, analysis.minimum_shanten)]
        for discard, distance in options:
            if distance is None or distance >= 4:
                continue
            hand = list(counts_for(state))
            if discard is not None:
                hand[discard] -= 1
            predicted = hypothesis(hand, visible_counts(state), len(own_melds(state)), analysis.horizon)
            reference = observation[961:978, discard if discard is not None else 0]
            difference = float(np.max(np.abs(predicted - reference)))
            errors.append(difference)
            by_distance[distance].append(difference)
            if difference > 1e-6:
                examples.append({'case': case['case'], 'discard': discard, 'shanten': distance,
                                 'max_abs_difference': difference})
    return {'scope': 'test a pure tenpai-maximization hypothesis; not migrated probability features',
            'diagnostic_only': True, 'migration_ready': False, 'reference_cases': len(cases),
            'candidate_vectors': len(errors), 'horizon_comparisons': 17 * len(errors),
            'max_abs_difference': max(errors, default=0.),
            'candidate_vectors_over_1e_6': sum(error > 1e-6 for error in errors),
            'by_shanten': {distance: {'candidate_vectors': len(values),
                                      'max_abs_difference': max(values, default=0.),
                                      'candidate_vectors_over_1e_6': sum(value > 1e-6 for value in values)}
                           for distance, values in by_distance.items()},
            'hypothesis_supported': bool(errors) and not examples,
            'counterexamples': sorted(examples, key=lambda row: -row['max_abs_difference'])[:10],
            'frames_sha256': manifest['frames_sha256'], 'cases_sha256': manifest['cases_sha256'],
            'probe_sha256': sha256(Path(__file__)),
            'implementation_sha256': {path.name: sha256(path) for path in sorted((ROOT / 'nagomi_compat').glob('*.py'))},
            'limitations': ['assumes future discards maximize tenpai probability independently of score',
                            'does not establish the reference search objective or EV assumptions',
                            'float64 arithmetic; agreement within a diagnostic tolerance is not exact parity',
                            'probability/EV rows remain unknown and cannot be scored']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--corpus', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    if args.out.exists():
        parser.error('use a fresh output path')
    report = probe(args.corpus)
    with args.out.open('x') as output:
        output.write(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
