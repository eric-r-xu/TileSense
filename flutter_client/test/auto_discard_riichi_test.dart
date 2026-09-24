import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/round.dart';
import 'package:mahjong_core/tile.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';

import 'helpers.dart';

/// Riichi auto-discard (always on): once locked into riichi, every later
/// discard is already forced to be the drawn tile ([Round.discard]'s tsumogiri
/// lock), so it is cut on its own after a short 0.5–1.5 s pause. It must still
/// wait for a real decision — a self-kan on offer, or a win — rather than
/// throwing either away.
void main() {
  testWidgets('cuts the drawn tile on its own once locked into riichi',
      (tester) async {
    Sfx.i.enabled = false;
    final game = GameController(seed: 5);
    final round = game.round;
    try {
      final drawn = Tile(801, TileType.sou5);
      round.seats[kHumanSeat]
        ..hand = [...parseTiles('123m 456m 789m 111p 22p'), drawn]
        ..drawn = drawn
        ..riichi = true
        ..melds = [];
      round.turn = kHumanSeat;
      round.phase = RoundPhase.discarding;
      expect(round.seats[kHumanSeat].pond, isEmpty);

      await tester.pump(const Duration(seconds: 3));

      expect(round.seats[kHumanSeat].pond, isNotEmpty);
      expect(round.seats[kHumanSeat].pond.first.id, drawn.id,
          reason: 'the drawn tile should have been cut automatically');
    } finally {
      game.dispose();
      Sfx.i.enabled = true;
    }
  });

  testWidgets('waits at least half a second before cutting', (tester) async {
    Sfx.i.enabled = false;
    final game = GameController(seed: 5);
    final round = game.round;
    try {
      final drawn = Tile(801, TileType.sou5);
      round.seats[kHumanSeat]
        ..hand = [...parseTiles('123m 456m 789m 111p 22p'), drawn]
        ..drawn = drawn
        ..riichi = true
        ..melds = [];
      round.turn = kHumanSeat;
      round.phase = RoundPhase.discarding;

      // The first turn step lands after ~1.1 s; the discard then waits
      // another 0.5–1.5 s on top.
      await tester.pump(const Duration(milliseconds: 1500));
      expect(round.seats[kHumanSeat].pond, isEmpty,
          reason: 'the drawn tile must stay visible for the pause first');

      await tester.pump(const Duration(milliseconds: 1500));
      expect(round.seats[kHumanSeat].pond.single.id, drawn.id);
    } finally {
      game.dispose();
      Sfx.i.enabled = true;
    }
  });

  testWidgets('pauses for a self-kan instead of discarding it away',
      (tester) async {
    Sfx.i.enabled = false;
    final game = GameController(seed: 5);
    final round = game.round;
    try {
      // Waits on 7s alone; setting the fourth 5s aside as a kan leaves the
      // same wait — see riichi_kan_test.dart's identical scenario.
      final drawn = Tile(801, TileType.sou5);
      round.seats[kHumanSeat]
        ..hand = [...parseTiles('555s 68s 234m 567m 99p'), drawn]
        ..drawn = drawn
        ..riichi = true
        ..melds = [];
      round.turn = kHumanSeat;
      round.phase = RoundPhase.discarding;
      expect(round.closedKanTypes(kHumanSeat), [TileType.sou5],
          reason: 'sanity: the kan must actually be on offer for this test');

      await tester.pump(const Duration(seconds: 3));

      expect(round.seats[kHumanSeat].pond, isEmpty,
          reason: 'a self-kan decision must be left to the player, not '
              'discarded away automatically');
    } finally {
      game.dispose();
      Sfx.i.enabled = true;
    }
  });
}
