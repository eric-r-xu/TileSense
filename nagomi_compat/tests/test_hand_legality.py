import unittest

from nagomi_compat.hand import ORPHANS, complete, decompositions, shanten, waits
from nagomi_compat.legality import furiten, legal_mask
from nagomi_compat.observation import encode
from nagomi_compat.state import VisibleState, tile_index
from nagomi_compat.yaku import has_yaku


def counts(tiles):
    result = [0] * 34
    for tile in tiles.split():
        result[tile_index(tile)] += 1
    return tuple(result)


def start(hand, seat=0):
    event = {'type': 'start_kyoku', 'bakaze': 'E', 'dora_marker': '9s', 'kyoku': 1,
             'honba': 0, 'kyotaku': 0, 'oya': 0, 'scores': [25000] * 4,
             'tehais': [['?'] * 13 for _ in range(4)]}
    event['tehais'][seat] = hand.split()
    state = VisibleState(seat)
    state.apply(event)
    return state


class HandMathTests(unittest.TestCase):
    def test_standard_open_and_closed_hands(self):
        hand = counts('1p 2p 3p 4p 5p 6p 7p 8p 9p E E E N')
        self.assertEqual(shanten(hand), 0)
        self.assertEqual(waits(hand), (30,))
        full = list(hand)
        full[30] += 1
        self.assertTrue(complete(full))
        self.assertEqual(shanten(full), -1)
        opened = counts('1p 2p 3p 4p 5p 6p 7p 8p 9p E')
        self.assertEqual(shanten(opened, 1), 0)
        self.assertEqual(waits(opened, 1), (27,))

    def test_seven_pairs_does_not_count_quads_as_two_pairs(self):
        hand = counts('1m 1m 3m 3m 5m 5m 7p 7p 9p 9p E E N')
        self.assertEqual(shanten(hand), 0)
        self.assertIn(30, waits(hand))
        self.assertFalse(complete(counts('E E E E S S S S W W W W N N')))

    def test_thirteen_orphans_thirteen_sided_wait(self):
        hand = tuple(int(i in ORPHANS) for i in range(34))
        self.assertEqual(shanten(hand), 0)
        self.assertEqual(waits(hand), ORPHANS)
        opened = tuple(int(i in ORPHANS[:10]) for i in range(34))
        self.assertEqual(waits(opened, 1), ())

    def test_ambiguous_triplet_sequence_readings_are_all_retained(self):
        hand = counts('1p 1p 1p 2p 2p 2p 3p 3p 3p 4s 5s 6s E E')
        readings = decompositions(hand)
        self.assertGreaterEqual(len(readings), 2)
        self.assertTrue(any(sum(kind == 'triplet' for kind, _ in groups) == 3 for _, groups in readings))
        self.assertTrue(any(sum(kind == 'sequence' for kind, _ in groups) == 4 for _, groups in readings))

    def test_invalid_count_vectors_rejected(self):
        for function in (shanten, waits, complete, decompositions):
            for hand in ((-1,) + (0,) * 33, (5,) + (0,) * 33, (0,) * 33):
                with self.subTest(function=function.__name__), self.assertRaises(ValueError):
                    function(hand)

    def test_quad_cannot_wait_for_a_fifth_identical_tile(self):
        for hand, melds in [('5s 5s 5s 5s', 3),
                            ('5p 5p 5p 5p 2s 3s 4s', 2),
                            ('F F F F 2s 3s 4s 6s 7s 8s', 1)]:
            with self.subTest(hand=hand):
                self.assertEqual(shanten(counts(hand), melds), 1)
                self.assertEqual(waits(counts(hand), melds), ())


class LegalityTests(unittest.TestCase):
    def test_yaku_discard_feature_requires_live_wait_and_remaining_draws(self):
        hand = '1p 2p 3p 4p 5p 6p 7p 8p 9p E E E N'
        state = start(hand)
        state.apply({'type': 'tsumo', 'actor': 0, 'pai': '1s'})
        self.assertEqual(encode(state).values[877, 18], 1)
        state.draws = 70
        self.assertEqual(encode(state).values[877, 18], 0)

        state = start(hand)
        for actor in (1, 2, 3):
            state.apply({'type': 'tsumo', 'actor': actor, 'pai': '?'})
            state.apply({'type': 'dahai', 'actor': actor, 'pai': 'N', 'tsumogiri': True})
        state.apply({'type': 'tsumo', 'actor': 0, 'pai': '1s'})
        self.assertEqual(encode(state).values[877, 18], 0)

    def test_draw_can_declare_riichi_and_followup_only_discards_tenpai(self):
        state = start('1p 2p 3p 4p 5p 6p 7p 8p 9p E E E N')
        state.apply({'type': 'tsumo', 'actor': 0, 'pai': '1s'})
        self.assertTrue(legal_mask(state)[37])
        state.apply({'type': 'reach', 'actor': 0})
        mask = legal_mask(state)
        self.assertTrue(mask[18])
        self.assertFalse(mask[37])
        self.assertFalse(mask[42])
        state.apply({'type': 'dahai', 'actor': 0, 'pai': '1s', 'tsumogiri': True})
        state.apply({'type': 'reach_accepted', 'actor': 0})
        frozen = state.keep_discards
        state.apply({'type': 'tsumo', 'actor': 0, 'pai': '2s'})
        self.assertEqual(state.keep_discards, frozen)
        self.assertEqual([i for i in range(37) if legal_mask(state)[i]], [19])

    def test_no_kan_immediately_after_pon_and_kuikae_is_forbidden(self):
        state = start('1p 2p 3p 4p 5p 5p 5pr 6p 6s 6s 6s E N', seat=1)
        state.apply({'type': 'tsumo', 'actor': 0, 'pai': '?'})
        state.apply({'type': 'dahai', 'actor': 0, 'pai': '5p', 'tsumogiri': True})
        self.assertTrue(legal_mask(state)[41])
        state.apply({'type': 'pon', 'actor': 1, 'target': 0, 'pai': '5p', 'consumed': ['5pr', '5p']})
        self.assertFalse(legal_mask(state)[42])
        self.assertFalse(legal_mask(state)[13])

    def test_chi_is_only_from_previous_seat_and_bans_suji_exchange(self):
        state = start('2p 3p 4p 5p 6p 7p 8p E E E N N S')
        state.apply({'type': 'tsumo', 'actor': 1, 'pai': '?'})
        state.apply({'type': 'dahai', 'actor': 1, 'pai': '1p', 'tsumogiri': True})
        self.assertFalse(legal_mask(state)[38:41].any())
        state.apply({'type': 'tsumo', 'actor': 3, 'pai': '?'})
        state.apply({'type': 'dahai', 'actor': 3, 'pai': '1p', 'tsumogiri': True})
        self.assertTrue(legal_mask(state)[38])
        state.apply({'type': 'chi', 'actor': 0, 'target': 3, 'pai': '1p', 'consumed': ['2p', '3p']})
        self.assertFalse(legal_mask(state)[12])  # Cannot exchange 1p for 4p.

    def test_nine_terminals_requires_uninterrupted_first_draw(self):
        state = start('1m 9m 1p 9p 1s 9s E S W N P F C')
        state.apply({'type': 'tsumo', 'actor': 0, 'pai': '2p'})
        self.assertTrue(legal_mask(state)[44])
        state.has_calls = True
        self.assertFalse(legal_mask(state)[44])

    def test_dora_is_not_a_yaku_and_situational_yaku_can_be_excluded(self):
        state = start('1p 2p 3p 4p 5p 6p 7m 8m N N 4s 5s 6s')
        state.seats[0].melds = [{'type': 'chi', 'pai': '4s', 'consumed': ['5s', '6s']}]
        winning = counts('1p 2p 3p 4p 5p 6p 7m 8m 9m N N')
        self.assertFalse(has_yaku(state, winning, 8))
        state.draws = 70
        self.assertTrue(has_yaku(state, winning, 8))
        self.assertFalse(has_yaku(state, winning, 8, include_situational=False))

    def test_yakuless_structural_win_sets_temporary_furiten_until_discard(self):
        state = start('5s 5s 5p 5mr 2p 7p 6m 6p 3p 7m 8p 8p C', seat=3)
        for event in [
            {'type': 'tsumo', 'actor': 2, 'pai': '?'},
            {'type': 'dahai', 'actor': 2, 'pai': '8p', 'tsumogiri': True},
            {'type': 'pon', 'actor': 3, 'target': 2, 'pai': '8p', 'consumed': ['8p', '8p']},
            {'type': 'dahai', 'actor': 3, 'pai': 'C', 'tsumogiri': False},
            {'type': 'tsumo', 'actor': 0, 'pai': '?'},
            {'type': 'dahai', 'actor': 0, 'pai': 'E', 'tsumogiri': True},
            {'type': 'tsumo', 'actor': 1, 'pai': '?'},
            {'type': 'dahai', 'actor': 1, 'pai': 'S', 'tsumogiri': True},
            {'type': 'tsumo', 'actor': 2, 'pai': '?'},
            {'type': 'dahai', 'actor': 2, 'pai': '1p', 'tsumogiri': True},
        ]:
            state.apply(event)
        self.assertTrue(furiten(state))
        self.assertFalse(legal_mask(state)[43])
        state.apply({'type': 'tsumo', 'actor': 3, 'pai': '1m'})
        self.assertTrue(furiten(state))
        state.apply({'type': 'dahai', 'actor': 3, 'pai': '1m', 'tsumogiri': True})
        self.assertFalse(furiten(state))


if __name__ == '__main__':
    unittest.main()
