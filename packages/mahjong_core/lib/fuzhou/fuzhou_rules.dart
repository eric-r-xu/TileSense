/// Rules for Fuzhou ("Gold Rush") mahjong, following Mahjong Pros'
/// "Beginner's Guide to Fuzhou Mahjong": a 16-tile game (a complete hand is
/// five melds and a pair — 17 tiles) on 144 tiles, where every honor and every
/// flower is a flower, and one tile type is flipped as the Gold: a wild card.
///
/// The score is flat and additive, not a doubling table:
/// `((base + flowers + golds + dealer streak + kongs) x 2) + special hands`.
/// See docs/FUZHOU_RULES.md for how each line of the guide is read.
library;

import '../tile.dart';

class FuzhouRules {
  /// Points every hand starts from.
  static const basePoints = 5;

  /// Points every seat starts a game with. The guide leaves the stake to the
  /// table ("50 or 100, however you can go as high as you like"); a typical
  /// hand moves 20-40 a head, so this keeps a whole game in play.
  static const startingPoints = 500;

  /// Tiles held back at the end of the wall. The hand is a draw once the live
  /// wall runs out, and the Gold is flipped from the last of these.
  static const deadWallSize = 18;

  /// Concealed tiles a seat holds between draws.
  static const handSize = 16;

  // --- scoring lines -----------------------------------------------------

  static const flowerPoint = 1;
  static const goldPoint = 1;
  static const dealerContinuationPoint = 1;
  static const openKongPoints = 1;
  static const concealedKongPoints = 2;

  /// A complete set of four flowers or seasons, or four of one wind or
  /// dragon. Stacks with the single-flower points.
  static const fullBloomPoints = 6;

  static const allSequences = 10;
  static const oneFlower = 15;
  static const goldenPair = 20;
  static const threeGoldKnockdown = 30;
  static const goldenDragon = 40;
  static const robbingTheGold = 50;
  static const blessingOfEarth = 40;
  static const blessingOfHeaven = 50;

  /// Whether [t] is a flower here: the eight flowers and seasons, and every
  /// wind and dragon. All are exposed and replaced from the wall when drawn
  /// (unless they are the Gold — see [goldTypesFor]).
  static bool isFlower(TileType t) => t.isBonus || t.isHonor;

  /// The tile types that are wild when [revealed] is flipped as the Gold.
  ///
  /// An ordinary tile makes its own type gold: the three copies still in play
  /// (the flipped one is the indicator, not a tile anyone can hold). If a
  /// flower or season is flipped, the other seven flowers and seasons are
  /// gold instead.
  static Set<TileType> goldTypesFor(TileType revealed) {
    if (revealed.isBonus) {
      return {
        for (final t in TileType.values)
          if (t.isBonus && t != revealed) t,
      };
    }
    return {revealed};
  }

  /// How many complete "Full Bloom" sets [flowers] holds: all four flowers,
  /// all four seasons, or all four copies of one wind or dragon.
  static int fullBloomSets(Iterable<TileType> flowers) {
    final counts = <TileType, int>{};
    for (final f in flowers) {
      counts[f] = (counts[f] ?? 0) + 1;
    }
    var sets = 0;
    const flowerSet = [
      TileType.plum,
      TileType.orchid,
      TileType.chrysanthemum,
      TileType.bamboo
    ];
    const seasonSet = [
      TileType.spring,
      TileType.summer,
      TileType.autumn,
      TileType.winter
    ];
    if (flowerSet.every(counts.containsKey)) sets++;
    if (seasonSet.every(counts.containsKey)) sets++;
    for (final e in counts.entries) {
      if (e.key.isHonor && e.value >= 4) sets++;
    }
    return sets;
  }
}
