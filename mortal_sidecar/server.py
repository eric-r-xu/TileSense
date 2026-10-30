"""Mortal sidecar: Mortal's moves for offline riichi games.

The guide's Mortal column asks it what Mortal would do in your seat, and the
Saeko bot plays its answers in hers. Each request is for one seat, and the app
sends mjai events already reduced to what that seat can see (see
packages/mahjong_core/lib/mjai.dart), so Mortal never sees hidden tiles.

Mortal runs on ONNX Runtime, not PyTorch, to fit the droplet: about 170 MB
peak and ~20 ms a decision on one thread (reports/mortal_onnx_step0; on the
droplet, 120 MB and ~100 ms). The service is stateless: each request carries the hand so
far, which is replayed into a fresh libriichi `Bot` allowed to act on the last
event only.

    POST /react  {"player_id": 0-3, "events": [{"type": "start_game"}, ...],
                  "game_length": 4 | 8}
    ->           {"reaction": {...}, "riichi_discard": {...} | null}

`game_length` is 4 for an East-only game and 8 (the default) for a hanchan:
Mortal needs it to know which hand is the last. It is only handed to libriichi
when it is not a hanchan, so a libriichi built before that option existed still
serves hanchan.

Sanma (three-player) runs the same file on a libriichi built with
`--features sanma` and a sanma model (model_sanma.json): `player_id` is then
0-2, `game_length` 3 or 6 (default 6), and the events are sanma mjai (`nukidora`
for a kita, no `chi`, three seats). The libriichi it loads decides which, so one
process serves one or the other; production runs them as two services.

`reaction` is Mortal's mjai reply (or null: nothing to do), with
`meta.q_values` / `meta.mask_bits` scoring every legal action. When it is a
`reach`, `riichi_discard` is the discard Mortal pairs with it.

Setup, from this directory (pyo3 0.25 needs Python <= 3.13):

    uv venv --python 3.12 .venv && uv pip install --python .venv/bin/python onnxruntime numpy
    (cd ~/Documents/GitHub/Mortal && PYO3_PYTHON=$OLDPWD/.venv/bin/python \\
        cargo build -p libriichi --lib --release)
    cp ~/Documents/GitHub/Mortal/target/release/libriichi.dylib libriichi.so
    .venv/bin/python server.py --model mortal_298k.onnx

For sanma, build from the fork's `sanma` branch with `--features sanma`, copy the
library to sanma/libriichi.so, and pass `--libriichi sanma --port 8791`.

The .onnx file is exported from the checkpoint by export_onnx.py. Mortal (code and weights) is AGPL-3.0.
"""

import argparse
import json
import os
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

import numpy as np
import onnxruntime as ort

MAX_BODY = 64 * 1024

parser = argparse.ArgumentParser()
parser.add_argument('--model', required=True, help='Mortal exported to ONNX (fp32)')
parser.add_argument('--host', default='127.0.0.1')
parser.add_argument('--port', type=int, default=8790)
parser.add_argument('--allow-origin', help='CORS origin, for local `flutter run` only')
parser.add_argument('--libriichi', help='folder holding libriichi.so (default: beside this file)')
args = parser.parse_args()

# libriichi.so is built from a Mortal checkout and placed beside this file.
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(here, args.libriichi) if args.libriichi else here)
from libriichi import consts
from libriichi.mjai import Bot

# Builds before sanma existed do not export these; they are 4-player.
NUM_PLAYERS = getattr(consts, 'NUM_PLAYERS', 4)
TONPUU = getattr(consts, 'TONPUU', 4)
HANCHAN = getattr(consts, 'HANCHAN', 8)


class OnnxEngine:
    """The engine contract libriichi's Mortal agent expects, backed by ONNX."""

    engine_type = 'mortal'
    # 4 for 4-player, 5 (the only one sanma builds accept) for sanma
    version = consts.MAX_VERSION
    is_oracle = False
    enable_quick_eval = True
    enable_rule_based_agari_guard = True
    name = 'mortal'

    def __init__(self, path):
        opts = ort.SessionOptions()
        opts.intra_op_num_threads = 1
        opts.inter_op_num_threads = 1
        self.session = ort.InferenceSession(path, opts, providers=['CPUExecutionProvider'])
        # A 4-player model on a sanma build (or the reverse) would fail on every
        # request; refuse to start instead.
        shape = tuple(self.session.get_inputs()[0].shape[1:])
        if shape != consts.obs_shape(self.version):
            raise SystemExit(f'{path} takes observations of shape {shape}, but this libriichi '
                             f'({NUM_PLAYERS} players) makes {consts.obs_shape(self.version)}')

    def react_batch(self, obs, masks, invisible_obs):
        masks = np.stack(masks)
        q = self.session.run(None, {'obs': np.stack(obs), 'mask': masks})[0]
        return q.argmax(-1).tolist(), q.tolist(), masks.tolist(), [True] * len(q)


engine = OnnxEngine(args.model)


def react(seat, events, game_length=HANCHAN):
    bot = Bot(engine, seat) if game_length == HANCHAN else Bot(engine, seat, game_length=game_length)
    reaction = None
    for i, event in enumerate(events):
        reaction = bot.react(json.dumps(event), can_act=i == len(events) - 1)
    reaction = None if reaction is None else json.loads(reaction)
    riichi_discard = None
    if reaction and reaction['type'] == 'reach':
        # Mortal names its riichi discard once told the riichi stands.
        followup = bot.react(json.dumps({'type': 'reach', 'actor': seat}), can_act=True)
        riichi_discard = None if followup is None else json.loads(followup)
    return {'reaction': reaction, 'riichi_discard': riichi_discard}


class Handler(BaseHTTPRequestHandler):
    def _send(self, code, body=None):
        self.send_response(code)
        if args.allow_origin:
            self.send_header('Access-Control-Allow-Origin', args.allow_origin)
            self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        if body is not None:
            self.wfile.write(json.dumps(body).encode())

    def do_OPTIONS(self):
        self._send(204)

    def do_POST(self):
        if self.path != '/react':
            return self._send(404, {'error': 'not found'})
        length = int(self.headers.get('Content-Length') or 0)
        if not 0 < length <= MAX_BODY:
            return self._send(413, {'error': 'body too large'})
        try:
            req = json.loads(self.rfile.read(length))
            events = req['events']
            seat = req.get('player_id')
            if seat not in range(NUM_PLAYERS) or not isinstance(events, list) or not events:
                raise ValueError(f'expected player_id 0-{NUM_PLAYERS - 1} and a non-empty events list')
            game_length = req.get('game_length', HANCHAN)
            if game_length not in (TONPUU, HANCHAN):
                raise ValueError(f'expected game_length {TONPUU} or {HANCHAN}')
            self._send(200, react(seat, events, game_length))
        except Exception as ex:
            self._send(400, {'error': str(ex)})

    def log_message(self, *_):
        pass  # one line per decision is noise in the journal


print(f'mortal (onnx, {NUM_PLAYERS} players) serving on http://{args.host}:{args.port}', file=sys.stderr)
HTTPServer((args.host, args.port), Handler).serve_forever()
