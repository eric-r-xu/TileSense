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
      // 7p is the dora. Cutting it leaves a two-sided wait on pinfu — the quick
      // cheap line; cutting 4p keeps it on a closed wait — the slow rich one.
      // The two have to genuinely trade chance for payout. A line that is
      // worse on both halves moves whichever way its two gaps happen to
      // balance, which says nothing about the dial.
      double quickOverRich(HandFocus focus) {
        final r = read('234m 567m 234s 88p 4p 5p 7p',
            focus: focus, dora: const [TileType.pin6]);
        final rich = r.lines.firstWhere((l) => l.discard == TileType.pin4);
        final quick = r.lines.firstWhere((l) => l.discard == TileType.pin7);
        expect(quick.winProbability, greaterThan(rich.winProbability));
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

  group('it changes what the guide tells you to do', () {
    test('Speed throws a lone dora for width; the others keep it', () {
      // The S indicator makes W the dora, and it sits alone. Cutting it is the
      // wide, quick line; cutting 4p keeps the dora and what it pays. That is
      // exactly the trade the dial is there to make.
      DiscardLine pick(HandFocus focus) => read('345m 7m 345p 4p 3s 566s 9s W',
              focus: focus,
              dora: const [TileType.sou8, TileType.nan],
              wall: 40)
          .lines
          .firstWhere((l) => l.recommended);

      final speed = pick(HandFocus.speed);
      final value = pick(HandFocus.value);
      expect(speed.discard, TileType.shaa);
      expect(pick(HandFocus.balanced).discard, TileType.pin4);
      expect(value.discard, TileType.pin4);
      expect(speed.winProbability, greaterThan(value.winProbability));
      expect(speed.averagePoints, lessThan(value.averagePoints));
    });

    GuidedAction call(
      String spec,
      TileType offered, {
      required HandFocus focus,
      List<TileType> dora = const [TileType.pin4],
      int wall = 50,
    }) {
      final hand = parseTiles(spec);
      final visible = toCounts34(hand)..[offered.index - 1] += 1;
      for (final t in dora) {
        visible[t.index - 1]++;
      }
      return EfficiencyEngine()
          .adviseCall(
            hand: hand,
            offered: Tile(999, offered),
            available: {
              if (hand.where((t) => t.type == offered).length >= 2)
                GuidedAction.pon,
              if (!offered.isHonor) GuidedAction.chi,
            },
            visibleCounts34: visible,
            context: EfficiencyValueContext(
              melds: const <Meld>[],
              roundWind: Wind.east,
              seatWind: Wind.south,
              isDealer: false,
              inRiichi: false,
              wallTilesRemaining: wall,
              doraIndicators: dora,
              focus: focus,
            ),
          )
          .recommended;
    }

    test('Value turns down the cheap pon that the others take', () {
      // Ponning green gets you moving on a 1000-point hand; staying closed
      // keeps riichi, and the bigger hand that comes with it, on the table.
      const spec = '123m 56m 788s NN GG R';
      expect(call(spec, TileType.hatsu, focus: HandFocus.speed, wall: 54),
          GuidedAction.pon);
      expect(call(spec, TileType.hatsu, focus: HandFocus.balanced, wall: 54),
          GuidedAction.pon);
      expect(call(spec, TileType.hatsu, focus: HandFocus.value, wall: 54),
          GuidedAction.pass);
    });

    test('Speed takes a chi to tenpai that the others turn down', () {
      // The green triplet is already a yaku, so the chi is tenpai at once —
      // but it gives up riichi and menzen for it.
      const spec = '123m 56m 788s NN GGG';
      expect(call(spec, TileType.sou6, focus: HandFocus.speed),
          GuidedAction.chi);
      expect(call(spec, TileType.sou6, focus: HandFocus.balanced),
          GuidedAction.pass);
      expect(call(spec, TileType.sou6, focus: HandFocus.value),
          GuidedAction.pass);
    });

    test('Value still takes a call that pays', () {
      // Same pon to tenpai on red twice over: cheap, Value stays closed; with
      // red as dora it is a big hand already, and Value takes it.
      const spec = '1m 234m 567m 78p 99s RR';
      expect(
          call(spec, TileType.chun,
              focus: HandFocus.value, dora: const [TileType.pei]),
          GuidedAction.pass);
      expect(
          call(spec, TileType.chun,
              focus: HandFocus.value, dora: const [TileType.hatsu]),
          GuidedAction.pon);
      expect(
          call(spec, TileType.chun,
              focus: HandFocus.speed, dora: const [TileType.pei]),
          GuidedAction.pon);
    });
  });

  test('no setting picks a line that is worse on both halves', () {
    // A tilt reorders lines that trade chance against payout. It must never
    // prefer a line that is simply worse — no better paid, and far less
    // likely to get home. Value once did: the riichi deposit was capped with
    // the plain chance while the line was valued with the tilted one, so a
    // hand could gain by getting *less* likely to win.
    final rng = Random(4242);
    final offenders = <String>[];
    var positions = 0;
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
        positions++;
        DiscardLine? balanced;
        for (final focus in HandFocus.values) {
          final lines = EfficiencyEngine()
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
                  focus: focus,
                ),
              )
              .lines;
          final pick = lines.firstWhere((l) => l.recommended);
          if (focus == HandFocus.balanced) balanced = pick;
          // Same distance from tenpai, at least as well paid, and clearly
          // likelier — a small gap in chance is a real trade, not an error.
          final better = lines.where((o) =>
              o.shanten == pick.shanten &&
              o.averagePoints >= pick.averagePoints - 1e-6 &&
              o.winProbability > pick.winProbability * 1.25 + 0.02);
          if (better.isNotEmpty) {
            offenders.add('${focus.label} cut ${pick.discard.code} '
                '(${(pick.winProbability * 100).round()}%) over '
                '${better.first.discard.code} '
                '(${(better.first.winProbability * 100).round()}%)');
          }
        }
        if (balanced!.shanten == 0) break;
        tiles.remove(balanced.discard);
        pond.add(balanced.discard);
        tiles.add(wall[next++]);
      }
    }
    expect(positions, greaterThan(2000), reason: 'the sweep really ran');
    expect(offenders, isEmpty,
        reason: '${offenders.length} dominated picks, first few: '
            '${offenders.take(3).join('; ')}');
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
