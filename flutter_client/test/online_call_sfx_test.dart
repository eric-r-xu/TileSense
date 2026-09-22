import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/mahjong_core.dart';
import 'package:tilesense/game/online_game_controller.dart';
import 'package:tilesense/game/sfx.dart';

/// Regression test for online multiplayer never sounding a chi/pon/kan: the
/// protocol has no "seat N just called" signal the way it has
/// `discardSerial`/`lastDiscardSeat` for a discard, so
/// `OnlineGameController.newMeldKind` has to infer it by comparing meld
/// counts between the last snapshot and this one. `OnlineGameController`
/// itself always opens a real `MpClient` (a live connection) in its
/// constructor, so it can't be instantiated here — this exercises the pure
/// detection function it calls instead.
void main() {
  Round roundWith(Map<int, List<Meld>> melds) {
    final round = Round.posed(
      dealer: 0,
      roundWind: Wind.east,
      wall: Wall.posed(remaining: 0, dora: const []),
      startingPoints: List.filled(4, 25000),
      ruleset: Ruleset.riichi,
    );
    melds.forEach((seat, m) => round.seats[seat].melds = m);
    return round;
  }

  Meld meld(MeldKind kind) =>
      Meld(kind: kind, low: TileType.man1, concealed: false);

  test('a new sequence meld sounds chi', () {
    final before = roundWith(const {});
    final after = roundWith({
      2: [meld(MeldKind.sequence)]
    });
    expect(OnlineGameController.newMeldKind(before, after, 2), SfxKind.chi);
  });

  test('a new triplet meld sounds pon', () {
    final before = roundWith(const {});
    final after = roundWith({
      1: [meld(MeldKind.triplet)]
    });
    expect(OnlineGameController.newMeldKind(before, after, 1), SfxKind.pon);
  });

  test('a new kan meld sounds kan, open or closed alike', () {
    final before = roundWith({
      3: [meld(MeldKind.triplet)]
    });
    final after = roundWith({
      3: [meld(MeldKind.triplet), meld(MeldKind.kan)]
    });
    expect(OnlineGameController.newMeldKind(before, after, 3), SfxKind.kan);
  });

  test('no new meld at that seat plays nothing', () {
    final steady = roundWith({
      0: [meld(MeldKind.triplet)]
    });
    expect(OnlineGameController.newMeldKind(steady, steady, 0), isNull);
  });

  test('the very first snapshot (no previous round) never misfires', () {
    // Every seat starts empty-handed before any call, so a null
    // `previousRound` — the very first snapshot the client ever sees — must
    // not read as "everyone just called".
    final first = roundWith({
      1: [meld(MeldKind.triplet)]
    });
    expect(OnlineGameController.newMeldKind(null, first, 1), SfxKind.pon);
    expect(OnlineGameController.newMeldKind(null, first, 0), isNull);
  });

  test('only the seat that actually gained a meld sounds anything', () {
    final before = roundWith({
      0: [meld(MeldKind.triplet)]
    });
    final after = roundWith({
      0: [meld(MeldKind.triplet)], // unchanged
      2: [meld(MeldKind.sequence)], // seat 2 just called
    });
    expect(OnlineGameController.newMeldKind(before, after, 0), isNull);
    expect(OnlineGameController.newMeldKind(before, after, 1), isNull);
    expect(OnlineGameController.newMeldKind(before, after, 2), SfxKind.chi);
    expect(OnlineGameController.newMeldKind(before, after, 3), isNull);
  });

  group('playCallVoice', () {
    // `playCallVoice` calls `Sfx.i.play`/`Sfx.i.voice`, and the very first
    // touch of the `Sfx.i` singleton in a test run initializes the audio
    // plugin — that needs `testWidgets`' own binding already active (a plain
    // `test()` throws `MissingPluginException`), same as
    // `online_win_voice_test.dart`.
    Character characterForSeat(int seat) => const [
          Character.orderic,
          Character.grant,
          Character.hubert,
          Character.astaroth,
        ][seat];

    testWidgets(
        'the caller gets their own spoken chi/pon/kan line, not just the '
        'blip', (tester) async {
      Sfx.i.enabled = false;
      final log = <(Character, VoiceKind)>[];
      Sfx.debugVoiceLog = log;
      try {
        final before = roundWith(const {});
        final after = roundWith({
          2: [meld(MeldKind.triplet)]
        });
        OnlineGameController.playCallVoice(before, after, characterForSeat);
        expect(log, [(Character.hubert, VoiceKind.pon)]);
      } finally {
        Sfx.debugVoiceLog = null;
        Sfx.i.enabled = true;
      }
    });

    testWidgets('no new meld means no voice line either', (tester) async {
      Sfx.i.enabled = false;
      final log = <(Character, VoiceKind)>[];
      Sfx.debugVoiceLog = log;
      try {
        final steady = roundWith({
          0: [meld(MeldKind.triplet)]
        });
        OnlineGameController.playCallVoice(steady, steady, characterForSeat);
        expect(log, isEmpty);
      } finally {
        Sfx.debugVoiceLog = null;
        Sfx.i.enabled = true;
      }
    });

    testWidgets(
        'a seat declaring riichi sounds its own spoken line, not just the '
        'silent RIICHI bubble', (tester) async {
      // Regression test: riichi has no meld, so it was the one call kind
      // `playCallVoice` detected (to flash the bubble) but never actually
      // sounded — every other call kind below it in the same loop already
      // played its blip and voice line.
      Sfx.i.enabled = false;
      final log = <(Character, VoiceKind)>[];
      Sfx.debugVoiceLog = log;
      try {
        final before = roundWith(const {});
        final after = roundWith(const {});
        after.seats[3].riichi = true;
        OnlineGameController.playCallVoice(before, after, characterForSeat);
        expect(log, [(Character.astaroth, VoiceKind.riichi)]);
      } finally {
        Sfx.debugVoiceLog = null;
        Sfx.i.enabled = true;
      }
    });

    testWidgets('already being in riichi does not re-sound it', (tester) async {
      Sfx.i.enabled = false;
      final log = <(Character, VoiceKind)>[];
      Sfx.debugVoiceLog = log;
      try {
        final steady = roundWith(const {});
        steady.seats[1].riichi = true;
        OnlineGameController.playCallVoice(steady, steady, characterForSeat);
        expect(log, isEmpty);
      } finally {
        Sfx.debugVoiceLog = null;
        Sfx.i.enabled = true;
      }
    });
  });
}
