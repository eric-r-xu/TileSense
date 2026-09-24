import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/round.dart';
import 'package:mahjong_core/tile.dart';
import 'package:tilesense/game/call_callout.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';

import 'helpers.dart';

/// The "Auto-win" toggle (on by default): a legal ron or tsumo is declared
/// for you instead of waiting on the button.
void main() {
  // `CallCallout` is a process-wide singleton and its `remaining` reads the
  // wall clock, which a widget test's fake clock never advances. The game loop
  // adds that remainder to its step timer, so a bubble left over from the
  // previous test in this file would silently delay this one's.
  setUp(CallCallout.i.clear);

  GameController awaitingRon({required bool autoWin}) {
    final game = GameController(seed: 4)..setAutoWin(autoWin);
    final round = game.round;
    final fed = Tile(900, TileType.pin5);
    round.seats[kHumanSeat]
      ..hand = parseTiles('46p 123m 456m 789m 99s')
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

  GameController awaitingTsumo({required bool autoWin}) {
    final game = GameController(seed: 4)..setAutoWin(autoWin);
    final round = game.round;
    final drawn = Tile(901, TileType.pin5);
    round.seats[kHumanSeat]
      ..hand = [...parseTiles('46p 123m 456m 789m 99s'), drawn]
      ..drawn = drawn
      ..riichi = true // menzen tsumo + riichi: a yaku either way
      ..melds = [];
    round.turn = kHumanSeat;
    round.phase = RoundPhase.discarding;
    return game;
  }

  testWidgets('is on by default', (tester) async {
    final game = GameController(seed: 4);
    expect(game.autoWin, isTrue);
    expect(game.autoDiscardInRiichi, isTrue);
    game.dispose();
  });

  testWidgets('declares a legal ron on its own', (tester) async {
    Sfx.i.enabled = false;
    final game = awaitingRon(autoWin: true);
    try {
      await pumpUntil(tester, () => game.round.finished);
      expect(game.round.finished, isTrue);
      expect(game.round.result!.kind, RoundEndKind.ron);
      expect(game.round.result!.winners, contains(kHumanSeat));
    } finally {
      game.dispose();
      Sfx.i.enabled = true;
    }
  });

  testWidgets('declares a legal tsumo on its own', (tester) async {
    Sfx.i.enabled = false;
    final game = awaitingTsumo(autoWin: true);
    try {
      await pumpUntil(tester, () => game.round.finished);
      expect(game.round.finished, isTrue);
      expect(game.round.result!.kind, RoundEndKind.tsumo);
    } finally {
      game.dispose();
      Sfx.i.enabled = true;
    }
  });

  testWidgets('off, the ron waits for the button', (tester) async {
    Sfx.i.enabled = false;
    final game = awaitingRon(autoWin: false);
    try {
      await pumpUntil(tester, () => game.awaitingHumanCall);
      expect(game.round.finished, isFalse);
      expect(game.awaitingHumanCall, isTrue);
    } finally {
      game.dispose();
      Sfx.i.enabled = true;
    }
  });

  testWidgets('off, the tsumo waits for the button (and is never cut)',
      (tester) async {
    Sfx.i.enabled = false;
    final game = awaitingTsumo(autoWin: false);
    try {
      // Slices, not one long pump: a single pump only walks one link of the
      // turn's timer chain, so it would pass even if the tsumo *were* cut.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(game.round.finished, isFalse);
      expect(game.round.seats[kHumanSeat].pond, isEmpty);
    } finally {
      game.dispose();
      Sfx.i.enabled = true;
    }
  });
}
