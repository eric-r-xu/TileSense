# 🇯🇵 Japanese riichi rules

The default ruleset; switch with the ruleset toggle (welcome screen, game app
bar, or builder chip row). One-page reference:
[Riichi.pdf](https://app.ericrxu.com/static/Riichi.pdf).

The engine is adapted from [OpenRiichi](https://github.com/FluffyStuff/OpenRiichi)
(`packages/mahjong_core/lib/round.dart`, `scoring.dart`, `wall.dart`). It covers
the common yaku, the standard fu table and the yakuman set; a few rare rules are
simplified or left out, as listed below. This is a trainer, not a ruleset arbiter.

## Table

- Four players, 136 tiles: four of each of 34 types, with **one red five per suit** (aka dora). No flowers.
- Everyone starts on **25,000 points**. A full game is a **hanchan** — East and South, 8 dealerships — or East only as an option.
- 14 tiles form the dead wall: four kan replacements and the dora / ura-dora indicators. The other 122 are the live wall. A kan's replacement comes from the dead wall and shortens the live wall by one. At most four kans are made per hand.
- Chi only from the player on your left. Ron takes priority over pon/kan, then chi. Added kans can be robbed (chankan); closed kans cannot.
- **Multiple ron** is allowed: every seat that can ron wins, each paid separately by the discarder. There is no head bump.
- The game ends after the last scheduled hand unless the dealer repeats it, or at once when anyone falls **below zero** (tobi). There is no West-round extension, no uma or oka, and the dealer keeps playing the last hand for as long as they repeat.

## Riichi and furiten

- **Riichi** needs a closed hand that is tenpai after the declaring discard, at least 1,000 points, and at least four tiles left in the live wall. It costs a 1,000-point stick.
- A hand in riichi is frozen: it must discard what it draws. It may make a closed kan only of the tile just drawn, and only if that leaves the wait unchanged; added kans are blocked. (Real rules allow some added kans; the trainer keeps riichi hands fixed.)
- **Double riichi** is a riichi on your first discard with no call or kan at the table yet. **Ippatsu** lasts until your next discard or any call or kan.
- **Furiten** bars ron, never tsumo, in three cases: a wait is in your own discards (including tiles later called away); you passed a winning tile since your last draw (temporary); or you passed one while in riichi (permanent for the hand).
- **Kyuushu kyuuhai**: any seat may abort the hand on its first discard, before any call or kan, with nine or more different terminals and honours. The dealer repeats and a honba is added.

## Yaku

A hand needs at least one yaku to win; dora alone never count. Open values are shown where a yaku is allowed open.

| Yaku | Closed | Open | Notes |
|---|---:|---:|---|
| Riichi | 1 | — | Double Riichi: 2 |
| Ippatsu | 1 | — | |
| Menzen Tsumo | 1 | — | Self-draw with a closed hand |
| Haitei Raoyue / Houtei Raoyui | 1 | 1 | Last live-wall tile / last discard; not on a kan replacement |
| Rinshan Kaihou | 1 | 1 | Win on a kan replacement |
| Chankan | 1 | 1 | Robbing an added kan |
| Tanyao | 1 | 1 | All simples; open tanyao allowed |
| Yakuhai | 1 each | 1 each | Dragon triplet, round wind, seat wind; a double wind earns 2 |
| Pinfu | 1 | — | All sequences, non-yakuhai pair, two-sided wait |
| Iipeiko | 1 | — | Two identical sequences |
| Ryanpeikou | 3 | — | Replaces Iipeiko |
| Sanshoku Doujun | 2 | 1 | Same sequence in all three suits |
| Sanshoku Doukou | 2 | 2 | Same triplet in all three suits |
| Ittsu | 2 | 1 | 123-456-789 in one suit |
| Chanta | 2 | 1 | Every set and the pair hold a terminal or honour |
| Junchan | 3 | 2 | As Chanta with no honours; replaces it |
| Toitoi | 2 | 2 | Four triplets or kans |
| Sanankou | 2 | 2 | Three concealed triplets; a triplet completed by ron counts as open |
| Sankantsu | 2 | 2 | |
| Honroutou | 2 | 2 | All terminals and honours, four triplets (so always with Toitoi) |
| Shousangen | 2 | 2 | Two dragon triplets and a dragon pair |
| Honitsu | 3 | 2 | One suit plus honours |
| Chinitsu | 6 | 5 | One suit only; replaces Honitsu |
| Chiitoitsu | 2 | — | Seven pairs, always 25 fu |

**Yakuman** (8,000 basic points each; they stack): Kokushi Musou, Suuankou,
Daisangen, Shousuushii, Daisuushii (double), Tsuuiisou, Chinroutou, Ryuuiisou
(2, 3, 4, 6, 8 sou and green dragon; the dragon is not required) and Chuuren
Poutou (closed). 13 or more han is **kazoe yakuman**. Suuankou tanki and the
nine-sided Chuuren are not doubled.

**Not implemented:** Tenhou, Chiihou, Renhou, Suukantsu and nagashi mangan; the
four-wind, four-riichi and four-kan abortive draws.

**Seven pairs** currently scores only its own 2 han plus dora: it does not add
Riichi, Menzen Tsumo, Tanyao, Honroutou or the flushes (Tsuuiisou is the one
exception).

## Dora

- One dora indicator shows at the start; each kan reveals another as its replacement is drawn. The dora is the next tile in sequence (9 → 1, winds E → S → W → N → E, dragons white → green → red → white).
- **Ura-dora** under each revealed indicator count only on a riichi win.
- Each red five is one more han. Dora of every kind count only on a hand that already has a yaku, and are not added to yakuman.

## Fu and points

- 20 fu base, +10 for a closed ron, +2 for a tsumo. Pinfu is 30 fu on ron and 20 on tsumo. Chiitoitsu is 25.
- Triplets: 2 open simple, 4 closed simple or open terminal/honour, 8 closed terminal/honour; kans ×4. A yakuhai pair +2 (a double-wind pair +4). A kanchan, penchan or tanki wait +2 — unless the winning tile can also be read as a two-sided wait.
- Fu round up to the next 10, except that an open hand winning by ron with nothing beyond base fu stays at 20 (standard rules score it as 30).
- Basic points = fu × 2^(han + 2), then limits: **mangan** 2,000 at 5 han or once basic reaches 2,000 (no kiriage mangan), **haneman** 3,000 at 6–7, **baiman** 4,000 at 8–10, **sanbaiman** 6,000 at 11–12, **kazoe yakuman** 8,000 at 13+.
- **Ron**: the discarder pays 4× basic, or 6× to the dealer. **Tsumo**: a dealer collects 2× basic from each seat; a non-dealer collects 2× from the dealer and 1× from the others. Each payment rounds up to 100.

## Honba, sticks and draws

- **Honba** add 300 to a ron (from the discarder, to each winner) or 100 from each payer on a tsumo. A honba is added when the dealer repeats or on an exhaustive draw, and reset when the dealership passes after a win.
- **Riichi sticks** on the table go to the winner — on a multiple ron, the winner nearest the discarder in turn order. After a draw they carry to the next hand.
- **Exhaustive draw**: tenpai seats share 3,000 points from the noten seats (1,000 / 1,500 / 3,000 each, depending on the split); nothing moves if everyone or no one is tenpai. The dealer repeats if tenpai.
- Pon and chi are still offered on the last discard of the hand.

## Guide

The guide grades every discard on shanten, ukeire, probability-weighted point
value (including honba and sticks) and, once an opponent threatens, safety. It is
offline-only: multiplayer hides it, so no seat gets an assist the others lack.
For how it compares with the shipped bots, see
[`BOT_STRATEGY.md`](../flutter_client/BOT_STRATEGY.md#riichi--the-guide-beats-the-bots).
