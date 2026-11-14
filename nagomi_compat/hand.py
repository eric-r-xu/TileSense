"""Independent hand mathematics via bounded suit-partition dynamic programming.

No reference implementation, tables or generated reference results are used.
Standard shanten is the minimum incomplete-block cost over suit frontiers;
seven pairs and thirteen orphans are evaluated as separate closed-hand shapes.
"""

from functools import lru_cache
from itertools import product


ORPHANS = (0, 8, 9, 17, 18, 26, 27, 28, 29, 30, 31, 32, 33)


def _frontier(states):
    # For a fixed head count, more complete and incomplete blocks dominate.
    return tuple(sorted(s for s in states if not any(
        t != s and t[2] == s[2] and t[0] >= s[0] and t[1] >= s[1] for t in states)))


@lru_cache(maxsize=150000)
def _suit(counts, suited, paired=0):
    if not any(counts):
        return ((0, 0, 0),)
    index = next(i for i, value in enumerate(counts) if value)
    alternatives = [((index,), (0, 0, 0))]
    if counts[index] >= 3:
        alternatives.append(((index,) * 3, (1, 0, 0)))
    if counts[index] >= 2 and not paired & (1 << index):
        alternatives.extend([((index,) * 2, (0, 1, 0)), ((index,) * 2, (0, 0, 1))])
    if suited:
        if index <= 6 and counts[index + 1] and counts[index + 2]:
            alternatives.append(((index, index + 1, index + 2), (1, 0, 0)))
        for delta in (1, 2):
            if index + delta < 9 and counts[index + delta]:
                alternatives.append(((index, index + delta), (0, 1, 0)))
    states = set()
    for removed, added in alternatives:
        remaining = list(counts)
        for tile in removed:
            remaining[tile] -= 1
        # Two pairs of the same tile would need a fifth copy to become a
        # triplet and head (or six copies to become two triplets).
        next_paired = paired | (1 << index) if len(removed) == 2 and removed[0] == removed[1] else paired
        for melds, partials, head in _suit(tuple(remaining), suited, next_paired):
            candidate = melds + added[0], partials + added[1], head + added[2]
            if candidate[0] + candidate[1] <= 4 and candidate[2] <= 1:
                states.add(candidate)
    return _frontier(states)


def validate(counts, melds=0):
    if (len(counts) != 34 or type(melds) is not int or not 0 <= melds <= 4
            or any(type(value) is not int or not 0 <= value <= 4 for value in counts)
            or sum(counts) > 14 - 3 * melds):
        raise ValueError('invalid hand counts or meld count')


@lru_cache(maxsize=100000)
def _shanten(counts, open_melds):
    frontier = ((0, 0, 0),)
    for begin, end, suited in ((0, 9, True), (9, 18, True), (18, 27, True), (27, 34, False)):
        states = set()
        for a, b in product(frontier, _suit(counts[begin:end], suited)):
            candidate = tuple(x + y for x, y in zip(a, b))
            if candidate[0] + open_melds <= 4 and candidate[2] <= 1:
                states.add(candidate)
        frontier = _frontier(states)
    result = min(8 - 2 * (m + open_melds) - min(t, 4 - m - open_melds) - h for m, t, h in frontier)
    if open_melds == 0:
        pairs = sum(value >= 2 for value in counts)
        distinct = sum(value > 0 for value in counts)
        result = min(result, 6 - pairs + max(0, 7 - distinct),
                     13 - sum(counts[i] > 0 for i in ORPHANS) - int(any(counts[i] >= 2 for i in ORPHANS)))
    # Block counts alone can mistake a triplet plus its fourth copy for a
    # single-tile head wait. A fifth identical tile cannot complete that hand.
    if result == 0 and sum(counts) == 13 - 3 * open_melds and not _waits(counts, open_melds):
        result = 1
    return result


def shanten(counts, melds=0):
    counts = tuple(counts)
    validate(counts, melds)
    return _shanten(counts, melds)


@lru_cache(maxsize=100000)
def _groups(counts, needed):
    if not any(counts):
        return ((),) if needed == 0 else ()
    if needed <= 0 or sum(counts) != 3 * needed:
        return ()
    index = next(i for i, value in enumerate(counts) if value)
    answers = []
    if counts[index] >= 3:
        rest = list(counts)
        rest[index] -= 3
        answers.extend((('triplet', index), *groups) for groups in _groups(tuple(rest), needed - 1))
    if index < 27 and index % 9 <= 6 and counts[index + 1] and counts[index + 2]:
        rest = list(counts)
        for tile in (index, index + 1, index + 2):
            rest[tile] -= 1
        answers.extend((('sequence', index), *groups) for groups in _groups(tuple(rest), needed - 1))
    return tuple(answers)


@lru_cache(maxsize=50000)
def _decompositions(counts, melds=0):
    if sum(counts) != 14 - 3 * melds:
        return ()
    answers = []
    for pair, value in enumerate(counts):
        if value < 2:
            continue
        rest = list(counts)
        rest[pair] -= 2
        answers.extend((pair, groups) for groups in _groups(tuple(rest), 4 - melds))
    return tuple(answers)


def decompositions(counts, melds=0):
    counts = tuple(counts)
    validate(counts, melds)
    return _decompositions(counts, melds)


def complete(counts, melds=0):
    counts = tuple(counts)
    validate(counts, melds)
    if sum(counts) != 14 - 3 * melds:
        return False
    if melds == 0:
        if sum(value == 2 for value in counts) == 7:
            return True
        if all(counts[i] for i in ORPHANS) and any(counts[i] == 2 for i in ORPHANS):
            return True
    return bool(decompositions(counts, melds))


@lru_cache(maxsize=100000)
def _waits(counts, melds=0):
    if sum(counts) != 13 - 3 * melds:
        return ()
    result = []
    for index, value in enumerate(counts):
        if value == 4:
            continue
        candidate = list(counts)
        candidate[index] += 1
        if complete(candidate, melds):
            result.append(index)
    return tuple(result)


def waits(counts, melds=0):
    counts = tuple(counts)
    validate(counts, melds)
    return _waits(counts, melds)
