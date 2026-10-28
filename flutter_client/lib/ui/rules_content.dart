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
import 'package:mahjong_core/tile.dart';

import '../l10n/l10n.dart';
import '../l10n/mahjong_terms.dart';
import 'rules_text.dart';

class RuleEntry {
  const RuleEntry(this.name, this.value, this.note,
      {this.alias = '', this.example = ''});

  final String name;
  final String value;
  final String note;

  /// Tiles that show the pattern, in [parseExample] notation; empty for a
  /// pattern about when or how the hand wins rather than what it holds.
  final String example;

  /// The pattern's English name, so a search in English still finds it when
  /// the reader is in another language. Not shown.
  final String alias;

  bool matches(String query) =>
      '$name $value $note $alias'.toLowerCase().contains(query);
}

class RuleSection {
  const RuleSection(this.id, this.title, this.points,
      {this.entries = const [], this.nameHeading, this.valueHeading});

  final String id;
  final String title;

  /// Column headings for [entries] when this section's table is not a
  /// pattern catalogue (furiten types, minimums); [RulesText] supplies the
  /// catalogue's own.
  final String? nameHeading;
  final String? valueHeading;

  /// One sentence each: a lone point reads as a paragraph, several as bullets.
  final List<String> points;
  final List<RuleEntry> entries;

  String get body => points.join(' ');

  bool matches(String query) => filtered(query) != null;

  /// This section as a search for [query] shows it: whole when its title or
  /// text matches, cut down to the matching entries when only they do, and
  /// null when nothing does.
  RuleSection? filtered(String query) {
    if ('$title $body'.toLowerCase().contains(query)) return this;
    final hits = entries.where((e) => e.matches(query)).toList();
    return hits.isEmpty
        ? null
        : RuleSection(id, title, points,
            entries: hits,
            nameHeading: nameHeading,
            valueHeading: valueHeading);
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
      this.ownName = false,
      this.example = ''});

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

  /// See [RuleEntry.example].
  final String example;
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
              example: p.example,
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

// --- Examples ----------------------------------------------------------------

/// The tiles in one example set: `123m` is a run of characters (m), dots (p)
/// or bamboo (s), with 0 for a red five; `EEE` is honours by their codes
/// (E S W N winds, B G R dragons); `F12` and `S12` are flowers and seasons.
/// Sets are separated by spaces, and `→` marks an indicator and its dora.
List<Tile> exampleSet(String set) {
  final suited = RegExp(r'^(\d+)([mps])$').firstMatch(set);
  if (suited != null) {
    final suit = suited[2];
    return [
      for (final d in suited[1]!.split(''))
        Tile(0, _byCode['${d == '0' ? '5' : d}$suit']!, aka: d == '0')
    ];
  }
  final bonus = RegExp(r'^([FS])([1-4]+)$').firstMatch(set);
  if (bonus != null) {
    return [
      for (final d in bonus[2]!.split('')) Tile(0, _byCode['${bonus[1]}$d']!)
    ];
  }
  return [for (final c in set.split('')) Tile(0, _byCode[c]!)];
}

final _byCode = {
  for (final t in TileType.values)
    if (t != TileType.blank) t.code: t
};

// Hands more than one variant uses.
const _kokushi = '19m 19p 19s ESWNBGR R';
const _nineGates = '1112345678999m 5m';
const _sevenPairs = '11m 33m 55p 77p 22s 66s EE';
const _halfFlush = '123p 456p 777p WWW GG';
const _fullFlush = '123s 345s 678s 999s 55s';
const _allTriplets = '222m 777p 444s NNN 99s';
const _allSequences = '123m 456p 678p 234s 99s';
const _allSimples = '234m 567p 345s 888s 66p';
const _outside = '123m 789p 999s EEE RR';
const _terminalsHonours = '111m 999p 111s EEE GG';
const _terminals = '111m 999m 111p 999s 99p';
const _honours = 'EEE SSS BBB RRR NN';
const _allGreen = '234s 666s 888s GGG 22s';
const _pureStraight = '123p 456p 789p';
const _smallDragons = 'BBB GGG RR';
const _bigDragons = 'BBB GGG RRR';
const _smallWinds = 'EEE SSS WWW NN';
const _bigWinds = 'EEE SSS WWW NNN';
const _kong = '6666m';
const _twoKongs = '2222m 7777p';

// --- Riichi and Sanma --------------------------------------------------------

List<CatalogueGroup> _riichiCatalogue(bool sanma) => [
      CatalogueGroup('yaku', ValueUnit.han, [
        const ScoringPattern('Riichi', 1, closedOnly: true),
        const ScoringPattern('Double Riichi', 2, closedOnly: true),
        const ScoringPattern('Ippatsu', 1, closedOnly: true),
        const ScoringPattern('Menzen Tsumo', 1, closedOnly: true),
        const ScoringPattern('Pinfu', 1,
            closedOnly: true, example: '234m 567m 345p 678s 99p'),
        const ScoringPattern('Iipeiko', 1,
            closedOnly: true, example: '234m 234m'),
        const ScoringPattern('Haitei Raoyue', 1),
        const ScoringPattern('Houtei Raoyui', 1),
        const ScoringPattern('Rinshan Kaihou', 1),
        const ScoringPattern('Chankan', 1),
        const ScoringPattern('Tanyao', 1, example: _allSimples),
        const ScoringPattern('yakuhaiDragon', 1,
            each: true, ownName: true, example: 'RRR'),
        const ScoringPattern('Round Wind', 1, each: true, example: 'EEE'),
        const ScoringPattern('Seat Wind', 1, each: true, example: 'SSS'),
        if (!sanma)
          const ScoringPattern('Sanshoku Doujun', 2,
              open: 1, example: '345m 345p 345s'),
        const ScoringPattern('Ittsu', 2, open: 1, example: _pureStraight),
        const ScoringPattern('Chanta', 2, open: 1, example: _outside),
        const ScoringPattern('Chiitoitsu', 2,
            closedOnly: true, example: _sevenPairs),
        const ScoringPattern('Toitoi', 2, example: _allTriplets),
        const ScoringPattern('Sanankou', 2, example: '222m 777p 444s'),
        const ScoringPattern('Sanshoku Doukou', 2, example: '777m 777p 777s'),
        const ScoringPattern('Sankantsu', 2, example: '2222m 7777p 4444s'),
        const ScoringPattern('Honroutou', 2, example: _terminalsHonours),
        const ScoringPattern('Shousangen', 2, example: _smallDragons),
        const ScoringPattern('Junchan', 3,
            open: 2, example: '123m 789m 789p 111s 99s'),
        const ScoringPattern('Honitsu', 3, open: 2, example: _halfFlush),
        const ScoringPattern('Ryanpeikou', 3,
            closedOnly: true, example: '234m 234m 678p 678p 55s'),
        const ScoringPattern('Chinitsu', 6, open: 5, example: _fullFlush),
      ]),
      const CatalogueGroup('yakuman', ValueUnit.han, [
        ScoringPattern('Kokushi Musou', 0, yakuman: 1, example: _kokushi),
        ScoringPattern('Suuankou', 0, yakuman: 1, example: _allTriplets),
        ScoringPattern('Daisangen', 0, yakuman: 1, example: _bigDragons),
        ScoringPattern('Shousuushii', 0, yakuman: 1, example: _smallWinds),
        ScoringPattern('Daisuushii', 0, yakuman: 2, example: _bigWinds),
        ScoringPattern('Tsuuiisou', 0, yakuman: 1, example: _honours),
        ScoringPattern('Chinroutou', 0, yakuman: 1, example: _terminals),
        ScoringPattern('Ryuuiisou', 0, yakuman: 1, example: _allGreen),
        ScoringPattern('Chuuren Poutou', 0, yakuman: 1, example: _nineGates),
      ]),
      CatalogueGroup('dora', ValueUnit.han, [
        const ScoringPattern('Dora', 1, each: true, example: '4m → 5m'),
        const ScoringPattern('Ura Dora', 1, each: true, example: 'G → R'),
        const ScoringPattern('Aka Dora', 1, each: true, example: '0m 0p 0s'),
        if (sanma) const ScoringPattern('Kita', 1, each: true, example: 'N'),
      ]),
      const CatalogueGroup('fu', ValueUnit.fu, names: NameSource.reader, [
        ScoringPattern('fuBase', 20),
        ScoringPattern('fuClosedRon', 10),
        ScoringPattern('fuTsumo', 2),
        ScoringPattern('fuPinfu', 30),
        ScoringPattern('fuChiitoitsu', 25),
        ScoringPattern('fuOpenSimpleTriplet', 2, example: '555p'),
        ScoringPattern('fuClosedSimpleTriplet', 4, example: '333s'),
        ScoringPattern('fuOpenHonorTriplet', 4, example: '111s'),
        ScoringPattern('fuClosedHonorTriplet', 8, example: 'WWW'),
        ScoringPattern('fuKan', 0, example: '8888s'),
        ScoringPattern('fuValuePair', 2, example: 'RR'),
        ScoringPattern('fuWait', 2, example: '46p'),
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
  ScoringPattern('All Sequences', 1, example: _allSequences),
  ScoringPattern('All Triplets', 3, example: _allTriplets),
  ScoringPattern('All Concealed Triplets', 8, example: _allTriplets),
  ScoringPattern('All Quadruplets', 13, example: '2222m 7777p 4444s NNNN 99s'),
  ScoringPattern('hkDragonPung', 1, each: true, ownName: true, example: 'GGG'),
  ScoringPattern('Small Three Dragons', 5, example: _smallDragons),
  ScoringPattern('Big Three Dragons', 8, example: _bigDragons),
  ScoringPattern('Seat Wind', 1, example: 'SSS'),
  ScoringPattern('Round Wind', 1, example: 'EEE'),
  ScoringPattern('Small Four Winds', 6, example: _smallWinds),
  ScoringPattern('Big Four Winds', 13, example: _bigWinds),
  ScoringPattern('Mixed Flush', 3, example: _halfFlush),
  ScoringPattern('Full Flush', 7, example: _fullFlush),
  ScoringPattern('Mixed Terminals', 4, example: _terminalsHonours),
  ScoringPattern('All Terminals', 13, example: _terminals),
  ScoringPattern('All Honours', 10, example: _honours),
  ScoringPattern('Seven Pairs', 4, example: _sevenPairs),
  ScoringPattern('Nine Gates', 13, example: _nineGates),
  ScoringPattern('Thirteen Orphans', 13, example: _kokushi),
  ScoringPattern('Blessing of Heaven', 13),
  ScoringPattern('Blessing of Earth', 13),
  ScoringPattern('Blessing of Man', 13),
  ScoringPattern('No Flowers or Seasons', 1),
  ScoringPattern('hkSeatFlower', 1,
      each: true, ownName: true, example: 'F1 S1'),
  ScoringPattern('All Flowers', 2, example: 'F1234'),
  ScoringPattern('All Seasons', 2, example: 'S1234'),
  ScoringPattern('Seven Flowers', 3, example: 'F1234 S123'),
  ScoringPattern('Eight Flowers', 8, example: 'F1234 S1234'),
  ScoringPattern('Chicken Hand', 0, example: '123m 456p 777s 678p 99s'),
];

// --- Taiwanese ---------------------------------------------------------------

const _taiwaneseTai = [
  ScoringPattern('Self-Drawn', 1),
  ScoringPattern('Concealed Hand', 1),
  ScoringPattern('Fully Concealed Hand', 3),
  ScoringPattern('Value Honor', 1, each: true, example: 'RRR'),
  ScoringPattern('Flower Tile', 1, each: true, example: 'F3'),
  ScoringPattern('No Flower Tiles', 1),
  ScoringPattern('No Honors', 1),
  ScoringPattern('No Flower or Honor Tiles', 3),
  ScoringPattern('Melded Kong', 1, each: true, example: _kong),
  ScoringPattern('Concealed Kong', 2, each: true, example: _kong),
  ScoringPattern('Two Concealed Pungs', 2, example: '222m 777p'),
  ScoringPattern('Three Concealed Pungs', 5, example: '222m 777p 444s'),
  ScoringPattern('Four Concealed Pungs', 10, example: '222m 777p 444s NNN'),
  ScoringPattern('Five Concealed Pungs', 40,
      example: '222m 777p 444s NNN 999s'),
  ScoringPattern('Single Wait', 2),
  ScoringPattern('Closed Wait', 2, example: '46p'),
  ScoringPattern('Robbing the Kong', 1),
  ScoringPattern('Last Tile Draw', 1),
  ScoringPattern('Win Within 5 Discards', 10),
  ScoringPattern('Win Within 5 to 10 Discards', 5),
  ScoringPattern('Pure Straight', 5, example: _pureStraight),
  ScoringPattern('All Pungs', 10, example: '222m 777p 444s NNN 999s 55m'),
  ScoringPattern('All Chows', 10, example: '123m 456m 345p 678p 234s 99s'),
  ScoringPattern('All Chows with Flowers or Honors', 3,
      example: '123m 456m 345p 678p 234s RR'),
  ScoringPattern('Melded Hand', 10),
  ScoringPattern('Little Three Dragons', 10, example: _smallDragons),
  ScoringPattern('Big Three Dragons', 30, example: _bigDragons),
  ScoringPattern('Little Three Winds', 5, example: 'EEE SSS WW'),
  ScoringPattern('Big Three Winds', 10, example: 'EEE SSS WWW'),
  ScoringPattern('Little Four Winds', 30, example: _smallWinds),
  ScoringPattern('Big Four Winds', 40, example: _bigWinds),
  ScoringPattern('Half Flush', 10, example: '123p 456p 777p 789p WWW GG'),
  ScoringPattern('Full Flush', 40, example: '123s 345s 678s 999s 234s 55s'),
  ScoringPattern('Seven Pairs and a Pung', 30,
      example: '11m 33m 55p 77p 22s 66s EE 999s'),
  ScoringPattern('Blessings of Heaven', 40),
  ScoringPattern('Blessings of Earth', 40),
  ScoringPattern('All Flowers', 30, example: 'F1234 S1234'),
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
          ScoringPattern(f.name, f.points,
              each: f.id == 81, example: _mcrExamples[f.name] ?? ''),
        if (points == 6)
          const ScoringPattern(mcrMixedKongs, 6, example: _twoKongs),
      ]),
  ];
}

const _mcrExamples = {
  'Big Four Winds': _bigWinds,
  'Big Three Dragons': _bigDragons,
  'All Green': _allGreen,
  'Nine Gates': _nineGates,
  'Four Kongs': '2222m 7777p 4444s NNNN',
  'Seven Shifted Pairs': '22m 33m 44m 55m 66m 77m 88m',
  'Thirteen Orphans': _kokushi,
  'All Terminals': _terminals,
  'Little Four Winds': _smallWinds,
  'Little Three Dragons': _smallDragons,
  'All Honors': _honours,
  'Four Concealed Pungs': '222m 777p 444s NNN',
  'Pure Terminal Chows': '123m 123m 789m 789m 55m',
  'Quadruple Chow': '345p 345p 345p 345p',
  'Four Pure Shifted Pungs': '333s 444s 555s 666s',
  'Four Shifted Chows': '123m 234m 345m 456m',
  'Three Kongs': '2222m 7777p 4444s',
  'All Terminals and Honors': _terminalsHonours,
  'Seven Pairs': _sevenPairs,
  'Greater Honors and Knitted Tiles': '147m 258p 3s ESWNBGR',
  'All Even Pungs': '222m 444p 666s 888s 44m',
  'Full Flush': _fullFlush,
  'Pure Triple Chow': '456m 456m 456m',
  'Pure Shifted Pungs': '333s 444s 555s',
  'Upper Tiles': '789m 789p 777s 888s 99m',
  'Middle Tiles': '456m 456p 456s 444s 55m',
  'Lower Tiles': '123m 123p 123s 111s 22m',
  'Pure Straight': _pureStraight,
  'Three-Suited Terminal Chows': '123m 789m 123p 789p 55s',
  'Pure Shifted Chows': '123m 234m 345m',
  'All Fives': '345m 456p 555s 567s 55p',
  'Triple Pung': '777m 777p 777s',
  'Three Concealed Pungs': '222m 777p 444s',
  'Lesser Honors and Knitted Tiles': '147m 258p 369s ESWNB',
  'Knitted Straight': '147m 258p 369s EEE GG',
  'Upper Four': '678m 789p 666s 789s 99m',
  'Lower Four': '123m 234p 444s 123s 11m',
  'Big Three Winds': 'EEE SSS WWW',
  'Mixed Straight': '123m 456p 789s',
  'Reversible Tiles': '123p 345p 888s 456s BB',
  'Mixed Triple Chow': '345m 345p 345s',
  'Mixed Shifted Pungs': '333m 444p 555s',
  'Two Concealed Kongs': _twoKongs,
  'All Pungs': _allTriplets,
  'Half Flush': _halfFlush,
  'Mixed Shifted Chows': '123m 234p 345s',
  'All Types': '123m 456p 789s EEE RR',
  'Two Dragon Pungs': 'GGG RRR',
  'Outside Hand': _outside,
  'Two Melded Kongs': _twoKongs,
  'Dragon Pung': 'GGG',
  'Prevalent Wind': 'EEE',
  'Seat Wind': 'SSS',
  'All Chows': _allSequences,
  'Tile Hog': '234m 444m',
  'Double Pung': '777m 777p',
  'Two Concealed Pungs': '222m 777p',
  'Concealed Kong': _kong,
  'All Simples': _allSimples,
  'Pure Double Chow': '234m 234m',
  'Mixed Double Chow': '234m 234p',
  'Short Straight': '123s 456s',
  'Two Terminal Chows': '123m 789m',
  'Pung of Terminals or Honors': '999p',
  'Melded Kong': _kong,
  'One Voided Suit': '123m 456m 678p 777p 99m',
  'Edge Wait': '12m',
  'Closed Wait': '46p',
  'Flower Tiles': 'F1',
};

// --- Sichuan -----------------------------------------------------------------

const _sichuanFan = [
  ScoringPattern('Root', 1, each: true, example: '5555p'),
  ScoringPattern('All Pungs', 1, example: '222m 777m 444p 999p 55m'),
  ScoringPattern('Full Flush', 2, example: _fullFlush),
  ScoringPattern('Seven Pairs', 2, example: '11m 33m 55m 77p 22p 66p 99p'),
  ScoringPattern('Golden Single Wait', 2),
  ScoringPattern('Win after Kong', 1),
  ScoringPattern('Robbing the Kong', 1),
  ScoringPattern('Shoot after Kong', 1),
  ScoringPattern('Under the Sea', 1),
];
