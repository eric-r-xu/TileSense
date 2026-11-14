"""Seat-visible mjai encoding, shared by replay and inference.

The rules engine owns the hand, waits, furiten and legality. The accumulator
below summarizes public events; it does not infer hidden tiles or game rules.
"""

from collections import deque
import hashlib
import importlib
import json
from pathlib import Path
import sys

import numpy as np

from .audit import ROOT, sha256


TILES = tuple(f'{rank}{suit}' for suit in 'mps' for rank in range(1, 10)) + ('E', 'S', 'W', 'N', 'P', 'F', 'C')
TILE_IDS = {tile: i for i, tile in enumerate(TILES)}
TILE_IDS.update({'5mr': 34, '5pr': 35, '5sr': 36})
EVENT_IDS = {kind: i + 1 for i, kind in enumerate((
    'start_kyoku', 'tsumo', 'dahai', 'chi', 'pon', 'daiminkan', 'ankan', 'kakan',
    'nukidora', 'dora', 'reach', 'reach_accepted', 'hora', 'ryukyoku', 'end_kyoku'))}
FIELDS = {
    'start_game': (), 'end_game': (), 'end_kyoku': (), 'none': (),
    'start_kyoku': ('bakaze', 'dora_marker', 'kyoku', 'honba', 'kyotaku', 'oya', 'scores', 'tehais'),
    'tsumo': ('actor', 'pai'), 'dahai': ('actor', 'pai', 'tsumogiri'),
    'chi': ('actor', 'target', 'pai', 'consumed'), 'pon': ('actor', 'target', 'pai', 'consumed'),
    'daiminkan': ('actor', 'target', 'pai', 'consumed'), 'ankan': ('actor', 'consumed'),
    'kakan': ('actor', 'pai', 'consumed'), 'nukidora': ('actor', 'pai'),
    'dora': ('dora_marker',), 'reach': ('actor',), 'reach_accepted': ('actor',),
    'hora': ('actor', 'target'), 'ryukyoku': (),
}


def integer(value, low, high, field):
    if type(value) is not int or not low <= value <= high:
        raise ValueError(f'invalid {field}')
    return value


def tile_id(tile, unknown=False):
    if unknown and tile == '?':
        return -1
    if not isinstance(tile, str) or tile not in TILE_IDS:
        raise ValueError('invalid tile')
    return TILE_IDS[tile]


def base_tile(tile):
    index = tile_id(tile)
    return (4, 13, 22)[index - 34] if index >= 34 else index


def visible_event(event, seat, players):
    """Allowlist fields and hide private values before any state/feature update."""
    if not isinstance(event, dict) or not isinstance(event.get('type'), str) or event['type'] not in FIELDS:
        raise ValueError('unsupported mjai event')
    integer(players, 3, 4, 'players')
    integer(seat, 0, players - 1, 'seat')
    kind = event['type']
    if players == 3 and kind == 'chi':
        raise ValueError('chi is unavailable in sanma')

    def check_tile(tile, unknown=False):
        index = tile_id(tile, unknown)
        if players == 3 and (index in range(1, 8) or index == 34):
            raise ValueError('tile is unavailable in sanma')

    try:
        clean = {'type': kind, **{field: event[field] for field in FIELDS[kind]}}
    except KeyError:
        raise ValueError('missing mjai field') from None
    for field in ('actor', 'target', 'oya'):
        if field in clean:
            integer(clean[field], 0, players - 1, field)
    if kind == 'start_kyoku':
        hands = clean['tehais']
        if (not isinstance(hands, list) or len(hands) != players
                or any(not isinstance(hand, list) or len(hand) != 13 for hand in hands)):
            raise ValueError('expected one 13-tile hand per seat')
        clean['tehais'] = [list(hand) if i == seat else ['?'] * 13 for i, hand in enumerate(hands)]
        for tile in clean['tehais'][seat]:
            check_tile(tile)
        if clean['bakaze'] not in ('E', 'S', 'W', 'N'):
            raise ValueError('invalid round wind')
        integer(clean['kyoku'], 1, players, 'kyoku')
        for field in ('honba', 'kyotaku'):
            integer(clean[field], 0, 255, field)
        if not isinstance(clean['scores'], list) or len(clean['scores']) != players:
            raise ValueError('invalid scores')
        clean['scores'] = [integer(score, -(2**31), 2**31 - 1, 'score') for score in clean['scores']]
    if kind == 'tsumo' and clean['actor'] != seat:
        clean['pai'] = '?'
    for field in ('pai', 'dora_marker'):
        if field in clean:
            check_tile(clean[field], unknown=kind == 'tsumo' and clean['actor'] != seat)
    if 'consumed' in clean:
        expected = {'chi': 2, 'pon': 2, 'daiminkan': 3, 'ankan': 4, 'kakan': 3}[kind]
        if not isinstance(clean['consumed'], list) or len(clean['consumed']) != expected:
            raise ValueError('invalid consumed tiles')
        clean['consumed'] = list(clean['consumed'])
        for tile in clean['consumed']:
            check_tile(tile)
    if kind == 'dahai' and type(clean['tsumogiri']) is not bool:
        raise ValueError('invalid tsumogiri flag')
    return clean


def load_engine(ruleset):
    if ruleset not in ('sanma', 'nagomi'):
        raise ValueError('unsupported ruleset')
    folder = ROOT / 'mortal_sidecar' / ('sanma' if ruleset == 'sanma' else '')
    binary = folder / 'libriichi.so'
    if not binary.is_file():
        raise FileNotFoundError('build the pinned libriichi library before replaying games')
    existing = sys.modules.get('libriichi')
    if existing is not None and Path(existing.__file__).resolve() != binary.resolve():
        raise ValueError('run each ruleset in a separate Python process')
    if existing is None:
        sys.path.insert(0, str(folder))
    module = existing or importlib.import_module('libriichi')
    if module.consts.ACTION_SPACE != (47 if ruleset == 'sanma' else 46):
        raise ValueError('ruleset/library action space mismatch')
    return module


def engine_provenance(ruleset):
    module = load_engine(ruleset)
    manifest_name = 'model_sanma.json' if ruleset == 'sanma' else 'model_nagomi.json'
    manifest = json.loads((ROOT / 'mortal_sidecar' / manifest_name).read_text())
    return {'binary_sha256': sha256(Path(module.__file__)),
            'expected_source_commit': manifest['mortal_commit'],
            'binary_source_linkage': 'existing local build; source linkage not independently attested'}


def validate_inputs(inputs, players):
    shapes = ((34, 20), (40,), (128, 4), (128,), (47 if players == 3 else 46,))
    dtypes = (np.float32, np.float32, np.int64, np.bool_, np.bool_)
    for value, shape, dtype in zip(inputs, shapes, dtypes):
        if not isinstance(value, np.ndarray) or value.shape != shape or value.dtype != dtype:
            raise ValueError('invalid observation shape or dtype')
        if not np.isfinite(value).all():
            raise ValueError('nonfinite observation')
    if len(inputs) != 5 or not inputs[-1].any():
        raise ValueError('expected five inputs and at least one legal action')
    for column, size in enumerate((16, players + 1, 38, 8)):
        if np.any(inputs[2][:, column] < 0) or np.any(inputs[2][:, column] >= size):
            raise ValueError('history token out of range')
    if np.any(inputs[2][~inputs[3]]):
        raise ValueError('history padding must be zero')


class VisibleEncoder:
    """One acting seat, compact engine seat IDs, one game length, one ruleset."""

    def __init__(self, ruleset, seat, game_length=None):
        self.ruleset = ruleset
        self.players = 3 if ruleset == 'sanma' else 4
        integer(seat, 0, self.players - 1, 'seat')
        self.seat = seat
        self.game_length = game_length if game_length is not None else 2 * self.players
        if self.game_length not in (self.players, 2 * self.players):
            raise ValueError('invalid game length')
        self.engine = load_engine(ruleset)
        self.state = self.engine.state.PlayerState(seat, game_length=self.game_length)
        self.history = deque(maxlen=128)
        self.active = False

    def rel(self, actor):
        return (actor - self.seat) % self.players

    def update(self, event):
        clean = visible_event(event, self.seat, self.players)
        kind = clean['type']
        if kind not in ('start_game', 'start_kyoku', 'end_kyoku', 'end_game', 'hora', 'ryukyoku') and not self.active:
            raise ValueError('event outside an active hand')
        try:
            self.state.update(json.dumps(clean, allow_nan=False))
        except Exception:
            # Engine diagnostics may contain hand contents. Do not relay them.
            raise ValueError(f'rules engine rejected {kind}') from None
        if kind == 'start_kyoku':
            self.active = True
            self.history.clear()
            self.public = np.zeros(34, dtype=np.float32)
            self.public_red = np.zeros(34, dtype=np.float32)
            self.discards = np.zeros((4, 34), dtype=np.float32)
            self.after_reach = np.zeros((4, 34), dtype=np.float32)
            self.melds = np.zeros((4, 34), dtype=np.float32)
            self.indicators = np.zeros(34, dtype=np.float32)
            self.kitas = np.zeros(4, dtype=np.float32)
            self.declared = np.zeros(4, dtype=np.float32)
            self.accepted = np.zeros(4, dtype=np.float32)
            self.scores = np.zeros(4, dtype=np.float32)
            for actor, score in enumerate(clean['scores']):
                self.scores[self.rel(actor)] = score
            self.round = clean
            self.draws = 0
            self.indicators[base_tile(clean['dora_marker'])] += 1
            if tile_id(clean['dora_marker']) >= 34:
                self.public_red[base_tile(clean['dora_marker'])] += 1
        actor = self.rel(clean['actor']) if 'actor' in clean else None
        if kind == 'tsumo':
            self.draws += 1
        elif kind == 'dahai':
            index = base_tile(clean['pai'])
            self.discards[actor, index] += 1
            self.after_reach[actor, index] += self.declared[actor]
            self._reveal([clean['pai']])
        elif kind in ('chi', 'pon', 'daiminkan'):
            self._reveal(clean['consumed'])
            for tile in [*clean['consumed'], clean['pai']]:
                self.melds[actor, base_tile(tile)] += 1
        elif kind == 'ankan':
            self._reveal(clean['consumed'])
            for tile in clean['consumed']:
                self.melds[actor, base_tile(tile)] += 1
        elif kind == 'kakan':
            self._reveal([clean['pai']])
            self.melds[actor, base_tile(clean['pai'])] += 1
        elif kind == 'nukidora':
            self._reveal([clean['pai']])
            self.kitas[actor] += 1
        elif kind == 'dora':
            self.indicators[base_tile(clean['dora_marker'])] += 1
            if tile_id(clean['dora_marker']) >= 34:
                self.public_red[base_tile(clean['dora_marker'])] += 1
        elif kind == 'reach':
            self.declared[actor] = 1
        elif kind == 'reach_accepted':
            self.accepted[actor] = 1
            self.scores[actor] -= 1000
        if kind in EVENT_IDS:
            tile = clean.get('pai', clean.get('dora_marker'))
            if kind == 'ankan':
                tile = clean['consumed'][0]
            token = 0 if tile is None or tile == '?' else tile_id(tile) + 1
            flags = int(clean.get('tsumogiri', False))
            self.history.append([EVENT_IDS[kind], 0 if actor is None else actor + 1, token, flags])
        if kind in ('end_kyoku', 'end_game', 'hora', 'ryukyoku'):
            self.active = False
        return clean

    def _reveal(self, tiles):
        for tile in tiles:
            self.public[base_tile(tile)] += 1
            if tile_id(tile) >= 34:
                self.public_red[base_tile(tile)] += 1

    def snapshot(self, at_kan_select=False, reference=False):
        if type(at_kan_select) is not bool or not self.active or not self.state.last_cans.can_act:
            raise ValueError('snapshot requires an active decision')
        cans = self.state.last_cans
        if at_kan_select and not cans.can_kan:
            raise ValueError('kan selection outside a kan decision')
        # Reuse only the engine's legal mask. Legacy feature planes are discarded.
        legacy, mask = self.state.encode_obs(self.engine.consts.MAX_VERSION, at_kan_select)
        if reference:
            self.reference_digest = hashlib.sha256(legacy.tobytes()).hexdigest()
        # pyo3 exposes [u8; 34] as bytes in the pinned builds.
        hand = np.array(list(self.state.tehai), dtype=np.float32)
        own_red = np.zeros(34, dtype=np.float32)
        for index, present in zip((4, 13, 22), self.state.akas_in_hand):
            own_red[index] = present
        tiles = np.zeros((34, 20), dtype=np.float32)
        tiles[:, 0] = hand / 4
        tiles[:, 1] = own_red
        tiles[:, 2] = (hand + self.public + self.indicators) / 4
        tiles[:, 3] = self.indicators / 5
        tiles[:, 4] = self.state.waits
        tiles[:, 5] = 1
        if self.players == 3:
            tiles[1:8, 5] = 0
        tiles[:, 6:10] = self.discards.T / 4
        tiles[:, 10:14] = self.melds.T / 4
        tiles[:, 14] = own_red + self.public_red
        last_draw = self.state.last_self_tsumo()
        if last_draw is not None:
            tiles[base_tile(last_draw), 15] = 1
        tiles[:, 16:20] = self.after_reach.T / 4
        context = np.zeros(40, dtype=np.float32)
        context[:4] = np.clip(self.scores / 100000, -1, 1)
        context[4 + self.rel(self.round['oya'])] = 1
        context[8 + ('E', 'S', 'W', 'N').index(self.round['bakaze'])] = 1
        context[12] = self.round['kyoku'] / self.players
        context[13] = min(self.state.honba / 10, 1)
        context[14] = min(self.state.kyotaku / 10, 1)
        wall = 55 if self.players == 3 else 70
        context[15] = max(wall - self.draws, 0) / wall
        context[16] = self.game_length / 8
        context[17] = self.state.at_furiten
        context[18] = self.state.shanten / 8
        context[19] = at_kan_select
        context[20:24] = self.kitas / 4
        context[24:28] = self.declared
        context[28:32] = self.accepted
        context[32 + (self.seat - self.round['oya']) % self.players] = 1
        context[36:36 + self.players] = 1
        history = np.zeros((128, 4), dtype=np.int64)
        history_mask = np.zeros(128, dtype=np.bool_)
        history[:len(self.history)] = list(self.history)
        history_mask[:len(self.history)] = True
        inputs = tiles, context, history, history_mask, np.asarray(mask, dtype=np.bool_).copy()
        validate_inputs(inputs, self.players)
        return inputs


def encode_prefix(ruleset, seat, events, game_length=None, at_kan_select=False):
    encoder = VisibleEncoder(ruleset, seat, game_length)
    for event in events:
        encoder.update(event)
    return encoder.snapshot(at_kan_select)
