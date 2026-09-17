import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:mahjong_core/round.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/tile.dart';

import '../helpers.dart';

/// Hong Kong plays the same ron/tsumo voice line riichi does — see
/// `GameController._playRoundEndSfx` — even though its own vocabulary for
/// the two calls them Win / Self-pick (`Ruleset.ronLabel`/`tsumoLabel`).
/// `win_voice_test.dart` covers the riichi case and the mangan+ voice chain;
/// this only needs to confirm Hong Kong reaches the same two lines instead
/// of the old generic "win" line.
void main() {
  testWidgets('a Hong Kong win by discard voices ron, not the generic win line',
      (tester) async {
    Sfx.i.enabled = false; // no plugin under a test binding
    final log = <(Character, VoiceKind)>[];
    Sfx.debugVoiceLog = log;

    final game = GameController(seed: 4, ruleset: Ruleset.hongKong);
    final round = game.round;
    // 0-faan minimum: any complete hand wins, no yaku needed.
    round.seats[kHumanSeat]
      ..hand = parseTiles('123m 456m 789m 111s 22p')
      ..drawn = null
      ..melds = [];
    final fed = round.seats[kHumanSeat].hand.removeLast(); // the 2p pair tile
    round.seats[3]
      ..hand = [...parseTiles('123m 456m 789m 111p 2s'), fed]
      ..drawn = fed;
    round.turn = 3;
    round.phase = RoundPhase.discarding;
    round.discard(3, fed);
    try {
      await tester.pump(const Duration(seconds: 2));
      expect(game.awaitingHumanCall, isTrue);
      expect(game.humanCallOption!.types, contains(CallType.ron));

      game.answerCall(CallType.ron);
      await tester.pump(const Duration(seconds: 2));

      expect(game.round.finished, isTrue);
      expect(log, contains((Character.orderic, VoiceKind.ron)));
      expect(log, isNot(contains((Character.orderic, VoiceKind.win))));
    } finally {
      Sfx.debugVoiceLog = null;
      game.dispose();
      Sfx.i.enabled = true;
    }
  });

  testWidgets(
      'a Hong Kong self-draw win voices tsumo, not the generic win line',
      (tester) async {
    Sfx.i.enabled = false;
    final log = <(Character, VoiceKind)>[];
    Sfx.debugVoiceLog = log;

    final game = GameController(seed: 4, ruleset: Ruleset.hongKong);
    final round = game.round;
    final drawn = Tile(902, TileType.pin2);
    round.seats[kHumanSeat]
      ..hand = [...parseTiles('123m 456m 789m 111s 2p'), drawn]
      ..drawn = drawn
      ..melds = [];
    round.turn = kHumanSeat;
    try {
      expect(round.canTsumo(kHumanSeat), isTrue,
          reason: 'fixture is not a complete hand — fix the tiles');

      game.humanTsumo();

      expect(game.round.finished, isTrue);
      expect(log, contains((Character.orderic, VoiceKind.tsumo)));
      expect(log, isNot(contains((Character.orderic, VoiceKind.win))));
    } finally {
      Sfx.debugVoiceLog = null;
      game.dispose();
      Sfx.i.enabled = true;
    }
  });
}
