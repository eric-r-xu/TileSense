# Sanma (三麻): three-player riichi

TileSense's sanma follows the [Japanese Mahjong Wiki's Sanma page](https://riichi.wiki/Sanma).
Every rule of four-player riichi applies (see [JAPANESE_RIICHI_RULES.md](JAPANESE_RIICHI_RULES.md)),
with these changes.

## The table

- **Three players**, seated East, South and West. The seat across from you is
  empty: the player after you sits on your right and the one before you on
  your left, as at a real three-player table.
- **108 tiles.** The 2–8 man are removed; 1m and 9m stay, so kokushi musou
  and chinroutou can still be made, and sanshoku doujun cannot.
- **One red five each in pin and sou.** There is no 5m.
- **35,000 points** each. A hanchan is East and South, three hands a wind
  (six or more); East only is three or more.
- **Dora:** a 1m indicator makes 9m the dora (and 9m makes 1m).
- **The dead wall** is 14 tiles and serves eight replacement draws, shared by
  kans and kita. Each replacement moves the last live tile across, so the live
  wall shortens by one.

## Play

- **No chi.** Pon and kan are called as usual.
- **Kita (pei nuki, 北抜き).** On your turn you may set a North aside instead
  of keeping it. It counts as one dora, and again for every dora (or, after a
  riichi win, ura dora) indicator that points to North. You then draw a
  replacement from the dead wall; a win on it is rinshan. Kita ends the first
  go-around (double riichi, kyuushu and the first-turn wins) and every
  ippatsu. An opponent may ron the North, which is not chankan. In riichi
  you may only set aside the North you have just drawn. A North kept in hand
  is an ordinary guest wind.
- **Tsumo loss.** A self-draw is paid by the two other players at the
  four-player rates, with nothing added for the missing seat, so it is worth
  less than the same hand by ron.
- **Exhaustive draw:** 2,000 moves between noten and tenpai players (1,000
  from each noten player, shared by the tenpai ones).
- **Abortive draws:** kyuushu kyuuhai only.

## In TileSense

- The guide treats the 2–8 man as out of play, counts kita as dora, and always
  sets a North aside. It plays Aggressive · Speed · Points throughout: the
  placement model is built for four seats.
- Mortal plays four-player riichi only, so a sanma table has no Mortal column
  and no Saeko-on-Mortal. There is no daily quiz for sanma yet: riichi's
  puzzles are four-player tables, so they are not offered in its place.
- Online rooms seat three; bots fill the seats nobody takes.
