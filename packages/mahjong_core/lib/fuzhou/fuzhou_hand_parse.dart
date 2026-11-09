/// Fuzhou hand-shape analysis: five melds and a pair (17 tiles), with the
/// Gold tiles standing in for any tile at all.
///
/// A hand's tiles split into the natural tiles (a 34-slot count array, as the
/// rest of the engine uses) and a count of wilds. Whether the hand is complete
/// is a search over the naturals that spends wilds where a block is short;
/// every natural must land in a block, and whatever wilds are left over fill
/// whole blocks themselves, so the totals only have to agree.
///
/// Two substitutions let the search skip branches without losing answers: a
/// block takes as many natural tiles of its type as the hand has (a wild used
/// where a natural was available can always be swapped with it), and a run is
/// tried at each alignment around the lowest natural tile.
library;

import '../tile.dart';
import 'fuzhou_rules.dart';

/// A hand split for Gold: the natural tiles and the wild count.
typedef FuzhouTiles = ({List<int> counts, int wilds});

/// Splits [tiles] into natural counts and wilds. A tile whose type is in
/// [goldTypes] is a wild; a flower that is not Gold is not part of the hand.
FuzhouTiles splitGold(Iterable<Tile> tiles, Set<TileType> goldTypes) {
  final counts = List<int>.filled(34, 0);
  var wilds = 0;
  for (final t in tiles) {
    if (goldTypes.contains(t.type)) {
      wilds++;
    } else if (t.type.isPlayingTile) {
      counts[t.type.index - 1]++;
    }
  }
  return (counts: counts, wilds: wilds);
}

/// True when [counts34] plus [wilds] and [meldCount] open melds make a
/// complete hand: five melds and a pair. [allowTriplets] false asks for
/// sequences only ("All Sequences"); [needPair] false asks for the melds
/// alone, with the pair set aside.
bool isAgariFuzhou(
  List<int> counts34, {
  int wilds = 0,
  int meldCount = 0,
  bool allowTriplets = true,
  bool needPair = true,
}) =>
    _fits(List<int>.of(counts34), wilds, 5 - meldCount, needPair,
        allowTriplets);

bool _fits(List<int> c, int w, int melds, bool pair, bool triplets) {
  if (melds < 0 || w < 0) return false;
  var i = 0;
  while (i < 34 && c[i] == 0) {
    i++;
  }
  // Every natural is placed: what is left over must be exactly the wilds the
  // remaining blocks call for.
  if (i == 34) return w == melds * 3 + (pair ? 2 : 0);

  final n = c[i];
  if (pair) {
    if (n >= 2) {
      c[i] -= 2;
      final ok = _fits(c, w, melds, false, triplets);
      c[i] += 2;
      if (ok) return true;
    } else if (w >= 1) {
      c[i] -= 1;
      final ok = _fits(c, w - 1, melds, false, triplets);
      c[i] += 1;
      if (ok) return true;
    }
  }
  if (melds == 0) return false;

  if (triplets) {
    final k = n < 3 ? n : 3;
    if (w >= 3 - k) {
      c[i] -= k;
      final ok = _fits(c, w - (3 - k), melds - 1, pair, triplets);
      c[i] += k;
      if (ok) return true;
    }
  }

  final t = typeFrom34(i);
  if (t.isSuit) {
    final base = i - (t.number - 1);
    final p = t.number - 1; // 0..8 within the suit
    for (var q = p - 2; q <= p; q++) {
      if (q < 0 || q + 2 > 8) continue;
      var need = 0;
      final taken = <int>[];
      for (var j = q; j <= q + 2; j++) {
        if (c[base + j] > 0) {
          taken.add(base + j);
        } else {
          need++;
        }
      }
      if (need > w) continue;
      for (final x in taken) {
        c[x]--;
      }
      final ok = _fits(c, w - need, melds - 1, pair, triplets);
      for (final x in taken) {
        c[x]++;
      }
      if (ok) return true;
    }
  }
  return false;
}

/// True when [tiles] plus [openMelds] calls make a complete Fuzhou hand under
/// [goldTypes] (17 tiles less 3 per call).
bool isAgariFuzhouTiles(Iterable<Tile> tiles,
    {int openMelds = 0, Set<TileType> goldTypes = const {}}) {
  final s = splitGold(tiles, goldTypes);
  return isAgariFuzhou(s.counts, wilds: s.wilds, meldCount: openMelds);
}

/// The tiles that complete [hand] (16 concealed tiles, less 3 per call).
///
/// Every suit tile that is not Gold is a candidate, and so is the Gold itself:
/// drawing one adds a wild, which finishes any ready hand. That is why a
/// ready hand's waits always include the Gold types.
List<TileType> waitTilesFuzhou(List<Tile> hand,
    {int openMelds = 0, Set<TileType> goldTypes = const {}}) {
  final s = splitGold(hand, goldTypes);
  final waits = <TileType>[];
  for (var i = 0; i < 27; i++) {
    final type = typeFrom34(i);
    if (goldTypes.contains(type) || s.counts[i] >= 4) continue;
    s.counts[i]++;
    if (isAgariFuzhou(s.counts, wilds: s.wilds, meldCount: openMelds)) {
      waits.add(type);
    }
    s.counts[i]--;
  }
  if (goldTypes.isNotEmpty &&
      isAgariFuzhou(s.counts, wilds: s.wilds + 1, meldCount: openMelds)) {
    waits.addAll(goldTypes.toList()..sort((a, b) => a.index - b.index));
  }
  return waits;
}

/// True when the hand is one tile from a win.
bool isTenpaiFuzhou(List<Tile> hand,
        {int openMelds = 0, Set<TileType> goldTypes = const {}}) =>
    waitTilesFuzhou(hand, openMelds: openMelds, goldTypes: goldTypes)
        .isNotEmpty;

/// Which of the Gold specials a complete hand earns, given its [wilds]: the
/// best of Golden Dragon (three golds as a triplet), Three Gold Knockdown
/// (any three golds) and Golden Pair (two golds as the pair). They do not
/// stack. Null when none applies.
({String name, int points})? goldSpecial(
    List<int> counts34, int wilds, int meldCount) {
  if (wilds >= 3 &&
      isAgariFuzhou(counts34, wilds: wilds - 3, meldCount: meldCount + 1)) {
    return (name: 'Golden Dragon', points: FuzhouRules.goldenDragon);
  }
  if (wilds >= 3) {
    return (
      name: 'Three Gold Knockdown',
      points: FuzhouRules.threeGoldKnockdown
    );
  }
  if (wilds >= 2 &&
      isAgariFuzhou(counts34,
          wilds: wilds - 2, meldCount: meldCount, needPair: false)) {
    return (name: 'Golden Pair', points: FuzhouRules.goldenPair);
  }
  return null;
}
