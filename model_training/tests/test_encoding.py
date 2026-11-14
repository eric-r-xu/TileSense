import copy
import gzip
import os
from pathlib import Path
import tempfile
import unittest

import numpy as np

from model_training.audit import ROOT
from model_training.data import read_game, replay_samples
from model_training.encoding import VisibleEncoder, encode_prefix, validate_inputs, visible_event
from model_training.model import ModelConfig


RULESET = os.environ.get('TILESENSE_TEST_RULESET', 'nagomi')
PLAYERS = 3 if RULESET == 'sanma' else 4
BINARY = ROOT / 'mortal_sidecar' / ('sanma' if RULESET == 'sanma' else '') / 'libriichi.so'


def start(hand=None):
    hand = hand or ['1p', '2p', '3p', '4p', '5pr', '6p', '7p', '8p', '9p', 'E', 'E', 'N', 'N']
    return {'type': 'start_kyoku', 'bakaze': 'E', 'dora_marker': '9s', 'kyoku': 1,
            'honba': 0, 'kyotaku': 0, 'oya': 0, 'scores': [35000] * PLAYERS,
            'tehais': [hand] + [['?'] * 13 for _ in range(PLAYERS - 1)]}


class BoundaryTests(unittest.TestCase):
    def test_private_fields_are_removed_without_mutating_input(self):
        event = start()
        event['tehais'][1] = ['unavailable private value'] * 13
        event['future'] = {'outcome': 123}
        original = copy.deepcopy(event)
        clean = visible_event(event, 0, PLAYERS)
        self.assertEqual(event, original)
        self.assertEqual(clean['tehais'][1], ['?'] * 13)
        self.assertNotIn('future', clean)
        self.assertEqual(visible_event({'type': 'tsumo', 'actor': 1, 'pai': 'secret'}, 0, PLAYERS)['pai'], '?')

    def test_malformed_public_fields_rejected(self):
        for event in ({'type': 'reach', 'actor': PLAYERS},
                      {'type': 'reach', 'actor': True},
                      {'type': 'dahai', 'actor': 0, 'pai': '1p', 'tsumogiri': 1},
                      {'type': 'tsumo', 'actor': 0, 'pai': '?'},
                      {'type': 'pon', 'actor': 0, 'target': 1, 'pai': 'E', 'consumed': []},
                      {'type': 'unrecognized'}):
            with self.subTest(event=event), self.assertRaises(ValueError):
                visible_event(event, 0, PLAYERS)

    def test_real_schema_rejects_prototype_dimensions(self):
        with self.assertRaisesRegex(ValueError, 'visible-v1'):
            ModelConfig(RULESET, observation_schema_id='tilesense-visible-v1')

    def test_sanma_rejects_removed_tiles_and_chi_before_engine_update(self):
        for event in ({'type': 'tsumo', 'actor': 0, 'pai': '5mr'},
                      {'type': 'dahai', 'actor': 1, 'pai': '2m', 'tsumogiri': False},
                      {'type': 'chi', 'actor': 0, 'target': 1, 'pai': '1p', 'consumed': ['2p', '3p']}):
            with self.assertRaises(ValueError):
                visible_event(event, 0, 3)

    def test_oversized_log_rejected_before_json_parsing(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'oversize.json.gz'
            with gzip.open(path, 'wt') as output:
                output.write('x' * 65537)
            with self.assertRaisesRegex(ValueError, 'limits'):
                read_game(path)


@unittest.skipUnless(BINARY.exists(), 'needs the existing pinned rules-engine build')
class EngineEncodingTests(unittest.TestCase):
    def encoder(self, hand=None):
        encoder = VisibleEncoder(RULESET, 0)
        encoder.update(start(hand))
        return encoder

    def assert_inputs_equal(self, a, b):
        for expected, actual in zip(a, b):
            np.testing.assert_array_equal(actual, expected)

    def test_hidden_hand_and_draw_changes_cannot_change_observation(self):
        first = start()
        second = copy.deepcopy(first)
        first['tehais'][1] = ['1m'] * 13
        second['tehais'][1] = ['9m'] * 13
        tail = [{'type': 'dahai', 'actor': 1, 'pai': '7s', 'tsumogiri': True},
                {'type': 'tsumo', 'actor': 0, 'pai': '1s'}]
        prefix_a = [first, {'type': 'tsumo', 'actor': 1, 'pai': '1m'}, *tail]
        prefix_b = [second, {'type': 'tsumo', 'actor': 1, 'pai': '9m'}, *tail]
        self.assert_inputs_equal(encode_prefix(RULESET, 0, prefix_a), encode_prefix(RULESET, 0, prefix_b))

    def test_red_five_visible_count_and_invalid_tensor_boundaries(self):
        encoder = self.encoder()
        encoder.update({'type': 'tsumo', 'actor': 0, 'pai': '1s'})
        inputs = encoder.snapshot()
        self.assertEqual(inputs[0][13, 1], 1)
        self.assertEqual(inputs[0][13, 14], 1)
        altered = list(copy.deepcopy(inputs))
        altered[-1][:] = False
        with self.assertRaises(ValueError):
            validate_inputs(altered, PLAYERS)
        altered = list(copy.deepcopy(inputs))
        altered[2][0, 0] = 16
        with self.assertRaises(ValueError):
            validate_inputs(altered, PLAYERS)
        altered = list(copy.deepcopy(inputs))
        altered[0][0, 0] = np.nan
        with self.assertRaises(ValueError):
            validate_inputs(altered, PLAYERS)

    def test_rotating_absolute_seats_preserves_relative_features(self):
        events = [start(), {'type': 'tsumo', 'actor': 0, 'pai': '1s'}]
        events[0]['scores'] = [35000 + seat * 100 for seat in range(PLAYERS)]
        events[0]['oya'] = 1
        rotated = copy.deepcopy(events)
        initial = rotated[0]
        initial['tehais'] = initial['tehais'][-1:] + initial['tehais'][:-1]
        initial['scores'] = initial['scores'][-1:] + initial['scores'][:-1]
        initial['oya'] = (initial['oya'] + 1) % PLAYERS
        rotated[1]['actor'] = 1
        self.assert_inputs_equal(encode_prefix(RULESET, 0, events), encode_prefix(RULESET, 1, rotated))

    def test_riichi_followup_keeps_discard_and_context(self):
        hand = ['1p', '2p', '3p', '4p', '5p', '6p', '7p', '8p', '9p', 'E', 'E', 'E', 'N']
        encoder = self.encoder(hand)
        encoder.update({'type': 'tsumo', 'actor': 0, 'pai': '1s'})
        self.assertTrue(encoder.snapshot()[-1][37])
        encoder.update({'type': 'reach', 'actor': 0})
        self.assertTrue(encoder.snapshot()[-1][18])
        encoder.update({'type': 'dahai', 'actor': 0, 'pai': '1s', 'tsumogiri': True})
        encoder.update({'type': 'reach_accepted', 'actor': 0})
        encoder.update({'type': 'tsumo', 'actor': 0, 'pai': '2s'})
        context = encoder.snapshot()[1]
        self.assertAlmostEqual(context[0], 0.34)
        self.assertAlmostEqual(context[14], 0.1)
        self.assertEqual(context[24], 1)
        self.assertEqual(context[28], 1)

    def test_kan_selection_has_separate_mask_and_phase(self):
        hand = ['1p'] * 3 + ['2p', '3p', '4p', '5p', '6p', '7p', 'E', 'E', 'N', 'N']
        encoder = self.encoder(hand)
        encoder.update({'type': 'tsumo', 'actor': 0, 'pai': '1p'})
        self.assertTrue(encoder.snapshot()[-1][42])
        selected = encoder.snapshot(at_kan_select=True)
        self.assertEqual(selected[1][19], 1)
        self.assertTrue(selected[-1][9])
        self.assertEqual(selected[-1].sum(), 1)

    def test_game_length_is_part_of_the_input(self):
        events = [start(), {'type': 'tsumo', 'actor': 0, 'pai': '1s'}]
        short = encode_prefix(RULESET, 0, events, PLAYERS)
        long = encode_prefix(RULESET, 0, events, PLAYERS * 2)
        self.assertEqual(short[1][16] * 2, long[1][16])

    @unittest.skipUnless(RULESET == 'sanma', 'sanma only')
    def test_kita_updates_counts_and_removed_tiles(self):
        encoder = self.encoder()
        encoder.update({'type': 'tsumo', 'actor': 0, 'pai': '1s'})
        self.assertTrue(encoder.snapshot()[-1][46])
        encoder.update({'type': 'nukidora', 'actor': 0, 'pai': 'N'})
        encoder.update({'type': 'tsumo', 'actor': 0, 'pai': '2s'})
        tiles, context, *_ = encoder.snapshot()
        self.assertEqual(context[20], 0.25)
        self.assertTrue((tiles[1:8, 5] == 0).all())
        self.assertEqual(tiles[30, 2], 0.5)

    def test_real_replay_and_stateless_inference_have_identical_inputs(self):
        name, variant = ('mortal-sanma-data', 'sanma-hanchan') if RULESET == 'sanma' else ('mortal-4p-data', 'hanchan')
        files = sorted((Path.home() / 'Documents' / name / 'mjai' / variant / 'train').glob('*.json.gz'))
        if not files:
            self.skipTest('needs local game data')
        events = read_game(files[0])
        stats = {}
        rows, _ = replay_samples(RULESET, events, include_outcomes=True,
                                 verify_reference=True, stats=stats)
        self.assertGreater(len(rows), 10)
        self.assertEqual(stats['reference']['compared'], len(rows))
        self.assertEqual(stats['reference']['label_mismatches'], 0)
        self.assertEqual(stats['reference']['mask_mismatches'], 0)
        self.assertGreater(stats['labels'].get('45', 0), 0)
        self.assertEqual(sorted({row['final_rank'] for row in rows}), list(range(PLAYERS)))
        for row in rows:
            self.assertTrue((row['inputs'][0][:, 2] <= 1).all(), 'a visible tile was counted more than four times')
        for row in rows[::max(1, len(rows) // 5)]:
            actual = encode_prefix(RULESET, row['seat'], events[:row['event_index'] + 1],
                                   at_kan_select=row['kan_select'])
            self.assert_inputs_equal(row['inputs'], actual)


@unittest.skipUnless(BINARY.exists(), 'needs the existing pinned rules-engine build')
class LocalIntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        import torch
        from model_training.model import build_model
        from model_training.smoke import export_and_verify

        torch.set_num_threads(1)
        cls.folder = tempfile.TemporaryDirectory()
        cls.path = Path(cls.folder.name)
        cls.config = ModelConfig(RULESET, observation_schema_id='tilesense-visible-v1',
                                 tile_features=20, context_features=40, width=32, layers=1)
        model = build_model(cls.config).eval()
        with torch.no_grad():
            model.advantage.weight.zero_()
            model.advantage.bias.zero_()
            model.advantage.bias[37] = 1000
            model.advantage.bias[42] = 1100
            if RULESET == 'sanma':
                model.advantage.bias[46] = 500
        export_and_verify(model, cls.path)

    @classmethod
    def tearDownClass(cls):
        cls.folder.cleanup()

    def test_riichi_is_decoded_with_a_legal_followup_discard(self):
        from model_training.inference import react_local

        hand = ['1p', '2p', '3p', '4p', '5p', '6p', '7p', '8p', '9p', 'E', 'E', 'E', 'N']
        events = [start(hand), {'type': 'tsumo', 'actor': 0, 'pai': '1s'}]
        result = react_local(self.config, self.path / 'prototype.onnx', 0, events)
        self.assertEqual(result['reaction']['type'], 'reach')
        self.assertEqual(result['riichi_discard']['type'], 'dahai')
        encoder = VisibleEncoder(RULESET, 0)
        for event in [*events, {'type': 'reach', 'actor': 0}]:
            encoder.update(event)
        import json
        encoder.state.validate_reaction(json.dumps(result['riichi_discard']))

    def test_kan_selection_is_decoded_from_the_custom_network(self):
        from model_training.inference import react_local

        hand = ['1p'] * 3 + ['2p', '3p', '4p', '5p', '6p', '7p', 'E', 'E', 'N', 'N']
        events = [start(hand), {'type': 'tsumo', 'actor': 0, 'pai': '1p'}]
        result = react_local(self.config, self.path / 'prototype.onnx', 0, events)
        self.assertEqual(result['reaction']['type'], 'ankan')
        self.assertEqual(result['reaction']['consumed'], ['1p'] * 4)
        self.assertEqual(result['network_decisions'], 2)

    def test_legacy_export_cannot_be_loaded_as_custom_observations(self):
        from model_training.inference import LocalOnnxEngine

        name = 'mortal_sanma.onnx' if RULESET == 'sanma' else 'mortal_nagomi.onnx'
        path = ROOT / 'mortal_sidecar' / name
        if not path.exists():
            self.skipTest('needs baseline export')
        with self.assertRaisesRegex(ValueError, 'schema mismatch'):
            LocalOnnxEngine(self.config, path, 0)


if __name__ == '__main__':
    unittest.main()
