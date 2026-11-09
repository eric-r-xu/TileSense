/// Fuzhou scoring for a 17-tile hand (five melds and a pair, Gold tiles
/// standing in for any tile), following Mahjong Pros' guide:
///
///     payout = ((base + flowers + golds + dealer streak + kongs) x 2)
///              + special hands
///
/// A win by discard is paid by the discarder alone; a self-draw is paid by
/// every other seat, each the same amount — there is no dealer premium (the
/// dealer's streak is already in the formula) and no minimum to win. Shares
/// [ScoreContext], [HandScore] and [YakuResult] with the other rulesets;
/// points travel in the `han` fields.
///
/// The guide's worked example scores "All Sequences" at 15 although its own
/// table says 10; the table wins here.
library;

import '../meld.dart';
import '../scoring.dart';
import '../tile.dart';
import 'fuzhou_hand_parse.dart';
import 'fuzhou_rules.dart';

/// What Fuzhou scoring needs beyond [ScoreContext].
class FuzhouScoreContext {
  const FuzhouScoreContext({
    this.goldTypes = const {},
    this.dealerContinuation = 0,
    this.robbingGold = false,
  });

  /// The tile types that are wild this hand.
  final Set<TileType> goldTypes;

  /// The dealer's consecutive wins (0 for anyone else): one point each.
  final int dealerContinuation;

  /// The win is Robbing the Gold: taken off the flipped Gold before the
  /// winner's first draw.
  final bool robbingGold;
}

/// Score a Fuzhou win. [concealed] excludes the winning tile and all declared
/// melds. [ctx.flowers] are the winner's exposed flowers (honors included);
/// [ctx.heavenly] and [ctx.earthly] mark the first-turn blessings.
HandScore scoreFuzhouHand(
    List<Tile> concealed, Tile winTile, List<Meld> openMelds, ScoreContext ctx,
    {required bool isDealer,
    FuzhouScoreContext fuzhou = const FuzhouScoreContext()}) {
  final all = [...concealed, winTile];
  if (openMelds.length > 5 ||
      all.length != 17 - openMelds.length * 3 ||
      all.any((t) => !t.type.isPlayingTile && !fuzhou.goldTypes.contains(t.type))) {
    return HandScore.invalid();
  }
  for (final m in openMelds) {
    if (m.kind == MeldKind.pair ||
        !m.low.isPlayingTile ||
        (m.isSequence && (!m.low.isSuit || m.low.number > 7))) {
      return HandScore.invalid();
    }
  }
  final split = splitGold(all, fuzhou.goldTypes);
  if (!isAgariFuzhou(split.counts,
      wilds: split.wilds, meldCount: openMelds.length)) {
    return HandScore.invalid();
  }

  final patterns = <YakuResult>[];
  var counted = FuzhouRules.basePoints;
  patterns.add(const YakuResult('Base Points', FuzhouRules.basePoints));

  final flowerCount = ctx.flowers.length * FuzhouRules.flowerPoint;
  if (flowerCount > 0) {
    patterns.add(YakuResult('Flower Points', flowerCount));
    counted += flowerCount;
  }
  final blooms = FuzhouRules.fullBloomSets(ctx.flowers);
  if (blooms > 0) {
    patterns.add(YakuResult('Full Bloom', blooms * FuzhouRules.fullBloomPoints));
    counted += blooms * FuzhouRules.fullBloomPoints;
  }
  final golds = split.wilds * FuzhouRules.goldPoint;
  if (golds > 0) {
    patterns.add(YakuResult('Gold Points', golds));
    counted += golds;
  }
  if (isDealer && fuzhou.dealerContinuation > 0) {
    final streak = fuzhou.dealerContinuation * FuzhouRules.dealerContinuationPoint;
    patterns.add(YakuResult('Dealer Continuation', streak));
    counted += streak;
  }
  final openKongs = openMelds.where((m) => m.isKan && !m.concealed).length;
  final concealedKongs = openMelds.where((m) => m.isKan && m.concealed).length;
  if (openKongs > 0) {
    final p = openKongs * FuzhouRules.openKongPoints;
    patterns.add(YakuResult('Open Kong', p));
    counted += p;
  }
  if (concealedKongs > 0) {
    final p = concealedKongs * FuzhouRules.concealedKongPoints;
    patterns.add(YakuResult('Concealed Kong', p));
    counted += p;
  }
  // The whole of the above is doubled.
  patterns.add(YakuResult('Doubled', counted));
  var total = counted * 2;

  void special(String name, int points) {
    patterns.add(YakuResult(name, points));
    total += points;
  }

  final allSequences = openMelds.every((m) => m.isSequence) &&
      isAgariFuzhou(split.counts,
          wilds: split.wilds,
          meldCount: openMelds.length,
          allowTriplets: false);
  if (allSequences) special('All Sequences', FuzhouRules.allSequences);
  if (ctx.flowers.length == 1) special('One Flower', FuzhouRules.oneFlower);
  final gold = goldSpecial(split.counts, split.wilds, openMelds.length);
  if (gold != null) special(gold.name, gold.points);
  if (fuzhou.robbingGold) {
    special('Robbing the Gold', FuzhouRules.robbingTheGold);
  }
  if (ctx.heavenly && ctx.isTsumo && isDealer) {
    special('Blessing of Heaven', FuzhouRules.blessingOfHeaven);
  }
  if (ctx.earthly && !ctx.isTsumo && !isDealer) {
    special('Blessing of Earth', FuzhouRules.blessingOfEarth);
  }

  return HandScore(
      yaku: patterns,
      han: total,
      fu: 0,
      yakuman: 0,
      points: total,
      dealerPays: total,
      nonDealerPays: total,
      limitName: '',
      valid: true);
}
