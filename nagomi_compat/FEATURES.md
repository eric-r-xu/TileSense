# Pinned Nagomi observation contract

The model consumes float32 `[1012, 34]` observations and boolean `[46]`
action masks. Column order is `1m..9m, 1p..9p, 1s..9s, E,S,W,N,P,F,C`.
Rows below are zero-based and inclusive. A scalar occupies all 34 columns.
Relative seats are self, next, opposite and previous. This describes the
independent implementation established through black-box comparisons; it is
not copied reference-engine code.

A seven-row tile packet contains four cumulative count rows and three scalar
red-five flags. Dora flags in river records reflect indicators when the
discard occurred. Meld packets instead use four count rows and one scalar
flag for any red tile. Empty/skipped river slots remain empty.

| Rows | Implemented meaning |
| --- | --- |
| 0–6 | Own concealed hand packet, including the current draw |
| 7–14 | Relative scores, each clipped to 100,000 and 30,000, then divided by that bound |
| 15–18 | Own rank one-hot; ties use absolute seat order |
| 19–22 | Hand number one-hot |
| 23–24 | Honba and riichi sticks, clipped to 10 and divided by 10 |
| 25–26 | Round and own seat wind tile flags |
| 27 | Hand progress, clipped to 7 and divided by 7 |
| 28–34 | Dora indicator packet |
| 35–58 | First six self river slots: kan tile flags, discard, red, dora |
| 59–130 | Newest 18 self river slots, same four-row format |
| 131 | Self discard recency by tile, with exponential age weights |
| 132–716 | Three opponent blocks of 195 rows: first six and newest 18 river slots, followed by discard/tedashi/riichi recency. Each slot has consumed low/high tiles, kan tiles, discard, red, dora, tedashi and riichi |
| 717 | Remaining draws divided by 69; the initial hand has 70 remaining |
| 718–721 | Visible owned dora/red counts per relative seat, clipped to 12 and divided by 12 |
| 722 | Unseen dora/red inventory divided by 23 |
| 723–750 | All discards, seven-row packet per relative seat |
| 751–830 | Open melds, four five-row slots per relative seat |
| 831–834 | Concealed-kan tile flags per relative seat |
| 835 | Unique physically visible tile counts divided by four |
| 836–844 | Last tedashi per opponent: tile, red and dora |
| 845–853 | Riichi discard per opponent: tile, red and dora |
| 854–856 | Opponent riichi declarations |
| 857–859 | Opponent accepted riichi |
| 860 | Cached waits, filtered for four visible copies at refresh time |
| 861 | Current temporary/permanent/discard furiten |
| 862–868 | Cached shanten, one-hot over 0–6 |
| 869–870 | Own accepted riichi and explicit kan-selection phase |
| 871–873 | Offered tile, red and dora when passing is available |
| 874 | Legal discard tile types; red identity is folded into the base tile |
| 875–876 | Cached discards that preserve or improve the stored shanten |
| 877 | Legal discards leaving nonfuriten tenpai with a physically available base-yaku ron wait and remaining draws |
| 878 | Own riichi declaration while discarding |
| 879–884 | Riichi, three chi variants, pon and open-kan eligibility |
| 885–886 | Concealed-kan and added-kan tile candidates |
| 887–888 | Agari and nine-terminals abortive-draw eligibility |
| 889–890 | **Unimplemented** maximum expected-value normalizations |
| 891–924 | Live improving tile flags per minimum-shanten discard type |
| 925–958 | Live improving tile flags per worsening discard type in the high-shanten fallback |
| 959 | Discard with most live improving copies in the minimum-shanten tier |
| 960 | Live improving tile flags for a hand before drawing |
| 961–1011 | **Unimplemented** probability and expected-value horizon groups |

Cached fields are part of the wire contract. The stored shanten is the
pre-draw value, not the minimum after choosing a discard from 14 tiles. Waits
refresh after an own discard or kan; chi/pon preserve the previous waits until
the mandatory discard. Public updates and draws do not refresh them. Once
riichi is accepted, shanten, waits and discard-analysis vectors stay frozen.
Rows 875–876 can therefore flag tiles that are no longer held. The unfiltered
structural waits are retained separately for discard furiten.

Row 877 excludes pending riichi as a yaku, dora alone and situational yaku such
as chankan, rinshan and the last tile. Accepted riichi counts. A dead wait may
still cause discard furiten, but cannot supply the available winning tile.

The legal mask preserves separate red-discard action IDs. It independently
handles calls, kuikae, riichi, kan candidates, yaku existence and furiten.
`yaku.has_yaku` checks eligibility; the separate [scoring module](SCORING.md)
now calculates han/fu/basic payments. Future-value assumptions, the model's
final win guard and chained policy reactions remain separate migration gates.

Rows 891–960 use independently enumerated draws and shanten calculations.
Physically visible copies stay unavailable even after a hypothetical discard.
At minimum shanten four or higher, the fallback also emits the next shanten
tier in rows 925–958. Below four it emits only minimum-shanten candidates.
Accepted riichi restricts candidates to the drawn tile. Otherwise these
structural candidates are separate from the legal action mask.

Row 959 first maximizes live improving copies. Ties prefer honors, then tiles
farther from five within a suit, then an available nonred copy, then the lower
base tile index. This is a tile-efficiency preference, not the model's policy
argmax or the maximum-EV discard.

The structural group's future-draw horizon is
`max((70 - draws - offset) // 4, 0)`. For a discard position, `offset=0`.
For a response position it is the positive seat distance from the current
actor to self. Complete self-drawn hands and positions with zero horizon
leave rows 891–960 empty. A ron opportunity can still have a nonempty future
response vector.

## Remaining probability/EV work

There are 53 unknown rows. Black-box fixtures suggest three 17-row blocks:
tenpai probability (961–977), winning probability (978–994) and relative EV
(995–1011). These labels and the two scalar EV normalizations still require
a complete independent implementation and differential validation.

An analytical diagnostic tests a one-shanten hypothesis against the frozen
frames: `1 - product(1 - live / (unseen - elapsed - turn))`, over the remaining
own draws. It covers 3,196 horizon/candidate comparisons across 100 fixture
cases. Maximum absolute difference is `4.32e-7`, with no differences over
`1e-6`. It does not meet the encoder's `1e-7` comparison tolerance on all cases;
float32 operation order, multi-stage hand transitions, winning probability and
score EV remain unresolved. No probability row is promoted by this diagnostic.

Independent current-hand scoring now matches 841 recorded wins, 48 synthetic
completed-hand probes and 30 frozen completed self-draw frames. It is a
prerequisite for future EV, not an implementation of these 53 rows.

A pure tenpai-maximization search was tested on 704 candidate vectors across
the frozen corpora. It differs by more than `1e-6` on 190 vectors, with maximum
absolute probability difference `0.11948`. The isolated hypothesis does not
reproduce the target. The search objective/transition assumptions still need
characterization; score-dependent choices are a next hypothesis, not a proven
explanation. The failed experiment is kept outside the runtime encoder.

Next work is future scoring/riichi/bonus assumptions and the finite-draw
multi-stage calculation. Preserve the oracle-only test boundary, then validate
the scalar normalizations and all 17 horizons before enabling those rows.
The win guard and full reaction-chain parity follow complete independent
observations.

Unknown rows contain NaN, with `known_rows=False`. Both complete-observation
validation and inference reject incomplete inputs. Implemented-row agreement
on validation replays is evidence for those sampled states, not proof over
every possible game or an estimate of remaining engineering work.
