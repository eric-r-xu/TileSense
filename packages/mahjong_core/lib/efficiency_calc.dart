/// Shanten / ukeire calculator based on Riichi-Trainer's
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
  int _targetMelds = 4;

  /// Melds a complete hand needs: 4 (14 tiles) for riichi and Hong Kong, 5
  /// (17 tiles) for Taiwanese. Every "13"/"14"/"8"/"4" below that isn't a
  /// tile-suit constant is really `totalMelds*3+1`, `+1` or `*2`/`totalMelds`
  /// in disguise, so this is the only thing a Taiwanese caller ever varies.
  static int _concealedSize(int totalMelds) => totalMelds * 3 + 1;

  /// For each discardable tile in [concealedHand] (a 38-slot count array),
  /// the resulting shanten and ukeire given [remainingTiles] (38-slot counts
  /// of tiles still live). Ported from `calculate()`.
  List<TileEfficiencyResult> calculate(
    List<int> concealedHand,
    List<int> remainingTiles, {
    int totalMelds = 4,
  }) {
    final winSize = _concealedSize(totalMelds) + 1;
    final hand = List<int>.of(concealedHand);
    final openHand = _countTiles(hand) < winSize;

    // Riichi-Trainer pads each open meld with a completed honor triplet.
    final shantenOffset = ((winSize - _countTiles(hand)) ~/ 3) * 2;
    for (var i = 0; i < shantenOffset; i += 2) {
      hand[31] += 3;
    }

    final results = <TileEfficiencyResult>[];

    for (var discard = 1; discard < hand.length; discard++) {
      if (discard % 10 == 0 || concealedHand[discard] == 0) continue;

      hand[discard]--;
      final resultingShanten = _shanten(hand, openHand, -2, totalMelds);
      // Acceptance is measured against *this* line's shanten, not the best
      // shanten on offer. Riichi-Trainer passes `baseShanten` here because it
      // only ever ranks optimal discards; that made every shanten-worsening
      // discard report zero acceptance, since drawing back to `baseShanten` is
      // not "below" it. The guide scores those lines too — folding usually
      // means breaking your own shape — so they need a real number.
      final ukeire = _calculateUkeire(
          hand, remainingTiles, openHand, resultingShanten, totalMelds);
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

  /// The widest live wait among the discards that leave a 14-tile (or 11/8/5,
  /// or Taiwanese's 17/14/11/8/5) hand tenpai, or 0 when none does. A cheap
  /// subset of `calculate()` for lookahead: only tenpai discards pay for an
  /// acceptance count.
  int bestTenpaiWait(List<int> concealedHand, List<int> remainingTiles,
      {int totalMelds = 4}) {
    final winSize = _concealedSize(totalMelds) + 1;
    final hand = List<int>.of(concealedHand);
    final openHand = _countTiles(hand) < winSize;
    final shantenOffset = ((winSize - _countTiles(hand)) ~/ 3) * 2;
    for (var i = 0; i < shantenOffset; i += 2) {
      hand[31] += 3;
    }

    var best = 0;
    for (var discard = 1; discard < hand.length; discard++) {
      if (discard % 10 == 0 || concealedHand[discard] == 0) continue;
      hand[discard]--;
      if (_shanten(hand, openHand, 0, totalMelds) == 0) {
        final wait =
            _calculateUkeire(hand, remainingTiles, openHand, 0, totalMelds)
                .value;
        if (wait > best) best = wait;
      }
      hand[discard]++;
    }
    return best;
  }

  /// The tiles that reduce the shanten of a 13-tile (or 10/7/4, or
  /// Taiwanese's 16/13/10/7/4) hand, and how many are live given
  /// [remainingTiles]. Convenience wrapper around the same logic
  /// `calculate()` uses per discard.
  ({int count, List<int> tiles}) acceptance(
    List<int> concealedHand,
    List<int> remainingTiles, {
    int totalMelds = 4,
  }) {
    final concealedSize = _concealedSize(totalMelds);
    final hand = List<int>.of(concealedHand);
    final open = _countTiles(hand) < concealedSize;
    final melds = (concealedSize - _countTiles(hand)) ~/ 3;
    final clamped = melds < 0 ? 0 : melds;
    for (var i = 0; i < clamped; i++) {
      hand[31] += 3;
    }
    final base = _shanten(hand, open || clamped > 0, -2, totalMelds);
    final r = _calculateUkeire(
        hand, remainingTiles, open || clamped > 0, base, totalMelds);
    return (count: r.value, tiles: r.tiles);
  }

  /// Live tiles that would lower the shanten of a hand between draws (13, 10,
  /// 7 or 4 concealed tiles) if claimed off a discard and followed by the best
  /// discard: [pung] counts types this hand can pung (off any seat), [chow]
  /// types it can chow (off the left seat only). A type that works both ways
  /// counts in each. Zero for a hand that is already ready.
  ({int pung, int chow}) callAcceptance(
    List<int> concealedHand,
    List<int> remainingTiles, {
    int totalMelds = 4,
  }) {
    final hand = List<int>.of(concealedHand);
    if (_countTiles(hand) < 4) return (pung: 0, chow: 0);
    final base = calculateWaitingShanten(hand, totalMelds: totalMelds);
    if (base <= 0) return (pung: 0, chow: 0);

    /// Whether claiming the tile that completes a set with [a] and [b] leaves
    /// a hand that can discard below [base]. A call adds one set, so shanten
    /// falls by at most one; the first discard that gets there ends the search.
    bool improvesWith(int a, int b) {
      hand[a]--;
      hand[b]--;
      var improves = false;
      for (var d = 1; d < hand.length && !improves; d++) {
        if (d % 10 == 0 || hand[d] == 0) continue;
        hand[d]--;
        if (calculateWaitingShanten(hand, totalMelds: totalMelds) < base) {
          improves = true;
        }
        hand[d]++;
      }
      hand[a]++;
      hand[b]++;
      return improves;
    }

    var pung = 0, chow = 0;
    for (var t = 1; t < hand.length; t++) {
      if (t % 10 == 0 || remainingTiles[t] == 0) continue;
      if (hand[t] >= 2 && improvesWith(t, t)) pung += remainingTiles[t];
      if (t > 30) continue; // honours cannot be chowed
      final n = t % 10;
      final runs = [
        if (n >= 3) (t - 2, t - 1),
        if (n >= 2 && n <= 8) (t - 1, t + 1),
        if (n <= 7) (t + 1, t + 2),
      ];
      for (final (a, b) in runs) {
        if (hand[a] > 0 && hand[b] > 0 && improvesWith(a, b)) {
          chow += remainingTiles[t];
          break;
        }
      }
    }
    return (pung: pung, chow: chow);
  }

  /// Shanten of a hand between draws (13, 10, 7 or 4 concealed tiles, or
  /// Taiwanese's 16, 13, 10, 7 or 4). Ported from `calculate_waiting_shanten()`.
  int calculateWaitingShanten(List<int> concealedHand, {int totalMelds = 4}) {
    final concealedSize = _concealedSize(totalMelds);
    final hand = List<int>.of(concealedHand);
    final melds = (concealedSize - _countTiles(hand)) ~/ 3;
    final clamped = melds < 0 ? 0 : melds;
    for (var i = 0; i < clamped; i++) {
      hand[31] += 3;
    }
    return _shanten(hand, clamped > 0, -2, totalMelds);
  }

  _UkeireResult _calculateUkeire(
    List<int> hand,
    List<int> remainingTiles,
    bool openHand,
    int baseShanten,
    int totalMelds,
  ) {
    final result = _UkeireResult();
    for (var added = 1; added < hand.length; added++) {
      if (added % 10 == 0 || remainingTiles[added] == 0) continue;

      hand[added]++;
      if (_shanten(hand, openHand, baseShanten - 1, totalMelds) <
          baseShanten) {
        result.value += remainingTiles[added];
        result.tiles.add(added);
      }
      hand[added]--;
    }
    return result;
  }

  /// [totalMelds] other than 4 is Taiwanese's 5-meld shape, which has neither
  /// riichi's seven-pairs nor its thirteen-orphans alternate hand (Taiwanese's
  /// own "seven pairs and a pung" is a different shape this shanten search
  /// does not chase — see `taiwanese_hand_parse.dart`), so only the standard
  /// search runs for it.
  int _shanten(List<int> hand, bool openHand,
      [int knownMinimum = -2, int totalMelds = 4]) {
    if (openHand || totalMelds != 4) {
      return _standardShanten(hand,
          knownMinimum: knownMinimum, totalMelds: totalMelds);
    }

    final chiitoitsu = _chiitoitsuShanten(hand);
    if (chiitoitsu < 0) return chiitoitsu;

    final kokushi = _kokushiShanten(hand);
    if (kokushi < 3) return kokushi;

    final standard =
        _standardShanten(hand,
            knownMinimum: knownMinimum, totalMelds: totalMelds);
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

  int _standardShanten(List<int> hand,
      {int knownMinimum = -2, int totalMelds = 4}) {
    _copyInto(_workHand, hand);
    _completeSets = 0;
    _pair = 0;
    _partialSets = 0;
    _targetMelds = totalMelds;
    _bestShanten = totalMelds * 2;
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
    if (_hasGivenMinimum &&
        _completeSets < (_targetMelds - 1) - _minimumShanten) {
      return;
    }

    var i = start;
    while (i < _workHand.length && _workHand[i] == 0) {
      i++;
    }

    if (i >= _workHand.length) {
      final current =
          _targetMelds * 2 - _completeSets * 2 - _partialSets - _pair;
      if (current < _bestShanten) _bestShanten = current;
      return;
    }

    if (_completeSets + _partialSets < _targetMelds) {
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
    if (tile.type.isPlayingTile) counts[trainerIndexOf(tile.type)]++;
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
