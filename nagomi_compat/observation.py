"""Independently written portions of the pinned v4 observation format.

Offsets/normalizations are a wire-format contract established by oracle probes.
No reference engine implementation is imported, copied or translated here.
Unimplemented rows remain explicitly unknown and cannot be scored as a frame.
"""

from dataclasses import dataclass
import math

import numpy as np

from .state import RED, bonus_tile, tile_index
from .visibility import visible_counts, visible_tiles
from .hand import shanten, waits
from .legality import furiten, legal_mask
from .yaku import counts_for, has_yaku, own_melds
from .efficiency import analyze


class IncompleteObservationError(RuntimeError):
    pass


@dataclass
class Observation:
    values: np.ndarray
    known_rows: np.ndarray
    missing_groups: tuple

    def require_complete(self):
        if not self.known_rows.all():
            raise IncompleteObservationError('unimplemented observation groups: ' + ', '.join(self.missing_groups))
        return self.values


def _packet(array, offset, tiles):
    counts = np.bincount([tile_index(tile) for tile in tiles], minlength=34)
    for level in range(4):
        array[offset + level] = counts > level
    for suit, tile in enumerate(RED):
        array[offset + 4 + suit] = tile in tiles


def encode(state, at_kan_select=False):
    if type(at_kan_select) is not bool:
        raise ValueError('invalid kan phase')
    if state.failed or not state.active:
        raise ValueError('observation requires an active hand')
    values = np.full((1012, 34), np.nan, dtype=np.float32)
    known = np.zeros(1012, dtype=np.bool_)
    values[:35] = 0
    _packet(values, 0, state.hand)
    for relative in range(4):
        score = state.scores[(state.seat + relative) % 4]
        values[7 + relative * 2] = np.float32(min(max(score, 0), 100000)) / np.float32(100000)
        values[8 + relative * 2] = np.float32(min(max(score, 0), 30000)) / np.float32(30000)
    ranking = sorted(range(4), key=lambda seat: (-state.scores[seat], seat))
    values[15 + ranking.index(state.seat)] = 1
    values[19 + state.round['kyoku'] - 1] = 1
    values[23] = np.float32(min(state.round['honba'], 10)) / np.float32(10)
    values[24] = np.float32(min(state.sticks, 10)) / np.float32(10)
    values[25, tile_index(state.round['bakaze'])] = 1
    values[26, 27 + (state.seat - state.round['oya']) % 4] = 1
    progress = state.round['kyoku'] - 1 + (0 if state.round['bakaze'] == 'E' else 4)
    values[27] = np.float32(min(progress, 7)) / np.float32(7)
    _packet(values, 28, state.indicators)
    known[:35] = True
    values[35:717] = 0
    entries = state.rivers[0]
    for start, subset in ((35, entries[:6]), (59, list(reversed(entries))[:18])):
        for position, discard in enumerate(subset):
            if discard is None:
                continue
            row = start + 4 * position
            for tile in discard.kans:
                values[row, tile_index(tile)] = 1
            values[row + 1, tile_index(discard.tile)] = 1
            values[row + 2] = discard.tile in RED
            values[row + 3] = discard.bonus
    for position, discard in enumerate(entries):
        if discard is None:
            continue
        age = np.float32(-0.2) * np.float32(len(entries) - 1 - position)
        values[131, tile_index(discard.tile)] = np.float32(math.exp(float(age)))
    for relative in range(1, 4):
        entries = state.rivers[relative]
        block = 132 + (relative - 1) * 195
        for start, subset in ((block, entries[:6]), (block + 48, list(reversed(entries))[:18])):
            for position, discard in enumerate(subset):
                if discard is None:
                    continue
                row = start + 8 * position
                if discard.call is not None:
                    consumed = [tile_index(tile) for tile in discard.call['consumed']]
                    values[row, min(consumed)] = 1
                    values[row + 1, max(consumed)] = 1
                for tile in discard.kans:
                    values[row + 2, tile_index(tile)] = 1
                values[row + 3, tile_index(discard.tile)] = 1
                values[row + 4] = discard.tile in RED
                values[row + 5] = discard.bonus
                values[row + 6] = discard.tedashi
                values[row + 7] = discard.riichi
        for position, discard in enumerate(entries):
            if discard is None:
                continue
            tile = tile_index(discard.tile)
            age = np.float32(-0.2) * np.float32(max(len(state.rivers[0]) - 1 - position, 0))
            weight = np.float32(math.exp(float(age)))
            values[block + 192, tile] = weight
            if discard.tedashi:
                values[block + 193, tile] = weight
            if discard.riichi:
                values[block + 194, tile] = weight
    known[35:717] = True
    values[717:836] = 0
    values[717] = np.float32(70 - state.draws) / np.float32(69)
    seen = visible_tiles(state)
    bonus_types = [bonus_tile(marker) for marker in state.indicators]
    owned = [list(state.hand) if relative == 0 else [] for relative in range(4)]
    for relative in range(4):
        actor = (state.seat + relative) % 4
        player = state.seats[actor]
        _packet(values, 723 + relative * 7, [record.tile for record in player.discards])
        slot = 0
        for meld in player.melds:
            all_tiles = list(meld['consumed'])
            if meld['type'] != 'ankan':
                all_tiles.append(meld['pai'])
            owned[relative].extend(all_tiles)
            if meld['type'] == 'ankan':
                values[831 + relative, tile_index(all_tiles[0])] = 1
            else:
                row = 751 + relative * 20 + slot * 5
                counts = np.bincount([tile_index(tile) for tile in all_tiles], minlength=34)
                for level in range(4):
                    values[row + level] = counts > level
                values[row + 4] = any(tile in RED for tile in all_tiles)
                slot += 1
    for relative, tiles in enumerate(owned):
        count = sum(bonus_types.count(tile_index(tile)) + int(tile in RED) for tile in tiles)
        values[718 + relative] = np.float32(min(count, 12)) / np.float32(12)
    visible_bonus = sum(bonus_types.count(tile_index(tile)) + int(tile in RED) for tile in seen)
    values[722] = np.float32(max(len(state.indicators) * 4 + 3 - visible_bonus, 0)) / np.float32(23)
    values[835] = np.bincount([tile_index(tile) for tile in seen], minlength=34).astype(np.float32) / np.float32(4)
    known[717:836] = True
    values[836:889] = 0
    for relative in range(1, 4):
        discards = state.seats[(state.seat + relative) % 4].discards
        last_tedashi = next((discard for discard in reversed(discards) if discard.tedashi), None)
        riichi_discard = next((discard for discard in discards if discard.riichi), None)
        for start, discard in ((836 + (relative - 1) * 3, last_tedashi),
                               (845 + (relative - 1) * 3, riichi_discard)):
            if discard is not None:
                values[start, tile_index(discard.tile)] = 1
                values[start + 1] = discard.tile in RED
                values[start + 2] = discard.bonus
        seat = state.seats[(state.seat + relative) % 4]
        values[854 + relative - 1] = seat.declared
        values[857 + relative - 1] = seat.accepted
    values[860, list(state.stored_waits)] = 1
    values[861] = furiten(state)
    values[862 + min(max(state.stored_shanten, 0), 6)] = 1
    own = state.seats[state.seat]
    values[869] = own.accepted
    values[870] = at_kan_select
    normal = legal_mask(state)
    counts = counts_for(state)
    melds = own_melds(state)
    if normal[45]:
        event = state.last_event
        tile = event['consumed'][0] if event['type'] == 'ankan' else event['pai']
        values[871, tile_index(tile)] = 1
        values[872] = tile in RED
        values[873] = any(bonus_tile(marker) == tile_index(tile) for marker in state.indicators)
    legal_discards = set()
    for action in np.flatnonzero(normal[:37]):
        index = int(action) if action < 34 else (4, 13, 22)[action - 34]
        legal_discards.add(index)
    pond = {tile_index(discard.tile) for discard in own.discards}
    physical_counts = visible_counts(state)
    if legal_discards:
        values[875, list(state.keep_discards)] = 1
        values[876, list(state.improving_discards)] = 1
    for index in legal_discards:
        values[874, index] = 1
        after = list(counts)
        after[index] -= 1
        distance = shanten(after, len(melds))
        if state.draws < 70 and state.stored_shanten <= 1 and distance == 0 and not state.riichi_furiten:
            winning = waits(after, len(melds))
            if winning and not ((pond | {index}) & set(winning)):
                for winner in winning:
                    if physical_counts[winner] == 4:
                        continue
                    full = list(after)
                    full[winner] += 1
                    if has_yaku(state, full, winner, include_situational=False):
                        values[877, index] = 1
                        break
    values[878] = bool(legal_discards) and own.declared
    for row, action in zip(range(879, 885), (37, 38, 39, 40, 41, 42)):
        values[row] = normal[action] if action != 42 else normal[action] and state.last_event.get('actor') != state.seat
    if normal[42] and state.last_event.get('actor') == state.seat:
        choices = np.flatnonzero(legal_mask(state, True))
        for index in choices:
            values[885 if counts[index] == 4 else 886, index] = 1
    values[887] = normal[43]
    values[888] = normal[44]
    known[836:889] = True
    efficiency = analyze(state)
    values[891:961] = 0
    for option in efficiency.discards:
        row = (891 if option.shanten == efficiency.minimum_shanten else 925) + option.tile
        values[row, list(option.required)] = 1
    if efficiency.best_discard is not None:
        values[959, efficiency.best_discard] = 1
    values[960, list(efficiency.required)] = 1
    known[891:961] = True
    missing = ('maximum_ev_planes_889_890', 'probability_and_ev_horizons_961_1011')
    return Observation(values, known, missing)
