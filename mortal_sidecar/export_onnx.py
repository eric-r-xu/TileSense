"""Exports a Mortal checkpoint to the ONNX model production runs, and checks it.

Exports Mortal to ONNX (fp32 and a static int8), checks both pick the same
actions as PyTorch on positions from real Mortal games, and measures a
production-shaped process — libriichi + onnxruntime + numpy, no torch — for
peak memory and latency. Results: reports/mortal_onnx_step0/summary.json
(mortal_298k: fp32 100% same actions, 169 MB peak; int8 only 93%, not used).
Nothing here is used by the app.

Setup, from this directory: a Mac-native libriichi.so and a venv as in
server.py's header, plus the export-only packages, and the checkpoint from
https://huggingface.co/VoidShine/mortal-298k beside this file:

    uv pip install --python .venv/bin/python torch onnx onnxruntime onnxscript
    OMP_NUM_THREADS=1 .venv/bin/python export_onnx.py --state mortal_298k.pth

To ship a new model: publish mortal_298k.onnx (fp32) as a GitHub release,
point model.json's url and sha256 at it, and merge; deploys pick it up.

Sanma: build libriichi with `--features sanma` into sanma/libriichi.so (see
server.py) and take the test positions from held-out mjai logs, because
libriichi's self-play arena is 4-player only:

    OMP_NUM_THREADS=1 .venv/bin/python export_onnx.py --state mortal_sanma.pth \
        --out mortal_sanma.onnx --libriichi sanma \
        --logs ~/Documents/mortal-sanma-data/mjai/sanma-hanchan/val \
        --report ../reports/mortal_onnx_sanma/summary.json

Ship it the same way, through model_sanma.json.
"""

import argparse
import glob
import gzip
import json
import os
import resource
import subprocess
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPORT = os.path.join(HERE, '..', 'reports', 'mortal_onnx_step0', 'summary.json')
POSITIONS = os.path.join(HERE, 'step0_positions.npz')



def use_libriichi(folder):
    """Imports libriichi from [folder] (relative to this file), or from beside it."""
    sys.path.insert(0, os.path.join(HERE, folder) if folder else HERE)


class OnnxEngine:
    """The engine contract libriichi's Mortal agent expects, backed by ONNX."""

    engine_type = 'mortal'
    is_oracle = False
    enable_quick_eval = True
    enable_rule_based_agari_guard = True
    name = 'mortal-onnx'

    def __init__(self, path):
        import onnxruntime as ort
        from libriichi.consts import MAX_VERSION
        self.version = MAX_VERSION  # 4, or 5 on a sanma build
        opts = ort.SessionOptions()
        opts.intra_op_num_threads = 1
        opts.inter_op_num_threads = 1
        self.session = ort.InferenceSession(path, opts, providers=['CPUExecutionProvider'])

    def react_batch(self, obs, masks, invisible_obs):
        masks = np.stack(masks)
        q = self.session.run(None, {'obs': np.stack(obs), 'mask': masks})[0]
        return q.argmax(-1).tolist(), q.tolist(), masks.tolist(), [True] * len(q)


def rss_mb():
    peak = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
    return peak / 2**20 if sys.platform == 'darwin' else peak / 2**10


def measure(path, requests_file, libriichi):
    """Runs in a fresh process: only libriichi, onnxruntime and numpy."""
    use_libriichi(libriichi)
    from libriichi.mjai import Bot
    engine = OnnxEngine(path)
    requests = json.load(open(requests_file))
    loaded = rss_mb()
    times, replies = [], []
    for player_id, events in requests:
        start = time.perf_counter()
        bot = Bot(engine, player_id)
        reaction = None
        for i, event in enumerate(events):
            reaction = bot.react(json.dumps(event), can_act=i == len(events) - 1)
        times.append((time.perf_counter() - start) * 1000)
        replies.append(None if reaction is None else json.loads(reaction)['type'])
    times.sort()
    print(json.dumps({
        'rss_after_load_mb': round(loaded, 1),
        'peak_rss_mb': round(rss_mb(), 1),
        'p50_ms': round(times[len(times) // 2], 1),
        'p95_ms': round(times[int(len(times) * 0.95)], 1),
        'first_reply': replies[0],
        'requests': len(times),
        'torch_loaded': 'torch' in sys.modules,
    }))


def load_torch(state_path, mortal_dir):
    import torch
    sys.path.insert(1, mortal_dir)
    from model import Brain, DQN
    from engine import MortalEngine
    state = torch.load(state_path, weights_only=True, map_location='cpu')
    cfg = state['config']
    version = cfg['control'].get('version', 1)
    brain = Brain(version=version, num_blocks=cfg['resnet']['num_blocks'],
                  conv_channels=cfg['resnet']['conv_channels']).eval()
    dqn = DQN(version=version).eval()
    brain.load_state_dict(state['mortal'])
    dqn.load_state_dict(state['current_dqn'])
    engine = MortalEngine(brain, dqn, version=version, is_oracle=False,
                          device=torch.device('cpu'), enable_amp=False,
                          enable_quick_eval=True, enable_rule_based_agari_guard=True,
                          name='mortal')
    return torch, brain, dqn, engine


def export(torch, brain, dqn, version, path):
    from libriichi.consts import ACTION_SPACE, obs_shape

    class Scorer(torch.nn.Module):
        def __init__(self):
            super().__init__()
            self.brain, self.dqn = brain, dqn

        def forward(self, obs, mask):
            return self.dqn(self.brain(obs), mask)

    obs = torch.zeros(2, *obs_shape(version))
    mask = torch.ones(2, ACTION_SPACE, dtype=torch.bool)
    with torch.no_grad():
        torch.onnx.export(Scorer().eval(), (obs, mask), path, input_names=['obs', 'mask'],
                          output_names=['q'], opset_version=17, dynamo=False,
                          dynamic_axes={'obs': {0: 'batch'}, 'mask': {0: 'batch'},
                                        'q': {0: 'batch'}})


class Recorder:
    """Passes decisions on to [engine] and keeps their (obs, mask)."""

    def __init__(self, engine, seen_obs, seen_masks):
        self.engine, self.seen_obs, self.seen_masks = engine, seen_obs, seen_masks
        self.engine_type, self.version, self.is_oracle = 'mortal', engine.version, False
        self.enable_quick_eval = engine.enable_quick_eval
        self.enable_rule_based_agari_guard = engine.enable_rule_based_agari_guard
        self.name = 'recorder'

    def react_batch(self, obs, masks, invisible_obs):
        self.seen_obs.extend(obs)
        self.seen_masks.extend(masks)
        return self.engine.react_batch(obs, masks, invisible_obs)


def collect(engine, seeds):
    """(obs, mask) of every decision Mortal makes in [seeds] x 4 hanchan of self-play."""
    from libriichi.arena import OneVsThree
    seen_obs, seen_masks = [], []
    recorder = Recorder(engine, seen_obs, seen_masks)
    OneVsThree(disable_progress_bar=True).py_vs_py(
        challenger=recorder, champion=recorder, seed_start=(10000, 0x2000), seed_count=seeds)
    return np.stack(seen_obs).astype(np.float32), np.stack(seen_masks)


def read_logs(folder, games):
    """The first [games] mjai logs in [folder] (sorted by name), each a list of events."""
    files = sorted(glob.glob(os.path.join(folder, '*.json.gz')))[:games]
    if not files:
        raise SystemExit(f'no *.json.gz logs in {folder}')
    return [[json.loads(line) for line in gzip.open(f, 'rt')] for f in files]


def seat_view(events, seat):
    """[events] as [seat] sees them: other hands and draws hidden, as the apps send."""
    view = []
    for e in events:
        if e['type'] == 'start_kyoku':
            e = dict(e, tehais=[t if i == seat else ['?'] * len(t) for i, t in enumerate(e['tehais'])])
        elif e['type'] == 'tsumo' and e['actor'] != seat:
            e = dict(e, pai='?')
        view.append(e)
    return view


def collect_logs(engine, logs):
    """(obs, mask) of every decision each seat faces when [logs] are replayed.

    The replay follows the log, not Mortal's replies, so positions are the
    human players' and Mortal is scored on each of them."""
    from libriichi.consts import HANCHAN, NUM_PLAYERS
    from libriichi.mjai import Bot
    seen_obs, seen_masks = [], []
    recorder = Recorder(engine, seen_obs, seen_masks)
    for events in logs:
        for seat in range(NUM_PLAYERS):
            bot = Bot(recorder, seat, game_length=HANCHAN)
            for e in seat_view(events, seat):
                bot.react(json.dumps(e), can_act=True)
    return np.stack(seen_obs).astype(np.float32), np.stack(seen_masks)


def log_requests(logs, count):
    """Requests as server.py receives them: seat 0's view of a log, cut after
    each of its own draws."""
    requests = []
    for events in logs:
        view = seat_view(events, 0)
        requests += [[0, view[:i + 1]] for i, e in enumerate(view)
                     if e['type'] == 'tsumo' and e['actor'] == 0]
        if len(requests) >= count:
            return requests[:count]
    return requests


def quantize(calib_obs, calib_masks, fp32, int8):
    from onnxruntime.quantization import (CalibrationDataReader, QuantFormat, QuantType,
                                          quantize_static)
    from onnxruntime.quantization.shape_inference import quant_pre_process

    class Reader(CalibrationDataReader):
        def __init__(self):
            self.items = iter({'obs': calib_obs[i:i + 1], 'mask': calib_masks[i:i + 1]}
                              for i in range(len(calib_obs)))

        def get_next(self):
            return next(self.items, None)

    prepped = fp32 + '.prep'
    quant_pre_process(fp32, prepped)
    quantize_static(prepped, int8, Reader(), quant_format=QuantFormat.QDQ,
                    activation_type=QuantType.QInt8, weight_type=QuantType.QInt8,
                    op_types_to_quantize=['Conv', 'MatMul', 'Gemm'], per_channel=True)
    os.remove(prepped)


def agreement(path, obs, masks, torch_q):
    engine = OnnxEngine(path)
    q = np.concatenate([engine.session.run(None, {'obs': obs[i:i + 256], 'mask': masks[i:i + 256]})[0]
                        for i in range(0, len(obs), 256)])
    legal = np.isfinite(torch_q)
    return {
        'same_action_pct': round(100 * float((q.argmax(-1) == torch_q.argmax(-1)).mean()), 3),
        'max_abs_q_diff': round(float(np.abs(q[legal] - torch_q[legal]).max()), 4),
    }


def requests_from(count):
    """Canned requests, as server.py receives them: the earlier benchmark hand."""
    q = '?'
    events = [
        {'type': 'start_game', 'names': ['a', 'b', 'c', 'd']},
        {'type': 'start_kyoku', 'bakaze': 'E', 'dora_marker': '1p', 'kyoku': 1, 'honba': 0,
         'kyotaku': 0, 'oya': 0, 'scores': [25000] * 4,
         'tehais': [[q] * 13, ['1m', '2m', '3m', '5p', '6p', '7p', '2s', '3s', '9s', 'E', 'E', 'N', 'P'],
                    [q] * 13, [q] * 13]},
        {'type': 'tsumo', 'actor': 0, 'pai': q},
        {'type': 'dahai', 'actor': 0, 'pai': 'W', 'tsumogiri': True},
        {'type': 'tsumo', 'actor': 1, 'pai': '4s'},
    ]
    return [[1, events]] * count


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--state', default=os.path.join(HERE, 'mortal_298k.pth'))
    parser.add_argument('--out', default=os.path.join(HERE, 'mortal_298k.onnx'),
                        help='fp32 model to write; the int8 one goes beside it')
    parser.add_argument('--mortal-dir', default=os.path.expanduser('~/Documents/GitHub/Mortal/mortal'))
    parser.add_argument('--libriichi', help='folder holding libriichi.so (default: beside this file)')
    parser.add_argument('--seeds', type=int, default=2, help='x4 hanchan of self-play')
    parser.add_argument('--logs', help='take positions from these mjai logs instead of self-play')
    parser.add_argument('--games', type=int, default=40, help='logs to read with --logs')
    parser.add_argument('--report', default=REPORT)
    parser.add_argument('--measure', nargs=2, metavar=('MODEL', 'REQUESTS'), help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.measure:
        return measure(*args.measure, args.libriichi)

    use_libriichi(args.libriichi)
    fp32 = os.path.abspath(args.out)
    int8 = fp32.removesuffix('.onnx') + '.int8.onnx'
    torch, brain, dqn, engine = load_torch(args.state, args.mortal_dir)
    print('1/4 exporting fp32 ONNX', flush=True)
    export(torch, brain, dqn, engine.version, fp32)
    if args.logs:
        logs = read_logs(args.logs, args.games)
        print(f'2/4 collecting positions from {len(logs)} logs', flush=True)
        obs, masks = collect_logs(engine, logs)
        positions = fp32.removesuffix('.onnx') + '_positions.npz'
    else:
        print(f'2/4 collecting positions from {args.seeds * 4} hanchan of self-play', flush=True)
        obs, masks = collect(engine, args.seeds)
        positions = POSITIONS
    rng = np.random.default_rng(0)
    order = rng.permutation(len(obs))
    calib, evaluate = order[:500], order[500:]
    np.savez_compressed(positions, obs=obs, masks=masks)
    print(f'    {len(obs)} decisions', flush=True)
    print('3/4 quantizing to int8', flush=True)
    quantize(obs[calib], masks[calib], fp32, int8)

    print('4/4 measuring', flush=True)
    with torch.inference_mode():
        torch_q = np.concatenate([
            dqn(brain(torch.from_numpy(obs[evaluate][i:i + 256])),
                torch.from_numpy(masks[evaluate][i:i + 256])).numpy()
            for i in range(0, len(evaluate), 256)])
    requests = os.path.join(HERE, 'step0_requests.json')
    json.dump(log_requests(logs, 200) if args.logs else requests_from(200), open(requests, 'w'))
    summary = {'decisions': len(obs), 'evaluated': len(evaluate)}
    env = dict(os.environ, OMP_NUM_THREADS='1')
    measure_args = ['--libriichi', args.libriichi] if args.libriichi else []
    for label, path in [('fp32', fp32), ('int8', int8)]:
        result = agreement(path, obs[evaluate], masks[evaluate], torch_q)
        run = subprocess.run([sys.executable, __file__, '--measure', path, requests, *measure_args],
                             env=env, capture_output=True, text=True, check=True)
        result.update(json.loads(run.stdout.strip().splitlines()[-1]))
        result['file_mb'] = round(os.path.getsize(path) / 2**20, 1)
        summary[label] = result
    os.remove(requests)

    os.makedirs(os.path.dirname(os.path.abspath(args.report)), exist_ok=True)
    json.dump(summary, open(args.report, 'w'), indent=2)
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()
