import unittest

from nagomi_compat.scoring import Meld, WinContext, score_hand, score_win
from nagomi_compat.state import tile_index
from nagomi_compat.tests.test_hand_legality import counts, start


PINFU = '1m 2m 3m 4m 5m 6m 7p 8p 9p 2s 3s 4s 5p 5p'


def score(hand, winner, *, melds=(), bonus=0, **context):
    return score_hand(counts(hand), tile_index(winner), melds,
                      WinContext(seat_wind=context.pop('seat_wind', 28), **context), bonus)


class ScoringTests(unittest.TestCase):
    def test_pinfu_ron_and_self_draw_use_different_fu(self):
        ron = score(PINFU, '4s')
        tsumo = score(PINFU, '4s', tsumo=True)
        self.assertEqual((ron.han, ron.fu, ron.total_points), (1, 30, 1000))
        self.assertEqual((tsumo.han, tsumo.fu, tsumo.payments), (2, 20, (400, 400, 700)))

    def test_edge_wait_cannot_claim_pinfu(self):
        result = score(PINFU, '3m', tsumo=True)
        self.assertEqual((result.han, result.fu, result.total_points), (1, 30, 1100))
        self.assertNotIn('pinfu', dict(result.yaku))

    def test_bonus_tiles_do_not_supply_a_yaku(self):
        self.assertIsNone(score(PINFU, '3m', bonus=20))

    def test_open_hand_minimum_ron_fu(self):
        result = score('4p 5p 6p 6p 7p 8p 3s 4s 5s 2p 2p', '5s', melds=(Meld('chi', 1),))
        self.assertEqual((result.han, result.fu, result.total_points), (1, 30, 1000))

    def test_ron_triplet_is_open_for_fu_and_concealed_triplet_yaku(self):
        hand = '5p 5p 5p 4s 5s 6s E E E N N'
        melds = (Meld('chi', 1),)
        ron = score(hand, 'E', melds=melds)
        tsumo = score(hand, 'E', melds=melds, tsumo=True)
        self.assertEqual((ron.fu, tsumo.fu), (30, 40))
        hand = '3m 3m 3m 4p 4p 4p 6s 6s 6s 2p 3p 4p E E'
        self.assertIsNone(score(hand, '3m'))
        self.assertIn('three_concealed_triplets', dict(score(hand, '3m', tsumo=True).yaku))

    def test_double_wind_pair_is_additive_in_pinned_rules(self):
        hand = '3m 3m 3m 4p 4p 4p 2s 3s 4s 6s 7s 8s E E'
        single = score(hand, '4s', riichi=1)
        double = score(hand, '4s', riichi=1, seat_wind=27)
        self.assertEqual((single.fu, double.fu), (40, 50))

    def test_seven_pairs_has_fixed_fu_and_can_combine_with_other_yaku(self):
        result = score('E E S S W W N N 1m 1m 9p 9p 1s 1s', 'N')
        self.assertEqual((result.han, result.fu, result.total_points), (4, 25, 6400))

    def test_best_ambiguous_sequence_reading_beats_triplet_reading(self):
        result = score('1p 1p 1p 2p 2p 2p 3p 3p 3p 4s 5s 6s E E', '6s', riichi=1)
        self.assertIsNotNone(result)
        self.assertEqual(result.total_points, 6400)
        self.assertIn('three_concealed_triplets', dict(result.yaku))

    def test_no_kiriage_and_counted_yakuman_ceiling(self):
        result = score(PINFU, '4s', tsumo=True, bonus=2)
        self.assertEqual((result.han, result.fu, result.total_points), (4, 20, 5200))
        hand = '1m 2m 3m 4p 5p 6p 7s 8s 9s E E E N N'
        result = score(hand, '9s', tsumo=True, bonus=3)
        self.assertEqual((result.han, result.fu, result.total_points), (5, 30, 8000))
        result = score(PINFU, '4s', bonus=20)
        self.assertEqual(result.total_points, 32000)

    def test_mangan_boundary_does_not_round_1920_base_up(self):
        # Riichi + pinfu + two bonus han, closed ron: 4 han, 30 fu.
        result = score(PINFU, '4s', riichi=1, bonus=2)
        self.assertEqual((result.han, result.fu, result.base_points, result.total_points), (4, 30, 1920, 7700))

    def test_thirteen_orphans_and_four_concealed_triplets(self):
        orphan = score('1m 9m 1p 9p 1s 9s E S W N P F C C', 'C')
        concealed = score('1m 1m 1m 9m 9m 9m 2p 2p 2p 8p 8p 8p E E', 'E')
        self.assertEqual((orphan.yakuman, orphan.total_points), (1, 32000))
        self.assertEqual((concealed.yakuman, concealed.total_points), (1, 32000))

    def test_stacked_yakuman(self):
        result = score('E E E S S S W W W N N N C C', 'C', tsumo=True)
        self.assertEqual((result.yakuman, result.total_points), (3, 96000))
        self.assertEqual(set(dict(result.yaku)), {'all_honors', 'four_winds', 'four_concealed_triplets'})

    def test_nine_gates(self):
        result = score('1m 1m 1m 2m 3m 4m 5m 5m 6m 7m 8m 9m 9m 9m', '5m')
        self.assertEqual((result.yakuman, result.total_points), (1, 32000))

    def test_quad_fu_and_three_kans(self):
        melds = (Meld('ankan', 0), Meld('daiminkan', 16), Meld('kakan', 23))
        result = score('2p 3p 4p E E', '4p', melds=melds, tsumo=True)
        self.assertEqual((result.han, result.fu, result.total_points), (2, 80, 5200))
        self.assertIn('three_kans', dict(result.yaku))

    def test_invalid_contexts_melds_and_counts_are_rejected(self):
        for kwargs in ({'riichi': True}, {'ippatsu': True}, {'rinshan': True},
                       {'seat_wind': 31}, {'tsumo': True, 'chankan': True}):
            with self.subTest(kwargs=kwargs), self.assertRaises(ValueError):
                WinContext(**kwargs)
        for kind, tile in (('chi', 7), ('chi', 27), ('pon', True), ('other', 0)):
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                Meld(kind, tile)
        with self.assertRaises(ValueError):
            score('1m 1m 1m 2p 3p 4p 5p 6p 7p E E', 'E', melds=(Meld('pon', 0),))
        with self.assertRaises(ValueError):
            score_hand(counts(PINFU), 0, bonus_han=-1)


class ScoringStateTests(unittest.TestCase):
    def test_double_riichi_and_ippatsu_lifecycle(self):
        state = start('1p 2p 3p 4p 5p 6p 7p 8p 9p E E E N')
        state.apply({'type': 'tsumo', 'actor': 0, 'pai': '1s'})
        state.apply({'type': 'reach', 'actor': 0})
        self.assertEqual(state.seats[0].riichi_level, 2)
        state.apply({'type': 'dahai', 'actor': 0, 'pai': '1s', 'tsumogiri': True})
        state.apply({'type': 'reach_accepted', 'actor': 0})
        self.assertTrue(state.seats[0].ippatsu)
        state.apply({'type': 'tsumo', 'actor': 0, 'pai': 'N'})
        self.assertIn('ippatsu', dict(score_win(state, tsumo=True).yaku))
        state.apply({'type': 'dahai', 'actor': 0, 'pai': 'N', 'tsumogiri': True})
        self.assertFalse(state.seats[0].ippatsu)

    def test_call_interrupts_ippatsu_without_removing_double_riichi(self):
        state = start('1p 2p 3p 4p 5p 6p 7p 8p 9p E E E N')
        for event in ({'type': 'tsumo', 'actor': 0, 'pai': '1s'},
                      {'type': 'reach', 'actor': 0},
                      {'type': 'dahai', 'actor': 0, 'pai': '1s', 'tsumogiri': True},
                      {'type': 'reach_accepted', 'actor': 0},
                      {'type': 'chi', 'actor': 1, 'target': 0, 'pai': '1s', 'consumed': ['2s', '3s']}):
            state.apply(event)
        self.assertFalse(state.seats[0].ippatsu)
        self.assertEqual(state.seats[0].riichi_level, 2)

    def test_revealed_ura_requires_riichi_and_tsumo_uses_drawn_identity(self):
        state = start('1p 2p 3p 4p 5p 6p 7p 8p 9p E E E N')
        state.apply({'type': 'tsumo', 'actor': 0, 'pai': 'N'})
        with self.assertRaises(ValueError):
            score_win(state, tsumo=True, ura_indicators=('C',))
        with self.assertRaises(ValueError):
            score_win(state, 'E', tsumo=True)

    def test_malformed_public_meld_is_not_scored_as_a_valid_triplet(self):
        state = start('1p 2p 3p 4p 5p 6p 7p 8p 9p E E E N')
        state.apply({'type': 'tsumo', 'actor': 0, 'pai': 'N'})
        state.seats[0].melds = [{'type': 'pon', 'pai': '2s', 'consumed': ['3s', '4s']}]
        with self.assertRaises(ValueError):
            score_win(state, tsumo=True)


if __name__ == '__main__':
    unittest.main()
