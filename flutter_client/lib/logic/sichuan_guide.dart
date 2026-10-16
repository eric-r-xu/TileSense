/// The guide under Sichuan rules: shanten and acceptance on the hand that
/// can actually win, with the void suit counted as dead weight. There is no
/// expected-value model yet (see BOT_STRATEGY.md), so the discard table ranks
/// by distance from ready, then by how many live tiles improve the hand, and
/// every value column reads zero. `EfficiencyEngine` hands its Sichuan work
/// here before it touches anything riichi-, Hong Kong- or Taiwanese-shaped.
library;

import 'package:mahjong_core/efficiency_calc.dart';
import 'package:mahjong_core/scoring.dart';
import 'package:mahjong_core/sichuan/sichuan_efficiency.dart';
import 'package:mahjong_core/sichuan/sichuan_rules.dart';
import 'package:mahjong_core/sichuan/sichuan_scoring.dart';
import 'package:mahjong_core/tile.dart';

import 'efficiency_engine.dart';

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

  static List<int> _countsAfter(List<Tile> hand, Tile? remove, int? voidSuit) {
    final counts = toTrainerCounts(hand);
    if (remove != null) counts[trainerIndexOf(remove.type)]--;
    return _deadify(counts, voidSuit);
  }

  static EfficiencyReport analyze({
    required List<Tile> hand,
    required List<int> visibleCounts34,
    required EfficiencyValueContext context,
  }) {
    final v = context.voidSuit;
    final remaining = _remaining(visibleCounts34, v);
    final holdsVoid = v != null && hand.any((t) => t.type.suit == v);
    final seen = <TileType>{};
    final lines = <DiscardLine>[];
    for (final tile in hand) {
      if (!seen.add(tile.type)) continue;
      // The void suit goes first: nothing else may be discarded while it is
      // held.
      if (holdsVoid && tile.type.suit != v) continue;
      final counts = _countsAfter(hand, tile, v);
      final shanten = _calc.calculateWaitingShanten(counts);
      final accept = _calc.acceptance(counts, remaining);
      lines.add(DiscardLine(
        discard: tile.type,
        shanten: shanten,
        ukeire: accept.count,
        accepts: [for (final i in accept.tiles) typeFromTrainerIndex(i)],
        expectedValue: 0,
        averagePoints: 0,
        valuePlan: shanten <= 0 ? 'READY' : 'BUILD HAND',
        recommendRiichi: false,
        reason: holdsVoid ? 'Void suit goes first.' : '',
      ));
    }
    lines.sort((a, b) {
      final c = a.shanten.compareTo(b.shanten);
      return c != 0 ? c : b.ukeire.compareTo(a.ukeire);
    });
    if (lines.isNotEmpty) {
      lines.first.recommended = true;
      lines.first.bestExpectedValue = true;
      final best = lines.map((l) => l.ukeire).reduce((a, b) => a > b ? a : b);
      for (final l in lines) {
        l.bestUkeire = l.ukeire == best;
      }
    }
    final shanten = lines.isEmpty ? 99 : lines.first.shanten;
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

  static int _shantenOf(List<Tile> hand, int? v) =>
      _calc.calculateWaitingShanten(_countsAfter(hand, null, v));

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
    final passShanten = _shantenOf(hand, v);
    final isVoid = v != null && offered.type.suit == v;
    GuidedAction best = GuidedAction.pass;
    if (available.contains(GuidedAction.kan)) {
      options.add(ActionAdvice(
        action: GuidedAction.kan,
        expectedValue: 0,
        shantenAfter: passShanten,
        eligible: !isVoid,
        reason: isVoid
            ? 'A kong of your void suit can never win.'
            : 'Kong — the discarder pays you 2 at the end, if you are ready '
                'or Hu.',
      ));
      if (!isVoid) best = GuidedAction.kan;
    }
    if (available.contains(GuidedAction.pon)) {
      var after = 99;
      if (!isVoid) {
        final rest = List<Tile>.of(hand);
        for (var i = 0; i < 2; i++) {
          rest.removeAt(rest.indexWhere((t) => t.type == offered.type));
        }
        final report = analyze(
            hand: rest, visibleCounts34: visibleCounts34, context: context);
        after = report.lines.isEmpty ? 99 : report.lines.first.shanten;
      }
      final helps = after < passShanten;
      options.add(ActionAdvice(
        action: GuidedAction.pon,
        expectedValue: 0,
        shantenAfter: after,
        eligible: helps,
        discardAfter: null,
        reason: isVoid
            ? 'A pung of your void suit can never win.'
            : helps
                ? 'Pung — brings you from ${_far(passShanten)} to ${_far(after)}.'
                : 'Pung — does not bring you closer to ready.',
      ));
      if (helps && best == GuidedAction.pass) best = GuidedAction.pon;
    }
    options.add(ActionAdvice(
      action: GuidedAction.pass,
      expectedValue: 0,
      shantenAfter: passShanten,
      reason: 'Pass — you stay ${_far(passShanten)}.',
    ));
    options.sort((a, b) {
      if (a.action == best) return -1;
      if (b.action == best) return 1;
      return 0;
    });
    return CallAdvice(recommended: best, options: options);
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
    return ActionAdvice(
      action: GuidedAction.kan,
      expectedValue: 0,
      shantenAfter: _shantenOf(hand, v),
      reason: concealed
          ? 'Kong — every player still in pays you $pay at the end, if you '
              'are ready or Hu. It takes a tile from the tail.'
          : 'Kong — worth $pay from each player still in only if the added '
              'tile is the one you just drew, and it can be robbed.',
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
      expectedValue: (each * 3).toDouble(),
      shantenAfter: -1,
      reason: 'Self-draw Hu — $each points from each player still in. '
          'Always take the win.',
    );
  }

  static HandScore _score(List<Tile> concealed, Tile win,
          EfficiencyValueContext context,
          {required bool isTsumo}) =>
      scoreSichuanHand(
          concealed,
          win,
          context.melds,
          ScoreContext(
            roundWind: context.roundWind,
            seatWind: context.seatWind,
            isTsumo: isTsumo,
            closed: context.closed,
          ));
}
