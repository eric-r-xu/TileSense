# <img src="../flutter_client/assets/flags/sichuan.png" height="22" alt="Sichuan"> Sichuan rules

Chosen on the welcome and character screens; the welcome screen starts on
Hong Kong. It is also offered in the online lobby (see
[Online](#online)). Rules reference:
[Sichuan.pdf](https://app.ericrxu.com/static/Sichuan.pdf).

The source is the **Sichuan Bloody Rules (SBR)** quick reference on
[mahjongpictureguide.com](https://www.mahjongpictureguide.com/sbr/) ("Simple
Basic Rules" Sichuan, 血战到底). This page is a summary of what the app
implements, plus the places that sheet is silent and what the app does there.
It is not a copy of the rules; the sheet itself is the PDF above, hosted with
its author's permission.

The code lives under `packages/mahjong_core/lib/sichuan/`. The other rulesets
keep their own parsers, scorers and payments; every shared path Sichuan
touches is gated on `Ruleset.isSichuan`. Its flag is an image, not an emoji
(`Ruleset.flagAsset`, shown by `RulesetFlag`), because Sichuan is a province.

## Tiles and play

- **108 tiles**: characters, dots and bamboo, four of each. No honors, no
  flowers, no red fives, no dead wall. Kong replacements come from the tail.
- **13-tile hands**; a complete hand is four sets and a pair, or seven pairs
  (four identical tiles may stand as two of them).
- **Void suit.** Before the dealer's first draw every seat names one suit to
  give up. You must discard every tile of it before any other tile, and a
  hand holding any of it (melds included) cannot win. Your choice is hidden
  until your first discard shows it. Because the app enforces the order, the
  sheet's 48-point penalty (still holding the suit having discarded
  something else) is in the code and tested, but cannot arise in normal play.
- **No chow calls.** Chows are fine inside your own hand; no discard can be
  claimed for one. Pung and kong are claimed as usual.
- **Bloody battle.** A seat that declares Hu stops playing; the others carry
  on. The hand ends when three seats have won or the wall runs out. Several
  seats may Hu on the same discard; all are paid by the discarder.
- **Skipping a Hu.** If you pass a discard you could Hu, you may not Hu that
  tile from anyone else until after your own turn, nor any other discard
  unless it is worth more.
- No riichi, furiten or honba. The last discard may only be claimed for Hu.

## Scoring

Add up the fan, then turn the total into the hand value:

| Fan | 0 | 1 | 2 | 3 or more |
|---|---|---|---|---|
| Hand value | 1 | 2 | 4 | 8 |

| Pattern | Fan |
|---|---|
| Root: four identical tiles in the hand, kong or not (each set counts) | 1 |
| All Pungs | 1 |
| Full Flush: one suit only | 2 |
| Seven Pairs | 2 |
| Golden Single Wait: four melds out, the win completes the pair (includes All Pungs) | 2 |
| Win after Kong | 1 |
| Robbing the Kong | 1 |
| Shoot after Kong: Hu on the discard after a kong | 1 |
| Under the Sea: the last wall tile, or the discard after it | 1 |

There is no minimum to win.

- **Hu on a discard**: the discarder pays the hand value to each winner.
- **Self-draw**: every seat still playing pays hand value + 1.
- **Kongs** (settled at the end): a concealed kong is worth 2 from each seat
  still playing; a kong claimed off a discard 2 from the discarder; an added
  kong 1 from each, and only if the added tile is the one just drawn. A
  kong's payment is cancelled if it is robbed, or if someone Hu's on the
  discard right after it. A seat that finishes still playing and not ready
  collects no kong payments.
- **When the wall ends** with two or more seats still playing, each seat that
  is not ready pays each ready one the hand value of the best hand it is
  ready for. Ready means one tile from a legal win: it counts even if every
  copy of the wait is visible on the table, but not if all four are in your
  own hand.
- Everyone starts a game on 0 points.

## Dealing and game length

If nobody wins, the dealer stays. If the first Hu is by one seat, that seat
deals next; if it is by several on one discard, the discarder does. A game is
4 hands (practice) or 8 (full); there is no round wind, so hands are simply
numbered.

## Where the sheet is silent

| Question | What the app does |
|---|---|
| Who receives the 48-point penalty? | Each other seat, 48 apiece. |
| Does Root count once per set of four? | Yes, and inside seven pairs too. |
| Whose turn follows a Hu on a discard? | The next seat still playing after the discarder (after the kong declarer, for a robbed kong). |
| How is "worth more" compared when skipping? | By hand value in points (1, 2, 4, 8). |
| Are situational fan counted in a ready hand's value? | No. |
| May you pung or kong your void suit? | Yes, but the hand then can never win; the bots never do. |
| Dice, wall-breaking, face-down first discard | Not modelled; the suit is simply hidden until the first discard. |

## Online

The server runs the table. Every seat names its void suit at the start, all at
once, under the turn clock; a seat that runs out of time gets the suit a bot
would pick, and counts a strike like a missed discard. Other seats are told only
*that* you have chosen: your suit stays hidden until your first discard shows
it, and your hand never leaves the server. A seat that has gone out is skipped
by the turn, the call windows and the clocks. A client from before Sichuan is
asked to update rather than being dealt a table it cannot draw, and there is
no guide or Auto-Play online, as in every ruleset.

## The guide

The guide ranks discards, pungs and kongs by expected points (the full method is
in [`EXPECTED_VALUE.md`](../flutter_client/EXPECTED_VALUE.md#under-sichuan-rules)):
how likely the hand is to get home before the wall ends, what that Hu pays, what an
unwon hand settles for at the wall, less what the discard risks against the
seats that are ready. Your void suit counts as dead weight and goes first, and
the suit prompt's star goes to the suit whose loss leaves the rest nearest to
ready. It reads only what the table shows: a rival's void suit once it has made
its first discard, and what each seat has thrown.

It plays level with the bots, not better, and the win chance it quotes is only
meant for a hand that is ready or one step from it; see
[`BOT_STRATEGY.md`](../flutter_client/BOT_STRATEGY.md#sichuan--the-guide-ties-the-bots).
It does not play online, as in every ruleset.
