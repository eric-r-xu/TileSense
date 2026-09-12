# TileSenseHK rules

The scoring source is **HKMJ Cheat Sheet 1.0.pdf**, “Hong Kong Mahjong Rule Sheet / 香港麻雀正統牌型,” version 1.0, April 3, 2025, by /u/danma, supplied for this conversion. Its **New Style, discarder-pays-all** payment table replaces the original Japanese scoring system. The minimum is **0 faan**, as requested.

## Payments

| Faan | Table points |
|---:|---:|
| 0 | 1 |
| 1 | 2 |
| 2 | 4 |
| 3 | 8 |
| 4 | 16 |
| 5 | 24 |
| 6 | 32 |
| 7 | 48 |
| 8 | 64 |
| 9 | 96 |
| 10 | 128 |
| 11 | 192 |
| 12 | 256 |
| 13+ | 384 |

On a discard win, **only the discarder pays twice the table points**. On a self-pick, **each of the other three players pays the table points**. There is no dealer multiplier. Faan above 13 are shown in the breakdown but payouts stay capped. Points are abstract chips, not a currency.

A 0-faan discard win therefore receives 2 chips. A 3-faan self-pick receives 24 chips: 8 from each opponent. Draws transfer nothing. There are no riichi deposits, repeat payments, fu, dora, ura-dora, red fives, or furiten restrictions.

## Features

Independent features add together. Indented features in the source replace their parent; the app never adds both the parent and its replacement.

| Feature | Faan | Replacement / condition |
|---|---:|---|
| Self-Pick | 1 | |
| Win by Kong Replacement | 2 | Replaces Self-Pick |
| Double Kong Replacement | 9 | Replaces the self-pick/kong award; the first replacement tile must be used in the next kong |
| Concealed Hand | 1 | No exposed calls; concealed kongs preserve concealment |
| Robbing the Kong | 1 | Winning on the tile added to an exposed pung |
| Moon Under the Sea | 1 | Last wall tile or last discard |
| All Sequences | 1 | Four chows |
| All Triplets | 3 | Four pungs/kongs |
| All Concealed Triplets | 8 | Replaces All Triplets; self-pick or discard completing the pair |
| All Quadruplets | 13 | Replaces the triplet award |
| Dragon pung/kong | 1 each | |
| Small Three Dragons | 5 | Replaces individual dragon awards |
| Big Three Dragons | 8 | Replaces individual dragon awards |
| Seat / round wind pung/kong | 1 each | A double wind earns 2 |
| Small Four Winds | 6 | Replaces seat/round wind awards |
| Big Four Winds | 13 | Replaces seat/round wind awards |
| Mixed Flush | 3 | One suit and honours |
| Full Flush | 7 | One suit only; replaces Mixed Flush |
| Mixed Terminals | 4 | Only terminals and honours; includes All Triplets |
| All Terminals | 13 | Only ones and nines; includes All Triplets |
| All Honours | 10 | Only honour tiles; includes All Triplets |
| No Flowers or Seasons | 1 | |
| Seat flower / season | 1 each | East 1, South 2, West 3, North 4 |
| All Flowers / All Seasons | 2 each | Adds to matching-seat bonuses |
| Seven Flowers | 3 | Optional immediate flower win |
| Eight Flowers | 8 | Optional immediate flower win |
| Blessing of Heaven | 13 | Dealer's beginning hand |
| Blessing of Earth | 13 | Win on dealer's first discard, before any call |
| Blessing of Man | 13 | Non-dealer's first self-pick, before any call |
| Nine Gates | 13 | Concealed 1112345678999 plus any tile of that suit |
| Thirteen Orphans | 13 | Each terminal and honour plus a matching tile |
| Seven Pairs | 4 | Enabled optional variant; seven distinct pairs, combinable with flushes / All Honours |

When a terminal/honour feature includes the 3-faan triplet award and the hand also has concealed triplets or four kongs, the breakdown shows the terminal/honour award in full and only the additional upgrade (5 or 10). This counts the shared triplet component once.

## Play and decisions outside the sheet

- Four players, 144 tiles: four of each of 34 ordinary types and eight unique flowers/seasons. Bonus tiles are exposed, not retained in the 13-tile concealed hand.
- Ordinary draws come from the front; flower and kong replacements come from the tail. There is no reserved dead wall or four-kong replacement limit.
- Exposing the seventh or eighth bonus tile pauses **before** its replacement. The player may claim the independent 3/8-faan flower win or continue drawing. Bots/autoplay take the available win. Flower wins use self-pick payments and do not add ordinary hand or flower bonuses.
- Chow only from the immediately preceding player. Winning claims take priority over kong/pung, then chow. Added kongs can be robbed; concealed kongs cannot.
- Multiple winners on one discard are retained from the existing engine. The discarder pays each independently, with result pages ordered by turn distance.
- Dealer repeats on a win or a drawn hand. Otherwise dealership advances. A full game covers all four winds (16 dealerships); an East-only option remains. Repeats use fresh deals and add no payment. Negative chip balances do not stop the game.
- Concealed Hand includes a win on discard if there were no exposed calls. The winning discard itself does not turn a concealed hand into an exposed hand. This is the interpretation used for the sheet's concealed-hand wording.
- Seven Pairs is enabled at your explicit request; it is centralized in `HongKongRules` for easy adjustment.

The sheet does not specify every gameplay detail above. These choices are explicit defaults, not additional claims about the source.

## Guide and compatibility

The guide uses exact HK scoring for ready-hand waits and an estimate for unfinished hands. It retains the existing shanten/acceptance and completion lookahead, with values converted to HK chips. Its risk estimates activate against opponents with at least two exposed sets. Discard history never grants immunity: there is no genbutsu or suji rule. Even a heavily visible honour retains special-hand risk.

Probability and risk parameters are heuristics, not a calibrated Hong Kong solver. The optional large simulation tools remain available separately.

Some internal API and telemetry names (`han`, `yaku`, `ron`, `tsumo`, `chi`, `pon`, `kan`, `hanchan`) remain for compatibility. `han` carries faan, `yaku` carries the scoring-feature list, and the full-game option now means four winds. Legacy riichi flags and scoring inputs confer no legal action or bonus. Telemetry also includes the HK ruleset identifier, `faan`, and `scoring_patterns`; the existing server's legacy columns remain compatible.
