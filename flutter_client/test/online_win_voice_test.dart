import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/mahjong_core.dart';
import 'package:tilesense/game/online_game_controller.dart';
import 'package:tilesense/game/sfx.dart';

/// Regression test for online multiplayer round-ends playing only a plain
/// chime, with none of the character voice acting offline gets: a mangan+
/// ron should chain the winner's voice line, their "yeah", then the
/// discarder's resigned "acquiescement" — exactly like
/// `GameController._playRoundEndSfx`, just sourcing each seat's character
/// from the server's assignment (`characterForSeat`) instead of the fixed
/// `kSeatCharacters` mapping. `OnlineGameController` always opens a real
/// `MpClient` (a live connection) in its constructor, so it can't be
/// instantiated here — this exercises the static, pure function it calls
/// instead.
///
/// `Sfx.i.enabled` is set inside every `testWidgets` body, not a `setUp` —
/// the very first touch of the `Sfx.i` singleton initialises the audio
/// plugin, which needs `testWidgets`' own binding already active, and a
/// `setUp` hook runs before that binding is — see `win_voice_test.dart`.
void main() {
  HandScore score({String limitName = '', int han = 1}) => HandScore(
        yaku: const [],
        han: han,
        fu: 30,
        yakuman: 0,
        points: 1000,
        dealerPays: 0,
        nonDealerPays: 1000,
        limitName: limitName,
        valid: true,
      );

  Character characterForSeat(int seat) => const [
        Character.orderic,
        Character.grant,
        Character.hubert,
        Character.astaroth,
      ][seat];

  testWidgets('a mangan-or-higher ron chains win, yeah, then the acquiescement',
      (tester) async {
    Sfx.i.enabled = false; // no plugin under a test binding
    final log = <(Character, VoiceKind)>[];
    Sfx.debugVoiceLog = log;
    try {
      final res = RoundResult(
        kind: RoundEndKind.ron,
        winners: const [0],
        loser: 3,
        pointDeltas: const {},
        label: '',
        scores: [score(limitName: 'Mangan')],
      );

      OnlineGameController.playRoundEndVoice(
          res, Ruleset.riichi, characterForSeat);

      expect(
        log,
        containsAllInOrder([
          (Character.orderic, VoiceKind.ron),
          (Character.orderic, VoiceKind.yeah),
          (Character.astaroth, VoiceKind.acquiescement),
        ]),
      );
    } finally {
      Sfx.debugVoiceLog = null;
      Sfx.i.enabled = true;
    }
  });

  testWidgets('a cheap ron speaks only the plain win line', (tester) async {
    Sfx.i.enabled = false;
    final log = <(Character, VoiceKind)>[];
    Sfx.debugVoiceLog = log;
    try {
      final res = RoundResult(
        kind: RoundEndKind.ron,
        winners: const [0],
        loser: 3,
        pointDeltas: const {},
        label: '',
        scores: [score()], // limitName empty — not mangan+
      );

      OnlineGameController.playRoundEndVoice(
          res, Ruleset.riichi, characterForSeat);

      expect(log, [(Character.orderic, VoiceKind.ron)]);
    } finally {
      Sfx.debugVoiceLog = null;
      Sfx.i.enabled = true;
    }
  });

  testWidgets(
      'a mangan-or-higher tsumo chains win then yeah, with no '
      'acquiescement (no discarder)', (tester) async {
    Sfx.i.enabled = false;
    final log = <(Character, VoiceKind)>[];
    Sfx.debugVoiceLog = log;
    try {
      final res = RoundResult(
        kind: RoundEndKind.tsumo,
        winners: const [1],
        pointDeltas: const {},
        label: '',
        scores: [score(limitName: 'Haneman')],
      );

      OnlineGameController.playRoundEndVoice(
          res, Ruleset.riichi, characterForSeat);

      expect(log, [
        (Character.grant, VoiceKind.tsumo),
        (Character.grant, VoiceKind.yeah),
      ]);
    } finally {
      Sfx.debugVoiceLog = null;
      Sfx.i.enabled = true;
    }
  });

  testWidgets(
      'Hong Kong voices the generic win line, not the Japanese ron/tsumo '
      'clips', (tester) async {
    Sfx.i.enabled = false;
    final log = <(Character, VoiceKind)>[];
    Sfx.debugVoiceLog = log;
    try {
      final res = RoundResult(
        kind: RoundEndKind.ron,
        winners: const [2],
        loser: 0,
        pointDeltas: const {},
        label: '',
        scores: [score()],
      );

      OnlineGameController.playRoundEndVoice(
          res, Ruleset.hongKong, characterForSeat);

      expect(log, [(Character.hubert, VoiceKind.win)]);
    } finally {
      Sfx.debugVoiceLog = null;
      Sfx.i.enabled = true;
    }
  });

  testWidgets(
      'a 5+ faan Hong Kong ron also chains win, yeah, then the '
      'acquiescement — not just the 13-faan payment cap', (tester) async {
    Sfx.i.enabled = false;
    final log = <(Character, VoiceKind)>[];
    Sfx.debugVoiceLog = log;
    try {
      final res = RoundResult(
        kind: RoundEndKind.ron,
        winners: const [2],
        loser: 0,
        pointDeltas: const {},
        label: '',
        scores: [score(han: 5)], // limitName only ever set at the 13-faan cap
      );

      OnlineGameController.playRoundEndVoice(
          res, Ruleset.hongKong, characterForSeat);

      expect(log, [
        (Character.hubert, VoiceKind.win),
        (Character.hubert, VoiceKind.yeah),
        (Character.orderic, VoiceKind.acquiescement),
      ]);
    } finally {
      Sfx.debugVoiceLog = null;
      Sfx.i.enabled = true;
    }
  });

  testWidgets('an exhaustive draw voices nothing', (tester) async {
    Sfx.i.enabled = false;
    final log = <(Character, VoiceKind)>[];
    Sfx.debugVoiceLog = log;
    try {
      final res = RoundResult(
        kind: RoundEndKind.exhaustiveDraw,
        winners: const [],
        pointDeltas: const {},
        label: '',
      );

      OnlineGameController.playRoundEndVoice(
          res, Ruleset.riichi, characterForSeat);

      expect(log, isEmpty);
    } finally {
      Sfx.debugVoiceLog = null;
      Sfx.i.enabled = true;
    }
  });
}
