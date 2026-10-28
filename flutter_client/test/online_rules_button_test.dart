import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:tilesense/game/online_game_controller.dart';
import 'package:tilesense/main.dart' show kDesignSize;
import 'package:tilesense/ui/online_game_page.dart';
import 'package:tilesense/ui/online_lobby_page.dart';
import 'package:tilesense/ui/rules_reader.dart';

import 'loading_helpers.dart';
import 'lobby_helpers.dart';

/// The rulebook is reachable from the online screens too: the lobby, beside
/// the ruleset it describes, and the table, in the bar or (on a phone) the
/// Menu. It is a dialog, so opening and closing it leaves the game alone.
void main() {
  preloadDeferredPages();

  Ruleset readerRuleset(WidgetTester tester) =>
      tester.widget<RulesReader>(find.byType(RulesReader)).ruleset;

  Future<void> closeReader(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('rulesReaderClose')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(RulesReader), findsNothing);
  }

  Future<void> pumpTable(WidgetTester tester, OnlineGameController game,
      {required bool phone}) async {
    await tester.binding.setSurfaceSize(kDesignSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(phone ? 1.35 : 1)),
        child: child!,
      ),
      home: OnlineGamePage(controller: game, onExit: () {}),
    ));
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('online table', () {
    testWidgets('the bar has a Rules button that opens the room\'s ruleset',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final game = OnlineGameController()..ruleset = Ruleset.mcr;
      addTearDown(game.dispose);
      await pumpTable(tester, game, phone: false);

      expect(find.byType(RulesReader), findsNothing);
      await tester.tap(find.byKey(const Key('rulesRead')));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(RulesReader), findsOneWidget);
      expect(readerRuleset(tester), Ruleset.mcr);
      expect(tester.takeException(), isNull);

      await closeReader(tester);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('a phone has it in the Menu, not the bar', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final game = OnlineGameController()..ruleset = Ruleset.sichuan;
      addTearDown(game.dispose);
      await pumpTable(tester, game, phone: true);

      expect(find.byKey(const Key('rulesRead')), findsNothing);
      await tester.tap(find.byKey(const Key('phoneMenu')));
      // Two pumps: the first starts the sheet's slide-up, the second ends it.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const Key('onlineMenuRules')));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(RulesReader), findsOneWidget);
      expect(readerRuleset(tester), Ruleset.sichuan);
      expect(tester.takeException(), isNull);

      await closeReader(tester);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('the Menu on a mouse-driven small window has it too',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final game = OnlineGameController();
      addTearDown(game.dispose);
      await pumpTable(tester, game, phone: true);

      await tester.tap(find.byKey(const Key('phoneMenu')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('onlineMenuRules')), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('online lobby', () {
    Future<void> pumpLobby(
        WidgetTester tester, OnlineGameController game) async {
      await tester.binding.setSurfaceSize(kDesignSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: kDesignSize.width,
            height: kDesignSize.height,
            child: AnimatedBuilder(
              animation: game,
              builder: (_, __) => OnlineLobbyPage(
                controller: game,
                initialRuleset: Ruleset.riichi,
                onExit: () {},
              ),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('the Rules button follows the ruleset picked in the dropdown',
        (tester) async {
      final game = OnlineGameController();
      addTearDown(game.dispose);
      await pumpLobby(tester, game);

      await tester.tap(find.byKey(const Key('onlineRulesRead')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(readerRuleset(tester), Ruleset.riichi);
      await closeReader(tester);

      await pickOnlineRuleset(tester, Ruleset.taiwanese);
      await tester.tap(find.byKey(const Key('onlineRulesRead')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(readerRuleset(tester), Ruleset.taiwanese);
      expect(tester.takeException(), isNull);
      await closeReader(tester);

      // Reading the rules picks nothing.
      expect(onlineRulesetShown(tester), Ruleset.taiwanese);
    });
  });
}
