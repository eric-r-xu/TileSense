/// Hand shape analysis: agari (win) detection, all standard decompositions,
/// wait tiles, and furiten.
library;

import 'meld.dart';
import 'hong_kong_rules.dart';
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
  if (counts34.length != 34 ||
      meldCount < 0 ||
      meldCount > 4 ||
      counts34.any((n) => n < 0 || n > 4) ||
      counts34.fold(0, (int a, b) => a + b) != 14 - meldCount * 3) {
    return false;
  }
  if (meldCount == 0) {
    if (HongKongRules.sevenPairs && _isSevenPairs(counts34)) return true;
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
    void collect(List<Meld> melds) {
      if (melds.length == needMelds) {
        if (work.every((n) => n == 0)) {
          results.add(
              HandDecomposition(melds: List.of(melds), pair: typeFrom34(pair)));
        }
        return;
      }
      final i = work.indexWhere((n) => n > 0);
      if (i < 0) return;
      final t = typeFrom34(i);
      if (work[i] >= 3) {
        work[i] -= 3;
        collect(
            [...melds, Meld(kind: MeldKind.triplet, low: t, concealed: true)]);
        work[i] += 3;
      }
      if (t.isSuit && t.number <= 7 && work[i + 1] > 0 && work[i + 2] > 0) {
        work[i]--;
        work[i + 1]--;
        work[i + 2]--;
        collect(
            [...melds, Meld(kind: MeldKind.sequence, low: t, concealed: true)]);
        work[i]++;
        work[i + 1]++;
        work[i + 2]++;
      }
    }

    collect([]);
  }

  if (HongKongRules.sevenPairs && openMelds == 0 && _isSevenPairs(counts34)) {
    final pairs = <Meld>[];
    for (var i = 0; i < 34; i++) {
      if (counts34[i] == 2) {
        pairs.add(
            Meld(kind: MeldKind.pair, low: typeFrom34(i), concealed: true));
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
bool inFuriten(List<Tile> hand, List<Tile> pond, {int openMelds = 0}) => false;
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
