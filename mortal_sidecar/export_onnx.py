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
"""

import argparse
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
FP32 = os.path.join(HERE, 'mortal_298k.onnx')
INT8 = os.path.join(HERE, 'mortal_298k.int8.onnx')
sys.path.insert(0, HERE)


class OnnxEngine:
    """The engine contract libriichi's Mortal agent expects, backed by ONNX."""

    engine_type = 'mortal'
    version = 4
    is_oracle = False
    enable_quick_eval = True
    enable_rule_based_agari_guard = True
    name = 'mortal-onnx'

    def __init__(self, path):
        import onnxruntime as ort
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


def measure(path, requests_file):
    """Runs in a fresh process: only libriichi, onnxruntime and numpy."""
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


def export(torch, brain, dqn):
    class Scorer(torch.nn.Module):
        def __init__(self):
            super().__init__()
            self.brain, self.dqn = brain, dqn

        def forward(self, obs, mask):
            return self.dqn(self.brain(obs), mask)

    obs = torch.zeros(2, 1012, 34)
    mask = torch.ones(2, 46, dtype=torch.bool)
    with torch.no_grad():
        torch.onnx.export(Scorer().eval(), (obs, mask), FP32, input_names=['obs', 'mask'],
                          output_names=['q'], opset_version=17, dynamo=False,
                          dynamic_axes={'obs': {0: 'batch'}, 'mask': {0: 'batch'},
                                        'q': {0: 'batch'}})


def collect(engine, seeds):
    """(obs, mask) of every decision Mortal makes in [seeds] x 4 hanchan of self-play."""
    from libriichi.arena import OneVsThree
    seen_obs, seen_masks = [], []

    class Recorder:
        engine_type, version, is_oracle = 'mortal', engine.version, False
        enable_quick_eval = engine.enable_quick_eval
        enable_rule_based_agari_guard = engine.enable_rule_based_agari_guard
        name = 'recorder'

        def react_batch(self, obs, masks, invisible_obs):
            seen_obs.extend(obs)
            seen_masks.extend(masks)
            return engine.react_batch(obs, masks, invisible_obs)

    OneVsThree(disable_progress_bar=True).py_vs_py(
        challenger=Recorder(), champion=Recorder(), seed_start=(10000, 0x2000), seed_count=seeds)
    return np.stack(seen_obs).astype(np.float32), np.stack(seen_masks)


def quantize(calib_obs, calib_masks):
    from onnxruntime.quantization import (CalibrationDataReader, QuantFormat, QuantType,
                                          quantize_static)
    from onnxruntime.quantization.shape_inference import quant_pre_process

    class Reader(CalibrationDataReader):
        def __init__(self):
            self.items = iter({'obs': calib_obs[i:i + 1], 'mask': calib_masks[i:i + 1]}
                              for i in range(len(calib_obs)))

        def get_next(self):
            return next(self.items, None)

    prepped = FP32 + '.prep'
    quant_pre_process(FP32, prepped)
    quantize_static(prepped, INT8, Reader(), quant_format=QuantFormat.QDQ,
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
    parser.add_argument('--mortal-dir', default=os.path.expanduser('~/Documents/GitHub/Mortal/mortal'))
    parser.add_argument('--seeds', type=int, default=2, help='x4 hanchan of self-play')
    parser.add_argument('--measure', nargs=2, metavar=('MODEL', 'REQUESTS'), help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.measure:
        return measure(*args.measure)

    torch, brain, dqn, engine = load_torch(args.state, args.mortal_dir)
    print('1/4 exporting fp32 ONNX', flush=True)
    export(torch, brain, dqn)
    print(f'2/4 collecting positions from {args.seeds * 4} hanchan of self-play', flush=True)
    obs, masks = collect(engine, args.seeds)
    rng = np.random.default_rng(0)
    order = rng.permutation(len(obs))
    calib, evaluate = order[:500], order[500:]
    np.savez_compressed(POSITIONS, obs=obs, masks=masks)
    print(f'    {len(obs)} decisions', flush=True)
    print('3/4 quantizing to int8', flush=True)
    quantize(obs[calib], masks[calib])

    print('4/4 measuring', flush=True)
    with torch.inference_mode():
        torch_q = np.concatenate([
            dqn(brain(torch.from_numpy(obs[evaluate][i:i + 256])),
                torch.from_numpy(masks[evaluate][i:i + 256])).numpy()
            for i in range(0, len(evaluate), 256)])
    requests = os.path.join(HERE, 'step0_requests.json')
    json.dump(requests_from(200), open(requests, 'w'))
    summary = {'decisions': len(obs), 'evaluated': len(evaluate)}
    env = dict(os.environ, OMP_NUM_THREADS='1')
    for label, path in [('fp32', FP32), ('int8', INT8)]:
        result = agreement(path, obs[evaluate], masks[evaluate], torch_q)
        run = subprocess.run([sys.executable, __file__, '--measure', path, requests],
                             env=env, capture_output=True, text=True, check=True)
        result.update(json.loads(run.stdout.strip().splitlines()[-1]))
        result['file_mb'] = round(os.path.getsize(path) / 2**20, 1)
        summary[label] = result
    os.remove(requests)

    os.makedirs(os.path.dirname(REPORT), exist_ok=True)
    json.dump(summary, open(REPORT, 'w'), indent=2)
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()
