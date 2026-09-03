/// Turns the raw shanten/ukeire calculator plus the safety model into a typed
/// report the UI renders. This replaces the tab-delimited string protocol that
/// `EfficiencyLogging.log_turn` builds in the Vala client; the analysis intent
/// (best ukeire, recommended discard, riichi hint, defensive ranking) is the
/// same.
library;

import 'dart:math' as math;

import 'efficiency_calc.dart';
import 'meld.dart';
import 'safety.dart';
import 'scoring.dart';
import 'tile.dart';

/// Round and hand-value inputs used by the discard EV model.
///
/// Ura-dora and situational yaku are deliberately omitted: they are either
/// hidden information or cannot be known for a hypothetical future win.
class EfficiencyValueContext {
  const EfficiencyValueContext({
    required this.melds,
    required this.roundWind,
    required this.seatWind,
    required this.isDealer,
    required this.inRiichi,
    required this.wallTilesRemaining,
    required this.doraIndicators,
  });

  final List<Meld> melds;
  final Wind roundWind;
  final Wind seatWind;
  final bool isDealer;
  final bool inRiichi;
  final int wallTilesRemaining;
  final List<TileType> doraIndicators;

  bool get closed => melds.every((m) => m.kind == MeldKind.kan && m.concealed);
}

class DiscardLine {
  DiscardLine({
    required this.discard,
    required this.shanten,
    required this.ukeire,
    required this.accepts,
    required this.expectedValue,
    required this.averagePoints,
    required this.valuePlan,
    required this.recommendRiichi,
    this.safety,
    this.bestUkeire = false,
    this.bestExpectedValue = false,
    this.recommended = false,
  });

  final TileType discard;
  final int shanten;
  final int ukeire;
  final List<TileType> accepts;
  final double expectedValue;
  final double averagePoints;
  final String valuePlan;
  final bool recommendRiichi;
  SafetyRating? safety;
  bool bestUkeire;
  bool bestExpectedValue;
  bool recommended;
}

class EfficiencyReport {
  EfficiencyReport({
    required this.lines,
    required this.currentShanten,
    required this.tenpai,
    required this.recommendRiichi,
    required this.defending,
    required this.defense,
    this.headline,
  });

  final List<DiscardLine> lines;
  final int currentShanten;
  final bool tenpai;
  final bool recommendRiichi;
  final bool defending;
  final List<SafetyRating> defense;
  final String? headline;

  static EfficiencyReport waiting() => EfficiencyReport(
        lines: const [],
        currentShanten: 99,
        tenpai: false,
        recommendRiichi: false,
        defending: false,
        defense: const [],
        headline: 'Waiting for your turn…',
      );
}

class EfficiencyEngine {
  static const _damatenMinPoints = 5200;
  static const _dealerDamatenMinPoints = 7700;

  final _calc = TileEfficiencyCalculator();

  /// [hand] is the 14-tile concealed hand on the player's turn (13 + draw).
  /// [visibleCounts34] counts every tile the player can see (own hand, all
  /// discards, all melds, revealed dora indicators).
  EfficiencyReport analyze({
    required List<Tile> hand,
    required List<int> visibleCounts34,
    required bool canRiichi,
    required EfficiencyValueContext valueContext,
    List<Tile>? defenseHand,
    List<TileType> opponentDiscards = const [],
    List<TileType> allDiscards = const [],
    bool opponentRiichi = false,
  }) {
    final remaining34 = [for (var i = 0; i < 34; i++) 4 - visibleCounts34[i]];
    final concealed = toTrainerCounts(hand);
    final remaining = trainerCountsFromTypeCounts(remaining34);

    final raw = _calc.calculate(concealed, remaining);

    // Deduplicate by tile type (multiple copies of the same tile in hand).
    final byType = <TileType, TileEfficiencyResult>{};
    for (final r in raw) {
      final t = r.discard;
      final existing = byType[t];
      if (existing == null || r.ukeire > existing.ukeire) byType[t] = r;
    }

    final lines = byType.values.map((r) {
      final afterDiscard = _handAfterDiscard(hand, r.discard);
      final value = _assessValue(
        result: r,
        remaining: remaining,
        concealed: afterDiscard,
        canRiichi: canRiichi,
        context: valueContext,
      );
      return DiscardLine(
        discard: r.discard,
        shanten: r.shanten,
        ukeire: r.ukeire,
        accepts: r.accepts,
        expectedValue: value.expectedValue,
        averagePoints: value.averagePoints,
        valuePlan: value.plan,
        recommendRiichi: value.recommendRiichi,
      );
    }).toList();

    // Rank by probability-weighted points, then use shape to break ties.
    lines.sort((a, b) {
      final ev = b.expectedValue.compareTo(a.expectedValue);
      if (ev != 0) return ev;
      final s = a.shanten.compareTo(b.shanten);
      if (s != 0) return s;
      return b.ukeire.compareTo(a.ukeire);
    });

    final currentShanten = lines.isEmpty
        ? 99
        : lines.map((l) => l.shanten).reduce((a, b) => a < b ? a : b);

    // Best ukeire among the lowest-shanten discards.
    DiscardLine? bestEfficiency;
    for (final l in lines.where((l) => l.shanten == currentShanten)) {
      if (bestEfficiency == null ||
          l.ukeire > bestEfficiency.ukeire ||
          (l.ukeire == bestEfficiency.ukeire &&
              l.expectedValue > bestEfficiency.expectedValue)) {
        bestEfficiency = l;
      }
    }
    bestEfficiency?.bestUkeire = true;

    final bestValue = lines.isEmpty ? null : lines.first;
    bestValue?.bestExpectedValue = true;

    final defending = opponentRiichi && defenseHand != null;
    var defense = <SafetyRating>[];
    if (defending) {
      defense = rankSafety(
        defenseHand,
        opponentDiscards: opponentDiscards,
        allDiscards: allDiscards,
        visibleCounts34: visibleCounts34,
      );
      final safeByType = {for (final s in defense) s.type: s};
      for (final l in lines) {
        l.safety = safeByType[l.discard];
      }
    }

    // Recommendation: while defending against riichi and not already tenpai,
    // prefer the safest discard; otherwise the best expected-value discard.
    DiscardLine? recommended;
    if (defending && currentShanten > 0 && defense.isNotEmpty) {
      final safest = defense.first;
      recommended = lines.firstWhere(
        (l) => l.discard == safest.type,
        orElse: () => bestValue ?? lines.first,
      );
    } else {
      recommended = bestValue;
    }
    recommended?.recommended = true;

    final tenpai = currentShanten == 0;
    final recommendRiichi =
        tenpai && !opponentRiichi && (recommended?.recommendRiichi ?? false);

    return EfficiencyReport(
      lines: lines,
      currentShanten: currentShanten,
      tenpai: tenpai,
      recommendRiichi: recommendRiichi,
      defending: defending,
      defense: defense,
      headline: defending
          ? 'An opponent is in RIICHI — defensive ranking shown'
          : tenpai
              ? 'Tenpai — best EV ${bestValue?.expectedValue.round() ?? 0} pts'
              : '$currentShanten-shanten',
    );
  }

  _ValueAssessment _assessValue({
    required TileEfficiencyResult result,
    required List<int> remaining,
    required List<Tile> concealed,
    required bool canRiichi,
    required EfficiencyValueContext context,
  }) {
    // A normal discard analysis starts with 14 tiles including open melds.
    // Off-turn defensive reads can have only 13, so avoid pretending those
    // incomplete states can be scored as winning hands.
    final completeTurnTileCount =
        concealed.length + context.melds.length * 3 == 13;
    if (!completeTurnTileCount) {
      return const _ValueAssessment(plan: 'DEFENSE');
    }

    if (result.shanten == 0) {
      return _assessTenpaiValue(
        waits: result.accepts,
        remaining: remaining,
        concealed: concealed,
        canRiichi: canRiichi,
        context: context,
      );
    }

    final yakuPath = context.closed || _hasOpenYakuPath(concealed, context);
    if (!yakuPath) return const _ValueAssessment(plan: 'YAKU NEEDED');

    final unseen = _countRemaining(remaining);
    final draws = math.max(1, (context.wallTilesRemaining + 3) ~/ 4);
    final improveRate =
        unseen > 0 ? math.min(1.0, result.ukeire / unseen) : 0.0;
    final improveProbability = 1 - math.pow(1 - improveRate, draws).toDouble();
    final completionProbability =
        math.pow(improveProbability, result.shanten + 1).toDouble();

    // Before tenpai the exact final hand is unknown. These representative
    // values match the desktop advisor; exact yaku/fu/dora scoring takes over
    // as soon as a discard leaves the hand in tenpai.
    final projectedPoints = context.closed
        ? (context.isDealer ? 5800.0 : 3900.0)
        : (context.isDealer ? 2900.0 : 2000.0);
    return _ValueAssessment(
      expectedValue: completionProbability * projectedPoints,
      averagePoints: projectedPoints,
      plan: context.closed ? 'RIICHI PATH' : 'YAKU PATH',
    );
  }

  _ValueAssessment _assessTenpaiValue({
    required List<TileType> waits,
    required List<int> remaining,
    required List<Tile> concealed,
    required bool canRiichi,
    required EfficiencyValueContext context,
  }) {
    var liveWaits = 0;
    var damaPoints = 0.0;
    var riichiPoints = 0.0;
    var everyDamaRon = true;
    var anyDamaRon = false;
    var anyDamaTsumo = false;
    var minimumDamaRon = 1 << 30;

    final riichiAvailable = (canRiichi || context.inRiichi) && context.closed;
    for (final wait in waits) {
      final copies = remaining[trainerIndexOf(wait)];
      if (copies <= 0) continue;

      final winTile = Tile(-1000 - wait.index, wait);
      final damaRon = _scoreWait(
        concealed,
        winTile,
        isTsumo: false,
        assumeRiichi: false,
        context: context,
      );
      final damaTsumo = _scoreWait(
        concealed,
        winTile,
        isTsumo: true,
        assumeRiichi: false,
        context: context,
      );
      final damaRonPoints = damaRon.valid ? damaRon.points : 0;
      final damaTsumoPoints = damaTsumo.valid ? damaTsumo.points : 0;
      if (damaRonPoints == 0) {
        everyDamaRon = false;
      } else {
        anyDamaRon = true;
        minimumDamaRon = math.min(minimumDamaRon, damaRonPoints);
      }
      if (damaTsumoPoints > 0) anyDamaTsumo = true;
      damaPoints += copies * (0.65 * damaRonPoints + 0.35 * damaTsumoPoints);

      if (riichiAvailable) {
        final riichiRon = _scoreWait(
          concealed,
          winTile,
          isTsumo: false,
          assumeRiichi: true,
          context: context,
        );
        final riichiTsumo = _scoreWait(
          concealed,
          winTile,
          isTsumo: true,
          assumeRiichi: true,
          context: context,
        );
        riichiPoints += copies *
            (0.65 * (riichiRon.valid ? riichiRon.points : 0) +
                0.35 * (riichiTsumo.valid ? riichiTsumo.points : 0));
      }
      liveWaits += copies;
    }

    if (liveWaits == 0) return const _ValueAssessment(plan: 'DEAD WAIT');

    damaPoints /= liveWaits;
    riichiPoints /= liveWaits;
    final damatenMinimum =
        context.isDealer ? _dealerDamatenMinPoints : _damatenMinPoints;
    final qualifyingDamaten = everyDamaRon && minimumDamaRon >= damatenMinimum;

    late final String plan;
    late final double selectedPoints;
    late final bool ronAvailable;
    var recommendRiichi = false;
    if (context.inRiichi) {
      plan = 'RIICHI';
      selectedPoints = riichiPoints;
      ronAvailable = true;
    } else if (qualifyingDamaten) {
      plan = 'DAMATEN';
      selectedPoints = damaPoints;
      ronAvailable = true;
    } else if (riichiAvailable) {
      plan = 'RIICHI';
      selectedPoints = riichiPoints;
      ronAvailable = true;
      recommendRiichi = true;
    } else if (everyDamaRon) {
      plan = context.closed ? 'DAMATEN' : 'OPEN YAKU';
      selectedPoints = damaPoints;
      ronAvailable = true;
    } else if (anyDamaRon) {
      plan = 'PARTIAL YAKU';
      selectedPoints = damaPoints;
      ronAvailable = true;
    } else if (anyDamaTsumo) {
      plan = 'TSUMO ONLY';
      selectedPoints = damaPoints;
      ronAvailable = false;
    } else {
      return const _ValueAssessment(plan: 'NO YAKU');
    }

    final unseen = _countRemaining(remaining);
    final draws = math.max(1, (context.wallTilesRemaining + 3) ~/ 4);
    final opportunities = draws * (ronAvailable ? 2.0 : 1.0);
    final hitRate = unseen > 0 ? math.min(1.0, liveWaits / unseen) : 0.0;
    final winProbability = 1 - math.pow(1 - hitRate, opportunities).toDouble();
    var expectedValue = winProbability * selectedPoints;
    if (recommendRiichi) expectedValue -= (1 - winProbability) * 1000;

    return _ValueAssessment(
      expectedValue: expectedValue,
      averagePoints: selectedPoints,
      plan: plan,
      recommendRiichi: recommendRiichi,
    );
  }

  HandScore _scoreWait(
    List<Tile> concealed,
    Tile winTile, {
    required bool isTsumo,
    required bool assumeRiichi,
    required EfficiencyValueContext context,
  }) {
    final akaCount = [...concealed, winTile].where((tile) => tile.aka).length +
        context.melds
            .expand((meld) => meld.tiles)
            .where((tile) => tile.aka)
            .length;
    final scoreContext = ScoreContext(
      roundWind: context.roundWind,
      seatWind: context.seatWind,
      isTsumo: isTsumo,
      closed: context.closed,
      riichi: assumeRiichi,
      doraIndicators: context.doraIndicators,
      akaCount: akaCount,
    );
    return scoreHand(
      concealed,
      winTile,
      context.melds,
      scoreContext,
      isDealer: context.isDealer,
    );
  }

  static List<Tile> _handAfterDiscard(List<Tile> hand, TileType discard) {
    final copy = List<Tile>.of(hand);
    var index = copy.indexWhere((tile) => tile.type == discard && !tile.aka);
    if (index < 0) index = copy.indexWhere((tile) => tile.type == discard);
    if (index >= 0) copy.removeAt(index);
    return copy;
  }

  static int _countRemaining(List<int> remaining) =>
      remaining.fold(0, (sum, copies) => sum + copies);

  static bool _hasOpenYakuPath(
    List<Tile> concealed,
    EfficiencyValueContext context,
  ) {
    final all = <TileType>[
      ...concealed.map((tile) => tile.type),
      ...context.melds.expand((meld) => meld.types),
    ];
    if (all.isEmpty) return false;

    final allSimples = all.every((tile) => !tile.isTerminalOrHonor);
    final terminalsAndHonors = all.every((tile) => tile.isTerminalOrHonor);
    final suited = all.where((tile) => !tile.isHonor).toList();
    final oneSuit = suited.isNotEmpty &&
        suited.every((tile) => tile.suit == suited.first.suit);
    if (allSimples || terminalsAndHonors || oneSuit) return true;

    return context.melds.any((meld) =>
        meld.isTripletLike &&
        (meld.low.isDragon ||
            meld.low == context.seatWind.tile ||
            meld.low == context.roundWind.tile));
  }
}

class _ValueAssessment {
  const _ValueAssessment({
    this.expectedValue = 0,
    this.averagePoints = 0,
    required this.plan,
    this.recommendRiichi = false,
  });

  final double expectedValue;
  final double averagePoints;
  final String plan;
  final bool recommendRiichi;
}
