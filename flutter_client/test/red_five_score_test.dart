import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/game_timing.dart';
import 'package:mahjong_core/mahjong_core.dart';
import 'package:tilesense/game/call_callout.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/ui/scoring_view.dart';
import 'package:tilesense/ui/tile_face.dart';

import 'helpers.dart';

Round _round(Ruleset ruleset) => Round.posed(
      dealer: 0,
      roundWind: Wind.east,
      ruleset: ruleset,
      wall: ruleset.isSanma
          ? SanmaWall.posed(remaining: 0, dora: const [])
          : Wall.posed(remaining: 0, dora: const []),
      startingPoints: [
        for (var i = 0; i < 4; i++)
          ruleset.seatIsActive(i) ? ruleset.startingPoints : 0,
      ],
    );

(Round, Tile) _meldResult(Ruleset ruleset, String call,
    {bool draw = false, bool physicalTiles = true}) {
  final round = _round(ruleset);
  const red = Tile(900, TileType.pin5, aka: true);
  final sequence = call == 'chi';
  final kan = call.contains('kan');
  final meld = Meld(
    kind:
        sequence ? MeldKind.sequence : (kan ? MeldKind.kan : MeldKind.triplet),
    low: sequence ? TileType.pin4 : TileType.pin5,
    concealed: call == 'concealed kan',
    addedKan: call == 'added kan',
    calledFromSeatOffset: call == 'concealed kan' ? null : 3,
    tiles: physicalTiles
        ? [
            if (sequence) ...[
              const Tile(901, TileType.pin4),
              const Tile(902, TileType.pin6),
            ] else ...[
              const Tile(901, TileType.pin5),
              const Tile(902, TileType.pin5),
              if (kan) const Tile(903, TileType.pin5),
            ],
            red,
          ]
        : const [],
  );
  final seat = round.seats[1];
  seat.melds = [meld];
  seat.hand = parseTiles('BBB 123s 789s 22p');
  if (draw) {
    seat.hand.removeLast();
    round.beginPosedPlay();
  } else {
    seat.drawn = seat.hand.last;
    round.turn = 1;
    round.declareTsumo(1);
  }
  return (round, red);
}

Round _online(Round round) {
  final wire =
      jsonDecode(jsonEncode(roundSnapshotToJson(round, reveal: (_) => true)))
          as Map<String, dynamic>;
  return buildRoundFromSnapshot(wire, mySeat: 3);
}

void main() {
  setUp(() {
    Sfx.i.enabled = false;
    CallCallout.i.clear();
  });
  tearDown(() => Sfx.i.enabled = true);

  Future<void> showResult(
      WidgetTester tester, Round round, Future<void> Function() check) async {
    final game = GameController(seed: 5, ruleset: round.ruleset)..paused = true;
    game.round = round;
    game.phase = GamePhase.roundEnd;
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    try {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: ScoringView(game: game, autoContinue: false))));
      await tester.pump(kWinScorePause);
      await tester.pump();
      await check();
      expect(tester.takeException(), isNull);
    } finally {
      game.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.binding.setSurfaceSize(null);
    }
  }

  Finder redFace(Tile red) => find.byWidgetPredicate(
      (w) => w is TileFace && w.tile?.id == red.id && w.tile!.aka);

  for (final ruleset in [Ruleset.riichi, Ruleset.sanma]) {
    for (final online in [false, true]) {
      for (final call in [
        if (ruleset.isRiichi) 'chi',
        'pon',
        'open kan',
        'concealed kan',
        'added kan',
      ]) {
        testWidgets('${ruleset.name} $call red five, online=$online',
            (tester) async {
          final (source, red) = _meldResult(ruleset, call);
          final round = online ? _online(source) : source;
          final score = round.result!.score!;
          expect(score.valid, isTrue);
          expect(score.yaku.singleWhere((y) => y.name == 'Aka Dora').han, 1);
          await showResult(tester, round, () async {
            expect(redFace(red), findsOneWidget);
            // The score breakdown and the actual red tile agree.
            expect(find.text('Aka Dora'), findsOneWidget);
          });
        });
      }

      testWidgets('${ruleset.name} tenpai meld red five, online=$online',
          (tester) async {
        final (source, red) = _meldResult(ruleset, 'pon', draw: true);
        final round = online ? _online(source) : source;
        expect(round.result!.kind, RoundEndKind.exhaustiveDraw);
        expect(round.result!.tenpaiAtDraw, hasLength(1));
        await showResult(tester, round, () async {
          expect(redFace(red), findsOneWidget);
        });
      });

      for (final winningRed in [false, true]) {
        testWidgets(
            '${ruleset.name} concealed/winning red five=$winningRed, online=$online',
            (tester) async {
          final source = _round(ruleset);
          final seat = source.seats[1];
          seat.hand = parseTiles('123p 456p 789s BBB 22s');
          final index = seat.hand.indexWhere((t) => t.type == TileType.pin5);
          const red = Tile(900, TileType.pin5, aka: true);
          seat.hand[index] = red;
          seat.drawn = winningRed ? red : seat.hand.last;
          source.turn = 1;
          source.declareTsumo(1);
          final round = online ? _online(source) : source;
          expect(
              round.result!.score!.yaku
                  .singleWhere((y) => y.name == 'Aka Dora')
                  .han,
              1);
          await showResult(tester, round, () async {
            expect(redFace(red), findsOneWidget);
          });
        });
      }
    }

    testWidgets('${ruleset.name} type-only melds still show every tile',
        (tester) async {
      final (round, _) = _meldResult(ruleset, 'pon', physicalTiles: false);
      await showResult(tester, round, () async {
        final fives = tester
            .widgetList<TileFace>(find.byType(TileFace))
            .where((face) => (face.tile?.type ?? face.type) == TileType.pin5);
        expect(fives, hasLength(3));
      });
    });
  }
}
