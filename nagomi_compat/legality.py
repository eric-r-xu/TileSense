"""Independent four-player action eligibility; checked separately from the oracle.

This module uses hand mathematics and yaku existence, not reference masks.
The original network's win guard is a separate, still-unimplemented policy.
"""

import numpy as np

from .hand import ORPHANS, decompositions, waits
from .state import RED, tile_index
from .yaku import closed, counts_for, has_yaku, own_melds


def waiting_hand(state):
    counts = list(counts_for(state))
    if len(state.hand) % 3 == 2 and state.last_draw is not None:
        counts[tile_index(state.last_draw)] -= 1
    return tuple(counts)


def hand_waits(state):
    return waits(waiting_hand(state), len(own_melds(state)))


def furiten(state):
    discarded = {tile_index(record.tile) for record in state.seats[state.seat].discards}
    return (state.temporary_furiten or state.riichi_furiten
            or bool(discarded & set(state.shape_waits)))


def could_ron(state, trigger=None):
    event = trigger or state.last_event
    if (event is None or event['type'] not in ('dahai', 'kakan', 'ankan')
            or event['actor'] == state.seat or furiten(state)):
        return False
    tile = event['consumed'][0] if event['type'] == 'ankan' else event['pai']
    index = tile_index(tile)
    counts = list(counts_for(state))
    if counts[index] == 4:
        return False
    counts[index] += 1
    if event['type'] == 'ankan':
        return not own_melds(state) and all(counts[i] for i in ORPHANS) and sum(counts[i] for i in ORPHANS) == 14
    return has_yaku(state, counts, index, chankan=event['type'] == 'kakan')


def _riichi_kan(state, index):
    if state.last_draw is None or tile_index(state.last_draw) != index:
        return False
    before = waiting_hand(state)
    after = list(counts_for(state))
    after[index] -= 4
    melds = len(own_melds(state))
    original = waits(before, melds)
    if not original or waits(tuple(after), melds + 1) != original:
        return False
    # An accepted riichi must retain the original concealed triplet reading.
    for winner in original:
        complete = list(before)
        complete[winner] += 1
        if any(('triplet', index) not in groups for _, groups in decompositions(tuple(complete), melds)):
            return False
    return True


def legal_mask(state, at_kan_select=False):
    mask = np.zeros(46, dtype=np.bool_)
    if state.failed or not state.active or state.last_event is None:
        return mask
    event = state.last_event
    kind = event['type']
    own = state.seats[state.seat]
    counts = counts_for(state)
    melds = own_melds(state)
    remaining = 70 - state.draws
    on_turn = kind in ('tsumo', 'chi', 'pon', 'reach') and event.get('actor') == state.seat
    closed_kans = []
    added_kans = []
    if on_turn:
        if kind == 'tsumo' and remaining > 0 and len(melds) < 4:
            closed_kans = [i for i, count in enumerate(counts) if count == 4
                           and (not own.accepted or _riichi_kan(state, i))]
            if not own.declared:
                added_kans = [tile_index(m['pai']) for m in melds if m['type'] == 'pon'
                              and counts[tile_index(m['pai'])] > 0]
        if at_kan_select:
            mask[closed_kans + added_kans] = True
            return mask
        if own.accepted:
            if state.last_draw is not None:
                index = RED.index(state.last_draw) + 34 if state.last_draw in RED else tile_index(state.last_draw)
                mask[index] = True
        else:
            for tile in set(state.hand):
                index = tile_index(tile)
                if index in state.forbidden_discards:
                    continue
                if own.declared:
                    after = list(counts)
                    after[index] -= 1
                    if not waits(tuple(after), len(melds)):
                        continue
                mask[RED.index(tile) + 34 if tile in RED else index] = True
        if not own.declared and closed(state) and state.scores[state.seat] >= 1000 and remaining >= 4:
            for tile in set(state.hand):
                after = list(counts)
                after[tile_index(tile)] -= 1
                if waits(tuple(after), len(melds)):
                    mask[37] = True
                    break
        mask[42] = bool(closed_kans or added_kans)
        if kind == 'tsumo':
            mask[43] = has_yaku(state, counts, tile_index(event['pai']), tsumo=True,
                                rinshan=state.rinshan_draw)
            mask[44] = (state.own_draws == 1 and not own.discards and not state.has_calls
                        and sum(counts[i] > 0 for i in ORPHANS) >= 9)
        return mask
    if kind not in ('dahai', 'kakan', 'ankan') or event.get('actor') == state.seat:
        return mask
    mask[43] = could_ron(state)
    if kind == 'dahai' and not own.declared and remaining > 0:
        index = tile_index(event['pai'])
        mask[41] = counts[index] >= 2
        if counts[index] >= 3 and len(melds) < 4:
            if at_kan_select:
                mask[:] = False
                mask[index] = True
                return mask
            mask[42] = True
        if index < 27 and event['actor'] == (state.seat + 3) % 4:
            for variant in range(3):
                low = index - variant
                if low < 0 or low // 9 != index // 9 or low + 2 >= (index // 9 + 1) * 9:
                    continue
                consumed = [i for i in range(low, low + 3) if i != index]
                if all(counts[i] for i in consumed):
                    mask[38 + variant] = True
    if at_kan_select:
        return np.zeros(46, dtype=np.bool_)
    mask[45] = mask[38:44].any()
    return mask
