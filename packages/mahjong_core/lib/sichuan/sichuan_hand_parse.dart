/// Sichuan hand-shape analysis: four melds and a pair, or seven pairs. It is
/// the standard riichi shape with two differences: four identical tiles may
/// stand as two of the seven pairs (that hand also earns a Root), and there
/// is no thirteen orphans (the wall has no honors to make one with).
///
/// Only the 27 suit tiles exist, so every function ignores slots 27..33 of the
/// 34-length counts array.
library;

import '../hand_parse.dart';
import '../meld.dart';
import '../tile.dart';

/// Mirrors [HandDecomposition] without the kokushi flag.
class SichuanDecomposition {
  SichuanDecomposition({
    required this.melds,
    required this.pair,
    this.sevenPairs = false,
  });

  /// Four melds (or, for [sevenPairs], seven pair-melds).
  final List<Meld> melds;

  /// Null for [sevenPairs].
  final TileType? pair;
  final bool sevenPairs;
}

bool _onlySuits(List<int> c) {
  for (var i = 27; i < c.length; i++) {
    if (c[i] != 0) return false;
  }
  return true;
}

bool _isSevenPairs(List<int> c) {
  var pairs = 0;
  for (final v in c) {
    if (v.isOdd) return false;
    pairs += v ~/ 2;
  }
  return pairs == 7;
}

/// True when [counts34] plus [meldCount] open melds forms a complete Sichuan
/// hand: 4 melds and a pair, or (with nothing exposed) seven pairs.
bool isAgariSichuan(List<int> counts34, {int meldCount = 0}) {
  if (!_onlySuits(counts34)) return false;
  if (meldCount == 0 && _isSevenPairs(counts34)) return true;
  return isAgari(counts34, meldCount: meldCount);
}

/// Every decomposition of the concealed [counts34] (which already contains the
/// winning tile): every split into melds, plus the seven-pairs reading.
List<SichuanDecomposition> decomposeSichuan(List<int> counts34,
    {int openMelds = 0}) {
  if (!_onlySuits(counts34)) return const [];
  final results = [
    for (final d in decompose(counts34, openMelds: openMelds, allArrangements: true)
        .where((d) => !d.sevenPairs && !d.kokushi))
      SichuanDecomposition(melds: d.melds, pair: d.pair),
  ];
  if (openMelds == 0 && _isSevenPairs(counts34)) {
    final pairs = <Meld>[];
    for (var i = 0; i < 27; i++) {
      for (var n = 0; n < counts34[i] ~/ 2; n++) {
        pairs.add(
            Meld(kind: MeldKind.pair, low: typeFrom34(i), concealed: true));
      }
    }
    results.add(SichuanDecomposition(melds: pairs, pair: null, sevenPairs: true));
  }
  return results;
}

/// The tiles that complete [hand] (13 tiles less 3 per open meld).
List<TileType> waitTilesSichuan(List<Tile> hand, {int openMelds = 0}) {
  final base = toCounts34(hand);
  final waits = <TileType>[];
  for (var i = 0; i < 27; i++) {
    if (base[i] >= 4) continue;
    base[i]++;
    if (isAgariSichuan(base, meldCount: openMelds)) waits.add(typeFrom34(i));
    base[i]--;
  }
  return waits;
}

/// True when the hand is one tile from a win.
bool isTenpaiSichuan(List<Tile> hand, {int openMelds = 0}) =>
    waitTilesSichuan(hand, openMelds: openMelds).isNotEmpty;
