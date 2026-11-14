import copy
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import numpy as np

from nagomi_compat.actions import decode
from nagomi_compat.observation import IncompleteObservationError, encode
from nagomi_compat.runtime import NagomiRuntime
from nagomi_compat.state import VisibleState, bonus_tile, redact


ROOT = Path(__file__).resolve().parents[2]
MODEL = ROOT / 'mortal_sidecar/mortal_nagomi.onnx'


def initial():
    return {'type': 'start_kyoku', 'bakaze': 'E', 'dora_marker': '1m', 'kyoku': 1,
            'honba': 0, 'kyotaku': 0, 'oya': 0, 'scores': [25000] * 4,
            'tehais': [['1p', '2p', '4p', '5pr', '7p', '8p', '1s', '3s', '5s', '7s', 'E', 'E', 'N']]
                      + [['?'] * 13 for _ in range(3)]}


class IndependentStateTests(unittest.TestCase):
    def test_unknown_planes_are_not_usable_as_complete_inputs(self):
        state = VisibleState(0)
        state.apply(initial())
        state.apply({'type': 'tsumo', 'actor': 0, 'pai': 'C'})
        frame = encode(state)
        self.assertEqual(frame.known_rows.sum(), 959)
        self.assertTrue(np.isnan(frame.values[~frame.known_rows]).all())
        with self.assertRaises(IncompleteObservationError):
            frame.require_complete()

    def test_hidden_values_and_metadata_cannot_affect_reconstructed_features(self):
        states = []
        original = initial()
        for secret in ('1m', '9m'):
            start = copy.deepcopy(original)
            start['tehais'][1] = [secret] * 13
            start['meta'] = {'future': secret}
            state = VisibleState(0)
            state.apply(start)
            state.apply({'type': 'tsumo', 'actor': 1, 'pai': secret})
            state.apply({'type': 'dahai', 'actor': 1, 'pai': '8m', 'tsumogiri': True})
            state.apply({'type': 'tsumo', 'actor': 0, 'pai': 'C'})
            states.append(encode(state))
        np.testing.assert_array_equal(states[0].values, states[1].values)
        self.assertEqual(original, initial())

    def test_rejected_event_poisons_replay_until_recreated(self):
        state = VisibleState(0)
        state.apply(initial())
        with self.assertRaises(ValueError):
            state.apply({'type': 'dahai', 'actor': 0, 'pai': '9s', 'tsumogiri': True})
        with self.assertRaises(ValueError):
            encode(state)
        with self.assertRaises(ValueError):
            state.apply({'type': 'tsumo', 'actor': 0, 'pai': 'C'})

    def test_call_updates_river_alignment_but_cannot_complete_probability_planes(self):
        state = VisibleState(0)
        state.apply(initial())
        state.apply({'type': 'tsumo', 'actor': 1, 'pai': '?'})
        state.apply({'type': 'dahai', 'actor': 1, 'pai': 'E', 'tsumogiri': True})
        state.apply({'type': 'pon', 'actor': 0, 'target': 1, 'pai': 'E', 'consumed': ['E', 'E']})
        frame = encode(state)
        self.assertEqual(frame.known_rows.sum(), 959)
        self.assertEqual(state.hand.count('E'), 0)
        with self.assertRaises(IncompleteObservationError):
            frame.require_complete()

    def test_red_identity_is_preserved_and_payments_update_relative_scores(self):
        state = VisibleState(0)
        state.apply(initial())
        state.apply({'type': 'reach', 'actor': 1})
        state.apply({'type': 'reach_accepted', 'actor': 1})
        frame = encode(state)
        self.assertTrue((frame.values[5] == 1).all())
        self.assertAlmostEqual(float(frame.values[9, 0]), 0.24)
        self.assertAlmostEqual(float(frame.values[24, 0]), 0.1)

    def test_malformed_public_inputs_rejected_before_state_tracking(self):
        for event in ({'type': []}, {'type': 'reach', 'actor': True},
                      {'type': 'tsumo', 'actor': 0, 'pai': '?'},
                      {'type': 'nukidora', 'actor': 0, 'pai': 'N'}):
            with self.assertRaises(ValueError):
                redact(event, 0)

    def test_dora_cycles_wrap_suits_winds_and_dragons(self):
        self.assertEqual(bonus_tile('9m'), 0)
        self.assertEqual(bonus_tile('N'), 27)
        self.assertEqual(bonus_tile('C'), 31)
        self.assertEqual(bonus_tile('5pr'), 14)

    def test_relative_turn_alignment_and_reverse_river_windows(self):
        start = initial()
        hand = start['tehais'][0]
        start['tehais'] = [['?'] * 13 for _ in range(3)] + [hand]
        start['oya'] = 2
        state = VisibleState(3)
        state.apply(start)
        events = [
            {'type': 'tsumo', 'actor': 2, 'pai': '?'},
            {'type': 'dahai', 'actor': 2, 'pai': 'W', 'tsumogiri': True},
            {'type': 'tsumo', 'actor': 3, 'pai': 'C'},
            {'type': 'dahai', 'actor': 3, 'pai': 'C', 'tsumogiri': True},
            {'type': 'tsumo', 'actor': 0, 'pai': '?'},
            {'type': 'dahai', 'actor': 0, 'pai': 'N', 'tsumogiri': False},
            {'type': 'tsumo', 'actor': 1, 'pai': '?'},
            {'type': 'dahai', 'actor': 1, 'pai': 'P', 'tsumogiri': True},
            {'type': 'tsumo', 'actor': 2, 'pai': '?'},
            {'type': 'dahai', 'actor': 2, 'pai': 'F', 'tsumogiri': True},
            {'type': 'tsumo', 'actor': 3, 'pai': 'S'},
        ]
        for event in events:
            state.apply(event)
        frame = encode(state).values
        self.assertTrue((frame[35:39] == 0).all())  # Self's initial skipped slot.
        self.assertEqual(frame[40, 33], 1)  # First self discard, chronological window.
        self.assertEqual(frame[60, 33], 1)  # Same tile, newest-first window.
        self.assertEqual(frame[573, 32], 1)  # Dealer's newest discard is green dragon.
        self.assertEqual(frame[581, 29], 1)  # Previous discard is West.
        self.assertEqual(frame[714, 32], 1)
        self.assertEqual(frame[714, 29], np.float32(0.8187307715415955))

    def test_interrupted_turns_get_empty_slots_and_call_metadata(self):
        state = VisibleState(0)
        state.apply(initial())
        for event in [
            {'type': 'tsumo', 'actor': 0, 'pai': 'C'},
            {'type': 'dahai', 'actor': 0, 'pai': 'C', 'tsumogiri': True},
            {'type': 'pon', 'actor': 2, 'target': 0, 'pai': 'C', 'consumed': ['C', 'C']},
            {'type': 'dahai', 'actor': 2, 'pai': '8s', 'tsumogiri': False},
        ]:
            state.apply(event)
        frame = encode(state).values
        self.assertTrue((frame[132:140] == 0).all())  # Seat 1 lost its turn.
        self.assertEqual(frame[327, 33], 1)
        self.assertEqual(frame[328, 33], 1)
        self.assertEqual(frame[330, 25], 1)


class IndependentDecoderTests(unittest.TestCase):
    def test_red_chi_consumption_and_discard_identity(self):
        state = VisibleState(0)
        state.apply(initial())
        state.apply({'type': 'tsumo', 'actor': 3, 'pai': '?'})
        state.apply({'type': 'dahai', 'actor': 3, 'pai': '3p', 'tsumogiri': True})
        self.assertEqual(decode(38, state), {'type': 'chi', 'actor': 0, 'target': 3,
                                            'pai': '3p', 'consumed': ['4p', '5pr']})
        state.apply({'type': 'tsumo', 'actor': 0, 'pai': 'C'})
        self.assertEqual(decode(33, state)['tsumogiri'], True)
        self.assertEqual(decode(35, state)['pai'], '5pr')

    def test_closed_kan_preserves_red_tile_and_requires_selection_if_ambiguous(self):
        state = VisibleState(0)
        start = initial()
        start['tehais'][0] = ['5p', '5p', '5pr', '1p', '1p', '1p', 'E', 'E', 'N', 'N', '3s', '4s', '5s']
        state.apply(start)
        state.apply({'type': 'tsumo', 'actor': 0, 'pai': '5p'})
        result = decode(42, state)
        self.assertEqual(result['type'], 'ankan')
        self.assertEqual(sorted(result['consumed']), ['5p', '5p', '5p', '5pr'])
        state = VisibleState(0)
        start['tehais'][0] = ['1p'] * 3 + ['5p'] * 3 + ['5pr', 'E', 'E', 'N', 'N', '3s', '4s']
        state.apply(start)
        state.apply({'type': 'tsumo', 'actor': 0, 'pai': '1p'})
        with self.assertRaisesRegex(ValueError, 'selection is required'):
            decode(42, state)
        self.assertEqual(sorted(decode(42, state, kan_tile=13)['consumed']), ['5p', '5p', '5p', '5pr'])

    def test_honors_cannot_be_used_for_chi(self):
        state = VisibleState(0)
        state.apply(initial())
        state.apply({'type': 'tsumo', 'actor': 3, 'pai': '?'})
        state.apply({'type': 'dahai', 'actor': 3, 'pai': 'N', 'tsumogiri': True})
        with self.assertRaises(ValueError):
            decode(38, state)


@unittest.skipUnless(MODEL.exists(), 'requires the frozen local ONNX artifact')
class RuntimeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.runtime = NagomiRuntime(MODEL)

    def test_bad_masks_nonfinite_or_wrong_dtype_inputs_rejected(self):
        obs = np.zeros((1, 1012, 34), dtype=np.float32)
        mask = np.ones((1, 46), dtype=np.bool_)
        for value, masks in ((obs.astype(np.float64), mask), (obs, np.zeros_like(mask))):
            with self.assertRaises(ValueError):
                self.runtime.score(value, masks)
        obs[0, 0, 0] = np.nan
        with self.assertRaises(ValueError):
            self.runtime.score(obs, mask)

    def test_unknown_partial_frame_cannot_bypass_readiness_guard(self):
        state = VisibleState(0)
        state.apply(initial())
        with self.assertRaises(ValueError):
            self.runtime.score(encode(state).values[None], np.ones((1, 46), dtype=np.bool_))

    def test_mismatched_weights_rejected_before_session_creation(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'wrong.onnx'
            path.write_bytes(b'not the frozen model')
            with self.assertRaisesRegex(ValueError, 'frozen Nagomi'):
                NagomiRuntime(path)

    def test_runtime_executes_with_all_reference_imports_blocked(self):
        code = '''
import importlib.abc, sys
class BlockReference(importlib.abc.MetaPathFinder):
    def find_spec(self, fullname, path=None, target=None):
        if fullname.split('.')[0] in ('libriichi', 'riichi', 'model_training', 'mortal_sidecar'):
            raise AssertionError('reference dependency: ' + fullname)
sys.meta_path.insert(0, BlockReference())
import numpy as np
from nagomi_compat.runtime import NagomiRuntime
from nagomi_compat.scoring import score_hand, WinContext
counts = [0] * 34
for tile in (0, 1, 2, 3, 4, 5, 15, 16, 17, 19, 20, 21, 13, 13):
    counts[tile] += 1
assert score_hand(counts, 21, context=WinContext(seat_wind=28)).total_points == 1000
model = NagomiRuntime(sys.argv[1])
q = model.score(np.zeros((1,1012,34), dtype=np.float32), np.ones((1,46), dtype=np.bool_))
assert q.shape == (1,46) and np.isfinite(q).all()
'''
        subprocess.run([sys.executable, '-c', code, str(MODEL)], check=True, cwd=ROOT,
                       capture_output=True, text=True)


if __name__ == '__main__':
    unittest.main()
