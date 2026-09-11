import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/main.dart';
import 'package:tilesense/ui/efficiency_overlay.dart';
import 'package:tilesense/logic/efficiency_engine.dart';
import 'package:tilesense/logic/meld.dart';
import 'package:tilesense/logic/tile.dart';

import 'helpers.dart';

/// The hand-focus dial: which hand the guide chases when two are worth about
/// the same. It is the second axis, independent of [PlayStyle] — that one says
/// how much danger is worth taking, this says what to take it for.
void main() {
  EfficiencyReport read(
    String spec, {
    HandFocus focus = HandFocus.balanced,
    List<TileType> dora = const [TileType.pei],
    int wall = 50,
  }) {
    final hand = parseTiles(spec);
    final visible = toCounts34(hand);
    for (final t in dora) {
      visible[t.index - 1]++;
    }
    return EfficiencyEngine().analyze(
      hand: hand,
      visibleCounts34: visible,
      canRiichi: true,
      valueContext: EfficiencyValueContext(
        melds: const [],
        roundWind: Wind.east,
        seatWind: Wind.south,
        isDealer: false,
        inRiichi: false,
        wallTilesRemaining: wall,
        doraIndicators: dora,
        focus: focus,
      ),
    );
  }

  group('balanced is the untilted reference', () {
    test('it moves nothing at all', () {
      // Speed and Value are opposite exponents on the two halves of
      // `chance x payout`; on Balanced both are 1, so the product has to come
      // back exactly as it was. Any drift here means the dial has stopped
      // being a tilt and started being a thumb on the scale.
      for (final line in read('234m 567m 234p 99s 45s 1m').lines) {
        expect(line.valueTilt, closeTo(0, 1e-9),
            reason: '${line.discard.code} was moved on Balanced');
        final reconstructed =
            line.winProbability * (line.averagePoints + line.winBonus) +
                line.valueTilt -
                line.riichiLockCost -
                line.dealInCost -
                line.commitmentCost;
        expect(line.expectedValue, closeTo(reconstructed, 0.5),
            reason: '${line.discard.code} does not add up');
      }
    });
  });

  group('what the dial moves', () {
    test('the quick cheap line gains on Speed and loses on Value', () {
      // A trade-off dial is only meaningful *between* lines, so that is what
      // is asserted. Comparing one line's own number across the three settings
      // says very little: a line that is both likely and big sits above both
      // pivots, and Value pushes its payout up while pulling its chance down,
      // which can net out either way.
      //
      // 9s is the dora here and the hand holds two. Cutting one is the quick
      // cheap line, keeping them is the slow rich one.
      double quickOverRich(HandFocus focus) {
        final r = read('234m 567m 234p 99s 45s 1m',
            focus: focus, dora: const [TileType.sou8]);
        final rich = r.lines.firstWhere((l) => l.discard == TileType.man1);
        final quick = r.lines.firstWhere((l) => l.discard == TileType.sou9);
        expect(quick.winProbability, lessThan(rich.winProbability));
        expect(quick.averagePoints, lessThan(rich.averagePoints));
        return quick.expectedValue / rich.expectedValue;
      }

      expect(quickOverRich(HandFocus.speed),
          greaterThan(quickOverRich(HandFocus.balanced)));
      expect(quickOverRich(HandFocus.balanced),
          greaterThan(quickOverRich(HandFocus.value)));
    });

    test('it does not change what a hand actually pays', () {
      // The tilt is a preference, not a rescoring. What the hand pays when it
      // wins is a fact about the hand, and the table column that reports it
      // has to stay put whichever way the dial is set.
      List<double> paid(HandFocus f) => [
            for (final l in read('234m 567m 234p 99s 45s 1m', focus: f).lines)
              l.averagePoints,
          ];
      expect(paid(HandFocus.speed), paid(HandFocus.balanced));
      expect(paid(HandFocus.value), paid(HandFocus.balanced));
    });

    test('a line is quoted off the dora it keeps, not the hand it came from',
        () {
      // Without this every discard is quoted the same payout however much
      // value it throws away, and the dial has nothing to bite on: a tilt
      // applied equally to every line reorders none of them.
      final r = read('234m 567m 234p 99s 45s 1m',
          dora: const [TileType.sou8]); // dora is 9s, and the hand holds two
      final keeps = r.lines.firstWhere((l) => l.discard == TileType.man1);
      final cuts = r.lines.firstWhere((l) => l.discard == TileType.sou9);
      expect(cuts.averagePoints, lessThan(keeps.averagePoints),
          reason: 'cutting a dora has to cost the line something');
    });
  });

  group('across simulated play', () {
    test('Speed buys the chance, Value buys the payout', () {
      final rng = Random(4242);
      var positions = 0, differ = 0;
      var speedChance = 0.0, valueChance = 0.0;
      var speedPoints = 0.0, valuePoints = 0.0;

      for (var game = 0; game < 250; game++) {
        final wall = <TileType>[
          for (var i = 0; i < 34; i++)
            for (var c = 0; c < 4; c++) typeFrom34(i),
        ]..shuffle(rng);
        var next = 0;
        final tiles = <TileType>[for (var i = 0; i < 14; i++) wall[next++]];
        final pond = <TileType>[];
        final dora = [wall[next++], wall[next++]];

        for (var turn = 0; turn < 12 && next < wall.length; turn++) {
          var id = 0;
          final hand = tiles.map((t) => Tile(id++, t)).toList();
          final seen = List<int>.filled(34, 0);
          for (final t in [...tiles, ...pond, ...dora]) {
            seen[t.index - 1]++;
          }
          DiscardLine pick(HandFocus f) => EfficiencyEngine()
              .analyze(
                hand: hand,
                visibleCounts34: seen,
                canRiichi: true,
                valueContext: EfficiencyValueContext(
                  melds: const [],
                  roundWind: Wind.east,
                  seatWind: Wind.south,
                  isDealer: false,
                  inRiichi: false,
                  wallTilesRemaining: 70 - turn * 4,
                  doraIndicators: dora,
                  focus: f,
                ),
              )
              .lines
              .firstWhere((l) => l.recommended);

          final fast = pick(HandFocus.speed);
          final rich = pick(HandFocus.value);
          positions++;
          if (fast.discard != rich.discard) {
            differ++;
            speedChance += fast.winProbability;
            valueChance += rich.winProbability;
            speedPoints += fast.averagePoints;
            valuePoints += rich.averagePoints;
          }

          final bal = pick(HandFocus.balanced);
          if (bal.shanten == 0) break;
          tiles.remove(bal.discard);
          pond.add(bal.discard);
          tiles.add(wall[next++]);
        }
      }

      // A dial nobody can see moving is not a dial. This is the guard against
      // it quietly going inert again — it did once, when the tilt was applied
      // only to the payout, which every line in a hand shares.
      expect(differ / positions, greaterThan(0.02),
          reason: 'the dial changed the recommendation in only $differ of '
              '$positions positions');

      // And when it does move, it has to move the right way: Speed pays points
      // for a better chance of getting there, Value does the reverse.
      expect(speedChance / differ, greaterThan(valueChance / differ));
      expect(speedPoints / differ, lessThan(valuePoints / differ));
    });
  });

  test('a call is scored on the dials that are actually set', () {
    // Both places that rebuilt the context to score a call did it by hand and
    // dropped the dials, the honba and the sticks, so every call was weighed
    // as though the table were flat and the guide sat on Balanced.
    CallAdvice advise({required HandFocus focus, required int honba}) {
      final hand = parseTiles('1m 234m 567m 78p 99s RR');
      final visible = toCounts34(hand)
        ..[TileType.chun.index - 1] += 1;
      return EfficiencyEngine().adviseCall(
        hand: hand,
        offered: Tile(999, TileType.chun),
        available: const {GuidedAction.pon},
        visibleCounts34: visible,
        context: EfficiencyValueContext(
          melds: const <Meld>[],
          roundWind: Wind.east,
          seatWind: Wind.south,
          isDealer: false,
          inRiichi: false,
          wallTilesRemaining: 50,
          doraIndicators: const [TileType.pei],
          honba: honba,
          focus: focus,
        ),
      );
    }

    double pon(CallAdvice a) =>
        a.forAction(GuidedAction.pon)!.expectedValue;

    expect(pon(advise(focus: HandFocus.value, honba: 0)),
        isNot(closeTo(pon(advise(focus: HandFocus.speed, honba: 0)), 1)),
        reason: 'the focus dial never reached the call evaluator');
    expect(pon(advise(focus: HandFocus.balanced, honba: 5)),
        greaterThan(pon(advise(focus: HandFocus.balanced, honba: 0))),
        reason: 'the honba never reached the call evaluator');
  });

  testWidgets('the guide panel offers the dial, and it drives the report',
      (tester) async {
    await tester.binding.setSurfaceSize(kDesignSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Start'));
    await tester.pump(const Duration(milliseconds: 100));
    // The guide is off by default; the clefairy mark opens it.
    await tester.tap(find.byKey(const Key('guideToggle')));
    await tester.pump(const Duration(milliseconds: 100));

    // Both dials are there, as two rows of the same kind of chip.
    expect(find.byKey(const Key('guidePlayStyle_balanced')), findsOneWidget);
    for (final focus in HandFocus.values) {
      expect(find.byKey(Key('guideHandFocus_${focus.name}')), findsOneWidget);
    }
    expect(
        find.descendant(
          of: find.byType(EfficiencyOverlay),
          matching: find.text('FOCUS'),
        ),
        findsOneWidget);

    // Which one is picked is read the way a player reads it — off the chip.
    bool picked(HandFocus focus) => tester
            .widget<Text>(find.descendant(
              of: find.byKey(Key('guideHandFocus_${focus.name}')),
              matching: find.byType(Text),
            ))
            .style
            ?.fontWeight ==
        FontWeight.w700;

    expect(picked(HandFocus.balanced), isTrue);
    expect(picked(HandFocus.value), isFalse);

    await tester.tap(find.byKey(const Key('guideHandFocus_value')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(picked(HandFocus.value), isTrue);
    expect(picked(HandFocus.balanced), isFalse);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
