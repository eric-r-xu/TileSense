# 🇹🇼 Taiwanese rules

Chosen with the ruleset toggle (welcome screen, game app bar, online lobby,
or builder chip row); Riichi remains the default. One-page reference:
[Taiwanese.pdf](https://app.ericrxu.com/static/Taiwanese.pdf).

The scoring source is the San Diego Mahjong Club's **Taiwanese Mahjong**
pamphlet (台灣麻雀), designed by Nathanael J. Reynolds. Unlike riichi and Hong
Kong, a complete Taiwanese hand is **17 tiles — five melds and a pair**, not
fourteen; the app deals for that shape rather than reskinning the 14-tile one
(see [Hand shape](#hand-shape-and-wall)).

**Minimum: 5 points** (`TaiwaneseRules.minimumPoints`). A complete hand
scoring fewer points than this cannot be declared — there is no zero-point
chicken hand the way Hong Kong's zero-faan hand is always legal.

## Hand shape and wall

- Four players, the same 144-tile wall Hong Kong plays: four of each of 34
  ordinary types plus eight unique flowers/seasons. Bonus tiles are exposed,
  not held in the concealed hand.
- The deal gives **16 tiles to every seat**. The dealer's own turn then
  begins exactly like anyone else's — an ordinary draw — which brings them to
  the **17 tiles** they open on; every other seat reaches 17 the same way, on
  their own first draw.
- A complete hand is five melds (chows, pungs, or kongs) and a pair, **or**
  the sheet's alternate shape, **Seven Pairs and a Pung** — seven distinct
  pairs plus one triplet (14 + 3 = 17 tiles). There is no Thirteen Orphans in
  Taiwanese.
- `packages/mahjong_core/lib/hand_parse.dart` and `efficiency_calc.dart` — the
  decomposition and shanten/acceptance search every bot and the guide runs on
  — take the number of melds a complete hand needs as a `totalMelds`
  parameter (4 for riichi and Hong Kong, 5 here) instead of hardcoding 4, so
  the same search drives both hand sizes. `taiwanese_hand_parse.dart` adds
  the one shape that generalization alone can't express: seven pairs and a
  pung.
- A kong still counts as one meld, the same as riichi and Hong Kong; its
  extra tile is balanced by its own replacement draw, off the tail of the
  same wall (`TileWall.drawDeadWall`), the way Hong Kong's already is.
- A **concealed kong is laid down completely face down**: the other seats
  see four tile backs, not riichi's two, and learn what it was only when the
  hand ends. The guide doesn't count those tiles as seen, and online they go
  to the other players as blanks (`Round.isHiddenKong`).

## Payments

Points are abstract, not a currency. Unlike Hong Kong's doubling faan table,
a Taiwanese hand's points are **flat and additive** — its value is simply the
sum of its features — and there is **no dealer premium on the hand's own
value**: every payer pays the same amount.

- **Self-drawn**: each of the other three players pays the hand's full point
  value.
- **Discard win**: only the discarder pays the hand's full point value; the
  other two players pay nothing.

A separate **dealer win-streak bonus** sits on top of that, paid only when
the dealer is involved:

| Consecutive dealer wins so far | Bonus |
|---:|---:|
| 0 (the dealer's first hand) | 0 |
| 1 | 2 |
| 2 | 4 |
| 3 or more | 6 |

If the dealer wins, this bonus is added to their payout using the same
payer rule as the hand itself (every other seat on a self-draw, the
discarder alone on a discard win). If the dealer instead **deals into**
someone else's win while on a streak, the dealer pays that bonus to every
winner, on top of the ordinary loss. A drawn hand is not a win: the dealer
keeps their seat but the streak resets to 0, so their next win starts back
at the 2-point tier. (`TaiwaneseRules.dealerBonus`, tracked via `honba`
repurposed as the streak counter rather than a riichi-style repeat-payment
multiplier — see `Round._applyRon`/`_finishWin` and
`GameController.rotateAfterRound`.)

## Features

Independent features add together. Where a family of features only ever
lets its strongest member fire (the way Hong Kong's terminal/honour and
triplet awards do), that is noted below.

| Feature | Points | Family / condition |
|---|---:|---|
| Value Honor | 1 each | A dragon pung/kong, or a pung/kong of your own seat wind |
| No Flower Tiles | 1 | No flowers or seasons in hand |
| No Honors | 1 | No dragons or winds in hand |
| No Flower or Honor Tiles | 3 | Replaces No Flower Tiles + No Honors together |
| Flower Tile | 1 each | Every flower/season declared, regardless of seat match |
| Self-Drawn | 1 | Tsumo — stacks with Concealed Hand / Fully Concealed Hand below |
| Concealed Hand | 1 | Closed hand, won on a discard |
| Fully Concealed Hand | 3 | Closed hand, self-drawn — the closed-and-tsumo case instead of Concealed Hand |
| Melded Kong | 1 each | An open or added kong |
| Concealed Kong | 2 each | A concealed kong |
| Two Concealed Pungs | 2 | Replaced by the stronger tiers below when they apply |
| Three Concealed Pungs | 5 | Replaces Two Concealed Pungs |
| Four Concealed Pungs | 10 | Replaces the smaller tiers |
| Five Concealed Pungs | 40 | Replaces the smaller tiers |
| Single Wait | 2 | Winning tile completes the pair |
| Closed Wait | 2 | Winning tile is the middle tile of a chow (e.g. 5 in 4-5-6) |
| Robbing the Kong | 1 | Winning on the tile added to an exposed pung |
| Last Tile Draw | 1 | Winning by drawing the final wall tile |
| Win Within 5 Discards | 10 | Fewer than five discards on the table when the hand is won |
| Win Within 5 to 10 Discards | 5 | Replaced by the above; more discards on the table but under ten |
| Pure Straight | 5 | Three consecutive chows, 1–9, in one suit |
| All Pungs | 10 | Five pungs/kongs |
| All Chows | 10 | Five chows, no flowers, and a non-honor pair |
| All Chows with Flowers or Honors | 3 | Replaces All Chows when flowers or an honor pair are present |
| Melded Hand | 10 | Every meld and the pair completed off other players' discards (ron, all five groups called) |
| Little Three Dragons | 10 | Two dragon pungs/kongs and a dragon pair |
| Big Three Dragons | 30 | Replaces Little Three Dragons and individual Value Honor dragon awards |
| Little Three Winds | 5 | Two wind pungs/kongs and a wind pair |
| Big Three Winds | 10 | Three wind pungs/kongs, replaces Little Three Winds |
| Little Four Winds | 30 | Three wind pungs/kongs and a wind pair, replaces Big Three Winds |
| Big Four Winds | 40 | Four wind pungs/kongs, replaces the smaller wind tiers |
| Half Flush | 10 | One suit plus honor tiles |
| Full Flush | 40 | One suit only, replaces Half Flush |
| Blessings of Heaven | 40 | Dealer wins with their opening 17-tile hand |
| Blessings of Earth | 40 | Non-dealer wins off the dealer's first discard |
| Seven Pairs and a Pung | 30 | The alternate hand shape — see [Hand shape](#hand-shape-and-wall) |
| All Flowers | 30 | All eight flower/season tiles; an independent win, no other feature scored |

When a hand qualifies for more than one member of the same family (for
example, three wind pungs that are also the seat wind), the app scores only
the strongest one, the same convention Hong Kong's own scoring already uses.

Two features from the source sheet are **not implemented**, as rare,
interactive edge cases rather than ordinary hand scoring:

- **Riichi** (10 points) — a house-rule declaration the sheet allows only on
  a player's very first turn, before any draw, if the opening deal is
  already one tile from mahjong. It freezes the hand except for upgrading
  concealed pungs to kongs.
- **Robbing the Flower** (20 points) — a player already holding seven
  flowers may steal an eighth flower tile another player attempts to meld,
  instantly completing All Flowers.

## Play and decisions outside the sheet

- Ordinary draws come from the front of the wall; flower and kong
  replacements come from the tail, the same as Hong Kong.
- Exposing the eighth (and last) bonus tile pauses before its replacement,
  offering the independent 30-point All Flowers win — the same
  claim-or-continue pause Hong Kong offers at its seventh flower, just moved
  to Taiwanese's own eighth, since a seventh flower carries no special score
  here. Bots/autoplay take the win when it is offered.
- **Taiwanese Furiten**: a wait tile you pass up locks you out of declaring
  mahjong on it until your own next draw — the same *temporary* furiten
  riichi has outside of a riichi declaration. Unlike riichi there is no
  permanent lock, and unlike Hong Kong (no furiten at all) this restriction
  is real: a missed win is still off-limits for that stretch of the round.
  Calling chow, pung, or kong is unaffected by furiten.
- Chow only from the immediately preceding player. Claiming a discard:
  mahjong beats pung/kong beats chow.
- Dealer repeats their seat on a win or a drawn hand, the same renchan rule
  Hong Kong uses; a full game is a hanchan (East and South, 8+ hands) by
  default, with an East-only option. The dealer-streak bonus above is
  tracked independently of this repeat rule — see [Payments](#payments).
- No riichi declaration, dora, ura-dora, or red fives.

The sheet does not specify every gameplay detail above. These choices are
explicit defaults, not additional claims about the source.

## Guide and compatibility

The efficiency guide, safety ranking, and `SimpleBot` all speak Taiwanese:
Style and Strategy have nothing left to weigh here (no riichi, no damaten,
no placement wiring yet) and are hidden and pinned, the same treatment Hong
Kong gets. Shanten and acceptance run the real 5-meld search described in
[Hand shape](#hand-shape-and-wall). Safety ranking reuses Hong Kong's
(`rankHongKongSafety`), with an opponent counted as a threat at 4 exposed
sets rather than 3.

Every payout the guide weighs is in Taiwanese points. Once a discard leaves a
hand ready it scores each wait exactly with the point chart above
(`scoreTaiwaneseHand`), a self-draw collected from all three other seats;
before that it estimates the payout from the patterns the hand already shows
(`_taiwaneseProjectedPoints`). Its win-probability model counts pung and chow
acceptance as well as draws (`WinModel.taiwanese`), since a five-set hand
leans on calls. Tuned this way it beats the bots by 0.15 of a placement on
held-out seeds — see "Taiwanese — the guide beats the bots" in
[`BOT_STRATEGY.md`](../flutter_client/BOT_STRATEGY.md).

The guide above is offline-only: multiplayer hides it entirely, so no seat
gets an assist the others lack.

Internal API and telemetry names (`han`, `yaku`, `ron`/`hu`, `tsumo`, `chi`,
`pon`, `kan`, `hanchan`) are shared with riichi and Hong Kong. Under
Taiwanese rules `han` carries the point total and `yaku` carries the
feature list; win/self-draw buttons read "Hu" / "Self-pick"
(`Ruleset.ronLabel`/`tsumoLabel`).
