import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/round.dart';

import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/main.dart';
import 'package:tilesense/ui/hand_view.dart';
import 'package:tilesense/ui/table_view.dart';
import 'package:tilesense/ui/tile_face.dart';

import 'helpers.dart';
import 'loading_helpers.dart';

/// The table's controls sized and grouped for a thumb on a phone, where the
/// whole 1600×820 canvas is drawn at about half size.
void main() {
  preloadDeferredPages();

  Future<void> startGame(WidgetTester tester, {Size size = kDesignSize}) async {
    Sfx.i.enabled = false;
    addTearDown(() => Sfx.i.enabled = true);
    await tester.binding.setSurfaceSize(size);
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

  testWidgets('Sort, Discard, Auto-win and Auto-pass are thumb-sized and apart',
      (tester) async {
    await startGame(tester);
    final sort = tester.getRect(find.byKey(const Key('sortHand')));
    final autoWin = tester.getRect(find.byKey(const Key('autoWin')));
    final autoPass = tester.getRect(find.byKey(const Key('autoPass')));
    final discard = tester.getRect(find.byKey(const Key('discardMode')));
    for (final r in [sort, discard, autoWin, autoPass]) {
      expect(r.width, greaterThanOrEqualTo(96));
      expect(r.height, greaterThanOrEqualTo(46));
    }
    // Sort over Discard, then the two call toggles stacked beside them.
    expect(discard.top - sort.bottom, greaterThanOrEqualTo(10),
        reason: 'far enough apart to hit the one you meant');
    expect(discard.left, sort.left);
    expect(autoWin.left - sort.right, greaterThanOrEqualTo(10),
        reason: 'far enough apart to hit the one you meant');
    expect(autoPass.top - autoWin.bottom, greaterThanOrEqualTo(10),
        reason: 'far enough apart to hit the one you meant');
    expect(autoPass.left, autoWin.left);
    expect(tester.takeException(), isNull);
    await tearDownApp(tester);
  });

  testWidgets('Auto-Play sits in its panel, lit while it plays',
      (tester) async {
    await startGame(tester);
    final group = find.byKey(const Key('autoplayGroup'));
    expect(
        find.descendant(of: group, matching: find.byKey(const Key('autoplay'))),
        findsOneWidget);
    // The dials it plays are not shown in the bar.
    expect(find.byKey(const Key('playingDials')), findsNothing);
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

  group('on a landscape iPhone', () {
    const iPhone = Size(852, 393);

    GameController gameOf(WidgetTester tester) =>
        tester.widget<TableView>(find.byType(TableView)).game as GameController;

    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('phoneMenu')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('the hand toggles shrink to icons, and all tiles still fit',
        (tester) async {
      await startGame(tester, size: iPhone);
      final toggles = [
        for (final key in ['sortHand', 'discardMode', 'autoWin', 'autoPass'])
          tester.getRect(find.byKey(Key(key)))
      ];
      // Square icons, all the same size (46 design units: the canvas is
      // drawn at about half scale here, so fewer on-screen pixels).
      for (final r in toggles) {
        expect(r.width, moreOrLessEquals(r.height));
        expect(r.width, moreOrLessEquals(toggles.first.width));
      }
      // Labels are gone; the tooltips name each toggle.
      expect(find.text('AUTO-PASS'), findsNothing);
      // Every tile of the resting hand is on screen without scrolling.
      final tiles = tester
          .widgetList<TileFace>(find.descendant(
              of: find.byType(HandView), matching: find.byType(TileFace)))
          .map((w) => tester.getRect(find.byWidget(w)))
          .toList()
        ..sort((a, b) => a.left.compareTo(b.left));
      expect(tiles[12].right, lessThanOrEqualTo(iPhone.width));
      expect(tester.takeException(), isNull);
      await tearDownApp(tester);
    });

    testWidgets('one Menu button under the right thumb replaces the bar tiles',
        (tester) async {
      await startGame(tester, size: iPhone);
      expect(find.byKey(const Key('phoneMenu')), findsOneWidget);
      for (final key in ['backToMenu', 'autoplay', 'newGame', 'soundToggle']) {
        expect(find.byKey(Key(key)), findsNothing, reason: key);
      }
      final menu = tester.getRect(find.byKey(const Key('phoneMenu')));
      expect(menu.width, greaterThanOrEqualTo(44));
      expect(menu.height, greaterThanOrEqualTo(44));
      expect(iPhone.width - menu.right, greaterThanOrEqualTo(16),
          reason: 'clear of the right edge, which a raised case covers');
      expect(menu.top, greaterThan(iPhone.height / 2),
          reason: 'low, where a thumb rests, not at the top edge');
      expect(menu.bottom, lessThan(iPhone.height));
      expect(tester.takeException(), isNull);
      await tearDownApp(tester);
    });

    testWidgets('the menu pauses, and the button says so', (tester) async {
      await startGame(tester, size: iPhone);
      final game = gameOf(tester);
      await openMenu(tester);
      final pause = tester.getRect(find.byKey(const Key('phoneMenuPause')));
      expect(pause.height, greaterThanOrEqualTo(44),
          reason: 'drawn at full size, not shrunk with the canvas');
      await tester.tap(find.byKey(const Key('phoneMenuPause')));
      await tester.pump();
      expect(game.paused, isTrue);
      await tester.tap(find.byKey(const Key('phoneMenuDone')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
          find.descendant(
              of: find.byKey(const Key('phoneMenu')),
              matching: find.text('PAUSED')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await tearDownApp(tester);
    });

    testWidgets('the menu shows the dials in play, with no goal to pick',
        (tester) async {
      await startGame(tester, size: iPhone);
      await openMenu(tester);
      expect(find.byKey(const Key('phoneMenuPlayingDials')), findsOneWidget);
      expect(find.byKey(const Key('phoneMenuGoal_points')), findsNothing);
      expect(tester.takeException(), isNull);
      await tearDownApp(tester);
    });

    testWidgets('New game still asks first, and Main menu leaves',
        (tester) async {
      await startGame(tester, size: iPhone);
      await openMenu(tester);
      await tester.tap(find.byKey(const Key('phoneMenuNewGame')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('newGameConfirm')), findsOneWidget);
      await tester.tap(find.byKey(const Key('newGameCancel')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await openMenu(tester);
      await tester.tap(find.byKey(const Key('phoneMenuMainMenu')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Single Player'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tearDownApp(tester);
    });
  });
}
