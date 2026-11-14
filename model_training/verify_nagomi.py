"""Compare local Nagomi candidates to the deployed ONNX on real replay inputs.

Uses the model source at the production manifest's pinned engine commit, not
the source currently checked out in the training repository. Read-only inputs.
"""

import argparse
import gzip
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import types

import numpy as np
import onnxruntime as ort
import torch

from .audit import ROOT, sha256


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine-repo', type=Path, default=ROOT.parent / 'Mortal')
    parser.add_argument('--candidates', type=Path,
                        default=Path.home() / 'Documents/mortal-4p-data/ft/run1')
    parser.add_argument('--logs', type=Path,
                        default=Path.home() / 'Documents/mortal-4p-data/mjai/hanchan/val')
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    if args.out.exists():
        parser.error('output already exists')
    manifest = json.loads((ROOT / 'mortal_sidecar/model_nagomi.json').read_text())
    artifact = ROOT / 'mortal_sidecar/mortal_nagomi.onnx'
    if sha256(artifact) != manifest['sha256']:
        parser.error('local ONNX does not match production manifest')
    # This is the project's trusted local engine source, pinned by the manifest.
    source = subprocess.check_output(
        ['git', '-C', str(args.engine_repo), 'show', f"{manifest['mortal_commit']}:mortal/model.py"],
        text=True)
    sys.path.insert(0, str(ROOT / 'mortal_sidecar'))
    module = types.ModuleType('pinned_model')
    exec(compile(source, 'pinned_model.py', 'exec'), module.__dict__)
    from export_onnx import OnnxEngine, Recorder, seat_view
    from libriichi.mjai import Bot

    candidates = sorted(args.candidates.glob('g*.pth'))
    logs = sorted(args.logs.glob('*.json.gz'))[:1]
    if not candidates or not logs:
        parser.error('need at least one candidate and validation game')
    seen_obs, seen_masks = [], []
    recorder = Recorder(OnnxEngine(str(artifact)), seen_obs, seen_masks)
    for log in logs:
        with gzip.open(log, 'rt') as file:
            events = [json.loads(line) for line in file]
        for seat in range(4):
            bot = Bot(recorder, seat)
            for event in seat_view(events, seat):
                bot.react(json.dumps(event), can_act=True)
    if not seen_obs:
        raise ValueError('replay generated no decisions')
    indices = np.random.default_rng(7).permutation(len(seen_obs))[:128]
    obs = np.stack(seen_obs)[indices].astype(np.float32)
    masks = np.stack(seen_masks)[indices]
    options = ort.SessionOptions()
    options.intra_op_num_threads = 1
    session = ort.InferenceSession(str(artifact), options, providers=['CPUExecutionProvider'])
    actual = session.run(None, {'obs': obs, 'mask': masks})[0]
    torch.set_num_threads(1)
    results = []
    for path in candidates:
        state = torch.load(path, weights_only=True, map_location='cpu')
        brain = module.Brain(version=4, **state['config']['resnet']).eval()
        head = module.DQN(version=4).eval()
        brain.load_state_dict(state['mortal'])
        head.load_state_dict(state['current_dqn'])
        with torch.inference_mode():
            expected = head(brain(torch.from_numpy(obs)), torch.from_numpy(masks)).numpy()
        difference = float(np.abs(expected[masks] - actual[masks]).max())
        row = {'candidate': path.name, 'sha256': sha256(path),
               'max_abs_legal_q_difference': difference,
               'same_action_fraction': float((expected.argmax(-1) == actual.argmax(-1)).mean()),
               'matches_replay_fixture': bool(np.allclose(expected[masks], actual[masks], rtol=1e-4, atol=1e-5)),
               'can_resume_original_training': all(k in state for k in ('optimizer', 'scheduler', 'steps'))}
        results.append(row)
        print(json.dumps(row), flush=True)
    report = {'schema_version': 1, 'model_sha256': manifest['sha256'],
              'engine_commit': manifest['mortal_commit'], 'decisions': len(obs),
              'replayed_games': [{'file': p.name, 'sha256': sha256(p)} for p in logs],
              'fixture_sha256': hashlib.sha256(obs.tobytes() + masks.tobytes()).hexdigest(),
              'candidates': results,
              'limitation': 'numerical agreement on a replay fixture; not byte-level export provenance '
                            'or an estimate of playing strength'}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open('x') as file:
        json.dump(report, file, indent=2)
        file.write('\n')


if __name__ == '__main__':
    main()
