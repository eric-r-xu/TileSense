# 🇨🇳 MCR rules

Chosen with the ruleset toggle (welcome screen, game app bar, online lobby,
or builder chip row); Riichi remains the default. Rules reference:
[MCR.pdf](https://app.ericrxu.com/static/MCR.pdf).

The source is the World Mahjong Organization's **Mahjong Competition Rules**
(MCR, 国标麻将), English edition. Section numbers below (§) refer to it. This
page is a summary of what the app implements, not a copy of the rules.
Tournament administration (draw lots, time limits, table points, referee
penalties — §3.5, §3.9.2, §3.10) is out of scope.

The code lives under `packages/mahjong_core/lib/mcr/`. Riichi, Hong Kong and
Taiwanese keep their own parsers, scorers, payments and dealer rules; every
shared code path that MCR touches is gated on `Ruleset.isMcr`.

## Tiles and play

- **144 tiles**: three suits, winds, dragons and eight flowers (§3.5.5). No
  red fives, no dead wall: kong and flower replacements come from the tail
  of the wall.
- **13-tile hands**; a complete hand is four sets and a pair, or one of the
  special shapes (§3.7.2): Seven Pairs (four identical tiles may count as
  two pairs), Thirteen Orphans, Lesser/Greater Honors and Knitted Tiles,
  and a Knitted Straight with one set and a pair.
- **Flowers are replaced automatically.** The rules let a player hold or
  discard a flower (§3.4.20, Appendix 1 fan 81); the app always exposes and
  replaces it. Flowers never win on their own.
- **Calls** (§3.6.6–3.6.8, §3.7.1): Hu beats Kong/Pung, which beat Chow.
  The last discard may only be claimed for Hu. A kong cannot be declared on
  the same turn as a chow or pung. Concealed kongs are laid face down and
  stay hidden from the other seats until the hand ends.
- **One winner** (§3.7.2.4): when several players declare Hu on a discard,
  the one nearest after the discarder wins.
- No riichi, furiten, deposits or honba.

## Scoring

- **81 fan** with their point values and exclusions (Appendix 1), in
  `mcr_fan.dart`. The scorer tries every decomposition of the hand and every
  place the winning tile could have gone, then picks the highest legal
  total under the five combination principles of §3.9.1.5 (non-repeat,
  non-separation, non-identical, high-versus-low, account-once).
- **8-point minimum** (§3.9.1.1), not counting flowers. A hand worth 7
  points plus any number of flowers cannot be declared. A hand that
  otherwise scores nothing is a Chicken Hand (8).
- **Flowers** add 1 point each after the minimum check.
- A win on a flower replacement after a kong scores Self-Drawn, not Out
  with Replacement Tile (Appendix 1, fan 46). One melded and one concealed
  kong score 6 together (fan 57).

## Payments (§3.9.1.3)

For a hand worth **F** points, flowers included:

| Win | Discarder | Each other player |
|---|---|---|
| Self-drawn | — | F + 8 |
| On a discard | F + 8 | 8 |

A draw transfers nothing. Scores start at 0 and may go negative.

## Game length

The dealer passes to the right after **every** hand, win or draw (§3.4.8).
A full game is four rounds — East, South, West, North — of four hands each:
**16 hands** (§3.4.3–3.4.5). The shorter setting is a 4-hand East-round
practice game.

## Guide and bots

Ready hands are judged with the real scorer, so a wait that cannot reach 8
points is shown as unwinnable. Before ready, the guide's value estimate and
the bots' pattern potential are heuristics, labelled as such. Mortal stays
riichi-only.

## Online play

Clients send the rulesets they support when creating, joining or
reconnecting to a room. An older client that does not list `mcr` can still
play the other rulesets but gets an "update required" error for MCR rooms.
