"""Independent conversion of documented action IDs to mjai reactions.

The caller must supply verified legality/guard decisions. This module handles
representation only and is not yet a replacement for a complete rules engine.
"""

from .state import RED, action_tile, tile_index


def _consume(hand, index, count):
    candidates = [tile for tile in hand if tile_index(tile) == index]
    candidates.sort(key=lambda tile: tile not in RED)  # Preserve red bonus in called melds.
    if len(candidates) < count:
        raise ValueError('not enough own tiles for decoded action')
    return candidates[:count]


def decode(action, state, kan_tile=None):
    if state.failed or not state.active:
        raise ValueError('action decoding requires a valid active replay')
    if type(action) is not int or not 0 <= action < 46:
        raise ValueError('invalid four-player action ID')
    if kan_tile is not None and (type(kan_tile) is not int or not 0 <= kan_tile < 34):
        raise ValueError('invalid kan selection ID')
    actor = state.seat
    if action < 37:
        tile = action_tile(action)
        if tile not in state.hand:
            raise ValueError('discard is absent from own hand')
        return {'type': 'dahai', 'actor': actor, 'pai': tile, 'tsumogiri': tile == state.last_draw}
    if action == 37:
        return {'type': 'reach', 'actor': actor}
    if action == 44:
        return {'type': 'ryukyoku'}
    if action == 45:
        return {'type': 'none'}
    if action == 43:
        target = actor if state.last_event['type'] == 'tsumo' and state.last_event['actor'] == actor else state.last_event.get('actor')
        if target is None:
            raise ValueError('winning action has no triggering actor')
        return {'type': 'hora', 'actor': actor, 'target': target}
    if action == 42:
        closed = [i for i in range(34) if sum(tile_index(t) == i for t in state.hand) == 4]
        added = [tile_index(meld['pai']) for meld in state.seats[actor].melds
                 if meld['type'] == 'pon' and any(tile_index(t) == tile_index(meld['pai']) for t in state.hand)]
        if closed or added:
            choices = closed + added
            if kan_tile is None:
                if len(choices) != 1:
                    raise ValueError('kan selection is required')
                kan_tile = choices[0]
            if kan_tile not in choices:
                raise ValueError('invalid kan tile choice')
            if kan_tile in closed:
                return {'type': 'ankan', 'actor': actor, 'consumed': _consume(state.hand, kan_tile, 4)}
            pai = _consume(state.hand, kan_tile, 1)[0]
            pon = next(m for m in state.seats[actor].melds if m['type'] == 'pon' and tile_index(m['pai']) == kan_tile)
            return {'type': 'kakan', 'actor': actor, 'pai': pai, 'consumed': [*pon['consumed'], pon['pai']]}
    if state.last_discard is None:
        raise ValueError('call has no triggering discard')
    discarded = state.last_discard
    index = tile_index(discarded['pai'])
    common = {'actor': actor, 'target': discarded['actor'], 'pai': discarded['pai']}
    if action in (41, 42):
        return {'type': 'pon' if action == 41 else 'daiminkan', **common,
                'consumed': _consume(state.hand, index, 2 if action == 41 else 3)}
    if index >= 27:
        raise ValueError('honors cannot form a sequence')
    low = index - (action - 38)
    if low < 0 or low // 9 != index // 9 or low + 2 >= (index // 9 + 1) * 9:
        raise ValueError('chi crosses a suit boundary')
    consumed = [_consume(state.hand, candidate, 1)[0] for candidate in range(low, low + 3) if candidate != index]
    return {'type': 'chi', **common, 'consumed': consumed}
