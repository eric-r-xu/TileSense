"""Mortal sidecar: Mortal's opinion for the guide's "Mortal decision" column.

Offline riichi games ask it, for your seat only, what Mortal would do with
exactly what your seat can see (the app sends mjai events already reduced to
that view; see packages/mahjong_core/lib/mjai.dart). It is display only: no
seat is played by it.

Mortal runs on ONNX Runtime, not PyTorch, to fit the droplet: about 170 MB
peak and ~20 ms a decision on one thread (reports/mortal_onnx_step0; on the
droplet, 120 MB and ~100 ms). The service is stateless: each request carries the hand so
far, which is replayed into a fresh libriichi `Bot` allowed to act on the last
event only.

    POST /react  {"player_id": 0, "events": [{"type": "start_game"}, ...]}
    ->           {"reaction": {...}, "riichi_discard": {...} | null}

`reaction` is Mortal's mjai reply (or null: nothing to do), with
`meta.q_values` / `meta.mask_bits` scoring every legal action. When it is a
`reach`, `riichi_discard` is the discard Mortal pairs with it.

Setup, from this directory (pyo3 0.25 needs Python <= 3.13):

    uv venv --python 3.12 .venv && uv pip install --python .venv/bin/python onnxruntime numpy
    (cd ~/Documents/GitHub/Mortal && PYO3_PYTHON=$OLDPWD/.venv/bin/python \\
        cargo build -p libriichi --lib --release)
    cp ~/Documents/GitHub/Mortal/target/release/libriichi.dylib libriichi.so
    .venv/bin/python server.py --model mortal_298k.onnx

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
SEAT = 0  # the human seat; bots never ask

parser = argparse.ArgumentParser()
parser.add_argument('--model', required=True, help='Mortal exported to ONNX (fp32)')
parser.add_argument('--host', default='127.0.0.1')
parser.add_argument('--port', type=int, default=8790)
parser.add_argument('--allow-origin', help='CORS origin, for local `flutter run` only')
args = parser.parse_args()

# libriichi.so is built from a Mortal checkout and placed beside this file.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from libriichi.mjai import Bot


class OnnxEngine:
    """The engine contract libriichi's Mortal agent expects, backed by ONNX."""

    engine_type = 'mortal'
    version = 4
    is_oracle = False
    enable_quick_eval = True
    enable_rule_based_agari_guard = True
    name = 'mortal'

    def __init__(self, path):
        opts = ort.SessionOptions()
        opts.intra_op_num_threads = 1
        opts.inter_op_num_threads = 1
        self.session = ort.InferenceSession(path, opts, providers=['CPUExecutionProvider'])

    def react_batch(self, obs, masks, invisible_obs):
        masks = np.stack(masks)
        q = self.session.run(None, {'obs': np.stack(obs), 'mask': masks})[0]
        return q.argmax(-1).tolist(), q.tolist(), masks.tolist(), [True] * len(q)


engine = OnnxEngine(args.model)


def react(events):
    bot = Bot(engine, SEAT)
    reaction = None
    for i, event in enumerate(events):
        reaction = bot.react(json.dumps(event), can_act=i == len(events) - 1)
    reaction = None if reaction is None else json.loads(reaction)
    riichi_discard = None
    if reaction and reaction['type'] == 'reach':
        # Mortal names its riichi discard once told the riichi stands.
        followup = bot.react(json.dumps({'type': 'reach', 'actor': SEAT}), can_act=True)
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
            if req.get('player_id') != SEAT or not isinstance(events, list) or not events:
                raise ValueError('expected player_id 0 and a non-empty events list')
            self._send(200, react(events))
        except Exception as ex:
            self._send(400, {'error': str(ex)})

    def log_message(self, *_):
        pass  # one line per decision is noise in the journal


print(f'mortal (onnx) serving on http://{args.host}:{args.port}', file=sys.stderr)
HTTPServer((args.host, args.port), Handler).serve_forever()
