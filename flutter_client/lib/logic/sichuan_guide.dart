/// The guide under Sichuan rules. Every line, call and kong is ranked by
/// expected points: the chance the hand gets home before the wall runs out,
/// what that Hu pays, what an unwon hand settles for at the wall, less what
/// the discard risks against the seats that are ready (`sichuan_value.dart`,
/// and EXPECTED_VALUE.md, "Under Sichuan rules"). The void suit counts as
/// dead weight and goes first, as the rules insist. `EfficiencyEngine` hands
/// its Sichuan work here before it touches anything riichi-, Hong Kong- or
/// Taiwanese-shaped.
library;

import 'package:mahjong_core/efficiency_calc.dart';
import 'package:mahjong_core/meld.dart';
import 'package:mahjong_core/scoring.dart';
import 'package:mahjong_core/sichuan/sichuan_efficiency.dart';
import 'package:mahjong_core/sichuan/sichuan_rules.dart';
import 'package:mahjong_core/sichuan/sichuan_scoring.dart';
import 'package:mahjong_core/tile.dart';

import 'efficiency_engine.dart';
import 'sichuan_value.dart';

/// Where a hand stands: how far from ready, how likely to get home, and what
/// getting home pays.
class _Standing {
  _Standing({
    required this.shanten,
    required this.outs,
    required this.win,
    required this.ready,
    required this.value,
    required this.payoff,
    required this.ev,
  });

  final int shanten;
  final int outs;

  /// Chance of a Hu in the draws left, and of standing ready when they run out.
  final double win;
  final double ready;

  /// Mean hand value of that Hu, and what it pays across the table.
  final double value;
  final double payoff;

  /// Expected points, before any discard's danger.
  final double ev;
}

class SichuanGuide {
  static final _calc = SichuanEfficiencyCalculator();

  /// Live tiles by type, minus the void suit (nobody draws toward it).
  static List<int> _remaining(List<int> visibleCounts34, int? voidSuit) =>
      withoutVoidSuit(
          trainerCountsFromTypeCounts([
            for (var i = 0; i < 34; i++) (4 - visibleCounts34[i]).clamp(0, 4)
          ]),
          voidSuit);

  /// [counts] with every void-suit tile turned into an isolated dead tile (a
  /// lone honor slot, which this wall never holds). The hand keeps its size,
  /// so the calculator still reads its open melds correctly, but the dead
  /// tiles join nothing.
  static List<int> _deadify(List<int> counts, int? voidSuit) {
    if (voidSuit == null) return counts;
    final out = List<int>.of(counts);
    var dead = 0;
    for (var n = 1; n <= 9; n++) {
      dead += out[voidSuit * 10 + n];
      out[voidSuit * 10 + n] = 0;
    }
    for (var i = 0; i < dead; i++) {
      out[31 + i % 7]++;
    }
    return out;
  }

  /// The suit to give up from [hand] (13 tiles, or 14 for the dealer): the one
  /// whose loss leaves the rest of the hand nearest to ready, then widest,
  /// then costing the fewest tiles. The void tiles count as dead weight, so a
  /// suit holding the hand's best sets is never the one given up. [fallback]
  /// is the rule it replaces (fewest tiles) when the dial is off.
  static int suggestVoidSuit(List<Tile> hand, {required int fallback}) {
    if (!SichuanValue.guideVoidPickOn) return fallback;
    final own = toTrainerCounts(hand);
    var best = fallback;
    (int, int, int)? bestKey;
    for (var suit = 0; suit < 3; suit++) {
      final counts = _deadify(own, suit);
      final remaining = withoutVoidSuit(
          [for (var i = 0; i < 38; i++) i % 10 == 0 || i > 29 ? 0 : 4 - own[i]],
          suit);
      var shanten = 99;
      var ukeire = 0;
      if (hand.length % 3 == 2) {
        for (final r in _calc.calculate(counts, remaining)) {
          if (r.shanten < shanten ||
              (r.shanten == shanten && r.ukeire > ukeire)) {
            shanten = r.shanten;
            ukeire = r.ukeire;
          }
        }
      } else {
        shanten = _calc.calculateWaitingShanten(counts);
        ukeire = _calc.acceptance(counts, remaining).count;
      }
      final voided = hand.where((t) => t.type.suit == suit).length;
      final key = (shanten, -ukeire, voided);
      if (bestKey == null || _less(key, bestKey)) {
        bestKey = key;
        best = suit;
      }
    }
    return best;
  }

  static bool _less((int, int, int) a, (int, int, int) b) =>
      a.$1 != b.$1 ? a.$1 < b.$1 : a.$2 != b.$2 ? a.$2 < b.$2 : a.$3 < b.$3;

  static List<int> _countsOf(List<Tile> hand, int? voidSuit) =>
      _deadify(toTrainerCounts(hand), voidSuit);

  static ScoreContext _scoreContext(
          EfficiencyValueContext context, List<Meld> melds,
          {required bool isTsumo}) =>
      ScoreContext(
        roundWind: context.roundWind,
        seatWind: context.seatWind,
        isTsumo: isTsumo,
        closed: melds.every((m) => m.kind == MeldKind.kan && m.concealed),
      );

  /// Seats still playing besides this one. With no table to read (a bare
  /// context), the other three.
  static int _rivalsIn(EfficiencyValueContext context) =>
      context.sichuanRivals.isEmpty
          ? 3
          : context.sichuanRivals.where((r) => !r.out).length;

  /// How a hand of [rest] (the concealed tiles between draws) stands with
  /// [melds] declared. [extraDraws] adds draws it has not yet counted, such as
  /// a kong's replacement.
  static _Standing _stand({
    required List<Tile> rest,
    required List<Meld> melds,
    required List<int> visibleCounts34,
    required EfficiencyValueContext context,
    int extraDraws = 0,
  }) {
    final v = context.voidSuit;
    final counts = _countsOf(rest, v);
    final shanten = _calc.calculateWaitingShanten(counts);
    final accept = _calc.acceptance(counts, _remaining(visibleCounts34, v));
    final rivals = _rivalsIn(context);
    final unseen =
        108 - visibleCounts34.fold<int>(0, (a, b) => a + b);
    final voidLeft =
        v == null ? 0 : rest.where((t) => t.type.suit == v).length;

    // A hand still holding its void suit cannot win until every one of those
    // tiles has gone, and it goes one a turn.
    final draws = (SichuanValue.draws(context.wallTilesRemaining, rivals) +
            extraDraws -
            voidLeft)
        .clamp(0, 99);

    var value = SichuanValue.potentialValue(rest, melds, v);
    var outs = accept.count;
    if (shanten == 0 && voidLeft == 0) {
      final live34 = [for (final n in visibleCounts34) 4 - n];
      final wait = SichuanValue.waitValue(
        rest: rest,
        melds: melds,
        live34: live34,
        context: _scoreContext(context, melds, isTsumo: false),
      );
      if (wait.outs > 0) {
        value = wait.value;
        outs = wait.outs;
      }
    }

    final chain = SichuanValue.chain(
      shanten: shanten,
      outs: outs,
      unseen: unseen,
      draws: draws,
      rivals: rivals,
    );
    final payoff = SichuanValue.payoff(value, rivals);
    final end = SichuanValue.endValue(
      pReady: chain.ready,
      pUnready: (1 - chain.win - chain.ready).clamp(0.0, 1.0),
      readyValue: value,
      rivals: rivals,
    );
    return _Standing(
      shanten: shanten,
      outs: outs,
      win: chain.win,
      ready: chain.ready,
      value: value,
      payoff: payoff,
      ev: chain.win * payoff + end,
    );
  }

  static List<Tile> _without(List<Tile> hand, Tile tile) =>
      List<Tile>.of(hand)..remove(tile);

  /// Every distinct discard from [hand] (the void suit first, when the rules
  /// require it), scored and best first.
  static List<DiscardLine> _lines({
    required List<Tile> hand,
    required List<Meld> melds,
    required List<int> visibleCounts34,
    required EfficiencyValueContext context,
  }) {
    final v = context.voidSuit;
    final holdsVoid = v != null && hand.any((t) => t.type.suit == v);
    final remaining = _remaining(visibleCounts34, v);
    final seen = <TileType>{};
    final lines = <DiscardLine>[];
    for (final tile in hand) {
      if (!seen.add(tile.type)) continue;
      // The void suit goes first: nothing else may be discarded while it is
      // held.
      if (holdsVoid && tile.type.suit != v) continue;
      final rest = _without(hand, tile);
      final standing = _stand(
        rest: rest,
        melds: melds,
        visibleCounts34: visibleCounts34,
        context: context,
      );
      final danger = SichuanValue.dealInCost(tile.type, context.sichuanRivals);
      final counts = _countsOf(rest, v);
      final accept = _calc.acceptance(counts, remaining);
      lines.add(DiscardLine(
        discard: tile.type,
        shanten: standing.shanten,
        ukeire: accept.count,
        accepts: [for (final i in accept.tiles) typeFromTrainerIndex(i)],
        expectedValue: standing.ev - danger,
        averagePoints: standing.payoff,
        valuePlan: standing.shanten <= 0 ? 'READY' : 'BUILD HAND',
        recommendRiichi: false,
        reason: _reason(standing, danger, holdsVoid),
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

  static String _reason(_Standing s, double danger, bool holdsVoid) {
    final parts = <String>[
      if (holdsVoid) 'Void suit goes first.',
      if (s.shanten <= 0)
        'Ready on ${s.outs} live tiles — about '
            '${(s.win * 100).round()}% to win.'
      else
        '${s.shanten} away — about ${(s.win * 100).round()}% to get home.',
      if (danger >= 0.05)
        'Risks about ${danger.toStringAsFixed(2)} points of dealing in.',
    ];
    return parts.join(' ');
  }

  static EfficiencyReport analyze({
    required List<Tile> hand,
    required List<int> visibleCounts34,
    required EfficiencyValueContext context,
  }) {
    final v = context.voidSuit;
    final holdsVoid = v != null && hand.any((t) => t.type.suit == v);
    final lines = _lines(
      hand: hand,
      melds: context.melds,
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
      headline: holdsVoid ? 'Discard your void suit first.' : null,
    );
  }

  /// The best a hand can do by discarding one of [hand]'s tiles, danger
  /// included; null when it has nothing to discard.
  static double? _bestAfterDiscard(
      {required List<Tile> hand,
      required List<Meld> melds,
      required List<int> visibleCounts34,
      required EfficiencyValueContext context}) {
    final lines = _lines(
        hand: hand,
        melds: melds,
        visibleCounts34: visibleCounts34,
        context: context);
    return lines.isEmpty ? null : lines.first.expectedValue;
  }

  static int _shantenOf(List<Tile> hand, int? v) =>
      _calc.calculateWaitingShanten(_countsOf(hand, v));

  static CallAdvice adviseCall({
    required List<Tile> hand,
    required Tile offered,
    required Set<GuidedAction> available,
    required List<int> visibleCounts34,
    required EfficiencyValueContext context,
  }) {
    final v = context.voidSuit;
    final hu = _score(hand, offered, context, isTsumo: false);
    final options = <ActionAdvice>[];
    if (available.contains(GuidedAction.ron)) {
      final value = hu.valid ? hu.points : 0;
      return CallAdvice(recommended: GuidedAction.ron, options: [
        ActionAdvice(
          action: GuidedAction.ron,
          expectedValue: value.toDouble(),
          shantenAfter: -1,
          reason: 'Hu — $value points from the discarder.',
        ),
        const ActionAdvice(
            action: GuidedAction.pass,
            expectedValue: 0,
            shantenAfter: 0,
            reason:
                'Pass — and you may not Hu this tile again unless a later one is worth more.'),
      ]);
    }

    final isVoid = v != null && offered.type.suit == v;
    final pass = _stand(
      rest: hand,
      melds: context.melds,
      visibleCounts34: visibleCounts34,
      context: context,
    );
    final rivals = _rivalsIn(context);

    // Each way of taking the tile, and what the hand is worth afterwards.
    double? ponEv;
    int ponShanten = 99;
    double? kanEv;
    if (!isVoid && available.contains(GuidedAction.pon)) {
      final rest = _without(_without(hand, _firstOf(hand, offered.type)),
          _firstOf(hand, offered.type, skip: 1));
      final melds = [
        ...context.melds,
        Meld(kind: MeldKind.triplet, low: offered.type, concealed: false),
      ];
      ponEv = _bestAfterDiscard(
          hand: rest,
          melds: melds,
          visibleCounts34: visibleCounts34,
          context: context);
      ponShanten = _shantenOf(rest, v);
    }
    if (!isVoid && available.contains(GuidedAction.kan)) {
      final rest = List<Tile>.of(hand)
        ..removeWhere((t) => t.type == offered.type);
      final melds = [
        ...context.melds,
        Meld(kind: MeldKind.kan, low: offered.type, concealed: false),
      ];
      final after = _stand(
        rest: rest,
        melds: melds,
        visibleCounts34: visibleCounts34,
        context: context,
        extraDraws: 1,
      );
      // An open kong is paid by the discarder alone, and only if the hand
      // finishes a Hu or ready.
      kanEv = after.ev +
          (after.win + after.ready) * SichuanRules.meldedKongPayment;
    }

    if (available.contains(GuidedAction.kan)) {
      options.add(ActionAdvice(
        action: GuidedAction.kan,
        expectedValue: kanEv ?? 0,
        shantenAfter: _shantenOf(hand, v),
        eligible: !isVoid,
        reason: isVoid
            ? 'A kong of your void suit can never win.'
            : 'Kong — the discarder pays you '
                '${SichuanRules.meldedKongPayment} at the end if you are '
                'ready or Hu, and you draw again from the tail.',
      ));
    }
    if (available.contains(GuidedAction.pon)) {
      options.add(ActionAdvice(
        action: GuidedAction.pon,
        expectedValue: ponEv ?? 0,
        shantenAfter: ponShanten,
        eligible: ponEv != null && ponEv > pass.ev,
        discardAfter: null,
        reason: isVoid
            ? 'A pung of your void suit can never win.'
            : ponEv != null && ponEv > pass.ev
                ? 'Pung — worth ${(ponEv - pass.ev).toStringAsFixed(2)} '
                    'points more than passing.'
                : 'Pung — does not improve on passing.',
      ));
    }
    options.add(ActionAdvice(
      action: GuidedAction.pass,
      expectedValue: pass.ev,
      shantenAfter: pass.shanten,
      reason: 'Pass — you stay ${_far(pass.shanten)}'
          '${rivals > 0 ? ', about ${(pass.win * 100).round()}% to win' : ''}.',
    ));

    var best = GuidedAction.pass;
    var bestEv = pass.ev;
    if (kanEv != null && kanEv > bestEv) {
      best = GuidedAction.kan;
      bestEv = kanEv;
    }
    if (ponEv != null && ponEv > bestEv) {
      best = GuidedAction.pon;
    }
    options.sort((a, b) {
      if (a.action == best) return -1;
      if (b.action == best) return 1;
      return 0;
    });
    return CallAdvice(recommended: best, options: options);
  }

  static Tile _firstOf(List<Tile> hand, TileType type, {int skip = 0}) =>
      hand.where((t) => t.type == type).elementAt(skip);

  static String _far(int shanten) =>
      shanten <= 0 ? 'ready' : '$shanten away from ready';

  /// A kong on your own turn: the tiles of [kanType] leave the hand for a meld
  /// and you draw once more, against discarding as you would have.
  static ActionAdvice adviseKan({
    required List<Tile> hand,
    required TileType kanType,
    required List<int> visibleCounts34,
    required EfficiencyValueContext context,
    required bool concealed,
  }) {
    final v = context.voidSuit;
    if (v != null && kanType.suit == v) {
      return const ActionAdvice(
        action: GuidedAction.kan,
        expectedValue: 0,
        shantenAfter: 99,
        eligible: false,
        reason: 'A kong of your void suit can never win.',
      );
    }
    final pay = concealed
        ? SichuanRules.concealedKongPayment
        : SichuanRules.addedKongPayment;
    final rivals = _rivalsIn(context);

    final rest = List<Tile>.of(hand)..removeWhere((t) => t.type == kanType);
    final melds = [
      for (final m in context.melds)
        // An added kong grows a pung already shown.
        if (concealed || m.low != kanType) m,
      Meld(kind: MeldKind.kan, low: kanType, concealed: concealed),
    ];
    final after = _stand(
      rest: rest,
      melds: melds,
      visibleCounts34: visibleCounts34,
      context: context,
      extraDraws: 1,
    );
    var gain = after.ev + (after.win + after.ready) * pay * rivals;
    // An added kong can be robbed by a seat that is ready on the tile.
    if (!concealed) {
      gain -= SichuanValue.dealInCost(kanType, context.sichuanRivals);
    }
    final keep = _bestAfterDiscard(
        hand: hand,
        melds: context.melds,
        visibleCounts34: visibleCounts34,
        context: context);
    final delta = keep == null ? 0.0 : gain - keep;
    return ActionAdvice(
      action: GuidedAction.kan,
      expectedValue: gain,
      shantenAfter: after.shanten,
      eligible: keep == null || delta > 0,
      reason: concealed
          ? 'Kong — every player still in pays you $pay at the end, if you '
              'are ready or Hu. It takes a tile from the tail. '
              '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(2)} points '
              'against not.'
          : 'Kong — worth $pay from each player still in only if the added '
              'tile is the one you just drew, and it can be robbed. '
              '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(2)} points '
              'against not.',
    );
  }

  static ActionAdvice adviseTsumo({
    required List<Tile> hand,
    required Tile drawn,
    required EfficiencyValueContext context,
  }) {
    final concealed = List<Tile>.of(hand)..remove(drawn);
    final score = _score(concealed, drawn, context, isTsumo: true);
    final each = (score.valid ? score.points : 0) + SichuanRules.selfDrawBonus;
    return ActionAdvice(
      action: GuidedAction.tsumo,
      expectedValue: (each * _rivalsIn(context)).toDouble(),
      shantenAfter: -1,
      reason: 'Self-draw Hu — $each points from each player still in. '
          'Always take the win.',
    );
  }

  static HandScore _score(List<Tile> concealed, Tile win,
          EfficiencyValueContext context,
          {required bool isTsumo}) =>
      scoreSichuanHand(concealed, win, context.melds,
          _scoreContext(context, context.melds, isTsumo: isTsumo));
}
