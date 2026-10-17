/// The arithmetic behind the Sichuan guide's expected value (EXPECTED_VALUE.md,
/// "Under Sichuan rules"): how likely a hand is to get home before the wall
/// runs out, what a Hu pays, what the end of the hand settles, and what a
/// discard risks against the seats that are ready.
///
/// It is pure formulas over numbers and tiles. The shanten and acceptance it
/// is fed come from `SichuanGuide`, and every constant here is one measured by
/// `test/sichuan_calibration_test.dart` from SimpleBot self-play (the table is
/// in EXPECTED_VALUE.md) or one of the dials `sichuan_tuning_sweep_test.dart`
/// moves.
///
/// The one thing that makes this different from the other rulesets' models:
/// another seat's Hu does not end your hand. A Hu seat leaves, the rest play
/// on, and the hand ends only when the wall does or three have won. So the
/// clock on a hand is the wall, not the other seats, and the question a
/// discard asks is "how likely am I to get home in the draws I have left, and
/// what do I pay if I feed someone on the way".
library;

import 'dart:math';

import 'package:mahjong_core/mahjong_core.dart';

/// Every constant the model uses, so a sweep can move one at a time and a
/// reader can find them in one place. The defaults are the shipped values.
class SichuanValueTuning {
  /// How much of a rival's discards reach a ready seat's wait, per rival, as
  /// a share of one more draw. Fitted: 0.81 reproduces how often a ready seat
  /// actually wins (71.9% over 4000 hands).
  static double ronPerRival = 0.81;

  /// Live tiles on the wait of a typical hand that reaches ready, and the
  /// width of each step before it ([stepWidth], index = shanten before the
  /// step, 1..6).
  ///
  /// These are ranking weights, not calibrated probabilities. They were chosen
  /// by play: against SimpleBot over 3000 games they gain about +1.2 points a
  /// game. Fitting them instead to how often a SimpleBot hand at each shanten
  /// goes on to win (`sichuan_calibration_test.dart`: tenpaiWait 5.9, steps
  /// 25 / 64 / 120) reproduces those win rates, and plays far worse: -10
  /// points a game, and 0.42 wins a hand against 0.65. Matching the level is
  /// not matching the slope; a model that thinks every hand eventually gets
  /// home stops caring which discard gets it there first. Adding a per-turn
  /// chance that the hand ends first ([handEnds] 0.04-0.06, widths refitted)
  /// made it worse still, -12 to -14. So the win chance the panel quotes is a
  /// good figure for a hand ready or one step off (67% against 62%, and 46%
  /// against 54%) and an understatement beyond that (18% where hands two away
  /// win 58%); the guide does not quote it there.
  static double tenpaiWait = 4.3;
  static List<double> stepWidth = [0, 5.5, 8.5, 11, 13, 15, 17];

  /// Chance, each turn, that the hand ends before you finish — three other
  /// seats have won and you are the one left over. It is what makes speed
  /// matter in a game with a long wall: without it every hand eventually gets
  /// home and the shape of the hand stops mattering.
  static double handEnds = 0.0;

  /// A draw that is one of your outs is taken at most this often; keeps a
  /// freak count from promising more than a draw can.
  static double maxStep = 0.9;

  /// Value of a Hu is 1 + this times what the hand's shape suggests it will
  /// score above 1 (0 = every Hu is worth the base; 1 = the full estimate).
  static double valueScale = 1.0;

  /// Chance multiplier per off-suit tile left in a hand for a full flush to
  /// still be on. Swept at 0.15-0.72 over 3000 games each: 0.2-0.4 all gain
  /// about a point a game on SimpleBot; 0.72 (a flush looks 10% likely with
  /// seven off-suit tiles) loses 12.
  static double flushDecay = 0.3;
  static double flushWeight = 1.0;

  /// All pungs and seven pairs, as potential. Both measured as losses (-1.75
  /// and -0.76 points a game): chasing them costs more wins than the extra
  /// fan pays. Off; the code stays so the sweep can re-test them.
  static double pungWeight = 0.0;
  static double pairsWeight = 0.0;

  /// Charged against a discard: this much of the expected points it deals
  /// into the ready seats. 0 turns defence off; 1 prices it as measured.
  static double dealInScale = 1.0;

  /// What a ready rival's Hu costs you, in points (their mean hand is 1.37;
  /// the ready hands that survive to a wall end average 1.69).
  static double rivalValue = 1.5;

  /// Pick the void suit by how the other two suits play out (shanten, then
  /// acceptance), not by which suit has fewest tiles. Off falls back to
  /// `Round.suggestVoidSuit`.
  static bool guideVoidPick = true;

  /// How a hand that has not been won is settled at the wall, and how often
  /// that is where it ends.
  static bool endSettlement = true;
  static double wallEndShare = 0.5;
  static double rivalReadyAtEnd = 0.776;
  static double readyValue = 1.69;
}

/// What the table shows of another seat — nothing here is read from a hand
/// the viewer cannot see, and nothing from a void suit its owner has not yet
/// revealed with a first discard.
class SichuanRival {
  const SichuanRival({
    required this.seat,
    required this.out,
    required this.voidSuit,
    required this.discards,
    required this.thrown,
    required this.melds,
  });

  final int seat;

  /// Has declared Hu and no longer plays.
  final bool out;

  /// The suit this seat gave up, once its first discard has shown it.
  final int? voidSuit;

  /// Discards made so far, counting any that were called away.
  final int discards;

  /// The tile types this seat has discarded.
  final Set<TileType> thrown;

  /// Melds shown.
  final int melds;

  /// Every other seat, as [mySeat] sees the table.
  static List<SichuanRival> of(Round round, int mySeat) => [
        for (final s in round.seats)
          if (s.seat != mySeat)
            SichuanRival(
              seat: s.seat,
              out: s.out,
              voidSuit: s.voidRevealed ? s.voidSuit : null,
              discards: s.allDiscards.length,
              thrown: {for (final t in s.allDiscards) t.type},
              melds: s.melds.length,
            ),
      ];
}

/// Fan for the shapes the potential estimate chases (see
/// `sichuan_scoring.dart`).
const _flushFan = 2;
const _allPungsFan = 1;
const _sevenPairsFan = 2;

class SichuanValue {
  static bool get guideVoidPickOn => SichuanValueTuning.guideVoidPick;

  /// Chance a seat is ready after its n-th discard (n = 0..20), measured over
  /// 4000 hands of SimpleBot play, among the seats still in.
  static const readyByDiscards = [
    0.0, 0.001, 0.008, 0.026, 0.062, 0.12, 0.19, 0.27, 0.35, 0.43, 0.50, //
    0.56, 0.62, 0.67, 0.72, 0.76, 0.80, 0.84, 0.86, 0.89, 0.92,
  ];

  /// How often one discard completes a ready seat that is not void in its
  /// suit, by how central the tile is (measured). A tile that seat has
  /// already thrown completes it 0.6% of the time against 12.2% for a fresh
  /// one.
  static double hitRate(TileType t) {
    switch (t.number) {
      case 1:
      case 9:
        return 0.081;
      case 2:
      case 8:
        return 0.112;
      case 3:
      case 7:
        return 0.159;
      default:
        return 0.135;
    }
  }

  static const thrownFactor = 0.05;

  /// Chance [r] is ready now, from how many discards it has made and what it
  /// has shown: each meld brings it closer.
  static double readyChance(SichuanRival r) {
    if (r.out) return 0;
    final base = readyByDiscards[min(r.discards, readyByDiscards.length - 1)];
    return min(0.97, base * (1 + 0.12 * r.melds));
  }

  /// Points a discard of [tile] is expected to pay out: for each rival still
  /// in, the chance it is ready, completes on this tile, and takes it, times
  /// what its Hu costs. A suit the rival gave up can never complete it; one it
  /// has not shown yet may be any, so two in three.
  static double dealInCost(TileType tile, List<SichuanRival> rivals) {
    var cost = 0.0;
    for (final r in rivals) {
      if (r.out) continue;
      var p = readyChance(r);
      if (p == 0) continue;
      if (r.voidSuit == tile.suit) continue;
      if (r.voidSuit == null) p *= 2 / 3;
      var hit = hitRate(tile);
      if (r.thrown.contains(tile)) hit *= thrownFactor;
      cost += p * hit * SichuanValueTuning.rivalValue;
    }
    return cost * SichuanValueTuning.dealInScale;
  }

  /// Draws you have left: the wall is shared by the seats still in.
  static int draws(int wallRemaining, int rivalsIn) =>
      max(1, (wallRemaining / (rivalsIn + 1)).ceil());

  /// The chance a hand [shanten] steps from ready, with [outs] live tiles on
  /// its first step, wins within [draws] of its own turns, and the chance it
  /// is standing ready (unwon) when they run out.
  ///
  /// Each turn a hand at step k moves to k-1 with width/unseen — the actual
  /// [outs] on the first step, the typical width for its step after that —
  /// and a ready hand wins with its wait over unseen, plus what the other
  /// seats' discards add per rival.
  static ({double win, double ready}) chain({
    required int shanten,
    required int outs,
    required int unseen,
    required int draws,
    required int rivals,
    int waitingWidth = 0,
  }) {
    if (shanten < 0) return (win: 1, ready: 0);
    final u = max(unseen, 1).toDouble();
    final ron = 1 + SichuanValueTuning.ronPerRival * rivals;
    final cap = SichuanValueTuning.maxStep;
    // mass[k]: probability of standing k steps from ready. Index 0 = ready.
    final top = min(shanten, 6);
    final mass = List<double>.filled(top + 1, 0)..[top] = 1;
    var win = 0.0;
    for (var turn = 0; turn < draws; turn++) {
      final next = List<double>.filled(top + 1, 0);
      for (var k = 0; k <= top; k++) {
        final m = mass[k];
        if (m == 0) continue;
        if (k == 0) {
          final width = shanten == 0
              ? outs.toDouble()
              : (waitingWidth > 0
                  ? waitingWidth.toDouble()
                  : SichuanValueTuning.tenpaiWait);
          final q = min(cap, width / u * ron);
          win += m * q;
          next[0] += m * (1 - q);
        } else {
          final width =
              k == top ? outs.toDouble() : SichuanValueTuning.stepWidth[k];
          final a = min(cap, width / u);
          next[k - 1] += m * a;
          next[k] += m * (1 - a);
        }
      }
      final survive = 1 - SichuanValueTuning.handEnds;
      for (var k = 0; k <= top; k++) {
        mass[k] = next[k] * survive;
      }
    }
    return (win: win, ready: mass[0]);
  }

  /// What a Hu of value [v] pays you, on average: a self-draw pays each of the
  /// [rivals] still in v + 1, a Hu off a discard pays v from the discarder only.
  /// Ron wins arrive in the proportion the model gave them.
  static double payoff(double v, int rivals) {
    final ron = SichuanValueTuning.ronPerRival * rivals;
    final selfDrawn = 1 / (1 + ron);
    return selfDrawn * (v + SichuanRules.selfDrawBonus) * rivals +
        (1 - selfDrawn) * v;
  }

  /// What the end of an unwon hand is worth to a seat that is [ready] when
  /// the wall runs out: the ready seat collects from each seat that is not,
  /// and the rest pay each ready seat what it was ready for. Charged only for
  /// the share of unwon hands that end on the wall rather than on a third Hu.
  static double endValue({
    required double pReady,
    required double pUnready,
    required double readyValue,
    required int rivals,
  }) {
    if (!SichuanValueTuning.endSettlement) return 0;
    final rho = SichuanValueTuning.rivalReadyAtEnd;
    final gain = readyValue * rivals * (1 - rho);
    final loss = SichuanValueTuning.readyValue * rivals * rho;
    return SichuanValueTuning.wallEndShare * (pReady * gain - pUnready * loss);
  }

  /// Value of a hand that is ready: the average over its waits, weighted by
  /// the live copies of each, of what that Hu scores. [live34] counts the
  /// copies of every tile still unseen. Returns the live outs as well.
  static ({double value, int outs}) waitValue({
    required List<Tile> rest,
    required List<Meld> melds,
    required List<int> live34,
    required ScoreContext context,
  }) {
    var outs = 0;
    var total = 0.0;
    for (final w in waitTilesSichuan(rest, openMelds: melds.length)) {
      final live = live34[w.index - 1].clamp(0, 4);
      if (live == 0) continue;
      final score = scoreSichuanHand(rest, Tile(9000 + w.index, w), melds, context);
      final v = score.valid ? score.points : 1;
      outs += live;
      total += live * v;
    }
    return (value: outs == 0 ? 1.0 : total / outs, outs: outs);
  }

  /// What a hand that is not ready yet is likely to be worth when it is: the
  /// roots it already holds, plus its chances of a flush, all pungs or seven
  /// pairs, each read off the shape of what is in hand. Never below 1.
  static double potentialValue(
      List<Tile> rest, List<Meld> melds, int? voidSuit) {
    final counts = <TileType, int>{};
    for (final t in rest) {
      // A Sichuan wall holds no honors; a hand posed with one (the builder)
      // simply gets nothing from it.
      if (!t.type.isSuit) continue;
      if (voidSuit != null && t.type.suit == voidSuit) continue;
      counts[t.type] = (counts[t.type] ?? 0) + 1;
    }
    var roots = counts.values.where((n) => n == 4).length;
    var trips = counts.values.where((n) => n >= 3).length;
    var pairs = counts.values.where((n) => n == 2).length;
    var pairUnits = counts.values.fold<int>(0, (a, n) => a + n ~/ 2);
    for (final m in melds) {
      if (m.kind == MeldKind.kan) roots++;
      if (m.isTripletLike) trips++;
    }

    final scale = SichuanValueTuning.valueScale;
    final extras = <(double, int)>[];

    // Full flush: one suit only, melds included.
    final meldSuits = {for (final m in melds) m.low.suit};
    if (meldSuits.length <= 1) {
      final bySuit = List<int>.filled(3, 0);
      for (final e in counts.entries) {
        bySuit[e.key.suit] += e.value;
      }
      var dominant = 0;
      for (var s = 1; s < 3; s++) {
        if (bySuit[s] > bySuit[dominant]) dominant = s;
      }
      if (meldSuits.length == 1) dominant = meldSuits.first;
      final minor = bySuit.fold<int>(0, (a, b) => a + b) - bySuit[dominant];
      final p = pow(SichuanValueTuning.flushDecay, minor) *
          SichuanValueTuning.flushWeight;
      if (p > 0.02) extras.add((min(1.0, p) * scale, _flushFan));
    }

    // All pungs: every set a pung. Pairs can still become one; a tile that
    // joins its neighbours cannot.
    final linked = counts.entries.where((e) {
      if (e.value != 1) return false;
      for (final o in counts.keys) {
        if (o.suit == e.key.suit && (o.number - e.key.number).abs() <= 2 && o != e.key) {
          return true;
        }
      }
      return false;
    }).length;
    final pung = ((trips + 0.5 * pairs) / 4 - 0.12 * linked).clamp(0.0, 0.9);
    if (pung > 0.05) {
      extras.add((pung * SichuanValueTuning.pungWeight * scale, _allPungsFan));
    }

    // Seven pairs: closed, and already most of the way.
    if (melds.isEmpty && pairUnits >= 4) {
      final p = ((pairUnits - 3) / 3).clamp(0.0, 1.0) * SichuanValueTuning.pairsWeight;
      extras.add((p * scale, _sevenPairsFan));
    }

    // Expected value over the extras, taken as independent.
    var expected = 0.0;
    for (var mask = 0; mask < (1 << extras.length); mask++) {
      var p = 1.0;
      var fan = roots;
      for (var i = 0; i < extras.length; i++) {
        if (mask & (1 << i) != 0) {
          p *= extras[i].$1;
          fan += extras[i].$2;
        } else {
          p *= 1 - extras[i].$1;
        }
      }
      expected += p * SichuanRules.handValue(fan);
    }
    return max(1.0, expected);
  }
}
