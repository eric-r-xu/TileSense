/// Turns the raw shanten/ukeire calculator plus the safety model into a typed
/// report the UI renders. This replaces the tab-delimited string protocol that
/// `EfficiencyLogging.log_turn` builds in the Vala client; the analysis intent
/// (best ukeire, recommended discard, riichi hint, defensive ranking) is the
/// same.
library;

import 'efficiency_calc.dart';
import 'safety.dart';
import 'tile.dart';

class DiscardLine {
  DiscardLine({
    required this.discard,
    required this.shanten,
    required this.ukeire,
    required this.accepts,
    this.safety,
    this.bestUkeire = false,
    this.recommended = false,
  });

  final TileType discard;
  final int shanten;
  final int ukeire;
  final List<TileType> accepts;
  SafetyRating? safety;
  bool bestUkeire;
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
  final _calc = TileEfficiencyCalculator();

  /// [hand] is the 14-tile concealed hand on the player's turn (13 + draw).
  /// [visibleCounts34] counts every tile the player can see (own hand, all
  /// discards, all melds, revealed dora indicators). [openMelds] is the number
  /// of calls the player has made.
  EfficiencyReport analyze({
    required List<Tile> hand,
    required List<int> visibleCounts34,
    required int openMelds,
    required bool canRiichi,
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

    final lines = byType.values
        .map((r) => DiscardLine(
              discard: r.discard,
              shanten: r.shanten,
              ukeire: r.ukeire,
              accepts: r.accepts,
            ))
        .toList();

    // Rank: fewest shanten first, then most ukeire.
    lines.sort((a, b) {
      final s = a.shanten.compareTo(b.shanten);
      if (s != 0) return s;
      return b.ukeire.compareTo(a.ukeire);
    });

    final currentShanten =
        lines.isEmpty ? 99 : lines.map((l) => l.shanten).reduce((a, b) => a < b ? a : b);

    // Best ukeire among the lowest-shanten discards.
    DiscardLine? best;
    for (final l in lines.where((l) => l.shanten == currentShanten)) {
      if (best == null || l.ukeire > best.ukeire) best = l;
    }
    best?.bestUkeire = true;

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
    // prefer the safest discard; otherwise the best-ukeire discard.
    DiscardLine? recommended;
    if (defending && currentShanten > 0 && defense.isNotEmpty) {
      final safest = defense.first;
      recommended = lines.firstWhere(
        (l) => l.discard == safest.type,
        orElse: () => best ?? lines.first,
      );
    } else {
      recommended = best;
    }
    recommended?.recommended = true;

    final tenpai = currentShanten == 0;
    final recommendRiichi = tenpai &&
        canRiichi &&
        openMelds == 0 &&
        !opponentRiichi &&
        (best?.ukeire ?? 0) > 0;

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
              ? 'Tenpai — ${best?.ukeire ?? 0} tiles complete the hand'
              : '$currentShanten-shanten',
    );
  }
}
