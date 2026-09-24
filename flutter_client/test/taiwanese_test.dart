import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/mahjong_core.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/logic/efficiency_engine.dart';
import 'package:tilesense/scenario/scenario.dart';
import 'package:tilesense/ui/meld_row.dart';
import 'package:tilesense/ui/tile_face.dart';

import 'helpers.dart';

/// Taiwanese's 16-tile hand (5 melds and a pair, 17 with the winning tile)
/// reaching the parts of the app that were written for riichi and Hong Kong's
/// 13: the guide's shanten search, the round's own wait list, the builder's
/// hand size, and the riichi-only rules it must not pick up.
void main() {
  // 123m 456m 789m 234p 567p + a lone 9s: five melds, waiting on the pair.
  const readyHand = '123456789m 234567p 9s';

  Round freshRound(Ruleset ruleset) => Round(
        seed: 7,
        dealer: 0,
        roundWind: Wind.east,
        startingPoints: List.filled(4, ruleset.startingPoints),
        ruleset: ruleset,
      );

  test('the ruleset knows its hand size', () {
    expect(Ruleset.riichi.totalMelds, 4);
    expect(Ruleset.hongKong.totalMelds, 4);
    expect(Ruleset.taiwanese.totalMelds, 5);
    expect(Ruleset.riichi.concealedHandSize, 13);
    expect(Ruleset.hongKong.concealedHandSize, 13);
    expect(Ruleset.taiwanese.concealedHandSize, 16);
  });

  test('the guide counts shanten against five melds, not four', () {
    final calc = TileEfficiencyCalculator();
    final counts = toTrainerCounts(parseTiles(readyHand));
    expect(calc.calculateWaitingShanten(counts, totalMelds: 5), 0);

    final remaining = List<int>.filled(38, 4);
    final acceptance = calc.acceptance(counts, remaining, totalMelds: 5);
    expect(acceptance.tiles, [trainerIndexOf(TileType.sou9)]);

    // Read as a 4-meld hand the same 16 tiles are already "complete" with
    // tiles to spare — what the guide reported before it passed totalMelds.
    expect(calc.calculateWaitingShanten(counts), lessThan(0));
  });

  test('the round lists a 16-tile hand\'s waits', () {
    final round = freshRound(Ruleset.taiwanese);
    round.seats[1].hand = parseTiles(readyHand);
    expect(round.waitsFor(1), [TileType.sou9]);
  });

  test('scores a closed self-drawn hand by adding its patterns', () {
    final score = scoreTaiwaneseHand(
      parseTiles(readyHand),
      Tile(99, TileType.sou9),
      const [],
      ScoreContext(
        roundWind: Wind.east,
        seatWind: Wind.south,
        isTsumo: true,
        closed: true,
        discardCount: 20,
      ),
      isDealer: false,
    );
    expect(score.valid, isTrue);
    expect({for (final y in score.yaku) y.name: y.faan}, {
      'Pure Straight': 5,
      'All Chows': 10,
      'No Flower or Honor Tiles': 3,
      'Self-Drawn': 1,
      'Fully Concealed Hand': 3,
      'Single Wait': 2,
    });
    expect(score.points, 24);
    expect(score.nonDealerPays, 24);
    expect(score.dealerPays, 24, reason: 'no dealer premium');
  });

  test('kyuushu kyuuhai is riichi-only', () {
    final round = freshRound(Ruleset.taiwanese);
    round.seats[0].hand = parseTiles('19m 19p 19s ESWNBGR 234m 5m');
    round.turn = 0;
    round.phase = RoundPhase.discarding;
    expect(round.canDeclareKyuushu(0), isFalse);
  });

  test('the builder asks for 16 tiles, 17 with the draw', () {
    final s = Scenario()..ruleset = Ruleset.taiwanese;
    expect(s.concealedTarget(withDraw: false), 16);
    expect(s.concealedTarget(withDraw: true), 17);
    s.ruleset = Ruleset.riichi;
    expect(s.concealedTarget(withDraw: false), 13);
    expect(s.concealedTarget(withDraw: true), 14);
  });

  group('concealed kongs', () {
    Meld concealedKong() => Meld(
          kind: MeldKind.kan,
          low: TileType.pin5,
          concealed: true,
          tiles: [for (var i = 0; i < 4; i++) Tile(500 + i, TileType.pin5)],
        );

    test('are hidden under Taiwanese rules only, and only until the hand ends',
        () {
      final kong = concealedKong();
      final open = Meld(
          kind: MeldKind.kan,
          low: TileType.pin5,
          concealed: false,
          tiles: kong.tiles);
      expect(freshRound(Ruleset.riichi).isHiddenKong(kong), isFalse);
      expect(freshRound(Ruleset.hongKong).isHiddenKong(kong), isFalse);
      final round = freshRound(Ruleset.taiwanese);
      expect(round.isHiddenKong(kong), isTrue);
      expect(round.isHiddenKong(open), isFalse);

      round.result = RoundResult(
        kind: RoundEndKind.exhaustiveDraw,
        winners: const [],
        pointDeltas: const {},
        label: 'Exhaustive Draw',
      );
      expect(round.isHiddenKong(kong), isFalse);
    });

    test('go over the wire as blanks to every seat but their owner', () {
      final round = freshRound(Ruleset.taiwanese);
      round.seats[1].melds.add(concealedKong());
      final json = roundSnapshotToJson(round, reveal: (seat) => seat == 1);
      Map<String, dynamic> meldOf(int seat) =>
          ((json['seats'] as List)[seat] as Map)['melds'][0]
              as Map<String, dynamic>;
      expect(meldOf(1)['low'], 'pin5');

      final other = roundSnapshotToJson(round, reveal: (seat) => seat == 0);
      final hidden =
          ((other['seats'] as List)[1] as Map)['melds'][0] as Map;
      expect(hidden['low'], 'blank');
      expect(hidden['concealed'], isTrue);
      expect([for (final t in hidden['tiles'] as List) t['type']],
          everyElement('blank'));

      // A riichi table keeps showing it, as before.
      final riichi = freshRound(Ruleset.riichi);
      riichi.seats[1].melds.add(concealedKong());
      final riichiJson =
          roundSnapshotToJson(riichi, reveal: (seat) => seat == 0);
      expect(((riichiJson['seats'] as List)[1] as Map)['melds'][0]['low'],
          'pin5');
    });

    testWidgets('draw all four tiles face down when asked to', (tester) async {
      Future<int> faceDownCount({required bool faceDown}) async {
        await tester.pumpWidget(MaterialApp(
            home: MeldRow(concealedKong(), faceDown: faceDown)));
        return tester
            .widgetList<TileFace>(find.byType(TileFace))
            .where((t) => t.faceDown)
            .length;
      }

      expect(await faceDownCount(faceDown: false), 2);
      expect(await faceDownCount(faceDown: true), 4);
    });
  });

  testWidgets(
      'the guide values a Taiwanese turn instead of writing every line off',
      (tester) async {
    // It once checked for a 13-tile hand, so every 16-tile line fell into
    // the off-turn DEFENSE read and was worth nothing.
    Sfx.i.enabled = false;
    final game = GameController(seed: 1003, ruleset: Ruleset.taiwanese);
    try {
      for (var i = 0; i < 200 && !game.isHumanTurn; i++) {
        await tester.pump(const Duration(milliseconds: 1104));
      }
      expect(game.isHumanTurn, isTrue);
      final lines = game.report.lines;
      expect(lines, isNotEmpty);
      expect(lines.every((l) => l.valuePlan == 'DEFENSE'), isFalse);
      expect(lines.any((l) => l.winProbability > 0), isTrue);
    } finally {
      game.dispose();
      Sfx.i.enabled = true;
    }
  });

  test('the guide plays the call-aware win model, and only for Taiwanese', () {
    expect(HongKongGuideTuning.taiwaneseWinModel.countsCalls, isTrue);
    expect(HongKongGuideTuning.winModel.countsCalls, isFalse);
    expect(HongKongGuideTuning.threatSetsFor(Ruleset.taiwanese), 4);
    expect(HongKongGuideTuning.threatSetsFor(Ruleset.hongKong), 3);
  });
}
