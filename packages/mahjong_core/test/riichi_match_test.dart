import 'package:mahjong_core/mahjong_core.dart';
import 'package:test/test.dart';

void main() {
  const belowTarget = [29000, 27000, 24000, 20000];
  const atTarget = [30000, 26000, 24000, 20000];

  bool ends(int nextHand, List<int> points,
          {bool kept = false,
          bool fullGame = true,
          Ruleset ruleset = Ruleset.riichi}) =>
      ruleset.gameEndsAfterRound(
        fullGame: fullGame,
        roundNumber: nextHand,
        dealerKept: kept,
        points: points,
      );

  test('South 4 extends only when everyone is below 30,000', () {
    expect(ends(8, belowTarget), isFalse);
    expect(ends(8, atTarget), isTrue);
    expect(ends(8, [35000, 25000, 22000, 18000]), isTrue);
  });

  test('reaching 30,000 before South 4 does not end a hanchan', () {
    expect(ends(7, atTarget), isFalse);
  });

  test('West ends at the target, or after West 4 even without it', () {
    expect(ends(9, belowTarget), isFalse);
    expect(ends(9, atTarget), isTrue);
    expect(ends(11, belowTarget), isFalse);
    expect(ends(12, belowTarget), isTrue);
  });

  test('dealer repeats retain priority over target and West 4', () {
    expect(ends(7, atTarget, kept: true), isFalse);
    expect(ends(8, atTarget, kept: true), isFalse);
    expect(ends(11, belowTarget, kept: true), isFalse);
    expect(ends(11, atTarget, kept: true), isFalse);
  });

  test('bankruptcy still ends immediately, including on a dealer repeat', () {
    expect(ends(1, [50100, 25000, 25000, -100], kept: true), isTrue);
    expect(ends(9, [50100, 25000, 25000, -100]), isTrue);
    expect(ends(1, [50000, 25000, 25000, 0]), isFalse);
  });

  test('East-only and other variants keep their existing schedules', () {
    expect(ends(4, belowTarget, fullGame: false), isTrue);
    expect(ends(3, belowTarget, fullGame: false, kept: true), isFalse);
    for (final ruleset in Ruleset.values.where((r) => !r.isRiichi)) {
      final last = ruleset.handsPerGame(fullGame: true);
      expect(ends(last - 1, belowTarget, ruleset: ruleset), isFalse,
          reason: ruleset.name);
      expect(ends(last, belowTarget, ruleset: ruleset), isTrue,
          reason: ruleset.name);
    }
  });

  test('riichi extension uses West as the prevailing wind', () {
    for (var hand = 0; hand < 12; hand++) {
      expect(Ruleset.riichi.roundWindFor(hand), Wind.values[hand ~/ 4]);
    }
    expect(Ruleset.sanma.roundWindFor(3), Wind.south);
    expect(Ruleset.mcr.roundWindFor(12), Wind.north);
  });
}
