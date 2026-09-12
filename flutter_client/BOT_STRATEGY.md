# Bots and Autoplay

Opponent seats use `SimpleBot`; human-seat Autoplay uses the same guide shown
in the interface.

Both take legal wins, including an immediately available seven/eight-flower
win. Opponents take available kongs and accept pungs/chows when they improve
hand distance. Chow evaluation uses the same first legal sequence that the
round engine will apply. Their discard heuristic keeps ready hands, then
prefers isolated, less useful tiles. They have no concealed information from
other seats and no riichi declaration or yaku requirement.

Autoplay compares expected values, evaluates the available call sequences,
and follows the guide's recommended discard and kong decision. The speed/value
and play-style controls feed that same analysis. See [the value model](EXPECTED_VALUE.md)
for its assumptions.

The [rules reference](../docs/HONG_KONG_RULES.md) defines scoring, payments,
flowers, and defaults outside the supplied cheat sheet. Ordinary test runs
cover legal actions and deterministic games. The pre-existing optional
`SIM_GAMES` and `SIM_DIAG` tools are preserved; their historical riichi-named
counters are compatibility fields, not active gameplay rules.
