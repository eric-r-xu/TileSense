"""Independent yaku-existence checks for legality, not han/fu or EV scoring."""

from collections import Counter

from .hand import ORPHANS, complete, decompositions
from .state import tile_index


def counts_for(state):
    counts = [0] * 34
    for tile in state.hand:
        counts[tile_index(tile)] += 1
    return tuple(counts)


def own_melds(state):
    return state.seats[state.seat].melds


def closed(state):
    return all(meld['type'] == 'ankan' for meld in own_melds(state))


def _meld_shape(meld):
    if meld['type'] == 'chi':
        return 'sequence', min(tile_index(tile) for tile in [meld['pai'], *meld['consumed']])
    return 'triplet', tile_index(meld['consumed'][0] if meld['type'] == 'ankan' else meld['pai'])


def has_yaku(state, counts, win_tile, tsumo=False, chankan=False, rinshan=False,
             include_situational=True):
    melds = own_melds(state)
    counts = tuple(counts)
    if not complete(counts, len(melds)):
        return False
    concealed = closed(state)
    riichi_yaku = state.seats[state.seat].accepted or include_situational and state.seats[state.seat].declared
    if (riichi_yaku or (tsumo and concealed)
            or include_situational and (chankan or rinshan or state.draws == 70)):
        return True
    all_counts = list(counts)
    for meld in melds:
        for tile in (meld['consumed'] if meld['type'] == 'ankan' else [meld['pai'], *meld['consumed']]):
            all_counts[tile_index(tile)] += 1
    tiles = {i for i, value in enumerate(all_counts) if value}
    suits = {i // 9 for i in tiles if i < 27}
    honors = tiles & set(range(27, 34))
    if not honors and all(i % 9 not in (0, 8) for i in tiles):  # all simples
        return True
    if len(suits) <= 1:  # half/full flush or all honors
        return True
    if tiles <= set(ORPHANS) or tiles <= {19, 20, 21, 23, 25, 32}:
        return True
    if not melds and (sum(value == 2 for value in counts) == 7
                      or (all(counts[i] for i in ORPHANS) and any(counts[i] == 2 for i in ORPHANS))):
        return True
    values = {31, 32, 33, tile_index(state.round['bakaze']), 27 + (state.seat - state.round['oya']) % 4}
    exposed = [_meld_shape(meld) for meld in melds]
    kans = sum(meld['type'] in ('ankan', 'daiminkan', 'kakan') for meld in melds)
    if kans >= 3:
        return True
    for pair, hidden in decompositions(counts, len(melds)):
        groups = [*hidden, *exposed]
        triplets = {tile for kind, tile in groups if kind == 'triplet'}
        sequences = [tile for kind, tile in groups if kind == 'sequence']
        if triplets & values or len(triplets) == 4:
            return True
        if concealed and any(amount >= 2 for amount in Counter(sequences).values()):
            return True
        for number in range(9):
            if {number, number + 9, number + 18} <= triplets:
                return True
        for number in range(7):
            if {number, number + 9, number + 18} <= set(sequences):
                return True
        if any({suit * 9, suit * 9 + 3, suit * 9 + 6} <= set(sequences) for suit in range(3)):
            return True
        if pair in {31, 32, 33} and len(triplets & {31, 32, 33}) >= 2:
            return True
        outside_pair = pair >= 27 or pair % 9 in (0, 8)
        outside_groups = all(tile >= 27 or tile % 9 in (0, 8) if kind == 'triplet'
                             else tile % 9 in (0, 6) for kind, tile in groups)
        if outside_pair and outside_groups:
            return True
        hidden_triplets = [tile for kind, tile in hidden if kind == 'triplet']
        concealed_triplets = len(hidden_triplets) + sum(meld['type'] == 'ankan' for meld in melds)
        hidden_sequences = [tile for kind, tile in hidden if kind == 'sequence']
        can_place_elsewhere = pair == win_tile or any(low <= win_tile <= low + 2 for low in hidden_sequences
                                                    if low // 9 == win_tile // 9)
        if not tsumo and win_tile in hidden_triplets and not can_place_elsewhere:
            concealed_triplets -= 1
        if concealed_triplets >= 3:
            return True
        if concealed and len(sequences) == 4 and pair not in values:
            if any((win_tile == low and low % 9 < 6)
                   or (win_tile == low + 2 and low % 9 > 0) for low in sequences):
                return True
    return False
