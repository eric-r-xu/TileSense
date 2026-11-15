import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/mahjong_core.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/online_game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/logic/efficiency_engine.dart';
import 'package:tilesense/ui/hand_view.dart';
import 'package:tilesense/ui/tile_face.dart';

import 'helpers.dart';

Round calledRound(Ruleset ruleset) {
  final round = Round(
    seed: 7,
    dealer: 0,
    roundWind: Wind.east,
    startingPoints: List.filled(4, ruleset.startingPoints),
    ruleset: ruleset,
  );
  round.seats[0]
    ..hand = parseTiles(
        ruleset.isSanma ? '555p 19m 28s 136p ESW' : '1234p 19m 147s ESGB')
    ..drawn = null;
  final fed = Tile(900, ruleset.isSanma ? TileType.pin5 : TileType.pin1);
  round.seats[3].hand.add(fed);
  round.seats[3].drawn = fed;
  round.turn = 3;
  round.phase = RoundPhase.discarding;
  round.discard(3, fed);
  round.resolveCalls(
    {0: ruleset.isSanma ? CallType.pon : CallType.chi},
    chiLow: {0: TileType.pin1},
  );
  return round;
}

void main() {
  setUp(() => Sfx.i.enabled = false);
  tearDown(() => Sfx.i.enabled = true);

  for (final ruleset in [Ruleset.riichi, Ruleset.sanma]) {
    testWidgets('${ruleset.name}: guide and human input respect kuikae',
        (tester) async {
      final game = GameController(seed: 5, ruleset: ruleset)..paused = true;
      try {
        game.round = calledRound(ruleset);
        game.setPlayStyle(PlayStyle.defensive);
        final round = game.round;
        final forbidden = round.seats[0].hand
            .where((t) => round.seats[0].kuikaeForbidden.contains(t.type))
            .toList();
        expect(forbidden, isNotEmpty);
        expect(game.report.lines, isNotEmpty);
        expect(
            game.report.lines.any((line) =>
                round.seats[0].kuikaeForbidden.contains(line.discard)),
            isFalse);

        for (final tile in forbidden) {
          game.humanDiscard(tile);
          expect(round.seats[0].hand, contains(tile));
          expect(round.seats[0].pond, isEmpty);
        }

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: HandView(game: game)),
        ));
        for (final face in tester.widgetList<TileFace>(find.byType(TileFace))) {
          if (forbidden.contains(face.tile)) {
            expect(face.dimmed, isTrue);
            final button = find
                .ancestor(
                    of: find.byWidget(face), matching: find.byType(InkWell))
                .first;
            expect(tester.widget<InkWell>(button).onTap, isNull);
          }
        }
        final legal = round.legalDiscards(0).first;
        game.humanDiscard(legal);
        expect(round.seats[0].pond, [legal]);
        expect(round.seats[0].kuikaeForbidden, isEmpty);
      } finally {
        game.dispose();
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      }
    });

    testWidgets('${ruleset.name}: online input cannot predict an illegal cut',
        (tester) async {
      final game = OnlineGameController()..ruleset = ruleset;
      final sent = <Map<String, dynamic>>[];
      game.debugOnSend = sent.add;
      try {
        final round = calledRound(ruleset);
        game.debugReceive({
          'type': 'state',
          'yourSeat': 0,
          'gamePhase': 'playing',
          'handInWind': 1,
          'tablePoints': List.filled(4, ruleset.startingPoints),
          'discardSerial': 1,
          'lastDiscardSeat': null,
          'lastDiscardTsumogiri': false,
          'turnDeadlineMs': null,
          'round': roundSnapshotToJson(round, reveal: (s) => s == 0),
        });
        final forbidden = game.round.seats[0].hand.firstWhere(
            (t) => game.round.seats[0].kuikaeForbidden.contains(t.type));
        game.humanDiscard(forbidden);
        expect(sent.where((m) => m['kind'] == 'discard'), isEmpty);
        expect(game.round.seats[0].hand, contains(forbidden));
        expect(game.round.seats[0].pond, isEmpty);

        final legal = game.round.legalDiscards(0).first;
        game.humanDiscard(legal);
        expect(sent.where((m) => m['kind'] == 'discard'), hasLength(1));
        expect(game.round.seats[0].pond, [legal]);
        expect(game.round.seats[0].kuikaeForbidden, isEmpty);
      } finally {
        game.dispose();
        await tester.pump(const Duration(seconds: 3));
      }
    });
  }

  test('call advice cannot recommend a chi with no legal following discard',
      () {
    final hand = parseTiles('2344p');
    final advice = EfficiencyEngine().adviseCall(
      hand: hand,
      offered: Tile(900, TileType.pin1),
      available: {GuidedAction.chi},
      visibleCounts34: toCounts34(hand)..[TileType.pin1.index - 1] += 1,
      context: EfficiencyValueContext(
        melds: [
          for (final type in [TileType.ton, TileType.nan, TileType.haku])
            Meld(kind: MeldKind.triplet, low: type, concealed: false),
        ],
        roundWind: Wind.east,
        seatWind: Wind.south,
        isDealer: false,
        inRiichi: false,
        wallTilesRemaining: 40,
        doraIndicators: const [],
      ),
    );
    expect(advice.forAction(GuidedAction.chi)!.eligible, isFalse);
    expect(advice.forAction(GuidedAction.chi)!.discardAfter, isNull);
    expect(advice.recommended, GuidedAction.pass);
  });
}
