"""Independent structural tile-efficiency calculations for the pinned format.

This module enumerates draws using our own hand mathematics. It neither
estimates score/EV nor imports an oracle. The horizon and candidate-selection
rules are wire-format behavior established by separate black-box tests.
"""

from dataclasses import dataclass
from functools import lru_cache

from .hand import complete, shanten, validate
from .state import TILES, tile_index
from .visibility import visible_counts
from .yaku import counts_for, own_melds


@lru_cache(maxsize=50000)
def _improving_tiles(counts, melds):
    distance = shanten(counts, melds)
    candidates = []
    after = list(counts)
    for tile, amount in enumerate(counts):
        if amount == 4:
            continue
        after[tile] += 1
        if shanten(after, melds) < distance:
            candidates.append(tile)
        after[tile] -= 1
    return tuple(candidates)


def improving_tiles(counts, melds=0):
    """Draw types reducing shanten, before public visibility is considered."""
    counts = tuple(counts)
    validate(counts, melds)
    if sum(counts) != 13 - 3 * melds:
        raise ValueError('tile efficiency requires a hand before drawing')
    return _improving_tiles(counts, melds)


@dataclass(frozen=True)
class DiscardEfficiency:
    tile: int
    shanten: int
    required: tuple
    live_copies: int


@dataclass(frozen=True)
class Efficiency:
    horizon: int
    discards: tuple = ()
    required: tuple = ()
    best_discard: int | None = None
    minimum_shanten: int | None = None


def analyze(state):
    """Calculate the structural lookahead group without score approximations."""
    if state.failed or not state.active:
        raise ValueError('tile efficiency requires an active hand')
    counts = counts_for(state)
    melds = len(own_melds(state))
    before_draw = sum(counts) == 13 - 3 * melds
    offset = (state.seat - (state.last_event or {}).get('actor', state.seat)) % 4 if before_draw else 0
    horizon = max((70 - state.draws - offset) // 4, 0)
    if not horizon or complete(counts, melds):
        return Efficiency(horizon)
    seen = visible_counts(state)
    if any(amount > 4 for amount in seen):
        raise ValueError('too many physically visible copies')

    def available(hand):
        return tuple(tile for tile in improving_tiles(hand, melds) if seen[tile] < 4)

    if before_draw:
        return Efficiency(horizon, required=available(counts), minimum_shanten=shanten(counts, melds))
    if sum(counts) != 14 - 3 * melds:
        raise ValueError('unexpected own hand size for tile efficiency')
    candidates = []
    accepted = state.seats[state.seat].accepted
    forced = tile_index(state.last_draw) if accepted and state.last_draw is not None else None
    for tile, amount in enumerate(counts):
        if not amount or accepted and tile != forced:
            continue
        after = list(counts)
        after[tile] -= 1
        candidates.append((tile, tuple(after), shanten(after, melds)))
    if not candidates:
        raise ValueError('no own discard candidates')
    minimum = min(distance for _, _, distance in candidates)
    discards = []
    for tile, after, distance in candidates:
        # The high-shanten fallback includes the next shanten tier. The
        # lower-shanten search emits only minimum-shanten candidates.
        if minimum < 4 and distance != minimum:
            continue
        required = available(after)
        discards.append(DiscardEfficiency(tile, distance, required, sum(4 - seen[t] for t in required)))
    best = max((option for option in discards if option.shanten == minimum),
               key=lambda option: (option.live_copies,
                                   5 if option.tile >= 27 else abs(option.tile % 9 - 4),
                                   TILES[option.tile] in state.hand,
                                   -option.tile))
    return Efficiency(horizon, tuple(discards), best_discard=best.tile, minimum_shanten=minimum)
