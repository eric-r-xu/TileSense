/// Which mahjong rules a table plays: Japanese riichi, Hong Kong, or
/// Taiwanese.
///
/// The round, guide, bots and UI are shared. Each asks the ruleset only where
/// the games actually differ — how a hand scores, what the wall holds, which
/// declarations exist and how a game is paced — and the Hong Kong-only pieces
/// live under `hong_kong/`, the Taiwanese-only pieces under `taiwanese/`.
/// Hong Kong and Taiwanese share the same discard-based flow (flowers, no
/// riichi, no furiten, nothing callable off the last discard) — see
/// [isChineseStyle] — and differ mainly in scoring vocabulary and payment.
library;

import 'hong_kong/hong_kong_rules.dart';
import 'scoring.dart';
import 'taiwanese/taiwanese_rules.dart';

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
  ),
  taiwanese(
    label: 'Taiwanese',
    flag: '🇹🇼',
    unit: 'points',
    rulesUrl: 'https://app.ericrxu.com/static/Taiwanese.pdf',
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
  bool get isTaiwanese => this == Ruleset.taiwanese;
  bool get isRiichi => this == Ruleset.riichi;

  /// Hong Kong and Taiwanese share the same table flow: flowers exposed and
  /// replaced from the wall, no riichi, no furiten, and nothing callable off
  /// the last discard. They differ only in scoring vocabulary and payment —
  /// see `hong_kong_scoring.dart` and `taiwanese_scoring.dart`.
  bool get isChineseStyle => isHongKong || isTaiwanese;

  Ruleset get next => Ruleset.values[(index + 1) % Ruleset.values.length];

  /// Each seat's score at the start of a game.
  int get startingPoints => isHongKong
      ? HongKongRules.startingChips
      : isTaiwanese
          ? TaiwaneseRules.startingChips
          : 25000;

  /// Scheduled hands in a game: East and South (hanchan) for every ruleset.
  /// [fullGame] false is East only in every ruleset.
  int handsPerGame({required bool fullGame}) => fullGame ? 8 : 4;

  /// Melds in a complete hand, beside its pair: 4 (a 14-tile hand) for riichi
  /// and Hong Kong, 5 (17 tiles) for Taiwanese.
  int get totalMelds => isTaiwanese ? 5 : 4;

  /// Concealed tiles a closed hand holds between draws: 13, or Taiwanese's 16.
  int get concealedHandSize => totalMelds * 3 + 1;

  /// Taiwanese lays a concealed kong down with all four tiles face down, so
  /// the other seats can't see what it is until the hand ends. Riichi and
  /// Hong Kong show the middle two.
  bool get hidesConcealedKongs => isTaiwanese;

  /// Names for the calls and wins, in this game's vocabulary.
  String get chiLabel => isChineseStyle ? 'Chow' : 'Chi';
  String get ponLabel => isChineseStyle ? 'Pung' : 'Pon';
  String get kanLabel => isChineseStyle ? 'Kong' : 'Kan';
  String get ronLabel => isTaiwanese ? 'Hu' : (isHongKong ? 'Win' : 'Ron');
  String get tsumoLabel => isChineseStyle ? 'Self-pick' : 'Tsumo';

  /// A hand's distance from ready, in this game's vocabulary.
  String shapeLabel(int shanten) => isChineseStyle
      ? (shanten <= 0 ? 'ready' : '$shanten away from ready')
      : (shanten <= 0 ? 'tenpai' : '$shanten-shanten');

  /// Whether [score] is worth a character's celebratory "yeah" (and, on a
  /// ron, the discarder's resigned acquiescement) rather than just the plain
  /// win line. Riichi already has a name for this threshold — mangan+, i.e.
  /// [HandScore.limitName] is set. Hong Kong's own [HandScore.limitName]
  /// only flags the payment table's 13-faan cap, which an ordinary game
  /// essentially never reaches, so it gets its own threshold instead: 5
  /// faan, the same rough "the scale stops just doubling" position mangan
  /// (5 han) occupies among riichi hands. Taiwanese has no such cap either,
  /// and its default 5-point minimum to declare a win at all means every win
  /// there already clears that bar — so its threshold sits a tier higher, at
  /// the sheet's 10-Point patterns, the first tier that reads as a genuinely
  /// strong hand rather than just a legal one.
  bool isBigHand(HandScore score) => isTaiwanese
      ? score.han >= 10
      : isHongKong
          ? score.han >= 5
          : score.limitName.isNotEmpty;
}
