/// Rules for 16-tile Taiwanese mahjong (a complete hand is 5 melds and a
/// pair — 17 tiles), following the San Diego Mahjong Club's Taiwanese
/// cheat sheet: a flat, additive point score (not a doubling faan/tai
/// table), a minimum to declare mahjong (the sheet's 5 by default; 1 or 3
/// as table options), and a dealer streak bonus paid on top of the hand's
/// own value.
library;

class TaiwaneseRules {
  /// "MAHJONG · 5-Point Minimum" — a complete hand scoring fewer points than
  /// the table's minimum cannot be declared. The sheet's 5 is a club house
  /// rule rather than a standard: in Taiwan any complete hand usually wins,
  /// and groups that set a minimum commonly play 1 or 3 tai. See
  /// docs/TAIWANESE_RULES.md.
  static const defaultMinimumPoints = 5;

  /// The minimums a table may pick from.
  static const minimumPointsChoices = [1, 3, 5];

  /// Anything other than a listed choice falls back to the default.
  static int normalizeMinimumPoints(Object? v) =>
      v is int && minimumPointsChoices.contains(v) ? v : defaultMinimumPoints;

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
