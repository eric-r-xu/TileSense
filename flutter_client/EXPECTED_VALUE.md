# Expected Value — how the guide scores a discard

A plain-language walkthrough of the number in the guide panel's **Expected
Value** column, and how it picks the recommended discard and drives Autoplay.
Based on `lib/logic/efficiency_engine.dart`, `lib/logic/efficiency_calc.dart`
(shanten / ukeire), and `lib/logic/scoring.dart` (hand value). The opponents
use none of this — see [`BOT_STRATEGY.md`](BOT_STRATEGY.md).

## The short version

- **Expected Value (EV) = how likely this hand is to finish × what it pays,
  minus a couple of risk penalties.** It's in points, not a shanten count.
- Every legal discard gets its own EV. The guide recommends the **highest-EV**
  one — except when an opponent is in riichi and you are not yet tenpai, when it
  recommends the **safest** tile instead.
- Two different estimators depending on where the hand sits:
  - **Not yet tenpai:** a rough "will I even get there, and roughly what will it
    be worth" figure with flat placeholder point values.
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

```
draws        = max(1, (wallTilesRemaining + 3) / 4)      // your remaining draws
improveRate  = min(1, ukeire / unseenTiles)              // chance one draw helps
steps        = shanten + 1                               // improvements still needed
drawsPerStep = draws / steps                             // draws are SHARED across the steps
improveProb  = 1 − (1 − improveRate) ^ drawsPerStep
completion   = improveProb ^ steps
EV           = completion × projectedPoints
```

`drawsPerStep` splitting the wall across the steps is the important bit: without
it, a wide hand three tiles away looked likelier to finish than a narrow hand
one tile away, which made "call vs. don't" meaningless.

`projectedPoints` is a flat stand-in until the hand is actually tenpai:

| | dealer | non-dealer |
|---|---|---|
| closed | 5800 | 3900 |
| open | 2900 | 2000 |

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
draws         = max(1, (wallTilesRemaining + 3) / 4)
opportunities = draws × 2   if ron is possible   (someone's discard OR your draw can hit)
              = draws × 1   otherwise
hitRate       = liveWaits / unseenTiles
winProb       = 1 − (1 − hitRate) ^ opportunities
EV            = winProb × selectedPoints
```

**Riichi penalties** — only applied when the guide is actually recommending
riichi:

- `EV −= (1 − winProb) × 1000` — the 1000-point stick you forfeit if you do not
  win.
- If an opponent is *also* in riichi:
  `EV −= (1 − winProb) × riichiDangerFactor × 4000` — the cost of being locked
  into tsumogiri on a live board. A big enough hand still clears it.

### `riichiDangerFactor`  (0 = safe … 1 = dangerous)

The weighted-average danger of **every tile you might still draw and be forced
to tsumogiri** under your own riichi, using the same 0–15 `safety.dart` rating
the defensive panel uses, weighted by how many copies of each remain. It is
purely a discount on your own riichi when someone else has already declared.

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

- **Expected Value** column = `DiscardLine.expectedValue`, rounded.
- The value / "average" figure = `averagePoints` — what it pays *if* you win,
  before multiplying by the win chance.
- The plan tag and reason string come straight from `_ValueAssessment`.

## Known simplifications (by design)

- Flat placeholder points before tenpai; exact scoring only once tenpai.
- Draws treated as independent; no model of opponents calling your tiles,
  advancing their own hands, or the round ending in an exhaustive draw — beyond
  the riichi-danger discount above.
- No ura-dora, no kan-dora upside, no ippatsu / haitei / houtei / rinshan /
  chankan.
- One exchange of lookahead — no deep search.
- The `0.65 / 0.35` ron/tsumo split, the projected-point tables, the `1000` and
  `4000` penalty scales, and the `5200 / 7700` damaten thresholds are tuned
  constants, not derived.

## Where it lives

| File | Role |
|---|---|
| `lib/logic/efficiency_calc.dart` | shanten + ukeire (ported from Riichi-Trainer) |
| `lib/logic/efficiency_engine.dart` | everything above — `analyze`, `_assessValue`, `_assessTenpaiValue`, `adviseCall`, `_kanAdvice`, `_riichiDangerFactor` |
| `lib/logic/scoring.dart` | `scoreHand` — yaku / fu / han / dora → points |
| `lib/logic/safety.dart` | 0–15 tile-danger rating used by the riichi discount and defensive mode |
| `lib/game/game_controller.dart` | `_refreshReport()` builds the context each turn; Autoplay reads the result |
| `lib/ui/efficiency_overlay.dart` | renders the panel |
| `test/efficiency_engine_test.dart` | regression tests (dora raises EV, dealer raises EV, dead waits, riichi-danger, …) |
