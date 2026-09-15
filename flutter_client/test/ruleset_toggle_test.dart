import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/logic/ruleset.dart';
import 'package:tilesense/main.dart';
import 'package:tilesense/ui/efficiency_overlay.dart';
import 'package:tilesense/ui/table_view.dart';

/// The Riichi / Hong Kong switch: where it lives, what it changes, and that
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

  testWidgets('riichi stays the default from the welcome screen',
      (tester) async {
    await boot(tester);
    expect(find.textContaining('optimal Riichi Mahjong play'), findsOneWidget);
    await tester.tap(find.text('Start'));
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

    await tester.tap(find.text('Start'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(labelOf(tester, const Key('ruleset')), Ruleset.hongKong.flagLabel);
    expect(labelOf(tester, const Key('hanchan')), 'Four winds');
    expect(labelOf(tester, const Key('playStyle')), 'Aggressive');
    expect(labelOf(tester, const Key('handFocus')), 'Speed');
    expect(find.text('FLOWERS & SEASONS'), findsOneWidget);
    expect(find.text('DORA'), findsNothing);
    expect(find.byKey(const Key('rulesPdf')), findsOneWidget);
    expect(find.textContaining('Honba'), findsNothing);
    expect(find.textContaining('1000'), findsWidgets,
        reason: 'every seat starts on 1000 chips');

    // The guide panel speaks Hong Kong too.
    await tester.tap(find.byKey(const Key('guideToggle')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(EfficiencyOverlay), findsOneWidget);
    expect(find.text('Away'), findsOneWidget);
    expect(find.text('Shanten'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  test('each ruleset links its own rules PDF', () {
    expect(Ruleset.riichi.rulesUrl, 'https://app.ericrxu.com/static/Riichi.pdf');
    expect(Ruleset.hongKong.rulesUrl, 'https://app.ericrxu.com/static/HK.pdf');
  });

  testWidgets('the in-game switch changes rules both ways', (tester) async {
    await boot(tester);
    await tester.tap(find.text('Start'));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('ruleset')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(labelOf(tester, const Key('ruleset')), Ruleset.hongKong.flagLabel);
    expect(find.byType(TableView), findsOneWidget);
    expect(find.text('FLOWERS & SEASONS'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ruleset')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(labelOf(tester, const Key('ruleset')), Ruleset.riichi.flagLabel);
    expect(find.text('DORA'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('the builder opens in the chosen rules and can switch',
      (tester) async {
    await boot(tester);
    await tester.tap(find.byKey(const Key('ruleset_hongKong')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('openBuilder')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('🇭🇰 Hong Kong rules ⇄'), findsOneWidget);
    expect(find.text('Honba '), findsNothing);
    expect(find.text('Your flowers (0)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('builderRuleset')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('🇯🇵 Riichi rules ⇄'), findsOneWidget);
    expect(find.text('Honba '), findsOneWidget);
    expect(find.text('Dora (1)'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
