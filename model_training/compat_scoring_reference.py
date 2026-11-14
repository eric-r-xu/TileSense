"""Oracle-only checks of independently constructed scoring edge cases.

Uses public native state/observation APIs; no reference implementation source
is read, copied, translated or imported by the replacement scorer.
"""

import argparse
import json
from pathlib import Path

import numpy as np

from nagomi_compat.hand import complete
from nagomi_compat.scoring import score_win
from nagomi_compat.state import TILES, VisibleState, redact, tile_index
from nagomi_compat.yaku import counts_for, own_melds
from .audit import ROOT, sha256
from .encoding import engine_provenance, load_engine


CASES = (
    ('pinfu', '1m 2m 3m 4m 5m 6m 7p 8p 9p 2s 3s 4s 5p 5p', '4s'),
    ('edge_wait', '1m 2m 3m 4m 5m 6m 7p 8p 9p 2s 3s 4s 5p 5p', '3m'),
    ('double_wind_pair', '3m 3m 3m 4p 4p 4p 2s 3s 4s 6s 7s 8s E E', '4s'),
    ('seven_pairs', 'E E S S W W N N 1m 1m 9p 9p 1s 1s', 'N'),
    ('ambiguous', '1p 1p 1p 2p 2p 2p 3p 3p 3p 4s 5s 6s E E', '6s'),
    ('three_suits', '2m 3m 4m 2p 3p 4p 2s 3s 4s 6s 7s 8s 5p 5p', '4s'),
    ('straight', '1m 2m 3m 4m 5m 6m 7m 8m 9m 2p 3p 4p S S', '4p'),
    ('duplicate_sequences', '2m 3m 4m 2m 3m 4m 6s 7s 8s 6s 7s 8s 5p 5p', '4m'),
    ('outside', '1m 2m 3m 7m 8m 9m 1p 2p 3p E E E S S', '3p'),
    ('terminal_outside', '1m 2m 3m 7m 8m 9m 1p 2p 3p 7s 8s 9s 9p 9p', '3p'),
    ('half_flush', '1p 2p 3p 4p 5p 6p 7p 8p 9p E E E N N', 'N'),
    ('red_five', '2m 3m 4m 4p 5pr 6p 2s 3s 4s 6s 7s 8s E E', '4s'),
    ('four_concealed_pair_wait', '1m 1m 1m 9m 9m 9m 2p 2p 2p 8p 8p 8p E E', 'E'),
    ('four_concealed_triplet_wait', '1m 1m 1m 9m 9m 9m 2p 2p 2p 8p 8p 8p E E', '2p'),
    ('orphan_thirteen_wait', '1m 9m 1p 9p 1s 9s E S W N P F C C', 'C'),
    ('orphan_single_wait', '1m 9m 1p 9p 1s 9s E S W N P F C C', '1m'),
    ('nine_gates_pure_wait', '1m 1m 1m 2m 3m 4m 5m 5m 6m 7m 8m 9m 9m 9m', '5m'),
    ('nine_gates_other_wait', '1m 1m 1m 2m 3m 4m 5m 5m 6m 7m 8m 9m 9m 9m', '1m'),
    ('three_dragons', 'P P P F F F C C C 1m 2m 3m N N', '3m'),
    ('green_and_concealed', '2s 2s 2s 3s 3s 3s 4s 4s 4s 6s 6s 6s F F', 'F'),
    ('terminals_and_concealed', '1m 1m 1m 9m 9m 9m 1p 1p 1p 9p 9p 9p 1s 1s', '1s'),
    ('winds_honors_concealed', 'E E E S S S W W W N N N C C', 'C'),
    ('dragons_honors_concealed', 'P P P F F F C C C E E E N N', 'N'),
)


def check(corpora=()):
    module = load_engine('nagomi')
    results = []
    for name, hand, winner in (*CASES, ('initial_self_draw', CASES[0][1], CASES[0][2])):
        for seat in (0, 1):
            initial = hand.split()
            initial.remove(winner)
            start = {'type': 'start_kyoku', 'bakaze': 'E', 'dora_marker': '9s', 'kyoku': 1,
                     'honba': 0, 'kyotaku': 0, 'oya': 0, 'scores': [25000] * 4,
                     'tehais': [['?'] * 13 for _ in range(4)]}
            start['tehais'][seat] = initial
            dummy = next(tile for tile in TILES if sum(tile_index(t) == tile_index(tile) for t in initial) < 4)
            prefix = (start, {'type': 'tsumo', 'actor': seat, 'pai': dummy},
                      {'type': 'dahai', 'actor': seat, 'pai': dummy, 'tsumogiri': True},
                      {'type': 'tsumo', 'actor': seat, 'pai': winner})
            if name == 'initial_self_draw':
                prefix = (start, {'type': 'tsumo', 'actor': seat, 'pai': winner})
            oracle, state = module.state.PlayerState(seat), VisibleState(seat)
            for event in prefix:
                oracle.update(json.dumps(redact(event, seat)))
                state.apply(event)
            values, mask = oracle.encode_obs(4, False)
            score = score_win(state, tsumo=True)
            native = [float(values[row, 0]) for row in (889, 890)]
            independent = [min(score.total_points, limit) / limit for limit in (100000, 30000)]
            different = max(abs(a - b) for a, b in zip(native, independent))
            results.append({'name': name, 'dealer': seat == 0, 'oracle_can_agari': bool(mask[43]),
                            'oracle_ev_scalars': native, 'independent_ev_scalars': independent,
                            'independent_points': score.total_points,
                            'passed': bool(mask[43]) and different <= 1e-7})
    frozen, sources = [], []
    for corpus in corpora:
        manifest = json.loads((corpus / 'manifest.json').read_text())
        for filename, key in (('frames.npz', 'frames_sha256'), ('cases.jsonl', 'cases_sha256')):
            if sha256(corpus / filename) != manifest[key]:
                raise ValueError('frozen scoring fixture checksum mismatch')
        with np.load(corpus / 'frames.npz', allow_pickle=False) as data:
            observations = data['obs']
        cases = [json.loads(line) for line in (corpus / 'cases.jsonl').read_text().splitlines()]
        if len(cases) != len(observations) or len(cases) != manifest['cases']:
            raise ValueError('frozen scoring fixture count mismatch')
        sources.append({key: manifest[key] for key in ('frames_sha256', 'cases_sha256', 'model_sha256')})
        for case, observation in zip(cases, observations):
            state = VisibleState(case['seat'])
            for event in case['prefix']:
                state.apply(event)
            if len(state.hand) % 3 != 2 or not complete(counts_for(state), len(own_melds(state))):
                continue
            score = score_win(state, tsumo=True)
            native = [float(observation[row, 0]) for row in (889, 890)]
            independent = [min(score.total_points, limit) / limit for limit in (100000, 30000)]
            frozen.append({'source': len(sources) - 1, 'case': case['case'],
                           'independent_points': score.total_points,
                           'passed': max(abs(a - b) for a, b in zip(native, independent)) <= 1e-7})
    return {'scope': 'completed self-draw scoring and scalar normalization; not future EV',
            'cases': results, 'frozen_completed_cases': frozen, 'frozen_sources': sources,
            'passed': all(case['passed'] for case in [*results, *frozen]), 'migration_ready': False,
            'oracle': engine_provenance('nagomi'), 'probe_sha256': sha256(Path(__file__)),
            'implementation_sha256': {path.name: sha256(path) for path in sorted((ROOT / 'nagomi_compat').glob('*.py'))},
            'limitations': ['synthetic prefixes isolate scoring and do not constitute legal full-game replay',
                            'scalar clipping cannot distinguish all hand values above normalization bounds',
                            'future EV assumptions, ron-only edge cases and liability settlement are not certified']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--corpus', type=Path, action='append', default=[])
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    if args.out.exists():
        parser.error('use a fresh output path')
    report = check(args.corpus)
    with args.out.open('x') as output:
        output.write(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
