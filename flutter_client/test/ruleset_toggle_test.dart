import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/main.dart';
import 'package:tilesense/ui/efficiency_overlay.dart';
import 'package:tilesense/ui/table_view.dart';

/// The Riichi / Hong Kong / Taiwanese switch: where it lives, what it changes, and that
/// the game it switches to lays out as cleanly as the one it left.
void main() {
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
    final game =
        (tester.widget(find.byType(TableView)) as TableView).game
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
    expect(find.textContaining('optimal Riichi Mahjong play'), findsOneWidget);
    await tester.tap(find.text('Single Player'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('charactersContinue')));
    await tester.pump(const Duration(milliseconds: 100));

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
    expect(
        find.textContaining('optimal Hong Kong Mahjong play'), findsOneWidget);
    expect(find.text('🇯🇵 Riichi'), findsOneWidget);
    expect(find.text('🇭🇰 Hong Kong'), findsOneWidget);
    expect(find.byKey(const Key('rulesPdf_riichi')), findsOneWidget);
    expect(find.byKey(const Key('rulesPdf_hongKong')), findsOneWidget);

    await tester.tap(find.text('Single Player'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('charactersContinue')));
    await tester.pump(const Duration(milliseconds: 100));

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
    await tester.tap(find.byKey(const Key('guideToggle')));
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
    expect(Ruleset.riichi.rulesUrl, 'https://app.ericrxu.com/static/Riichi.pdf');
    expect(Ruleset.hongKong.rulesUrl, 'https://app.ericrxu.com/static/HK.pdf');
    expect(Ruleset.taiwanese.rulesUrl,
        'https://app.ericrxu.com/static/Taiwanese.pdf');
  });

  testWidgets('the in-game switch cycles through all three rulesets and back',
      (tester) async {
    await boot(tester);
    await tester.tap(find.text('Single Player'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('charactersContinue')));
    await tester.pump(const Duration(milliseconds: 100));

    // Style is a riichi-only dial; pick a non-default value so the
    // Chinese-style-and-back round trip below can prove it survives.
    await tester.tap(find.byKey(const Key('playStyle')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(labelOf(tester, const Key('playStyle')), 'Defensive');

    await tester.tap(find.byKey(const Key('ruleset')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(labelOf(tester, const Key('ruleset')), Ruleset.hongKong.flagLabel);
    expect(find.byType(TableView), findsOneWidget);
    expect(find.byKey(const Key('playStyle')), findsNothing,
        reason: 'Hong Kong pins style to Balanced and hides the dial');

    await tester.tap(find.byKey(const Key('ruleset')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(labelOf(tester, const Key('ruleset')), Ruleset.taiwanese.flagLabel);
    expect(find.byType(TableView), findsOneWidget);
    expect(find.byKey(const Key('playStyle')), findsNothing,
        reason: 'Taiwanese pins style to Balanced and hides the dial too');

    await tester.tap(find.byKey(const Key('ruleset')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(labelOf(tester, const Key('ruleset')), Ruleset.riichi.flagLabel);
    expect(find.text('DORA'), findsOneWidget);
    expect(labelOf(tester, const Key('playStyle')), 'Defensive',
        reason: 'the riichi style from before the trip comes back');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('the builder opens in the chosen rules and can switch',
      (tester) async {
    await boot(tester);
    await tester.tap(find.byKey(const Key('ruleset_hongKong')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('openBuilder')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

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
    expect(find.textContaining('optimal Taiwanese Mahjong play'),
        findsOneWidget);
    expect(find.text('🇯🇵 Riichi'), findsOneWidget);
    expect(find.text('🇭🇰 Hong Kong'), findsOneWidget);
    expect(find.text('🇹🇼 Taiwanese'), findsOneWidget);
    expect(find.byKey(const Key('rulesPdf_taiwanese')), findsOneWidget);

    await tester.tap(find.text('Single Player'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('charactersContinue')));
    await tester.pump(const Duration(milliseconds: 100));

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
    await tester.tap(find.byKey(const Key('guideToggle')));
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
