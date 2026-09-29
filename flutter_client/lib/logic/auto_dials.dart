/// Picks the guide's three dials — [PlayStyle], [HandFocus], [Strategy] — for
/// the point in the game, so the player never has to: points early,
/// placement in the final hands.
library;

import 'package:mahjong_core/ruleset.dart';

import 'efficiency_engine.dart';

/// How many hands at the end of a game the guide plays for placement rather
/// than points: the last two, whatever the game's length (South 3–4 in a
/// hanchan, East 3–4 East-only). A dealer repeat in them still counts.
const int kPlacementHands = 2;

typedef AutoDials = ({PlayStyle style, HandFocus focus, Strategy strategy});

/// The dials the guide plays under [ruleset] with [handsLeft] hands to go,
/// counting the current one.
///
/// Riichi plays for points until the last [kPlacementHands] hands, then for
/// placement: Balanced, and Strategy: Placement, which weighs each line by how
/// it moves the chance of finishing above each other seat on the current
/// scores (`placement_utility.dart`).
///
/// Measured at 2,400 paired seeds per length (502400–504799, guide on
/// Autoplay against three SimpleBots) against the fixed Balanced / Speed /
/// Points it replaced: placement +0.008 ± 0.020 East and +0.007 ± 0.023
/// hanchan (95% CI, lower is better; z 0.77 / 0.64), points −122 ± 181 and
/// +68 ± 269. No measurable difference either way; 80–85% of games played
/// identically.
///
/// Read off `reports/stats_report.md` at engine `d53ec82` (seeds
/// 500000–501199) and engine `c127f01` (fresh seeds 501200–502399), 1200
/// paired seeds each, for the fixed dials this replaced:
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
AutoDials autoDials(Ruleset ruleset,
    {required int minimumPoints, required int handsLeft}) {
  if (ruleset.isRiichi) {
    final end = handsLeft <= kPlacementHands;
    return (
      style: end ? PlayStyle.balanced : PlayStyle.aggressive,
      focus: HandFocus.speed,
      strategy: end ? Strategy.placement : Strategy.points,
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
