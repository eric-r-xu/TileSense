import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/main.dart';
import 'package:tilesense/ui/efficiency_overlay.dart';
import 'package:tilesense/ui/table_view.dart';

import 'loading_helpers.dart';

/// The Riichi / Hong Kong / Taiwanese choice: it is made on the welcome screen,
/// carried into the character and online-lobby screens (still changeable
/// there), fixed once a game is under way, and the game it deals lays out as
/// cleanly as the one it left.
void main() {
  preloadDeferredPages();

  String labelOf(WidgetTester tester, Key key) => tester
      .widget<Text>(find
          .descendant(of: find.byKey(key), matching: find.byType(Text))
          .first)
      .data!;

  Future<void> boot(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(kDesignSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Who opens as dealer is rolled per game (see `GameController
  /// ._startGame`), not fixed to the human seat, so the bots ahead of them
  /// may win before the human's own first turn — possibly for a whole hand,
  /// or (on a dealer repeat) several. Drives the game forward until the
  /// human actually has something to act on: skips a round-end's auto-
  /// continue countdown instead of waiting it out, and rerolls a fresh game
  /// on the rare run where the whole game ends without that ever happening.
  Future<void> pumpUntilReported(WidgetTester tester) async {
    final game = (tester.widget(find.byType(TableView)) as TableView).game
        as GameController;
    for (var i = 0; i < 200; i++) {
      if (find.text('Away').evaluate().isNotEmpty) return;
      if (game.phase == GamePhase.roundEnd) {
        game.continueFromRoundEnd();
      } else if (game.phase == GamePhase.gameEnd) {
        game.newGame();
      }
      await tester.pump(const Duration(milliseconds: 1104));
    }
  }

  testWidgets('riichi stays the default from the welcome screen',
      (tester) async {
    await boot(tester);
    expect(find.textContaining('optimal Riichi Mahjong decisions'),
        findsOneWidget);
    await tester.tap(find.text('Single Player'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('charactersContinue')));
    await tester.pump(const Duration(milliseconds: 100));
    // The table is created after a loading frame.
    await tester.pump();

    expect(labelOf(tester, const Key('ruleset')), Ruleset.riichi.flagLabel);
    expect(labelOf(tester, const Key('hanchan')), 'Hanchan');
    expect(labelOf(tester, const Key('playStyle')), 'Aggressive');
    expect(labelOf(tester, const Key('handFocus')), 'Speed');
    expect(find.textContaining('Honba'), findsOneWidget);
    expect(find.text('DORA'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('choosing Hong Kong before Start deals a Hong Kong table',
      (tester) async {
    await boot(tester);
    await tester.tap(find.byKey(const Key('ruleset_hongKong')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('optimal Hong Kong Mahjong decisions'),
        findsOneWidget);
    expect(find.text('🇯🇵 Riichi'), findsOneWidget);
    expect(find.text('🇭🇰 Hong Kong'), findsOneWidget);
    expect(find.byKey(const Key('rulesPdf_riichi')), findsOneWidget);
    expect(find.byKey(const Key('rulesPdf_hongKong')), findsOneWidget);

    await tester.tap(find.text('Single Player'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('charactersContinue')));
    await tester.pump(const Duration(milliseconds: 100));
    // The table is created after a loading frame.
    await tester.pump();

    expect(labelOf(tester, const Key('ruleset')), Ruleset.hongKong.flagLabel);
    expect(labelOf(tester, const Key('hanchan')), 'Hanchan');
    // Style has nothing left to weigh under Hong Kong — no riichi, no
    // damaten, and no measured placement effect either — so the chip is
    // hidden rather than shown pinned on Balanced.
    expect(find.byKey(const Key('playStyle')), findsNothing);
    expect(labelOf(tester, const Key('handFocus')), 'Speed');
    // Hong Kong has no dora panel — flowers show beside each seat's own
    // placard instead, empty (and invisible) until one is actually drawn.
    expect(find.text('DORA'), findsNothing);
    expect(find.byKey(const Key('rulesPdf')), findsOneWidget);
    expect(find.textContaining('Honba'), findsNothing);
    expect(find.textContaining('1000'), findsWidgets,
        reason: 'every seat starts on 1000 chips');

    // The guide panel speaks Hong Kong too.
    await tester.tap(find.byKey(const Key('bottomGuideToggle')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(EfficiencyOverlay), findsOneWidget);
    await pumpUntilReported(tester);
    expect(find.text('Away'), findsOneWidget);
    expect(find.text('Shanten'), findsNothing);
    expect(find.byKey(const Key('guidePlayStyle_balanced')), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  test('each ruleset links its own rules PDF', () {
    expect(
        Ruleset.riichi.rulesUrl, 'https://app.ericrxu.com/static/Riichi.pdf');
    expect(Ruleset.hongKong.rulesUrl, 'https://app.ericrxu.com/static/HK.pdf');
    expect(Ruleset.taiwanese.rulesUrl,
        'https://app.ericrxu.com/static/Taiwanese.pdf');
  });

  /// Back arrow → welcome screen → [ruleset] → Single Player → Start: the
  /// only way to change the style once a game is under way.
  Future<void> switchViaMenu(WidgetTester tester, Ruleset ruleset) async {
    await tester.tap(find.byKey(const Key('backToMenu')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(Key('ruleset_${ruleset.name}')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Single Player'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('charactersContinue')));
    await tester.pump(const Duration(milliseconds: 100));
    // The table is created after a loading frame.
    await tester.pump();
  }

  testWidgets('the in-game style label cannot switch rules mid-game',
      (tester) async {
    await boot(tester);
    await tester.tap(find.text('Single Player'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('charactersContinue')));
    await tester.pump(const Duration(milliseconds: 100));
    // The table is created after a loading frame.
    await tester.pump();

    expect(labelOf(tester, const Key('ruleset')), Ruleset.riichi.flagLabel);
    expect(
        find.descendant(
            of: find.byKey(const Key('ruleset')),
            matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)),
        findsNothing,
        reason: 'the label is not a button');
    await tester.tap(find.byKey(const Key('ruleset')), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(labelOf(tester, const Key('ruleset')), Ruleset.riichi.flagLabel,
        reason: 'tapping it does nothing');
    expect(find.text('DORA'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('going back to the menu switches through all three and back',
      (tester) async {
    await boot(tester);
    await tester.tap(find.text('Single Player'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('charactersContinue')));
    await tester.pump(const Duration(milliseconds: 100));
    // The table is created after a loading frame.
    await tester.pump();

    // Style is a riichi-only dial; pick a non-default value so the
    // Chinese-style-and-back round trip below can prove it survives.
    await tester.tap(find.byKey(const Key('playStyle')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(labelOf(tester, const Key('playStyle')), 'Defensive');

    await switchViaMenu(tester, Ruleset.hongKong);
    expect(labelOf(tester, const Key('ruleset')), Ruleset.hongKong.flagLabel);
    expect(find.byType(TableView), findsOneWidget);
    expect(find.byKey(const Key('playStyle')), findsNothing,
        reason: 'Hong Kong pins style to Balanced and hides the dial');

    await switchViaMenu(tester, Ruleset.taiwanese);
    expect(labelOf(tester, const Key('ruleset')), Ruleset.taiwanese.flagLabel);
    expect(find.byType(TableView), findsOneWidget);
    expect(find.byKey(const Key('playStyle')), findsNothing,
        reason: 'Taiwanese pins style to Balanced and hides the dial too');

    await switchViaMenu(tester, Ruleset.riichi);
    expect(labelOf(tester, const Key('ruleset')), Ruleset.riichi.flagLabel);
    expect(find.text('DORA'), findsOneWidget);
    expect(labelOf(tester, const Key('playStyle')), 'Defensive',
        reason: 'the riichi style from before the trip comes back');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  /// Whether the character screen's (or lobby's) [key] button is drawn as
  /// the selected one — the gold 2px outline.
  bool picked(WidgetTester tester, Key key) {
    final b = tester.widget<OutlinedButton>(find.byKey(key));
    return b.style!.side!.resolve({})!.width == 2;
  }

  testWidgets(
      'the character screen starts on the home screen\'s style and can '
      'still change it', (tester) async {
    await boot(tester);
    await tester.tap(find.byKey(const Key('ruleset_hongKong')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Single Player'));
    await tester.pump();

    expect(picked(tester, const Key('startRuleset_hongKong')), isTrue);
    expect(picked(tester, const Key('startRuleset_riichi')), isFalse);
    expect(picked(tester, const Key('startRuleset_taiwanese')), isFalse);
    expect(tester.takeException(), isNull,
        reason: 'the style row fits the character screen');

    await tester.tap(find.byKey(const Key('startRuleset_taiwanese')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(picked(tester, const Key('startRuleset_taiwanese')), isTrue);
    expect(picked(tester, const Key('startRuleset_hongKong')), isFalse);

    await tester.tap(find.byKey(const Key('charactersContinue')));
    await tester.pump(const Duration(milliseconds: 100));
    // The table is created after a loading frame.
    await tester.pump();
    expect(labelOf(tester, const Key('ruleset')), Ruleset.taiwanese.flagLabel);

    // And the menu remembers it: back out and the home screen shows
    // Taiwanese as the current choice.
    await tester.tap(find.byKey(const Key('backToMenu')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('optimal Taiwanese Mahjong decisions'),
        findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('the online lobby starts on the home screen\'s style',
      (tester) async {
    await boot(tester);
    await tester.tap(find.byKey(const Key('ruleset_taiwanese')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('playOnline')));
    await pumpLoadedPage(tester);
    await tester.pump(const Duration(milliseconds: 100));

    expect(picked(tester, const Key('onlineRuleset_taiwanese')), isTrue);
    expect(picked(tester, const Key('onlineRuleset_riichi')), isFalse);

    // Still changeable there.
    await tester.tap(find.byKey(const Key('onlineRuleset_hongKong')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(picked(tester, const Key('onlineRuleset_hongKong')), isTrue);
    expect(picked(tester, const Key('onlineRuleset_taiwanese')), isFalse);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('the builder opens in the chosen rules and can switch',
      (tester) async {
    await boot(tester);
    await tester.tap(find.byKey(const Key('ruleset_hongKong')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('openBuilder')));
    await pumpUntilFound(tester, find.text('🇭🇰 HK'));

    expect(find.text('🇭🇰 HK'), findsOneWidget);
    expect(find.text('Honba '), findsNothing);
    expect(find.text('Your flowers (0)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('builderRuleset_taiwanese')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('🇹🇼 TW'), findsOneWidget);
    expect(find.text('Honba '), findsNothing);
    expect(find.text('Your flowers (0)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('builderRuleset_riichi')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Honba '), findsOneWidget);
    expect(find.text('Dora (1)'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('choosing Taiwanese before Start deals a Taiwanese table',
      (tester) async {
    await boot(tester);
    await tester.tap(find.byKey(const Key('ruleset_taiwanese')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('optimal Taiwanese Mahjong decisions'),
        findsOneWidget);
    expect(find.text('🇯🇵 Riichi'), findsOneWidget);
    expect(find.text('🇭🇰 Hong Kong'), findsOneWidget);
    expect(find.text('🇹🇼 Taiwanese'), findsOneWidget);
    expect(find.byKey(const Key('rulesPdf_taiwanese')), findsOneWidget);

    await tester.tap(find.text('Single Player'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('charactersContinue')));
    await tester.pump(const Duration(milliseconds: 100));
    // The table is created after a loading frame.
    await tester.pump();

    expect(labelOf(tester, const Key('ruleset')), Ruleset.taiwanese.flagLabel);
    expect(labelOf(tester, const Key('hanchan')), 'Hanchan');
    expect(find.byKey(const Key('playStyle')), findsNothing);
    expect(labelOf(tester, const Key('handFocus')), 'Speed');
    // Taiwanese has no dora panel either — flowers show beside each seat's
    // own placard instead, empty (and invisible) until one is drawn.
    expect(find.text('DORA'), findsNothing);
    expect(find.byKey(const Key('rulesPdf')), findsOneWidget);
    expect(find.textContaining('Honba'), findsNothing);
    expect(find.textContaining('1000'), findsWidgets,
        reason: 'every seat starts on 1000 points');

    // The guide panel speaks Taiwanese too.
    await tester.tap(find.byKey(const Key('bottomGuideToggle')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(EfficiencyOverlay), findsOneWidget);
    await pumpUntilReported(tester);
    expect(find.text('Away'), findsOneWidget);
    expect(find.text('Shanten'), findsNothing);
    expect(find.byKey(const Key('guidePlayStyle_balanced')), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
