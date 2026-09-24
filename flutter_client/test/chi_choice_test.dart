import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/round.dart';
import 'package:mahjong_core/tile.dart';
import 'package:tilesense/game/call_callout.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/ui/hand_view.dart';

import 'helpers.dart';

/// When one discard can be chowed into several runs, you pick which — the
/// guide's choice used to be made for you — and a riichi-capable hand says so
/// whether or not the guide would declare it.
void main() {
  // `CallCallout` is a process-wide singleton and its `remaining` reads the
  // wall clock, which a widget test's fake clock never advances. The game loop
  // adds that remainder to its step timer, so a bubble left over from the
  // previous test in this file would silently delay this one's.
  setUp(CallCallout.i.clear);

  /// Seat 3 cuts [fed]; seat 0 is its kamicha, so seat 0 is offered the call.
  GameController awaitingCall(Tile fed, {required String seat0Hand}) {
    final game = GameController(seed: 4);
    game.autoWin = false; // these exercise the manual win/call buttons
    final round = game.round;
    round.seats[kHumanSeat]
      ..hand = parseTiles(seat0Hand)
      ..drawn = null
      ..melds = [];
    round.seats[3]
      ..hand = [...parseTiles('123m 456m 789m 111s 2p'), fed]
      ..drawn = fed;
    round.turn = 3;
    round.phase = RoundPhase.discarding;
    round.discard(3, fed);
    return game;
  }

  // 3-4, 4-6 and 6-7 of man each make a run with a 5m.
  const manyRuns = '3467m 123p 456p 99s 7s';

  Future<GameController> boot(WidgetTester tester, String hand) async {
    Sfx.i.enabled = false; // no audio plugin under a test binding
    addTearDown(() => Sfx.i.enabled = true);
    final game = awaitingCall(Tile(900, TileType.man5), seat0Hand: hand);
    await pumpUntil(tester, () => game.awaitingHumanCall);
    expect(game.awaitingHumanCall, isTrue);
    return game;
  }

  testWidgets('every run the discard could make is offered', (tester) async {
    final game = await boot(tester, manyRuns);
    try {
      expect(game.humanChiRuns,
          [TileType.man3, TileType.man4, TileType.man5]);
    } finally {
      game.dispose();
    }
  });

  for (final run in [
    (TileType.man3, '345'),
    (TileType.man4, '456'),
    (TileType.man5, '567'),
  ]) {
    testWidgets('chowing ${run.$2}m takes exactly that run', (tester) async {
      final game = await boot(tester, manyRuns);
      try {
        game.answerCall(CallType.chi, chiLow: run.$1);
        final meld = game.round.seats[kHumanSeat].melds.single;
        expect(meld.low, run.$1);
        expect(meld.tiles.map((t) => t.type).toSet().length, 3);
      } finally {
        game.dispose();
      }
    });
  }

  testWidgets('the call bar has a button per run, and each takes its own',
      (tester) async {
    final game = await boot(tester, manyRuns);
    try {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: HandView(game: game, onToggleGuide: () {})),
      ));
      await tester.pump();

      for (final low in ['man3', 'man4', 'man5']) {
        expect(find.byKey(Key('chiRun_$low')), findsOneWidget, reason: low);
      }
      expect(find.textContaining('345m'), findsOneWidget);
      expect(find.textContaining('567m'), findsOneWidget);

      await tester.tap(find.byKey(const Key('chiRun_man5')));
      await tester.pump();
      expect(game.round.seats[kHumanSeat].melds.single.low, TileType.man5);
    } finally {
      game.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }
  });

  testWidgets('a single possible run keeps the plain Chi button',
      (tester) async {
    Sfx.i.enabled = false;
    addTearDown(() => Sfx.i.enabled = true);
    final game = awaitingCall(Tile(901, TileType.pin5),
        seat0Hand: '46p 123m 456m 789m 99s');
    try {
      await pumpUntil(tester, () => game.awaitingHumanCall);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: HandView(game: game, onToggleGuide: () {})),
      ));
      await tester.pump();

      expect(game.humanChiRuns, [TileType.pin4]);
      expect(find.text('CHI'), findsOneWidget);
      expect(find.byKey(const Key('chiRun_pin4')), findsNothing);
    } finally {
      game.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }
  });

  group('riichi available', () {
    /// Human to move, closed and one discard from tenpai on 3p.
    GameController onTurn({bool tenpaiAfterDiscard = true}) {
      final game = GameController(seed: 4);
    game.autoWin = false; // these exercise the manual win/call buttons
      final round = game.round;
      final drawn = Tile(900, TileType.pin9);
      round.seats[kHumanSeat]
        ..hand = [
          ...parseTiles(tenpaiAfterDiscard
              ? '123m 456m 789m 12p 55s'
              : '135m 468m 27p 159s 37s'),
          drawn,
        ]
        ..drawn = drawn
        ..melds = [];
      round.turn = kHumanSeat;
      round.phase = RoundPhase.discarding;
      game.togglePause();
      return game;
    }

    Future<void> pumpBar(WidgetTester tester, GameController game,
        {bool guide = true}) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: HandView(
              game: game, onToggleGuide: () {}, showGuide: guide),
        ),
      ));
      await tester.pump();
    }

    testWidgets('shows whenever riichi is legal, guide on or off',
        (tester) async {
      for (final guide in [true, false]) {
        final game = onTurn();
        try {
          expect(game.humanCanRiichi, isTrue);
          await pumpBar(tester, game, guide: guide);
          expect(find.byKey(const Key('riichiAvailable')), findsOneWidget,
              reason: 'guide=$guide');
          if (!guide) {
            expect(find.textContaining('recommended'), findsNothing,
                reason: 'the guide is off, so it has no opinion to show');
          }
        } finally {
          game.dispose();
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
        }
      }
    });

    testWidgets('is absent when no discard leaves the hand tenpai',
        (tester) async {
      final game = onTurn(tenpaiAfterDiscard: false);
      try {
        expect(game.humanCanRiichi, isFalse);
        await pumpBar(tester, game);
        expect(find.byKey(const Key('riichiAvailable')), findsNothing);
      } finally {
        game.dispose();
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      }
    });
  });
}
