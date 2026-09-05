import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/logic/bot.dart';
import 'package:tilesense/logic/round.dart';
import 'package:tilesense/logic/tile.dart';

import 'helpers.dart';

/// Autoplay plays your seat from the guide — the efficiency / expected-value /
/// safety analysis the panel shows — and not from [SimpleBot]. These tests are
/// built around cases where the two disagree, so they fail if the seat ever
/// falls back to the opponents' heuristic.
void main() {
  testWidgets('autoplay folds to the safe tile where the bot cuts by shape',
      (tester) async {
    Sfx.i.enabled = false;
    final game = GameController(seed: 5);
    final round = game.round;
    try {
      // Seat 1 has declared riichi, and has already cut 1m — so 1m is genbutsu.
      round.seats[1].riichi = true;
      round.seats[1].pond.add(Tile(800, TileType.man1));

      // Your hand is 2-shanten and holds both a worthless west wind (what a
      // shape-only heuristic reaches for) and that genbutsu 1m (what a
      // safety-aware guide cuts while behind a riichi).
      final drawn = Tile(801, TileType.sou5);
      round.seats[kHumanSeat]
        ..hand = [...parseTiles('1m 234m 567m 99s 78p 3p W'), drawn]
        ..drawn = drawn
        ..melds = [];
      round.turn = kHumanSeat;
      round.phase = RoundPhase.discarding;

      // The opponents' brain would throw the honour — it has no safety model.
      expect(
        SimpleBot(1).decideTurn(round, kHumanSeat).discard?.type,
        TileType.shaa,
      );

      game.setAutoplay(true);
      await tester.pump(const Duration(seconds: 2));

      expect(round.seats[kHumanSeat].pond, isNotEmpty);
      expect(
        round.seats[kHumanSeat].pond.first.type,
        TileType.man1,
        reason: 'autoplay should fold to the genbutsu, not cut by shape',
      );
    } finally {
      game.dispose();
      Sfx.i.enabled = true;
    }
  });

  testWidgets('the call prompt reflects the guide, not the bot',
      (tester) async {
    Sfx.i.enabled = false;
    final game = GameController(seed: 9);
    final round = game.round;
    try {
      // You are already tenpai on 3p. Ponning the dragons would swap that for a
      // worse tenpai and give up a concealed hand, so the guide passes.
      round.seats[kHumanSeat]
        ..hand = parseTiles('123m 456m 789m 12p RR')
        ..drawn = null
        ..melds = [];

      final fed = Tile(802, TileType.chun);
      round.seats[3]
        ..hand = [...parseTiles('123m 456m 789m 111s 2p'), fed]
        ..drawn = fed;
      round.turn = 3;
      round.phase = RoundPhase.discarding;
      round.discard(3, fed);
      expect(round.phase, RoundPhase.callOffer);

      // The opponents' brain pons any valuable pair on sight.
      expect(
        SimpleBot(1).decideCall(round, kHumanSeat, fed, const {CallType.pon}),
        CallType.pon,
      );

      await tester.pump(const Duration(seconds: 2));

      expect(game.awaitingHumanCall, isTrue);
      expect(game.recommendedCall, CallType.none);
      // And it explains itself in terms the bot has no concept of.
      expect(game.recommendedCallReason, contains('tenpai'));
    } finally {
      game.dispose();
      Sfx.i.enabled = true;
    }
  });

  testWidgets('a fully autoplayed round reaches an end state', (tester) async {
    Sfx.i.enabled = false;
    final game = GameController(seed: 11);
    try {
      game.setAutoplay(true);
      for (var i = 0; i < 500 && game.phase == GamePhase.playing; i++) {
        await tester.pump(const Duration(milliseconds: 960));
      }

      expect(game.phase, isNot(GamePhase.playing));
      expect(tester.takeException(), isNull);
    } finally {
      game.dispose();
      Sfx.i.enabled = true;
    }
  });
}
