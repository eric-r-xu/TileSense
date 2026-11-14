"""Oracle-only Nagomi compatibility fixtures; never imported by the new library.

Reference state/encoding/guards come from the existing pinned libriichi build.
Replacement code is independently written and tested on these observable traces.
"""

import argparse
from collections import Counter
import json
from pathlib import Path
import sys
import time

import numpy as np

from nagomi_compat.state import redact
from .audit import ROOT, sha256
from .data import read_game, replay_samples
from .encoding import load_engine


def category(row):
    if row['kan_select']:
        return 'kan_selection'
    label = row['label']
    if label < 37:
        return 'discard'
    return {37: 'riichi', 38: 'chi', 39: 'chi', 40: 'chi', 41: 'pon', 42: 'kan',
            43: 'agari', 44: 'abortive_draw', 45: 'pass'}[label]


def capture(log_dir, out, games=16, per_kind=32, skip_games=0):
    if out.exists():
        raise FileExistsError('reference output already exists')
    module = load_engine('nagomi')
    sys.path.insert(0, str(ROOT / 'mortal_sidecar'))
    from export_onnx import OnnxEngine
    reference_engine = OnnxEngine(str(ROOT / 'mortal_sidecar/mortal_nagomi.onnx'))

    def reply(seat, events):
        bot = module.mjai.Bot(reference_engine, seat)
        reaction = None
        for index, event in enumerate(events):
            reaction = bot.react(json.dumps(event), can_act=index + 1 == len(events))
        reaction = None if reaction is None else json.loads(reaction)
        discard = None
        if reaction and reaction['type'] == 'reach':
            value = bot.react(json.dumps({'type': 'reach', 'actor': seat}), can_act=True)
            discard = None if value is None else json.loads(value)
        return {'reaction': None if reaction is None else {k: v for k, v in reaction.items() if k != 'meta'},
                'riichi_discard': None if discard is None else {k: v for k, v in discard.items() if k != 'meta'}}

    selected = Counter()
    metadata, observations, masks, q_values = [], [], [], []
    started = time.perf_counter()
    sources = []
    files = sorted(log_dir.glob('*.json.gz'))[skip_games:skip_games + games]
    if len(files) != games:
        raise ValueError('not enough games for requested reference selection')
    for game_index, path in enumerate(files):
        events = read_game(path)
        rows, _ = replay_samples('nagomi', events)
        # Select deterministically across the entire game, including rare actions.
        wanted = []
        for index in np.random.default_rng(100 + game_index).permutation(len(rows)):
            row = rows[index]
            kind = category(row)
            if selected[kind] < per_kind:
                selected[kind] += 1
                wanted.append((row, kind))
        grouped = {}
        for row, kind in wanted:
            grouped.setdefault(row['seat'], {}).setdefault(row['event_index'], []).append((row, kind))
        for seat, positions in grouped.items():
            state = module.state.PlayerState(seat)
            prefix = [{'type': 'start_game'}]
            for event_index, raw in enumerate(events):
                clean = redact(raw, seat)
                state.update(json.dumps(clean))
                if clean['type'] == 'start_kyoku':
                    prefix = [{'type': 'start_game'}]
                if clean['type'] != 'start_game':
                    prefix.append(clean)
                for row, kind in positions.get(event_index, []):
                    obs, mask = state.encode_obs(4, row['kan_select'])
                    q = reference_engine.session.run(None, {'obs': obs[None], 'mask': mask[None]})[0][0]
                    target = None if row['kan_select'] else reply(seat, prefix)
                    observations.append(obs)
                    masks.append(mask)
                    q_values.append(q)
                    metadata.append({'case': len(metadata), 'game': path.name, 'seat': seat,
                                     'event_index': event_index, 'kind': kind,
                                     'kan_select': row['kan_select'], 'prefix': list(prefix),
                                     'reference': target, 'argmax': int(q.argmax())})
        sources.append({'file': path.name, 'sha256': sha256(path)})
        print(json.dumps({'games': game_index + 1, 'cases': len(metadata),
                          'seconds': round(time.perf_counter() - started, 1)}), flush=True)
    if not metadata:
        raise ValueError('no compatibility fixtures selected')
    out.mkdir(parents=True)
    np.savez_compressed(out / 'frames.npz', obs=np.stack(observations),
                        mask=np.stack(masks), q=np.stack(q_values))
    with (out / 'cases.jsonl').open('x') as output:
        for case in metadata:
            output.write(json.dumps(case, separators=(',', ':')) + '\n')
    manifest = {'format_version': 1, 'scope': 'oracle fixtures only; not a migrated library',
                'model_sha256': sha256(ROOT / 'mortal_sidecar/mortal_nagomi.onnx'),
                'oracle_binary_sha256': sha256(Path(module.__file__)),
                'oracle_inference': 'mortal_sidecar.export_onnx.OnnxEngine',
                'oracle_code_sha256': sha256(ROOT / 'mortal_sidecar/export_onnx.py'),
                'cases': len(metadata), 'by_kind': dict(selected), 'games': sources,
                'frames_sha256': sha256(out / 'frames.npz'),
                'cases_sha256': sha256(out / 'cases.jsonl')}
    (out / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--logs', type=Path,
                        default=Path.home() / 'Documents/mortal-4p-data/mjai/hanchan/val')
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--games', type=int, default=16)
    parser.add_argument('--per-kind', type=int, default=32)
    parser.add_argument('--skip-games', type=int, default=0)
    args = parser.parse_args()
    if not 1 <= args.games <= 128 or not 1 <= args.per_kind <= 256 or args.skip_games < 0:
        parser.error('reference capture bounds exceeded')
    capture(args.logs, args.out, args.games, args.per_kind, args.skip_games)


if __name__ == '__main__':
    main()
