"""Outcome-aware action labels. Future events supply labels, never features."""

from collections import Counter, defaultdict, deque
import gzip
import hashlib
import json

import numpy as np

from .encoding import VisibleEncoder, base_tile, load_engine, tile_id


EXTRACTOR_VERSION = 'tilesense-outcome-labels-v1'
ANNOUNCEMENTS = ('reach_accepted', 'dora')


def read_game(path):
    events = []
    # Bound local input size, including decompressed log lines.
    with gzip.open(path, 'rt', encoding='utf-8') as source:
        total = 0
        while True:
            line = source.readline(65537)
            if not line:
                break
            total += len(line)
            if len(line) > 65536 or len(events) >= 20000 or total > 16 * 1024 * 1024:
                raise ValueError('log exceeds extraction limits')
            event = json.loads(line)
            if not isinstance(event, dict) or not isinstance(event.get('type'), str):
                raise ValueError('invalid log event')
            events.append(event)
    if not events or events[-1].get('type') != 'end_game':
        raise ValueError('expected a complete game log')
    return events


def immediate_label(event, seat):
    if event.get('actor') != seat:
        return None
    kind = event.get('type')
    if kind == 'dahai':
        return tile_id(event['pai'])
    if kind == 'chi':
        called = base_tile(event['pai'])
        consumed = [base_tile(tile) for tile in event['consumed']]
        return 38 if called < min(consumed) else 39 if called < max(consumed) else 40
    return {'reach': 37, 'pon': 41, 'daiminkan': 42, 'ankan': 42,
            'kakan': 42, 'hora': 43, 'nukidora': 46}.get(kind)


def resolve_label(events, index, seat, cans):
    """Return (label, outcome index, reason); censor unobservable lost calls.

    A losing call in a log does not tell us whether another seat declined a
    lower-priority action. Such cases must not become invented pass targets.
    """
    following = index + 1
    while following < len(events) and events[following]['type'] in ANNOUNCEMENTS:
        following += 1
    if following >= len(events):
        return None, following, 'no_continuation'
    event = events[following]
    kind = event['type']
    if kind == 'hora':
        cursor = following
        while cursor < len(events) and events[cursor]['type'] in ('hora', *ANNOUNCEMENTS):
            if events[cursor]['type'] == 'hora' and events[cursor]['actor'] == seat:
                return 43, cursor, 'win'
            cursor += 1
        return None, following, 'interrupted_by_win'
    label = immediate_label(event, seat)
    if label is not None:
        return label, following, 'self_action'
    if kind == 'ryukyoku':
        return (44, following, 'abortive_draw') if cans.can_ryukyoku else (None, following, 'terminal_draw')
    if kind == 'tsumo' and cans.can_pass:
        return 45, following, 'declined_call'
    if kind in ('chi', 'pon', 'daiminkan') and cans.can_pass:
        # Ron/pon/kan would beat another seat's chi. Chi loses to pon/kan.
        if kind != 'chi' and cans.can_chi:
            return None, following, 'censored_lower_priority_call'
        if kind != 'chi' and (cans.can_pon or cans.can_daiminkan):
            players = len(next(e['scores'] for e in reversed(events[:index + 1])
                               if e['type'] == 'start_kyoku'))
            if (seat - event['target']) % players > (event['actor'] - event['target']) % players:
                return None, following, 'censored_lower_priority_call'
        return 45, following, 'declined_higher_priority_call'
    return None, following, 'unresolved_continuation'


def verify_engine_labels(ruleset, events, rows):
    """Compare retained labels/masks at identical legacy observation positions."""
    module = load_engine(ruleset)
    loader = module.dataset.GameplayLoader(version=module.consts.MAX_VERSION,
                                           oracle=False, always_include_kan_select=True)
    games = loader.load_log('\n'.join(json.dumps(event) for event in events))
    result = Counter()
    for game in games:
        by_position = defaultdict(deque)
        actions, masks, observations = game.take_actions(), game.take_masks(), game.take_obs()
        for action, mask, obs in zip(actions, masks, observations):
            by_position[hashlib.sha256(obs.tobytes()).hexdigest()].append((action, mask))
        seat = game.take_player_id()
        for row in (row for row in rows if row['seat'] == seat):
            matches = by_position[row['reference_digest']]
            if not matches:
                result['missing_reference'] += 1
                continue
            action, mask = matches.popleft()
            result['compared'] += 1
            result['label_mismatches'] += action != row['label']
            result['mask_mismatches'] += not np.array_equal(mask, row['inputs'][-1])
        result['reference_only'] += sum(len(values) for values in by_position.values())
    if any(result[key] for key in ('missing_reference', 'label_mismatches', 'mask_mismatches')):
        raise ValueError(f'engine reference disagreement: {dict(result)}')
    return dict(result)


def replay_samples(ruleset, events, game_length=None, *, include_outcomes=False,
                   verify_reference=False, stats=None):
    players = 3 if ruleset == 'sanma' else 4
    rows = []
    checked = 0
    counts = Counter()
    ranks = None
    if include_outcomes:
        # Outcome labels are obtained separately; raw future events never enter
        # the seat-visible encoder. Delegate tie/deposit rules to the engine.
        grp = load_engine(ruleset).dataset.Grp.load_log('\n'.join(json.dumps(e) for e in events))
        ranks = list(grp.take_rank_by_player())
    for seat in range(players):
        encoder = VisibleEncoder(ruleset, seat, game_length)
        for index, event in enumerate(events):
            encoder.update(event)
            checked += 1
            if index + 1 >= len(events) or not encoder.active or not encoder.state.last_cans.can_act:
                continue
            label, outcome_index, reason = resolve_label(events, index, seat, encoder.state.last_cans)
            counts[reason] += 1
            if label is None:
                continue
            inputs = encoder.snapshot(reference=verify_reference)
            if label >= len(inputs[-1]) or not inputs[-1][label]:
                raise ValueError('logged label is outside the engine legal mask')
            rows.append({'inputs': inputs, 'label': label, 'seat': seat, 'event_index': index,
                         'kan_select': False, 'label_reason': reason, 'outcome_index': outcome_index})
            if verify_reference:
                rows[-1]['reference_digest'] = encoder.reference_digest
            if label == 42:
                action = events[outcome_index]
                tile = action['consumed'][0] if action['type'] == 'ankan' else action['pai']
                selected = base_tile(tile)
                inputs = encoder.snapshot(at_kan_select=True, reference=verify_reference)
                if not inputs[-1][selected]:
                    raise ValueError('kan selection label is outside the engine legal mask')
                rows.append({'inputs': inputs, 'label': selected, 'seat': seat, 'event_index': index,
                             'kan_select': True, 'label_reason': 'kan_selection', 'outcome_index': outcome_index})
                if verify_reference:
                    rows[-1]['reference_digest'] = encoder.reference_digest
    if ranks is not None:
        for row in rows:
            row['final_rank'] = ranks[row['seat']]
    if stats is not None:
        stats.update({'extractor_version': EXTRACTOR_VERSION, 'decisions': dict(counts),
                      'labels': dict(Counter(str(row['label']) for row in rows))})
    if verify_reference:
        comparison = verify_engine_labels(ruleset, events, rows)
        if stats is not None:
            stats['reference'] = comparison
    return rows, checked


def stack_rows(rows):
    if not rows:
        raise ValueError('replay generated no labeled decisions')
    inputs = tuple(np.stack([row['inputs'][column] for row in rows]) for column in range(5))
    labels = np.array([row['label'] for row in rows], dtype=np.int64)
    return inputs, labels
