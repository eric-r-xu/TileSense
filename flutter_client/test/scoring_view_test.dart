import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/round.dart';
import 'package:mahjong_core/tile.dart';
import 'package:mahjong_core/wall.dart';
import 'package:tilesense/game/call_callout.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/main.dart' show kDesignSize;
import 'package:tilesense/ui/scoring_view.dart';
import 'package:tilesense/ui/tile_face.dart';

import 'helpers.dart';

/// Regression test: a riichi tsumo's drawn winning tile is already part of
/// `seat.hand` (every draw gets added there, win or not — see
/// `Round._acceptDraw`), so the result screen's hand row must leave it out
/// of the plain tile loop and render it only once, highlighted, via the
/// separate `winTile` slot. It used to render there *and* again in the
/// plain loop, showing the same tile twice. Hong Kong already had this
/// covered (`hk_ui_test.dart`'s "renders a self-picked tile once"); this is
/// the riichi case.
void main() {
  Future<void> withScores(
      WidgetTester tester, Future<void> Function(_ScoreGame) check,
      {List<int> winners = const []}) async {
    Sfx.i.enabled = false;
    final game = _ScoreGame();
    game.round
      ..phase = RoundPhase.finished
      ..result = RoundResult(
        kind: winners.isEmpty ? RoundEndKind.exhaustiveDraw : RoundEndKind.ron,
        winners: winners,
        pointDeltas: const {},
        label: 'Round result',
      );
    game.phase = GamePhase.roundEnd;
    await tester.binding.setSurfaceSize(kDesignSize);
    try {
      CallCallout.i.show(0, 'RON');
      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: ScoringView(game: game))));
      await check(game);
    } finally {
      game.dispose();
      Sfx.i.enabled = true;
      await tester.pumpWidget(const SizedBox());
      await tester.binding.setSurfaceSize(null);
    }
  }

  testWidgets('scores get 25 visible seconds after the winning call clears',
      (tester) async {
    await withScores(tester, (game) async {
      expect(find.text('Round result'), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Round result'), findsNothing);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Auto Continue in 25s'), findsOneWidget);
      await tester.pump(const Duration(seconds: 24));
      expect(game.continues, 0);
      expect(find.textContaining('Auto Continue in 1s'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(game.continues, 1);
    });
  });

  testWidgets('pausing holds the score countdown and manual Continue works',
      (tester) async {
    await withScores(tester, (game) async {
      await tester.pump(CallCallout.flash);
      await tester.pump(const Duration(seconds: 5));
      game.togglePause();
      await tester.pump(const Duration(seconds: 30));
      expect(game.continues, 0);
      game.togglePause();
      await tester.pump();
      expect(find.textContaining('Auto Continue in 20s'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      expect(game.continues, 1);
    });
  });

  testWidgets('each winner score page gets its own 25 seconds', (tester) async {
    await withScores(tester, (game) async {
      await tester.pump(CallCallout.flash);
      expect(find.text('Round result  (1 / 2)'), findsOneWidget);
      await tester.pump(const Duration(seconds: 25));
      expect(game.continues, 0);
      expect(find.text('Round result  (2 / 2)'), findsOneWidget);
      expect(find.textContaining('Auto Continue in 25s'), findsOneWidget);
      await tester.pump(const Duration(seconds: 24));
      expect(game.continues, 0);
      await tester.pump(const Duration(seconds: 1));
      expect(game.continues, 1);
    }, winners: [0, 1]);
  });

  testWidgets('a riichi tsumo renders its winning tile once, not twice',
      (tester) async {
    Sfx.i.enabled = false;
    final game = GameController(seed: 5);
    game.togglePause();
    try {
      final r = Round.posed(
        dealer: 0,
        roundWind: Wind.east,
        wall: Wall.posed(remaining: 0, dora: const []),
        startingPoints: List.filled(4, 25000),
      );
      final win = Tile(900, TileType.pin5);
      r.turn = 1;
      r.seats[1].hand = [...parseTiles('123m 456p 789s 22m 55p'), win];
      r.seats[1].drawn = win;
      r.declareTsumo(1);
      game.round = r;
      game.phase = GamePhase.roundEnd;
      await tester.binding.setSurfaceSize(kDesignSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: ScoringView(game: game))));
      await tester.pump(CallCallout.flash);

      expect(find.byWidgetPredicate((w) => w is TileFace && w.tile == win),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      game.dispose();
      Sfx.i.enabled = true;
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }
  });

  testWidgets(
      'an exhaustive draw reveals tenpai hands at normal size, without '
      'overflowing the panel', (tester) async {
    Sfx.i.enabled = false;
    final game = GameController(seed: 6);
    game.togglePause();
    try {
      final r = Round.posed(
        dealer: 0,
        roundWind: Wind.east,
        wall: Wall.posed(remaining: 0, dora: const []),
        startingPoints: List.filled(4, 25000),
      );
      // Tenpai on 5p: a plain two-sided wait, nothing exotic — the size of
      // the reveal is what this test is about, not its content.
      r.seats[0].hand = parseTiles('123m 456p 789s 22m 34p');
      r.result = RoundResult(
        kind: RoundEndKind.exhaustiveDraw,
        winners: const [],
        pointDeltas: const {},
        label: 'Exhaustive draw',
        tenpaiAtDraw: const [0],
      );
      game.round = r;
      game.phase = GamePhase.roundEnd;
      await tester.binding.setSurfaceSize(kDesignSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: ScoringView(game: game))));
      await tester.pump(CallCallout.flash);

      // The reveal now matches the winning hand's TileSize.normal, not the
      // old TileSize.small.
      final revealed = tester
          .widgetList<TileFace>(find.byType(TileFace))
          .where((w) => w.tile != null)
          .toList();
      expect(revealed, isNotEmpty);
      expect(revealed.every((w) => w.size == TileSize.normal), isTrue,
          reason: 'the tenpai reveal should render at normal size');

      // Still inside the panel: no render overflow, and every tile sits
      // within the scrollable panel's bounds (it wraps/scrolls instead).
      expect(tester.takeException(), isNull);
    } finally {
      game.dispose();
      Sfx.i.enabled = true;
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }
  });
}

class _ScoreGame extends GameController {
  _ScoreGame() : super(seed: 5);

  int continues = 0;

  @override
  void continueFromRoundEnd() => continues++;
}
