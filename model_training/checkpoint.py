"""Explicit checkpoint contracts; no automatic reuse of an existing run."""

import random

import numpy as np
import torch


def save_checkpoint(path, model, optimizer, steps, provenance, trainer_state=None):
    numpy_rng = np.random.get_state(legacy=False)
    numpy_rng['state']['key'] = numpy_rng['state']['key'].tolist()
    state = {
        'format_version': 1, 'config': model.config.to_dict(),
        'model': model.state_dict(), 'optimizer': optimizer.state_dict(), 'steps': steps,
        'provenance': provenance, 'torch_rng': torch.get_rng_state(),
        'python_rng': random.getstate(),
        'numpy_rng': numpy_rng,
        'trainer_state': trainer_state,
    }
    if torch.backends.mps.is_available():
        state['mps_rng'] = torch.mps.get_rng_state()
    # Exclusive creation protects earlier checkpoints and baselines.
    with path.open('xb') as output:
        torch.save(state, output)


def load_checkpoint(path, model, optimizer=None, restore_rng=False, expected_provenance=None):
    state = torch.load(path, weights_only=True, map_location='cpu')
    if state.get('format_version') != 1 or state.get('config') != model.config.to_dict():
        raise ValueError('checkpoint model/encoder/action/ruleset contract mismatch')
    if expected_provenance is not None and state.get('provenance') != expected_provenance:
        raise ValueError('checkpoint training/data/source contract mismatch')
    model.load_state_dict(state['model'])
    if optimizer is not None:
        optimizer.load_state_dict(state['optimizer'])
    if restore_rng:
        torch.set_rng_state(state['torch_rng'])
        random.setstate(state['python_rng'])
        np.random.set_state(state['numpy_rng'])
        if 'mps_rng' in state:
            if not torch.backends.mps.is_available():
                raise ValueError('MPS RNG resume requires MPS')
            torch.mps.set_rng_state(state['mps_rng'])
    return state
