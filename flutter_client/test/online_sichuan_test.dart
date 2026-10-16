// ignore_for_file: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/game_timing.dart';
import 'package:mahjong_core/mahjong_core.dart';
import 'package:tilesense/game/call_callout.dart';
import 'package:tilesense/game/online_game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/ui/hand_view.dart';
import 'package:tilesense/ui/online_lobby_page.dart';
import 'package:tilesense/ui/table_view.dart';

import 'helpers.dart';
import 'l10n_helpers.dart';

/// A Sichuan table over the wire: the void-suit step, what is hidden from
/// whom, the Hu announced as it happens, and the lobby that offers it.
void main() {
  setUp(() {
    Sfx.i.enabled = false;
    CallCallout.i.clear();
  });
  tearDown(() => Sfx.i.enabled = true);

  Round newRound({SichuanWall? wall}) => Round(
        seed: 11,
        dealer: 0,
        roundWind: Wind.east,
        startingPoints: List.filled(4, 0),
        ruleset: Ruleset.sichuan,
        wall: wall,
      );

  /// The `state` the server would send seat 0 for [round].
  Map<String, dynamic> state(Round round, {int serial = 0}) => {
        'type': 'state',
        'yourSeat': 0,
        'gamePhase': 'playing',
        'handInWind': 1,
        'tablePoints': [for (final s in round.seats) s.points],
        'discardSerial': serial,
        'lastDiscardSeat': null,
        'lastDiscardTsumogiri': false,
        'turnDeadlineMs': null,
        'round': roundSnapshotToJson(round, reveal: (s) => s == 0),
      };

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

  testWidgets('the table asks for your suit, and sends it once', (tester) {
    return withGame(tester, (game) async {
      final sent = <Map<String, dynamic>>[];
      game.debugOnSend = sent.add;
      final round = newRound();
      game.debugReceive(state(round));

      expect(game.round.awaitingVoidSuit, isTrue);
      expect(game.awaitingHumanVoidSuit, isTrue);

      // Not a suit: nothing goes out.
      game.humanDeclareVoidSuit(3);
      game.humanDeclareVoidSuit(-1);
      expect(sent, isEmpty);

      game.humanDeclareVoidSuit(1);
      expect(sent, [
        {'type': 'action', 'kind': 'void_suit', 'suit': 1}
      ]);

      // The server's answer: you have chosen, the others have not.
      round.declareVoidSuit(0, 1);
      game.debugReceive(state(round));
      expect(game.awaitingHumanVoidSuit, isFalse);
      expect(game.round.awaitingVoidSuit, isTrue);
      expect(game.round.seats[0].voidSuit, 1);
      expect(game.round.hasDeclaredVoidSuit(1), isFalse);
      game.humanDeclareVoidSuit(2);
      expect(sent, hasLength(1), reason: 'you cannot choose twice');
    });
  });

  testWidgets('the prompt carries the server\'s clock; after you choose the '
      'table says it is waiting on the others', (tester) {
    return withGame(tester, (game) async {
      final round = newRound();
      final deadline =
          DateTime.now().add(const Duration(seconds: 40)).millisecondsSinceEpoch;
      game.debugReceive({...state(round), 'turnDeadlineMs': deadline});
      // The page rebuilds on the controller, as OnlineGamePage does.
      await pumpLocalized(
          tester,
          Scaffold(
              body: ListenableBuilder(
                  listenable: game,
                  builder: (_, __) => Column(children: [
                        Expanded(child: TableView(game: game)),
                        HandView(game: game),
                      ]))));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('voidSuitTitle')), findsOneWidget);
      expect(find.byType(CountdownBadge), findsOneWidget,
          reason: 'one clock, on the prompt, not on the dealer\'s seat');
      expect(find.byKey(const Key('voidSuitWaiting')), findsNothing);

      round.declareVoidSuit(0, 1);
      game.debugReceive({...state(round, serial: 1), 'turnDeadlineMs': deadline});
      expect(game.awaitingHumanVoidSuit, isFalse);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('voidSuitTitle')), findsNothing);
      expect(find.byKey(const Key('voidSuitWaiting')), findsOneWidget);
      expect(find.byType(CountdownBadge), findsNothing);
    });
  });

  testWidgets('other seats show a hidden suit until they discard',
      (tester) {
    return withGame(tester, (game) async {
      final round = newRound();
      for (var i = 0; i < 4; i++) {
        round.declareVoidSuit(i, round.suggestVoidSuit(i));
      }
      game.debugReceive(state(round));
      expect(game.round.awaitingVoidSuit, isFalse);
      expect(game.round.seats[0].voidSuit, round.seats[0].voidSuit);
      for (var local = 1; local < 4; local++) {
        expect(game.round.seats[local].voidSuit, isNull);
        expect(game.round.hasDeclaredVoidSuit(local), isTrue);
      }

      await pumpLocalized(tester, Scaffold(body: TableView(game: game)));
      expect(find.byKey(const Key('voidSuitBadge_0')), findsOneWidget);
      for (var local = 1; local < 4; local++) {
        expect(find.byKey(Key('voidSuitBadge_$local')), findsOneWidget);
      }
      expect(find.text('Void: ?'), findsNWidgets(3));
    });
  });

  testWidgets('with a void suit in hand, any other discard is not sent',
      (tester) {
    return withGame(tester, (game) async {
      final sent = <Map<String, dynamic>>[];
      game.debugOnSend = sent.add;
      final round = newRound();
      for (var i = 0; i < 4; i++) {
        round.declareVoidSuit(i, round.suggestVoidSuit(i));
      }
      // Seat 0 holds its void suit and another: only the void suit may go.
      final suit = round.seats[0].voidSuit!;
      final hand = round.seats[0].hand;
      final other = hand.firstWhere((t) => t.type.suit != suit);
      final void_ = hand.firstWhere((t) => t.type.suit == suit);
      game.debugReceive(state(round));
      expect(game.isHumanTurn, isTrue);

      game.humanDiscard(other);
      expect(sent, isEmpty, reason: 'void suit first');
      game.humanDiscard(void_);
      expect(sent.single['kind'], 'discard');
      expect(sent.single['tileId'], void_.id);
    });
  });

  testWidgets('a seat that goes out is announced once, not again on resend',
      (tester) {
    return withGame(tester, (game) async {
      final round = newRound(
          wall: SichuanWall.fromTiles(parseTiles('1111m 2222m 3333m 4444m '
              '5555m 6666m 7777m 8888m 9999m 1111p 2222p 3333p 4444p '
              '5p 6p 7p 8p')));
      for (var i = 0; i < 4; i++) {
        round.declareVoidSuit(i, 2);
      }
      game.debugReceive(state(round));
      expect(CallCallout.i.latest(0), isNull);

      // Seat 1 draws into a finished hand (all pungs and a pair, no sou).
      final s = round.seats[1];
      final win = Tile(9000, TileType.man5);
      s.hand = [
        ...parseTiles('111m 222m 333m 444m 5m').map((t) => Tile(8000 + t.id, t.type)),
        win,
      ];
      s.drawn = win;
      round.turn = 1;
      round.phase = RoundPhase.discarding;
      round.declareTsumo(1);
      expect(round.seats[1].out, isTrue);

      game.debugReceive(state(round, serial: 1));
      await tester.pump(kReplayGap);
      // Seat 1 is local seat 1 to seat 0.
      final first = CallCallout.i.latest(1);
      expect(first, isNotNull);
      expect(first!.text, 'TSUMO');
      expect(game.round.seats[1].out, isTrue);

      // The same Hu again (a resend, or the next state) says nothing new.
      game.debugReceive(state(round, serial: 1));
      await tester.pump(kReplayGap);
      expect(CallCallout.i.latest(1)!.id, first.id);
    });
  });

  testWidgets('joining a hand already in progress is silent about earlier Hu',
      (tester) {
    return withGame(tester, (game) async {
      final round = newRound(
          wall: SichuanWall.fromTiles(parseTiles('1111m 2222m 3333m 4444m '
              '5555m 6666m 7777m 8888m 9999m 1111p 2222p 3333p 4444p '
              '5p 6p 7p 8p')));
      for (var i = 0; i < 4; i++) {
        round.declareVoidSuit(i, 2);
      }
      final s = round.seats[1];
      final win = Tile(9000, TileType.man5);
      s.hand = [
        ...parseTiles('111m 222m 333m 444m 5m').map((t) => Tile(8000 + t.id, t.type)),
        win,
      ];
      s.drawn = win;
      round.turn = 1;
      round.phase = RoundPhase.discarding;
      round.declareTsumo(1);

      // The first thing this controller ever hears already has a Hu in it.
      game.debugReceive(state(round));
      await tester.pump(kReplayGap);
      expect(CallCallout.i.latest(1), isNull);
    });
  });

  group('the lobby', () {
    testWidgets('offers Sichuan, and opens on it when it was picked',
        (tester) async {
      final game = OnlineGameController();
      addTearDown(game.dispose);
      await pumpLocalized(
          tester,
          OnlineLobbyPage(
              controller: game,
              initialRuleset: Ruleset.sichuan,
              onExit: () {}));
      expect(tester.takeException(), isNull);

      final dropdown = tester.widget<DropdownButton<Ruleset>>(
          find.byType(DropdownButton<Ruleset>).first);
      expect(dropdown.value, Ruleset.sichuan);
      expect(dropdown.items!.map((i) => i.value),
          contains(Ruleset.sichuan));

      // Its game length reads as Sichuan's hands, not a hanchan.
      expect(find.textContaining('8 hands'), findsOneWidget);
    });

    testWidgets('creating a Sichuan room names it to the server',
        (tester) async {
      final game = OnlineGameController();
      addTearDown(game.dispose);
      final sent = <Map<String, dynamic>>[];
      game.debugOnSend = sent.add;
      game.createRoom(ruleset: Ruleset.sichuan, hanchan: false);
      expect(sent.single['type'], 'create_room');
      expect(sent.single['ruleset'], 'sichuan');
      expect(sent.single['hanchan'], false);
    });
  });
}
