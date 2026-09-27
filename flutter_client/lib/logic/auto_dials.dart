/// Picks the guide's three dials — [PlayStyle], [HandFocus], [Strategy] — for
/// a chosen [Goal], so a player says what they want and not how to play for it.
library;

import 'package:mahjong_core/ruleset.dart';

import 'efficiency_engine.dart';

/// What the player wants from the game. The guide and Auto-Play pick their
/// dials from this through [autoDials].
enum Goal {
  winRate(label: 'Win Rate'),
  points(label: 'Points'),
  placement(label: 'Placement');

  const Goal({required this.label});

  final String label;

  Goal get next => Goal.values[(index + 1) % Goal.values.length];
}

const Goal kDefaultGoal = Goal.placement;

typedef AutoDials = ({PlayStyle style, HandFocus focus, Strategy strategy});

/// The dials the guide plays [goal] with under [ruleset].
///
/// Read off `reports/stats_report.md` at engine `d53ec82` (seeds
/// 500000–501199) and engine `c127f01` (fresh seeds 501200–502399), 1200
/// paired seeds each. [goal] only changes the answer for Riichi Placement.
///
/// - Riichi: Aggressive / Speed / Points leads on win rate and points in both
///   lengths. For Placement, Balanced / Speed / Points ties it on the first
///   seeds (2.205 vs 2.202 East, 2.100 vs 2.105 hanchan), beats it East on the
///   fresh ones (2.152 vs 2.193, paired p = 0.007; hanchan 2.082 vs 2.083),
///   and deals in less (about 8% vs 9.5%).
/// - Hong Kong and Taiwanese stay pinned to Balanced / Points (see
///   `GameController.setRuleset`); only Focus moves. Speed at Taiwanese 1 and
///   3 tai (Balanced trails by 0.10–0.24 placement, z ≥ 2.6). Balanced at 5
///   tai (0.065 / 0.085 placement ahead East / hanchan, paired z = 2.1 / 2.5).
///   Hong Kong keeps Speed: no minimum separates the two (|z| ≤ 2.0).
AutoDials autoDials(Goal goal, Ruleset ruleset, {required int minimumPoints}) {
  if (ruleset.isRiichi) {
    return (
      style: goal == Goal.placement ? PlayStyle.balanced : PlayStyle.aggressive,
      focus: HandFocus.speed,
      strategy: Strategy.points,
    );
  }
  return (
    style: PlayStyle.balanced,
    focus: ruleset.isTaiwanese && minimumPoints >= 5
        ? HandFocus.balanced
        : HandFocus.speed,
    strategy: Strategy.points,
  );
}
