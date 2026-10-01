import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/game_timing.dart';
import 'package:mahjong_core/mahjong_core.dart';
import 'package:tilesense/game/online_game_controller.dart';
import 'package:tilesense/game/sfx.dart';

/// Online play under lag: your own discard shows the moment you make it, and
/// a burst of the server's updates replays one discard at a time instead of
/// jumping the table to the newest one.
void main() {
  setUp(() => Sfx.i.enabled = false);
  tearDown(() => Sfx.i.enabled = true);

  /// The server's own table, and the `state` messages it would send seat 0 —
  /// built with the same serializer the server uses.
  ({
    Round round,
    Map<String, dynamic> Function(int serial, [int? lastSeat]) state
  }) serverTable() {
    final round = Round(
      seed: 7,
      dealer: 0,
      roundWind: Wind.east,
      startingPoints: List.filled(4, 25000),
    );
    return (
      round: round,
      state: (serial, [lastSeat]) => {
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
          },
    );
  }

  /// Plays [count] discards on the server's table — whoever's turn it is,
  /// nobody calling — and returns the `state` sent after each.
  List<Map<String, dynamic>> playDiscards(
      ({Round round, Map<String, dynamic> Function(int, [int?]) state}) t,
      int from,
      int count) {
    final out = <Map<String, dynamic>>[];
    for (var k = 0; k < count; k++) {
      final r = t.round;
      final seat = r.turn;
      r.discard(seat, r.legalDiscards(seat).first);
      if (r.phase == RoundPhase.callOffer) r.resolveCalls({});
      out.add(t.state(from + k, seat));
    }
    return out;
  }

  /// Runs [body] against a fresh controller, then disposes it before the
  /// test ends so none of its timers outlive the test.
  Future<void> withGame(WidgetTester tester,
      Future<void> Function(OnlineGameController game) body) async {
    final game = OnlineGameController();
    try {
      await body(game);
    } finally {
      game.dispose();
      await tester.pump(kReplayGap);
    }
  }

  testWidgets(
      'your discard leaves your hand at once, and the echo is quiet',
      (tester) => withGame(tester, (game) async {
            final t = serverTable();
            game.debugReceive(t.state(0));
            expect(game.isHumanTurn, isTrue);
            final hand = game.round.seats[0].hand.length;
            final tile = game.round.seats[0].hand.first;

            game.humanDiscard(tile);
            expect(game.round.seats[0].hand.length, hand - 1);
            expect(game.round.seats[0].pond.map((x) => x.id), [tile.id]);
            expect(game.isHumanTurn, isFalse,
                reason: 'a second tap does nothing');
            expect(game.discardSerial, 1);
            game.humanDiscard(game.round.seats[0].hand.first);
            expect(game.round.seats[0].pond.length, 1);

            // The server agrees: same pond, same serial — nothing to animate again.
            t.round.discard(
                0, t.round.seats[0].hand.firstWhere((x) => x.id == tile.id));
            if (t.round.phase == RoundPhase.callOffer) t.round.resolveCalls({});
            game.debugReceive(t.state(1, 0));
            expect(game.round.seats[0].pond.map((x) => x.id), [tile.id]);
            expect(game.discardSerial, 1);
            expect(game.lastDiscardSeat, 0);
          }));

  testWidgets(
      'a discard the server turns down goes back in your hand',
      (tester) => withGame(tester, (game) async {
            final t = serverTable();
            game.debugReceive(t.state(0));
            final hand = [for (final x in game.round.seats[0].hand) x.id];

            game.humanDiscard(game.round.seats[0].hand.first);
            game.debugReceive({
              'type': 'error',
              'message': 'illegal action for the current turn'
            });
            expect([for (final x in game.round.seats[0].hand) x.id], hand);
            expect(game.round.seats[0].pond, isEmpty);
            expect(game.isHumanTurn, isTrue);
            expect(game.discardSerial, 0);
          }));

  testWidgets(
      'a burst of discards lands one at a time',
      (tester) => withGame(tester, (game) async {
            final t = serverTable();
            final burst = playDiscards(t, 1, 3);
            for (final m in burst) {
              game.debugReceive(m);
            }
            expect(game.discardSerial, 1,
                reason: 'only the first lands at once');
            await tester.pump(kReplayGap - const Duration(milliseconds: 10));
            expect(game.discardSerial, 1);
            await tester.pump(const Duration(milliseconds: 10));
            expect(game.discardSerial, 2);
            await tester.pump(kReplayGap);
            expect(game.discardSerial, 3);
          }));

  testWidgets(
      'a long backlog catches up faster',
      (tester) => withGame(tester, (game) async {
            final t = serverTable();
            for (final m in playDiscards(t, 1, 6)) {
              game.debugReceive(m);
            }
            expect(game.discardSerial, 1);
            await tester.pump(kReplayGap);
            expect(game.discardSerial, 2);
            // Four still waiting: the next gaps are the short ones.
            await tester.pump(kReplayCatchUpGap);
            expect(game.discardSerial, 3);
            await tester.pump(kReplayCatchUpGap);
            expect(game.discardSerial, 4);
            await tester.pump(kReplayGap);
            await tester.pump(kReplayGap);
            expect(game.discardSerial, 6);
          }));

  testWidgets(
      'an update with no new discard is not held back',
      (tester) => withGame(tester, (game) async {
            final t = serverTable();
            final first = playDiscards(t, 1, 1).single;
            game.debugReceive(first);
            // The same discard again (say, a call offer resolving): straight on.
            final turnBefore = game.round.turn;
            game.debugReceive(t.state(1));
            expect(game.discardSerial, 1);
            expect(game.round.turn, turnBefore);
            await tester.pump(kReplayGap);
          }));

  testWidgets(
      'on a healthy connection nothing waits',
      (tester) => withGame(tester, (game) async {
            final t = serverTable();
            final msgs = playDiscards(t, 1, 3);
            for (final m in msgs) {
              game.debugReceive(m);
              expect(game.discardSerial, m['discardSerial']);
              // The server spaces bots' turns 900 ms apart, wider than the gap.
              await tester.pump(const Duration(milliseconds: 900));
            }
          }));
}
