import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/tile.dart';
import 'package:tilesense/logic/efficiency_engine.dart';
import 'helpers.dart';

void main() {
  EfficiencyValueContext context(bool expanded, int wall, Ruleset ruleset) =>
      EfficiencyValueContext(
        melds: const [],
        roundWind: Wind.east,
        seatWind: Wind.south,
        isDealer: false,
        inRiichi: false,
        wallTilesRemaining: wall,
        doraIndicators: const [],
        expandedRiichiLookahead: expanded,
        ruleset: ruleset,
      );
  EfficiencyReport analyze(bool expanded,
      {int wall = 40, Ruleset ruleset = Ruleset.riichi}) {
    final hand = parseTiles('123m 456p 78s 34p 55s 9m E');
    return EfficiencyEngine().analyze(
        hand: hand,
        visibleCounts34: toCounts34(hand),
        canRiichi: true,
        valueContext: context(expanded, wall, ruleset));
  }

  test('ordinary one-shanten hands receive a bounded downward correction', () {
    final before = analyze(false), after = analyze(true);
    expect(before.lines.every((l) => l.shanten > 0), isTrue);
    var changed = 0;
    for (final line in after.lines) {
      final old = before.lines.singleWhere((l) => l.discard == line.discard);
      expect(
          line.winProbability, inInclusiveRange(0, old.winProbability + 1e-12));
      if (line.winBreakdown?.estimator == WinEstimator.tenpaiLookahead) {
        changed++;
        expect(line.shanten, 1);
        final b = line.winBreakdown!;
        expect(b.win, closeTo(line.winProbability, 1e-12));
        expect(b.turns.last.reachedTenpai, greaterThanOrEqualTo(b.win));
        expect(b.turns.fold<double>(0, (sum, t) => sum + t.hit),
            closeTo(b.win, 1e-12));
      }
    }
    expect(changed, greaterThan(0));
  });

  test('shorter walls do not increase expanded win probabilities', () {
    final early = analyze(true), late = analyze(true, wall: 8);
    for (final line in late.lines) {
      expect(
          line.winProbability,
          lessThanOrEqualTo(early.lines
                  .singleWhere((l) => l.discard == line.discard)
                  .winProbability +
              1e-12));
    }
  });

  test('experiment remains off by default and survives context copies', () {
    expect(context(false, 40, Ruleset.riichi).expandedRiichiLookahead, isFalse);
    final c = context(true, 40, Ruleset.riichi);
    expect(c.withMelds([]).expandedRiichiLookahead, isTrue);
    expect(
        c.copyWith(style: PlayStyle.defensive).expandedRiichiLookahead, isTrue);
  });

  test('enabling the riichi experiment does not alter Hong Kong', () {
    final before = analyze(false, ruleset: Ruleset.hongKong);
    final after = analyze(true, ruleset: Ruleset.hongKong);
    for (final line in after.lines) {
      expect(
          line.expectedValue,
          before.lines
              .singleWhere((l) => l.discard == line.discard)
              .expectedValue);
    }
  });
}
