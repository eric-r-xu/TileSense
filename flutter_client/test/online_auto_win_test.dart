import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/game_timing.dart';
import 'package:mahjong_core/mahjong_core.dart';
import 'package:tilesense/game/game_controller.dart' show kAutoWinDelay;
import 'package:tilesense/game/online_game_controller.dart';
import 'package:tilesense/game/sfx.dart';

import 'helpers.dart';

/// Online Auto-win (on by default, like solo): a legal ron or tsumo is sent
/// for you, but only after [kAutoWinDelay], so the table doesn't jump straight
/// to the score screen.
void main() {
  setUp(() => Sfx.i.enabled = false);
  tearDown(() => Sfx.i.enabled = true);

  Map<String, dynamic> state(Round round, int serial, [int? lastSeat]) => {
        'type': 'state',
        'yourSeat': 0,
        'gamePhase': 'playing',
        'handInWind': 1,
        'tablePoints': List.filled(4, 25000),
        'discardSerial': serial,
        'lastDiscardSeat': lastSeat,
        'lastDiscardTsumogiri': false,
        'turnDeadlineMs': null,
        'round': roundSnapshotToJson(round, reveal: (s) => s == 0),
      };

  Round table() => Round(
        seed: 7,
        dealer: 0,
        roundWind: Wind.east,
        startingPoints: List.filled(4, 25000),
      );

  /// Your turn, with a riichi tsumo in hand.
  Map<String, dynamic> tsumoOnOffer() {
    final round = table();
    final drawn = Tile(901, TileType.pin5);
    round.seats[0]
      ..hand = [...parseTiles('46p 123m 456m 789m 99s'), drawn]
      ..drawn = drawn
      ..riichi = true
      ..melds = [];
    round.turn = 0;
    round.phase = RoundPhase.discarding;
    return state(round, 0);
  }

  /// The left seat's discard, which you can ron (a pure straight).
  Map<String, dynamic> ronOnOffer() {
    final round = table();
    final fed = Tile(900, TileType.pin5);
    round.seats[0]
      ..hand = parseTiles('46p 123m 456m 789m 99s')
      ..drawn = null
      ..melds = [];
    round.seats[3]
      ..hand = [...parseTiles('123m 456m 789m 111s 2p'), fed]
      ..drawn = fed;
    round.turn = 3;
    round.phase = RoundPhase.discarding;
    round.discard(3, fed);
    return state(round, 1, 3);
  }

  bool isWin(Map<String, dynamic> m) =>
      m['kind'] == 'tsumo' || (m['kind'] == 'call' && m['callType'] == 'ron');

  for (final (name, offer) in [
    ('tsumo', tsumoOnOffer),
    ('ron', ronOnOffer),
  ]) {
    testWidgets('a $name is sent after the pause, once', (tester) async {
      final game = OnlineGameController();
      final sent = <Map<String, dynamic>>[];
      game.debugOnSend = sent.add;
      try {
        expect(game.autoWin, isTrue, reason: 'on by default');
        final msg = offer();
        game.debugReceive(msg);
        await tester.pump(kAutoWinDelay - const Duration(milliseconds: 100));
        expect(sent.where(isWin), isEmpty, reason: 'still pausing');
        // A repeat of the same state (e.g. a reconnect) doesn't restart it.
        game.debugReceive(msg);
        await tester.pump(const Duration(milliseconds: 200));
        expect(sent.where(isWin), hasLength(1));
        await tester.pump(kAutoWinDelay * 2);
        expect(sent.where(isWin), hasLength(1), reason: 'sent only once');
      } finally {
        game.dispose();
        await tester.pump(kReplayGap);
      }
    });
  }

  testWidgets('switching Auto-win off during the pause sends nothing',
      (tester) async {
    final game = OnlineGameController();
    final sent = <Map<String, dynamic>>[];
    game.debugOnSend = sent.add;
    try {
      game.debugReceive(tsumoOnOffer());
      await tester.pump(const Duration(milliseconds: 500));
      game.setAutoWin(false);
      await tester.pump(kAutoWinDelay * 2);
      expect(sent.where(isWin), isEmpty);
    } finally {
      game.dispose();
      await tester.pump(kReplayGap);
    }
  });

  testWidgets(
      'next up while others weigh a call: your turn is on the clock, '
      'waiting on its draw', (tester) async {
    final game = OnlineGameController();
    final sent = <Map<String, dynamic>>[];
    game.debugOnSend = sent.add;
    try {
      // What the server shows the next player during a call window it has
      // no part in (see TableLoop._maskCallWindow): their turn, no draw yet.
      final round = table();
      round.turn = 0;
      round.phase = RoundPhase.drawing;
      final deadline = DateTime.now()
          .add(const Duration(seconds: 40))
          .millisecondsSinceEpoch;
      game.debugReceive(
          {...state(round, 1, 3), 'turnDeadlineMs': deadline});
      expect(game.round.turn, 0);
      expect(game.turnDeadlineMs, deadline);
      expect(game.isHumanTurn, isFalse, reason: 'nothing to discard yet');
      expect(game.awaitingHumanCall, isFalse);
      await tester.pump(kAutoWinDelay * 2);
      expect(sent.where((m) => m['type'] == 'action'), isEmpty);
    } finally {
      game.dispose();
      await tester.pump(kReplayGap);
    }
  });
}
