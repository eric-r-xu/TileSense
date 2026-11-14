"""Test a one-shanten probability hypothesis against frozen oracle frames.

This diagnostic is separate from the replacement encoder. Agreement here does
not implement or certify the full probability/EV search or promote any rows.
"""

import argparse
import json
from pathlib import Path

import numpy as np

from nagomi_compat.efficiency import analyze
from nagomi_compat.state import VisibleState
from nagomi_compat.visibility import visible_counts
from .audit import sha256


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
    errors = []
    positions = candidates = 0
    for case, observation in zip(cases, observations):
        state = VisibleState(case['seat'])
        for event in case['prefix']:
            state.apply(event)
        analysis = analyze(state)
        unseen = 136 - sum(visible_counts(state))
        options = [(option.tile, option.shanten, option.live_copies) for option in analysis.discards]
        if not options:
            live = sum(4 - visible_counts(state)[tile] for tile in analysis.required)
            options = [(None, analysis.minimum_shanten, live)]
        tested_position = False
        for tile, distance, live in options:
            if distance != 1:
                continue
            tested_position = True
            candidates += 1
            for elapsed in range(17):
                horizon = max(analysis.horizon - elapsed, 0)
                miss = 1.0
                # A later starting point has fewer unknown tiles. The
                # calculation conditions on no earlier useful draw.
                for turn in range(horizon):
                    miss *= 1.0 - live / (unseen - elapsed - turn)
                prediction = 1.0 - miss
                reference = observation[961 + elapsed, tile if tile is not None else 0]
                errors.append(abs(prediction - float(reference)))
        positions += int(tested_position)
    return {'scope': 'one-shanten analytical probability diagnostic only',
            'diagnostic_only': True, 'migration_ready': False,
            'reference_cases': len(cases), 'positions': positions, 'discard_or_response_candidates': candidates,
            'horizon_comparisons': len(errors), 'max_abs_difference': max(errors, default=0.0),
            'differences_over_1e_7': sum(error > 1e-7 for error in errors),
            'differences_over_1e_6': sum(error > 1e-6 for error in errors),
            'formula': '1 - product(1 - live / (unseen - elapsed - turn)) over remaining own draws',
            'frames_sha256': manifest['frames_sha256'], 'cases_sha256': manifest['cases_sha256'],
            'model_sha256': manifest['model_sha256'], 'probe_sha256': sha256(Path(__file__)),
            'limitations': ['uses oracle observations only as expected outputs',
                            'float64 analytical calculation; pinned float32 operation order is unresolved',
                            'does not test two/three-shanten search, winning probabilities or score EV',
                            'does not mark any probability/EV row implemented']}


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
