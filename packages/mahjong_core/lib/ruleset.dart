/// Which mahjong rules a table plays: Japanese riichi, its three-player
/// variant sanma, Hong Kong, Taiwanese, MCR, or Sichuan.
///
/// The round, guide, bots and UI are shared. Each asks the ruleset only where
/// the games actually differ — how a hand scores, what the wall holds, which
/// declarations exist and how a game is paced — and the Hong Kong-only pieces
/// live under `hong_kong/`, the Taiwanese-only pieces under `taiwanese/`, the
/// Sichuan-only pieces under `sichuan/`.
/// Hong Kong and Taiwanese share the same discard-based flow (flowers, no
/// riichi, no furiten, nothing callable off the last discard) — see
/// [isChineseStyle] — and differ mainly in scoring vocabulary and payment.
library;

import 'hong_kong/hong_kong_rules.dart';
import 'scoring.dart';
import 'sanma/sanma_rules.dart';
import 'sichuan/sichuan_rules.dart';
import 'tile.dart' show Wind;
import 'taiwanese/taiwanese_rules.dart';

enum Ruleset {
  riichi(
    label: 'Riichi',
    flag: '🇯🇵',
    unit: 'points',
    rulesUrl: 'https://app.ericrxu.com/static/Riichi.pdf',
  ),
  sanma(
    label: 'Sanma',
    // Drawn from [flagAsset]: the Japanese flag with 三麻 on it, so it can be
    // told apart from four-player riichi at a glance.
    flag: '🇯🇵',
    flagAsset: 'assets/flags/sanma.png',
    unit: 'points',
    rulesUrl: 'https://riichi.wiki/Sanma',
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
  ),
  mcr(
    label: 'MCR', flag: '🇨🇳', unit: 'points',
    rulesUrl: 'https://app.ericrxu.com/static/MCR.pdf',
  ),
  sichuan(
    label: 'Sichuan',
    // No emoji: Sichuan is a province, drawn from [flagAsset]. Left empty so
    // plain-text labels read just "Sichuan".
    flag: '',
    flagAsset: 'assets/flags/sichuan.png',
    unit: 'points',
    rulesUrl: 'https://app.ericrxu.com/static/Sichuan.pdf',
  );

  const Ruleset({
    required this.label,
    required this.flag,
    required this.unit,
    required this.rulesUrl,
    this.flagAsset,
  });

  /// Short name for prose and headers.
  final String label;

  /// The country flag shown beside [label] wherever the rules are picked.
  final String flag;

  /// An image to show in place of [flag] where the UI can draw one (a Flutter
  /// asset path), for rules with no emoji flag: Sichuan is a province. [flag]
  /// stays as the text stand-in for labels, semantics and plain-text docs.
  final String? flagAsset;

  /// [label] with its [flag] in front, for toggles.
  String get flagLabel => '$flag $label'.trim();

  /// A one-page rules reference (PDF).
  final String rulesUrl;

  /// What scores are counted in.
  final String unit;

  bool get isMcr => this == Ruleset.mcr;

  bool get isHongKong => this == Ruleset.hongKong;
  bool get isTaiwanese => this == Ruleset.taiwanese;
  bool get isRiichi => this == Ruleset.riichi;
  bool get isSichuan => this == Ruleset.sichuan;

  /// Sanma: riichi for three players (see `sanma/sanma_rules.dart`).
  bool get isSanma => this == Ruleset.sanma;

  /// Japanese rules, four-player or three: riichi, furiten, dora, honba and
  /// tenpai payments. Sanma changes the table around them, not the rules.
  bool get isJapanese => isRiichi || isSanma;

  /// How many players sit at the table: 3 for sanma, 4 otherwise.
  int get playerCount => isSanma ? 3 : 4;

  /// The seat indices that are played, in turn order. Seats are numbered from
  /// your own (0) round to your left (3), so sanma leaves the seat across
  /// (2) empty and plays 0, 1 and 3: your right-hand opponent is still seat
  /// 1 and your left-hand one seat 3.
  List<int> get activeSeats =>
      isSanma ? const [0, 1, 3] : const [0, 1, 2, 3];

  /// Whether [seat] is played under these rules.
  bool seatIsActive(int seat) => !isSanma || seat != SanmaRules.emptySeat;

  /// The seat after [seat] in turn order, skipping an empty one.
  int nextSeat(int seat) {
    final n = (seat + 1) % 4;
    return seatIsActive(n) ? n : (n + 1) % 4;
  }

  /// How many turns after [from] the turn reaches [to]: 1 for the next seat
  /// to play, up to [playerCount] - 1.
  int seatDistance(int from, int to) {
    var d = 0;
    for (var s = from; s != to; s = nextSeat(s)) {
      d++;
      if (d > 4) break;
    }
    return d;
  }

  /// The wind [seat] sits in when [dealer] deals: East for the dealer, then
  /// South and West (and North, with four) in turn order.
  Wind seatWind(int seat, int dealer) =>
      Wind.values[seatDistance(dealer, seat) % 4];

  /// The seat that deals after [dealer].
  int nextDealer(int dealer) => nextSeat(dealer);

  /// [seat] as the player in seat [viewer] numbers the table, with themself
  /// as 0: an online client always sits at its own seat 0. Turn order is
  /// kept, so under sanma the player after you is 1 and the one before you
  /// is 3, and the empty seat stays across, at 2.
  int relativeSeat(int seat, int viewer) {
    if (!isSanma) return (seat - viewer + 4) % 4;
    if (!seatIsActive(seat)) return SanmaRules.emptySeat;
    final seats = activeSeats;
    final n = seats.length;
    return seats[(seats.indexOf(seat) - seats.indexOf(viewer) + n) % n];
  }

  /// The inverse of [relativeSeat]: the seat that [viewer] calls [local].
  int absoluteSeat(int local, int viewer) {
    if (!isSanma) return (local + viewer) % 4;
    if (!seatIsActive(local)) return SanmaRules.emptySeat;
    final seats = activeSeats;
    final n = seats.length;
    return seats[(seats.indexOf(local) + seats.indexOf(viewer)) % n];
  }

  /// Hong Kong and Taiwanese share the same table flow: flowers exposed and
  /// replaced from the wall, no riichi, no furiten, and nothing callable off
  /// the last discard. They differ only in scoring vocabulary and payment —
  /// see `hong_kong_scoring.dart` and `taiwanese_scoring.dart`.
  ///
  /// Sichuan shares that table flow too (no riichi, no furiten, nothing
  /// callable off the last discard) but has no flowers, and its wins do not end
  /// the hand — see `Round`'s Sichuan paths.
  bool get isChineseStyle => isHongKong || isTaiwanese || isMcr || isSichuan;

  Ruleset get next => Ruleset.values[(index + 1) % Ruleset.values.length];

  /// Each seat's score at the start of a game.
  int get startingPoints => isSanma ? SanmaRules.startingPoints : isMcr ? 0 : isSichuan ? SichuanRules.startingPoints : isHongKong
      ? HongKongRules.startingChips
      : isTaiwanese
          ? TaiwaneseRules.startingChips
          : 25000;

  /// Scheduled hands in a game: East and South (hanchan) for every ruleset
  /// but MCR, which plays all four winds. [fullGame] false is East only in
  /// every ruleset.
  /// Sanma deals three hands a wind, one per player.
  int handsPerGame({required bool fullGame}) =>
      (fullGame ? (isMcr ? 4 : 2) : 1) * playerCount;

  /// Melds in a complete hand, beside its pair: 4 (a 14-tile hand) for riichi
  /// and Hong Kong, 5 (17 tiles) for Taiwanese.
  int get totalMelds => isTaiwanese ? 5 : 4;

  /// Concealed tiles a closed hand holds between draws: 13, or Taiwanese's 16.
  int get concealedHandSize => totalMelds * 3 + 1;

  /// Taiwanese lays a concealed kong down with all four tiles face down, so
  /// the other seats can't see what it is until the hand ends. Riichi and
  /// Hong Kong show the middle two.
  bool get hidesConcealedKongs => isTaiwanese || isMcr;

  /// Names for the calls and wins, in this game's vocabulary.
  String get chiLabel => isChineseStyle ? 'Chow' : 'Chi';
  String get ponLabel => isChineseStyle ? 'Pung' : 'Pon';
  String get kanLabel => isChineseStyle ? 'Kong' : 'Kan';
  String get ronLabel => (isTaiwanese || isMcr || isSichuan) ? 'Hu' : (isHongKong ? 'Win' : 'Ron');
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
  bool isBigHand(HandScore score) => isSichuan ? score.han >= 3 : isMcr ? score.han >= 24 : isTaiwanese
      ? score.han >= 10
      : isHongKong
          ? score.han >= 5
          : score.limitName.isNotEmpty;
}
