"""Compare independent hand payments with recorded four-player win outcomes.

Revealed ura tiles are outcome information used for this scoring diagnostic,
never observation inputs or a substitute for future-value calculation.
"""

import argparse
from collections import Counter
import json
from pathlib import Path

from nagomi_compat.scoring import score_win
from nagomi_compat.state import VisibleState
from .audit import ROOT, sha256
from .data import read_game


def check(logs, games=32, skip=0):
    files = sorted(logs.glob('*.json.gz'))[skip:skip + games]
    if len(files) != games:
        raise ValueError('not enough requested validation games')
    implementation = {path.name: sha256(path) for path in sorted((ROOT / 'nagomi_compat').glob('*.py'))}
    counts, yaku, failures = Counter(), Counter(), []
    sources = []
    for path in files:
        prefix = []
        winners = 0
        for event_index, event in enumerate(read_game(path)):
            kind = event['type']
            if kind == 'start_kyoku':
                prefix = [event]
                winners = 0
            elif kind == 'hora':
                seat, target = event['actor'], event['target']
                state = VisibleState(seat)
                for earlier in prefix:
                    state.apply(earlier)
                tsumo = seat == target
                trigger = state.ron_window if not tsumo else None
                if not tsumo and trigger is None:
                    raise ValueError('recorded ron has no visible trigger')
                tile = None if tsumo else trigger['consumed'][0] if trigger['type'] == 'ankan' else trigger['pai']
                score = score_win(state, tile, tsumo=tsumo, ura_indicators=event.get('ura_markers', []))
                deltas = event['deltas']
                if (not isinstance(deltas, list) or len(deltas) != 4
                        or any(type(value) is not int for value in deltas)
                        or sum(deltas) < 0 or sum(deltas) % 1000):
                    raise ValueError('unsupported recorded settlement')
                deposits = sum(deltas)
                # These Tenhou-derived records award the honba only once in
                # a multiple-ron outcome, to the first recorded winner.
                honba = state.round['honba'] if winners == 0 else 0
                if winners:
                    counts['multiple_ron_followups'] += 1
                winners += 1
                hand_points = deltas[seat] - deposits - 300 * honba
                counts['wins'] += 1
                counts['self_draws' if tsumo else 'ron'] += 1
                if state.seats[seat].accepted:
                    counts['riichi_wins'] += 1
                if state.seats[seat].ippatsu:
                    counts['ippatsu_wins'] += 1
                if state.seats[seat].riichi_level == 2:
                    counts['double_riichi_wins'] += 1
                expected = [0] * 4
                if score is not None:
                    yaku.update(name for name, _ in score.yaku)
                    if score.yakuman:
                        counts['yakuman_wins'] += 1
                    if tsumo:
                        for payer in range(4):
                            if payer != seat:
                                amount = score.payments[2 if payer == state.round['oya'] else 0]
                                expected[payer] = -(amount + 100 * honba)
                    else:
                        expected[target] = -(score.total_points + 300 * honba)
                    expected[seat] = -sum(expected) + deposits
                if score is not None and score.total_points == hand_points:
                    counts['hand_total_exact'] += 1
                if score is not None and expected == deltas:
                    counts['settlement_vector_exact'] += 1
                elif len(failures) < 30:
                    failures.append({'game': path.name, 'event': event_index, 'seat': seat,
                                     'reference_hand_points': hand_points,
                                     'independent_hand_points': score.total_points if score else None,
                                     'reference_deltas': deltas, 'independent_deltas': expected,
                                     'yaku': list(score.yaku) if score else []})
                # Multiple ron results share the same visible decision prefix.
            elif prefix and kind not in ('end_kyoku', 'end_game', 'ryukyoku'):
                prefix.append(event)
        sources.append({'file': path.name, 'sha256': sha256(path)})
    return {'scope': 'revealed winning-hand scoring; not future EV or policy parity',
            'counts': dict(counts), 'yaku_counts': dict(yaku), 'examples': failures,
            'passed': counts['wins'] > 0 and counts['settlement_vector_exact'] == counts['wins'],
            'implementation_sha256': implementation, 'games': sources, 'migration_ready': False,
            'settlement_convention': 'honba once, to the first recorded winner; deposits from recorded delta sum',
            'limitations': ['recorded ura indicators are outcome-only information',
                            'liability settlement is not implemented; vector differences are reported',
                            'this does not implement the remaining probability/EV rows or win guard']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--logs', type=Path, default=Path.home() / 'Documents/mortal-4p-data/mjai/hanchan/val')
    parser.add_argument('--games', type=int, default=32)
    parser.add_argument('--skip-games', type=int, default=0)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    if args.out.exists() or not 1 <= args.games <= 256 or args.skip_games < 0:
        parser.error('use a fresh output path and bounded game selection')
    report = check(args.logs, args.games, args.skip_games)
    with args.out.open('x') as output:
        output.write(json.dumps(report, indent=2) + '\n')
    print(json.dumps({key: value for key, value in report.items() if key != 'games'}, indent=2))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
