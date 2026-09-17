/// How much a point swing is worth to final placement, given the table's
/// current scores — the model behind [Strategy.placement] in
/// `efficiency_engine.dart`.
///
/// Deliberately not a simulator: no rest-of-hand or rest-of-game Monte Carlo,
/// no opponent hand modelling. It is a closed-form heuristic — "chance I
/// finish above seat j" approximated as a logistic in the current score
/// gap — tuned to have the right shape (marginal points matter most in a
/// close race, least in a blowout lead or a hopeless last) rather than fitted
/// to any data. See EXPECTED_VALUE.md.
library;

import 'dart:math' as math;

class PlacementUtility {
  const PlacementUtility({
    required this.tablePoints,
    required this.mySeat,
    required this.handsRemaining,
  }) : assert(tablePoints.length == 4);

  /// All four seats' current scores, seat-indexed.
  final List<int> tablePoints;

  /// Which index in [tablePoints] is the seat being valued.
  final int mySeat;

  /// Hands left in the game, including whichever one is in progress. Not
  /// aware of renchan — recomputed fresh every turn from the live round
  /// state, so it self-corrects as the game actually runs long.
  final int handsRemaining;

  /// Points-of-gap at which one seat is judged a 50/50 coin flip to finish
  /// above another, scaled by how much game is left: gaps are more decisive
  /// the closer the game is to over. A tuned constant, not derived — see
  /// EXPECTED_VALUE.md's "known simplifications".
  static const double _baseSpread = 5000;

  double get _spread =>
      _baseSpread * math.sqrt(handsRemaining.clamp(1, 16).toDouble());

  double _logistic(double x) => 1 / (1 + math.exp(-x));

  /// A monotonic read of how good [myScore] is against the other three —
  /// higher is better, roughly 0 (last, no hope) to 3 (first, lock).
  double _u(num myScore) {
    var sum = 0.0;
    for (var j = 0; j < 4; j++) {
      if (j == mySeat) continue;
      sum += _logistic((myScore - tablePoints[j]) / _spread);
    }
    return sum;
  }

  /// What gaining [points] (negative for a loss) from here is worth to final
  /// placement, as a utility delta rather than a point count. Only
  /// meaningful for ranking one candidate against another at this same table
  /// state — the absolute scale carries no independent meaning.
  ///
  /// A finite difference rather than a derivative at the current score, so a
  /// large swing (a mangan, a big deal-in) correctly saturates once it
  /// crosses a rank instead of being extrapolated past it.
  double valueOf(double points) =>
      _u(tablePoints[mySeat] + points) - _u(tablePoints[mySeat]);
}
