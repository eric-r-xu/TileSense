/// Shanten / ukeire calculator — a faithful port of the pure part of the Vala
/// client's `source/Game/Logic/TileEfficiency.vala` (`TileEfficiencyCalculator`,
/// lines 45-305), which itself was ported from Riichi-Trainer's
/// ShantenCalculator.js / UkeireCalculator.js (GPL-3.0).
///
/// The 38-slot tile representation is retained so results match Riichi-Trainer:
///   1-9   = 1m..9m
///   11-19 = 1p..9p
///   21-29 = 1s..9s
///   31-37 = east, south, west, north, white, green, red
/// Slot 0 and the x10 slots (10, 20, 30) are unused.
library;

import 'tile.dart';

/// Per-discard efficiency result. Mirrors `TileEfficiencyResult`.
class TileEfficiencyResult {
  TileEfficiencyResult({
    required this.tileIndex,
    required this.shanten,
    required this.ukeire,
    required this.improvingTiles,
  });

  /// 38-slot index of the tile discarded to reach this line.
  final int tileIndex;

  /// Shanten after discarding [tileIndex] (-1 == complete).
  final int shanten;

  /// Number of live tiles that reduce shanten.
  final int ukeire;

  /// 38-slot indices of the tile types that reduce shanten.
  final List<int> improvingTiles;

  TileType get discard => typeFromTrainerIndex(tileIndex);
  List<TileType> get accepts =>
      improvingTiles.map(typeFromTrainerIndex).toList();
}

class _UkeireResult {
  int value = 0;
  final List<int> tiles = [];
}

class TileEfficiencyCalculator {
  final List<int> _workHand = List<int>.filled(38, 0);
  int _completeSets = 0;
  int _pair = 0;
  int _partialSets = 0;
  int _bestShanten = 8;
  int _minimumShanten = -1;
  bool _hasGivenMinimum = false;

  /// For each discardable tile in [concealedHand] (a 38-slot count array),
  /// the resulting shanten and ukeire given [remainingTiles] (38-slot counts
  /// of tiles still live). Ported from `calculate()`.
  List<TileEfficiencyResult> calculate(
    List<int> concealedHand,
    List<int> remainingTiles,
  ) {
    final hand = List<int>.of(concealedHand);
    final openHand = _countTiles(hand) < 14;

    // Riichi-Trainer pads each open meld with a completed honor triplet.
    final shantenOffset = ((14 - _countTiles(hand)) ~/ 3) * 2;
    for (var i = 0; i < shantenOffset; i += 2) {
      hand[31] += 3;
    }

    final baseShanten = _shanten(hand, openHand);
    final results = <TileEfficiencyResult>[];

    for (var discard = 1; discard < hand.length; discard++) {
      if (discard % 10 == 0 || concealedHand[discard] == 0) continue;

      hand[discard]--;
      final resultingShanten = _shanten(hand, openHand);
      final ukeire = _calculateUkeire(hand, remainingTiles, openHand, baseShanten);
      hand[discard]++;

      results.add(TileEfficiencyResult(
        tileIndex: discard,
        shanten: resultingShanten,
        ukeire: ukeire.value,
        improvingTiles: ukeire.tiles,
      ));
    }

    return results;
  }

  /// The tiles that reduce the shanten of a 13-tile (or 10/7/4) hand, and how
  /// many are live given [remainingTiles]. Convenience wrapper around the same
  /// logic `calculate()` uses per discard.
  ({int count, List<int> tiles}) acceptance(
    List<int> concealedHand,
    List<int> remainingTiles,
  ) {
    final hand = List<int>.of(concealedHand);
    final open = _countTiles(hand) < 13;
    final melds = (13 - _countTiles(hand)) ~/ 3;
    final clamped = melds < 0 ? 0 : melds;
    for (var i = 0; i < clamped; i++) {
      hand[31] += 3;
    }
    final base = _shanten(hand, open || clamped > 0);
    final r = _calculateUkeire(hand, remainingTiles, open || clamped > 0, base);
    return (count: r.value, tiles: r.tiles);
  }

  /// Shanten of a hand between draws (13, 10, 7 or 4 concealed tiles). Ported
  /// from `calculate_waiting_shanten()`.
  int calculateWaitingShanten(List<int> concealedHand) {
    final hand = List<int>.of(concealedHand);
    final melds = (13 - _countTiles(hand)) ~/ 3;
    final clamped = melds < 0 ? 0 : melds;
    for (var i = 0; i < clamped; i++) {
      hand[31] += 3;
    }
    return _shanten(hand, clamped > 0);
  }

  _UkeireResult _calculateUkeire(
    List<int> hand,
    List<int> remainingTiles,
    bool openHand,
    int baseShanten,
  ) {
    final result = _UkeireResult();
    for (var added = 1; added < hand.length; added++) {
      if (added % 10 == 0 || remainingTiles[added] == 0) continue;

      hand[added]++;
      if (_shanten(hand, openHand, baseShanten - 1) < baseShanten) {
        result.value += remainingTiles[added];
        result.tiles.add(added);
      }
      hand[added]--;
    }
    return result;
  }

  int _shanten(List<int> hand, bool openHand, [int knownMinimum = -2]) {
    if (openHand) return _standardShanten(hand, knownMinimum);

    final chiitoitsu = _chiitoitsuShanten(hand);
    if (chiitoitsu < 0) return chiitoitsu;

    final kokushi = _kokushiShanten(hand);
    if (kokushi < 3) return kokushi;

    final standard = _standardShanten(hand, knownMinimum);
    return [standard, chiitoitsu, kokushi].reduce((a, b) => a < b ? a : b);
  }

  int _chiitoitsuShanten(List<int> hand) {
    var pairs = 0;
    var unique = 0;
    for (var i = 1; i < hand.length; i++) {
      if (hand[i] == 0) continue;
      unique++;
      if (hand[i] >= 2) pairs++;
    }
    var result = 6 - pairs;
    if (unique < 7) result += 7 - unique;
    return result;
  }

  int _kokushiShanten(List<int> hand) {
    var unique = 0;
    var hasPair = 0;
    for (var i = 1; i < hand.length; i++) {
      if (i % 10 != 1 && i % 10 != 9 && i <= 30) continue;
      if (hand[i] == 0) continue;
      unique++;
      if (hand[i] >= 2) hasPair = 1;
    }
    return 13 - unique - hasPair;
  }

  int _standardShanten(List<int> hand, [int knownMinimum = -2]) {
    _copyInto(_workHand, hand);
    _completeSets = 0;
    _pair = 0;
    _partialSets = 0;
    _bestShanten = 8;
    _hasGivenMinimum = knownMinimum != -2;
    _minimumShanten = _hasGivenMinimum ? knownMinimum : -1;

    for (var i = 1; i < _workHand.length; i++) {
      if (_workHand[i] < 2) continue;
      _pair++;
      _workHand[i] -= 2;
      _removeCompletedSets(1);
      _workHand[i] += 2;
      _pair--;
    }

    _removeCompletedSets(1);
    return _bestShanten;
  }

  void _removeCompletedSets(int start) {
    if (_bestShanten <= _minimumShanten) return;

    var i = start;
    while (i < _workHand.length && _workHand[i] == 0) {
      i++;
    }

    if (i >= _workHand.length) {
      _removePotentialSets(1);
      return;
    }

    if (_workHand[i] >= 3) {
      _completeSets++;
      _workHand[i] -= 3;
      _removeCompletedSets(i);
      _workHand[i] += 3;
      _completeSets--;
    }

    if (i < 30 && _workHand[i + 1] != 0 && _workHand[i + 2] != 0) {
      _completeSets++;
      _workHand[i]--;
      _workHand[i + 1]--;
      _workHand[i + 2]--;
      _removeCompletedSets(i);
      _workHand[i]++;
      _workHand[i + 1]++;
      _workHand[i + 2]++;
      _completeSets--;
    }

    _removeCompletedSets(i + 1);
  }

  void _removePotentialSets(int start) {
    if (_bestShanten <= _minimumShanten) return;
    if (_hasGivenMinimum && _completeSets < 3 - _minimumShanten) return;

    var i = start;
    while (i < _workHand.length && _workHand[i] == 0) {
      i++;
    }

    if (i >= _workHand.length) {
      final current = 8 - _completeSets * 2 - _partialSets - _pair;
      if (current < _bestShanten) _bestShanten = current;
      return;
    }

    if (_completeSets + _partialSets < 4) {
      if (_workHand[i] == 2) {
        _partialSets++;
        _workHand[i] -= 2;
        _removePotentialSets(i);
        _workHand[i] += 2;
        _partialSets--;
      }

      if (i < 30 && _workHand[i + 1] != 0) {
        _partialSets++;
        _workHand[i]--;
        _workHand[i + 1]--;
        _removePotentialSets(i);
        _workHand[i]++;
        _workHand[i + 1]++;
        _partialSets--;
      }

      if (i < 30 && i % 10 <= 8 && _workHand[i + 2] != 0) {
        _partialSets++;
        _workHand[i]--;
        _workHand[i + 2]--;
        _removePotentialSets(i);
        _workHand[i]++;
        _workHand[i + 2]++;
        _partialSets--;
      }
    }

    _removePotentialSets(i + 1);
  }

  static int _countTiles(List<int> hand) => hand.fold(0, (a, b) => a + b);

  static void _copyInto(List<int> dst, List<int> src) {
    for (var i = 0; i < src.length; i++) {
      dst[i] = src[i];
    }
  }
}

/// TileType -> 38-slot trainer index.
int trainerIndexOf(TileType type) {
  if (type.isMan) return type.number;
  if (type.isPin) return 10 + type.number;
  if (type.isSou) return 20 + type.number;
  // ton..chun -> 31..37
  return 31 + (type.index - TileType.ton.index);
}

/// 38-slot trainer index -> TileType.
TileType typeFromTrainerIndex(int i) {
  if (i >= 1 && i <= 9) return TileType.values[TileType.man1.index + i - 1];
  if (i >= 11 && i <= 19) return TileType.values[TileType.pin1.index + i - 11];
  if (i >= 21 && i <= 29) return TileType.values[TileType.sou1.index + i - 21];
  return TileType.values[TileType.ton.index + i - 31];
}

/// Build a 38-slot count array from tiles.
List<int> toTrainerCounts(Iterable<Tile> tiles) {
  final counts = List<int>.filled(38, 0);
  for (final tile in tiles) {
    counts[trainerIndexOf(tile.type)]++;
  }
  return counts;
}

/// Build a 38-slot count array from TileType counts (e.g. remaining tiles).
List<int> trainerCountsFromTypeCounts(List<int> counts34) {
  final counts = List<int>.filled(38, 0);
  for (var i = 0; i < 34; i++) {
    counts[trainerIndexOf(typeFrom34(i))] = counts34[i];
  }
  return counts;
}
