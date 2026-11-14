"""Oracle-only differential tests of independent hand analysis and legal masks."""

import argparse
from collections import Counter
import json
from pathlib import Path
import time

import numpy as np

from nagomi_compat.legality import furiten, legal_mask
from nagomi_compat.observation import encode
from nagomi_compat.state import VisibleState, redact
from .audit import sha256
from .data import read_game
from .encoding import engine_provenance, load_engine


def check(logs, games=32, skip=0, check_features=False):
    module = load_engine('nagomi')
    files = sorted(logs.glob('*.json.gz'))[skip:skip + games]
    if len(files) != games:
        raise ValueError('not enough requested games')
    counts, mismatches, missing, extra = Counter(), Counter(), Counter(), Counter()
    feature_mismatches = Counter()
    examples = []
    sources = []
    implementation = {path.name: sha256(path) for path in sorted((Path(__file__).resolve().parents[1] / 'nagomi_compat').glob('*.py'))}
    started = time.perf_counter()

    def compare_features(state, reference, kan_phase=False):
        observation = encode(state, at_kan_select=kan_phase)
        different = observation.known_rows & np.any(np.abs(observation.values - reference) > 1e-7, axis=1)
        counts['feature_row_comparisons'] += int(observation.known_rows.sum())
        if different.any():
            mismatches['observation_features'] += 1
            feature_mismatches.update(str(row) for row in np.flatnonzero(different))
        return bool(different.any())

    for game_index, path in enumerate(files):
        events = read_game(path)
        for seat in range(4):
            independent = VisibleState(seat)
            oracle = module.state.PlayerState(seat)
            for event_index, event in enumerate(events):
                independent.apply(event)
                oracle.update(json.dumps(redact(event, seat)))
                actual = legal_mask(independent)
                expected = np.zeros(46, dtype=np.bool_)
                reference_obs = None
                if oracle.last_cans.can_act:
                    reference_obs, expected = oracle.encode_obs(4, False)
                counts['event_seat_updates'] += 1
                if oracle.last_cans.can_act or actual.any():
                    counts['decision_positions'] += 1
                failures = []
                if check_features and reference_obs is not None:
                    if compare_features(independent, reference_obs):
                        failures.append('observation_features')
                if not np.array_equal(actual, expected):
                    mismatches['normal_mask'] += 1
                    missing.update(str(i) for i in np.flatnonzero(expected & ~actual))
                    extra.update(str(i) for i in np.flatnonzero(actual & ~expected))
                    failures.append('normal_mask')
                if independent.active:
                    reference_waits = tuple(i for i, value in enumerate(oracle.waits) if value)
                    for name, left, right in (
                            ('stored_shanten', independent.stored_shanten, oracle.shanten),
                            ('waits', independent.stored_waits, reference_waits),
                            ('furiten', furiten(independent), oracle.at_furiten)):
                        counts[f'{name}_checks'] += 1
                        if left != right:
                            mismatches[name] += 1
                            failures.append(name)
                if oracle.last_cans.can_kan:
                    kan_obs, kan = oracle.encode_obs(4, True)
                    counts['kan_selection_positions'] += 1
                    if check_features and compare_features(independent, kan_obs, True):
                        failures.append('kan_observation_features')
                    if not np.array_equal(legal_mask(independent, True), kan):
                        mismatches['kan_mask'] += 1
                        failures.append('kan_mask')
                if failures and len(examples) < 30:
                    examples.append({'game': path.name, 'seat': seat, 'event': event_index,
                                     'type': event['type'], 'failures': failures,
                                     'missing': np.flatnonzero(expected & ~actual).tolist(),
                                     'extra': np.flatnonzero(actual & ~expected).tolist()})
        sources.append({'file': path.name, 'sha256': sha256(path)})
        print(json.dumps({'games': game_index + 1, 'of': games, 'seconds': round(time.perf_counter() - started, 1),
                          'mismatches': dict(mismatches)}), flush=True)
    return {'scope': 'independent hand/legality parity; not complete encoder or win-guard parity',
            'counts': dict(counts), 'mismatches': dict(mismatches), 'missing_actions': dict(missing),
            'extra_actions': dict(extra), 'examples': examples, 'games': sources,
            'feature_mismatches_by_row': dict(feature_mismatches),
            'feature_comparison': {'atol': 1e-7, 'rtol': 0, 'includes_kan_phase': True} if check_features else None,
            'passed': not mismatches, 'seconds': time.perf_counter() - started,
            'migration_ready': False,
            'implementation_sha256': implementation,
            'oracle': engine_provenance('nagomi'),
            'limitations': ['four-player hanchan only', 'no independent win guard, han/fu or EV scoring']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--logs', type=Path, default=Path.home() / 'Documents/mortal-4p-data/mjai/hanchan/val')
    parser.add_argument('--games', type=int, default=32)
    parser.add_argument('--skip-games', type=int, default=0)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--check-features', action='store_true')
    args = parser.parse_args()
    if args.out.exists() or not 1 <= args.games <= 256 or args.skip_games < 0:
        parser.error('use fresh output and bounded game selection')
    report = check(args.logs, args.games, args.skip_games, args.check_features)
    with args.out.open('x') as output:
        output.write(json.dumps(report, indent=2) + '\n')
    print(json.dumps({key: value for key, value in report.items() if key not in ('games', 'examples')}, indent=2))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
