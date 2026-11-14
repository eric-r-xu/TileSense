"""Physical visible-tile accounting, avoiding called-discard double counting."""

from .state import tile_index


def visible_tiles(state):
    result = list(state.hand) + list(state.indicators)
    for player in state.seats:
        result.extend(discard.tile for discard in player.discards)
        for meld in player.melds:
            if meld['type'] == 'kakan':
                result.extend(meld['original_pon']['consumed'])
                result.append(meld['pai'])
            else:
                result.extend(meld['consumed'])
    return result


def visible_counts(state):
    result = [0] * 34
    for tile in visible_tiles(state):
        result[tile_index(tile)] += 1
    return tuple(result)
