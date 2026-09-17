/// Which mahjong rules a table plays: Japanese riichi or Hong Kong.
///
/// The round, guide, bots and UI are shared. Each asks the ruleset only where
/// the two games actually differ — how a hand scores, what the wall holds,
/// which declarations exist and how a game is paced — and the Hong Kong-only
/// pieces live under `hong_kong/`.
library;

import 'hong_kong/hong_kong_rules.dart';
import 'scoring.dart';

enum Ruleset {
  riichi(
    label: 'Riichi',
    flag: '🇯🇵',
    unit: 'points',
    rulesUrl: 'https://app.ericrxu.com/static/Riichi.pdf',
  ),
  hongKong(
    label: 'Hong Kong',
    flag: '🇭🇰',
    unit: 'chips',
    rulesUrl: 'https://app.ericrxu.com/static/HK.pdf',
  );

  const Ruleset({
    required this.label,
    required this.flag,
    required this.unit,
    required this.rulesUrl,
  });

  /// Short name for prose and headers.
  final String label;

  /// The country flag shown beside [label] wherever the rules are picked.
  final String flag;

  /// [label] with its [flag] in front, for toggles.
  String get flagLabel => '$flag $label';

  /// A one-page rules reference (PDF).
  final String rulesUrl;

  /// What scores are counted in.
  final String unit;

  bool get isHongKong => this == Ruleset.hongKong;
  bool get isRiichi => this == Ruleset.riichi;

  Ruleset get next => Ruleset.values[(index + 1) % Ruleset.values.length];

  /// Each seat's score at the start of a game.
  int get startingPoints => isHongKong ? HongKongRules.startingChips : 25000;

  /// Scheduled hands in a game: riichi plays East and South (hanchan), Hong
  /// Kong all four winds. [fullGame] false is East only in both.
  int handsPerGame({required bool fullGame}) =>
      fullGame ? (isHongKong ? 16 : 8) : 4;

  /// Names for the calls and wins, in this game's vocabulary.
  String get chiLabel => isHongKong ? 'Chow' : 'Chi';
  String get ponLabel => isHongKong ? 'Pung' : 'Pon';
  String get kanLabel => isHongKong ? 'Kong' : 'Kan';
  String get ronLabel => isHongKong ? 'Win' : 'Ron';
  String get tsumoLabel => isHongKong ? 'Self-pick' : 'Tsumo';

  /// A hand's distance from ready, in this game's vocabulary.
  String shapeLabel(int shanten) => isHongKong
      ? (shanten <= 0 ? 'ready' : '$shanten away from ready')
      : (shanten <= 0 ? 'tenpai' : '$shanten-shanten');

  /// Whether [score] is worth a character's celebratory "yeah" (and, on a
  /// ron, the discarder's resigned acquiescement) rather than just the plain
  /// win line. Riichi already has a name for this threshold — mangan+, i.e.
  /// [HandScore.limitName] is set. Hong Kong's own [HandScore.limitName]
  /// only flags the payment table's 13-faan cap, which an ordinary game
  /// essentially never reaches, so it gets its own threshold here instead:
  /// 5 faan, the same rough "the scale stops just doubling" position mangan
  /// (5 han) occupies among riichi hands.
  bool isBigHand(HandScore score) =>
      isHongKong ? score.han >= 5 : score.limitName.isNotEmpty;
}
