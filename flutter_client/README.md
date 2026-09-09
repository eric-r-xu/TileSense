# TileSense — Flutter Riichi Mahjong efficiency trainer

## What it does

- A locally shuffled 136-tile wall, four dealt hands, and a full offline round
  loop vs three bots: draws, discards, **chi**, **pon** and **closed kan**,
  riichi, tsumo, ron, and exhaustive draw with tenpai payments. Chi is offered
  only to the seat after the discarder, and loses to pon/kan/ron; the guide
  picks which run to take when more than one is possible.
- A **live efficiency guide** (bottom-left panel): for every discard from your
  hand it shows the resulting shanten, ukeire, accepted tile types, and
  probability-weighted point value. Tenpai EV uses yaku/han/fu scoring, visible
  dora, dealer status, live wait counts, estimated ron/tsumo opportunities, and
  the riichi deposit; earlier shapes use projected completion probability and
  hand value. Honba (300 a stick to the winner) and the riichi deposits
  already on the table (1000 each) ride on the win, so they are added to the
  payout before it is weighted by win probability — never to the hand's own
  value, so they cannot change which shape is worth chasing. Best-efficiency,
  best-EV, and recommended discards are marked, together with a riichi/damaten
  plan.
- A **defensive panel** when an opponent declares riichi: each of your tiles is
  ranked 0–15 (genbutsu / suji / one-chance / honor-by-copies) with a short
  explanation, and the recommendation switches to the safest discard. Scores
  refer only to the named riichi opponent: genbutsu includes their own discards
  (even before riichi) and other players' discards they passed after riichi.
  Every discard is also priced: its deal-in chance (from that 0–15 rating)
  times what a riichi hand pays, plus the turns that choosing it commits you
  to — subtracted from its expected value and shown in a Risk column. Push and
  fold then fall out of the numbers, with no separate rule: the recommendation
  is always simply the best expected value.
- **Call advice** on every pon / kan / ron offer: each option is scored through
  the same expected-value model as the discard table (the state it leaves you
  in, once melds are counted), then filtered by three hard rules — a call must
  advance the hand, leave a yaku to finish on, and not commit you while a
  riichi is out and you are still behind. The panel shows the verdict and why.
- Hand scoring at the end of a round: yaku list, han/fu, dora/ura/aka, limit
  hands and yakuman, and the point transfers.
- A **Custom Hand & Context Builder**, reached from the start screen and
  isolated from the game: it poses a [`Round`](lib/logic/round.dart) by hand
  rather than playing one, then feeds the same `EfficiencyEngine` the live
  guide uses. You set your concealed tiles and calls, every seat's pond and
  melds, the dora indicators, wall count, round wind, your own seat wind (East
  makes you the dealer, worth half again on a win), honba/sticks, the play
  style, and each seat's riichi (and which discard declared it). The tile palette enforces four
  copies of anything across the whole table. Genbutsu on a posed table is
  derived from discard order — a seat's own pond, plus other seats' discards
  that fall later in turn order than the declaration.
- An **Autoplay** toggle that plays your seat from that same guide — the
  recommended discard, its riichi/damaten verdict, its call advice and its
  concealed-kan verdict. It never falls back to the opponents' heuristic; see
  [`BOT_STRATEGY.md`](BOT_STRATEGY.md).

### Rules coverage

`lib/logic/efficiency_calc.dart` implements the Riichi-Trainer shanten/ukeire
algorithm, and `efficiency_engine.dart` adds the scoring-aware expected-value
model (walked through in [`EXPECTED_VALUE.md`](EXPECTED_VALUE.md)).
`lib/logic/bot.dart` drives seats 1–3 only; your own seat is always played
by the guide. The bots never call chi, though the round offers it and the guide
advises on it. Scoring covers the common yaku, the standard fu table, and the
yakuman set; rare fu corner cases and some double-yakuman rules are
approximated. There is no networking, lobby, replay, or optional-rule
configuration.

## Project layout

```
lib/
  logic/      pure Dart, no Flutter imports, unit-tested
    tile.dart            TileType, Tile, Wind helpers
    wall.dart            136-tile wall, dead wall, dora reveal
    efficiency_calc.dart shanten + ukeire (38-slot Riichi-Trainer port)
    hand_parse.dart      agari / decomposition / waits / furiten
    scoring.dart         yaku + han/fu -> points
    safety.dart          defensive tile ranking vs a riichi opponent
    bot.dart             SimpleBot opponent heuristic
    round.dart           the offline round state machine
    efficiency_engine.dart scoring-aware discard EV + typed UI report
  game/
    game_controller.dart ChangeNotifier: round + bots + async turn loop
  ui/
    table_view.dart, hand_view.dart, efficiency_overlay.dart,
    scoring_view.dart, tile_face.dart
test/                     shanten / ukeire / EV / scoring / round / widget tests
```

## Run

Install the [Flutter SDK](https://docs.flutter.dev/get-started/install), then:

```sh
cd flutter_client
flutter pub get
flutter run -d chrome      # or an Android device, an iOS simulator…
```

The `android/`, `ios/`, and `web/` folders are generated by `flutter create`;
re-run `flutter create .` here if they are ever missing.

## Test / analyze

```sh
flutter analyze
flutter test
```

## Ship it

See [`DEPLOYMENT.md`](DEPLOYMENT.md) for web, Android, and iOS build and release
instructions.

## How the guide and bots decide

- [`EXPECTED_VALUE.md`](EXPECTED_VALUE.md) — how the guide turns a discard into
  the Expected Value number, the recommended tile, and Autoplay's moves.
- [`BOT_STRATEGY.md`](BOT_STRATEGY.md) — a plain-language comparison of the
  opponents' `SimpleBot` heuristic against that guide.
