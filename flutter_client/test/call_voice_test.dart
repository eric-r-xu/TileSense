import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/logic/round.dart';
import 'package:tilesense/logic/tile.dart';

import 'helpers.dart';

/// Every call the game can make should voice its character's line. Chi is the
/// newest of them and the only one no opponent ever makes, so it is the one
/// most likely to be wired up but never actually heard.
void main() {
  /// Seat 3 cuts [fed]; seat 0 is its kamicha, so seat 0 is offered the call.
  GameController controllerAwaitingCallOn(
    Tile fed, {
    required String seat0Hand,
  }) {
    final game = GameController(seed: 4);
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

  testWidgets('taking a chi voices the chi line for your character',
      (tester) async {
    Sfx.i.enabled = false; // no plugin under a test binding
    final log = <(Character, VoiceKind)>[];
    Sfx.debugVoiceLog = log;

    final fed = Tile(900, TileType.pin5);
    final game = controllerAwaitingCallOn(fed,
        seat0Hand: '46p 123m 456m 789m 99s');
    try {
      await tester.pump(const Duration(seconds: 2));
      expect(game.awaitingHumanCall, isTrue);
      expect(game.humanCallOption!.types, contains(CallType.chi));

      game.answerCall(CallType.chi);

      expect(log, contains((Character.orderic, VoiceKind.chi)));
      // And the call really happened, so the line matches the table.
      expect(game.round.seats[kHumanSeat].melds.single.low, TileType.pin4);
    } finally {
      Sfx.debugVoiceLog = null;
      game.dispose();
      Sfx.i.enabled = true;
    }
  });

  testWidgets('passing on a chi voices nothing', (tester) async {
    Sfx.i.enabled = false;
    final log = <(Character, VoiceKind)>[];
    Sfx.debugVoiceLog = log;

    final fed = Tile(901, TileType.pin5);
    final game = controllerAwaitingCallOn(fed,
        seat0Hand: '46p 123m 456m 789m 99s');
    try {
      await tester.pump(const Duration(seconds: 2));
      game.answerCall(CallType.none);

      expect(log, isEmpty);
      expect(game.round.seats[kHumanSeat].melds, isEmpty);
    } finally {
      Sfx.debugVoiceLog = null;
      game.dispose();
      Sfx.i.enabled = true;
    }
  });

  test('every character has a recording for every call line', () {
    // A missing clip is skipped silently at play time, so the only way a gap
    // shows up is a call that never voices. Check the files exist instead.
    for (final character in Character.values) {
      for (final kind in [VoiceKind.chi, VoiceKind.pon, VoiceKind.kan]) {
        expect(
          Sfx.debugAssetFor(character, kind),
          isNotNull,
          reason: '${character.name} has no ${kind.name} line',
        );
      }
    }
  });
}
