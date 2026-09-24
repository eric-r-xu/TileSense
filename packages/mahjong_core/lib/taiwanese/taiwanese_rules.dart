/// Rules for 16-tile Taiwanese mahjong (a complete hand is 5 melds and a
/// pair — 17 tiles), following the San Diego Mahjong Club's Taiwanese
/// cheat sheet: a flat, additive point score (not a doubling faan/tai
/// table), a 5-point minimum to declare mahjong, and a dealer streak bonus
/// paid on top of the hand's own value.
library;

class TaiwaneseRules {
  /// "MAHJONG · 5-Point Minimum" — a complete hand scoring fewer points than
  /// this cannot be declared.
  static const minimumPoints = 5;

  /// Seven Pairs and a Pung is the sheet's variant on seven pairs; always on.
  static const sevenPairsAndPung = true;

  /// Chips every seat starts a game with.
  static const startingChips = 1000;

  /// The dealer-streak bonus after [wins] *consecutive* East wins (1 for the
  /// first, 2 for the second, ...), capped at the sheet's third-hand value:
  /// 2, 4, 6, 6, 6, ... A drawn hand is not a win and resets the streak to 0.
  static int dealerBonus(int wins) {
    if (wins <= 0) return 0;
    return 2 * (wins > 3 ? 3 : wins);
  }
}
