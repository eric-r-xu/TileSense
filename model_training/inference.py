"""Local ONNX/mjai adapter using the same visible encoder as training replay.

This is an integration check, not a production HTTP service or model release.
The existing rules engine retains action decoding and the agari guard.
"""

import json

import numpy as np
import onnxruntime as ort

from .encoding import VisibleEncoder
from .model import INPUT_NAMES


class LocalOnnxEngine:
    engine_type = 'mortal'  # libriichi's internal callback protocol
    is_oracle = False
    enable_quick_eval = False
    enable_rule_based_agari_guard = True
    name = 'tilesense-visible-v1-local'

    def __init__(self, config, path, seat, game_length=None):
        if config.observation_schema_id != 'tilesense-visible-v1':
            raise ValueError('local adapter requires the real observation schema')
        self.config = config
        self.encoder = VisibleEncoder(config.ruleset, seat, game_length)
        self.version = self.encoder.engine.consts.MAX_VERSION
        options = ort.SessionOptions()
        options.intra_op_num_threads = 1
        options.inter_op_num_threads = 1
        self.session = ort.InferenceSession(str(path), options, providers=['CPUExecutionProvider'])
        inputs = self.session.get_inputs()
        shapes = ((34, 20), (40,), (128, 4), (128,), (config.actions,))
        types = ('tensor(float)', 'tensor(float)', 'tensor(int64)', 'tensor(bool)', 'tensor(bool)')
        if (tuple(value.name for value in inputs) != INPUT_NAMES
                or any(tuple(value.shape[1:]) != shape or value.type != dtype
                       for value, shape, dtype in zip(inputs, shapes, types))):
            raise ValueError('ONNX observation schema mismatch')
        outputs = self.session.get_outputs()
        if (tuple(value.name for value in outputs) != ('q', 'rank')
                or outputs[0].shape[1:] != [config.actions]
                or outputs[1].shape[1:] != [config.players]):
            raise ValueError('ONNX output/action schema mismatch')
        self.calls = 0

    def react_batch(self, obs, masks, invisible_obs):
        # The legacy features arrive as part of the engine callback protocol.
        # Recompute our observations from visible state, retaining engine masks.
        normal = self.encoder.snapshot()
        choices = [normal]
        if self.encoder.state.last_cans.can_kan:
            choices.append(self.encoder.snapshot(at_kan_select=True))
        rows = []
        for mask in masks:
            matches = [inputs for inputs in choices if np.array_equal(inputs[-1], mask)]
            if len(matches) != 1:
                raise ValueError('training/inference rules-engine masks disagree')
            rows.append(matches[0])
        batch = {name: np.stack([row[column] for row in rows]) for column, name in enumerate(INPUT_NAMES)}
        q = self.session.run(['q'], batch)[0]
        mask_array = batch['action_mask']
        if not np.isfinite(q[mask_array]).all() or not np.isneginf(q[~mask_array]).all():
            raise ValueError('invalid ONNX action values')
        self.calls += len(rows)
        return q.argmax(-1).tolist(), q.tolist(), mask_array.tolist(), [True] * len(rows)


def react_local(config, path, seat, events, game_length=None):
    if not isinstance(events, list) or not 1 <= len(events) <= 20000:
        raise ValueError('expected a bounded nonempty event list')
    engine = LocalOnnxEngine(config, path, seat, game_length)
    from libriichi.mjai import Bot

    bot = Bot(engine, seat, game_length=engine.encoder.game_length)

    def apply(event, can_act):
        clean = engine.encoder.update(event)
        reply = bot.react(json.dumps(clean, allow_nan=False), can_act=can_act)
        return None if reply is None else json.loads(reply)

    reaction = None
    for index, event in enumerate(events):
        reaction = apply(event, index == len(events) - 1)
    riichi_discard = None
    if reaction and reaction['type'] == 'reach':
        riichi_discard = apply({'type': 'reach', 'actor': seat}, True)
    return {'reaction': reaction, 'riichi_discard': riichi_discard, 'network_decisions': engine.calls}
