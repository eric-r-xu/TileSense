import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/l10n/app_language.dart';
import 'package:tilesense/main.dart';
import 'package:tilesense/ui/rules_content.dart';
import 'package:tilesense/ui/rules_reader.dart';

import 'helpers.dart';
import 'l10n_helpers.dart';

void main() {
  tearDown(() {
    AppLanguageController.instance.select(AppLanguage.english);
    Sfx.i.enabled = true;
  });

  test('every variant has a complete summary with unique section IDs', () {
    for (final r in Ruleset.values) {
      final sections = rulesSections(r);
      expect(sections.map((s) => s.id),
          containsAll(['setup', 'calls', 'winning', 'game', 'source']));
      expect(sections.map((s) => s.id).toSet().length, sections.length);
      expect(sections.every((s) => s.body.isNotEmpty), isTrue);
    }
    expect(rulesSections(Ruleset.sanma).map((s) => s.id), contains('kita'));
    expect(rulesSections(Ruleset.riichi).map((s) => s.id),
        isNot(contains('kita')));
  });

  test('configured minimums replace the pre-game default explanation', () {
    String winning(Ruleset r, {int? faan, int? tai}) =>
        rulesSections(r, minimumFaan: faan, minimumPoints: tai)
            .firstWhere((s) => s.id == 'winning')
            .body;
    expect(winning(Ruleset.hongKong), contains('Default minimum: 0 faan'));
    expect(winning(Ruleset.hongKong, faan: 3),
        contains('This table’s minimum: 3 faan'));
    expect(winning(Ruleset.taiwanese), contains('Default minimum: 5 tai'));
    expect(winning(Ruleset.taiwanese, tai: 1),
        contains('This table’s minimum: 1 tai'));
    expect(
        winning(Ruleset.taiwanese, tai: 1), isNot(contains('Default minimum')));
  });

  testWidgets('searches body text, handles no matches, clears and scrolls',
      (tester) async {
    await pumpLocalized(
        tester,
        Scaffold(
            body: RulesReader(
          ruleset: Ruleset.sanma,
          onClose: () {},
        )),
        size: const Size(390, 700));
    await tester.enterText(find.byKey(const Key('rulesSearch')), '  NORTH  ');
    await tester.pump();
    expect(find.byKey(const Key('rule_kita')), findsOneWidget);
    expect(find.byKey(const Key('rule_setup')), findsNothing);
    await tester.enterText(find.byKey(const Key('rulesSearch')), 'zzzzz');
    await tester.pump();
    expect(find.byKey(const Key('rulesEmpty')), findsOneWidget);
    await tester.tap(find.byKey(const Key('rulesSearchClear')));
    await tester.pump();
    expect(find.byKey(const Key('rule_setup')), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('rule_source')), 300,
        scrollable: find
            .descendant(
                of: find.byKey(const Key('rulesList')),
                matching: find.byType(Scrollable))
            .first);
    await tester.drag(
        find.byKey(const Key('rulesList')), const Offset(0, -400));
    await tester.pumpAndSettle();
    final viewport = tester.getRect(find.byKey(const Key('rulesList')));
    final source = tester.getRect(find.byKey(const Key('rule_source')));
    expect(source.top, greaterThanOrEqualTo(viewport.top));
    expect(source.bottom, lessThanOrEqualTo(viewport.bottom + 1));
    expect(find.byKey(const Key('rulesReaderClose')).hitTestable(),
        findsOneWidget);
    expect(find.byKey(const Key('rulesExternalReference')).hitTestable(),
        findsOneWidget);
    // Filtering after scrolling must return to the top.
    await tester.enterText(
        find.byKey(const Key('rulesSearch')), 'tiles and the goal');
    await tester.pump();
    expect(find.byKey(const Key('rule_setup')).hitTestable(), findsOneWidget);
  });

  testWidgets(
      'opens each correct external reference and reports launch failure',
      (tester) async {
    for (final r in Ruleset.values) {
      Uri? opened;
      await pumpLocalized(
          tester,
          Scaffold(
              body: RulesReader(
            key: ValueKey(r),
            ruleset: r,
            onClose: () {},
            openReference: (uri) async {
              opened = uri;
              return false;
            },
          )));
      await tester.tap(find.byKey(const Key('rulesExternalReference')));
      await tester.pump();
      expect(opened.toString(), r.rulesUrl);
      expect(find.byKey(const Key('rulesReferenceError')), findsOneWidget);
      expect(find.byKey(const Key('rulesReader')), findsOneWidget);
    }
  });

  testWidgets('dialog fits phone layouts and every language with large text',
      (tester) async {
    for (final language in AppLanguage.values) {
      AppLanguageController.instance.select(language);
      for (final size in [const Size(390, 844), const Size(844, 390)]) {
        await pumpLocalized(
            tester,
            Builder(
                builder: (context) => Scaffold(
                      body: TextButton(
                          onPressed: () => showRulesReader(
                              context, Ruleset.taiwanese,
                              minimumPoints: 3),
                          child: const Text('Open')),
                    )),
            size: size);
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: '${language.name} $size');
        await tester.enterText(find.byKey(const Key('rulesSearch')), 'minimum');
        await tester.pump();
        expect(find.textContaining('This table’s minimum: 3 tai.'),
            findsOneWidget);
        await tester.tap(find.byKey(const Key('rulesReaderClose')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('rulesReader')), findsNothing);
      }
    }
  });

  testWidgets(
      'welcome reader leaves selected rules intact and keeps PDF buttons',
      (tester) async {
    Sfx.i.enabled = false;
    await tester.binding.setSurfaceSize(kDesignSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tapInPopup(
        tester, 'rulesTile', find.byKey(const Key('rulesRead_sanma')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<RulesReader>(find.byType(RulesReader)).ruleset,
        Ruleset.sanma);
    await tester.tap(find.byKey(const Key('rulesReaderClose')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('rulesPdf_sanma')), findsOneWidget);
    await closePopup(tester);
    expect(find.textContaining('Sharpen your Hong Kong Mahjong decisions'),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('offline toolbar opens the current table summary',
      (tester) async {
    Sfx.i.enabled = false;
    await tester.binding.setSurfaceSize(kDesignSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Single Player'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('charactersContinue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('rulesPdf')));
    await tester.pump(const Duration(milliseconds: 300));
    final reader = tester.widget<RulesReader>(find.byType(RulesReader));
    expect(reader.ruleset, Ruleset.hongKong);
    expect(reader.minimumFaan, 0);
    await tester.tap(find.byKey(const Key('rulesReaderClose')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
