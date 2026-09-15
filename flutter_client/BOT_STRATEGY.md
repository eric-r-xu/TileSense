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

- **Autoplay starts on Aggressive / Speed** in both rulesets — chosen from
  measured sweeps (see [How the guide measures up](#how-the-guide-measures-up)).
  In riichi the guide beats the bots at a statistically significant level; in
  Hong Kong it does not yet.

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
certified safe, and the threat is an opponent with two or more exposed sets),
and a 16-chip deal-in cost. There is no riichi, damaten or deposit to weigh.

## How the guide measures up

Autoplay plays your seat from the guide's own recommendation — the
highest-expected-value discard, its call advice and its kong verdict — tuned by
two dials: **Style** (how dearly danger is priced) and **Focus** (Speed
sharpens the gap between a likely hand and an unlikely one; Balanced leaves
expected value alone). Both start on **Aggressive / Speed**.

That default comes from `test/policy_sweep_test.dart`, which plays every
Style × Focus pairing on the *same* seeds (common random numbers) against a
**control arm**: `SimpleBot` sitting in your seat. Every guide arm is compared
game-by-game with the control, and p-values are Holm-corrected across the
pairings. Placement is 1–4 (lower is better; ties split).

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

### Hong Kong — the best setting, but the bots still win

Run for this change: 2000 East-only games per arm, Hong Kong rules,
`SimpleBot` opponents, common random numbers
(`SWEEP_GAMES=2000 SWEEP_EAST=1 SWEEP_RULESET=hongKong`). A four-wind
confirmation run was started and stopped before it finished.

| Arm | Avg place | 1st % | Win / hand | Deal-in / hand | Δ place vs control | Holm p |
|---|---|---|---|---|---|---|
| control (SimpleBot) | 2.443 | 25.8 | 0.262 | 0.196 | — | — |
| **Aggressive / Speed** | **2.571** | 20.9 | 0.214 | 0.174 | +0.129 ± 0.064 | 8.8e-5 |
| Balanced / Speed | 2.593 | 20.5 | 0.212 | 0.176 | +0.150 ± 0.064 | 9.6e-6 |
| Defensive / Speed | 2.607 | 19.9 | 0.205 | 0.174 | +0.165 ± 0.065 | 1.7e-6 |
| Aggressive / Balanced | 2.673 | 18.4 | 0.158 | 0.182 | +0.231 ± 0.065 | < 1e-6 |
| Balanced / Balanced | 2.680 | 18.1 | 0.152 | 0.177 | +0.237 ± 0.064 | < 1e-6 |
| Defensive / Balanced | 2.695 | 17.8 | 0.148 | 0.173 | +0.253 ± 0.064 | < 1e-6 |

- **Aggressive / Speed is the best Hong Kong setting**, and significantly so:
  0.021 of a placement ahead of Balanced / Speed (p = 6.5e-3), 0.036 ahead of
  Defensive / Speed (p = 3.6e-3) and 0.108 ahead of Balanced / Balanced
  (p = 1.7e-5). Speed beats Balanced at every style.
- **But every guide setting places significantly *worse* than the plain bot.**
  The guide deals in less (0.174 vs 0.196 per hand) yet wins far less often
  (0.214 vs 0.262). With a 0-faan minimum the race to *any* complete hand
  dominates, and the bot's habit of calling every improving pung and chow gets
  there first; the guide's pre-ready estimator credits drawn tiles only, not
  calls, so it undersells open hands. That is the next thing to fix for Hong
  Kong.

Re-run either sweep with, for example:

```sh
SWEEP_GAMES=2000 SWEEP_EAST=1 flutter test test/policy_sweep_test.dart                          # riichi
SWEEP_GAMES=2000 SWEEP_EAST=1 SWEEP_RULESET=hongKong flutter test test/policy_sweep_test.dart   # Hong Kong
```

## Bottom line

The opponents don't out-think you. They're a short, fixed checklist with no
sense of point value and zero defense, ported from the original desktop game's
simplest bot. Your seat plays a genuinely different game — one that counts
points, weighs calls, and folds when it should. In riichi that wins, measurably;
in Hong Kong, where speed is nearly everything, the checklist's eager calling
still has the edge.
