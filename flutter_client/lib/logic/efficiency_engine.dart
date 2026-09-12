library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'efficiency_calc.dart';
import 'meld.dart';
import 'safety.dart';
import 'scoring.dart';
import 'tile.dart';

enum PlayStyle {
  defensive(riskWeight: 2.0, damatenBar: 0.55, label: 'Defensive'),

  balanced(riskWeight: 1.0, damatenBar: 1.0, label: 'Balanced'),

  /// Pushes thin hands and declares on almost anything; treats the same danger
  /// as costing about half.
  aggressive(riskWeight: 0.45, damatenBar: 2.0, label: 'Aggressive');

  const PlayStyle({
    required this.riskWeight,
    required this.damatenBar,
    required this.label,
  });

  /// Multiplier applied to every risk charge.
  final double riskWeight;

  final double damatenBar;

  final String label;

  PlayStyle get next => PlayStyle.values[(index + 1) % PlayStyle.values.length];
}

enum HandFocus {
  /// A big hand is worth having, but not worth waiting for: payouts are
  /// flattened toward [_pivot], so the faster line wins most ties.
  speed(curve: 0.45, label: 'Speed'),

  /// No tilt at all. Expected value is taken at face value, and the line with
  /// the larger `chance x payout` wins whatever shape it is.
  balanced(curve: 1.0, label: 'Balanced'),

  /// Payouts are stretched away from [_pivot], so a hand that pays double is
  /// worth more than twice as much and is worth slowing down for.
  value(curve: 1.55, label: 'Value');

  const HandFocus({required this.curve, required this.label});

  /// Exponent on the payout. Below 1 compresses the spread between a cheap
  /// hand and a big one (speed); above 1 stretches it (value).
  final double curve;

  final String label;

  HandFocus get next => HandFocus.values[(index + 1) % HandFocus.values.length];

  /// The payout this focus pivots around — a hand worth exactly this much is
  /// worth the same to all three, and everything else is pulled toward it or
  /// pushed away from it. Set at a middling closed hand, so that neither tilt
  /// quietly inflates or deflates every hand on the table.
  static const double _pointsPivot = 32;

  /// The same idea for the other half of the product: a line with roughly this
  /// chance of getting home is read the same way by all three.
  static const double _chancePivot = 0.25;

  /// What [points] is *worth* to a player with this focus, in points.
  ///
  /// A curve rather than a flat multiplier, so the tilt is about the spread
  /// between a cheap hand and a big one and not about the general level: at
  /// [_pointsPivot] all three agree, and they disagree more the further a hand
  /// sits from it. Speed values a 7700 at about 6,700 and a 2000 at about
  /// 2,400 — so the gap between them shrinks from 3.9x to 2.8x. Value pulls
  /// the same pair apart instead.
  double worth(double points) => points <= 0
      ? points
      : _pointsPivot * math.pow(points / _pointsPivot, curve).toDouble();

  /// What a [chance] of getting home is worth to this focus.
  ///
  /// The payout curve on its own turned out to move almost nothing. Expected
  /// value is a product of two terms, and within one hand the discards barely
  /// differ in the payout — they nearly all end on the same hand — while they
  /// differ enormously in how likely they are to get there. A curve applied to
  /// the term they share reorders nothing.
  ///
  /// So the dial bends the other term too, by the opposite amount: the
  /// exponents are [curve] and `2 - curve`, which multiply back to a straight
  /// product on Balanced and leave it *exactly* as it was. Speed sharpens the
  /// spread between a likely line and an unlikely one, so getting there wins
  /// close calls; Value flattens it, so a thin line is forgiven in exchange
  /// for what it pays. That is the trade-off the dial is supposed to express,
  /// and it is the one it now makes.
  double chanceWorth(double chance) => chance <= 0
      ? chance
      : _chancePivot *
          math.pow(chance / _chancePivot, 2 - curve).toDouble().clamp(0.0, 8.0);
}

class EfficiencyValueContext {
  const EfficiencyValueContext({
    required this.melds,
    required this.roundWind,
    required this.seatWind,
    required this.isDealer,
    required this.inRiichi,
    required this.wallTilesRemaining,
    required this.doraIndicators,
    this.flowers = const [],
    this.flowersEnabled = true,
    this.honba = 0,
    this.riichiSticks = 0,
    this.style = PlayStyle.balanced,
    this.focus = HandFocus.balanced,
  });

  final List<TileType> flowers;
  final bool flowersEnabled;
  final List<Meld> melds;
  final Wind roundWind;
  final Wind seatWind;
  final bool isDealer;
  final bool inRiichi;
  final int wallTilesRemaining;
  final List<TileType> doraIndicators;

  /// Legacy input, ignored by Hong Kong scoring.
  final int honba;

  /// How heavily to weigh danger against value. See [PlayStyle].
  final PlayStyle style;

  /// Which hand to chase when two are worth the same. See [HandFocus].
  final HandFocus focus;

  final int riichiSticks;

  /// What winning this hand pays on top of the hand's own value, however it is
  /// won. It rides on the win, so expected value multiplies it by the chance of
  /// getting there — it never changes which hand shape is worth chasing, only
  /// how much the chase is worth.
  int get winBonus => 0;

  bool get closed => melds.every((m) => m.kind == MeldKind.kan && m.concealed);

  EfficiencyValueContext withMelds(List<Meld> melds) => EfficiencyValueContext(
        melds: melds,
        flowers: flowers,
        flowersEnabled: flowersEnabled,
        roundWind: roundWind,
        seatWind: seatWind,
        isDealer: isDealer,
        inRiichi: inRiichi,
        wallTilesRemaining: wallTilesRemaining,
        doraIndicators: doraIndicators,
        honba: honba,
        riichiSticks: riichiSticks,
        style: style,
        focus: focus,
      );
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
    this.reason = '',
    this.safety,
    this.dealInCost = 0,
    this.commitmentCost = 0,
    this.winProbability = 0,
    this.riichiLockCost = 0,
    this.valueTilt = 0,
    this.winBonus = 0,
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

  final String reason;
  SafetyRating? safety;

  final double dealInCost;

  final double commitmentCost;

  /// The total risk charged against this cut.
  double get riskCost => dealInCost + commitmentCost;

  final double winProbability;
  final double riichiLockCost;

  /// What the [HandFocus] dial moved this line by: the gap between the payout
  /// as scored and what a player on that dial treats it as worth, times the
  /// chance of collecting it. Positive on a big hand under Value, negative on
  /// one under Speed, and exactly zero on Balanced — which is why it is kept
  /// apart from [averagePoints] rather than folded into it. [averagePoints]
  /// stays the payout the hand really makes.
  final double valueTilt;

  final double winBonus;

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

  final bool eligible;

  /// For a chi, the lowest tile of the run the guide picked — several runs can
  /// often be made with the same discard, so the caller has to know which.
  final TileType? meldLow;

  /// The tile the guide would discard after making this call.
  final TileType? discardAfter;

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
  final _calc = TileEfficiencyCalculator();

  EfficiencyReport analyze({
    required List<Tile> hand,
    required List<int> visibleCounts34,
    required bool canRiichi,
    required EfficiencyValueContext valueContext,
    List<Tile>? defenseHand,
    List<TileType> opponentDiscards = const [],
    List<TileType> passedDiscardsAfterRiichi = const [],
    bool opponentRiichi = false,
    bool opponentIsDealer = false,
  }) {
    final remaining34 = [
      for (var i = 0; i < 34; i++) (4 - visibleCounts34[i]).clamp(0, 4)
    ];
    final concealed = toTrainerCounts(hand);
    final remaining = trainerCountsFromTypeCounts(remaining34);

    const riichiDangerFactor = 0.0;
    // Safety is needed before the lines are priced, not after: what a discard
    // can cost you when it deals in is part of what that discard is worth.
    final defending = opponentRiichi && defenseHand != null;
    final defense = defending
        ? rankSafety(
            defenseHand,
            opponentDiscards: opponentDiscards,
            passedDiscardsAfterRiichi: passedDiscardsAfterRiichi,
            visibleCounts34: visibleCounts34,
          )
        : <SafetyRating>[];
    final safeByType = {for (final s in defense) s.type: s};

    final raw = _calc.calculate(concealed, remaining);

    // Deduplicate by tile type (multiple copies of the same tile in hand).
    final byType = <TileType, TileEfficiencyResult>{};
    for (final r in raw) {
      final t = r.discard;
      final existing = byType[t];
      if (existing == null || r.ukeire > existing.ukeire) byType[t] = r;
    }

    final tenpaiResult = byType.values.where((r) => r.shanten == 0).firstOrNull;
    double? projectedPointsOverride;
    double? projectedDamaOverride;
    double? projectedDoraReference;
    if (tenpaiResult != null) {
      final probe = _assessValue(
        result: tenpaiResult,
        remaining: remaining,
        concealed: _handAfterDiscard(hand, tenpaiResult.discard),
        canRiichi: canRiichi,
        context: valueContext,
        opponentRiichi: opponentRiichi,
        opponentIsDealer: opponentIsDealer,
        riichiDangerFactor: riichiDangerFactor,
      );
      if (probe.averagePoints > 0) {
        projectedPointsOverride = probe.averagePoints;
        projectedDamaOverride = probe.damaPoints;
        projectedDoraReference = _doraKept(
          _handAfterDiscard(hand, tenpaiResult.discard),
          valueContext,
        ).toDouble();
      }
    }

    final hasTenpaiLine = byType.values.any((r) => r.shanten == 0);
    final unseenNow = _countRemaining(remaining);
    final drawsNow = math.max(1, (valueContext.wallTilesRemaining + 3) ~/ 4);
    double? reachedTenpaiWinChance(TileEfficiencyResult r) {
      if (!hasTenpaiLine || r.shanten != 1) return null;
      final after = toTrainerCounts(_handAfterDiscard(hand, r.discard));
      var weighted = 0.0;
      var copies = 0;
      for (final draw in r.improvingTiles) {
        final live = remaining[draw];
        if (live <= 0) continue;
        after[draw]++;
        remaining[draw]--;
        final wait = _calc.bestTenpaiWait(after, remaining);
        remaining[draw]++;
        after[draw]--;
        weighted += live *
            _winChanceOverTurns(
              waitWidth: wait.toDouble(),
              unseen: unseenNow - 1,
              draws: drawsNow - 1, // one draw is spent reaching tenpai
              chancesPerTurn: _winChancesPerTurn,
            ).win;
        copies += live;
      }
      return copies == 0 ? null : weighted / copies;
    }

    final lines = byType.values.map((r) {
      final afterDiscard = _handAfterDiscard(hand, r.discard);
      final value = _assessValue(
        reachedTenpaiWinChance: reachedTenpaiWinChance(r),
        projectedPointsOverride: projectedPointsOverride,
        projectedDamaOverride: projectedDamaOverride,
        projectedDoraReference: projectedDoraReference,
        result: r,
        remaining: remaining,
        concealed: afterDiscard,
        canRiichi: canRiichi,
        context: valueContext,
        opponentRiichi: opponentRiichi,
        opponentIsDealer: opponentIsDealer,
        riichiDangerFactor: riichiDangerFactor,
      );
      final safety = safeByType[r.discard];
      final dealInCost = _dealInPenalty(
            safety: safety,
            opponentIsDealer: opponentIsDealer,
            honba: valueContext.honba,
          ) *
          valueContext.style.riskWeight;
      final laterTurns = math.max(0.0, value.turnsExposed - 1);
      final commitmentCost = dealInCost * laterTurns * _pushCommitment;
      return DiscardLine(
        discard: r.discard,
        shanten: r.shanten,
        ukeire: r.ukeire,
        accepts: r.accepts,
        // What the cut is worth, less what it can cost you. Folding to a safe
        // tile now reads as the better line whenever the hand behind it isn't
        // worth the risk — no separate push/fold switch needed.
        expectedValue: value.expectedValue - dealInCost - commitmentCost,
        averagePoints: value.averagePoints,
        valuePlan: value.plan,
        recommendRiichi: value.recommendRiichi,
        reason: value.reason,
        safety: safety,
        dealInCost: dealInCost,
        commitmentCost: commitmentCost,
        winProbability: value.winProbability,
        riichiLockCost: value.riichiLockCost,
        valueTilt: value.valueTilt,
        winBonus: valueContext.winBonus.toDouble(),
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

    // Recommendation: the best expected value, full stop — at tenpai and
    // before it, defending or not.
    //
    // This used to switch to "cut the safest tile" whenever you were defending
    // and not yet tenpai, because the value model could not express folding.
    // It can now: every line carries the deal-in cost of the tile itself plus
    // the turns that choice commits you to, so a fold is priced as the cheap,
    // low-value line it is and a push has to actually be worth it. Across the
    // random defending positions in `push_fold_sweep_test.dart` the two agreed
    // on better than 99% of decisions before the switch came out.
    final recommended = bestValue;
    recommended?.recommended = true;
    // The panel always shows the recommended line first — while defending,
    // it can be the safest discard rather than the best-EV one, which the
    // EV sort above would otherwise bury anywhere in the list.
    if (recommended != null) {
      lines.remove(recommended);
      lines.insert(0, recommended);
    }

    final tenpai = currentShanten == 0;
    final recommendRiichi = tenpai && (recommended?.recommendRiichi ?? false);

    return EfficiencyReport(
      lines: lines,
      currentShanten: currentShanten,
      tenpai: tenpai,
      recommendRiichi: recommendRiichi,
      defending: defending,
      defense: defense,
      headline: defending
          ? 'An opponent has exposed two or more sets — estimated risk shown'
          : tenpai
              ? 'Tenpai — best EV ${bestValue?.expectedValue.round() ?? 0} pts'
              : '$currentShanten-shanten',
    );
  }

  // --- call and turn advice ----------------------------------------------

  CallAdvice adviseCall({
    required List<Tile> hand,
    required Tile offered,
    required Set<GuidedAction> available,
    required List<int> visibleCounts34,
    required EfficiencyValueContext context,
    List<TileType> opponentDiscards = const [],
    List<TileType> passedDiscardsAfterRiichi = const [],
    bool opponentRiichi = false,
    bool opponentIsDealer = false,
  }) {
    final remaining34 = [
      for (var i = 0; i < 34; i++) (4 - visibleCounts34[i]).clamp(0, 4)
    ];
    final remaining = trainerCountsFromTypeCounts(remaining34);

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
                'tile gives up a guaranteed win.',
          ),
        ],
      );
    }

    final passState = _evaluateWaitingHand(
      concealed: hand,
      remaining: remaining,
      context: context,
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
          passedDiscardsAfterRiichi: passedDiscardsAfterRiichi,
          opponentRiichi: opponentRiichi,
          opponentIsDealer: opponentIsDealer,
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
          passedDiscardsAfterRiichi: passedDiscardsAfterRiichi,
          opponentRiichi: opponentRiichi,
          opponentIsDealer: opponentIsDealer,
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
          contextAfter: _contextWithMeld(
            context,
            Meld(
              kind: MeldKind.kan,
              low: offered.type,
              concealed: false,
              tiles: [...consumed, offered],
            ),
          ),
          remaining: remaining,
          shantenBefore: passState.shanten,
          evBefore: passState.ev,
          opponentRiichi: opponentRiichi,
        ));
      }
    }

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

  ActionAdvice adviseClosedKan({
    required List<Tile> hand,
    required TileType kanType,
    required List<int> visibleCounts34,
    required EfficiencyValueContext context,
    bool opponentRiichi = false,
    bool opponentIsDealer = false,
  }) {
    final remaining34 = [
      for (var i = 0; i < 34; i++) (4 - visibleCounts34[i]).clamp(0, 4)
    ];
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
      contextAfter: _contextWithMeld(
        context,
        Meld(
            kind: MeldKind.kan, low: kanType, concealed: true, tiles: consumed),
      ),
      remaining: remaining,
      shantenBefore: shantenBefore,
      evBefore: evBefore,
      opponentRiichi: opponentRiichi,
    );
  }

  ActionAdvice adviseAddedKan({
    required List<Tile> hand,
    required TileType kanType,
    required List<Meld> melds,
    required List<int> visibleCounts34,
    required EfficiencyValueContext context,
    bool opponentRiichi = false,
    bool opponentIsDealer = false,
    List<TileType> opponentDiscards = const [],
    List<TileType> passedDiscardsAfterRiichi = const [],
  }) {
    final remaining34 = [
      for (var i = 0; i < 34; i++) (4 - visibleCounts34[i]).clamp(0, 4)
    ];
    final remaining = trainerCountsFromTypeCounts(remaining34);

    final current = analyze(
      hand: hand,
      visibleCounts34: visibleCounts34,
      canRiichi: false,
      valueContext: context,
    );
    final shantenBefore = current.currentShanten;
    final evBefore =
        current.lines.isEmpty ? 0.0 : current.lines.first.expectedValue;

    final ponIndex =
        melds.indexWhere((m) => m.kind == MeldKind.triplet && m.low == kanType);
    final consumed = _takeFromHand(hand, kanType, 1);
    if (ponIndex == -1 || consumed.isEmpty) {
      return const ActionAdvice(
        action: GuidedAction.kan,
        expectedValue: 0,
        shantenAfter: 99,
        eligible: false,
        reason: 'No matching open pon and tile to add it to.',
      );
    }
    final addedTile = consumed.single;

    if (opponentRiichi) {
      final rating = rankSafety(
        [addedTile],
        opponentDiscards: opponentDiscards,
        passedDiscardsAfterRiichi: passedDiscardsAfterRiichi,
        visibleCounts34: visibleCounts34,
      ).firstOrNull;
      if (rating != null && rating.rating < 8) {
        return ActionAdvice(
          action: GuidedAction.kan,
          expectedValue: evBefore,
          shantenAfter: shantenBefore,
          eligible: false,
          reason:
              'Robbing a kong risk — ${rating.label} against the exposed hand, '
              'the added tile can complete an opponent’s hand.',
        );
      }
    }

    final pon = melds[ponIndex];
    final meldsAfter = [...melds]..removeAt(ponIndex);
    meldsAfter.add(Meld(
      kind: MeldKind.kan,
      low: kanType,
      concealed: false,
      addedKan: true,
      calledFromSeatOffset: pon.calledFromSeatOffset,
      tiles: [...pon.tiles, addedTile],
    ));

    return _kanAdvice(
      concealedAfter: _handWithout(hand, consumed),
      contextAfter: context.withMelds(meldsAfter),
      remaining: remaining,
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
      reason: 'Self draw — $points chips. Always take the win.',
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
    required List<TileType> passedDiscardsAfterRiichi,
    required bool opponentRiichi,
    required bool opponentIsDealer,
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
      passedDiscardsAfterRiichi: passedDiscardsAfterRiichi,
      opponentRiichi: opponentRiichi,
      opponentIsDealer: opponentIsDealer,
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

    // "Does it advance the hand" is a question about the shape the call makes
    // available, not about which line the value model then prefers — a call
    // that reaches tenpai has advanced the hand even when the tenpai it
    // reaches is too thin to be worth taking. That comparison belongs to the
    // expected values below, which is where it happens.
    if (report.currentShanten >= passShanten) {
      return ActionAdvice(
        action: action,
        expectedValue: best.expectedValue,
        shantenAfter: best.shanten,
        eligible: false,
        meldLow: meld.low,
        discardAfter: best.discard,
        discardSafety: best.safety,
        reason: '$label gets you no closer — still $shape afterwards, and it '
            'offers no improvement in shape.',
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
        reason: '$label has no positive estimated value after risk.',
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
        reason: '$label commits you against an exposed hand while still '
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

  /// [contextAfter] must already reflect the hand's melds *after* the kan —
  /// callers building a genuinely new meld can get there via
  /// [_contextWithMeld]; shouminkan instead has to replace the pon it
  /// extends rather than append alongside it, so it builds its own.
  ActionAdvice _kanAdvice({
    required List<Tile> concealedAfter,
    required EfficiencyValueContext contextAfter,
    required List<int> remaining,
    required int shantenBefore,
    required double evBefore,
    required bool opponentRiichi,
  }) {
    final after = _evaluateWaitingHand(
      concealed: concealedAfter,
      remaining: remaining,
      context: contextAfter,
      canRiichi: contextAfter.closed && !contextAfter.inRiichi,
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
    if (!contextAfter.closed && after.ev <= 0) {
      return ActionAdvice(
        action: GuidedAction.kan,
        expectedValue: 0,
        shantenAfter: after.shanten,
        eligible: false,
        reason: 'Kong has no live improving tiles in this position.',
      );
    }
    if (opponentRiichi && after.shanten > 0) {
      return ActionAdvice(
        action: GuidedAction.kan,
        expectedValue: after.ev,
        shantenAfter: after.shanten,
        eligible: false,
        reason: 'Kong commits you against an exposed hand while still $shape.',
      );
    }
    return ActionAdvice(
      action: GuidedAction.kan,
      expectedValue: math.max(after.ev, evBefore),
      shantenAfter: after.shanten,
      reason: 'Kong keeps you at $shape and gives a replacement draw.',
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
      context.withMelds([...context.melds, meld]);

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

  /// What an ordinary hand's measured ukeire actually is at each shanten, used
  /// only to say how far above or below ordinary *this* hand is. Index is
  /// shanten; index 0 is a finished hand's wait.
  ///
  /// Measured, not guessed: these are the mean acceptances of the best line
  /// over simulated play, and `ev_calibration_test.dart` re-runs that
  /// simulation and fails if they drift apart. Getting them right matters
  /// because they are a *divisor* — understating them, as this table did from
  /// 3-shanten out, hands every far-from-tenpai hand a scale above 1 and
  /// compounds it over each of the many steps that hand has left, until a
  /// 5-shanten hand scores like a 1-shanten one.
  static const List<double> _typicalUkeire = [5, 14, 25, 43, 63, 73, 80];

  /// [_typicalUkeire], for `ev_calibration_test.dart` to hold against what
  /// simulated play actually produces.
  @visibleForTesting
  static List<double> get typicalUkeireByShanten => _typicalUkeire;

  /// The width an ordinary hand behaves as if it had at each remaining step.
  ///
  /// Deliberately not [_typicalUkeire]. A shanten step three away is not the
  /// same event as hitting a wait: much of a far hand's raw acceptance buys a
  /// step that barely moves it toward an actual win, and the model collapses
  /// each step into a single per-turn rate. These are the effective rates that
  /// reproduce real win frequencies, so a hand of ordinary width (scale 1) at
  /// each shanten lands where it should — see [_handSurvivesTurn].
  static const List<double> _stepWidth = [8, 20, 28, 35, 40, 44, 48];

  /// Chance the hand is still running after one more of your turns — the other
  /// three seats are drawing too, and one of them ending the hand (or an
  /// exhaustive draw) stops yours dead.
  ///
  /// Calibrated against the figure worth trusting: a hand wins a little over
  /// one time in five, and a dealt hand is typically three to four away. With
  /// [_stepWidth] this lands an ordinary hand with a full wall at roughly 35%
  /// from 1-shanten, 24% from 2, 16% from 3 and 10% from 4, against 53% from
  /// tenpai — so an average starting hand comes out near one in seven before
  /// any call, and the ordering by shanten is the one you would expect.
  static const double _handSurvivesTurn = 0.955;

  /// How much of a hand's width carries through to the wait it finishes on.
  /// 1 would mean a hand with twice the acceptance also ends on twice the wait;
  /// 0 would mean every hand ends on the same average wait. Neither is true.
  static const double _waitInheritance = 0.5;

  static const double _winChancesPerTurn = 1.0;

  static const double _pushCommitment = 0.3;

  /// The chance of hitting a wait this wide before the hand ends.
  ///
  /// Shared by both estimators, so a hand does not jump in value the moment it
  /// reaches tenpai. Each turn offers [chancesPerTurn] shots at the wait, and
  /// whatever has not won yet only carries on if the hand is still running —
  /// the other three seats are drawing too, and one of them winning (or the
  /// wall running out) ends yours.
  static ({double win, double turns}) _winChanceOverTurns({
    required double waitWidth,
    required int unseen,
    required int draws,
    required double chancesPerTurn,
  }) {
    if (unseen <= 0 || draws <= 0 || waitWidth <= 0) {
      return (win: 0, turns: 0);
    }
    final rate = math.min(1.0, waitWidth / unseen);
    final perTurn = 1 - math.pow(1 - rate, chancesPerTurn).toDouble();
    var alive = 1.0;
    var won = 0.0;
    var turns = 0.0;
    for (var turn = 0; turn < draws; turn++) {
      turns += alive; // this turn is only played if the hand got this far
      won += alive * perTurn;
      alive *= (1 - perTurn) * _handSurvivesTurn;
    }
    return (win: won.clamp(0.0, 1.0), turns: turns);
  }

  /// The chance a hand this far from home actually wins, over the draws it has
  /// left.
  ///
  /// Walks the hand forward one turn at a time. Each turn it may take a step
  /// (shanten − 1), and the acceptance for each step is scaled off the hand's
  /// own ukeire by [_typicalUkeire], because a hand two away does not keep its
  /// current width all the way in — the last step is hitting a wait, not
  /// picking up any useful tile. Every turn also carries the chance the hand
  /// ends first, which is what the old estimator missed entirely: it multiplied
  /// out to well over 90% for a 2-shanten hand with most of the wall left.
  ///
  /// [shanten] must be ≥ 1; tenpai is scored exactly by [_assessTenpaiValue].
  static ({double win, double reachedTenpai, double turns})
      _winProbabilityFromShanten({
    required int shanten,
    required int ukeire,
    required int unseen,
    required int draws,
  }) {
    if (shanten < 1 || draws <= 0 || unseen <= 0 || ukeire <= 0) {
      return (win: 0, reachedTenpai: 0, turns: 0);
    }

    // How much wider (or narrower) this hand is than a typical one that far
    // out. It applies in full to the step the hand is about to take and fades
    // as the hand closes up: being wide open now says a great deal about
    // picking up the next useful tile, and much less about the wait you
    // eventually sit on. It does not fade away entirely — a hand short of
    // acceptance is short of it because it is full of kanchan and tanki
    // shapes, and those are what it ends up waiting on.
    final scale = ukeire / _typicalUkeire[shanten.clamp(0, 6)];

    /// Chance one turn takes the step that leaves the hand at [to] shanten.
    /// The final step — tenpai to a win — gets two chances a turn, since a
    /// finished hand can be ronned off someone else's discard as well as drawn.
    double stepChance(int to) {
      final exponent =
          _waitInheritance + (1 - _waitInheritance) * (to / shanten);
      // Being wide open gets you to tenpai sooner — that is what the earlier
      // steps price. It does not hand you a wider wait than an ordinary hand
      // when you get there, so the last step never scales above typical.
      // Without this a wide 1-shanten came out likelier to win than the very
      // same hand already tenpai, which cannot be.
      var multiplier = math.pow(scale, exponent).toDouble();
      if (to == 0) multiplier = math.min(1.0, multiplier);
      final width = _stepWidth[to.clamp(0, 6)] * multiplier;
      final rate = math.min(1.0, width / unseen);
      // Only the last step — the win itself — can come off a discard.
      final tries = to == 0 ? _winChancesPerTurn : 1.0;
      return 1 - math.pow(1 - rate, tries).toDouble();
    }

    // states[s] = chance the hand is alive and still s steps from a win.
    // A step from shanten 1 lands on 0 (tenpai); one more wins.
    final states = List<double>.filled(shanten + 2, 0);
    states[shanten + 1] = 1;
    var won = 0.0;
    var reached = 0.0;
    var turnsPlayed = 0.0;

    for (var turn = 0; turn < draws; turn++) {
      // Only the turns the hand actually reaches are turns you discard on.
      turnsPlayed += states.fold<double>(0, (a, b) => a + b);
      final next = List<double>.filled(shanten + 2, 0);
      for (var s = shanten + 1; s >= 1; s--) {
        final mass = states[s];
        if (mass <= 0) continue;
        final p = stepChance(s - 1);
        if (s == 1) {
          won += mass * p; // that step was the win itself
        } else {
          next[s - 1] += mass * p;
          if (s == 2) reached += mass * p; // just became tenpai
        }
        next[s] += mass * (1 - p);
      }
      // Whatever has not won yet only continues if the hand is still going.
      for (var s = 0; s < next.length; s++) {
        next[s] *= _handSurvivesTurn;
      }
      states.setAll(0, next);
    }
    return (
      win: won.clamp(0.0, 1.0),
      reachedTenpai: reached.clamp(0.0, 1.0),
      turns: turnsPlayed,
    );
  }

  _ValueAssessment _assessValue({
    required TileEfficiencyResult result,
    required List<int> remaining,
    required List<Tile> concealed,
    required bool canRiichi,
    required EfficiencyValueContext context,
    bool opponentRiichi = false,
    bool opponentIsDealer = false,
    double riichiDangerFactor = 0.0,
    double? projectedPointsOverride,
    double? projectedDamaOverride,
    double? projectedDoraReference,
    double? reachedTenpaiWinChance,
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
        opponentRiichi: opponentRiichi,
        opponentIsDealer: opponentIsDealer,
        riichiDangerFactor: riichiDangerFactor,
      );
    }

    final unseen = _countRemaining(remaining);
    final draws = math.max(0, (context.wallTilesRemaining + 3) ~/ 4);
    final outlook = _winProbabilityFromShanten(
      shanten: result.shanten,
      ukeire: result.ukeire,
      unseen: unseen,
      draws: draws,
    );
    // Capped by the lookahead when there is one: you have to reach tenpai
    // first, and then win from the tenpai you actually reach.
    final completionProbability = reachedTenpaiWinChance == null
        ? outlook.win
        : math.min(outlook.win, outlook.reachedTenpai * reachedTenpaiWinChance);

    // Preserve the existing completion/lookahead model, priced in HK chips.
    // A known ready line anchors projections; otherwise use visible patterns.
    final projectedPoints =
        projectedPointsOverride ?? _projectedPoints(concealed, context);
    final worthOfWin = context.focus.worth(projectedPoints);
    final worthOfChance = context.focus.chanceWorth(completionProbability);
    final tilted = worthOfChance * worthOfWin;
    return _ValueAssessment(
      expectedValue: tilted,
      averagePoints: projectedPoints,
      valueTilt: tilted - completionProbability * projectedPoints,
      plan: 'BUILD HAND',
      winProbability: completionProbability,
      turnsExposed: outlook.turns,
    );
  }

  static double _projectedPoints(
      List<Tile> concealed, EfficiencyValueContext context) {
    final types = [
      ...concealed.map((t) => t.type),
      ...context.melds.expand((m) => m.types)
    ];
    var faan = 0;
    for (final t in TileType.values.where((t) => t.isHonor)) {
      if (types.where((x) => x == t).length < 3) continue;
      if (t.isDragon) faan++;
      if (t == context.seatWind.tile) faan++;
      if (t == context.roundWind.tile) faan++;
    }
    final suits = types.where((t) => t.isSuit).map((t) => t.suit).toSet();
    if (suits.length == 1) faan += types.any((t) => t.isHonor) ? 3 : 7;
    if (context.closed) faan++;
    if (context.flowersEnabled) {
      if (context.flowers.isEmpty) faan++;
      faan += context.flowers
          .where((t) => t.bonusNumber == context.seatWind.index + 1)
          .length;
      if (context.flowers
              .where((t) => t.isBonus && t.index < TileType.spring.index)
              .length ==
          4) {
        faan += 2;
      }
      if (context.flowers
              .where((t) => t.index >= TileType.spring.index)
              .length ==
          4) {
        faan += 2;
      }
    }
    return 0.65 * HongKongRules.basePoints(faan) * 2 +
        0.35 * HongKongRules.basePoints(faan + 1) * 3;
  }

  // Compatibility anchor for the existing lookahead, with no dora uplift.
  static int _doraKept(List<Tile> concealed, EfficiencyValueContext context) =>
      0;

  static const List<double> _dealInRateByRating = [
    0.070, 0.068, 0.065, 0.058, 0.055, 0.052, 0.048, 0.045, //
    0.038, 0.030, 0.028, 0.025, 0.022, 0.012, 0.006, 0.000,
  ];

  static const double _dealInCost = 16;
  static const double _dealerDealInCost = 16;

  static double _dealInPenalty({
    required SafetyRating? safety,
    required bool opponentIsDealer,
    required int honba,
  }) {
    if (safety == null) return 0;
    final rate = _dealInRateByRating[
        safety.rating.clamp(0, _dealInRateByRating.length - 1)];
    final cost = (opponentIsDealer ? _dealerDealInCost : _dealInCost);
    return rate * cost;
  }

  _ValueAssessment _assessTenpaiValue({
    required List<TileType> waits,
    required List<int> remaining,
    required List<Tile> concealed,
    required bool canRiichi,
    required EfficiencyValueContext context,
    bool opponentRiichi = false,
    bool opponentIsDealer = false,
    double riichiDangerFactor = 0.0,
  }) {
    var liveWaits = 0;
    var points = 0.0;
    for (final wait in waits) {
      final copies = remaining[trainerIndexOf(wait)];
      if (copies <= 0) continue;
      final tile = Tile(-1000 - wait.index, wait);
      final discard = _scoreWait(concealed, tile,
          isTsumo: false, assumeRiichi: false, context: context);
      final self = _scoreWait(concealed, tile,
          isTsumo: true, assumeRiichi: false, context: context);
      if (!discard.valid || !self.valid) continue;
      liveWaits += copies;
      points += copies * (0.65 * discard.points + 0.35 * self.points);
    }
    if (liveWaits == 0) return const _ValueAssessment(plan: 'NO LIVE WAIT');
    points /= liveWaits;
    final outlook = _winChanceOverTurns(
        waitWidth: liveWaits.toDouble(),
        unseen: _countRemaining(remaining),
        draws: math.max(0, (context.wallTilesRemaining + 3) ~/ 4),
        chancesPerTurn: _winChancesPerTurn);
    final expected =
        context.focus.chanceWorth(outlook.win) * context.focus.worth(points);
    return _ValueAssessment(
        expectedValue: expected,
        averagePoints: points,
        damaPoints: points,
        valueTilt: expected - outlook.win * points,
        winProbability: outlook.win,
        plan: 'READY',
        reason:
            'Any complete hand can win, including a zero-faan chicken hand.');
  }

  HandScore _scoreWait(
    List<Tile> concealed,
    Tile winTile, {
    required bool isTsumo,
    required bool assumeRiichi,
    required EfficiencyValueContext context,
  }) {
    final scoreContext = ScoreContext(
      roundWind: context.roundWind,
      seatWind: context.seatWind,
      isTsumo: isTsumo,
      closed: context.closed,
      flowers: context.flowers,
      flowersEnabled: context.flowersEnabled,
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
}

class _ValueAssessment {
  const _ValueAssessment({
    this.expectedValue = 0,
    this.averagePoints = 0,
    required this.plan,
    this.reason = '',
    this.winProbability = 0,
    this.turnsExposed = 0,
    this.damaPoints = 0,
    this.valueTilt = 0,
  });

  final double expectedValue;
  final double averagePoints;
  final String plan;
  bool get recommendRiichi => false;

  final double damaPoints;

  /// How far the [HandFocus] dial moved [expectedValue]. See
  /// [DiscardLine.valueTilt].
  final double valueTilt;

  final double winProbability;
  double get riichiLockCost => 0;

  final double turnsExposed;

  /// Plain-English justification for [plan], shown in the guide panel.
  /// Only populated at tenpai — earlier shanten has nothing to explain yet.
  final String reason;
}
