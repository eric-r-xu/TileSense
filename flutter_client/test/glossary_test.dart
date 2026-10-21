import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/l10n/app_language.dart';
import 'package:tilesense/l10n/l10n.dart';
import 'package:tilesense/main.dart';
import 'package:tilesense/ui/glossary.dart';

import 'l10n_helpers.dart';
import 'helpers.dart';

/// The glossary: terms worded for the rules in play, searchable, and reachable
/// from the welcome screen and from a game.
void main() {
  Future<AppLocalizations> english() =>
      AppLocalizations.delegate.load(const Locale('en'));

  Future<Set<String>> ids(Ruleset r) async => {
        for (final e in glossaryEntries(await english(), r)) e.id,
      };

  setUp(() => Sfx.i.enabled = false);
  tearDown(() => Sfx.i.enabled = true);

  group('entries', () {
    test('every ruleset has the basics, and none repeats a term', () async {
      for (final r in Ruleset.values) {
        final entries = glossaryEntries(await english(), r);
        final seen = entries.map((e) => e.id).toList();
        expect(seen.toSet().length, seen.length, reason: r.name);
        expect(seen, containsAll(['set', 'pair', 'pon', 'tsumo', 'ron']),
            reason: r.name);
        for (final e in entries) {
          expect(e.term, isNotEmpty, reason: '${r.name} ${e.id}');
          expect(e.definition, isNotEmpty, reason: '${r.name} ${e.id}');
        }
      }
    });

    test('Riichi alone has riichi, dora and furiten', () async {
      for (final r in Ruleset.values) {
        expect(await ids(r),
            r.isRiichi
                ? containsAll(['riichi', 'dora', 'furiten'])
                : isNot(anyOf(contains('riichi'), contains('dora'),
                    contains('furiten'))),
            reason: r.name);
      }
    });

    test('flowers are Chinese-style rules, bar Sichuan', () async {
      expect(await ids(Ruleset.hongKong), contains('flowers'));
      expect(await ids(Ruleset.taiwanese), contains('flowers'));
      expect(await ids(Ruleset.riichi), isNot(contains('flowers')));
      expect(await ids(Ruleset.sichuan), isNot(contains('flowers')));
    });

    test('Sichuan has a void suit and no chows, winds or dragons', () async {
      final sichuan = await ids(Ruleset.sichuan);
      expect(sichuan, contains('void'));
      expect(sichuan, isNot(anyOf(contains('chi'), contains('winds'),
          contains('dragons'))));
      expect(await ids(Ruleset.hongKong),
          allOf(contains('chi'), contains('winds'), isNot(contains('void'))));
    });

    test('call names follow the ruleset', () async {
      final l10n = await english();
      String term(Ruleset r, String id) =>
          glossaryEntries(l10n, r).firstWhere((e) => e.id == id).term;
      expect(term(Ruleset.hongKong, 'pon'), 'Pung');
      expect(term(Ruleset.riichi, 'pon'), 'Pon');
      expect(term(Ruleset.hongKong, 'score'), 'Faan');
      expect(term(Ruleset.riichi, 'score'), 'Han');
    });
  });

  group('view', () {
    Future<void> pumpView(WidgetTester tester, Ruleset r) => pumpLocalized(
        tester, Scaffold(body: GlossaryView(ruleset: r)),
        size: const Size(800, 700));

    testWidgets('lists the terms and filters by term or definition',
        (tester) async {
      await pumpView(tester, Ruleset.hongKong);
      expect(find.byKey(const Key('glossary_set')), findsOneWidget);
      expect(find.byKey(const Key('glossary_ready')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('glossarySearch')), 'faan');
      await tester.pump();
      expect(find.byKey(const Key('glossary_score')), findsOneWidget);
      expect(find.byKey(const Key('glossary_pair')), findsNothing);

      // A word that is only in a definition.
      await tester.enterText(
          find.byKey(const Key('glossarySearch')), '  REPLACEMENT ');
      await tester.pump();
      expect(find.byKey(const Key('glossary_kan')), findsOneWidget);
      expect(find.byKey(const Key('glossary_flowers')), findsOneWidget);
      expect(find.byKey(const Key('glossary_set')), findsNothing);
    });

    testWidgets('says so when nothing matches, and recovers', (tester) async {
      await pumpView(tester, Ruleset.hongKong);
      await tester.enterText(find.byKey(const Key('glossarySearch')), 'zzzz');
      await tester.pump();
      expect(find.byKey(const Key('glossaryEmpty')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('glossarySearch')), '');
      await tester.pump();
      expect(find.byKey(const Key('glossaryEmpty')), findsNothing);
      expect(find.byKey(const Key('glossary_set')), findsOneWidget);
    });
  });

  group('opening it', () {
    Future<void> boot(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(kDesignSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const TileSenseApp());
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('from the welcome screen, in the rules selected there',
        (tester) async {
      await boot(tester);
      await tapInPopup(tester, 'learnTile', find.byKey(const Key('glossaryLink')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('glossary_flowers')), findsOneWidget,
          reason: 'Hong Kong is the default');
      expect(find.byKey(const Key('glossary_furiten')), findsNothing);

      await tester.tap(find.byKey(const Key('glossaryClose')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.byKey(const Key('glossarySearch')), findsNothing);

      await tapInPopup(tester, 'rulesTile', find.byKey(const Key('ruleset_riichi')));
      await tester.pump();
      await tapInPopup(tester, 'learnTile', find.byKey(const Key('glossaryLink')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('glossary_furiten')), findsOneWidget);
      expect(find.byKey(const Key('glossary_flowers')), findsNothing);
    });

    testWidgets('from a game, in that game\'s rules', (tester) async {
      await boot(tester);
      await tester.tap(find.text('Single Player'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('charactersContinue')));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('glossaryButton')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('glossary_flowers')), findsOneWidget);

      await tester.tap(find.byKey(const Key('glossaryClose')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('fits in every language, on a desktop and a phone',
        (tester) async {
      addTearDown(
          () => AppLanguageController.instance.select(AppLanguage.english));
      for (final size in [kDesignSize, const Size(844, 390)]) {
        for (final language in AppLanguage.values) {
          AppLanguageController.instance.select(language);
          await tester.binding.setSurfaceSize(size);
          await tester.pumpWidget(const TileSenseApp());
          await tester.pump(const Duration(milliseconds: 100));
          await tapInPopup(tester, 'learnTile', find.byKey(const Key('glossaryLink')));
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.byKey(const Key('glossary_set')), findsOneWidget,
              reason: '${language.name} $size');
          expect(tester.takeException(), isNull,
              reason: '${language.name} $size');
          await tester.pumpWidget(const SizedBox());
        }
      }
      addTearDown(() => tester.binding.setSurfaceSize(null));
    });
  });
}
