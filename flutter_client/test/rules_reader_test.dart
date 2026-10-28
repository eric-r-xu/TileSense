import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/mcr/mcr_fan.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/l10n/app_language.dart';
import 'package:tilesense/l10n/l10n.dart';
import 'package:tilesense/l10n/mahjong_terms.dart';
import 'package:tilesense/main.dart';
import 'package:tilesense/ui/rules_content.dart';
import 'package:tilesense/ui/rules_reader.dart';
import 'package:tilesense/ui/rules_text.dart';
import 'package:tilesense/ui/tile_face.dart';

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
      expect(sections.every((s) => s.body.isNotEmpty || s.entries.isNotEmpty),
          isTrue);
    }
    expect(rulesSections(Ruleset.sanma).map((s) => s.id), contains('kita'));
    expect(rulesSections(Ruleset.riichi).map((s) => s.id),
        isNot(contains('kita')));
  });

  AppLocalizations l10nFor(AppLanguage language) =>
      lookupAppLocalizations(language.locale);

  test('every language has the same sections and a note for every entry', () {
    final english = l10nFor(AppLanguage.english);
    for (final r in Ruleset.values) {
      final ids = rulesSections(r, l10n: english).map((s) => s.id).toList();
      for (final language in AppLanguage.values) {
        final l10n = l10nFor(language);
        final sections = rulesSections(r, l10n: l10n);
        final reason = '${language.name} ${r.name}';
        expect(sections.map((s) => s.id), ids, reason: reason);
        expect(sections.last.id, 'source', reason: reason);
        for (final s in sections) {
          expect(s.title, isNotEmpty, reason: '$reason ${s.id}');
          expect(s.body.isNotEmpty || s.entries.isNotEmpty, isTrue,
              reason: '$reason ${s.id}');
          for (final e in s.entries) {
            expect(e.note, isNotEmpty, reason: '$reason ${e.alias}');
          }
        }
        // Every key a language's notes table has is one the catalogue uses;
        // riichi and sanma share a table.
        final keys = {
          for (final v in r.isJapanese ? [Ruleset.riichi, Ruleset.sanma] : [r])
            for (final g in scoringCatalogue(v)) ...g.patterns.map((p) => p.key)
        };
        expect(keys.containsAll(RulesText.of(l10n).notes(r).keys), isTrue,
            reason: reason);
        if (language != AppLanguage.english) {
          // Names come translated: nothing falls back to the English key.
          for (final e in sections.expand((s) => s.entries)) {
            expect(e.name, isNot(matches(RegExp('[A-Za-z]{3}'))),
                reason: '$reason ${e.name}');
          }
        }
      }
    }
  });

  test('each point is one sentence, so several read as bullets', () {
    // A sentence ending before the point does: "word. Next" or "。次", but
    // not an initial ("J. Reynolds").
    final inner = RegExp(r'[a-z\d)’]\.\s+\S|。.');
    for (final language in AppLanguage.values) {
      for (final r in Ruleset.values) {
        for (final s in rulesSections(r,
            l10n: l10nFor(language), minimumFaan: 3, minimumPoints: 5)) {
          for (final point in s.points) {
            expect(point, isNot(contains(inner)),
                reason: '${language.name} ${r.name} ${s.id}');
          }
        }
        for (final s in rulesSections(r, l10n: l10nFor(language))
            .where((s) => s.id == 'winning')) {
          expect(s.points.first, isNot(contains(inner)),
              reason: '${language.name} ${r.name} default minimum');
        }
      }
    }
  });

  test('every example parses, with at most four of any tile', () {
    for (final r in Ruleset.values) {
      for (final e in rulesSections(r).expand((s) => s.entries)) {
        final tiles = [
          for (final set in e.example.split(' '))
            if (set.isNotEmpty && set != '→') ...exampleSet(set)
        ];
        for (final type in tiles.map((t) => t.type).toSet()) {
          expect(
              tiles.where((t) => t.type == type).length, lessThanOrEqualTo(4),
              reason: '${r.name} ${e.alias} ${type.code}');
        }
      }
    }
    expect(exampleSet('0m').single.aka, isTrue);
    expect(exampleSet('S12').map((t) => t.type.code), ['S1', 'S2']);
    expect(exampleSet('SS').map((t) => t.type.code), ['S', 'S']);
  });

  testWidgets('catalogues are tables with tile examples; prose has bullets',
      (tester) async {
    await pumpLocalized(
        tester,
        Scaffold(
            body: RulesReader(
          ruleset: Ruleset.riichi,
          onClose: () {},
        )),
        size: const Size(390, 700));
    expect(find.text('•  '), findsWidgets);
    await tester.enterText(find.byKey(const Key('rulesSearch')), 'chiitoitsu');
    await tester.pump();
    final yaku = find.byKey(const Key('rule_yaku'));
    expect(find.descendant(of: yaku, matching: find.byType(Table)),
        findsOneWidget);
    expect(find.descendant(of: yaku, matching: find.text('Example')),
        findsOneWidget);
    expect(find.descendant(of: yaku, matching: find.byType(TileFace)),
        findsNWidgets(14));
    expect(tester.takeException(), isNull);
  });

  test('catalogues list every pattern each scorer can report', () {
    // Literal names in the scorers' add('…') and YakuResult('…') calls;
    // names built from a tile's name are families the catalogue names
    // itself (dragon pungs, seat flowers).
    final literal = RegExp(r"(?:add|YakuResult)\(\s*'([^'$]+)'");
    Set<String> reported(String file) => {
          for (final m in literal.allMatches(
              File('../packages/mahjong_core/lib/$file').readAsStringSync()))
            if (!m[1]!.endsWith('(upgrade)')) m[1]!
        };
    Set<String> listed(Ruleset r) => {
          for (final g in scoringCatalogue(r))
            for (final p in g.patterns) p.key
        };
    expect(listed(Ruleset.riichi),
        containsAll(reported('scoring.dart')..remove('Kita')));
    expect(listed(Ruleset.sanma), contains('Kita'));
    expect(listed(Ruleset.sanma), isNot(contains('Sanshoku Doujun')));
    expect(listed(Ruleset.hongKong),
        containsAll(reported('hong_kong/hong_kong_scoring.dart')));
    expect(listed(Ruleset.taiwanese),
        containsAll(reported('taiwanese/taiwanese_scoring.dart')));
    expect(listed(Ruleset.sichuan),
        containsAll(reported('sichuan/sichuan_scoring.dart')));
    expect(listed(Ruleset.mcr),
        containsAll([...mcrFans.map((f) => f.name), mcrMixedKongs]));
    expect(listed(Ruleset.mcr).length, mcrFans.length + 1);
  });

  test('MCR entries carry their points and exclusions', () {
    final english = rulesSections(Ruleset.mcr);
    final top = english.firstWhere((s) => s.id == 'mcr88');
    final bigWinds = top.entries.firstWhere((e) => e.alias == 'Big Four Winds');
    expect(bigWinds.value, '88 fan');
    expect(bigWinds.note,
        allOf(contains('Not with: '), contains('Big Three Winds')));
    expect(english.firstWhere((s) => s.id == 'mcr1').entries,
        hasLength(mcrFans.where((f) => f.points == 1).length));
    final chinese =
        rulesSections(Ruleset.mcr, l10n: l10nFor(AppLanguage.simplifiedChinese))
            .firstWhere((s) => s.id == 'mcr88')
            .entries
            .firstWhere((e) => e.alias == 'Big Four Winds');
    expect(chinese.name, '大四喜');
    expect(chinese.note, contains('三风刻'));
  });

  test('MCR fan names are translated on the score screen too', () {
    final ja = l10nFor(AppLanguage.japanese);
    expect(ja.scoringName('Nine Gates', Ruleset.mcr), '九蓮宝燈');
    expect(ja.scoringName('Nine Gates', Ruleset.hongKong), isNot('九蓮宝燈'));
    for (final f in mcrFans) {
      expect(ja.scoringName(f.name, Ruleset.mcr), isNot(f.name));
    }
  });

  test('a search inside a catalogue keeps only the matching entries', () {
    final hits = rulesSections(Ruleset.riichi)
        .map((s) => s.filtered('pinfu'))
        .nonNulls
        .toList();
    final yaku = hits.firstWhere((s) => s.id == 'yaku');
    expect(yaku.entries.map((e) => e.alias), ['Pinfu']);
    // English names still find a pattern in another language.
    final ja =
        rulesSections(Ruleset.riichi, l10n: l10nFor(AppLanguage.japanese))
            .map((s) => s.filtered('chiitoitsu'))
            .nonNulls
            .firstWhere((s) => s.id == 'yaku');
    expect(ja.entries.single.name, '七対子');
  });

  test('Riichi and Sanma explain all three furiten with examples', () {
    for (final r in [Ruleset.riichi, Ruleset.sanma]) {
      final furiten = rulesSections(r).firstWhere((s) => s.id == 'furiten');
      expect(furiten.entries.map((e) => e.alias),
          ['Discard furiten', 'Temporary furiten', 'Riichi furiten']);
      for (final e in furiten.entries) {
        expect(e.example, contains('→'), reason: e.alias);
        expect(e.note, contains('Avoid it'), reason: e.alias);
      }
      // It replaces the winning section's old furiten bullets.
      expect(rulesSections(r).firstWhere((s) => s.id == 'winning').body,
          isNot(contains('Furiten')));
    }
    for (final r in [
      Ruleset.hongKong,
      Ruleset.taiwanese,
      Ruleset.mcr,
      Ruleset.sichuan
    ]) {
      expect(rulesSections(r).map((s) => s.id), isNot(contains('furiten')));
    }
  });

  test('every style says what the minimum is and how to choose it', () {
    List<RuleSection> sections(Ruleset r) => rulesSections(r);
    expect(
        sections(Ruleset.hongKong)
            .firstWhere((s) => s.id == 'minimum')
            .entries
            .map((e) => e.name),
        ['0 faan', '1 faan', '2 faan', '3 faan']);
    expect(
        sections(Ruleset.taiwanese)
            .firstWhere((s) => s.id == 'minimum')
            .entries
            .map((e) => e.name),
        ['1 tai', '3 tai', '5 tai']);
    // Riichi, MCR and Sichuan have a fixed minimum: guidance sits in the
    // winning section.
    expect(sections(Ruleset.riichi).firstWhere((s) => s.id == 'winning').body,
        contains('1,000 points'));
    expect(sections(Ruleset.mcr).firstWhere((s) => s.id == 'winning').body,
        contains('add up to 8'));
    expect(sections(Ruleset.sichuan).firstWhere((s) => s.id == 'winning').body,
        contains('1 point'));
  });

  testWidgets(
      'furiten and minimum tables use their own headings; minimums '
      'have no tile column', (tester) async {
    Future<void> open(Ruleset r) async {
      await pumpLocalized(
          tester, Scaffold(body: RulesReader(ruleset: r, onClose: () {})),
          size: const Size(390, 700));
      await tester.pump();
    }

    Future<void> search(String query) async {
      await tester.enterText(find.byKey(const Key('rulesSearch')), query);
      await tester.pump();
    }

    await open(Ruleset.riichi);
    await search('furiten');
    final furiten = find.byKey(const Key('rule_furiten'));
    expect(find.descendant(of: furiten, matching: find.text('Type')),
        findsOneWidget);
    expect(find.descendant(of: furiten, matching: find.text('Lasts')),
        findsOneWidget);
    expect(find.descendant(of: furiten, matching: find.text('Example')),
        findsOneWidget);
    expect(find.descendant(of: furiten, matching: find.byType(TileFace)),
        findsWidgets);

    await open(Ruleset.hongKong);
    await search('choosing a minimum');
    final minimum = find.byKey(const Key('rule_minimum'));
    expect(find.descendant(of: minimum, matching: find.text('Best for')),
        findsOneWidget);
    expect(find.descendant(of: minimum, matching: find.text('Example')),
        findsNothing);
    expect(find.descendant(of: minimum, matching: find.byType(TileFace)),
        findsNothing);
    expect(tester.takeException(), isNull);
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
        maxScrolls: 200,
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
        final minimum =
            RulesText.of(l10nFor(language)).taiwaneseTableMinimum(3);
        await tester.enterText(find.byKey(const Key('rulesSearch')), minimum);
        await tester.pump();
        expect(
            find.descendant(
                of: find.byKey(const Key('rulesList')),
                matching: find.textContaining(minimum)),
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
    expect(taglineRules('Hong Kong'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the title screen opens the rulebook from the Learn popup and '
      'its own button, on the ruleset picked', (tester) async {
    Sfx.i.enabled = false;
    await tester.binding.setSurfaceSize(kDesignSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));

    // The button is in the title row, named, with no popup to open first.
    final icons = find.byKey(const Key('titleIcons'));
    expect(find.descendant(of: icons, matching: find.text('Read rules')),
        findsOneWidget);
    await tester.tap(find.byKey(const Key('titleRulebook')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.widget<RulesReader>(find.byType(RulesReader)).ruleset,
        Ruleset.hongKong);
    await tester.tap(find.byKey(const Key('rulesReaderClose')));
    await tester.pump(const Duration(milliseconds: 400));

    // And the first item in Learn / Train.
    await tapInPopup(
        tester, 'learnTile', find.byKey(const Key('rulebookLink')));
    expect(find.byType(RulesReader), findsOneWidget);
    expect(tester.widget<RulesReader>(find.byType(RulesReader)).ruleset,
        Ruleset.hongKong);
    await tester.tap(find.byKey(const Key('rulesReaderClose')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
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
