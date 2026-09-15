# Bot Strategy vs. You (Orderic)

A plain-language breakdown of how Grant, Hubert, and Astaroth decide what to
do — and how that compares to how your own seat plays. Based on
`lib/logic/bot.dart` (the opponents' brain) and `lib/logic/efficiency_engine.dart`
+ `safety.dart` (your guide).

## The short version

- **There is only one opponent "brain," used for all three of them.** Grant,
  Hubert, and Astaroth are not three different strategies — they're the exact
  same simple rulebook, just with different portraits and voice lines glued on
  top.
- **Your seat is played by the guide, never by that rulebook.** Whether you're
  tapping tiles yourself or you've flipped Autoplay on, your seat's decisions
  come from the efficiency / expected-value / safety analysis. The opponents
  never get any of it.
- **The opponents can't count points and can't play defense.** They have no
  idea what a hand is worth, they can't see dora, and they discard exactly the
  same way whether the table is calm or a riichi is bearing down on them.

- **Autoplay starts on Speed** in both rulesets, and on Aggressive under
  riichi — chosen from measured sweeps (see
  [How the guide measures up](#how-the-guide-measures-up)). The guide beats
  the bots at a statistically significant level in both rulesets.
- **Style is a riichi-only dial.** Hong Kong has no riichi or damaten for it
  to weigh, and a full sweep found no placement effect from it either, so the
  toggle is hidden and pinned to Balanced under Hong Kong rules.

## Same brain, three costumes

All three opponents are built from one piece of code, with only the
random-number seed differing so their tie-breaking coin flips don't all land
the same way:

```dart
_bots = [for (var i = 0; i < 4; i++) SimpleBot(_seed + i * 7 + _roundNumber)];
```

(Seat 0 gets an instance too, but nothing asks it for a decision — your seat
routes to the guide instead.)

## How an opponent picks what to discard

No lookahead, no scorekeeping — just a checklist, top to bottom, stopping at
the first rule that produces a tile:

- **Rule 1 — don't break a winning shape.** If any tile can be thrown without
  ruining a "one tile away" (tenpai) hand, throw one. If several qualify it
  takes the first it finds — no comparison of which leaves better odds or a
  bigger score.
- **Rule 2 — protect anything it holds three of.**
- **Rule 3 — dump useless honor tiles first.** Winds and dragons that can't
  score for that seat, or ones it holds a single copy of.
- **Rule 4 — otherwise work outward from "useless" to "useful":** skip scoring
  winds/dragons, skip tiles sitting next to another tile it holds, skip pairs,
  skip near-neighbours, skip terminals — each step only applied if it still
  leaves something to throw.
- **Rule 5 — pick at random from whatever survives.**

**What's missing:** any notion of value. The bot cannot see that a tile is a
red five or a dora, and will throw one away if the shape rules flag it as
isolated.

## How an opponent handles riichi, and calls

- **Riichi:** one hard-coded cutoff. If every possible winning tile already
  scores on its own *and* the smallest of those is worth 5200+ (7700+ as
  dealer), it stays quiet; otherwise it declares. No weighing of win chance
  against the 1000-point deposit.
- **Ron:** always taken.
- **Pon:** only for a tile worth something by itself (a dragon, or the
  seat/round wind), and only when already holding exactly two.
- **Chi:** never. The table offers it now, but the opponents' rulebook has no
  concept of it, so they let every chi go by — a free edge for you.
- **Closed kan:** taken every time it's legal, with no thought about whether
  flipping a fresh dora indicator is a good idea right now.

## What the opponents never do: play defense

Once someone declares riichi, a careful player starts choosing discards that
are provably safe instead of pushing their own hand. **The bots don't do this
at all** — the same checklist runs regardless. No safety check, no folding, no
risk-awareness, ever.

## What your seat does instead

Everything below applies whether you're playing manually (as advice) or on
Autoplay (as the actual move):

- **A real look-ahead calculator.** For every tile you could discard: exactly
  how far from a win you'd be, and exactly how many tiles would bring you
  closer.
- **Real point math.** It scores every live winning tile for real — yaku, han,
  fu, dora, red fives — blends win-by-discard against win-by-draw, and
  discounts by how many draws are realistically left.
- **An honest riichi-or-stay-quiet call**, with the 1000-point deposit and the
  chance of never winning priced in.
- **A safety table the moment a riichi lands** — every tile rated 0
  (dangerous) to 15 (provably safe) with a reason, and while you're still
  behind, the recommendation switches from "best" to "safest."
- **Call advice on every offer**, covering ron, chi, pon and kan. Each option is
  scored the same way as a discard — the state it leaves you in once melds
  count — and then has to clear three hard rules:
  1. **It has to get you closer.** A call that leaves you the same distance
     from a win is refused; it only costs you a concealed hand.
  2. **It has to leave a yaku.** Opening a hand that then has no way to score
     is refused outright.
  3. **It must not commit you into a riichi.** If someone has declared and
     you're still behind, it folds instead of opening up.
  Kan is judged last and on shape alone, because its real payoff — an extra
  dora indicator — cuts both ways and helps the opponents too.

Because it actually counts points, the guide will often *decline* a call the
opponents would grab: ponning a dragon to reach a 1000-point tanki is worse
than staying closed on a hand averaging 3900. It takes the call when the call
genuinely wins — a real tenpai with a decent wait, or a meld dragging three
dora along with it.

## Side-by-side

| | The opponents | Your seat (manual or Autoplay) |
|---|---|---|
| Picking a discard | Fixed checklist, first match wins, random tie-break | Every option ranked by real win-odds and real point value |
| Sees dora / red fives? | No | Yes, including dora inside called melds |
| Riichi vs. stay quiet | Hard-coded points cutoff | Real math on both, deposit risk included |
| Chi / pon / kan / ron | Simple fixed rules; never chis | Every option scored on expected value, then three hard rules |
| Plays defense vs. a riichi | Never | Yes — safety ratings, and it folds when behind |
| Explains itself | — | Yes, in plain English, in the guide panel |
| Different per character? | No — one shared brain in three costumes | — |

## About chi

Chi is fully in play: the round offers it to the seat immediately after the
discarder (and only that seat), it loses to pon, kan and ron, and it's barred
while you're in riichi — the normal rules. When the same discard could be
taken as more than one run — holding 34567p and offered 5p, you could make
345p, 456p or 567p — the guide scores each and takes the best, so the CHI
button stays a single tap.

The opponents never call it. That's deliberate: `SimpleBot` is a port of the
original desktop client's simplest bot, which has no chi logic, and keeping it
that way preserves the "they're a checklist, you have a calculator" gap this
document describes. The practical effect is that chi discards sail past them,
which makes the opponents a little slower than real players would be.

## Under Hong Kong rules

The same `SimpleBot` plays Hong Kong, with one branch: because any complete
hand wins there (0-faan minimum, no yaku needed), it **calls far more freely**.
It always takes a kong, and takes a pung or a chow whenever it lowers the
hand's shanten. It always declares a win, including a seventh- or eighth-flower
win. It still never defends.

Your seat's guide swaps in Hong Kong scoring (faan converted to chips on the
New Style table), Hong Kong defence (no genbutsu or suji — nothing is ever
certified safe, and the threat is an opponent with three or more exposed
sets), a 16-chip deal-in cost, and a gentler penalty on narrow hands before
ready (see [Hong Kong — the guide beats the bots](#hong-kong--the-guide-beats-the-bots)).
There is no riichi, damaten or deposit to weigh — which is also why the
**Style** dial is hidden under Hong Kong and pinned to Balanced rather than
left for you to set (see [Style does nothing under Hong Kong](#style-does-nothing-under-hong-kong)).

## How the guide measures up

Autoplay plays your seat from the guide's own recommendation — the
highest-expected-value discard, its call advice and its kong verdict — tuned by
two dials: **Style** (how dearly danger is priced) and **Focus** (Speed
sharpens the gap between a likely hand and an unlikely one; Balanced leaves
expected value alone). Both start on **Aggressive / Speed** under riichi;
Hong Kong hides Style and pins it to Balanced (see below), so only Focus is
exposed there, starting on **Speed**.

That default comes from `test/policy_sweep_test.dart`, which plays every
Style × Focus pairing on the *same* seeds (common random numbers) against a
**control arm**: `SimpleBot` sitting in your seat. Every guide arm is compared
game-by-game with the control, and p-values are Holm-corrected across the
pairings. Placement is 1–4 (lower is better; ties split). The same file's
`_dialEffects` isolates each dial on its own — Speed vs. Balanced focus at
every style, and every style pairing averaged over focus — which is what
established that Style does nothing under Hong Kong (see below).

### Riichi — the guide beats the bots

Recorded in commit `e850241` ("Stop paying width a premium it never earned,
and drop the Value focus"), measured against opponents that fold (`FoldingBot`):

| Measurement | Result |
|---|---|
| Guide vs. control bot, 3000 paired hanchan, after capping the width premium | **0.211 of a placement better** (was 0.247 worse), p = 4e-16 |
| Same change, guide against itself before the fix | −0.457 placement, p = 3e-96; deal-ins −0.080 per hanchan |
| All nine Style × Focus pairings, 2000 East games and again 800 hanchan, Holm-corrected | **Every Speed and Balanced pairing beat the bot by 0.11–0.26 of a placement** in both runs |
| The three Value pairings (since removed) | On or behind the bot in both runs (hanchan: Aggressive/Value −0.001, Balanced/Value +0.034, Defensive/Value +0.064) |

Aggressive / Speed is one of the six pairings that beat the bot; the recorded
runs do not rank those six against each other.

### Hong Kong — the guide beats the bots

**Result.** The shipped guide was measured on three sets of seeds that no
tuning round used — East-only games, Aggressive / Speed, `SimpleBot`
opponents, common random numbers. Δ is placement vs the control (`SimpleBot`
in your seat); negative means the guide finishes higher.

| Held-out run | Games | Guide place | Bot place | Δ vs bot (95% CI) | p |
|---|---|---|---|---|---|
| seeds 13000+ | 2000 | 2.369 | 2.486 | −0.116 ± 0.065 | 4.2e-4 |
| seeds 60000+ | 2000 | 2.428 | 2.514 | −0.086 ± 0.064 | 9.0e-3 |
| seeds 100000+ | 6000 | 2.437 | 2.473 | −0.036 ± 0.037 | 0.059 |
| **pooled (inverse-variance)** | **10000** | | | **−0.062 ± 0.029** | **2.6e-5** |

The tuned guide beats the bot by **about 0.06 of a placement**. The first
held-out run overstated that — the largest run found the smallest gap, and
the three differ more than chance alone usually produces (heterogeneity
p = 0.08) — so the pooled figure is the one to quote. Riichi's settings on the
same seeds placed *behind* the bot (+0.063 and +0.050 on the first two), so the
tuning is worth roughly 0.15 of a placement (0.179 and 0.136 on those runs,
both p < 1e-5).

**What was wrong.** A decision-level diagnostic
(`HK_DIAG=600 flutter test test/hong_kong/hk_guide_diag_test.dart`) plays your
seat both ways on the same seeds and counts what each does. Two faults stood
out:

1. **It broke up close hands for wider ones.** The pre-ready win model, built
   for riichi, marks a hand narrower than typical down hard. It credits only
   drawn tiles, so in Hong Kong — where any pung or chow advances a hand and
   no yaku is needed — narrow hands were badly undersold. The guide stepped
   *further* from ready on 1.3 calm-table discards per hand, five times as
   often as the bot.
2. **It defended, and refused calls, almost every hand.** It counted any
   opponent with two exposed sets as a threat. The bots expose two sets in
   most hands, so the guide spent three turns a hand defending — and a
   riichi-era rule refuses calls while threatened, which accounted for 67% of
   the calls it turned down that the bot took.

**How the fix was chosen.** `test/hong_kong/hk_tuning_sweep_test.dart` plays
tuning variants on identical seeds against the bot and against the original
guide, Holm-corrected. Round 1 (1500 games per arm) tried each candidate alone;
softening the narrow-hand penalty was the only large win (−0.168 placement vs
the original, p < 1e-6), while extra per-turn call chances made things worse
(+0.094) and removing the call gate or the concealed-hand faan from the
estimate did nothing measurable. Round 2 (2000 games per arm, fresh seeds)
refined it:

| Variant (round 2) | Δ place vs original | Δ place vs control |
|---|---|---|
| narrow penalty 0.25 | −0.174 | −0.114, p = 5.2e-4 |
| narrow penalty 0.5 | −0.152 | −0.092, p = 4.7e-3 |
| narrow penalty 0.75 | −0.081 | −0.021, p = 0.54 |
| penalty 0.5 + no call gate | −0.156 | −0.096, p = 3.2e-3 |
| **penalty 0.5 + threat at 3 sets** | **−0.183** | **−0.123, p = 1.8e-4** |
| penalty 0.5 + no gate + threat at 3 | −0.172 | −0.112, p = 6.4e-4 |

Picking the best of six flatters it, which is why the headline figures above
come from the separate held-out run. Shipped in `HongKongGuideTuning`:
**narrow penalty 0.5, threat at three or more exposed sets**, call gate kept.

**How it plays now** (per hand, 600 East-only games each):

| | Original guide | Tuned guide | SimpleBot |
|---|---|---|---|
| Steps away from ready | 1.84 | **0.76** | 0.37 |
| Hands that reach ready | 41% | **51%** | 55% |
| Chows / pungs / kongs taken | 0.39 / 0.40 / 0.04 | **0.50 / 0.43 / 0.05** | 0.68 / 0.53 / 0.06 |
| Turns spent defending | 2.96 | **0.58** | 0.54 |
| Wins | 0.216 | **0.247** | 0.249 |
| Deal-ins | 0.173 | **0.169** | 0.199 |
| Chips won | 2.13 | **2.68** | 2.59 |

It now wins as often as the bot while dealing in 15% less, and wins slightly
bigger hands.

**Counting calls and calibrating the model — tried, not adopted.** The
obvious next step was to fix the model itself rather than patch it:

1. **Count calls.** `TileEfficiencyCalculator.callAcceptance` counts the live
   tiles a hand could pung (off any seat) or chow (off the left seat) to move
   forward, and `WinModel.pungRate` / `chowRate` add them to its width.
2. **Calibrate for Hong Kong.** `test/hong_kong/hk_calibration_data_test.dart`
   logged 159,092 guide decisions from 3000 games, and
   `tools/fit_hk_win_model.py` — a line-for-line mirror of the Dart model,
   checked to agree to 4e-16 — fitted every `WinModel` constant to whether
   each hand went on to win.

The fit transformed how well the model predicts. Riichi's constants had a
1-shanten hand winning 41% of the time against a real 25%; on 53,938 held-out
decisions log loss fell from 0.5575 to 0.5270 (calibrated) and 0.5246
(calibrated with calls), with fitted rates of about 1.0 per pungable and 1.6
per chowable tile. But predicting better is not the same as choosing better:

| 2000 games, seeds 60000+ | Guide place | Δ vs bot |
|---|---|---|
| shipped | 2.428 | −0.086 |
| calibrated, draws only | 2.623 | **+0.109 (worse than the bot)** |
| calls counted, original constants | 2.425 | −0.089 |
| calibrated with calls | 2.385 | −0.129 |

Calibration alone made play *worse* — the constants that best predict the hand
the guide kept do not rank the hands it could have kept instead. Calibrated
with calls looked best, so it went to a direct head-to-head against the
shipped guide over 6000 paired games on fresh seeds (`HK_TUNE_ROUND=5`):
**0.014 of a placement better, ± 0.033, p = 0.40** — no measurable gain. The
shipped model stays; the call counter, the calibration harness and the fitter
remain for the next attempt, which should fit the model to *decisions* (which
discard leads to more wins) rather than to outcomes.

### Style does nothing under Hong Kong

Two of Style's three effects are already dead code under Hong Kong: it has no
riichi to lock into and no damaten to weigh, so `PlayStyle.damatenBar` is
never read and the riichi lock-in cost term never fires — Hong Kong scores
tenpai through its own `_assessHongKongTenpaiValue`, which doesn't touch
`context.style` at all. The one live wire left is `PlayStyle.riskWeight`
scaling the flat Hong Kong deal-in cost on every discard.

`_dialEffects` in `test/policy_sweep_test.dart` measured whether that
remaining wire moves anything, 2000 East-only games per Style × Focus arm
(14000 games total), Holm-corrected within each family:

| Comparison | Δ placement (95% CI) | Holm p |
|---|---|---|
| Defensive − Balanced (avg. focus) | 0.002 ± 0.008 | 1.0 |
| Defensive − Aggressive (avg. focus) | 0.005 ± 0.010 | 1.0 |
| Balanced − Aggressive (avg. focus) | 0.003 ± 0.006 | 1.0 |
| Speed − Balanced focus, every style | −0.10 to −0.11 ± 0.05 | ≤ 4.0e-5 |

Style is a well-powered null: every pairwise comparison is near zero with
Holm p = 1.0. Focus, on the same seeds, is not — Speed beats Balanced focus
at every style. So Autoplay's Hong Kong default is **Speed**, and the Style
toggle is hidden and pinned to Balanced rather than shown doing nothing (see
`GameController.setRuleset` and `ScenarioController.setRuleset`).

**Style and Focus.** The Style × Focus sweep was run on the original guide
(2000 East-only games per arm): Aggressive / Speed placed best of the six —
0.021 ahead of Balanced / Speed (p = 6.5e-3), 0.108 ahead of Balanced /
Balanced (p = 1.7e-5), with Speed ahead of Balanced at every style — though
all six then trailed the bot. The tuning above was measured on Aggressive /
Speed; the other pairings have not been re-swept on the tuned guide.

Re-run either sweep with, for example:

```sh
SWEEP_GAMES=2000 SWEEP_EAST=1 flutter test test/policy_sweep_test.dart                          # riichi
SWEEP_GAMES=2000 SWEEP_EAST=1 SWEEP_RULESET=hongKong flutter test test/policy_sweep_test.dart   # Hong Kong
HK_TUNE_ROUND=3 HK_TUNE_SEED=13000 HK_TUNE_GAMES=2000 flutter test test/hong_kong/hk_tuning_sweep_test.dart
HK_TUNE_ROUND=5 HK_TUNE_SEED=100000 HK_TUNE_GAMES=6000 flutter test test/hong_kong/hk_tuning_sweep_test.dart   # head-to-head
HK_CALIB_GAMES=3000 HK_CALIB_OUT=calib.csv flutter test test/hong_kong/hk_calibration_data_test.dart
python3 tools/fit_hk_win_model.py calib.csv holdout.csv
HK_DIAG=600 flutter test test/hong_kong/hk_guide_diag_test.dart
```

## Bottom line

The opponents don't out-think you. They're a short, fixed checklist with no
sense of point value and zero defense, ported from the original desktop game's
simplest bot. Your seat plays a genuinely different game — one that counts
points, weighs calls, and folds when it should — and in both rulesets that
wins, measurably.
