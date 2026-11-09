/// The guide under Fuzhou rules. Fuzhou's Gold tiles are wild, which the
/// ordinary shanten and expected-value model has no idea about, so
/// `EfficiencyEngine` hands every Fuzhou decision here before it touches
/// anything riichi-, Hong Kong- or Taiwanese-shaped.
///
/// A line is ranked by expected points: the chance the hand gets home in the
/// draws it has left, times what a win pays, less what the discard risks
/// against the other seats' exposed sets. The shanten and acceptance behind it
/// count the Gold tiles in hand as the wilds they are (and a Gold still unseen
/// as an out), through `FuzhouEfficiency`.
///
/// It is an estimate, not a calibrated model: the win chance treats every step
/// as drawing to the current outs, and the payoff counts what the hand has
/// banked (flowers, Golds, streak, kongs) but not the special hands. It is
/// meant to rank discards sensibly, not to quote odds.
library;

import 'dart:math' as math;

import 'package:mahjong_core/fuzhou/fuzhou_efficiency.dart';
import 'package:mahjong_core/fuzhou/fuzhou_rules.dart';
import 'package:mahjong_core/fuzhou/fuzhou_scoring.dart';
import 'package:mahjong_core/round.dart';
import 'package:mahjong_core/scoring.dart';
import 'package:mahjong_core/tile.dart';

import 'efficiency_engine.dart';

/// What the table shows of another seat: how many sets it has exposed, and
/// what it has thrown. The guide prices a discard's danger from this.
class FuzhouRival {
  const FuzhouRival({required this.melds, required this.thrown});

  final int melds;
  final Set<TileType> thrown;

  /// Every other seat, as [mySeat] sees the table.
  static List<FuzhouRival> of(Round round, int mySeat) => [
        for (final s in round.seats)
          if (s.seat != mySeat && round.isActive(s.seat))
            FuzhouRival(
              melds: s.melds.where((m) => !m.concealed).length,
              thrown: {for (final t in s.allDiscards) t.type},
            ),
      ];
}

class FuzhouGuide {
  /// Gold tiles still unseen from [mySeat]: those in no pond, no flower row and
  /// not in its own hand. A suit or honor Gold has three in play (the fourth is
  /// the face-up indicator); a flipped flower makes seven others Gold.
  static int goldLeft(Round round, int mySeat) {
    final gold = round.goldTypes;
    if (gold.isEmpty) return 0;
    final total = gold.any((t) => t.isBonus) ? gold.length : 3;
    var seen = round.seats[mySeat].hand.where((t) => gold.contains(t.type)).length;
    for (final s in round.seats) {
      seen += s.pond.where((t) => gold.contains(t.type)).length;
      seen += s.flowers.where((t) => gold.contains(t.type)).length;
    }
    return (total - seen).clamp(0, total);
  }

  /// Own draws left in the hand, for a wall of [remaining] tiles shared by
  /// four seats.
  static int draws(int remaining) => remaining ~/ 4;

  /// Chance a seat with [melds] exposed sets is ready on any given tile it is
  /// offered, per set beyond the first. A rough dial, not a measurement.
  static const dealInPerSet = 0.035;

  /// What a rival's win costs the seat that deals in.
  static const rivalPayout = 22.0;

  /// Share of wins that are self-draws, which every other seat pays.
  static const selfDrawShare = 0.4;

  /// Share of the improving draws that actually carry a hand a step closer.
  /// Uncalibrated: chosen so a hand three away is not a sure thing.
  static const stepFactor = 0.4;

  /// Chance a draw carries the hand a later step closer, once past the first.
  static const laterStep = 0.2;

  /// Chance, per own turn, that another seat wins first. Fuzhou hands end
  /// fast: wild Golds make them easy.
  static const handEnds = 0.05;

  /// Win chance multiplier on a line that discards a Gold: it may only win by
  /// self-draw from then on.
  static const goldDiscardPenalty = 0.55;

  static List<int> _live34(List<int> visibleCounts34, Set<TileType> gold) => [
        for (var i = 0; i < 34; i++)
          i >= 27 || gold.contains(typeFrom34(i))
              ? 0
              : (4 - visibleCounts34[i]).clamp(0, 4),
      ];

  /// Chance of at least [need] successes in [draws] tries. The first success
  /// comes at [first] a try, every later one at [later] — a hand's next steps
  /// are not known yet, so they are taken at a typical width.
  static double reach(int need, int draws, double first, [double? later]) {
    if (need <= 0) return 1;
    if (draws < need) return 0;
    final rest = (later ?? first).clamp(0.0, 0.95);
    first = first.clamp(0.0, 0.95);
    // dp[k] = chance of exactly k (capped at need) successes so far.
    var dp = List<double>.filled(need + 1, 0)..[0] = 1;
    for (var t = 0; t < draws; t++) {
      final next = List<double>.filled(need + 1, 0);
      for (var k = 0; k <= need; k++) {
        if (dp[k] == 0) continue;
        if (k == need) {
          next[need] += dp[k];
        } else {
          final p = k == 0 ? first : rest;
          next[k] += dp[k] * (1 - p);
          next[k + 1] += dp[k] * p;
        }
      }
      dp = next;
    }
    return dp[need];
  }

  /// What a win is worth to this hand, per hand: the doubled total it has
  /// banked, paid by one seat on a discard or three on a self-draw.
  static double payoff(EfficiencyValueContext c, int golds) {
    final kongs = c.melds
        .where((m) => m.isKan)
        .fold<int>(0, (a, m) =>
            a +
            (m.concealed
                ? FuzhouRules.concealedKongPoints
                : FuzhouRules.openKongPoints));
    final streak = c.isDealer ? c.honba : 0;
    final banked = FuzhouRules.basePoints +
        c.flowers.length * FuzhouRules.flowerPoint +
        FuzhouRules.fullBloomSets(c.flowers) * FuzhouRules.fullBloomPoints +
        golds * FuzhouRules.goldPoint +
        streak +
        kongs;
    final pay = banked * 2.0;
    return pay * (selfDrawShare * 3 + (1 - selfDrawShare));
  }

  static double dealInCost(TileType tile, List<FuzhouRival> rivals) {
    var cost = 0.0;
    for (final r in rivals) {
      if (r.thrown.contains(tile)) continue;
      final sets = r.melds;
      if (sets < 2) continue;
      cost += (sets - 1) * dealInPerSet * rivalPayout;
    }
    return cost;
  }

  static int _goldsIn(List<Tile> hand, Set<TileType> gold) =>
      hand.where((t) => gold.contains(t.type)).length;

  /// How a hand of [rest] (concealed tiles between draws) with [melds]
  /// declared stands: its shanten and outs, the chance it wins, and what that
  /// is worth.
  static ({
    int shanten,
    int outs,
    List<TileType> accepts,
    double win,
    double pay,
    double ev
  }) stand({
    required List<Tile> rest,
    required int openMelds,
    required List<int> visibleCounts34,
    required EfficiencyValueContext context,
    int extraDraws = 0,
    bool goldDiscarded = false,
  }) {
    final gold = context.goldTypes;
    final live = _live34(visibleCounts34, gold);
    final accept = FuzhouEfficiency.acceptance(rest,
        openMelds: openMelds,
        gold: gold,
        live34: live,
        goldLeft: context.goldLeft);
    final shanten =
        FuzhouEfficiency.shanten(rest, openMelds: openMelds, gold: gold);
    final unseen =
        live.fold<int>(0, (a, b) => a + b) + context.goldLeft;
    final d = draws(context.wallTilesRemaining) + extraDraws;
    final p0 = unseen == 0 ? 0.0 : accept.count / unseen;
    // An accepted draw is not always taken and later steps are narrower than
    // the first, so a step lands at [stepFactor] of the outs' share; and the
    // hand may end first, with another seat's win.
    var win = reach(shanten + 1, d, p0 * stepFactor, laterStep) *
        math.pow(1 - handEnds, d).toDouble();
    if (goldDiscarded) win *= goldDiscardPenalty;
    final pay = payoff(context, _goldsIn(rest, gold));
    return (
      shanten: shanten,
      outs: accept.count,
      accepts: accept.tiles,
      win: win,
      pay: pay,
      ev: win * pay,
    );
  }

  static List<DiscardLine> _lines({
    required List<Tile> hand,
    required int openMelds,
    required List<int> visibleCounts34,
    required EfficiencyValueContext context,
  }) {
    final gold = context.goldTypes;
    final live = _live34(visibleCounts34, gold);
    final raw = FuzhouEfficiency.lines(hand,
        openMelds: openMelds,
        gold: gold,
        live34: live,
        goldLeft: context.goldLeft);
    final lines = <DiscardLine>[];
    for (final line in raw) {
      final tile = hand.firstWhere((t) => t.type == line.discard);
      final rest = [...hand]..remove(tile);
      final isGold = gold.contains(line.discard);
      final standing = stand(
        rest: rest,
        openMelds: openMelds,
        visibleCounts34: visibleCounts34,
        context: context,
        goldDiscarded: isGold,
      );
      final danger = dealInCost(line.discard, context.fuzhouRivals);
      lines.add(DiscardLine(
        discard: line.discard,
        shanten: standing.shanten,
        ukeire: standing.outs,
        accepts: standing.accepts,
        expectedValue: standing.ev - danger,
        averagePoints: standing.pay,
        valuePlan: standing.shanten <= 0 ? 'READY' : 'BUILD HAND',
        recommendRiichi: false,
        reason: _reason(standing.shanten, standing.outs, standing.win, danger,
            isGold),
        dealInCost: danger,
        winProbability: standing.win,
      ));
    }
    lines.sort((a, b) {
      final c = b.expectedValue.compareTo(a.expectedValue);
      if (c != 0) return c;
      final s = a.shanten.compareTo(b.shanten);
      return s != 0 ? s : b.ukeire.compareTo(a.ukeire);
    });
    return lines;
  }

  static String _reason(
      int shanten, int outs, double win, double danger, bool gold) {
    final parts = <String>[
      if (gold)
        'A Gold is wild — throwing one limits you to winning by self-draw.',
      if (shanten <= 0)
        'Ready on $outs live tiles — about ${(win * 100).round()}% to win.'
      else
        '$shanten away on $outs live tiles — about '
            '${(win * 100).round()}% to win.',
      if (danger >= 0.5)
        'Risks about ${danger.toStringAsFixed(1)} points of dealing in.',
    ];
    return parts.join(' ');
  }

  static EfficiencyReport analyze({
    required List<Tile> hand,
    required List<int> visibleCounts34,
    required EfficiencyValueContext context,
  }) {
    final lines = _lines(
      hand: hand,
      openMelds: context.melds.length,
      visibleCounts34: visibleCounts34,
      context: context,
    );
    if (lines.isNotEmpty) {
      lines.first.recommended = true;
      lines.first.bestExpectedValue = true;
      final best = lines.map((l) => l.ukeire).reduce((a, b) => a > b ? a : b);
      for (final l in lines) {
        l.bestUkeire = l.ukeire == best;
      }
    }
    final shanten = lines.isEmpty
        ? 99
        : lines.map((l) => l.shanten).reduce((a, b) => a < b ? a : b);
    return EfficiencyReport(
      lines: lines,
      currentShanten: shanten,
      tenpai: shanten <= 0,
      recommendRiichi: false,
      defending: false,
      defense: const [],
      headline: _goldHeadline(context),
    );
  }

  static String? _goldHeadline(EfficiencyValueContext c) {
    if (c.goldTypes.isEmpty) return null;
    return 'Gold tiles in hand are wild. ${c.goldLeft} still unseen.';
  }

  static double _bestAfterDiscard({
    required List<Tile> hand,
    required int openMelds,
    required List<int> visibleCounts34,
    required EfficiencyValueContext context,
  }) {
    final lines = _lines(
        hand: hand,
        openMelds: openMelds,
        visibleCounts34: visibleCounts34,
        context: context);
    return lines.isEmpty ? 0 : lines.first.expectedValue;
  }

  static HandScore _score(List<Tile> concealed, Tile win,
      EfficiencyValueContext context,
      {required bool isTsumo}) {
    return scoreFuzhouHand(
      concealed,
      win,
      context.melds,
      ScoreContext(
        roundWind: context.roundWind,
        seatWind: context.seatWind,
        isTsumo: isTsumo,
        closed: context.melds.every((m) => m.concealed),
        flowers: context.flowers,
      ),
      isDealer: context.isDealer,
      fuzhou: FuzhouScoreContext(
        goldTypes: context.goldTypes,
        dealerContinuation: context.isDealer ? context.honba : 0,
      ),
    );
  }

  static CallAdvice adviseCall({
    required List<Tile> hand,
    required Tile offered,
    required Set<GuidedAction> available,
    required List<int> visibleCounts34,
    required EfficiencyValueContext context,
  }) {
    if (available.contains(GuidedAction.ron)) {
      final score = _score(hand, offered, context, isTsumo: false);
      final value = score.valid ? score.points : 0;
      return CallAdvice(recommended: GuidedAction.ron, options: [
        ActionAdvice(
          action: GuidedAction.ron,
          expectedValue: value.toDouble(),
          shantenAfter: -1,
          reason: 'Hu — $value points from the discarder.',
        ),
      ]);
    }

    final open = context.melds.length;
    final pass = stand(
        rest: hand,
        openMelds: open,
        visibleCounts34: visibleCounts34,
        context: context);
    final options = <ActionAdvice>[];

    ActionAdvice meldAdvice(GuidedAction action, List<Tile> consumed,
        {required String verb, int extraDraws = 0}) {
      final rest = [...hand];
      for (final t in consumed) {
        rest.remove(t);
      }
      final lines = _lines(
          hand: rest,
          openMelds: open + 1,
          visibleCounts34: visibleCounts34,
          context: context);
      final best = lines.isEmpty ? null : lines.first;
      final ev = best?.expectedValue ?? 0;
      final shanten = best?.shanten ?? 99;
      final better = ev > pass.ev + 0.01 && shanten <= pass.shanten;
      return ActionAdvice(
        action: action,
        expectedValue: ev,
        shantenAfter: shanten,
        eligible: better,
        discardAfter: best?.discard,
        reason: better
            ? '$verb — ${(ev - pass.ev).toStringAsFixed(1)} points better '
                'than passing, and you stay ${_far(shanten)} after the '
                'discard.'
            : '$verb — does not improve on passing.',
      );
    }

    final natural = hand.where((t) => !context.goldTypes.contains(t.type));
    if (available.contains(GuidedAction.kan)) {
      final consumed = natural.where((t) => t.type == offered.type).take(3).toList();
      options.add(meldAdvice(GuidedAction.kan, consumed,
          verb: 'Kong (1 point, and a draw from the tail)', extraDraws: 1));
    }
    if (available.contains(GuidedAction.pon)) {
      final consumed = natural.where((t) => t.type == offered.type).take(2).toList();
      options.add(meldAdvice(GuidedAction.pon, consumed, verb: 'Pung'));
    }
    if (available.contains(GuidedAction.chi)) {
      // Whichever run the table plays by default: the first the hand can make.
      final run = _firstRun(natural.toList(), offered.type);
      if (run != null) {
        options.add(meldAdvice(GuidedAction.chi, run, verb: 'Chow'));
      }
    }
    options.add(ActionAdvice(
      action: GuidedAction.pass,
      expectedValue: pass.ev,
      shantenAfter: pass.shanten,
      reason: 'Pass — you stay ${_far(pass.shanten)}.',
    ));

    var best = GuidedAction.pass;
    var bestEv = pass.ev;
    for (final o in options) {
      if (o.action != GuidedAction.pass && o.eligible && o.expectedValue > bestEv) {
        best = o.action;
        bestEv = o.expectedValue;
      }
    }
    options.sort((a, b) {
      if (a.action == best) return -1;
      if (b.action == best) return 1;
      return 0;
    });
    return CallAdvice(recommended: best, options: options);
  }

  static List<Tile>? _firstRun(List<Tile> hand, TileType offered) {
    if (!offered.isSuit) return null;
    final base = offered.index - offered.number;
    for (var offset = -2; offset <= 0; offset++) {
      final low = offered.number + offset;
      if (low < 1 || low + 2 > 9) continue;
      final taken = <Tile>[];
      var ok = true;
      for (var i = 0; i < 3; i++) {
        final need = TileType.values[base + low + i];
        if (need == offered) continue;
        final at = hand.indexWhere((t) => t.type == need && !taken.contains(t));
        if (at < 0) {
          ok = false;
          break;
        }
        taken.add(hand[at]);
      }
      if (ok) return taken;
    }
    return null;
  }

  static String _far(int shanten) =>
      shanten <= 0 ? 'ready' : '$shanten away from ready';

  static ActionAdvice adviseKan({
    required List<Tile> hand,
    required TileType kanType,
    required List<int> visibleCounts34,
    required EfficiencyValueContext context,
    required bool concealed,
  }) {
    final open = context.melds.length;
    final rest = [...hand]..removeWhere((t) => t.type == kanType);
    final melds = context.melds.length + (concealed ? 1 : 0);
    final after = stand(
      rest: rest,
      openMelds: concealed ? melds : open,
      visibleCounts34: visibleCounts34,
      context: context,
      extraDraws: 1,
    );
    final points = (concealed
            ? FuzhouRules.concealedKongPoints
            : FuzhouRules.openKongPoints) *
        2.0;
    final gain = after.ev + after.win * points;
    final keep = _bestAfterDiscard(
        hand: hand,
        openMelds: open,
        visibleCounts34: visibleCounts34,
        context: context);
    final delta = gain - keep;
    return ActionAdvice(
      action: GuidedAction.kan,
      expectedValue: gain,
      shantenAfter: after.shanten,
      eligible: delta > 0,
      reason: 'Kong — worth ${(points / 2).round()} point'
          '${points == 2 ? '' : 's'} (doubled) if you win, and a replacement '
          'draw from the tail. ${delta >= 0 ? '+' : ''}'
          '${delta.toStringAsFixed(1)} points against not.',
    );
  }

  static ActionAdvice adviseTsumo({
    required List<Tile> hand,
    required Tile drawn,
    required EfficiencyValueContext context,
  }) {
    final concealed = [...hand]..remove(drawn);
    final score = _score(concealed, drawn, context, isTsumo: true);
    final each = score.valid ? score.points : 0;
    return ActionAdvice(
      action: GuidedAction.tsumo,
      expectedValue: (each * 3).toDouble(),
      shantenAfter: -1,
      reason: 'Self-pick — $each points from each of the other three. '
          'Always take the win.',
    );
  }
}
