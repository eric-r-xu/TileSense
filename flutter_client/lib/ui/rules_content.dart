/// Player-facing summaries of docs/*_RULES.md and catalogues of every pattern
/// each scorer counts. Update both when rules change.
///
/// The catalogues' values live here, once, for every language; MCR's come
/// straight from `mcrFans`. Pattern names use the score screen's own
/// translations ([MahjongTerms.scoringName]); the prose, notes and value
/// wording come from the language's [RulesText].
library;

import 'package:flutter/widgets.dart' show Locale;
import 'package:mahjong_core/hong_kong/hong_kong_rules.dart';
import 'package:mahjong_core/mcr/mcr_fan.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/taiwanese/taiwanese_rules.dart';

import '../l10n/l10n.dart';
import '../l10n/mahjong_terms.dart';
import 'rules_text.dart';

class RuleEntry {
  const RuleEntry(this.name, this.value, this.note, {this.alias = ''});

  final String name;
  final String value;
  final String note;

  /// The pattern's English name, so a search in English still finds it when
  /// the reader is in another language. Not shown.
  final String alias;

  bool matches(String query) =>
      '$name $value $note $alias'.toLowerCase().contains(query);
}

class RuleSection {
  const RuleSection(this.id, this.title, this.body, {this.entries = const []});

  final String id;
  final String title;
  final String body;
  final List<RuleEntry> entries;

  bool matches(String query) => filtered(query) != null;

  /// This section as a search for [query] shows it: whole when its title or
  /// text matches, cut down to the matching entries when only they do, and
  /// null when nothing does.
  RuleSection? filtered(String query) {
    if ('$title $body'.toLowerCase().contains(query)) return this;
    final hits = entries.where((e) => e.matches(query)).toList();
    return hits.isEmpty ? null : RuleSection(id, title, body, entries: hits);
  }
}

/// How a catalogue group's values read: each [RulesText] words them.
enum ValueUnit { han, faan, tai, fan, mcrFan, fu, basicPoints }

/// How a catalogue group's names are found.
enum NameSource {
  /// The name `mahjong_core` reports, translated as on the score screen.
  scoring,

  /// A riichi limit, translated as on the score screen.
  limit,

  /// The reader's own name, for a fu rule: [RulesText.readerName].
  reader,
}

/// One catalogue line. [key] identifies it to every language's [RulesText]
/// (and, for [NameSource.scoring], is the scorer's own name).
class ScoringPattern {
  const ScoringPattern(this.key, this.value,
      {this.open,
      this.closedOnly = false,
      this.yakuman = 0,
      this.each = false,
      this.ownName = false});

  final String key;
  final int value;

  /// Riichi: the han when called open, if different from [value].
  final int? open;
  final bool closedOnly;
  final int yakuman;

  /// Scored once for every qualifying set or tile.
  final bool each;

  /// A family the scorer reports under each tile's name (a dragon pung, a
  /// seat flower): named by [RulesText.readerName] instead.
  final bool ownName;
}

class CatalogueGroup {
  const CatalogueGroup(this.id, this.unit, this.patterns,
      {this.names = NameSource.scoring});

  final String id;
  final ValueUnit unit;
  final List<ScoringPattern> patterns;
  final NameSource names;
}

/// The catalogue groups for [ruleset], in reading order.
List<CatalogueGroup> scoringCatalogue(Ruleset ruleset) => switch (ruleset) {
      Ruleset.riichi || Ruleset.sanma => _riichiCatalogue(ruleset.isSanma),
      Ruleset.hongKong => const [
          CatalogueGroup('faan', ValueUnit.faan, _hongKongFaan),
        ],
      Ruleset.taiwanese => const [
          CatalogueGroup('tai', ValueUnit.tai, _taiwaneseTai),
        ],
      Ruleset.mcr => _mcrCatalogue(),
      Ruleset.sichuan => const [
          CatalogueGroup('sichuanFan', ValueUnit.fan, _sichuanFan),
        ],
    };

/// Null minimums mean the reader was opened before a table was configured.
/// [l10n] picks the language; English when omitted.
List<RuleSection> rulesSections(Ruleset ruleset,
    {AppLocalizations? l10n, int? minimumFaan, int? minimumPoints}) {
  l10n ??= lookupAppLocalizations(const Locale('en'));
  final text = RulesText.of(l10n);
  final prose = switch (ruleset) {
    Ruleset.riichi || Ruleset.sanma => text.riichi(sanma: ruleset.isSanma),
    Ruleset.hongKong => text.hongKong(minimumFaan == null
        ? text.hongKongDefaultMinimum(
            HongKongRules.defaultMinimumFaan, HongKongRules.minimumFaanChoices)
        : text.hongKongTableMinimum(minimumFaan)),
    Ruleset.taiwanese => text.taiwanese(minimumPoints == null
        ? text.taiwaneseDefaultMinimum(TaiwaneseRules.defaultMinimumPoints,
            TaiwaneseRules.minimumPointsChoices)
        : text.taiwaneseTableMinimum(minimumPoints)),
    Ruleset.mcr => text.mcr(),
    Ruleset.sichuan => text.sichuan(),
  };
  final catalogue = [
    for (final group in scoringCatalogue(ruleset))
      RuleSection(
        group.id,
        text.groupTitle(group.id),
        text.groupIntro(group.id),
        entries: [
          for (final p in group.patterns)
            RuleEntry(
              p.ownName
                  ? text.readerName(p.key)
                  : _name(l10n, text, ruleset, group.names, p.key),
              text.value(group.unit, p),
              ruleset.isMcr && group.names == NameSource.scoring
                  ? _mcrNote(l10n, text, p.key)
                  : text.note(ruleset, p.key),
              alias: group.names == NameSource.reader || p.ownName ? '' : p.key,
            ),
        ],
      ),
  ];
  // The catalogue goes before the closing "About this summary".
  return [...prose.take(prose.length - 1), ...catalogue, prose.last];
}

String _name(AppLocalizations l10n, RulesText text, Ruleset r, NameSource names,
        String key) =>
    switch (names) {
      NameSource.scoring => l10n.scoringName(key, r),
      NameSource.limit => l10n.limitName(key),
      NameSource.reader => text.readerName(key),
    };

String _mcrNote(AppLocalizations l10n, RulesText text, String key) {
  final fan = mcrFans.where((f) => f.name == key).firstOrNull;
  final note = text.note(Ruleset.mcr, key);
  if (fan == null || fan.excludes.isEmpty) return note;
  final excluded = [
    for (final id in fan.excludes)
      l10n.scoringName(mcrFans[id - 1].name, Ruleset.mcr)
  ];
  return '$note ${text.mcrExcludes(excluded)}';
}

// --- Riichi and Sanma --------------------------------------------------------

List<CatalogueGroup> _riichiCatalogue(bool sanma) => [
      CatalogueGroup('yaku', ValueUnit.han, [
        const ScoringPattern('Riichi', 1, closedOnly: true),
        const ScoringPattern('Double Riichi', 2, closedOnly: true),
        const ScoringPattern('Ippatsu', 1, closedOnly: true),
        const ScoringPattern('Menzen Tsumo', 1, closedOnly: true),
        const ScoringPattern('Pinfu', 1, closedOnly: true),
        const ScoringPattern('Iipeiko', 1, closedOnly: true),
        const ScoringPattern('Haitei Raoyue', 1),
        const ScoringPattern('Houtei Raoyui', 1),
        const ScoringPattern('Rinshan Kaihou', 1),
        const ScoringPattern('Chankan', 1),
        const ScoringPattern('Tanyao', 1),
        const ScoringPattern('yakuhaiDragon', 1, each: true, ownName: true),
        const ScoringPattern('Round Wind', 1, each: true),
        const ScoringPattern('Seat Wind', 1, each: true),
        if (!sanma) const ScoringPattern('Sanshoku Doujun', 2, open: 1),
        const ScoringPattern('Ittsu', 2, open: 1),
        const ScoringPattern('Chanta', 2, open: 1),
        const ScoringPattern('Chiitoitsu', 2, closedOnly: true),
        const ScoringPattern('Toitoi', 2),
        const ScoringPattern('Sanankou', 2),
        const ScoringPattern('Sanshoku Doukou', 2),
        const ScoringPattern('Sankantsu', 2),
        const ScoringPattern('Honroutou', 2),
        const ScoringPattern('Shousangen', 2),
        const ScoringPattern('Junchan', 3, open: 2),
        const ScoringPattern('Honitsu', 3, open: 2),
        const ScoringPattern('Ryanpeikou', 3, closedOnly: true),
        const ScoringPattern('Chinitsu', 6, open: 5),
      ]),
      const CatalogueGroup('yakuman', ValueUnit.han, [
        ScoringPattern('Kokushi Musou', 0, yakuman: 1),
        ScoringPattern('Suuankou', 0, yakuman: 1),
        ScoringPattern('Daisangen', 0, yakuman: 1),
        ScoringPattern('Shousuushii', 0, yakuman: 1),
        ScoringPattern('Daisuushii', 0, yakuman: 2),
        ScoringPattern('Tsuuiisou', 0, yakuman: 1),
        ScoringPattern('Chinroutou', 0, yakuman: 1),
        ScoringPattern('Ryuuiisou', 0, yakuman: 1),
        ScoringPattern('Chuuren Poutou', 0, yakuman: 1),
      ]),
      CatalogueGroup('dora', ValueUnit.han, [
        const ScoringPattern('Dora', 1, each: true),
        const ScoringPattern('Ura Dora', 1, each: true),
        const ScoringPattern('Aka Dora', 1, each: true),
        if (sanma) const ScoringPattern('Kita', 1, each: true),
      ]),
      const CatalogueGroup('fu', ValueUnit.fu, names: NameSource.reader, [
        ScoringPattern('fuBase', 20),
        ScoringPattern('fuClosedRon', 10),
        ScoringPattern('fuTsumo', 2),
        ScoringPattern('fuPinfu', 30),
        ScoringPattern('fuChiitoitsu', 25),
        ScoringPattern('fuOpenSimpleTriplet', 2),
        ScoringPattern('fuClosedSimpleTriplet', 4),
        ScoringPattern('fuOpenHonorTriplet', 4),
        ScoringPattern('fuClosedHonorTriplet', 8),
        ScoringPattern('fuKan', 0),
        ScoringPattern('fuValuePair', 2),
        ScoringPattern('fuWait', 2),
        ScoringPattern('fuRounding', 0),
      ]),
      const CatalogueGroup(
          'limits',
          ValueUnit.basicPoints,
          names: NameSource.limit,
          [
            ScoringPattern('Mangan', 2000),
            ScoringPattern('Haneman', 3000),
            ScoringPattern('Baiman', 4000),
            ScoringPattern('Sanbaiman', 6000),
            ScoringPattern('Kazoe Yakuman', 8000),
            ScoringPattern('Yakuman', 8000),
          ]),
    ];

// --- Hong Kong ---------------------------------------------------------------

const _hongKongFaan = [
  ScoringPattern('Self-Pick', 1),
  ScoringPattern('Win by Kong Replacement', 2),
  ScoringPattern('Double Kong Replacement', 9),
  ScoringPattern('Concealed Hand', 1),
  ScoringPattern('Robbing the Kong', 1),
  ScoringPattern('Moon Under the Sea', 1),
  ScoringPattern('All Sequences', 1),
  ScoringPattern('All Triplets', 3),
  ScoringPattern('All Concealed Triplets', 8),
  ScoringPattern('All Quadruplets', 13),
  ScoringPattern('hkDragonPung', 1, each: true, ownName: true),
  ScoringPattern('Small Three Dragons', 5),
  ScoringPattern('Big Three Dragons', 8),
  ScoringPattern('Seat Wind', 1),
  ScoringPattern('Round Wind', 1),
  ScoringPattern('Small Four Winds', 6),
  ScoringPattern('Big Four Winds', 13),
  ScoringPattern('Mixed Flush', 3),
  ScoringPattern('Full Flush', 7),
  ScoringPattern('Mixed Terminals', 4),
  ScoringPattern('All Terminals', 13),
  ScoringPattern('All Honours', 10),
  ScoringPattern('Seven Pairs', 4),
  ScoringPattern('Nine Gates', 13),
  ScoringPattern('Thirteen Orphans', 13),
  ScoringPattern('Blessing of Heaven', 13),
  ScoringPattern('Blessing of Earth', 13),
  ScoringPattern('Blessing of Man', 13),
  ScoringPattern('No Flowers or Seasons', 1),
  ScoringPattern('hkSeatFlower', 1, each: true, ownName: true),
  ScoringPattern('All Flowers', 2),
  ScoringPattern('All Seasons', 2),
  ScoringPattern('Seven Flowers', 3),
  ScoringPattern('Eight Flowers', 8),
  ScoringPattern('Chicken Hand', 0),
];

// --- Taiwanese ---------------------------------------------------------------

const _taiwaneseTai = [
  ScoringPattern('Self-Drawn', 1),
  ScoringPattern('Concealed Hand', 1),
  ScoringPattern('Fully Concealed Hand', 3),
  ScoringPattern('Value Honor', 1, each: true),
  ScoringPattern('Flower Tile', 1, each: true),
  ScoringPattern('No Flower Tiles', 1),
  ScoringPattern('No Honors', 1),
  ScoringPattern('No Flower or Honor Tiles', 3),
  ScoringPattern('Melded Kong', 1, each: true),
  ScoringPattern('Concealed Kong', 2, each: true),
  ScoringPattern('Two Concealed Pungs', 2),
  ScoringPattern('Three Concealed Pungs', 5),
  ScoringPattern('Four Concealed Pungs', 10),
  ScoringPattern('Five Concealed Pungs', 40),
  ScoringPattern('Single Wait', 2),
  ScoringPattern('Closed Wait', 2),
  ScoringPattern('Robbing the Kong', 1),
  ScoringPattern('Last Tile Draw', 1),
  ScoringPattern('Win Within 5 Discards', 10),
  ScoringPattern('Win Within 5 to 10 Discards', 5),
  ScoringPattern('Pure Straight', 5),
  ScoringPattern('All Pungs', 10),
  ScoringPattern('All Chows', 10),
  ScoringPattern('All Chows with Flowers or Honors', 3),
  ScoringPattern('Melded Hand', 10),
  ScoringPattern('Little Three Dragons', 10),
  ScoringPattern('Big Three Dragons', 30),
  ScoringPattern('Little Three Winds', 5),
  ScoringPattern('Big Three Winds', 10),
  ScoringPattern('Little Four Winds', 30),
  ScoringPattern('Big Four Winds', 40),
  ScoringPattern('Half Flush', 10),
  ScoringPattern('Full Flush', 40),
  ScoringPattern('Seven Pairs and a Pung', 30),
  ScoringPattern('Blessings of Heaven', 40),
  ScoringPattern('Blessings of Earth', 40),
  ScoringPattern('All Flowers', 30),
];

// --- MCR ---------------------------------------------------------------------

/// The scorer's name for one melded plus one concealed kong (fan 57 at 6).
const mcrMixedKongs = 'Melded and Concealed Kongs';

/// All 81 fan from `mcrFans`, one group per point value, highest first.
List<CatalogueGroup> _mcrCatalogue() {
  final tiers = mcrFans.map((f) => f.points).toSet().toList()
    ..sort((a, b) => b.compareTo(a));
  return [
    for (final points in tiers)
      CatalogueGroup('mcr$points', ValueUnit.mcrFan, [
        for (final f in mcrFans.where((f) => f.points == points))
          ScoringPattern(f.name, f.points, each: f.id == 81),
        if (points == 6) const ScoringPattern(mcrMixedKongs, 6),
      ]),
  ];
}

// --- Sichuan -----------------------------------------------------------------

const _sichuanFan = [
  ScoringPattern('Root', 1, each: true),
  ScoringPattern('All Pungs', 1),
  ScoringPattern('Full Flush', 2),
  ScoringPattern('Seven Pairs', 2),
  ScoringPattern('Golden Single Wait', 2),
  ScoringPattern('Win after Kong', 1),
  ScoringPattern('Robbing the Kong', 1),
  ScoringPattern('Shoot after Kong', 1),
  ScoringPattern('Under the Sea', 1),
];
