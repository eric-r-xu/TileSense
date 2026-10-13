import 'loading_helpers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/game/online_game_controller.dart';
import 'package:tilesense/main.dart';
import 'package:tilesense/ui/online_game_page.dart';
import 'package:tilesense/ui/small_window_hint.dart';

/// Shrinking a desktop window below ~1040px (or to a short, wide one) flips
/// the table to the phone layout, where the toolbar lives in the Menu button
/// beside the hand. Nothing may be lost in that move, and a mouse user is
/// told where it went.
void main() {
  preloadDeferredPages();

  /// The desktop bar's controls and the Menu action that replaces each.
  const barToMenu = {
    'backToMenu': 'phoneMenuMainMenu',
    'soundToggle': 'phoneMenuSound',
    'newGame': 'phoneMenuNewGame',
    'fastMode': 'phoneMenuSpeed',
    'hanchan': 'phoneMenuLength',
    'rulesPdf': 'phoneMenuRules',
    'autoplay': 'phoneMenuAutoplay',
  };

  Future<void> startGame(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Single Player'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('charactersContinue')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> end(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;
    SmallWindowHint.dismissed = false;
  }

  bool has(String key) => find.byKey(Key(key)).evaluate().isNotEmpty;

  group('desktop window sizes', () {
    testWidgets('a full-size window keeps the whole bar and no hint',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      await startGame(tester, const Size(1280, 800));
      for (final key in barToMenu.keys) {
        expect(has(key), isTrue, reason: '$key missing from the bar');
      }
      expect(has('phoneMenu'), isFalse);
      expect(has('smallWindowHint'), isFalse);
      await end(tester);
    });

    for (final size in const [
      Size(1030, 700),
      Size(800, 600),
      Size(1600, 500),
    ]) {
      testWidgets(
          'at ${size.width.toInt()}x${size.height.toInt()} every bar control '
          'is in the Menu, and the hint says so', (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        await startGame(tester, size);
        expect(has('phoneMenu'), isTrue);
        expect(has('smallWindowHint'), isTrue);

        await tester.tap(find.byKey(const Key('phoneMenu')));
        await tester.pump(const Duration(milliseconds: 500));
        expect(has('phoneMenuPause'), isTrue, reason: 'Pause left the Menu');
        for (final entry in barToMenu.entries) {
          expect(has(entry.value), isTrue,
              reason: '${entry.key} has no Menu action ${entry.value}');
        }
        expect(tester.takeException(), isNull);
        await end(tester);
      });
    }

    testWidgets('the hint can be closed and stays closed', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      await startGame(tester, const Size(800, 600));
      await tester.tap(find.byKey(const Key('smallWindowHintClose')));
      await tester.pump();
      expect(has('smallWindowHint'), isFalse);
      expect(SmallWindowHint.dismissed, isTrue);
      await end(tester);
    });

    testWidgets('a touch device gets the phone layout without the hint',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await startGame(tester, const Size(852, 393));
      expect(has('phoneMenu'), isTrue);
      expect(has('smallWindowHint'), isFalse);
      await end(tester);
    });
  });

  group('online table', () {
    Future<void> pumpOnline(WidgetTester tester, {required bool phone}) async {
      await tester.binding.setSurfaceSize(kDesignSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(phone ? 1.35 : 1)),
          child: child!,
        ),
        home: OnlineGamePage(controller: OnlineGameController(), onExit: () {}),
      ));
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('small: a mouse user keeps Leave in the bar, and in the Menu',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      await pumpOnline(tester, phone: true);
      expect(has('smallWindowHint'), isTrue);
      expect(has('onlineLeave'), isTrue);
      final leave = tester.getRect(find.byKey(const Key('onlineLeave')));
      expect(leave.height, lessThanOrEqualTo(50),
          reason: 'Leave is taller than the bar');

      await tester.tap(find.byKey(const Key('phoneMenu')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(has('onlineMenuLeave'), isTrue);
      expect(tester.takeException(), isNull);
      await end(tester);
    });

    testWidgets('a phone keeps Leave in the Menu only', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await pumpOnline(tester, phone: true);
      expect(has('onlineLeave'), isFalse);
      await tester.tap(find.byKey(const Key('phoneMenu')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(has('onlineMenuLeave'), isTrue);
      await end(tester);
    });

    testWidgets('full size: Leave is in the bar and there is no hint',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      await pumpOnline(tester, phone: false);
      expect(has('onlineLeave'), isTrue);
      expect(has('smallWindowHint'), isFalse);
      await end(tester);
    });
  });
}
