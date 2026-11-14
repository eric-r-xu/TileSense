"""Execute the pinned Nagomi graph without any game-engine dependency."""

import hashlib
import json
from pathlib import Path

import numpy as np
import onnxruntime as ort


class NagomiRuntime:
    def __init__(self, path):
        spec = json.loads(Path(__file__).with_name('model.json').read_text())
        digest = hashlib.sha256()
        with Path(path).open('rb') as source:
            for block in iter(lambda: source.read(1024 * 1024), b''):
                digest.update(block)
        if digest.hexdigest() != spec['sha256']:
            raise ValueError('model does not match the frozen Nagomi artifact')
        options = ort.SessionOptions()
        options.intra_op_num_threads = 1
        options.inter_op_num_threads = 1
        self.session = ort.InferenceSession(str(path), options, providers=['CPUExecutionProvider'])
        inputs = self.session.get_inputs()
        outputs = self.session.get_outputs()
        if ([(value.name, value.type, value.shape[1:]) for value in inputs]
                != [('obs', 'tensor(float)', [1012, 34]), ('mask', 'tensor(bool)', [46])]
                or len(outputs) != 1 or outputs[0].name != 'q' or outputs[0].shape[1:] != [46]):
            raise ValueError('unsupported Nagomi tensor contract')

    def score(self, obs, mask):
        """Score complete externally encoded tensors; this does not encode mjai."""
        if (not isinstance(obs, np.ndarray) or obs.dtype != np.float32
                or obs.ndim != 3 or obs.shape[1:] != (1012, 34)
                or not 1 <= obs.shape[0] <= 256 or not np.isfinite(obs).all()):
            raise ValueError('expected finite float32 [1..256,1012,34] observations')
        if (not isinstance(mask, np.ndarray) or mask.dtype != np.bool_
                or mask.shape != (len(obs), 46) or not mask.any(-1).all()):
            raise ValueError('expected nonempty boolean action masks [batch,46]')
        q = self.session.run(['q'], {'obs': obs, 'mask': mask})[0]
        if q.shape != mask.shape or not np.isfinite(q[mask]).all() or not np.isneginf(q[~mask]).all():
            raise ValueError('invalid model action values')
        return q
