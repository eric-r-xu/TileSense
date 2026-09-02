/// Hand shape analysis: agari (win) detection, all standard decompositions,
/// wait tiles, and furiten. A pragmatic subset of the Vala client's
/// `source/Game/Logic/TileRules.vala` (`hand_reading_recursion`, `tenpai_tiles`,
/// `winning_hand`, `in_furiten`).
library;

import 'meld.dart';
import 'tile.dart';

const List<int> _kokushiIndices = [
  0, 8, // 1m, 9m
  9, 17, // 1p, 9p
  18, 26, // 1s, 9s
  27, 28, 29, 30, 31, 32, 33, // winds + dragons
];

/// One standard decomposition of a 14-tile hand (concealed part only; the
/// caller's open melds are appended separately for scoring).
class HandDecomposition {
  HandDecomposition({
    required this.melds,
    required this.pair,
    this.sevenPairs = false,
    this.kokushi = false,
  });

  final List<Meld> melds;
  final TileType? pair;
  final bool sevenPairs;
  final bool kokushi;
}

/// True when [counts34] (length 34, indexed man1==0) plus [meldCount] open
/// melds forms a complete hand.
bool isAgari(List<int> counts34, {int meldCount = 0}) {
  if (meldCount == 0) {
    if (_isSevenPairs(counts34)) return true;
    if (_isKokushi(counts34)) return true;
  }
  return _standardComplete(counts34, meldCount);
}

/// Every standard decomposition of the concealed [counts34] (which already
/// contains the winning tile). [openMelds] is the count of the player's calls.
List<HandDecomposition> decompose(List<int> counts34, {int openMelds = 0}) {
  final results = <HandDecomposition>[];
  final needMelds = 4 - openMelds;

  for (var pair = 0; pair < 34; pair++) {
    if (counts34[pair] < 2) continue;
    final work = List<int>.of(counts34);
    work[pair] -= 2;
    final melds = <Meld>[];
    if (_collectMelds(work, 0, needMelds, melds)) {
      results.add(HandDecomposition(
        melds: List<Meld>.of(melds),
        pair: typeFrom34(pair),
      ));
    }
  }

  if (openMelds == 0 && _isSevenPairs(counts34)) {
    final pairs = <Meld>[];
    for (var i = 0; i < 34; i++) {
      if (counts34[i] == 2) {
        pairs.add(Meld(kind: MeldKind.pair, low: typeFrom34(i), concealed: true));
      }
    }
    results.add(HandDecomposition(melds: pairs, pair: null, sevenPairs: true));
  }
  if (openMelds == 0 && _isKokushi(counts34)) {
    results.add(HandDecomposition(melds: const [], pair: null, kokushi: true));
  }

  return results;
}

/// The tiles that complete [hand] (13 concealed tiles) given [openMelds] calls.
List<TileType> waitTiles(List<Tile> hand, {int openMelds = 0}) {
  final base = toCounts34(hand);
  final waits = <TileType>[];
  for (var i = 0; i < 34; i++) {
    if (base[i] >= 4) continue;
    base[i]++;
    if (isAgari(base, meldCount: openMelds)) waits.add(typeFrom34(i));
    base[i]--;
  }
  return waits;
}

/// True when the hand (13 tiles) is one tile from a win.
bool isTenpai(List<Tile> hand, {int openMelds = 0}) =>
    waitTiles(hand, openMelds: openMelds).isNotEmpty;

/// Furiten: any wait tile sits in the player's own discard pond.
bool inFuriten(List<Tile> hand, List<Tile> pond, {int openMelds = 0}) {
  final waits = waitTiles(hand, openMelds: openMelds).toSet();
  if (waits.isEmpty) return false;
  return pond.any((t) => waits.contains(t.type));
}

// --- internals ---------------------------------------------------------------

bool _isSevenPairs(List<int> c) {
  var pairs = 0;
  for (final v in c) {
    if (v == 2) {
      pairs++;
    } else if (v != 0) {
      return false;
    }
  }
  return pairs == 7;
}

bool _isKokushi(List<int> c) {
  var total = 0;
  var hasPair = false;
  for (var i = 0; i < 34; i++) {
    if (!_kokushiIndices.contains(i)) {
      if (c[i] != 0) return false;
      continue;
    }
    if (c[i] == 0) return false;
    if (c[i] >= 2) hasPair = true;
    total += c[i];
  }
  return total == 14 && hasPair;
}

bool _standardComplete(List<int> counts34, int meldCount) {
  for (var pair = 0; pair < 34; pair++) {
    if (counts34[pair] < 2) continue;
    final work = List<int>.of(counts34);
    work[pair] -= 2;
    if (_meldsOnly(work, 0, 4 - meldCount)) return true;
  }
  return false;
}

bool _meldsOnly(List<int> c, int start, int need) {
  if (need == 0) return c.every((v) => v == 0);
  var i = start;
  while (i < 34 && c[i] == 0) {
    i++;
  }
  if (i >= 34) return false;

  if (c[i] >= 3) {
    c[i] -= 3;
    final ok = _meldsOnly(c, i, need - 1);
    c[i] += 3;
    if (ok) return true;
  }
  final t = typeFrom34(i);
  if (t.isSuit && t.number <= 7 && c[i + 1] > 0 && c[i + 2] > 0) {
    c[i]--;
    c[i + 1]--;
    c[i + 2]--;
    final ok = _meldsOnly(c, i, need - 1);
    c[i]++;
    c[i + 1]++;
    c[i + 2]++;
    if (ok) return true;
  }
  return false;
}

bool _collectMelds(List<int> c, int start, int need, List<Meld> acc) {
  if (need == 0) return c.every((v) => v == 0);
  var i = start;
  while (i < 34 && c[i] == 0) {
    i++;
  }
  if (i >= 34) return false;

  final t = typeFrom34(i);

  if (c[i] >= 3) {
    c[i] -= 3;
    acc.add(Meld(kind: MeldKind.triplet, low: t, concealed: true));
    if (_collectMelds(c, i, need - 1, acc)) {
      c[i] += 3;
      return true;
    }
    acc.removeLast();
    c[i] += 3;
  }

  if (t.isSuit && t.number <= 7 && c[i + 1] > 0 && c[i + 2] > 0) {
    c[i]--;
    c[i + 1]--;
    c[i + 2]--;
    acc.add(Meld(kind: MeldKind.sequence, low: t, concealed: true));
    if (_collectMelds(c, i, need - 1, acc)) {
      c[i]++;
      c[i + 1]++;
      c[i + 2]++;
      return true;
    }
    acc.removeLast();
    c[i]++;
    c[i + 1]++;
    c[i + 2]++;
  }

  return false;
}
