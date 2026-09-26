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
/// Read off `reports/stats_report.md` (1200 paired seeds, engine `d53ec82`):
/// the best fixed arm is the same for all three goals in every variant, so
/// [goal] does not change the answer yet — it will once the dials adapt to
/// the table during a game.
///
/// - Riichi: Aggressive / Speed / Points leads on win rate and points in both
///   lengths, and is within 0.004 placement of the leader.
/// - Hong Kong and Taiwanese stay pinned to Balanced / Points (see
///   `GameController.setRuleset`); only Focus moves. Speed at Taiwanese 1 and
///   3 tai (Balanced trails by 0.10–0.24 placement, z ≥ 2.6). Balanced at 5
///   tai (0.065 / 0.085 placement ahead East / hanchan, paired z = 2.1 / 2.5).
///   Hong Kong keeps Speed: no minimum separates the two (|z| ≤ 2.0).
AutoDials autoDials(Goal goal, Ruleset ruleset, {required int minimumPoints}) {
  if (ruleset.isRiichi) {
    return (
      style: PlayStyle.aggressive,
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
