import unittest

import numpy as np

from nagomi_compat.efficiency import analyze, improving_tiles
from nagomi_compat.observation import IncompleteObservationError, encode
from nagomi_compat.state import tile_index
from nagomi_compat.tests.test_hand_legality import counts, start


TENPAI = '1p 2p 3p 4p 5p 6p 7p 8p 9p E E E N'


class EfficiencyTests(unittest.TestCase):
    def test_structural_improvements_and_visible_inventory_are_separate(self):
        self.assertEqual(improving_tiles(counts(TENPAI)), (30,))
        state = start(TENPAI)
        for actor in (1, 2, 3):
            state.apply({'type': 'tsumo', 'actor': actor, 'pai': '?'})
            state.apply({'type': 'dahai', 'actor': actor, 'pai': 'N', 'tsumogiri': True})
        self.assertEqual(analyze(state).required, ())

    def test_horizon_accounts_for_position_in_draw_order(self):
        for actor, offset in ((3, 1), (2, 2), (1, 3)):
            with self.subTest(actor=actor):
                state = start(TENPAI)
                state.apply({'type': 'dahai', 'actor': actor, 'pai': '1m', 'tsumogiri': True})
                state.draws = 70 - (4 + offset)
                self.assertEqual(analyze(state).horizon, 1)
                self.assertEqual(analyze(state).required, (30,))
                state.draws += 1
                self.assertEqual(analyze(state).horizon, 0)
                self.assertEqual(analyze(state).required, ())

        state = start(TENPAI)
        state.apply({'type': 'tsumo', 'actor': 0, 'pai': '1s'})
        state.draws = 66
        self.assertEqual(analyze(state).horizon, 1)
        self.assertIsNotNone(analyze(state).best_discard)
        state.draws = 67
        self.assertEqual(analyze(state).discards, ())

    def test_complete_self_draw_has_no_future_discard_features(self):
        state = start(TENPAI)
        state.apply({'type': 'tsumo', 'actor': 0, 'pai': 'N'})
        analysis = analyze(state)
        self.assertEqual(analysis.discards, ())
        self.assertIsNone(analysis.best_discard)
        self.assertFalse(encode(state).values[891:961].any())

    def test_accepted_riichi_only_analyzes_drawn_tile(self):
        state = start(TENPAI)
        state.apply({'type': 'tsumo', 'actor': 0, 'pai': '1s'})
        state.apply({'type': 'reach', 'actor': 0})
        state.apply({'type': 'dahai', 'actor': 0, 'pai': '1s', 'tsumogiri': True})
        state.apply({'type': 'reach_accepted', 'actor': 0})
        state.apply({'type': 'tsumo', 'actor': 0, 'pai': '2s'})
        analysis = analyze(state)
        self.assertEqual([option.tile for option in analysis.discards], [19])
        self.assertEqual(analysis.best_discard, 19)

    def test_tie_break_preserves_red_five(self):
        state = start('8m 5s E 5p 7p 8p E 7p 2s 4s 7m 1s 5mr', seat=3)
        state.apply({'type': 'tsumo', 'actor': 3, 'pai': '9m'})
        analysis = analyze(state)
        by_tile = {option.tile: option for option in analysis.discards}
        self.assertEqual(by_tile[4].live_copies, by_tile[13].live_copies)
        self.assertEqual(analysis.best_discard, 13)

    def test_high_distance_fallback_retains_worsening_discard_tier(self):
        state = start('C 7p 3s 2p C 3s P 2s 1p F 3p 9m 6m')
        state.apply({'type': 'tsumo', 'actor': 0, 'pai': 'S'})
        analysis = analyze(state)
        self.assertEqual(analysis.minimum_shanten, 4)
        dragon = next(option for option in analysis.discards if option.tile == 33)
        self.assertEqual(dragon.shanten, 5)
        observation = encode(state)
        self.assertTrue(observation.values[925 + 33].any())
        self.assertFalse(observation.values[891 + 33].any())
        self.assertEqual(analysis.best_discard, tile_index('S'))

    def test_added_rows_do_not_make_incomplete_observation_scoreable(self):
        state = start(TENPAI)
        state.apply({'type': 'tsumo', 'actor': 0, 'pai': '1s'})
        observation = encode(state)
        self.assertEqual(int(observation.known_rows.sum()), 959)
        self.assertTrue(np.isfinite(observation.values[observation.known_rows]).all())
        np.testing.assert_array_equal(np.flatnonzero(~observation.known_rows),
                                      [889, 890, *range(961, 1012)])
        self.assertTrue(np.isnan(observation.values[~observation.known_rows]).all())
        with self.assertRaises(IncompleteObservationError):
            observation.require_complete()

    def test_efficiency_rejects_wrong_hand_size_and_failed_state(self):
        with self.assertRaises(ValueError):
            improving_tiles(counts(TENPAI + ' 1s'))
        state = start(TENPAI)
        with self.assertRaises(ValueError):
            state.apply({'type': 'tsumo', 'actor': 0, 'pai': '?'})
        with self.assertRaises(ValueError):
            analyze(state)


if __name__ == '__main__':
    unittest.main()
