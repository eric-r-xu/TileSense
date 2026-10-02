import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/round.dart' show CallType;
import 'package:mahjong_core/ruleset.dart';
import 'package:tilesense/l10n/app_language.dart';
import 'package:tilesense/l10n/l10n.dart';
import 'package:tilesense/l10n/mahjong_terms.dart';

/// The language setting, the ARB files, and the mahjong vocabulary: every
/// name `mahjong_core` can put on screen has all four languages.
void main() {
  final en = lookupAppLocalizations(AppLanguage.english.locale);
  final others = [
    for (final l in AppLanguage.values)
      if (l != AppLanguage.english) lookupAppLocalizations(l.locale)
  ];

  group('the language a first visit gets', () {
    AppLanguage of(List<Locale> locales) => AppLanguage.fromLocales(locales);
    test('follows the browser, Chinese by script or region', () {
      expect(of(const [Locale('ja', 'JP')]), AppLanguage.japanese);
      expect(of(const [Locale('zh', 'TW')]), AppLanguage.traditionalChinese);
      expect(of(const [Locale('zh', 'HK')]), AppLanguage.traditionalChinese);
      expect(of(const [Locale('zh', 'MO')]), AppLanguage.traditionalChinese);
      expect(
          of(const [Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')]),
          AppLanguage.traditionalChinese);
      expect(of(const [Locale('zh', 'CN')]), AppLanguage.simplifiedChinese);
      expect(of(const [Locale('zh', 'SG')]), AppLanguage.simplifiedChinese);
      expect(of(const [Locale('zh')]), AppLanguage.simplifiedChinese);
      expect(of(const [Locale('en', 'GB')]), AppLanguage.english);
    });

    test('takes the first preference we have, else English', () {
      expect(of(const [Locale('fr'), Locale('ja')]), AppLanguage.japanese);
      expect(of(const [Locale('fr'), Locale('de')]), AppLanguage.english);
      expect(of(const []), AppLanguage.english);
    });
  });

  test('an explicit pick is remembered and beats the browser', () {
    final store = <String, String>{};
    AppLanguageController make() => AppLanguageController(
          read: (k) => store[k],
          write: (k, v) => store[k] = v,
          browserLocales: () => const [Locale('ja')],
        );
    expect(make().value, AppLanguage.japanese, reason: 'nothing picked yet');
    make().select(AppLanguage.traditionalChinese);
    expect(make().value, AppLanguage.traditionalChinese,
        reason: 'the pick survives a reload, over the browser');
    store[AppLanguageController.storageKey] = 'klingon';
    expect(make().value, AppLanguage.japanese,
        reason: 'an unknown saved value falls back to the browser');
  });

  test('every language has every key, with no placeholder it can not fill',
      () {
    Map<String, dynamic> arb(String locale) => jsonDecode(
            File('lib/l10n/app_$locale.arb').readAsStringSync())
        as Map<String, dynamic>;
    Set<String> keys(Map<String, dynamic> a) =>
        {for (final k in a.keys) if (!k.startsWith('@')) k};
    Set<String> holes(String s) =>
        {for (final m in RegExp(r'\{(\w+)\}').allMatches(s)) m[1]!};
    final template = arb('en');
    for (final locale in ['ja', 'zh', 'zh_Hant']) {
      final other = arb(locale);
      expect(keys(other), keys(template), reason: locale);
      for (final k in keys(template)) {
        expect(holes(other[k] as String).difference(holes(template[k] as String)),
            isEmpty,
            reason: '$locale $k');
        expect((other[k] as String).trim(), isNotEmpty, reason: '$locale $k');
      }
    }
  });

  group('mahjong vocabulary', () {
    test('English call words are exactly the ruleset\'s own', () {
      for (final r in Ruleset.values) {
        expect(en.callLabel(CallType.chi, r), r.chiLabel);
        expect(en.callLabel(CallType.pon, r), r.ponLabel);
        expect(en.callLabel(CallType.kan, r), r.kanLabel);
        expect(en.callLabel(CallType.ron, r), r.ronLabel);
        expect(en.tsumoLabel(r), r.tsumoLabel);
        expect(en.rulesetName(r), r.label);
        expect(en.rulesetFlagLabel(r), r.flagLabel);
      }
    });

    test('every other language has its own word for every call, per ruleset',
        () {
      for (final l in others) {
        for (final r in Ruleset.values) {
          for (final t in [
            CallType.chi,
            CallType.pon,
            CallType.kan,
            CallType.ron
          ]) {
            expect(l.callLabel(t, r), isNot(en.callLabel(t, r)),
                reason: '${l.localeName} $t $r');
          }
          expect(l.tsumoLabel(r), isNot(en.tsumoLabel(r)));
        }
      }
      // Within Chinese, Hong Kong and Taiwanese keep their own words.
      final zh = lookupAppLocalizations(AppLanguage.simplifiedChinese.locale);
      expect(zh.callLabel(CallType.chi, Ruleset.hongKong), '上');
      expect(zh.callLabel(CallType.chi, Ruleset.taiwanese), '吃');
      expect(zh.callLabel(CallType.ron, Ruleset.hongKong), '食糊');
      expect(zh.callLabel(CallType.ron, Ruleset.taiwanese), '胡');
    });

    /// Every scoring-name literal in a `mahjong_core` source file: the first
    /// argument of `YakuResult(` / `add(`, and both sides of a ternary there.
    Set<String> namesIn(String path) {
      final src = File('../packages/mahjong_core/lib/$path').readAsStringSync();
      final names = <String>{};
      for (final call in RegExp(r"(?:YakuResult|add)\((?:const\s+)?([^;]*?),\s*\w")
          .allMatches(src)) {
        for (final lit in RegExp(r"'([^'$]+)'").allMatches(call[1]!)) {
          names.add(lit[1]!);
        }
      }
      return names;
    }

    for (final (ruleset, path) in [
      (Ruleset.riichi, 'scoring.dart'),
      (Ruleset.hongKong, 'hong_kong/hong_kong_scoring.dart'),
      (Ruleset.taiwanese, 'taiwanese/taiwanese_scoring.dart'),
    ]) {
      test('every ${ruleset.name} scoring name is translated', () {
        final names = namesIn(path);
        expect(names.length, greaterThan(25), reason: 'the scan found them');
        for (final name in names) {
          expect(en.scoringName(name, ruleset), name);
          for (final l in others) {
            expect(l.scoringName(name, ruleset), isNot(name),
                reason: '${l.localeName}: "$name" (${ruleset.name})');
          }
        }
      });
    }

    test('names built from a tile are translated too', () {
      for (final l in others) {
        expect(l.scoringName('Yakuhai (East)', Ruleset.riichi),
            isNot(contains('East')));
        expect(l.scoringName('Red Dragon Pung', Ruleset.hongKong),
            isNot(contains('Dragon')));
        expect(l.scoringName('Plum', Ruleset.hongKong), isNot('Plum'));
      }
      expect(en.scoringName('Yakuhai (East)', Ruleset.riichi), 'Yakuhai (East)');
      expect(en.scoringName('Red Dragon Pung', Ruleset.hongKong),
          'Red Dragon Pung');
    });

    test('every round result title and limit name is translated', () {
      final round = File('../packages/mahjong_core/lib/round.dart')
          .readAsStringSync();
      final labels = {
        for (final m in RegExp(r"'([A-Z][^'$]*)'")
            .allMatches(round.substring(round.indexOf('label:'))))
          if (_resultTitles.contains(m[1])) m[1]!
      };
      expect(labels, _resultTitles, reason: 'round.dart still uses them all');
      for (final label in labels) {
        expect(en.resultLabel(label, Ruleset.riichi), label);
        for (final l in others) {
          expect(l.resultLabel(label, Ruleset.riichi), isNot(label),
              reason: '${l.localeName}: $label');
        }
      }
      for (final limit in [
        'Mangan',
        'Haneman',
        'Baiman',
        'Sanbaiman',
        'Kazoe Yakuman',
        'Yakuman',
        '2× Yakuman',
        '13+ faan cap',
      ]) {
        expect(en.limitName(limit), limit);
        for (final l in others) {
          expect(l.limitName(limit), isNot(limit), reason: limit);
        }
      }
    });

    test('a name the core adds later shows in English, never blank', () {
      for (final l in [en, ...others]) {
        expect(l.scoringName('Brand New Yaku', Ruleset.riichi),
            'Brand New Yaku');
      }
    });
  });
}

const _resultTitles = {
  'Kyuushu Kyuuhai — nine terminals/honors',
  'Exhaustive Draw',
  'Multiple Wins',
  'Robbing a Kong',
  'Win on Discard',
  'Multiple Ron',
  'Chankan',
  'Ron',
  'Self Draw',
  'Tsumo',
};
