/// MCR shape distance and acceptance. Existing calculators retain their behavior.
library;

import '../efficiency_calc.dart';
import '../tile.dart';
import 'mcr_hand_parse.dart';

class McrEfficiencyCalculator extends TileEfficiencyCalculator {
  final _standard = TileEfficiencyCalculator();
  final Map<String, int> _cache = {};

  @override
  int calculateWaitingShanten(List<int> hand, {int totalMelds = 4}) =>
      _shanten(hand, openMelds: _openMelds(hand));

  /// Exposed sets beside a concealed [hand] between draws (13, 10, 7, 4 or 1
  /// tiles) or holding one (14, 11, ...).
  static int _openMelds(List<int> hand) =>
      ((14 - hand.fold<int>(0, (a, b) => a + b)) ~/ 3).clamp(0, 4);

  /// Shanten of [hand] beside [openMelds] exposed sets. The ordinary shape
  /// gets those sets padded in up front, as the standard calculator's own
  /// acceptance does: left to infer them from the tile count, it would see
  /// one fewer once a drawn tile is added to an open hand (11 tiles is no
  /// longer short of 13), and no draw would ever look like progress.
  int _shanten(List<int> hand, {required int openMelds}) {
    final key = '$openMelds:${hand.join(',')}';
    if (_cache[key] case final cached?) return cached;
    final counts = [
      for (var i = 0; i < 34; i++) hand[trainerIndexOf(typeFrom34(i))]
    ];
    final padded = List<int>.of(hand)..[31] += 3 * openMelds;
    final ordinary = _standard.calculateWaitingShanten(padded);
    final special =
        mcrSpecialShanten(counts, openMelds: openMelds, ceiling: ordinary);
    final result = special < ordinary ? special : ordinary;
    if (_cache.length > 20000) _cache.clear();
    return _cache[key] = result;
  }

  @override
  ({int count, List<int> tiles}) acceptance(List<int> hand, List<int> remaining,
      {int totalMelds = 4}) {
    final open = _openMelds(hand);
    final base = _shanten(hand, openMelds: open);
    final work = List<int>.of(hand);
    final tiles = <int>[];
    var count = 0;
    for (var i = 1; i < 38; i++) {
      if (i % 10 == 0 || remaining[i] <= 0 || work[i] >= 4) continue;
      work[i]++;
      if (_shanten(work, openMelds: open) < base) {
        tiles.add(i);
        count += remaining[i];
      }
      work[i]--;
    }
    return (count: count, tiles: tiles);
  }

  @override
  List<TileEfficiencyResult> calculate(List<int> hand, List<int> remaining,
      {int totalMelds = 4}) {
    final work = List<int>.of(hand);
    final result = <TileEfficiencyResult>[];
    for (var i = 1; i < 38; i++) {
      if (i % 10 == 0 || work[i] <= 0) continue;
      work[i]--;
      final shanten = calculateWaitingShanten(work);
      final accepts = acceptance(work, remaining);
      result.add(TileEfficiencyResult(
          tileIndex: i,
          shanten: shanten,
          ukeire: accepts.count,
          improvingTiles: accepts.tiles));
      work[i]++;
    }
    return result;
  }

  @override
  int bestTenpaiWait(List<int> hand, List<int> remaining,
      {int totalMelds = 4}) {
    var best = 0;
    for (final line in calculate(hand, remaining)) {
      if (line.shanten == 0 && line.ukeire > best) best = line.ukeire;
    }
    return best;
  }
}
