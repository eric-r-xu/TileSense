import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/game/online_game_controller.dart';
import 'package:tilesense/l10n/app_language.dart';
import 'package:tilesense/l10n/l10n.dart';
import 'package:tilesense/main.dart' show TileSenseApp, kDesignSize;
import 'package:tilesense/ui/feature_loader.dart';
import 'package:tilesense/ui/online_game_page.dart';
import 'package:tilesense/ui/online_lobby_page.dart';
import 'package:mahjong_core/ruleset.dart';

import 'l10n_helpers.dart';
import 'loading_helpers.dart';

/// Every screen carries the language picker (`LanguageButton`), and picking a
/// language there switches that screen in place, with nothing overflowing.
/// A new screen added without the picker fails here.
void main() {
  preloadDeferredPages();
  // The app's own controller is process-wide: leave it on English for the
  // next test, whatever this one picked.
  tearDown(() => AppLanguageController.instance.select(AppLanguage.english));

  final ja = lookupAppLocalizations(AppLanguage.japanese.locale);

  /// Opens the picker on this screen, picks 日本語, and checks [japanese]
  /// (some text of this screen, in Japanese) is now showing.
  Future<void> switchToJapanese(WidgetTester tester, String japanese) async {
    final button = find.byKey(const Key('languageButton'));
    expect(button, findsWidgets, reason: 'this screen has no language picker');
    // The menu ignores taps until it has finished opening.
    // The topmost one: a sheet's or the rotate prompt's, over the screen's.
    await tester.tap(button.last);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.byKey(const Key('language_japanese')).last);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(AppLanguageController.instance.value, AppLanguage.japanese);
    expect(find.textContaining(japanese), findsWidgets);
    expect(tester.takeException(), isNull);
  }

  Future<void> boot(WidgetTester tester, {Size size = kDesignSize}) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('welcome screen', (tester) async {
    await boot(tester);
    await switchToJapanese(tester, ja.singlePlayer);
  });

  testWidgets('character select', (tester) async {
    await boot(tester);
    await tester.tap(find.text('Single Player'));
    await tester.pump();
    await switchToJapanese(tester, ja.chooseCharacters);
  });

  testWidgets('the single-player table (and the score screen under its bar)',
      (tester) async {
    await boot(tester);
    await tester.tap(find.text('Single Player'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('charactersContinue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await switchToJapanese(tester, ja.soundCaption);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('the single-player table on a phone: in the Menu sheet',
      (tester) async {
    await boot(tester, size: const Size(852, 393));
    await tester.tap(find.text('Single Player'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('charactersContinue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('phoneMenu')));
    // The sheet takes taps once it has finished sliding up.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await switchToJapanese(tester, ja.mainMenu);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('the Custom Hand builder', (tester) async {
    await boot(tester);
    await tester.tap(find.byKey(const Key('openBuilder')));
    await pumpLoadedPage(tester);
    // The builder's own text is Phase 2; its bar is already translated.
    await switchToJapanese(tester, ja.back);
  });

  testWidgets('a loading screen', (tester) async {
    await pumpLocalized(tester, StartupScreen(label: 'x', onBack: () {}));
    await switchToJapanese(tester, ja.back);
  });

  testWidgets('the online lobby, before a room exists', (tester) async {
    await boot(tester);
    await tester.tap(find.byKey(const Key('playOnline')));
    await pumpLoadedPage(tester);
    await switchToJapanese(tester, ja.createARoom);
  });

  testWidgets('the online lobby, in a room', (tester) async {
    final game = OnlineGameController();
    addTearDown(game.dispose);
    game.debugReceive({
      'type': 'room_state',
      'code': 'ABCD',
      'ruleset': 'hongKong',
      'hanchan': true,
      'phase': 'lobby',
      'yourSeat': 0,
      'seats': [
        for (var i = 0; i < 4; i++)
          {
            'seat': i,
            'name': i == 0 ? 'Me' : null,
            'character': null,
            'isBot': false,
            'isHost': i == 0,
            'connected': i == 0,
          }
      ],
    });
    await pumpLocalized(
        tester,
        OnlineLobbyPage(
            controller: game,
            initialRuleset: Ruleset.hongKong,
            onExit: () {}));
    await switchToJapanese(tester, ja.leaveRoomButton);
  });

  testWidgets('the online table (and its score screen under its bar)',
      (tester) async {
    final game = OnlineGameController();
    addTearDown(game.dispose);
    await pumpLocalized(
        tester, OnlineGamePage(controller: game, onExit: () {}));
    await switchToJapanese(tester, ja.leave);
  });

  testWidgets('the rotate-your-device prompt', (tester) async {
    // Portrait the way the prompt sees it: the view itself, not just the
    // test surface.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(kDesignSize.height, kDesignSize.width);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Rotate your device'), findsOneWidget);
    await switchToJapanese(tester, ja.rotatePrompt);
  });
}
