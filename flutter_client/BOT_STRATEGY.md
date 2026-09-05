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

## Bottom line

The opponents don't out-think you. They're a short, fixed checklist with no
sense of point value and zero defense, ported from the original desktop game's
simplest bot. Your seat plays a genuinely different game — one that counts
points, weighs calls, and folds when it should.
