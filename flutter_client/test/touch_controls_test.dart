import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/round.dart';

import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/main.dart';
import 'package:tilesense/ui/table_view.dart';

import 'helpers.dart';
import 'loading_helpers.dart';

/// The table's controls sized and grouped for a thumb on a phone, where the
/// whole 1600×820 canvas is drawn at about half size.
void main() {
  preloadDeferredPages();

  Future<void> startGame(WidgetTester tester) async {
    Sfx.i.enabled = false;
    addTearDown(() => Sfx.i.enabled = true);
    await tester.binding.setSurfaceSize(kDesignSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Single Player'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('charactersContinue')));
    await tester.pump(); // Render the startup/loading frame.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> tearDownApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  testWidgets('Sort and Auto-win are thumb-sized and clear of the tiles',
      (tester) async {
    await startGame(tester);
    final sort = tester.getRect(find.byKey(const Key('sortHand')));
    final autoWin = tester.getRect(find.byKey(const Key('autoWin')));
    for (final r in [sort, autoWin]) {
      expect(r.width, greaterThanOrEqualTo(96));
      expect(r.height, greaterThanOrEqualTo(46));
    }
    expect(autoWin.top - sort.bottom, greaterThanOrEqualTo(10),
        reason: 'far enough apart to hit the one you meant');
    expect(tester.takeException(), isNull);
    await tearDownApp(tester);
  });

  testWidgets('Auto-Play and its dials share one panel, lit while it plays',
      (tester) async {
    await startGame(tester);
    final group = find.byKey(const Key('autoplayGroup'));
    for (final key in ['autoplay', 'playStyle', 'handFocus', 'strategy']) {
      expect(find.descendant(of: group, matching: find.byKey(Key(key))),
          findsOneWidget,
          reason: '$key sits in the Auto-Play panel');
    }
    expect(find.byKey(const Key('autoplaySeatBadge')), findsNothing);

    await tester.tap(find.byKey(const Key('autoplay')));
    await tester.pump(const Duration(milliseconds: 300));
    final border =
        (tester.widget<AnimatedContainer>(group).decoration! as BoxDecoration)
            .border as Border;
    expect(border.top.color, const Color(0xffcaa24e));
    expect(find.byKey(const Key('autoplaySeatBadge')), findsOneWidget,
        reason: 'your seat shows TileSensor is playing it');

    await tester.tap(find.byKey(const Key('autoplay')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('autoplaySeatBadge')), findsNothing);
    await tearDownApp(tester);
  });

  testWidgets('sound, pause and new game sit together in the top bar',
      (tester) async {
    await startGame(tester);
    final bar = tester.getRect(find.byType(AppBar));
    final sound = tester.getRect(find.byKey(const Key('soundToggle')));
    final pause = tester.getRect(find.byTooltip('Pause'));
    final fresh = tester.getRect(find.byKey(const Key('newGame')));
    for (final r in [sound, pause, fresh]) {
      expect(bar.contains(r.center), isTrue);
    }
    expect(sound.right, lessThan(pause.left));
    expect(pause.right, lessThan(fresh.left));
    await tearDownApp(tester);
  });

  testWidgets('new game asks first while a game is being played',
      (tester) async {
    await startGame(tester);
    final game = tester.widget<TableView>(find.byType(TableView)).game;
    final firstRound = game.round;

    await tester.tap(find.byKey(const Key('newGame')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Start a new game?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('newGameCancel')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(identical(game.round, firstRound), isTrue,
        reason: 'keep playing leaves the game alone');

    await tester.tap(find.byKey(const Key('newGame')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('newGameConfirm')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(identical(game.round, firstRound), isFalse);
    await tearDownApp(tester);
  });

  testWidgets('take back shows once you have moved, and undoes the move',
      (tester) async {
    await startGame(tester);
    final game = tester.widget<TableView>(find.byType(TableView)).game;
    // Deal-time flowers or a first-turn call can delay your first move.
    await pumpUntil(tester,
        () => game.round.turn == 0 && game.round.phase == RoundPhase.discarding,
        tries: 300);
    expect(find.byKey(const Key('undo')), findsNothing);

    final seat = game.round.seats[0];
    final tile = game.round.legalDiscards(0).first;
    final hand = [for (final t in seat.hand) t.id];
    // Discard through the controller: which tile widget is which is
    // hand_order_test's business, not this one's.
    (game as GameController).humanDiscard(tile);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('undo')), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const Key('undo')),
            matching:
                find.textContaining(tile.type.displayName, findRichText: true)),
        findsOneWidget,
        reason: 'the button names what it takes back');

    await tester.tap(find.byKey(const Key('undo')));
    await tester.pump(const Duration(milliseconds: 100));
    expect([for (final t in game.round.seats[0].hand) t.id], hand);
    expect(find.byKey(const Key('undo')), findsNothing);
    await tearDownApp(tester);
  });
}
