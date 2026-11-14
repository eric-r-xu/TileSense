"""Independent four-player hand scoring; no policy or future-value assumptions.

The scorer enumerates our own hand decompositions and winning-tile placements.
It returns hand payments before honba, riichi deposits or liability settlement.
Rules specific to the pinned target are checked by separate oracle tooling.
"""

from collections import Counter
from dataclasses import dataclass

from .hand import ORPHANS, complete, decompositions, validate


@dataclass(frozen=True)
class Meld:
    kind: str
    tile: int

    def __post_init__(self):
        if (self.kind not in ('chi', 'pon', 'daiminkan', 'ankan', 'kakan')
                or type(self.tile) is not int or not 0 <= self.tile < 34
                or self.kind == 'chi' and (self.tile >= 27 or self.tile % 9 > 6)):
            raise ValueError('invalid scoring meld')

    @property
    def tiles(self):
        if self.kind == 'chi':
            return tuple(range(self.tile, self.tile + 3))
        return (self.tile,) * (3 if self.kind == 'pon' else 4)


@dataclass(frozen=True)
class WinContext:
    round_wind: int = 27
    seat_wind: int = 27
    tsumo: bool = False
    riichi: int = 0
    ippatsu: bool = False
    rinshan: bool = False
    chankan: bool = False
    last_tile: bool = False
    first_turn: bool = False

    def __post_init__(self):
        if (type(self.round_wind) is not int or self.round_wind not in range(27, 31)
                or type(self.seat_wind) is not int or self.seat_wind not in range(27, 31)
                or type(self.riichi) is not int or self.riichi not in (0, 1, 2)
                or any(type(getattr(self, field)) is not bool for field in
                       ('tsumo', 'ippatsu', 'rinshan', 'chankan', 'last_tile', 'first_turn'))
                or self.ippatsu and not self.riichi
                or self.rinshan and (not self.tsumo or self.chankan)
                or self.chankan and self.tsumo
                or self.first_turn and not self.tsumo):
            raise ValueError('invalid winning context')


@dataclass(frozen=True)
class Score:
    han: int
    fu: int
    yakuman: int
    yaku: tuple
    base_points: int
    payments: tuple

    @property
    def total_points(self):
        return sum(self.payments)


def _outside(tile):
    return tile >= 27 or tile % 9 in (0, 8)


def _payment(han, fu, yakuman, yaku, context):
    if yakuman:
        base = 8000 * yakuman
    elif han >= 13:
        base = 8000
    elif han >= 11:
        base = 6000
    elif han >= 8:
        base = 4000
    elif han >= 6:
        base = 3000
    else:
        base = min(fu * 2 ** (han + 2), 2000)
    rounded = lambda value: (value + 99) // 100 * 100
    if context.tsumo:
        payments = (rounded(2 * base),) * 3 if context.seat_wind == 27 else (
            rounded(base), rounded(base), rounded(2 * base))
    else:
        payments = (rounded(base * (6 if context.seat_wind == 27 else 4)),)
    return Score(han, fu, yakuman, tuple(yaku), base, payments)


def score_hand(counts, winning_tile, melds=(), context=None, bonus_han=0):
    """Return the highest-paying valid reading, or None when there is no yaku.

    Counts include the winning tile. Bonus han is supplied explicitly after
    visible/ura/red accounting; it cannot make a yakuless hand valid. Tsumo
    payments are (nondealer, nondealer, dealer), or three equal dealer receipts.
    The target uses additive double-wind pair fu, no kiriage, and a counted
    yakuman ceiling. Special double-yakuman variants are not assumed.
    """
    counts, melds = tuple(counts), tuple(melds)
    if len(melds) > 4 or any(not isinstance(meld, Meld) for meld in melds):
        raise ValueError('invalid scoring melds')
    validate(counts, len(melds))
    if (type(winning_tile) is not int or not 0 <= winning_tile < 34 or not counts[winning_tile]
            or type(bonus_han) is not int or not 0 <= bonus_han <= 80):
        raise ValueError('invalid winning tile or bonus count')
    if context is None:
        context = WinContext()
    if not isinstance(context, WinContext):
        raise ValueError('invalid scoring context')
    concealed = all(meld.kind == 'ankan' for meld in melds)
    if context.riichi and not concealed:
        raise ValueError('riichi requires a closed hand')
    if context.first_turn and melds:
        raise ValueError('an initial self-draw cannot have melds')
    all_counts = list(counts)
    for meld in melds:
        for tile in meld.tiles:
            all_counts[tile] += 1
    if any(amount > 4 for amount in all_counts):
        raise ValueError('more than four physical copies in scoring hand')
    if not complete(counts, len(melds)):
        return None
    tiles = {tile for tile, amount in enumerate(all_counts) if amount}
    suits = {tile // 9 for tile in tiles if tile < 27}
    honors = tiles & set(range(27, 34))
    common_yaku = []
    common_limits = []
    if context.first_turn:
        common_limits.append('initial_self_draw')
    if not suits:
        common_limits.append('all_honors')
    if tiles <= {tile for tile in range(27) if tile % 9 in (0, 8)}:
        common_limits.append('all_terminals')
    if tiles <= {19, 20, 21, 23, 25, 32}:
        common_limits.append('all_green')
    if context.riichi:
        common_yaku.append(('riichi', context.riichi))
    for name, present in (('ippatsu', context.ippatsu), ('closed_self_draw', context.tsumo and concealed),
                          ('replacement_draw', context.rinshan), ('robbing_kan', context.chankan),
                          ('last_tile', context.last_tile)):
        if present:
            common_yaku.append((name, 1))
    if all(not _outside(tile) for tile in tiles):
        common_yaku.append(('all_simples', 1))
    if tiles <= set(ORPHANS):
        common_yaku.append(('terminals_and_honors', 2))
    if len(suits) == 1:
        common_yaku.append(('half_flush' if honors else 'full_flush',
                            (3 if concealed else 2) if honors else (6 if concealed else 5)))
    if not melds and len(suits) == 1 and not honors:
        suit = next(iter(suits))
        baseline = (3, 1, 1, 1, 1, 1, 1, 1, 3)
        if all(counts[suit * 9 + i] >= amount for i, amount in enumerate(baseline)):
            common_limits.append('nine_gates')
    if not melds and all(counts[tile] for tile in ORPHANS) and sum(counts[tile] for tile in ORPHANS) == 14:
        limits = [*common_limits, 'thirteen_orphans']
        return _payment(0, 0, len(limits), [(name, 1) for name in limits], context)
    results = []

    def record(yaku, fu, limits):
        if limits:
            results.append(_payment(0, 0, len(limits), [(name, 1) for name in limits], context))
        elif yaku:
            total = sum(han for _, han in yaku)
            if bonus_han:
                yaku = [*yaku, ('bonus', bonus_han)]
            results.append(_payment(total + bonus_han, fu, 0, yaku, context))

    if not melds and sum(amount == 2 for amount in counts) == 7:
        record([*common_yaku, ('seven_pairs', 2)], 25, common_limits)
    exposed = [('sequence' if meld.kind == 'chi' else 'triplet', meld.tile) for meld in melds]
    kans = sum(meld.kind in ('ankan', 'daiminkan', 'kakan') for meld in melds)
    for pair, hidden in decompositions(counts, len(melds)):
        placements = [('pair', -1)] if pair == winning_tile else []
        for index, (kind, tile) in enumerate(hidden):
            if kind == 'triplet' and tile == winning_tile or kind == 'sequence' and tile <= winning_tile <= tile + 2:
                placements.append((kind, index))
        for placement, index in placements:
            groups = [*hidden, *exposed]
            triplets = {tile for kind, tile in groups if kind == 'triplet'}
            sequences = [tile for kind, tile in groups if kind == 'sequence']
            concealed_triplets = sum(kind == 'triplet' for kind, _ in hidden) + sum(meld.kind == 'ankan' for meld in melds)
            if not context.tsumo and placement == 'triplet':
                concealed_triplets -= 1
            limits = list(common_limits)
            if {31, 32, 33} <= triplets:
                limits.append('three_dragons')
            winds = triplets & set(range(27, 31))
            if len(winds) == 4:
                limits.append('four_winds')
            elif len(winds) == 3 and pair in range(27, 31):
                limits.append('three_winds_and_pair')
            if concealed_triplets == 4:
                limits.append('four_concealed_triplets')
            if kans == 4:
                limits.append('four_kans')
            yaku = list(common_yaku)
            for tile in triplets:
                amount = int(tile >= 31) + int(tile == context.round_wind) + int(tile == context.seat_wind)
                if amount:
                    yaku.append(('value_triplet', amount))
            if len(triplets) == 4:
                yaku.append(('all_triplets', 2))
            if concealed_triplets >= 3:
                yaku.append(('three_concealed_triplets', 2))
            if kans >= 3:
                yaku.append(('three_kans', 2))
            if pair >= 31 and len(triplets & {31, 32, 33}) == 2:
                yaku.append(('two_dragons_and_pair', 2))
            if any({number, number + 9, number + 18} <= triplets for number in range(9)):
                yaku.append(('three_suit_triplets', 2))
            if any({number, number + 9, number + 18} <= set(sequences) for number in range(7)):
                yaku.append(('three_suit_sequences', 2 if concealed else 1))
            if any({suit * 9, suit * 9 + 3, suit * 9 + 6} <= set(sequences) for suit in range(3)):
                yaku.append(('straight', 2 if concealed else 1))
            if concealed:
                duplicate_pairs = sum(amount // 2 for amount in Counter(sequences).values())
                if duplicate_pairs:
                    yaku.append(('two_duplicate_sequences', 3) if duplicate_pairs == 2 else ('duplicate_sequence', 1))
            outside_groups = all(_outside(tile) if kind == 'triplet' else tile % 9 in (0, 6)
                                 for kind, tile in groups)
            if _outside(pair) and outside_groups and sequences:
                yaku.append(('outside_hand' if honors else 'terminal_outside_hand',
                             (2 if concealed else 1) if honors else (3 if concealed else 2)))
            wait_fu = 2 if placement == 'pair' else 0
            if placement == 'sequence':
                low = hidden[index][1]
                if winning_tile == low + 1 or low % 9 == 0 and winning_tile == low + 2 or low % 9 == 6 and winning_tile == low:
                    wait_fu = 2
            pair_fu = 2 * (int(pair >= 31) + int(pair == context.round_wind) + int(pair == context.seat_wind))
            pinfu = concealed and len(sequences) == 4 and pair_fu == 0 and wait_fu == 0
            if pinfu:
                yaku.append(('pinfu', 1))
            fu = 20 + pair_fu + wait_fu + (10 if concealed and not context.tsumo else 0)
            for group_index, (kind, tile) in enumerate(hidden):
                if kind == 'triplet':
                    opened_by_ron = not context.tsumo and placement == 'triplet' and index == group_index
                    fu += (2 if opened_by_ron else 4) * (2 if _outside(tile) else 1)
            for meld in melds:
                if meld.kind != 'chi':
                    fu += (2 if meld.kind == 'pon' else 16 if meld.kind == 'ankan' else 8) * (2 if _outside(meld.tile) else 1)
            if context.tsumo and not pinfu:
                fu += 2
            if not concealed and not context.tsumo:
                fu = max(fu, 30)
            fu = (fu + 9) // 10 * 10
            record(yaku, fu, limits)
    return max(results, key=lambda result: (result.total_points, result.yakuman, result.han, result.fu)) if results else None


def score_win(state, winning_tile=None, *, tsumo=False, ura_indicators=()):
    """Score a current win from visible state and explicitly supplied ura tiles.

    Actual ura indicators are only appropriate for a revealed result. They are
    not looked up or inferred for future EV calculations.
    """
    from .state import RED, bonus_tile, tile_index
    from .yaku import counts_for, own_melds

    if state.failed or not state.active or type(tsumo) is not bool:
        raise ValueError('win scoring requires an active valid state')
    if winning_tile is None:
        if not tsumo or state.last_draw is None:
            raise ValueError('a winning tile is required')
        winning_tile = state.last_draw
    if tsumo and winning_tile != state.last_draw:
        raise ValueError('self-draw scoring must use the actual drawn tile')
    winner = tile_index(winning_tile)
    counts = list(counts_for(state))
    tiles = list(state.hand)
    if not tsumo:
        counts[winner] += 1
        tiles.append(winning_tile)
    own = state.seats[state.seat]
    if not isinstance(ura_indicators, (tuple, list)) or len(ura_indicators) > 5:
        raise ValueError('invalid revealed ura indicators')
    for indicator in ura_indicators:
        tile_index(indicator)
    if ura_indicators and not own.accepted:
        raise ValueError('ura indicators require accepted riichi')
    melds = []
    for meld in own_melds(state):
        all_tiles = list(meld['consumed'])
        if meld['type'] != 'ankan':
            all_tiles.append(meld['pai'])
        tiles.extend(all_tiles)
        shape = Meld(meld['type'], min(tile_index(tile) for tile in all_tiles))
        if sorted(tile_index(tile) for tile in all_tiles) != sorted(shape.tiles):
            raise ValueError('public meld does not match its scoring shape')
        melds.append(shape)
    indicators = [*state.indicators, *ura_indicators]
    bonus = sum(tile in RED for tile in tiles) + sum(
        tile_index(tile) == bonus_tile(indicator) for tile in tiles for indicator in indicators)
    trigger = (state.ron_window if not tsumo else state.last_event) or {}
    chankan = not tsumo and trigger.get('type') in ('kakan', 'ankan')
    rinshan = tsumo and state.rinshan_draw
    context = WinContext(round_wind=tile_index(state.round['bakaze']),
                         seat_wind=27 + (state.seat - state.round['oya']) % 4,
                         tsumo=tsumo, riichi=own.riichi_level if own.accepted else 0,
                         ippatsu=own.ippatsu, rinshan=rinshan, chankan=chankan,
                         last_tile=state.draws == 70 and not (chankan or rinshan),
                         first_turn=tsumo and state.own_draws == 1 and not own.discards and not state.has_calls)
    return score_hand(counts, winner, melds, context, bonus)
