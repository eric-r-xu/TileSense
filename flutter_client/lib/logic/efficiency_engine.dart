/// Turns the raw shanten/ukeire calculator plus the safety model into the typed
/// report the UI renders: best ukeire, recommended discard, riichi hint, and
/// defensive ranking.
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

/// An action the guide can weigh up — call offers (chi/pon/kan/ron) and the
/// own-turn decisions (tsumo, concealed kan) alike.
enum GuidedAction { pass, chi, pon, kan, ron, tsumo }

/// One evaluated action, with the numbers that justify it.
class ActionAdvice {
  const ActionAdvice({
    required this.action,
    required this.expectedValue,
    required this.shantenAfter,
    required this.reason,
    this.eligible = true,
    this.meldLow,
    this.discardAfter,
    this.discardSafety,
  });

  final GuidedAction action;

  /// Probability-weighted points for the hand once this action is taken. For a
  /// winning action this is the hand's actual score.
  final double expectedValue;

  /// Shanten the hand sits at after taking this action and discarding: -1 for
  /// a win, 99 when the action leaves nothing playable.
  final int shantenAfter;

  /// Plain-English justification, shown in the guide panel.
  final String reason;

  /// False when a hard rule rules this out regardless of [expectedValue] — no
  /// shanten progress, no yaku to finish on, or folding under a riichi.
  final bool eligible;

  /// For a chi, the lowest tile of the run the guide picked — several runs can
  /// often be made with the same discard, so the caller has to know which.
  final TileType? meldLow;

  /// The tile the guide would discard after making this call.
  final TileType? discardAfter;

  /// How safe [discardAfter] is, when an opponent is in riichi.
  final SafetyRating? discardSafety;
}

/// The guide's verdict on a pending call, with everything it considered.
class CallAdvice {
  const CallAdvice({required this.recommended, required this.options});

  final GuidedAction recommended;

  /// Every evaluated action, best first, always including [GuidedAction.pass].
  final List<ActionAdvice> options;

  ActionAdvice get best => options.first;

  ActionAdvice? forAction(GuidedAction action) {
    for (final option in options) {
      if (option.action == action) return option;
    }
    return null;
  }

  /// The recommendation's own rationale.
  String get reason => forAction(recommended)?.reason ?? '';
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

  // --- call and turn advice ----------------------------------------------

  /// Should the hand take a call that is on offer, and why?
  ///
  /// [hand] is the seat's 13 concealed tiles; [offered] is the discard on the
  /// table and is *not* part of it. [available] is what the rules currently
  /// permit — anything else is ignored.
  ///
  /// Every option is scored the same way: the state it leaves you in once the
  /// dust settles (13 tiles' worth of hand, plus melds) run through the same
  /// expected-value model the discard table uses. That makes "call" and "don't
  /// call" directly comparable instead of a matter of taste. On top of the
  /// numbers sit three hard rules a call has to clear: it must actually
  /// advance the hand, it must leave a yaku to finish on, and it must not be
  /// an act of committing while a riichi is out and you are still behind.
  CallAdvice adviseCall({
    required List<Tile> hand,
    required Tile offered,
    required Set<GuidedAction> available,
    required List<int> visibleCounts34,
    required EfficiencyValueContext context,
    List<TileType> opponentDiscards = const [],
    List<TileType> allDiscards = const [],
    bool opponentRiichi = false,
  }) {
    final remaining34 = [for (var i = 0; i < 34; i++) 4 - visibleCounts34[i]];
    final remaining = trainerCountsFromTypeCounts(remaining34);

    // A win on offer ends the discussion: points now beat any hand you might
    // still build, and passing a winning tile puts you in furiten.
    if (available.contains(GuidedAction.ron)) {
      final score = _scoreWait(hand, offered,
          isTsumo: false, assumeRiichi: context.inRiichi, context: context);
      final points = score.valid ? score.points : 0;
      return CallAdvice(
        recommended: GuidedAction.ron,
        options: [
          ActionAdvice(
            action: GuidedAction.ron,
            expectedValue: points.toDouble(),
            shantenAfter: -1,
            reason: 'Ron — $points points banked now, and passing up a winning '
                'tile would leave you furiten.',
          ),
        ],
      );
    }

    final passState = _evaluateWaitingHand(
      concealed: hand,
      remaining: remaining,
      context: context,
      // A closed hand that is already tenpai can still riichi on its own turn,
      // so the do-nothing baseline is allowed to price that in.
      canRiichi: context.closed && !context.inRiichi,
    );
    final pass = ActionAdvice(
      action: GuidedAction.pass,
      expectedValue: passState.ev,
      shantenAfter: passState.shanten,
      reason: passState.shanten <= 0
          ? 'Stay as you are — already tenpai, worth about '
              '${passState.ev.round()} points.'
          : 'Stay closed at ${passState.shanten}-shanten, worth about '
              '${passState.ev.round()} points as things stand.',
    );

    final options = <ActionAdvice>[pass];

    if (available.contains(GuidedAction.pon)) {
      final consumed = _takeFromHand(hand, offered.type, 2);
      if (consumed.length == 2) {
        options.add(_meldCallAdvice(
          action: GuidedAction.pon,
          hand: hand,
          consumed: consumed,
          meld: Meld(
            kind: MeldKind.triplet,
            low: offered.type,
            concealed: false,
            tiles: [...consumed, offered],
          ),
          remaining: remaining,
          visibleCounts34: visibleCounts34,
          context: context,
          passShanten: passState.shanten,
          opponentDiscards: opponentDiscards,
          allDiscards: allDiscards,
          opponentRiichi: opponentRiichi,
        ));
      }
    }

    if (available.contains(GuidedAction.chi)) {
      ActionAdvice? bestChi;
      for (final candidate in _chiCandidates(hand, offered)) {
        final advice = _meldCallAdvice(
          action: GuidedAction.chi,
          hand: hand,
          consumed: candidate.consumed,
          meld: candidate.meld,
          remaining: remaining,
          visibleCounts34: visibleCounts34,
          context: context,
          passShanten: passState.shanten,
          opponentDiscards: opponentDiscards,
          allDiscards: allDiscards,
          opponentRiichi: opponentRiichi,
        );
        if (bestChi == null ||
            (advice.eligible && !bestChi.eligible) ||
            (advice.eligible == bestChi.eligible &&
                advice.expectedValue > bestChi.expectedValue)) {
          bestChi = advice;
        }
      }
      if (bestChi != null) options.add(bestChi);
    }

    if (available.contains(GuidedAction.kan)) {
      final consumed = _takeFromHand(hand, offered.type, 3);
      if (consumed.length == 3) {
        options.add(_kanAdvice(
          concealedAfter: _handWithout(hand, consumed),
          meld: Meld(
            kind: MeldKind.kan,
            low: offered.type,
            concealed: false,
            tiles: [...consumed, offered],
          ),
          remaining: remaining,
          context: context,
          shantenBefore: passState.shanten,
          evBefore: passState.ev,
          opponentRiichi: opponentRiichi,
        ));
      }
    }

    // Ranking: a call has to clear its hard rules *and* beat simply staying
    // put. Kan is judged last and only on shape, because its real payoff — an
    // extra dora indicator — is not something the value model can price.
    ActionAdvice? bestMeld;
    for (final option in options) {
      if (option.action != GuidedAction.pon &&
          option.action != GuidedAction.chi) {
        continue;
      }
      if (!option.eligible) continue;
      if (bestMeld == null || option.expectedValue > bestMeld.expectedValue) {
        bestMeld = option;
      }
    }

    var recommended = GuidedAction.pass;
    if (bestMeld != null && bestMeld.expectedValue > pass.expectedValue) {
      recommended = bestMeld.action;
    } else {
      final kan = options
          .where((o) => o.action == GuidedAction.kan && o.eligible)
          .firstOrNull;
      if (kan != null) recommended = GuidedAction.kan;
    }

    options.sort((a, b) {
      if (a.eligible != b.eligible) return a.eligible ? -1 : 1;
      return b.expectedValue.compareTo(a.expectedValue);
    });
    return CallAdvice(recommended: recommended, options: options);
  }

  /// Whether to declare a concealed kan on your own turn.
  ///
  /// [hand] is the 14 concealed tiles you are holding (13 + the draw). Unlike
  /// pon or chi this cannot advance the hand — the triplet was already there —
  /// so it is judged on whether it damages the shape and on whether flipping a
  /// fresh dora indicator is safe to do right now.
  ActionAdvice adviseClosedKan({
    required List<Tile> hand,
    required TileType kanType,
    required List<int> visibleCounts34,
    required EfficiencyValueContext context,
    bool opponentRiichi = false,
  }) {
    final remaining34 = [for (var i = 0; i < 34; i++) 4 - visibleCounts34[i]];
    final remaining = trainerCountsFromTypeCounts(remaining34);

    // Where the hand sits if the kan is skipped: its best ordinary discard.
    final current = analyze(
      hand: hand,
      visibleCounts34: visibleCounts34,
      canRiichi: false,
      valueContext: context,
    );
    final shantenBefore = current.currentShanten;
    final evBefore =
        current.lines.isEmpty ? 0.0 : current.lines.first.expectedValue;

    final consumed = _takeFromHand(hand, kanType, 4);
    if (consumed.length < 4) {
      return const ActionAdvice(
        action: GuidedAction.kan,
        expectedValue: 0,
        shantenAfter: 99,
        eligible: false,
        reason: 'You do not hold all four.',
      );
    }

    return _kanAdvice(
      concealedAfter: _handWithout(hand, consumed),
      meld: Meld(
        kind: MeldKind.kan,
        low: kanType,
        concealed: true,
        tiles: consumed,
      ),
      remaining: remaining,
      context: context,
      shantenBefore: shantenBefore,
      evBefore: evBefore,
      opponentRiichi: opponentRiichi,
    );
  }

  /// Tsumo is never declined — this exists so the guide can show what the win
  /// is actually worth alongside the recommendation.
  ActionAdvice adviseTsumo({
    required List<Tile> hand,
    required Tile drawn,
    required EfficiencyValueContext context,
  }) {
    final concealed = List<Tile>.of(hand)..remove(drawn);
    final score = _scoreWait(concealed, drawn,
        isTsumo: true, assumeRiichi: context.inRiichi, context: context);
    final points = score.valid ? score.points : 0;
    return ActionAdvice(
      action: GuidedAction.tsumo,
      expectedValue: points.toDouble(),
      shantenAfter: -1,
      reason: 'Tsumo — $points points. Always take the win.',
    );
  }

  ActionAdvice _meldCallAdvice({
    required GuidedAction action,
    required List<Tile> hand,
    required List<Tile> consumed,
    required Meld meld,
    required List<int> remaining,
    required List<int> visibleCounts34,
    required EfficiencyValueContext context,
    required int passShanten,
    required List<TileType> opponentDiscards,
    required List<TileType> allDiscards,
    required bool opponentRiichi,
  }) {
    final concealedAfter = _handWithout(hand, consumed);
    final contextAfter = _contextWithMeld(context, meld);
    final label = _actionLabel(action);

    final report = analyze(
      hand: concealedAfter,
      visibleCounts34: visibleCounts34,
      canRiichi: contextAfter.closed && !context.inRiichi,
      valueContext: contextAfter,
      defenseHand: opponentRiichi ? concealedAfter : null,
      opponentDiscards: opponentDiscards,
      allDiscards: allDiscards,
      opponentRiichi: opponentRiichi,
    );
    if (report.lines.isEmpty) {
      return ActionAdvice(
        action: action,
        expectedValue: 0,
        shantenAfter: 99,
        eligible: false,
        meldLow: meld.low,
        reason: '$label leaves no playable hand.',
      );
    }

    var best = report.lines.first;
    for (final line in report.lines) {
      if (line.recommended) {
        best = line;
        break;
      }
    }
    final shape = best.shanten == 0 ? 'tenpai' : '${best.shanten}-shanten';

    if (best.shanten >= passShanten) {
      return ActionAdvice(
        action: action,
        expectedValue: best.expectedValue,
        shantenAfter: best.shanten,
        eligible: false,
        meldLow: meld.low,
        discardAfter: best.discard,
        discardSafety: best.safety,
        reason: '$label gets you no closer — still $shape afterwards, and it '
            'costs you a concealed hand.',
      );
    }
    if (best.expectedValue <= 0) {
      return ActionAdvice(
        action: action,
        expectedValue: 0,
        shantenAfter: best.shanten,
        eligible: false,
        meldLow: meld.low,
        discardAfter: best.discard,
        discardSafety: best.safety,
        reason: '$label opens your hand with no yaku left to finish on, so it '
            'could not score.',
      );
    }
    if (opponentRiichi && best.shanten > 0) {
      return ActionAdvice(
        action: action,
        expectedValue: best.expectedValue,
        shantenAfter: best.shanten,
        eligible: false,
        meldLow: meld.low,
        discardAfter: best.discard,
        discardSafety: best.safety,
        reason: '$label commits you while a riichi is out and you are still '
            '$shape — fold instead.',
      );
    }

    final safety = best.safety;
    final safetyNote = safety == null
        ? ''
        : ', then discard ${best.discard.code} (${safety.label})';
    return ActionAdvice(
      action: action,
      expectedValue: best.expectedValue,
      shantenAfter: best.shanten,
      meldLow: meld.low,
      discardAfter: best.discard,
      discardSafety: safety,
      reason: '$label puts you at $shape worth about '
          '${best.expectedValue.round()} points$safetyNote.',
    );
  }

  ActionAdvice _kanAdvice({
    required List<Tile> concealedAfter,
    required Meld meld,
    required List<int> remaining,
    required EfficiencyValueContext context,
    required int shantenBefore,
    required double evBefore,
    required bool opponentRiichi,
  }) {
    final contextAfter = _contextWithMeld(context, meld);
    final after = _evaluateWaitingHand(
      concealed: concealedAfter,
      remaining: remaining,
      context: contextAfter,
      canRiichi: contextAfter.closed && !context.inRiichi,
    );
    final shape = after.shanten <= 0 ? 'tenpai' : '${after.shanten}-shanten';

    if (after.shanten > shantenBefore) {
      return ActionAdvice(
        action: GuidedAction.kan,
        expectedValue: after.ev,
        shantenAfter: after.shanten,
        eligible: false,
        reason: 'Kan breaks up your shape — it would drop you to $shape.',
      );
    }
    // A concealed kan keeps the hand closed, so riichi remains its yaku path.
    // An open kan has no such fallback and must retain a scoring route, just
    // like the pon/chi evaluator above.
    if (!contextAfter.closed && after.ev <= 0) {
      return ActionAdvice(
        action: GuidedAction.kan,
        expectedValue: 0,
        shantenAfter: after.shanten,
        eligible: false,
        reason: 'Kan leaves no live yaku-bearing finish, so the hand could '
            'not score.',
      );
    }
    if (opponentRiichi && after.shanten > 0) {
      return ActionAdvice(
        action: GuidedAction.kan,
        expectedValue: after.ev,
        shantenAfter: after.shanten,
        eligible: false,
        reason: 'Kan flips a new dora indicator that helps the riichi as much '
            'as you, and you are still $shape — skip it.',
      );
    }
    return ActionAdvice(
      action: GuidedAction.kan,
      expectedValue: math.max(after.ev, evBefore),
      shantenAfter: after.shanten,
      reason: 'Kan keeps you at $shape and adds a dora indicator plus a '
          'replacement draw, with no riichi to punish it.',
    );
  }

  /// Shanten and expected value of a hand *between* draws — 13 tiles' worth of
  /// hand once melds are counted. Used for the do-nothing baseline and for
  /// kan, neither of which ends in a discard.
  ({int shanten, double ev}) _evaluateWaitingHand({
    required List<Tile> concealed,
    required List<int> remaining,
    required EfficiencyValueContext context,
    required bool canRiichi,
  }) {
    final counts = toTrainerCounts(concealed);
    final shanten = _calc.calculateWaitingShanten(counts);
    final acceptance = _calc.acceptance(counts, remaining);
    final value = _assessValue(
      result: TileEfficiencyResult(
        tileIndex: 1,
        shanten: shanten,
        ukeire: acceptance.count,
        improvingTiles: acceptance.tiles,
      ),
      remaining: remaining,
      concealed: concealed,
      canRiichi: canRiichi,
      context: context,
    );
    return (shanten: shanten, ev: value.expectedValue);
  }

  /// Every sequence that could be formed with [offered] plus two tiles held.
  List<({Meld meld, List<Tile> consumed})> _chiCandidates(
    List<Tile> hand,
    Tile offered,
  ) {
    final out = <({Meld meld, List<Tile> consumed})>[];
    final type = offered.type;
    if (!type.isSuit) return out;

    for (final offset in [-2, -1, 0]) {
      final lowNumber = type.number + offset;
      if (lowNumber < 1 || lowNumber + 2 > 9) continue;
      final low = TileType.values[type.index - type.number + lowNumber];
      final needed = [
        for (var i = 0; i < 3; i++) TileType.values[low.index + i],
      ]..remove(type);
      if (needed.length != 2) continue;

      final consumed = <Tile>[];
      final pool = List<Tile>.of(hand);
      for (final want in needed) {
        final index = pool.indexWhere((t) => t.type == want);
        if (index < 0) break;
        consumed.add(pool.removeAt(index));
      }
      if (consumed.length != 2) continue;

      out.add((
        meld: Meld(
          kind: MeldKind.sequence,
          low: low,
          concealed: false,
          tiles: [...consumed, offered],
        ),
        consumed: consumed,
      ));
    }
    return out;
  }

  static EfficiencyValueContext _contextWithMeld(
    EfficiencyValueContext context,
    Meld meld,
  ) =>
      EfficiencyValueContext(
        melds: [...context.melds, meld],
        roundWind: context.roundWind,
        seatWind: context.seatWind,
        isDealer: context.isDealer,
        inRiichi: context.inRiichi,
        wallTilesRemaining: context.wallTilesRemaining,
        doraIndicators: context.doraIndicators,
      );

  /// [count] tiles of [type] from [hand], preferring plain copies so a red
  /// five stays where it can still be chosen freely.
  static List<Tile> _takeFromHand(List<Tile> hand, TileType type, int count) {
    final matches = hand.where((t) => t.type == type).toList()
      ..sort((a, b) => (a.aka ? 1 : 0).compareTo(b.aka ? 1 : 0));
    return matches.take(count).toList();
  }

  static List<Tile> _handWithout(List<Tile> hand, List<Tile> removed) {
    final out = List<Tile>.of(hand);
    for (final tile in removed) {
      out.remove(tile);
    }
    return out;
  }

  static String _actionLabel(GuidedAction action) => switch (action) {
        GuidedAction.pass => 'Passing',
        GuidedAction.chi => 'Chi',
        GuidedAction.pon => 'Pon',
        GuidedAction.kan => 'Kan',
        GuidedAction.ron => 'Ron',
        GuidedAction.tsumo => 'Tsumo',
      };

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
    // Getting home needs (shanten + 1) separate improvements, and they have to
    // share the draws that are left — so each step gets its slice of the wall,
    // not all of it. Spending the whole wall on every step made a wide hand
    // three away look likelier to finish than a narrow hand one away, which
    // made a "call vs. stay put" comparison meaningless.
    final steps = result.shanten + 1;
    final drawsPerStep = draws / steps;
    final improveProbability =
        1 - math.pow(1 - improveRate, drawsPerStep).toDouble();
    final completionProbability =
        math.pow(improveProbability, steps).toDouble();

    // Before tenpai the exact final hand is unknown. These representative
    // values keep pre-tenpai comparisons stable; exact yaku/fu/dora scoring
    // takes over as soon as a discard leaves the hand in tenpai.
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
