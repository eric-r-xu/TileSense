/// Turns the raw shanten/ukeire calculator plus the safety model into the typed
/// report the UI renders: best ukeire, recommended discard, riichi hint, and
/// defensive ranking.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'efficiency_calc.dart';
import 'meld.dart';
import 'safety.dart';
import 'scoring.dart';
import 'tile.dart';

/// Round and hand-value inputs used by the discard EV model.
///
/// Ura-dora and situational yaku are deliberately omitted: they are either
/// hidden information or cannot be known for a hypothetical future win.
/// How much weight to give what a discard can cost you, against what the hand
/// can win. It scales every risk the guide charges — the danger of the tile
/// itself, the turns pushing it commits you to, and the cost of locking into a
/// riichi — so one dial moves push/fold, riichi/damaten and call/pass together
/// without changing what any hand is actually worth.
enum PlayStyle {
  /// Folds early and cheaply, and keeps a good hand quiet rather than locking
  /// it into a riichi.
  defensive(riskWeight: 2.0, damatenBar: 0.55, label: 'Defensive'),

  /// The reference model: risk charged at what it is estimated to cost, and
  /// damaten reserved for hands that are already worth a mangan-ish ron.
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

  /// Multiplier on how much a hand must already be worth for damaten to beat
  /// riichi. Below 1 takes damaten readily — quiet, flexible, still able to
  /// fold; above 1 pushes almost everything into a riichi.
  final double damatenBar;

  final String label;

  PlayStyle get next => PlayStyle.values[(index + 1) % PlayStyle.values.length];
}

/// Which hand to chase when two lines are worth the same: the one that gets
/// home, or the one that pays.
///
/// A separate dial from [PlayStyle] because the two really are separate. Risk
/// tolerance is push/fold — how readily you keep firing at a live riichi.
/// This is shape selection — the wide cheap ryanmen against the slow
/// dora-heavy hand — and the archetypes come apart: a tempo player pushes
/// constantly and wants nothing to do with value, while chasing value means
/// sitting in the hand longer and eating more risk to do it.
///
/// The guide's expected value already prices speed against value on one scale:
/// `chance of finishing x what the win pays` takes whichever product is
/// bigger, with no preference either way. So this dial is a deliberate,
/// declared tilt away from that, expressed as a curve over the payout rather
/// than a thumb on the result — see [worth].
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
  static const double _pointsPivot = 5000;

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
    this.honba = 0,
    this.riichiSticks = 0,
    this.style = PlayStyle.balanced,
    this.focus = HandFocus.balanced,
  });

  final List<Meld> melds;
  final Wind roundWind;
  final Wind seatWind;
  final bool isDealer;
  final bool inRiichi;
  final int wallTilesRemaining;
  final List<TileType> doraIndicators;

  /// Repeat counter. Worth 300 to whoever wins the hand — 300 straight from
  /// the discarder on ron, 100 from each of the three on tsumo.
  final int honba;

  /// How heavily to weigh danger against value. See [PlayStyle].
  final PlayStyle style;

  /// Which hand to chase when two are worth the same. See [HandFocus].
  final HandFocus focus;

  /// Riichi deposits already on the table, collected whole by the winner.
  /// A deposit you have not placed yet is not in here; the cost of placing one
  /// is priced separately, against the hands you *don't* win.
  final int riichiSticks;

  /// What winning this hand pays on top of the hand's own value, however it is
  /// won. It rides on the win, so expected value multiplies it by the chance of
  /// getting there — it never changes which hand shape is worth chasing, only
  /// how much the chase is worth.
  int get winBonus => honba * 300 + riichiSticks * 1000;

  bool get closed => melds.every((m) => m.kind == MeldKind.kan && m.concealed);

  /// The same context with a different meld list, and *every* other setting
  /// carried across.
  ///
  /// Exists so it cannot be got wrong. Rebuilding this by hand to score a call
  /// is easy to do and easy to do incompletely — both places that did silently
  /// dropped the honba, the sticks and the play-style dial, so a call was
  /// always weighed as though the dial sat on Balanced and the table had
  /// nothing riding on it.
  EfficiencyValueContext withMelds(List<Meld> melds) => EfficiencyValueContext(
        melds: melds,
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

  /// Plain-English justification for [valuePlan] — why riichi, damaten, etc.
  final String reason;
  SafetyRating? safety;

  /// Points already subtracted from [expectedValue] for the chance this cut
  /// deals into the live riichi. Zero when nobody is in riichi.
  final double dealInCost;

  /// Points subtracted for the turns this cut commits you to *after* this one.
  /// Zero on a safe cut — folding commits you to nothing — and zero once
  /// tenpai, where declaring riichi is priced by [riichiLockCost] instead.
  final double commitmentCost;

  /// The total risk charged against this cut.
  double get riskCost => dealInCost + commitmentCost;

  /// The rest of the arithmetic behind [expectedValue], so the panel can show
  /// its working:
  ///
  ///   expectedValue = winProbability × (averagePoints + winBonus)
  ///                   + valueTilt
  ///                   − riichiLockCost − dealInCost − commitmentCost
  ///
  /// [winProbability] is the chance this line gets home — a win once tenpai, a
  /// completed hand before it. [riichiLockCost] is what declaring riichi costs
  /// against the hands it doesn't win; zero unless the plan is to declare.
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
  /// Safety uses the riichi opponent's complete [opponentDiscards] and only
  /// their [passedDiscardsAfterRiichi], never the table's entire discard history.
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
    final remaining34 = [for (var i = 0; i < 34; i++) 4 - visibleCounts34[i]];
    final concealed = toTrainerCounts(hand);
    final remaining = trainerCountsFromTypeCounts(remaining34);

    // How dangerous your OWN riichi lock-in would be against a live opponent
    // riichi: the weighted-average safety (the same 0..15 scale used for
    // defensive discards) of every tile you might still draw and be forced
    // to tsumogiri, weighted by how many copies remain. 0 = your live draws
    // are all safe right now, 1 = they're all live danger tiles.
    final riichiDangerFactor = opponentRiichi
        ? _riichiDangerFactor(
            remaining34: remaining34,
            opponentDiscards: opponentDiscards,
            passedDiscardsAfterRiichi: passedDiscardsAfterRiichi,
            visibleCounts34: visibleCounts34,
          )
        : 0.0;

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

    // If any discard leaves this hand tenpai, that line is scored exactly —
    // yaku, fu, dora, the lot. Use its payout as the yardstick for the hand's
    // pre-tenpai lines too, so lines at different distances are quoted in the
    // same money and a cheap hand cannot appear to gain by stepping back.
    final tenpaiResult =
        byType.values.where((r) => r.shanten == 0).firstOrNull;
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

    // A 1-shanten line is worth what the tenpai it would actually reach is
    // worth. The pre-tenpai estimator assumes a typical-width wait at the end,
    // so whenever the tenpai on offer right now was narrower than typical,
    // stepping back out of it scored higher — and Autoplay broke tenpai on
    // most turns it could have declared riichi. Only needed when there is a
    // tenpai to be compared with, which keeps the lookahead off most turns.
    //
    // Walked turn by turn: each draw may reach tenpai, and a tenpai reached
    // later has fewer draws left to win on. Valuing it as if it arrived on the
    // very next draw still let a slow 1-shanten out-run a tenpai in hand.
    final hasTenpaiLine = byType.values.any((r) => r.shanten == 0);
    final unseenNow = _countRemaining(remaining);
    final drawsNow = math.max(1, (valueContext.wallTilesRemaining + 3) ~/ 4);
    ({double win, double reached})? tenpaiLookahead(TileEfficiencyResult r) {
      if (!hasTenpaiLine || r.shanten != 1 || unseenNow <= 1) return null;
      final after = toTrainerCounts(_handAfterDiscard(hand, r.discard));
      // One entry per improving draw: its live copies and the widest wait it
      // leaves the hand on.
      final reachable = <({int live, int wait})>[];
      var copies = 0;
      for (final draw in r.improvingTiles) {
        final live = remaining[draw];
        if (live <= 0) continue;
        after[draw]++;
        remaining[draw]--;
        reachable.add((live: live, wait: _calc.bestTenpaiWait(after, remaining)));
        remaining[draw]++;
        after[draw]--;
        copies += live;
      }
      if (copies == 0) return null;

      final step = math.min(1.0, copies / unseenNow);
      var alive = 1.0; // still 1-shanten and the hand still running
      var win = 0.0;
      var reached = 0.0;
      for (var turn = 0; turn < drawsNow; turn++) {
        final hit = alive * step;
        reached += hit;
        final left = drawsNow - 1 - turn;
        if (left > 0) {
          var chance = 0.0;
          for (final e in reachable) {
            chance += e.live *
                _winChanceOverTurns(
                  waitWidth: e.wait.toDouble(),
                  unseen: unseenNow - 1,
                  draws: left,
                  chancesPerTurn: _winChancesPerTurn,
                ).win;
          }
          win += hit * chance / copies;
        }
        alive *= (1 - step) * _handSurvivesTurn;
      }
      return (win: win.clamp(0.0, 1.0), reached: reached.clamp(0.0, 1.0));
    }

    final lines = byType.values.map((r) {
      final afterDiscard = _handAfterDiscard(hand, r.discard);
      final value = _assessValue(
        tenpaiLookahead: tenpaiLookahead(r),
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
      // The tile you choose says whether you are folding or pushing, so it also
      // prices the turns that choice commits you to. A genbutsu cut commits you
      // to nothing; a live one commits you to more of the same.
      //
      // Only for as long as the riichi actually lasts, though, rather than for
      // as long as your own hand might: self-play puts a defending seat at
      // about 3.8 more discards before the hand ends, where the hand's own
      // expected length runs to eight or more. The per-tile rate was right all
      // along; the horizon it was charged over was not.
      final exposed = math.min(value.turnsExposed, _riichiPushHorizon);
      final laterTurns = math.max(0.0, exposed - 1);
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

    // Whether to riichi against a live opponent riichi is now weighed as an
    // expected-value trade-off (see _riichiDangerFactor) rather than blocked
    // outright — a big enough hand can still be worth the extra lock-in risk.
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
    List<TileType> passedDiscardsAfterRiichi = const [],
    bool opponentRiichi = false,
    bool opponentIsDealer = false,
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
    bool opponentIsDealer = false,
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

  /// Whether to fold a matching tile into an existing open pon (shouminkan).
  /// This never changes the hand's shape or waits at all — the triplet was
  /// already committed — so it comes down to two questions any kan raises
  /// (is a fresh dora indicator safe to flip, does the hand still have a
  /// yaku to finish on) plus one unique to adding to an *open* meld: could
  /// the tile you're folding in be ronned straight out from under you
  /// (chankan) before it ever reaches the meld?
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
    final remaining34 = [for (var i = 0; i < 34; i++) 4 - visibleCounts34[i]];
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

    // Chankan risk: this exact tile could be ronned by a live riichi before
    // it ever locks into the meld — rated the same way a discard would be.
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
          reason: 'Chankan risk — ${rating.label} against the live riichi, '
              'not worth risking the tile being ronned.',
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

  /// Effective chances to win per turn once the hand is complete: your own
  /// draw, plus whatever the other three seats actually let you ron — far less
  /// than three discards' worth, since anyone who reads the wait stops feeding
  /// it. Calibrated so an early riichi on a ryanmen wins a little over half the
  /// time, a kanchan around a third, a tanki around a fifth.
  ///
  /// Without a ron — no yaku on the wait, so the hand can only be drawn — you
  /// lose roughly the half of wins that come off someone else's discard.
  static const double _winChancesPerTurn = 1.0;
  static const double _tsumoOnlyChancesPerTurn = 0.5;

  /// How much of a push's later turns to charge for up front.
  ///
  /// Cutting a live tile before tenpai is not one decision, it is the start of
  /// a policy: you will keep discarding into the same riichi for as long as you
  /// stay in the hand. Charging only the tile in front of you undercounts that.
  /// Unlike a declared riichi, though, you can still change your mind next
  /// turn, so the later turns are charged at a discount rather than in full.
  ///
  /// Set so that a typical pre-tenpai push carries about two to three turns of
  /// risk in total, which is where a sweep of random defending positions stops
  /// disagreeing with folding outright.
  static const double _pushCommitment = 0.3;

  /// How many of your own discards a live opponent riichi actually lasts for.
  ///
  /// Measured in self-play rather than assumed: a seat discarding behind a live
  /// riichi gets about 3.8 discards away before the hand ends, and a seat that
  /// declares its own riichi into a live one only about 1.7 — those spots come
  /// late. A hand's own expected length runs two to four times longer than
  /// either, because it is the riichi that ends the hand, not the wall. Pricing
  /// risk against the hand's length instead of the riichi's is what made the
  /// guide walk out of three quarters of the tenpai it held behind a riichi,
  /// most of the time while holding a genbutsu that would have kept it.
  static const double _riichiPushHorizon = 3.8;
  static const double _riichiLockHorizon = 1.7;

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

  /// Weighted-average danger (0 safe .. 1 dangerous) of the tiles you might
  /// still draw and be forced to tsumogiri under your own riichi, rated on
  /// the same 0..15 safety scale [rankSafety] uses for defensive discards.
  double _riichiDangerFactor({
    required List<int> remaining34,
    required List<TileType> opponentDiscards,
    required List<TileType> passedDiscardsAfterRiichi,
    required List<int> visibleCounts34,
  }) {
    final everyType = [
      for (var i = 0; i < 34; i++) Tile(-2000 - i, typeFrom34(i)),
    ];
    final ratingByType = {
      for (final r in rankSafety(
        everyType,
        opponentDiscards: opponentDiscards,
        passedDiscardsAfterRiichi: passedDiscardsAfterRiichi,
        visibleCounts34: visibleCounts34,
      ))
        r.type: r.rating,
    };
    var weightedRating = 0.0;
    var totalWeight = 0;
    for (var i = 0; i < 34; i++) {
      final left = remaining34[i];
      if (left <= 0) continue;
      weightedRating += left * (ratingByType[typeFrom34(i)] ?? 3);
      totalWeight += left;
    }
    if (totalWeight == 0) return 0.0;
    final avgRating = weightedRating / totalWeight;
    return ((15 - avgRating) / 15).clamp(0.0, 1.0);
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
    ({double win, double reached})? tenpaiLookahead,
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

    final yakuPath = context.closed || _hasOpenYakuPath(concealed, context);
    if (!yakuPath) return const _ValueAssessment(plan: 'YAKU NEEDED');

    final unseen = _countRemaining(remaining);
    final draws = math.max(1, (context.wallTilesRemaining + 3) ~/ 4);
    final outlook = _winProbabilityFromShanten(
      shanten: result.shanten,
      ukeire: result.ukeire,
      unseen: unseen,
      draws: draws,
    );
    // The lookahead, when there is one, knows the tenpais this line can really
    // reach and when. It is only trusted to correct the generic estimate
    // downward — the overestimate is what made stepping back out of tenpai
    // look good — and when it does, it supplies both numbers, so the deposit
    // below is billed off the same hand the win is.
    final useLookahead =
        tenpaiLookahead != null && tenpaiLookahead.win < outlook.win;
    final completionProbability =
        useLookahead ? tenpaiLookahead.win : outlook.win;
    final reachedTenpai =
        useLookahead ? tenpaiLookahead.reached : outlook.reachedTenpai;

    // Before tenpai the exact final hand is unknown. These representative
    // values keep pre-tenpai comparisons stable; exact yaku/fu/dora scoring
    // takes over as soon as a discard leaves the hand in tenpai.
    // When some other discard leaves this same hand tenpai we know exactly
    // what it is worth, so use that instead of the table. Otherwise a cheap
    // hand's pre-tenpai lines get credited with an average hand's payout and
    // outrank its own tenpai line, which reads as "break tenpai to rebuild".
    final baseProjectedPoints = projectedPointsOverride ??
        (context.closed
            ? (context.isDealer ? 5800.0 : 3900.0)
            : (context.isDealer ? 2900.0 : 2000.0));

    // Adjusted for the dora this particular line keeps. Without it every
    // pre-tenpai discard is quoted the same payout whatever it throws away, so
    // cutting the red five reads exactly like cutting a junk terminal — and
    // the hand-focus dial has nothing to bite on, because a tilt applied
    // equally to every line reorders none of them.
    //
    // The reference is the tenpai line's own dora count when there is one, so
    // that line keeps its exact score and the others are quoted relative to
    // it; otherwise it is what a hand this shape usually holds.
    final doraDelta = _doraKept(concealed, context) -
        (projectedDoraReference ?? _baselineDora);
    final projectedPoints = baseProjectedPoints *
        math.pow(_doraValueMultiple, doraDelta).toDouble().clamp(0.6, 2.5);

    // A closed hand on this path means to riichi when it arrives, so it owes
    // the same 1000 the tenpai lines are charged — payable once it declares,
    // refunded if it wins. Without this, not being tenpai yet looks cheaper
    // than being tenpai purely because the deposit had not been billed.
    //
    // Billed with care, though. The deposit rides on *reaching tenpai* while
    // the payout rides on *winning*, and the first is far likelier than the
    // second, so charging it in full punished a hand for being close to home:
    // a hopeless line could outscore a good one purely by being too far away
    // to owe anything. Declaring is a choice made at tenpai, not now, and a
    // hand that cannot pay for the stick stays quiet — so cap the charge at
    // what declaring actually buys.
    //
    // Two readings of that uplift, and the *larger* wins. The representative
    // one is what riichi is usually worth; the exact one comes from the tenpai
    // some other discard already reaches, and can be far bigger on a cheap
    // hand — where riichi, ippatsu and ura are most of the payout — so taking
    // it keeps a wide 1-shanten from undercutting the hand's own tenpai. It is
    // never allowed to shrink the charge, because that tenpai is only one of
    // the ones these lines might reach, and the others may well want the
    // stick.
    final deposit = context.closed
        ? math.max(0.0, reachedTenpai - completionProbability) * 1000
        : 0.0;
    // Everything from here is weighed in what the payout is *worth* on the
    // hand-focus dial, not in raw points — including the uplift, so the stick
    // is judged by the same money the line is.
    final worthOfWin = context.focus.worth(projectedPoints);
    final worthOfChance = context.focus.chanceWorth(completionProbability);
    final representativeUplift =
        worthOfWin * (1 - 1 / _riichiValueMultiple);
    final knownUplift = projectedDamaOverride == null
        ? 0.0
        : worthOfWin - context.focus.worth(projectedDamaOverride);
    final riichiUplift = context.closed
        ? math.max(representativeUplift, knownUplift)
        : 0.0;
    // Priced per win: the stick lost for every hand this line wins, capped at
    // what declaring adds to each of those wins, then weighted by the same
    // tilted chance as the win itself. Charging the stick in plain points while
    // the win was tilted mixed the two: on Value — which flattens chance — a
    // line that reached tenpai less often could win less *and* score higher,
    // purely because it owed the stick less often. On Balanced the tilted
    // chance is the plain one, and this is exactly min(deposit, p · uplift).
    final chargedDeposit = completionProbability <= 0
        ? 0.0
        : worthOfChance *
            math.min(deposit / completionProbability, riichiUplift);
    final tilted = worthOfChance * (worthOfWin + context.winBonus);
    final plain =
        completionProbability * (projectedPoints + context.winBonus);

    return _ValueAssessment(
      expectedValue: tilted - chargedDeposit,
      averagePoints: projectedPoints,
      valueTilt: tilted - plain,
      plan: context.closed ? 'RIICHI PATH' : 'YAKU PATH',
      winProbability: completionProbability,
      riichiLockCost: chargedDeposit,
      turnsExposed: outlook.turns,
    );
  }

  /// How much of a closed hand's value comes from declaring — riichi itself,
  /// plus the ippatsu and ura it drags along. Used to bound the deposit
  /// before tenpai, where the hand's exact shape is not yet known and only the
  /// representative payout is on hand.
  static const double _riichiValueMultiple = 1.5;

  /// Dora (indicated plus red fives) held by a hand this shape, on average.
  /// One indicator puts four tiles in a 136-tile wall and you hold thirteen of
  /// them; the three red fives add a little more.
  static const double _baselineDora = 0.6;

  /// What one dora either way does to the payout. A dora is a han, and a han
  /// roughly halves or doubles a hand at the values these estimates sit at —
  /// but these are *averages over unfinished hands*, most of which never get
  /// scored at all, so the swing is damped well below that and bounded at
  /// both ends.
  static const double _doraValueMultiple = 1.8;

  /// Dora and red fives this hand is holding, melds included.
  static int _doraKept(
    List<Tile> concealed,
    EfficiencyValueContext context,
  ) {
    final tiles = [
      ...concealed,
      ...context.melds.expand((meld) => meld.tiles),
    ];
    var count = tiles.where((tile) => tile.aka).length;
    for (final indicator in context.doraIndicators) {
      final target = indicator.doraTarget;
      count += tiles.where((tile) => tile.type == target).length;
    }
    return count;
  }

  /// What a discard costs when it deals in, and how often each safety rating
  /// does. Both are representative averages in the same spirit as the
  /// pre-tenpai `projectedPoints` above — good enough to rank pushes against
  /// folds, not a substitute for a solver.
  ///
  /// The rates are keyed by the 0..15 rating [rankSafety] produces, and follow
  /// the shape the standard tables give: genbutsu never deals in, a non-suji
  /// middle tile is the worst ordinary cut at roughly one in fifteen, and suji
  /// / one-chance / thin honours sit between. Monotonic by construction, so a
  /// tile the safety model calls safer is never charged more.
  static const List<double> _dealInRateByRating = [
    0.070, 0.068, 0.065, 0.058, 0.055, 0.052, 0.048, 0.045, //
    0.038, 0.030, 0.028, 0.025, 0.022, 0.012, 0.006, 0.000,
  ];

  /// Average ron payment to a riichi hand, dealer and non-dealer. Riichi hands
  /// average a little over mangan-adjacent value once ura and ippatsu are in.
  static const double _dealInCost = 5800;
  static const double _dealerDealInCost = 8700;

  /// The points a discard is expected to cost, given how safe it is. Zero
  /// without a live riichi to deal into, and zero on genbutsu.
  static double _dealInPenalty({
    required SafetyRating? safety,
    required bool opponentIsDealer,
    required int honba,
  }) {
    if (safety == null) return 0;
    final rate = _dealInRateByRating[
        safety.rating.clamp(0, _dealInRateByRating.length - 1)];
    // Honba rides on their win too — you pay it.
    final cost =
        (opponentIsDealer ? _dealerDealInCost : _dealInCost) + honba * 300;
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

    if (liveWaits == 0) {
      return const _ValueAssessment(
        plan: 'DEAD WAIT',
        reason: 'No live tiles left for this wait.',
      );
    }

    damaPoints /= liveWaits;
    riichiPoints /= liveWaits;
    final damatenMinimum =
        (context.isDealer ? _dealerDamatenMinPoints : _damatenMinPoints) *
            context.style.damatenBar;
    final qualifyingDamaten = everyDamaRon && minimumDamaRon >= damatenMinimum;

    late final String plan;
    late final double selectedPoints;
    late final bool ronAvailable;
    late final String reason;
    var recommendRiichi = false;
    if (context.inRiichi) {
      plan = 'RIICHI';
      selectedPoints = riichiPoints;
      ronAvailable = true;
      reason = 'Already in riichi — locked into tsumogiri until it hits.';
    } else if (qualifyingDamaten) {
      plan = 'DAMATEN';
      selectedPoints = damaPoints;
      ronAvailable = true;
      reason = 'Damaten — yaku guaranteed and worth ${damaPoints.round()}+ '
          'already, not worth the riichi lock-in.';
    } else if (riichiAvailable) {
      plan = 'RIICHI';
      selectedPoints = riichiPoints;
      ronAvailable = true;
      recommendRiichi = true;
      reason = opponentRiichi
          ? 'Riichi — no qualifying damaten here, and the value still '
              'clears the added risk of the live opponent riichi.'
          : 'Riichi — the only way to guarantee a yaku on this wait.';
    } else if (everyDamaRon) {
      plan = context.closed ? 'DAMATEN' : 'OPEN YAKU';
      selectedPoints = damaPoints;
      ronAvailable = true;
      reason = 'Yaku already secured on every wait.';
    } else if (anyDamaRon) {
      plan = 'PARTIAL YAKU';
      selectedPoints = damaPoints;
      ronAvailable = true;
      reason = 'Only some waits carry a yaku — ron isn\'t guaranteed on '
          'every tile.';
    } else if (anyDamaTsumo) {
      plan = 'TSUMO ONLY';
      selectedPoints = damaPoints;
      ronAvailable = false;
      reason = 'No yaku for ron on any wait — tsumo only.';
    } else {
      return const _ValueAssessment(
        plan: 'NO YAKU',
        reason: 'No yaku on any wait — can\'t declare a win yet.',
      );
    }

    final unseen = _countRemaining(remaining);
    final draws = math.max(1, (context.wallTilesRemaining + 3) ~/ 4);
    final outlook = _winChanceOverTurns(
      waitWidth: liveWaits.toDouble(),
      unseen: unseen,
      draws: draws,
      chancesPerTurn:
          ronAvailable ? _winChancesPerTurn : _tsumoOnlyChancesPerTurn,
    );
    final winProbability = outlook.win;
    // Honba and the riichi deposits already on the table go to the winner
    // whatever the hand is worth, so they scale with the chance of winning it.
    final worthOfWin = context.focus.worth(selectedPoints);
    final worthOfChance = context.focus.chanceWorth(winProbability);
    var expectedValue = worthOfChance * (worthOfWin + context.winBonus);
    final plainValue =
        winProbability * (selectedPoints + context.winBonus);
    var lockCost = 0.0;
    if (recommendRiichi) {
      // Your own deposit, which is not yet in [context.riichiSticks]: you get
      // it back on a win, so it only costs you on the hands you don't win.
      //
      // Capped at what declaring actually buys, because declaring is a choice.
      // A wait too thin or too cheap to pay for the stick just stays quiet, so
      // the deposit can never charge more than the riichi uplift over standing
      // pat — nor, when the wait has no yaku without riichi and standing pat is
      // worth nothing, more than the whole hand. Uncapped, a thin late wait
      // priced out *negative*, and a line with no tenpai to declare at all
      // scored above it.
      //
      // Only the stick is weighed here. What pushing costs against a live
      // riichi is charged below and stays in the line's expected value, where
      // it competes against the folding lines — that trade-off belongs to
      // `analyze`, which can see the alternatives this method cannot.
      final standPat = _standPatValue(
        everyDamaRon: everyDamaRon,
        anyDamaRon: anyDamaRon,
        anyDamaTsumo: anyDamaTsumo,
        damaPoints: damaPoints,
        closed: context.closed,
        liveWaits: liveWaits,
        unseen: unseen,
        draws: draws,
        winBonus: context.winBonus,
        focus: context.focus,
      );
      lockCost += math.max(
        0.0,
        math.min(
          (1 - winProbability) * 1000,
          expectedValue - standPat.expectedValue,
        ),
      );

      // Locking into tsumogiri against a live riichi means every tile you
      // draw from here goes straight out, unlooked at. That is the real cost
      // of declaring, and it is the same arithmetic a single dangerous cut is
      // charged — just repeated for every turn the hand is expected to last.
      if (opponentRiichi) {
        final perDiscard = riichiDangerFactor * _dealInRateByRating.first;
        // You can only deal in once, and only while the riichi you are racing
        // is still live — which is not how long your own hand lasts. Summing a
        // per-turn rate over the hand's full expected length priced the lock at
        // two to three thousand points, more than the hands it was charged
        // against were worth: self-play puts the real figure at 13%, about 900
        // points. The per-tile rate was never the problem; the horizon was.
        final exposed = math.min(outlook.turns, _riichiLockHorizon);
        final dealsIn = 1 - math.pow(1 - perDiscard, exposed).toDouble();
        lockCost += dealsIn *
            (opponentIsDealer ? _dealerDealInCost : _dealInCost) *
            context.style.riskWeight;
      }
      expectedValue -= lockCost;
    }

    return _ValueAssessment(
      expectedValue: expectedValue,
      averagePoints: selectedPoints,
      plan: plan,
      recommendRiichi: recommendRiichi,
      reason: reason,
      winProbability: winProbability,
      riichiLockCost: lockCost,
      valueTilt: worthOfChance * (worthOfWin + context.winBonus) - plainValue,
      damaPoints: damaPoints,
      // Staying tenpai without declaring still commits you to discarding for
      // the rest of the hand — less than a riichi does, since you can still
      // back out, but not nothing. Declaring is priced by [riichiLockCost]
      // instead, so only one of the two ever applies.
      turnsExposed: recommendRiichi ? 0 : outlook.turns,
    );
  }

  /// What this tenpai is worth if it never declares — the alternative every
  /// riichi is measured against. Mirrors the non-riichi arms of
  /// [_assessTenpaiValue]: a wait with no yaku at all cannot be won on, so it
  /// is worth nothing rather than worth less than nothing.
  static _ValueAssessment _standPatValue({
    required bool everyDamaRon,
    required bool anyDamaRon,
    required bool anyDamaTsumo,
    required double damaPoints,
    required bool closed,
    required int liveWaits,
    required int unseen,
    required int draws,
    required int winBonus,
    required HandFocus focus,
  }) {
    final String plan;
    final String reason;
    final bool ronAvailable;
    if (everyDamaRon) {
      plan = closed ? 'DAMATEN' : 'OPEN YAKU';
      ronAvailable = true;
      reason = 'Damaten — declaring costs more than the riichi is worth on '
          'this wait.';
    } else if (anyDamaRon) {
      plan = 'PARTIAL YAKU';
      ronAvailable = true;
      reason = 'Staying quiet — riichi costs more than it buys here, and only '
          'some waits carry a yaku without it.';
    } else if (anyDamaTsumo) {
      plan = 'TSUMO ONLY';
      ronAvailable = false;
      reason = 'Staying quiet — riichi costs more than it buys here, so this '
          'wait is tsumo only.';
    } else {
      return const _ValueAssessment(
        plan: 'NO YAKU',
        reason: 'Riichi costs more than it buys on this wait, and there is no '
            'yaku without it.',
      );
    }

    final outlook = _winChanceOverTurns(
      waitWidth: liveWaits.toDouble(),
      unseen: unseen,
      draws: draws,
      chancesPerTurn:
          ronAvailable ? _winChancesPerTurn : _tsumoOnlyChancesPerTurn,
    );
    final worth = focus.worth(damaPoints);
    final chance = focus.chanceWorth(outlook.win);
    return _ValueAssessment(
      expectedValue: chance * (worth + winBonus),
      averagePoints: damaPoints,
      valueTilt: chance * (worth + winBonus) -
          outlook.win * (damaPoints + winBonus),
      plan: plan,
      reason: reason,
      winProbability: outlook.win,
      turnsExposed: outlook.turns,
      damaPoints: damaPoints,
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
    this.reason = '',
    this.winProbability = 0,
    this.riichiLockCost = 0,
    this.turnsExposed = 0,
    this.damaPoints = 0,
    this.valueTilt = 0,
  });

  final double expectedValue;
  final double averagePoints;
  final String plan;
  final bool recommendRiichi;

  /// What this same wait pays without declaring. Only a tenpai assessment
  /// knows it exactly; the pre-tenpai lines of the same hand borrow it so the
  /// riichi uplift they cap the deposit against is this hand's, not a
  /// representative one.
  final double damaPoints;

  /// How far the [HandFocus] dial moved [expectedValue]. See
  /// [DiscardLine.valueTilt].
  final double valueTilt;

  /// The two terms the panel shows its arithmetic with: how often this line
  /// gets home, and what declaring riichi on it costs against the hands it
  /// does not win. Together with [averagePoints] and the deal-in cost they
  /// reconstruct [expectedValue] exactly.
  final double winProbability;
  final double riichiLockCost;

  /// How many more turns this line expects to still be in the hand, and so how
  /// many more discards it commits you to. Zero once tenpai — declaring riichi
  /// is priced by [riichiLockCost] instead.
  final double turnsExposed;

  /// Plain-English justification for [plan], shown in the guide panel.
  /// Only populated at tenpai — earlier shanten has nothing to explain yet.
  final String reason;
}
