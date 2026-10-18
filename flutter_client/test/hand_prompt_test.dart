import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/round.dart';
import 'package:mahjong_core/tile.dart';
import 'package:tilesense/game/call_callout.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/ui/beginner_guide.dart';
import 'package:tilesense/ui/hand_view.dart';
import 'package:tilesense/ui/tile_face.dart';

import 'helpers.dart';

/// Beginner help on the hand bar: a plain sentence about what you can do, and
/// a glow on the tiles a pending call would use.
void main() {
  const glow = Color(0xff26c6da);

  setUp(() {
    CallCallout.i.clear();
    Sfx.i.enabled = false;
    BeginnerGuide.set(true);
  });
  tearDown(() {
    BeginnerGuide.set(false);
    Sfx.i.enabled = true;
  });

  /// Seat 3 cuts [fed]; seat 0 is its kamicha, so seat 0 is offered the call.
  GameController awaitingCall(Tile fed, {required String hand}) {
    final game = GameController(seed: 4)..autoWin = false;
    final round = game.round;
    round.seats[kHumanSeat]
      ..hand = parseTiles(hand)
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

  GameController onTurn() {
    final game = GameController(seed: 4)..autoWin = false;
    final round = game.round;
    final drawn = Tile(900, TileType.pin9);
    round.seats[kHumanSeat]
      ..hand = [...parseTiles('135m 468m 27p 159s 37s'), drawn]
      ..drawn = drawn
      ..melds = [];
    round.turn = kHumanSeat;
    round.phase = RoundPhase.discarding;
    game.togglePause();
    return game;
  }

  Future<void> pumpBar(WidgetTester tester, GameController game,
      {bool guide = true, bool hasToggle = true}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HandView(
            game: game,
            onToggleGuide: hasToggle ? () {} : null,
            showGuide: guide),
      ),
    ));
    await tester.pump();
  }

  int glowing(WidgetTester tester) => tester
      .widgetList<TileFace>(find.byType(TileFace))
      .where((t) => t.highlightColor == glow)
      .length;

  String? prompt(WidgetTester tester) {
    final f = find.byKey(const Key('handPrompt'));
    return f.evaluate().isEmpty ? null : tester.widget<Text>(f).data;
  }

  Future<void> withCall(WidgetTester tester, String hand, TileType fed,
      Future<void> Function(GameController game) body) async {
    final game = awaitingCall(Tile(900, fed), hand: hand);
    try {
      await pumpUntil(tester, () => game.awaitingHumanCall);
      await body(game);
    } finally {
      game.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }
  }

  testWidgets('a pon offer names the call and glows the matching pair',
      (tester) async {
    await withCall(tester, '55p 147m 258s 369m 24s', TileType.pin5,
        (game) async {
      await pumpBar(tester, game);
      expect(prompt(tester), contains('You can'));
      expect(prompt(tester), contains('Pon'));
      expect(prompt(tester), contains('or pass'));
      expect(glowing(tester), 2);
    });
  });

  testWidgets('a chi offer glows the two tiles that make the run',
      (tester) async {
    await withCall(tester, '46p 147m 258s 369m 24s', TileType.pin5,
        (game) async {
      await pumpBar(tester, game);
      expect(prompt(tester), contains('Chi'));
      expect(glowing(tester), 2);
    });
  });

  testWidgets('several possible runs glow every tile that could join one',
      (tester) async {
    await withCall(tester, '3467m 123p 456p 99s 7s', TileType.man5,
        (game) async {
      await pumpBar(tester, game);
      expect(glowing(tester), 4);
    });
  });

  testWidgets('your own turn says to tap a tile to discard it',
      (tester) async {
    final game = onTurn();
    try {
      await pumpBar(tester, game);
      expect(prompt(tester), contains('tap a tile to discard'));
      expect(glowing(tester), 0);
    } finally {
      game.dispose();
    }
  });

  testWidgets('nothing shows with the full guide, no guide, or in multiplayer',
      (tester) async {
    await withCall(tester, '55p 147m 258s 369m 24s', TileType.pin5,
        (game) async {
      BeginnerGuide.set(false);
      await pumpBar(tester, game);
      expect(prompt(tester), isNull, reason: 'full guide view');
      expect(glowing(tester), 0);

      BeginnerGuide.set(true);
      await pumpBar(tester, game, guide: false);
      expect(prompt(tester), isNull, reason: 'guide hidden');
      expect(glowing(tester), 0);

      await pumpBar(tester, game, hasToggle: false);
      expect(prompt(tester), isNull, reason: 'no guide online');
      expect(glowing(tester), 0);
    });
  });

  testWidgets('switching views updates the bar in place', (tester) async {
    final game = onTurn();
    try {
      await pumpBar(tester, game);
      expect(prompt(tester), isNotNull);
      BeginnerGuide.set(false);
      await tester.pump();
      expect(prompt(tester), isNull);
    } finally {
      game.dispose();
    }
  });
}
