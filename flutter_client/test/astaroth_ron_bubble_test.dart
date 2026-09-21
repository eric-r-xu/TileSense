import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/round.dart';
import 'package:mahjong_core/tile.dart';
import 'package:tilesense/game/call_callout.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/ui/table_view.dart';

import 'helpers.dart';

/// When a bot wins by ron, the winner's seat flashes a RON bubble beside its
/// portrait — for every character, Astaroth (the default seat 3, drawn on the
/// left with the bubble to the right of his portrait) included. The existing
/// `call_bubble_test.dart` pokes `CallCallout.show` directly; this drives a
/// real ron through the controller and the table.
void main() {
  /// Seat 0 (the human) discards [fed]; seat 3 — Astaroth — holds [seat3Hand]
  /// waiting on it. Seats 1 and 2 hold nothing that could ron or call it.
  GameController controllerWithAstarothWaiting(
    Tile fed, {
    required String seat3Hand,
  }) {
    final game = GameController(seed: 4);
    final round = game.round;
    const junk = '1m 3m 5m 7m 9m 2p 4p 6p 8p 1s 3s 5s 7s';
    round.seats[1]
      ..hand = parseTiles(junk)
      ..drawn = null
      ..melds = [];
    round.seats[2]
      ..hand = parseTiles(junk)
      ..drawn = null
      ..melds = [];
    round.seats[3]
      ..hand = parseTiles(seat3Hand)
      ..drawn = null
      ..melds = [];
    round.seats[kHumanSeat]
      ..hand = [...parseTiles('123m 456m 789m 111s 2p'), fed]
      ..drawn = fed
      ..melds = [];
    round.turn = kHumanSeat;
    round.phase = RoundPhase.discarding;
    round.discard(kHumanSeat, fed);
    return game;
  }

  Future<void> expectRonBubble(
    WidgetTester tester, {
    required String seat3Hand,
    required TileType winningTile,
  }) async {
    Sfx.i.enabled = false; // no audio plugin under a test binding
    final fed = Tile(900, winningTile);
    final game = controllerWithAstarothWaiting(fed, seat3Hand: seat3Hand);
    try {
      expect(game.characterForSeat(3), Character.astaroth,
          reason: 'seat 3 is Astaroth by default — see kSeatCharacters');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body:
              SizedBox(width: 1600, height: 760, child: TableView(game: game)),
        ),
      ));
      expect(find.text('RON'), findsNothing);

      // Let the bots resolve the call offer; stop the moment the bubble is up.
      var shown = false;
      for (var i = 0; i < 60 && !shown; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        shown =
            find.byKey(const ValueKey('call-bubble-3')).evaluate().isNotEmpty;
      }

      expect(game.round.finished, isTrue, reason: 'Astaroth should have won');
      expect(game.round.result!.kind, RoundEndKind.ron);
      expect(game.round.result!.winners, [3]);
      expect(CallCallout.i.latest(3)?.text, 'RON');
      expect(shown, isTrue, reason: 'the RON bubble never appeared at seat 3');
      expect(find.text('RON'), findsOneWidget);
      // Only the winner speaks.
      for (final seat in [0, 1, 2]) {
        expect(find.byKey(ValueKey('call-bubble-$seat')), findsNothing);
      }

      // And it clears again after its flash.
      await tester.pump(CallCallout.flash + const Duration(milliseconds: 100));
      expect(find.text('RON'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      game.dispose();
      Sfx.i.enabled = true;
    }
  }

  testWidgets('Astaroth ron (cheap hand) flashes a RON bubble at his seat',
      (tester) async {
    // Shanpon wait on 1s / chun; ron on chun is yakuhai only — not a big hand.
    await expectRonBubble(tester,
        seat3Hand: '234m 456p 789s 11s RR', winningTile: TileType.chun);
  });

  testWidgets('Astaroth ron (yakuman) flashes a RON bubble at his seat',
      (tester) async {
    // Kokushi musou waiting on chun — the mangan+ path, which chains extra
    // voice lines after the bubble.
    await expectRonBubble(tester,
        seat3Hand: '119m 19p 19s ESWN BG', winningTile: TileType.chun);
  });
}
