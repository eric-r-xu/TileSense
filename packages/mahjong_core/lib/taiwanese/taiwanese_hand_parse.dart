/// Taiwanese hand-shape analysis: a complete hand is 5 melds and a pair (17
/// tiles) rather than riichi and Hong Kong's 4 and 14 — the [_kTotalMelds]
/// every function here passes through to the shared, meld-count-generic
/// [isAgari]/[decompose]/[waitTiles]/[isTenpai] in `hand_parse.dart`.
///
/// Taiwanese also has one alternate shape those don't know about: seven
/// pairs plus a pung (14 + 3 = 17 tiles), covered here by
/// [_isSevenPairsAndPung] and folded into every function below. It has no
/// thirteen-orphans hand at all.
library;

import '../hand_parse.dart';
import '../meld.dart';
import '../tile.dart';

const _kTotalMelds = 5;

/// Mirrors [HandDecomposition], with the pair-plus-pung alternate shape in
/// place of riichi's kokushi.
class TaiwaneseDecomposition {
  TaiwaneseDecomposition({
    required this.melds,
    required this.pair,
    this.sevenPairsAndPung = false,
  });

  /// 5 melds (or, for [sevenPairsAndPung], 7 pair-melds and 1 triplet).
  final List<Meld> melds;

  /// Null for [sevenPairsAndPung], which has no single pair of its own.
  final TileType? pair;
  final bool sevenPairsAndPung;
}

/// True when [counts34] plus [meldCount] open melds forms a complete
/// Taiwanese hand: 5 melds and a pair, or seven pairs and a pung.
bool isAgariTaiwanese(List<int> counts34, {int meldCount = 0}) {
  if (meldCount == 0 && _isSevenPairsAndPung(counts34)) return true;
  return isAgari(counts34, meldCount: meldCount, totalMelds: _kTotalMelds);
}

/// Every standard decomposition of the concealed [counts34] (which already
/// contains the winning tile), plus the pair-and-pung shape when it applies.
/// [allArrangements] is always on — Taiwanese scoring needs every split, the
/// same way Hong Kong's does.
List<TaiwaneseDecomposition> decomposeTaiwanese(
  List<int> counts34, {
  int openMelds = 0,
}) {
  final results = [
    for (final d in decompose(counts34,
        openMelds: openMelds, allArrangements: true, totalMelds: _kTotalMelds))
      TaiwaneseDecomposition(melds: d.melds, pair: d.pair),
  ];

  if (openMelds == 0 && _isSevenPairsAndPung(counts34)) {
    final melds = <Meld>[];
    for (var i = 0; i < 34; i++) {
      if (counts34[i] == 2) {
        melds.add(Meld(kind: MeldKind.pair, low: typeFrom34(i), concealed: true));
      } else if (counts34[i] == 3) {
        melds.add(
            Meld(kind: MeldKind.triplet, low: typeFrom34(i), concealed: true));
      }
    }
    results.add(TaiwaneseDecomposition(
        melds: melds, pair: null, sevenPairsAndPung: true));
  }

  return results;
}

/// The tiles that complete [hand] (16 concealed tiles, minus 3 per open meld)
/// given [openMelds] calls.
List<TileType> waitTilesTaiwanese(List<Tile> hand, {int openMelds = 0}) {
  final base = toCounts34(hand);
  final waits = <TileType>[];
  for (var i = 0; i < 34; i++) {
    if (base[i] >= 4) continue;
    base[i]++;
    if (isAgariTaiwanese(base, meldCount: openMelds)) waits.add(typeFrom34(i));
    base[i]--;
  }
  return waits;
}

/// True when the hand is one tile from a win.
bool isTenpaiTaiwanese(List<Tile> hand, {int openMelds = 0}) =>
    waitTilesTaiwanese(hand, openMelds: openMelds).isNotEmpty;

bool _isSevenPairsAndPung(List<int> c) {
  var pairs = 0;
  var pungs = 0;
  for (final v in c) {
    if (v == 2) {
      pairs++;
    } else if (v == 3) {
      pungs++;
    } else if (v != 0) {
      return false;
    }
  }
  return pairs == 7 && pungs == 1;
}
