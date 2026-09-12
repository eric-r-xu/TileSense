# Hong Kong guide value model

The guide ranks legal discards by expected chip value under
[the configured HK rules](../docs/HONG_KONG_RULES.md).

At readiness, it enumerates live winning tiles, scores each as a discard win
and a self-pick, and weights their payouts by remaining copies. The retained
heuristic mixture is 65% discard wins and 35% self-picks. Exact scoring includes
the seat/round winds, declared melds, and already exposed flowers. It does not
predict future flowers, first-turn awards, or future kong-replacement bonuses.

Before readiness, the existing shanten/acceptance transition model estimates
completion probability. Its lookahead caps a one-away line by the winning
chances of the ready hands it can actually reach. A ready line's known payout
anchors other lines of that same hand. Otherwise visible wind/dragon sets,
flush structure, concealment, and flower bonuses estimate the eventual payout.
These are projections, not scored winning hands.

Balanced expected value is `win probability × average payout − risk`.
Speed/value focus applies the existing curves to probability and payout;
its displayed tilt plus the risk terms reconstruct the reported total.
Play style scales risk without altering the hand's faan or chip payout.

The risk panel activates when an opponent has at least two exposed sets.
It uses public tile counts and ordinary sequence/pair exposure, with a
representative 16-chip deal-in cost and estimated future exposure. There is no
furiten, genbutsu, or suji immunity. Previously discarded or passed tiles can
still win. No tile receives a guaranteed-safe rating.

There are no riichi branches, deposits, lock-in costs, dora multipliers, or
honba bonuses. The completion and danger probabilities remain heuristics;
no claim of HK-specific statistical calibration is made. Optional simulation
tests can measure performance independently of the rules regression suite.
