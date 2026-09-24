import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/logic/efficiency_engine.dart';
import 'package:tilesense/logic/placement_utility.dart';
import 'package:mahjong_core/round.dart';
import 'package:mahjong_core/tile.dart';
import 'package:tilesense/main.dart';

import 'helpers.dart';

/// The Strategy dial: points or placement, riichi only. Every fixture below
/// was found by a random search over hands and pinned down to a fixed,
/// reconstructible hand rather than kept as a moving random seed — see the
/// commit that added this file for the search itself.
void main() {
  group('PlacementUtility', () {
    test('is monotonic in own score', () {
      final u = PlacementUtility(
        tablePoints: [25000, 25000, 25000, 25000],
        mySeat: 0,
        handsRemaining: 4,
      );
      expect(u.valueOf(1000), greaterThan(0));
      expect(u.valueOf(-1000), lessThan(0));
      expect(u.valueOf(2000), greaterThan(u.valueOf(1000)));
    });

    test('a tied table is worth the same to every seat', () {
      const tied = [25000, 25000, 25000, 25000];
      final gains = [
        for (var seat = 0; seat < 4; seat++)
          PlacementUtility(tablePoints: tied, mySeat: seat, handsRemaining: 4)
              .valueOf(3000)
      ];
      for (final g in gains.skip(1)) {
        expect(g, closeTo(gains.first, 1e-9));
      }
    });

    test('a big enough swing saturates instead of extrapolating past it', () {
      // Already a lock for first: a modest further gain adds almost nothing.
      final locked = PlacementUtility(
        tablePoints: [80000, 10000, 5000, 5000],
        mySeat: 0,
        handsRemaining: 1,
      );
      expect(locked.valueOf(3000), lessThan(0.01));

      // Hopeless last: a modest further loss costs almost nothing either —
      // there is barely anywhere left to fall.
      final hopeless = PlacementUtility(
        tablePoints: [3000, 30000, 30000, 30000],
        mySeat: 0,
        handsRemaining: 1,
      );
      expect(hopeless.valueOf(-1000).abs(), lessThan(0.01));
    });

    test('gaps matter more the closer the game is to over', () {
      final earlyGame = PlacementUtility(
        tablePoints: [30000, 25000, 25000, 20000],
        mySeat: 0,
        handsRemaining: 8,
      );
      final finalHand = PlacementUtility(
        tablePoints: [30000, 25000, 25000, 20000],
        mySeat: 0,
        handsRemaining: 1,
      );
      // Same gap, but a loss (or gain) is worth more when there is no more
      // game left to make it up.
      expect(finalHand.valueOf(-3000).abs(),
          greaterThan(earlyGame.valueOf(-3000).abs()));
    });
  });

  group('Strategy.points reproduces the reference model exactly', () {
    test('a tenpai hand scores identically with strategy left unset', () {
      final hand = parseTiles('123m 456m 789m 34p 55p 9s');
      final visible = toCounts34(hand);
      EfficiencyReport withStrategy(Strategy? s) => EfficiencyEngine().analyze(
            hand: hand,
            visibleCounts34: visible,
            canRiichi: true,
            valueContext: EfficiencyValueContext(
              melds: const [],
              roundWind: Wind.east,
              seatWind: Wind.south,
              isDealer: false,
              inRiichi: false,
              wallTilesRemaining: 40,
              doraIndicators: const [],
              strategy: s ?? Strategy.points,
            ),
          );
      final unset = withStrategy(null);
      final explicit = withStrategy(Strategy.points);
      expect(explicit.lines.first.expectedValue, unset.lines.first.expectedValue);
      expect(explicit.lines.first.valuePlan, unset.lines.first.valuePlan);
      expect(explicit.lines.first.discard, unset.lines.first.discard);
    });
  });

  group('push/fold', () {
    EfficiencyReport read(
      String spec,
      String pond, {
      required Strategy strategy,
      required List<int> tablePoints,
      required int handsRemaining,
      required TileType doraIndicator,
      required int wall,
    }) {
      final hand = parseTiles(spec);
      final pondTypes = parseTypes(pond);
      final visible = toCounts34(hand);
      for (final t in [...pondTypes, doraIndicator]) {
        visible[t.index - 1]++;
      }
      return EfficiencyEngine().analyze(
        hand: hand,
        visibleCounts34: visible,
        canRiichi: true,
        defenseHand: hand,
        opponentRiichi: true,
        opponentDiscards: pondTypes,
        valueContext: EfficiencyValueContext(
          melds: const [],
          roundWind: Wind.east,
          seatWind: Wind.south,
          isDealer: false,
          inRiichi: false,
          wallTilesRemaining: wall,
          doraIndicators: [doraIndicator],
          style: PlayStyle.balanced,
          strategy: strategy,
          tablePoints: tablePoints,
          mySeat: 0,
          handsRemaining: handsRemaining,
        ),
      );
    }

    // Same hand throughout: 2-shanten with a decently live push (pin7,
    // safety 3) clearly ahead of the alternatives on points EV.
    const leadHand = '1267m 1237p 1167s NN';
    const leadPond = '35m 8p 338s';
    const neutralPoints = [25000, 25000, 25000, 25000];
    const bigLead = [40000, 22000, 22000, 16000];

    test('a comfortable final-hand lead folds a push points would take', () {
      DiscardLine reco(Strategy s, List<int> tp, int handsRemaining) => read(
            leadHand,
            leadPond,
            strategy: s,
            tablePoints: tp,
            handsRemaining: handsRemaining,
            doraIndicator: TileType.shaa,
            wall: 66,
          ).lines.firstWhere((l) => l.recommended);

      final neutral = reco(Strategy.placement, neutralPoints, 8);
      final pointsWithLead = reco(Strategy.points, bigLead, 1);
      final placementWithLead = reco(Strategy.placement, bigLead, 1);

      expect(neutral.discard, TileType.pin7,
          reason: 'on a neutral table this push is simply the best line');
      expect(pointsWithLead.discard, TileType.pin7,
          reason: 'points keeps pushing regardless of the score situation');
      expect(placementWithLead.discard, isNot(TileType.pin7),
          reason: 'placement folds instead, to protect a lead points '
              'ignores');
      expect(placementWithLead.safety!.rating,
          greaterThan(pointsWithLead.safety!.rating));
    });

    // A different hand: points already folds to a genbutsu everywhere it is
    // asked, but a hole in the final hand is worth pushing out of.
    const behindHand = '2799m 115699p 3689s';
    const behindPond = '6m 3p 8s WW';
    const deepHole = [8000, 27000, 30000, 35000];

    test('a hole in the final hand pushes a tile points would fold', () {
      DiscardLine reco(Strategy s, List<int> tp, int handsRemaining) => read(
            behindHand,
            behindPond,
            strategy: s,
            tablePoints: tp,
            handsRemaining: handsRemaining,
            doraIndicator: TileType.pin4,
            wall: 66,
          ).lines.firstWhere((l) => l.recommended);

      final neutral = reco(Strategy.points, neutralPoints, 8);
      final pointsBehind = reco(Strategy.points, deepHole, 1);
      final placementBehind = reco(Strategy.placement, deepHole, 1);

      expect(neutral.discard, TileType.sou8,
          reason: 'the safe line is simply the best one on a neutral table');
      expect(pointsBehind.discard, TileType.sou8,
          reason: 'points keeps folding regardless of the score situation');
      expect(placementBehind.discard, isNot(TileType.sou8),
          reason: 'placement pushes instead, to try to climb out of last');
      expect(placementBehind.safety!.rating,
          lessThan(pointsBehind.safety!.rating));
    });
  });

  test('riichi vs damaten: placement can pick the one points would not', () {
    // No opponent riichi here — the trade-off is the 1000-point deposit and
    // the flexibility of staying quiet against the value riichi adds, not a
    // deal-in risk.
    final hand = parseTiles('777m 227999p 33367s');
    final visible = toCounts34(hand)..[TileType.man4.index - 1] += 1;

    DiscardLine reco(Strategy s, List<int> tablePoints, int handsRemaining) =>
        EfficiencyEngine()
            .analyze(
              hand: hand,
              visibleCounts34: visible,
              canRiichi: true,
              valueContext: EfficiencyValueContext(
                melds: const [],
                roundWind: Wind.east,
                seatWind: Wind.south,
                isDealer: false,
                inRiichi: false,
                wallTilesRemaining: 36,
                doraIndicators: const [TileType.man4],
                style: PlayStyle.balanced,
                strategy: s,
                tablePoints: tablePoints,
                mySeat: 0,
                handsRemaining: handsRemaining,
              ),
            )
            .lines
            .firstWhere((l) => l.recommended);

    const neutral = [25000, 25000, 25000, 25000];
    const lead = [38000, 24000, 22000, 16000];

    expect(reco(Strategy.points, neutral, 8).valuePlan, 'RIICHI');
    expect(reco(Strategy.placement, neutral, 8).valuePlan, 'RIICHI',
        reason: 'nothing to protect on a neutral table, so both agree');

    expect(reco(Strategy.points, lead, 1).valuePlan, 'RIICHI',
        reason: 'points always prefers the bigger expected payout');
    expect(reco(Strategy.placement, lead, 1).valuePlan, 'DAMATEN',
        reason: 'placement keeps the lead flexible instead of locking in');
  });

  testWidgets('the game exposes the dial and it drives the guide',
      (tester) async {
    await tester.binding.setSurfaceSize(kDesignSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Single Player'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('charactersContinue')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(labelOf(const Key('strategy')), 'Points');
    await tester.tap(find.byKey(const Key('strategy')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(labelOf(const Key('strategy')), 'Placement');
    await tester.tap(find.byKey(const Key('strategy')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(labelOf(const Key('strategy')), 'Points');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('the guide carries a synced copy of the dial', (tester) async {
    await tester.binding.setSurfaceSize(kDesignSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Single Player'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('charactersContinue')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('guideToggle')));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('guideStrategy_placement')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(labelOf(const Key('strategy')), 'Placement');

    await tester.tap(find.byKey(const Key('strategy')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(labelOf(const Key('strategy')), 'Points');
    expect(guideChipPicked(tester, Strategy.points), isTrue);
    expect(guideChipPicked(tester, Strategy.placement), isFalse);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('Hong Kong hides and pins the dial, riichi restores it',
      (tester) async {
    await tester.binding.setSurfaceSize(kDesignSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Single Player'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('charactersContinue')));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('strategy')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(labelOf(const Key('strategy')), 'Placement');

    await tester.tap(find.byKey(const Key('ruleset')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('strategy')), findsNothing);

    // Hong Kong -> Taiwanese: still Chinese-style, so the dial stays hidden
    // and pinned rather than being restored here.
    await tester.tap(find.byKey(const Key('ruleset')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('strategy')), findsNothing);

    await tester.tap(find.byKey(const Key('ruleset')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(labelOf(const Key('strategy')), 'Placement',
        reason: 'restored on the way back to riichi');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  test('the setting reaches the guide via GameController', () {
    Sfx.i.enabled = false;
    final game = GameController(seed: 11);
    try {
      final round = game.round;
      round.seats[kHumanSeat].hand = parseTiles('777m 227999p 33367s');
      round.turn = kHumanSeat;
      round.phase = RoundPhase.discarding;

      game.setStrategy(Strategy.placement);
      expect(game.strategy, Strategy.placement);
      expect(game.report.lines, isNotEmpty,
          reason: 'setStrategy should have refreshed the report');

      game.setStrategy(Strategy.points);
      expect(game.strategy, Strategy.points);
      expect(game.report.lines, isNotEmpty);
    } finally {
      game.dispose();
      Sfx.i.enabled = true;
    }
  });
}

/// The label a cycling dial button is currently showing.
String labelOf(Key key) => (find
        .descendant(of: find.byKey(key), matching: find.byType(Text))
        .evaluate()
        .first
        .widget as Text)
    .data!;

/// Whether the guide panel's chip for [strategy] is rendering as the picked
/// one — mirrors the equivalent [PlayStyle] helper in play_style_test.dart.
bool guideChipPicked(WidgetTester tester, Strategy strategy) {
  final text = tester.widget<Text>(find.descendant(
    of: find.byKey(Key('guideStrategy_${strategy.name}')),
    matching: find.byType(Text),
  ));
  return text.style?.color == strategyColor(strategy);
}
