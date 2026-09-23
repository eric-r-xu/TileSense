import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:mahjong_core/round.dart';
import 'package:mahjong_core/tile.dart';

import 'helpers.dart';

/// A mangan-or-higher ron chains three voice lines — the winner's "ron", the
/// winner's celebratory "yeah", then the discarder's resigned
/// "acquiescement" — right after each other. A cheaper win only speaks the
/// plain win line, and a mangan+ tsumo has no discarder to acquiesce.
void main() {
  /// Seat 3 discards [fed] into seat 0's hand, offering seat 0 a ron.
  GameController controllerAwaitingRon(
    Tile fed, {
    required String seat0Hand,
  }) {
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

  testWidgets(
      'a mangan-or-higher ron chains win, yeah, then the discarder\'s '
      'acquiescement', (tester) async {
    Sfx.i.enabled = false; // no plugin under a test binding
    final log = <(Character, VoiceKind)>[];
    Sfx.debugVoiceLog = log;

    // Kokushi musou (thirteen orphans) — always yakuman, so this is a
    // mangan-or-higher win regardless of dora/fu, with no need to hand-count
    // han. Hand holds every terminal/honor but chun, paired on 1m; ron on
    // chun completes it.
    final fed = Tile(900, TileType.chun);
    final game = controllerAwaitingRon(fed, seat0Hand: '119m 19p 19s ESWN BG');
    try {
      await tester.pump(const Duration(seconds: 2));
      expect(game.awaitingHumanCall, isTrue);
      expect(game.humanCallOption!.types, contains(CallType.ron));

      game.answerCall(CallType.ron);
      await tester.pump(const Duration(seconds: 2));

      expect(game.round.finished, isTrue);
      expect(
        log,
        containsAllInOrder([
          (Character.orderic, VoiceKind.ron),
          (Character.orderic, VoiceKind.yeah),
          (Character.astaroth, VoiceKind.acquiescement),
        ]),
        reason: 'seat 0 is Orderic, seat 3 (the discarder) is Astaroth — see '
            'kSeatCharacters',
      );
    } finally {
      Sfx.debugVoiceLog = null;
      game.dispose();
      Sfx.i.enabled = true;
    }
  });

  testWidgets('a cheap ron speaks only the plain win line', (tester) async {
    Sfx.i.enabled = false;
    final log = <(Character, VoiceKind)>[];
    Sfx.debugVoiceLog = log;

    // Shanpon wait on 1s/chun: ron on chun gives yakuhai and nothing else —
    // one han, nowhere near mangan.
    final fed = Tile(901, TileType.chun);
    final game =
        controllerAwaitingRon(fed, seat0Hand: '234m 456p 789s 11s RR');
    try {
      await tester.pump(const Duration(seconds: 2));
      // Guard the fixture rather than assert a false positive if the shape
      // isn't tenpai the way this test expects.
      if (!game.awaitingHumanCall ||
          !(game.humanCallOption?.types.contains(CallType.ron) ?? false)) {
        fail('fixture is not offering a ron on chun — fix the hand shape');
      }

      game.answerCall(CallType.ron);
      await tester.pump(const Duration(seconds: 2));

      expect(game.round.finished, isTrue);
      expect(log, contains((Character.orderic, VoiceKind.ron)));
      expect(log, isNot(contains((Character.orderic, VoiceKind.yeah))));
      expect(
          log, isNot(contains((Character.astaroth, VoiceKind.acquiescement))));
    } finally {
      Sfx.debugVoiceLog = null;
      game.dispose();
      Sfx.i.enabled = true;
    }
  });

  test('every character has a recording for the win-chain lines', () {
    // A missing clip is skipped silently at play time, so the only way a gap
    // shows up is a step in the chain that never voices. Check the files
    // exist instead.
    for (final character in Character.values) {
      for (final kind in [
        VoiceKind.ron,
        VoiceKind.tsumo,
        VoiceKind.yeah,
        VoiceKind.acquiescement,
      ]) {
        expect(
          Sfx.debugAssetFor(character, kind),
          isNotNull,
          reason: '${character.name} has no ${kind.name} line',
        );
      }
    }
  });
}
