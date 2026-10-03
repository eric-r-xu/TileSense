/// MCR shape distance and acceptance. Existing calculators retain their behavior.
library;

import '../efficiency_calc.dart';
import '../tile.dart';
import 'mcr_hand_parse.dart';

class McrEfficiencyCalculator extends TileEfficiencyCalculator {
  final _standard = TileEfficiencyCalculator();
  final Map<String, int> _cache = {};

  @override
  int calculateWaitingShanten(List<int> hand, {int totalMelds = 4}) {
    final key = hand.join(',');
    if (_cache[key] case final cached?) return cached;
    final count = hand.fold<int>(0, (a, b) => a + b);
    final open = ((14 - count) ~/ 3).clamp(0, 4);
    final counts = [
      for (var i = 0; i < 34; i++) hand[trainerIndexOf(typeFrom34(i))]
    ];
    final ordinary = _standard.calculateWaitingShanten(hand);
    final special =
        mcrSpecialShanten(counts, openMelds: open, ceiling: ordinary);
    final result = special < ordinary ? special : ordinary;
    if (_cache.length > 20000) _cache.clear();
    return _cache[key] = result;
  }

  @override
  ({int count, List<int> tiles}) acceptance(List<int> hand, List<int> remaining,
      {int totalMelds = 4}) {
    final base = calculateWaitingShanten(hand);
    final work = List<int>.of(hand);
    final tiles = <int>[];
    var count = 0;
    for (var i = 1; i < 38; i++) {
      if (i % 10 == 0 || remaining[i] <= 0 || work[i] >= 4) continue;
      work[i]++;
      if (calculateWaitingShanten(work) < base) {
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
