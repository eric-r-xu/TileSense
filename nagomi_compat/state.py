"""Independently written, visible-event bookkeeping; no legality implementation.

This module is based on the mjai event contract and black-box fixtures, not a
translation of a reference engine. It deliberately does not infer hidden tiles.
"""

from dataclasses import dataclass, field


TILES = tuple(f'{number}{suit}' for suit in 'mps' for number in range(1, 10)) + ('E', 'S', 'W', 'N', 'P', 'F', 'C')
RED = ('5mr', '5pr', '5sr')
KINDS = {
    'start_game': (), 'start_kyoku': ('bakaze', 'kyoku', 'honba', 'kyotaku', 'oya', 'scores', 'tehais', 'dora_marker'),
    'tsumo': ('actor', 'pai'), 'dahai': ('actor', 'pai', 'tsumogiri'),
    'chi': ('actor', 'target', 'pai', 'consumed'), 'pon': ('actor', 'target', 'pai', 'consumed'),
    'daiminkan': ('actor', 'target', 'pai', 'consumed'), 'ankan': ('actor', 'consumed'),
    'kakan': ('actor', 'pai', 'consumed'), 'dora': ('dora_marker',),
    'reach': ('actor',), 'reach_accepted': ('actor',), 'hora': ('actor', 'target'),
    'ryukyoku': (), 'end_kyoku': (), 'end_game': (), 'none': (),
}


def number(value, low, high):
    if type(value) is not int or not low <= value <= high:
        raise ValueError('invalid integer field')
    return value


def tile_index(tile):
    if not isinstance(tile, str) or tile not in (*TILES, *RED):
        raise ValueError('invalid visible tile')
    return TILES.index(tile[:-1] if tile in RED else tile)


def action_tile(index):
    number(index, 0, 36)
    return TILES[index] if index < 34 else RED[index - 34]


def redact(event, seat):
    number(seat, 0, 3)
    if not isinstance(event, dict) or not isinstance(event.get('type'), str) or event['type'] not in KINDS:
        raise ValueError('unsupported four-player mjai event')
    kind = event['type']
    try:
        clean = {'type': kind, **{key: event[key] for key in KINDS[kind]}}
    except KeyError:
        raise ValueError('missing public event field') from None
    for key in ('actor', 'target', 'oya'):
        if key in clean:
            number(clean[key], 0, 3)
    if kind == 'start_kyoku':
        hands = clean['tehais']
        if not isinstance(hands, list) or len(hands) != 4 or any(not isinstance(h, list) or len(h) != 13 for h in hands):
            raise ValueError('expected four 13-tile hands')
        clean['tehais'] = [list(h) if i == seat else ['?'] * 13 for i, h in enumerate(hands)]
        for tile in clean['tehais'][seat]:
            tile_index(tile)
        if not isinstance(clean['scores'], list) or len(clean['scores']) != 4:
            raise ValueError('expected four scores')
        clean['scores'] = [number(score, -(2**31), 2**31 - 1) for score in clean['scores']]
        for key in ('honba', 'kyotaku'):
            number(clean[key], 0, 255)
        number(clean['kyoku'], 1, 4)
        if clean['bakaze'] not in ('E', 'S', 'W', 'N'):
            raise ValueError('invalid round wind')
    if kind == 'tsumo' and clean['actor'] != seat:
        clean['pai'] = '?'
    for key in ('pai', 'dora_marker'):
        if key in clean and not (kind == 'tsumo' and clean['actor'] != seat):
            tile_index(clean[key])
    if 'consumed' in clean:
        size = {'chi': 2, 'pon': 2, 'daiminkan': 3, 'ankan': 4, 'kakan': 3}[kind]
        if not isinstance(clean['consumed'], list) or len(clean['consumed']) != size:
            raise ValueError('invalid consumed tiles')
        clean['consumed'] = list(clean['consumed'])
        for tile in clean['consumed']:
            tile_index(tile)
    if kind == 'dahai' and type(clean['tsumogiri']) is not bool:
        raise ValueError('invalid tsumogiri')
    return clean


def bonus_tile(indicator):
    index = tile_index(indicator)
    if index < 27:
        return index // 9 * 9 + (index + 1) % 9
    return 27 + (index - 27 + 1) % 4 if index < 31 else 31 + (index - 31 + 1) % 3


@dataclass
class Discard:
    tile: str
    tedashi: bool
    riichi: bool
    bonus: bool
    call: dict | None = None
    kans: list = field(default_factory=list)


@dataclass
class PublicSeat:
    discards: list = field(default_factory=list)
    melds: list = field(default_factory=list)
    declared: bool = False
    accepted: bool = False
    riichi_level: int = 0
    ippatsu: bool = False


class VisibleState:
    def __init__(self, seat, game_length=8):
        self.seat = number(seat, 0, 3)
        if type(game_length) is not int or game_length not in (4, 8):
            raise ValueError('unsupported game length')
        self.game_length = game_length
        self.active = False
        self.hand = []
        self.last_draw = None
        self.last_discard = None
        self.last_event = None
        self.failed = False

    def apply(self, event):
        if self.failed:
            raise ValueError('state rejected an earlier event; create a new replay')
        try:
            return self._apply(event)
        except Exception:
            self.failed = True
            raise

    def _apply(self, event):
        clean = redact(event, self.seat)
        kind = clean['type']
        if self.active and self.ron_window is not None and kind not in ('dora', 'reach_accepted'):
            from .legality import could_ron
            if could_ron(self, self.ron_window):
                self.temporary_furiten = True
                self.riichi_furiten |= self.seats[self.seat].accepted
            self.ron_window = None
        if kind == 'start_kyoku':
            self.round = clean
            self.seats = [PublicSeat() for _ in range(4)]
            dealer_relative = self.relative(clean['oya'])
            self.rivers = [[None] if relative < dealer_relative else [] for relative in range(4)]
            self.next_relative = dealer_relative
            self.pending_calls = [None] * 4
            self.pending_kans = [[] for _ in range(4)]
            self.hand = clean['tehais'][self.seat].copy()
            self.scores = clean['scores'].copy()
            self.sticks = clean['kyotaku']
            self.indicators = [clean['dora_marker']]
            self.last_draw = self.last_discard = None
            self.draws = 0
            self.active = True
            self.has_calls = False
            self.own_draws = 0
            self.temporary_furiten = False
            self.riichi_furiten = False
            self.ron_window = None
            self.replacement_pending = None
            self.rinshan_draw = False
            self.forbidden_discards = set()
            self._refresh_hand_analysis()
            self.keep_discards = ()
            self.improving_discards = ()
        elif kind not in ('start_game', 'end_game', 'hora', 'ryukyoku', 'end_kyoku') and not self.active:
            raise ValueError('event outside a hand')
        if kind == 'tsumo':
            self.draws += 1
            if clean['actor'] == self.seat:
                self.own_draws += 1
                self.forbidden_discards.clear()
                self.rinshan_draw = self.replacement_pending == self.seat
                self.hand.append(clean['pai'])
                self.last_draw = clean['pai']
                self._refresh_discard_analysis()
            self.replacement_pending = None
        elif kind == 'dahai':
            player = self.seats[clean['actor']]
            if player.accepted:
                player.ippatsu = False
            marked = player.declared and not any(d.riichi for d in player.discards)
            index = tile_index(clean['pai'])
            bonus = any(bonus_tile(d) == index for d in self.indicators)
            relative = self.relative(clean['actor'])
            self._align(relative)
            record = Discard(clean['pai'], not clean['tsumogiri'], marked, bonus,
                             self.pending_calls[relative], self.pending_kans[relative])
            player.discards.append(record)
            self.rivers[relative].append(record)
            self.pending_calls[relative] = None
            self.pending_kans[relative] = []
            self.next_relative = (relative + 1) % 4
            if clean['actor'] == self.seat:
                self._remove([clean['pai']])
                self.last_draw = None
                self.forbidden_discards.clear()
                self.temporary_furiten = False
                self._refresh_hand_analysis()
            self.last_discard = clean
        elif kind in ('chi', 'pon', 'daiminkan', 'ankan', 'kakan'):
            self.has_calls = True
            for public in self.seats:
                public.ippatsu = False
            player = self.seats[clean['actor']]
            relative = self.relative(clean['actor'])
            if kind in ('chi', 'pon', 'daiminkan'):
                self._align(relative)
            if kind in ('chi', 'pon'):
                self.pending_calls[relative] = clean.copy()
            else:
                tile = clean['consumed'][0] if kind == 'ankan' else clean['pai']
                self.pending_kans[relative].append(tile)
            if kind == 'kakan':
                matching = [m for m in player.melds if m['type'] == 'pon' and tile_index(m['pai']) == tile_index(clean['pai'])]
                if len(matching) != 1:
                    raise ValueError('added kan has no matching pon')
                position = player.melds.index(matching[0])
                player.melds[position] = {**clean, 'original_pon': matching[0]}
            else:
                player.melds.append(clean.copy())
            if clean['actor'] == self.seat:
                self._remove([clean['pai']] if kind == 'kakan' else clean['consumed'])
                self.last_draw = None
                self._refresh_hand_analysis(update_waits=kind not in ('chi', 'pon'))
                if kind in ('chi', 'pon'):
                    self._refresh_discard_analysis()
                if kind in ('chi', 'pon'):
                    index = tile_index(clean['pai'])
                    self.forbidden_discards = {index}
                    if kind == 'chi':
                        low = min(index, *(tile_index(t) for t in clean['consumed']))
                        other = low + 3 if index == low else low - 1 if index == low + 2 else -1
                        if 0 <= other < 27 and other // 9 == index // 9:
                            self.forbidden_discards.add(other)
            if kind in ('ankan', 'kakan', 'daiminkan'):
                self.replacement_pending = clean['actor']
        elif kind == 'reach':
            player = self.seats[clean['actor']]
            player.riichi_level = 2 if not self.has_calls and not player.discards else 1
            player.declared = True
        elif kind == 'reach_accepted':
            player = self.seats[clean['actor']]
            if player.accepted:
                raise ValueError('duplicate riichi payment')
            player.accepted = True
            player.ippatsu = True
            self.scores[clean['actor']] -= 1000
            self.sticks += 1
        elif kind == 'dora':
            if len(self.indicators) == 5:
                raise ValueError('too many dora indicators')
            self.indicators.append(clean['dora_marker'])
        if kind in ('hora', 'ryukyoku', 'end_kyoku', 'end_game'):
            self.active = False
        if kind in ('dahai', 'ankan', 'kakan') and clean['actor'] != self.seat:
            self.ron_window = clean
            from .legality import could_ron, furiten
            from .hand import complete
            from .yaku import counts_for, own_melds
            index = tile_index(clean['consumed'][0] if kind == 'ankan' else clean['pai'])
            counts = list(counts_for(self))
            if kind != 'ankan' and counts[index] < 4 and not furiten(self) and index in self.stored_waits:
                counts[index] += 1
                if complete(counts, len(own_melds(self))) and not could_ron(self, clean):
                    self.temporary_furiten = True
        if len(self.hand) > 14 or any(sum(tile_index(t) == i for t in self.hand) > 4 for i in range(34)):
            raise ValueError('invalid own hand multiplicity')
        self.last_event = clean
        return clean

    def _remove(self, tiles):
        updated = self.hand.copy()
        try:
            for tile in tiles:
                updated.remove(tile)
        except ValueError:
            raise ValueError('action consumes an unavailable own tile') from None
        self.hand = updated

    def _align(self, relative):
        while self.next_relative != relative:
            self.rivers[self.next_relative].append(None)
            self.next_relative = (self.next_relative + 1) % 4

    def _refresh_hand_analysis(self, update_waits=True):
        from .hand import shanten, waits
        from .yaku import counts_for, own_melds
        from .visibility import visible_counts
        if self.seats[self.seat].accepted:
            return
        counts = counts_for(self)
        melds = len(own_melds(self))
        self.stored_shanten = shanten(counts, melds)
        if not update_waits:
            return
        candidates = set(waits(counts, melds))
        seen = visible_counts(self)
        self.shape_waits = tuple(sorted(candidates))
        self.stored_waits = tuple(sorted(tile for tile in candidates if seen[tile] < 4))

    def _refresh_discard_analysis(self):
        from .hand import shanten
        from .yaku import counts_for, own_melds
        if self.seats[self.seat].accepted:
            return
        counts = counts_for(self)
        keep, improve = [], []
        for index, value in enumerate(counts):
            if not value:
                continue
            after = list(counts)
            after[index] -= 1
            distance = shanten(after, len(own_melds(self)))
            if distance == self.stored_shanten:
                keep.append(index)
            if distance == self.stored_shanten - 1:
                improve.append(index)
        self.keep_discards, self.improving_discards = tuple(keep), tuple(improve)

    def relative(self, actor):
        return (actor - self.seat) % 4
