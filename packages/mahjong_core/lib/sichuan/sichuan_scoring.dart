/// Sichuan scoring: add up the fan, then turn the total into a hand value
/// (0 -> 1, 1 -> 2, 2 -> 4, 3 or more -> 8 points). Fan travel in
/// [HandScore.han]; the hand value is [HandScore.points], which is also what
/// every payer owes (a self-draw's extra point is added in `round.dart`).
///
/// Fan: Root (1 for each set of four identical tiles in the hand, whether or
/// not they are a kong), All Pungs 1, Full Flush 2, Seven Pairs 2, Golden
/// Single Wait 2 (four melds out, the win completes the pair; it already
/// includes All Pungs' fan), Win after Kong 1, Robbing the Kong 1, Shoot after
/// Kong 1, Under the Sea 1. There is no minimum to win.
library;

import '../meld.dart';
import '../scoring.dart';
import '../tile.dart';
import 'sichuan_hand_parse.dart';
import 'sichuan_rules.dart';

/// Score a Sichuan win. [concealed] excludes the winning tile and all declared
/// melds, as in the other rulesets. An illegal arrangement comes back invalid.
/// The void-suit rule is the caller's: a hand holding its voided suit may not
/// win, and `round.dart` checks that before it asks for a score.
HandScore scoreSichuanHand(
    List<Tile> concealed, Tile winTile, List<Meld> openMelds, ScoreContext ctx) {
  final all = [...concealed, winTile];
  if (openMelds.length > 4 ||
      all.length != 14 - openMelds.length * 3 ||
      all.any((t) => !t.type.isSuit)) {
    return HandScore.invalid();
  }
  for (final m in openMelds) {
    if (m.kind == MeldKind.pair || m.isSequence || !m.low.isSuit) {
      return HandScore.invalid();
    }
  }
  final types = [...all.map((t) => t.type), ...openMelds.expand((m) => m.types)];
  final counts = <TileType, int>{};
  for (final t in types) {
    counts[t] = (counts[t] ?? 0) + 1;
  }
  if (counts.values.any((n) => n > 4)) return HandScore.invalid();

  final roots = counts.values.where((n) => n == 4).length;
  final oneSuit = types.map((t) => t.suit).toSet().length == 1;

  HandScore? best;
  for (final d in decomposeSichuan(toCounts34(all), openMelds: openMelds.length)) {
    final patterns = <YakuResult>[];
    void add(String name, int fan) => patterns.add(YakuResult(name, fan));

    for (var i = 0; i < roots; i++) {
      add('Root', 1);
    }
    if (oneSuit) add('Full Flush', 2);

    if (d.sevenPairs) {
      add('Seven Pairs', 2);
    } else {
      final groups = [...openMelds, ...d.melds];
      final allPungs = groups.every((m) => m.isTripletLike);
      final goldenSingle = openMelds.length == 4 && d.pair == winTile.type;
      if (goldenSingle) {
        // Already includes the fan for All Pungs.
        add('Golden Single Wait', 2);
      } else if (allPungs) {
        add('All Pungs', 1);
      }
    }

    if (ctx.isTsumo) {
      if (ctx.rinshan) add('Win after Kong', 1);
      if (ctx.haitei) add('Under the Sea', 1);
    } else {
      if (ctx.chankan) add('Robbing the Kong', 1);
      if (ctx.afterKong && !ctx.chankan) add('Shoot after Kong', 1);
      if (ctx.houtei) add('Under the Sea', 1);
    }

    final fan = patterns.fold(0, (int n, p) => n + p.faan);
    final value = SichuanRules.handValue(fan);
    final score = HandScore(
      yaku: patterns,
      han: fan,
      fu: 0,
      yakuman: 0,
      points: value,
      dealerPays: value,
      nonDealerPays: value,
      limitName: '',
      valid: true,
    );
    if (best == null || score.faan > best.faan) best = score;
  }
  return best ?? HandScore.invalid();
}
