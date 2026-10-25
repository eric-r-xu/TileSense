/// The rules reader's text in one language. Every language implements every
/// member, so a missing translation fails to compile rather than showing
/// English; `rules_reader_test.dart` checks each has a note for every
/// catalogue entry and the same sections as English.
library;

import 'package:mahjong_core/ruleset.dart';

import '../l10n/app_localizations.dart';
import 'rules_content.dart';
import 'rules_text_en.dart';
import 'rules_text_ja.dart';
import 'rules_text_zh.dart';
import 'rules_text_zh_hant.dart';

abstract class RulesText {
  const RulesText();

  static RulesText of(AppLocalizations l10n) => switch (l10n.localeName) {
        'ja' => const JaRulesText(),
        'zh' => const ZhRulesText(),
        'zh_Hant' => const ZhHantRulesText(),
        _ => const EnRulesText(),
      };

  // Prose. Each list ends with the "About this summary" section (id
  // `source`); the catalogue is placed just before it.
  List<RuleSection> riichi({required bool sanma});
  List<RuleSection> hongKong(String minimum);
  List<RuleSection> taiwanese(String minimum);
  List<RuleSection> mcr();
  List<RuleSection> sichuan();

  String hongKongDefaultMinimum(int faan, List<int> choices);
  String hongKongTableMinimum(int faan);
  String taiwaneseDefaultMinimum(int tai, List<int> choices);
  String taiwaneseTableMinimum(int tai);

  // Catalogue.

  /// A catalogue group's heading and introduction; MCR's groups are `mcr88`,
  /// `mcr64` and so on, one per point value.
  String groupTitle(String id);
  List<String> groupIntro(String id);

  /// The catalogue table's column headings.
  String get nameHeading;
  String get valueHeading;
  String get exampleHeading;

  /// [p]'s value in [unit]. A zero fu value is a rule with no fixed amount
  /// (kans, rounding) and reads as nothing.
  String value(ValueUnit unit, ScoringPattern p);

  /// The note for catalogue entry [key] under [ruleset], from [notes].
  String note(Ruleset ruleset, String key) => notes(ruleset)[key] ?? '';

  /// Catalogue notes by entry key. Riichi and Sanma share one table.
  Map<String, String> notes(Ruleset ruleset);

  /// Names for [ScoringPattern.ownName] entries and fu rules.
  Map<String, String> get readerNames;
  String readerName(String key) => readerNames[key] ?? key;

  /// The MCR fan an entry does not combine with.
  String mcrExcludes(List<String> names);
}

/// 12345 → "12,345".
String groupDigits(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => ',');
