# Expected Value — how the guide scores a discard

A plain-language walkthrough of the number in the guide panel's **Expected
Value** column, and how it picks the recommended discard and drives Autoplay.
Based on `lib/logic/efficiency_engine.dart`, `lib/logic/efficiency_calc.dart`
(shanten / ukeire), and `lib/logic/scoring.dart` (hand value). The opponents
use none of this — see [`BOT_STRATEGY.md`](BOT_STRATEGY.md).

## The short version

- **Expected Value (EV) = how likely this hand is to finish × what it pays,
  minus a couple of risk penalties.** It's in points, not a shanten count.
- Every legal discard gets its own EV — including discards that step *back* a
  shanten, which is what folding usually costs — and every discard is charged
  what it risks: while an opponent is in riichi, its chance of dealing in times
  what that hand would cost you, plus the turns choosing it commits you to.
- The guide recommends the **highest-EV** discard. Always — at tenpai and
  before it, defending or not. Push and fold fall out of the numbers rather
  than from a switch.
- A **play style** — defensive, balanced or aggressive — scales every risk
  charge and how readily a hand is kept quiet. It never changes what a hand is
  worth, only what danger costs, and it steers Autoplay through the same
  scores. A second dial, **focus** (Speed or Balanced), tilts the trade between
  the chance of finishing and the payout. Both start on **Aggressive / Speed**
  under riichi; under Hong Kong, style has nothing left to weigh, so it's
  hidden and pinned to Balanced, leaving only focus (**Speed**).
- A third dial, **strategy** (Points or Placement, riichi only, starting on
  **Points**), changes what "worth" means rather than how danger is priced:
  Points is everything above; Placement runs every points-flavoured number
  through a heuristic model of how it moves the chance of finishing above
  each other seat, given the scores on the table right now — see
  [Strategy](#strategy--points-or-placement-riichi-only).
- Under **Hong Kong** rules the same machinery runs on faan converted to chips,
  with a 0-faan minimum — see [Under Hong Kong rules](#under-hong-kong-rules).
- Two different estimators depending on where the hand sits:
  - **Not yet tenpai:** a turn-by-turn walk of the hand towards a win — each
    turn it may take a step, each step is narrower than the last, and each turn
    the hand may end first — against flat placeholder point values.
  - **Tenpai:** the real thing — every wait scored with actual yaku / fu / han /
    dora, blended across ron vs. tsumo and by how many copies are still live.
- Calls (chi / pon / kan) and "just pass" are scored on the **same EV scale**,
  so "call vs. stay closed" is a number comparison, not a matter of taste.

## What goes in

`EfficiencyEngine.analyze(...)` is called every time it is your turn, from
`game_controller.dart` → `_refreshReport()`:

| Input | Used for |
|---|---|
| your 14 tiles (13 + draw) | shanten, ukeire, the hand to score |
| every tile you can see (your hand, all ponds, all melds, revealed dora indicators) | how many of each tile are **still live** (`4 − visible`) |
| open melds, round wind, seat wind, dealer? | yaku / fu / han when scoring a win |
| `inRiichi`, `canRiichi` | whether riichi is on the table as an option |
| wall tiles remaining | how many more times you will draw |
| revealed dora indicators | dora count when scoring |
| opponent in riichi + their discards + all discards | defensive ranking and the riichi-danger discount below |

**Deliberately left out:** ura-dora and hidden dora (you cannot see them),
situational yaku (ippatsu, haitei / houtei, rinshan, chankan — unknowable for a
hypothetical future win), the opponents' actual hands, and anything more than
one exchange ahead.

## The pipeline, per candidate discard

1. **Shanten + ukeire** from the calculator ported from Riichi-Trainer
   (`efficiency_calc.dart`): how many tiles from a ready hand, and how many live
   tiles would reduce that.
2. **Dedupe** lines that discard the same tile type, keeping the widest.
3. **Value** (`_assessValue`) → the EV, the "if you win" average points, a plan
   tag (`RIICHI` / `DAMATEN` / `YAKU PATH` / …), and a one-line reason.
4. **Sort** by EV; ties broken by lower shanten, then higher ukeire.
5. **Recommend** the top line — unless defending a live riichi while still
   ≥ 1-shanten, in which case the safest discard from `safety.dart` is floated
   to the top instead.

The panel flags up to three lines: `bestExpectedValue` (top of the EV sort),
`bestUkeire` (widest among the lowest-shanten lines), and `recommended`.

## EV before tenpai  (`_assessValue`, shanten ≥ 1)

First a gate: the hand needs a **yaku path** — it is closed (riichi always
counts), or `_hasOpenYakuPath` finds one (all simples, all terminals/honors,
one suit going, or a yakuhai triplet). No path → **EV = 0**, plan `YAKU NEEDED`.

Then:

Then `_winProbabilityFromShanten` walks the hand forward one turn at a time,
tracking the chance it is still alive and still `s` steps from a win:

```
draws  = max(1, (wallTilesRemaining + 3) / 4)     // your remaining draws
scale  = ukeire / typicalUkeire[shanten]          // how wide this hand is
                                                  // for its distance out

// width of the step that leaves the hand at `to` shanten
exponent  = waitInheritance + (1 − waitInheritance) × (to / shanten)
width(to) = typicalUkeire[to] × scale ^ exponent
rate(to)  = min(1, width(to) / unseenTiles)
step(to)  = 1 − (1 − rate(to)) ^ (to == 0 ? 2 : 1)   // the win can be ronned

// each turn: take a step or don't, then see whether the hand is still running
repeat `draws` times:
    mass moves s → s−1 with probability step(s−1);  reaching 0 is the win
    everything not yet won ×= handSurvivesTurn

EV = won × (projectedPoints + winBonus)
```

| constant | value | what it is |
|---|---|---|
| `typicalUkeire` | `[8, 20, 28, 35, 40, 44, 48]` by shanten | typical acceptance at each distance; index 0 is a finished hand's wait |
| `handSurvivesTurn` | `0.955` | chance the hand is still running after one more of your turns |
| `waitInheritance` | `0.5` | how much of a hand's width carries through to the wait it finishes on |

Three things this gets right that the previous estimator did not:

- **Acceptance narrows as the hand closes up.** The old version reused the
  hand's *current* ukeire for every remaining step, so a wide hand two away was
  scored as if it kept that width all the way to the wait. It doesn't — the last
  step is hitting a wait, not picking up any useful tile.
- **The hand can end before you get there.** Nothing modelled the other three
  seats winning, or an exhaustive draw. This was the dominant error: a 2-shanten
  hand with most of the wall left came out at **83–96%**.
- **Distance matters more than width.** The old numbers were driven almost
  entirely by ukeire, so a wide 2-shanten hand (89%) outscored a narrow
  1-shanten one (42%) — the wrong way round.

`handSurvivesTurn` is calibrated on the tenpai end, where the real numbers are
firmest: an early riichi on a ryanmen wins a little over half the time. Off a
full wall the pre-tenpai walk then gives roughly 35% from 1-shanten, 24% from 2,
16% from 3 and 11% from 4 — each rung comfortably below tenpai's ~53%, which is
the ordering that matters when the panel is ranking one discard against
another.

`projectedPoints` is what the hand is assumed to pay when it lands. If **any**
discard leaves this same hand tenpai, that line is scored exactly — yaku, fu,
dora and all — and its payout is used here too, so every line of a hand is
quoted in the same money. Only when nothing reaches tenpai does it fall back to
a flat table:

| | dealer | non-dealer |
|---|---|---|
| closed | 5800 | 3900 |
| open | 2900 | 2000 |

A closed pre-tenpai line also owes the riichi deposit it intends to place:
`(reachedTenpai − winProb) × 1000`, which is the same 1000 the tenpai lines are
charged, payable when it declares and refunded when it wins. Without both of
these a cheap hand's *backwards* lines were credited with an average hand's
payout and billed no deposit, and the guide would recommend breaking its own
tenpai to rebuild.

### Every discard is scored, including backwards ones

`efficiency_calc.dart` measures acceptance against **each line's own** shanten.
Riichi-Trainer measures it against the best shanten on offer, because it only
ever ranks optimal discards; that made every shanten-worsening discard report
`ukeire = 0`, so folding — which usually means breaking your own shape — landed
at a constant `EV = 0` instead of a real number. With that corrected a fold is
scored as what it is: a worse hand you can still win with. Three things have to
hold for the comparison to mean anything, and each is covered by a test:

- a backwards line is priced off the same hand's payout, not a generic one;
- a wide shape reaches tenpai sooner but is never handed a *wider wait* than an
  ordinary hand, or a 1-shanten line could out-run the very same hand already
  tenpai;
- a sound tenpai is kept — while a three-tile tanki may still be worth trading
  for a thirty-six-tile 1-shanten, which the numbers now say on their own.

## EV at tenpai  (`_assessTenpaiValue`, shanten = 0)

Now every wait is scored for real. For each wait tile that still has copies
live:

- `scoreHand` is run four ways — **ron / tsumo × damaten / riichi** — with the
  actual melds, winds, dealer flag, dora indicators, and red-five count.
- Blend: **0.65 × ron + 0.35 × tsumo**, weighted by copies remaining.
- Average those over all live waits → `damaPoints`, and (when riichi is
  available) `riichiPoints`.

Pick a **plan** — first row that applies:

| Plan | When | Points used |
|---|---|---|
| `RIICHI` (already) | you are in riichi | `riichiPoints` |
| `DAMATEN` | yaku on **every** wait **and** cheapest ron ≥ 5200 (7700 as dealer) | `damaPoints` |
| `RIICHI` (recommend) | riichi available, no qualifying damaten | `riichiPoints` |
| `OPEN YAKU` / `DAMATEN` | yaku on every wait, cannot / need not riichi | `damaPoints` |
| `PARTIAL YAKU` | yaku on some waits only | `damaPoints` |
| `TSUMO ONLY` | no ron yaku anywhere | `damaPoints`, ron disabled |
| `NO YAKU` | nothing | **EV = 0** |

Then the win chance:

```
draws    = max(1, (wallTilesRemaining + 3) / 4)
winProb  = winChanceOverTurns(liveWaits, unseenTiles, draws,
                              ron possible ? 1.0 : 0.5)
winBonus = 300 × honba + 1000 × riichiSticks
EV       = winProb × (selectedPoints + winBonus)
```

`winChanceOverTurns` is the same helper the pre-tenpai walk uses for its last
step, so a hand does not jump in value the moment it reaches tenpai:

```
rate    = min(1, waitWidth / unseenTiles)
perTurn = 1 − (1 − rate) ^ chancesPerTurn
repeat `draws` times:
    won   += alive × perTurn
    alive ×= (1 − perTurn) × handSurvivesTurn
```

| constant | value | what it is |
|---|---|---|
| `winChancesPerTurn` | `1.0` | your draw plus whatever the table actually lets you ron |
| `tsumoOnlyChancesPerTurn` | `0.5` | no yaku on the wait, so it has to be drawn |
| `handSurvivesTurn` | `0.955` | shared with the pre-tenpai walk |

The old version counted `draws × 2` independent shots and never asked whether
the hand was still running, so an early riichi on a ryanmen read **93%**. It now
reads about 53%, with a kanchan near a third and a tanki near a fifth — which is
what riichi actually wins. `winChancesPerTurn` is well under the three discards
a turn nominally offers, because anyone who reads the wait stops feeding it.

`winBonus` is what the table pays the winner on top of the hand: a honba is
worth 300 (300 straight from the discarder on ron, 100 from each of the three on
tsumo), and every riichi deposit already on the table is worth 1000. It rides on
the win, so it scales with `winProb` and never with the hand's own value — it
cannot change which shape is worth chasing, only how much the chase is worth.
A deposit *you* have not placed yet is not in here; see the riichi penalty
below, which prices it against the hands you don't win.

**Riichi penalties** — only applied when the guide is actually recommending
riichi:

- `EV −= (1 − winProb) × 1000` — the 1000-point stick you forfeit if you do not
  win.
- If an opponent is *also* in riichi, the cost of being locked into tsumogiri on
  a live board:

  ```
  EV −= turnsExposed × (riichiDangerFactor × maxDealInRate) × dealInBaseCost
  ```

  `turnsExposed` is how many turns the hand is expected to last, which
  `winChanceOverTurns` already accumulates. This is the same arithmetic a single
  dangerous discard is charged, repeated for every turn you can no longer fold —
  which is exactly what declaring costs. It used to be a tuned
  `(1 − winProb) × danger × 4000`, whose scale was implicitly calibrated against
  win probabilities that ran near 0.9; once those were corrected the same
  expression grew about eightfold and folded every tenpai hand.

### `riichiDangerFactor`  (0 = safe … 1 = dangerous)

The weighted-average danger of **every tile you might still draw and be forced
to tsumogiri** under your own riichi, using the same 0–15 `safety.dart` rating
the defensive panel uses, weighted by how many copies of each remain. It is
purely a discount on your own riichi when someone else has already declared.

## Deal-in cost  (charged on every discard, both estimators)

While an opponent is in riichi, each line is charged what the cut itself can
cost you, and the charge is subtracted from that line's EV:

```
dealInCost     = rate(safetyRating) × (baseCost + 300 × honba)
commitmentCost = dealInCost × (turnsExposed − 1) × pushCommitment
baseCost       = 5800   non-dealer riichi
               = 8700   dealer riichi
pushCommitment = 0.3
```

`dealInCost` is the tile in front of you. `commitmentCost` is the rest of the
hand: cutting a live tile before tenpai is not one decision but the start of a
policy — you keep discarding into the same riichi for as long as you stay in.
The tile you pick is what says which policy you are on, so a genbutsu cut is
charged nothing for the later turns and a live one is charged for all of them,
at a discount because (unlike a declared riichi) you can still change your mind
next turn. `turnsExposed` comes from the same walk that produces the win
probability, and this works out at roughly two extra turns of risk on a typical
push.

It applies only before tenpai. At tenpai the equivalent is the riichi lock-in
below — the same idea at full strength, because there you *cannot* change your
mind.

`rate` is keyed by the 0–15 `safety.dart` rating, and is monotonic by
construction — a tile the safety model calls safer is never charged more:

| rating | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| rate | .070 | .068 | .065 | .058 | .055 | .052 | .048 | .045 | .038 | .030 | .028 | .025 | .022 | .012 | .006 | .000 |

So genbutsu is free, a non-suji middle tile is the worst ordinary cut at roughly
one in fifteen, and suji / one-chance / thin honours fall between. The rates and
the two base costs are tuned constants in the same spirit as the projected-point
tables — enough to rank a push against a fold, not solver output.

**Does this replace the fold switch?** Nearly. Across 600 random defending
positions (`test/push_fold_sweep_test.dart`) the expected-value ranking alone
reaches the switch's discard in over 99% of them. Charging only the tile in
front of you left 3.7% disagreeing — every one of those the value model taking a
materially more dangerous tile for a median of 43 points, because it priced one
discard when the choice committed you to several. With `commitmentCost` that
falls under 1%, and what remains is between tiles of near-equal danger (safety 6
against 7) where the value model prefers the better shape, rather than a fold
being overruled. The test bounds both the rate and the worst safety gap.

**The switch is gone.** With both charges in place the recommendation is simply
the best expected value everywhere. `push_fold_sweep_test.dart` holds the
resulting behaviour to account over 600 random defending positions: where a
genbutsu existed the guide took it in **513 of 513**, and it picked the safest
available tile in **595 of 600** — the five exceptions being hands with nothing
safe in them at all, where it chose between tiles of near-identical danger.

## Play style  (`PlayStyle`)

One dial on `EfficiencyValueContext`, applied to every score the engine
produces — the discard table, call advice, kan advice, and therefore Autoplay,
which plays the recommended line.

| style | risk × | damaten bar × |
|---|---|---|
| Defensive | 2.0 | 0.55 |
| Balanced | 1.0 | 1.0 |
| Aggressive | 0.45 | 2.0 |

**Risk weight** multiplies the deal-in charge on a tile, the commitment charge
for the turns it takes on, and the riichi lock-in. It moves push against fold
without touching `averagePoints` — the hand is worth what it is worth, only
danger is repriced.

**Damaten bar** multiplies how much a hand must already pay for damaten to beat
riichi. Below 1 the hand is kept quiet more often, which is the defensive line
because a quiet hand can still fold; above 1 almost everything is declared. This
is what makes the styles differ on a calm table, where there is no danger to
reprice.

**Under Hong Kong rules, only the deal-in charge is live.** There is no riichi
to lock into and no damaten to weigh, so the damaten bar is never read and the
riichi lock-in term never fires — `_assessHongKongTenpaiValue` doesn't consult
`context.style` at all. `test/hong_kong/hk_play_style_test.dart` pins that
down: style scales `dealInCost` but never changes `averagePoints`. A 14,000-game
sweep found the remaining lever doesn't move placement either (every pairwise
style comparison Holm p = 1.0), so `GameController` and `ScenarioController`
pin `PlayStyle` to Balanced and hide the dial under Hong Kong — see
[`BOT_STRATEGY.md`](BOT_STRATEGY.md#style-does-nothing-under-hong-kong).

The two interact, and that interaction had to be paid for: making damaten easier
dodges the riichi lock-in, which briefly made *defensive* the style most willing
to push a tenpai. A tenpai hand that stays quiet is now charged the ordinary
commitment cost for the turns it stays in, so only one of the two ever applies
and the ordering holds. `test/play_style_test.dart` pins that ordering down,
here and over 400 random defending tables.

## Hand focus  (`HandFocus`)

The second dial. Expected value is `chance × payout`; the focus bends both
halves by opposite exponents — the payout by `curve`, the chance by
`2 − curve` — around a pivot (5,000 points in riichi, 32 chips in Hong Kong),
so on Balanced (`curve` 1.0) the product is untouched.

| focus | curve | effect |
|---|---|---|
| Speed | 0.45 | a likelier line wins close calls; big payouts are flattened |
| Balanced | 1.0 | plain expected value |

A third setting, Value (1.55), was removed after it failed to beat the bots.

## Strategy — points or placement, riichi only

The third, independent dial (`Strategy`): not how much danger costs (Style) or which hand to
chase (Focus), but what "worth" means in the first place — the points a line
pays, or how it moves final placement. **Riichi only.** The math behind it
isn't riichi-specific, but it hasn't been wired up for Hong Kong yet, so the
dial is hidden and pinned to Points there — the same treatment Style gets,
for a different reason (see
[`BOT_STRATEGY.md`](BOT_STRATEGY.md#style-is-a-riichi-only-dial)).

The engine already separates *estimating* a line (shanten, ukeire, win
probability, what it pays, what a deal-in costs) from *valuing* it (Style's
risk weight, Focus's curve) — Strategy is one more valuation layer on the
same estimates, not a second engine. Under `Strategy.points` every line is
worth `chance × payout` as everywhere above; nothing here changes for it, and
every existing test and tuned constant still applies exactly as measured.
Under `Strategy.placement`, every points-flavoured term in that arithmetic —
the payout, the riichi deposit, the deal-in cost, the commitment cost — is run
through `EfficiencyValueContext.placementValue` instead of taken at face
value, and *that* is what gets sorted, recommended and flagged. The plain
points numbers (`DiscardLine.expectedValue`) are always still computed and
shown, so the panel can display both side by side and the metric for
whichever strategy isn't driving stays visible.

### `PlacementUtility` — the model behind `placementValue`

Lives in `lib/logic/placement_utility.dart`, deliberately apart from the main
engine file: no Monte Carlo, no rest-of-hand or rest-of-game simulation, no
opponent modelling beyond the scores already on the table. It is a closed-form
heuristic, tagged as one everywhere it is surfaced.

For each of the other three seats it approximates "chance I finish above
them" as a logistic in the score gap:

```
spread   = 5000 × sqrt(handsRemaining.clamp(1, 16))
beat(j)  = logistic((myScore − scores[j]) / spread)
U(score) = Σ beat(j)                                    // 0 (last, no hope) … 3 (first, lock)
placementValue(points) = U(myScore + points) − U(myScore)
```

`handsRemaining` is hands left in the game including the current one — a
floor, not a promise, the same as the hand counts the app bar quotes (renchan
can run a game longer than this, and it is recomputed fresh from the round
every turn). `spread` shrinks near the end of the game, so the same score gap
is worth more the closer the table is to settling: a 5,000-point lead barely
matters in East 1, and can be everything in the final hand. It is a finite
difference, not a derivative at the current score, so a large swing (a
mangan, a big deal-in) saturates once it crosses a rank instead of being
extrapolated past it.

The asymmetry that makes this behave like a real placement-conscious player
falls straight out of the logistic's shape rather than being coded in
specially: once ahead of an opponent, a loss moves the gap back *toward* the
logistic's steepest point (so it costs more, marginally, per point) while an
equal gain moves it further away (so it is worth less) — the model prices a
push against a live lead as riskier than the same push from a neutral table,
without anything checking "am I ahead" directly. The reverse holds from
behind: a gain that starts closing the gap is worth more than the equivalent
loss, which is what lets it push a hand `Strategy.points` would fold when the
table needs the swing.

### Riichi vs damaten under placement

Normally the choice between declaring and staying quiet
(`_assessTenpaiValue`) is a fixed points threshold — `qualifyingDamaten`,
scaled by `Style`'s damaten bar — checked *before* riichi is even weighed as
an alternative. That threshold is left completely untouched under
`Strategy.points`, which is why every existing riichi/damaten test still
passes unmodified. Under `Strategy.placement`, whenever riichi is a live
choice and every wait already carries a yaku on its own, the threshold is
bypassed: both the riichi path and the damaten/stand-pat path are assessed in
full (`_finishTenpaiAssessment`, pulled out of `_assessTenpaiValue` so it can
run twice) and whichever scores higher on `placementExpectedValue` wins. That
is what lets the guide take damaten to protect a lead on a hand it would
riichi for the points, and the reverse from behind — see the worked example
in [`BOT_STRATEGY.md`](BOT_STRATEGY.md).

### Known simplifications

- A heuristic proxy for "chance of finishing above seat j," not a simulation
  of the rest of the hand or the rest of the game — tagged as an estimate
  everywhere the panel shows it, never as a certainty.
- Ignores what the other three seats' hands actually look like; it only ever
  sees their scores.
- No uma or oka, because none is modelled in this game yet — see the MVP
  scope note in the technical spec this dial was built from. Adding either
  would change `U`'s shape, not the rest of the machinery.
- `spread`'s constants (5,000 points, `sqrt(handsRemaining)`) are a reasoned
  default, not fitted — in the same spirit as `handSurvivesTurn` or the
  `5800`/`8700` deal-in costs above, they have not been through the
  large-scale sweep that set Style and Focus's defaults (see
  [`BOT_STRATEGY.md`](BOT_STRATEGY.md#how-the-guide-measures-up)). Targeted
  regression tests (`test/placement_strategy_test.dart`) pin down the
  *direction* of every effect described above; a full placement sweep against
  the bots, the way Style and Focus were measured, is future work.
- Chi/pon/kan/ron call advice (`adviseCall`) is not placement-aware yet — it
  stays on `Strategy.points` regardless of the dial, matching the MVP scope
  (discard selection, riichi vs damaten, push/fold) the spec itself lays out.

## Defaults, and the evidence for them

New games and builder tables start on **Aggressive / Speed** (`kDefaultPlayStyle`,
`kDefaultHandFocus`) under riichi, with **Strategy on Points**
(`kDefaultStrategy`) — Placement is opt-in, unlike Style and Focus's measured
defaults, since it has not been through the same large-scale sweep (see
above). Under Hong Kong, `setRuleset` pins style to **Balanced** and Strategy
to **Points**, hiding both dials, so only Focus is exposed, starting on
**Speed**. `EfficiencyValueContext` still defaults to Balanced / Balanced /
Points, so tests and callers that build a context by hand get the unweighted
model.

The choice is measured, not assumed — every pairing is played on identical
seeds against a `SimpleBot` control in `test/policy_sweep_test.dart`. In brief
(full tables in [`BOT_STRATEGY.md`](BOT_STRATEGY.md#how-the-guide-measures-up)):

- **Riichi:** every Speed and Balanced pairing beat the control bot by 0.11–0.26
  of a placement over 2000 East games and 800 hanchan, Holm-corrected; the
  guide as a whole went from 0.247 worse than the bot to 0.211 better
  (p = 4e-16).
- **Hong Kong:** Aggressive / Speed placed best of the six Style × Focus
  pairings (e.g. 0.108 ahead of Balanced / Balanced, p = 1.7e-5). With the
  Hong Kong tuning below, it beats the control bot by 0.062 of a placement,
  pooled over 10,000 held-out East-only games (±0.029, p = 2.6e-5); before
  that tuning it trailed the bot. A later sweep isolating each dial
  (`_dialEffects`, 14,000 games) found Style itself does nothing there —
  every pairwise style comparison came back Holm p = 1.0 — while Speed still
  beat Balanced focus at every style (p ≤ 4e-5); see
  [`BOT_STRATEGY.md`](BOT_STRATEGY.md#style-does-nothing-under-hong-kong).

## Under Hong Kong rules

`EfficiencyValueContext.ruleset` switches only what differs; shanten, ukeire,
the win-probability walk, the lookahead and the push/fold arithmetic are shared.

| | Riichi | Hong Kong |
|---|---|---|
| Ready hand | yaku/fu/han/dora, riichi vs damaten, deposit | every live wait scored with `scoreHongKongHand`; no riichi or damaten |
| Minimum to win | one yaku | **0 faan** — any complete hand, chicken hands included |
| Before ready | 3900/5800 (closed) or 2000/2900 (open) × dora | faan from visible dragon/wind pungs, flush, concealment and flowers, priced on the New Style table |
| Payout mix | 0.65 ron / 0.35 tsumo | 0.65 discard win (discarder pays 2×) / 0.35 self-pick (all three pay, +1 faan) |
| Deal-in cost | 5800 / 8700 + honba | 16 chips (a 3-faan discard win) |
| Threat | an opponent in riichi | an opponent with **three** or more exposed sets |
| Safety | genbutsu / suji / one-chance | honour copies and tile class only; nothing is certified safe |
| Push horizon | capped at 3.8 turns (the riichi ends the hand) | the hand's own expected length |
| Narrow hand before ready | width ratio `scale^exponent` | `scale^(exponent × 0.5)` — a narrow hand can pung or chow its way forward |
| Focus pivot | 5,000 points | 32 chips |

The two Hong Kong-only settings live in `HongKongGuideTuning` and were measured,
not assumed: riichi's own values (narrow exponent × 1, threat at two sets)
placed behind `SimpleBot`; the shipped ones place 0.062 ahead of it, pooled
over three held-out runs of 10,000 games (p = 2.6e-5). A model that also
counts calls, with constants fitted to Hong Kong self-play, was built and
measured but played no better (0.014 ahead of the shipped model over 6000
paired games, p = 0.40), so it is not used. Method and tables:
[`BOT_STRATEGY.md`](BOT_STRATEGY.md#hong-kong--the-guide-beats-the-bots).

## Calls, kan, ron, tsumo  (`adviseCall`)

Every option is turned into "the 13-tile hand it leaves you with" and run back
through `analyze` for an EV on the same scale as staying put. Before EV counts,
a call must clear three hard gates:

1. **Advance the hand** — strictly lower shanten than passing.
2. **Keep a yaku** — the resulting best line must have EV > 0 (an open hand with
   no yaku scores nothing).
3. **Do not over-commit** — if a riichi is out and you would still be
   ≥ 1-shanten, fold instead.

Kan is judged **last and on shape only**, because its real payoff — a fresh
dora indicator plus a rinshan draw — is not something the value model can
price. Ron and tsumo always win: EV = the actual points, always recommended
(passing a winning tile is furiten).

## What the panel shows

- **EV (HMR)** column (left of TileSense EV) = `DiscardLine.expectedValueHmr`, a standalone
  comparison figure that plays no part in the recommendation:
  `winProbability × averagePoints`, with none of `winBonus`, `valueTilt`,
  `riichiLockCost`, `dealInCost` or `commitmentCost` folded in. It mirrors the
  "E.V." stat in HMR (Hitori Mahjong Renshuuki), a closed-source solo,
  tsumo-only trainer with no code or data ties to this project — HMR's E.V.
  was worked out empirically from its own simulation log as total points
  scored ÷ hands played, which is exactly win rate × average winning score,
  and it has no other terms because it has no other seats to add a bonus from
  or a deal-in to price. Hovering the column heading or a row's cell explains
  the number the same way TileSense EV's tooltip does. **Tapping** a row's
  EV (HMR) cell opens `ev_explainer_dialog.dart`: the win probability as a
  turn-by-turn chart (from `DiscardLine.winBreakdown`), what the win pays,
  and a waterfall from EV (HMR) to TileSense EV. See also:
  [Training tool: Hitori Mahjong Simulator](https://pathofhouou.blogspot.com/2019/05/training-tool-hitori-mahjong-simulator.html).
- **TileSense EV** column (EV = Expected Value) = `DiscardLine.expectedValue`,
  rounded.
- **Risk** column = `DiscardLine.riskCost` — the charge on the tile itself plus
  the turns it commits you to, both already taken off the value beside it.
  Shown only while defending.
- The value / "average" figure = `averagePoints` — what it pays *if* you win,
  before multiplying by the win chance.
- The plan tag and reason string come straight from `_ValueAssessment`.
- Hovering the TileSense EV column heading or a single row's cell explains
  the number in plain English. On a row it also shows that line's own
  arithmetic. The terms it prints are exposed on `DiscardLine` and reconstruct
  the number exactly:

  ```
  expectedValue = winProbability × (averagePoints + winBonus)
                  − riichiLockCost − dealInCost − commitmentCost
  ```

## Where each part is explained in the panel

There is no glossary under the table: every heading and dial that names a
concept explains itself on hover, and quotes the tuned numbers from the engine
itself (`GuideConstants`, `PlayStyle`, `HandFocus`, `PlacementUtility`) so a
retune cannot leave the text stale. Each tooltip has the same layout — a
one-line answer, bullets for the ideas, a real table wherever a reference table
is in play, then the formula.

| Hover | Explains | Table |
|---|---|---|
| Shanten / Away | what it counts | — |
| Ukeire / Accepts | what it is, how width feeds the win chance | typical ukeire by shanten |
| TileSense EV, EV (HMR) | the formula, with a pointer to where each part is worked | — |
| Safety | what the rating means (riichi; Hong Kong has its own five-tier scale) | deal-in chance by rating |
| Risk | what goes into the charge | — |
| Detail | why a tile has its rating | — |
| Placement | how a line moves your finish among the four seats | what ±8,000 is worth in five situations |
| STYLE | what each style does | risk weight, damaten bar and the payout it stays quiet from |
| FOCUS | what Speed does (chips under Hong Kong) | payout and chance, as counted by Speed |
| STRATEGY | Points versus Placement | the two definitions |
| GUIDE (title) | the green / yellow tile legend and the pause key | — |

The **Safety, Risk and Detail columns are always in the table**, showing "—"
when nobody is being defended against, so their headings — and the tooltips on
them — can be reached on any turn, under either ruleset. STYLE, STRATEGY and
Placement are riichi-only (Hong Kong pins Style to Balanced and Strategy to
Points, and has no Placement column); everything else applies to both.

Tapping an EV (HMR) number opens the turn-by-turn chart page, which also states
the pre-tenpai payout placeholders.

## Known simplifications (by design)

- Flat placeholder points before tenpai; exact scoring only once tenpai.
- Draws treated as independent; no model of opponents calling your tiles,
  advancing their own hands, or the round ending in an exhaustive draw — beyond
  the riichi-danger discount above.
- No ura-dora, no kan-dora upside, no ippatsu / haitei / houtei / rinshan /
  chankan.
- One exchange of lookahead — no deep search.
- The `0.65 / 0.35` ron/tsumo split, the projected-point tables, the `1000` and
  `4000` penalty scales, the `5200 / 7700` damaten thresholds, and the deal-in
  rate table with its `5800 / 8700` base costs are tuned constants, not derived.
- Neither estimator credits **calling**. Advancing steps are drawn-only, so an
  open hand that pons its way home is undersold. A call-aware width
  (`WinModel.pungRate` / `chowRate`) exists and was measured for Hong Kong; it
  did not improve play, so both rulesets still count draws only. This is the main reason the
  absolute pre-tenpai numbers sit below the ~21% a hand wins on average, even
  though the ordering between hands is right.

## Where it lives

| File | Role |
|---|---|
| `lib/logic/efficiency_calc.dart` | shanten + ukeire (ported from Riichi-Trainer) |
| `lib/logic/efficiency_engine.dart` | everything above — `analyze`, `_assessValue`, `_assessTenpaiValue`, `_finishTenpaiAssessment`, `adviseCall`, `_kanAdvice`, `_riichiDangerFactor` |
| `lib/logic/placement_utility.dart` | `PlacementUtility` — the model behind `Strategy.placement` |
| `lib/logic/scoring.dart` | `scoreHand` — yaku / fu / han / dora → points |
| `lib/logic/hong_kong/hong_kong_scoring.dart` | `scoreHongKongHand` — faan patterns → chips |
| `lib/logic/hong_kong/hong_kong_safety.dart` | Hong Kong risk ratings |
| `test/policy_sweep_test.dart` | Style × Focus sweep against the bots (`SWEEP_RULESET` picks the game) |
| `test/hong_kong/hk_tuning_sweep_test.dart` | `HongKongGuideTuning` variants against the bots and the original guide |
| `test/hong_kong/hk_guide_diag_test.dart` | per-decision counters, guide vs bot, under Hong Kong rules |
| `lib/logic/safety.dart` | 0–15 tile-danger rating used by the riichi discount and defensive mode |
| `lib/game/game_controller.dart` | `_refreshReport()` builds the context each turn; Autoplay reads the result |
| `lib/ui/efficiency_overlay.dart` | renders the panel |
| `test/efficiency_engine_test.dart` | regression tests (dora raises EV, dealer raises EV, dead waits, riichi-danger, …) |
| `test/placement_strategy_test.dart` | `PlacementUtility` unit tests, and regression tests for Strategy's discard/riichi-vs-damaten effects |
