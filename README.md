# <img width="35" height="35" alt="tileSense" src="https://github.com/user-attachments/assets/5b178736-39e4-489d-9bc5-3ffa7f927057" /> TileSense

<img width="215" height="215" alt="TileSensor" src="flutter_client/assets/tilesensor.png" />

---

**[Play in your browser](https://app.ericrxu.com/tilesense/)**

TileSense is a mahjong game and trainer for 🇯🇵 Japanese riichi, 🇭🇰 Hong Kong and
🇹🇼 Taiwanese rules. Play against bots or friends, or pose any hand yourself. In
single player, a live guide grades every decision as you make it: how fast each
discard gets you ready, what it is worth, and what it risks.

This repo holds the cross-platform **Flutter** app (`flutter_client/`) for web,
Android and iOS, its shared pure-Dart core (`packages/mahjong_core/`), the
multiplayer server (`server/mp/`) and the telemetry ingest (`server/`).

---

## Features

### Play

- **Single player** against three bots: a full game with draws, discards,
  **chi**, **pon** and **kan**, riichi, tsumo, ron and exhaustive draws with
  tenpai payments. A hanchan (East and South) by default, or East only.
  Seat **Saeko** and, under riichi, she plays Mortal's moves (see below);
  every other bot plays the same simple rulebook.
- **Play Online**: a private room for up to four people, with bots filling any
  empty seat. There is no guide or Auto-Play online, by design: nobody gets help
  the others don't.
- **Hand-bar toggles** beside your tiles: **Sort** your hand, **Auto-Win** (declare
  ron and tsumo the moment they are legal) and **Auto-Pass** (pass chi, pon and kan
  calls; a ron is never passed). On a phone they shrink to icons so the whole hand
  fits.
- **Undo** a move in single player to try a different line, and a **Bot Speed**
  switch for normal or double pace.
- **End-of-round scoring**: yaku, han/fu, dora/ura/aka, limit hands and yakuman,
  and the point transfers. The score screen continues on its own after 20 seconds;
  **Pause** holds it.

Scoring covers the common yaku, the standard fu table and the full yakuman set;
rare fu edge cases and some double-yakuman rules are approximated. No replays yet.

### The guide

For every tile in your hand, the guide panel shows the resulting shanten, ukeire
(how many tiles would improve the hand), and expected value (EV), and highlights
the recommended discard or call.

- **Before tenpai**, EV combines the chance of completing the hand with an estimate
  of its value, allowing for dealer and open hands.
- **At tenpai**, EV scores every live wait by its remaining copies and chance of
  winning, and the guide suggests riichi or damaten.
- **Table money counts**: honba, and under riichi the riichi deposits, pay out on
  any win, so they are added in.
- **Defense is priced, not ruled.** Against a riichi, each discard is charged its
  chance of dealing in (from its safety rating) times what that hand pays, plus
  the turns it commits you to. The **Risk** column shows that charge. Folding wins
  when the numbers say the hand isn't worth pushing, with no separate "fold" rule.
- **EV (HMR)** is a standalone comparison column: the "E.V." stat from
  [Hitori Mahjong Renshuuki (HMR)](https://pathofhouou.blogspot.com/2019/05/training-tool-hitori-mahjong-simulator.html),
  win chance times average score, reproduced from HMR's own simulation log to check
  the guide's numbers against. It never drives the recommendation. HMR is a
  separate solo trainer with no code or data shared with this project.
- **Auto-Play** plays your seat with the guide's recommendations, or Mortal's
  under riichi when you choose it (see below).
- **The guide sets its own dials as the game goes**: under riichi it plays for
  points early and for placement in the final two hands, with no goal to pick
  (`flutter_client/lib/logic/auto_dials.dart`). The guide panel's **PLAYING**
  row shows the three dials in use:
  - **Play Style** (defensive, balanced or aggressive): how dearly danger is
    priced, and how readily a ready hand stays quiet rather than declaring riichi.
  - **Focus** (Speed or Balanced): how much finishing fast counts against payout.
  - **Strategy** (Points or Placement): Placement weighs each line by how it moves
    your chance of finishing above each other seat, using a heuristic model. See
    [`EXPECTED_VALUE.md`](flutter_client/EXPECTED_VALUE.md#strategy--points-or-placement-riichi-only).

  | Rules | Hands | Style | Focus | Strategy |
  |---|---|---|---|---|
  | Riichi | all but the last two | Aggressive | Speed | Points |
  | Riichi | the last two | Balanced | Speed | Placement |
  | Hong Kong | all | Balanced | Speed | Points |
  | Taiwanese | all | Balanced | Speed (Balanced at the 5-tai minimum) | Points |

  In 2,400 paired games per length against the bots, this placed the same as the
  fixed Balanced / Speed / Points it replaced (East +0.008 ± 0.020, hanchan
  +0.007 ± 0.023 of a place; no difference in points either).

How the guide measures up against the bots, and how the bots play, is in
[`BOT_STRATEGY.md`](flutter_client/BOT_STRATEGY.md).

### Mortal (optional)

In single-player riichi, the **Saeko** bot plays
[Mortal](https://github.com/Equim-chan/Mortal)'s moves, seeing only what her
seat can see; if Mortal can't answer a decision, she plays it like the other
bots.

The guide also adds a **Mortal bot** column: what Mortal, an open-source
deep-learning mahjong AI, would do in your seat, seeing only what your seat can
see. Its pick is outlined in red and the guide's filled green; where they pick
the same tile or move, it is filled green with a red outline.

**Auto-Play can follow either one** (the FOLLOWS dial in the top bar, the
AUTO-PLAY chips in the guide panel, or the phone menu):

- **TileSense** (the default): the guide plays your seat, and its
  recommendation tops the list. The Mortal column is a second opinion.
- **Mortal bot**: Mortal plays your seat, and the list follows its order of
  preference. Any decision Mortal can't answer (the sidecar is down or slow, or
  it names a move the table doesn't offer) is played by the guide instead.

All of it is off unless the app is built with `--dart-define=MORTAL_URL=<address>`. Mortal
runs on ONNX Runtime in a small sidecar (`mortal_sidecar/server.py`, setup steps in
its header).

### Daily quiz: "What would TileSensor do?"

Five new puzzles each day, from the start page (the card under the rules choice, or
**Daily quiz** beside Practice). Each poses a table and asks what you would do, in
multiple choice, then moves on with **Next question**; a results page gives the
score, and the day-streak extends once the fifth is answered. The five are
different puzzles, and the pool is worked through in turn before any repeats.

- **A cut**, or what to do with an opponent's discard (chi, pon, kan or pass).
- **Kan (kong in Hong Kong) whenever it could be declared**: holding all four of a
  tile adds it to a cut puzzle's choices, and three held with the fourth offered
  makes a call puzzle kan, pon or pass.
- **When the cut leaves you ready, a second question**: riichi, or stay quiet
  (dama)? Both parts must be right.
- Every puzzle is one **TileSense and Mortal agree on**, with a clear lead over
  the next-best move.
- **Why**, once you answer: the situation (how late in the hand and the game, your
  placement, the dealer, any riichi against you), TileSense's shanten, ukeire, EV
  and risk for the best move and for yours, and where Mortal ranks your pick.
  Mortal does not explain itself, so its part is a ranking, not reasoning. The
  guide's own sentence is shown in English only.
- Some tables have uneven scores. In the last two hands the guide then plays for
  placement, as in a game; the Custom Hand & Context Builder still has no scores.
- A day streak, kept on the device. Only a day's first answer counts.

Everything but the puzzles themselves is live: the app works TileSense's answer out
again from the table and fails a test if it ever stops matching the stored one, so
retuning the guide shows up as a stale puzzle rather than a wrong answer. Mortal's
side is stored with each puzzle, so the quiz needs no sidecar to play. The pool is
`flutter_client/assets/quiz/daily.json`; five puzzles a day, the same for everyone
on the same date, round the pool.

To grow it, start the Mortal sidecar and run, from `flutter_client/`:

```sh
QUIZ_MORTAL_URL=http://127.0.0.1:8790 QUIZ_COUNT=100 QUIZ_SEED=3 \
    flutter test tools/build_quiz.dart
```

New puzzles are appended after the existing ones; use a seed not used before. Each
run first re-checks the puzzles already in the file and drops any that no longer
stand (the guide's answer changed, a possible kan is not offered, or a Hong Kong
answer depends on play style). The tables are random: a finished hand
with a few tiles swapped, ponds, a dora, sometimes a riichi against you and
sometimes uneven scores. Only the tables both engines answer the same way are kept.

The quiz has riichi and Hong Kong puzzles, and today's is drawn from the pool for the
rules chosen on the welcome screen (Taiwanese, MCR and Sichuan take riichi's until they
have pools). Sanma has no quiz: riichi's puzzles are four-player tables, so the Learn tile
says there is none rather than posing them. Mortal does not play Hong Kong, so those puzzles need no sidecar: they
keep a table when TileSense's best line leads the next clearly **and** the guide gives
the same answer playing aggressively, defensively and by default. To grow that pool:

```sh
QUIZ_RULESET=hongKong QUIZ_COUNT=60 QUIZ_SEED=2 flutter test tools/build_quiz.dart
```

Answers are sent as a `quiz_answered` telemetry event.

### Custom Hand & Context Builder

From the start page, pose any table by hand and the same guide scores it:

- your tiles
- every seat's discards and calls
- the dora indicators, and who is in riichi (riichi only)
- the wall count, and your seat wind (East deals)
- for Sichuan, each seat's void suit and which opponents have already gone out
  (it has no dora, flowers, riichi or chi)
- for sanma, each seat's kita (Norths set aside); the seat across stays empty and
  the palette has no 2–8 man.

It plays the dials a game's guide would at that point, reading the hand off the
round and seat wind as a hanchan in which you dealt first; with no scores to
weigh, Strategy stays Points.

---

## Rulesets

Choose the rules on the welcome screen, or switch at any time from the game's app
bar (which deals a new game) or the builder's chip row. Riichi is the default.

| Rules | Tiles | Minimum to win | Rules page | One-page PDF |
|---|---|---|---|---|
| 🇯🇵 Riichi | 136, 13-tile hands | one yaku | [Riichi rules](docs/JAPANESE_RIICHI_RULES.md) | [Riichi.pdf](https://app.ericrxu.com/static/Riichi.pdf) |
| 🇭🇰 Hong Kong | 144 with flowers | **0 faan** by default; 1, 2 or 3 | [Hong Kong rules](docs/HONG_KONG_RULES.md) | [HK.pdf](https://app.ericrxu.com/static/HK.pdf) |
| 🇹🇼 Taiwanese | 144 with flowers, 16-tile hands (5 melds and a pair) | **5 tai** by default; 1 or 3 | [Taiwanese rules](docs/TAIWANESE_RULES.md) | [Taiwanese.pdf](https://app.ericrxu.com/static/Taiwanese.pdf) |
| 🇨🇳 MCR | 144 with flowers, 13-tile hands | **8 points**, flowers excluded | [MCR rules](docs/MCR_RULES.md) | [MCR.pdf](https://app.ericrxu.com/static/MCR.pdf) |
| <img src="flutter_client/assets/flags/sanma.png" height="14" alt="Sanma"> Sanma (3-player) | 108, no 2–8 man, 13-tile hands | one yaku; no chi, kita, tsumo loss | [Sanma rules](docs/SANMA_RULES.md) | [riichi.wiki/Sanma](https://riichi.wiki/Sanma) (web) |
| <img src="flutter_client/assets/flags/sichuan.png" height="14" alt="Sichuan"> Sichuan | 108, no honors or flowers, 13-tile hands | none; void suit, no chows, play on after a win | [Sichuan rules](docs/SICHUAN_RULES.md) | [Sichuan.pdf](https://app.ericrxu.com/static/Sichuan.pdf) |

Taiwanese scores flat, additive points and adds a dealer win-streak bonus.

Sanma (三麻) is riichi for three players: the seat across is empty, the 2–8 man are
removed, there is no chi, Norths can be set aside as kita for dora, and a self-draw
is paid by the two others only. Its flag is Japan's with 三麻 on it, and its tooltips
say it is three-player. It plays offline, in the builder and online, where rooms seat
three and bots fill the rest. Mortal plays four-player riichi only, so it sits sanma out.

Sichuan is bloody-battle mahjong: each seat gives up a suit, and a win takes that seat out while the others play on. It can be played online too: the server runs the table, and a seat's void suit stays hidden from the others until its first discard.

All three share one engine: `packages/mahjong_core/lib/ruleset.dart` defines
`Ruleset.riichi`, `Ruleset.hongKong` and `Ruleset.taiwanese`, and the round, guide,
bots, builder and UI branch on it only where the games differ. Hong Kong and
Taiwanese logic lives in `packages/mahjong_core/lib/hong_kong/` and
`packages/mahjong_core/lib/taiwanese/`.

---

## Getting started

Install the [Flutter SDK](https://docs.flutter.dev/get-started/install), then once:

```sh
cd flutter_client
flutter pub get
flutter doctor        # install or fix whatever it flags for the platforms you want
```

| Platform | Command | Needs |
|---|---|---|
| Web | `flutter run -d chrome` | Chrome (or `flutter run -d web-server --web-port 8080` for any browser) |
| Android | `flutter run -d android` | The Android SDK (via Android Studio) and an emulator or a USB-debugging device |
| iOS | `flutter run -d ios` | macOS, Xcode, and a booted Simulator or a plugged-in iPhone |

`flutter run` starts in debug with hot reload: `r` reloads, `R` restarts, `q`
quits. Add `--release` for a performance build; `flutter devices` lists every
target attached.

- **Android emulators**: `flutter emulators` lists them, and
  `flutter emulators --launch <id>` boots one.
- **iOS on a real device**: open `ios/Runner.xcworkspace` once and set a Signing
  Team under *Signing & Capabilities*. `open -a Simulator` boots the Simulator.
- The `web/`, `android/` and `ios/` folders are committed; if one goes missing,
  regenerate it with `flutter create .` in `flutter_client/`.

---

## Testing

```sh
cd flutter_client && flutter analyze && flutter test
cd packages/mahjong_core && dart analyze && dart test     # likewise server/ and server/mp/
python3 -B -m unittest discover -s server/deploy -p 'test_*.py'
```

CI (`.github/workflows/ci.yml`) runs all of these, plus a release build, on every
pull request. A pull request into `ericrxu_dev` can only be merged once they pass.

---

## Project layout

```
packages/mahjong_core/lib/   pure-Dart core shared by the app and the multiplayer
                             server: tile model, wall, shanten and ukeire, hand
                             parsing, scoring, safety model, SimpleBot, the round
                             state machine, mjai events for Mortal

flutter_client/lib/
  logic/      efficiency_engine.dart (the guide's discard EV),
              daily_quiz.dart (the daily quiz's model),
              placement_utility.dart (Strategy: Placement),
              auto_dials.dart (the dials for each point in the game)
  game/       game_controller.dart (single player), online_game_controller.dart,
              mortal_advisor.dart
  net/        multiplayer client (WebSocket)
  scenario/   the Custom Hand & Context Builder's state
  tools/      build_quiz.dart (the daily quiz's puzzle generator)
  telemetry/  gameplay telemetry client
  ui/         table, hand, guide panel, scoring screen, tile widget

server/mp/lib/       the multiplayer server (table_loop.dart)
server/bin/          the telemetry ingest (server.dart)
server/deploy/       deploy.py and remote.py, driven by ./deploy.sh
mortal_sidecar/      the optional Mortal service
docs/                rules pages
reports/             bot-simulation runs and the stats report
.github/workflows/   CI and automatic deploys
```

### Languages

The app, its core, the multiplayer server and the telemetry ingest are one **Dart**
codebase. Everything else is Flutter-generated platform glue, or tooling that is
not part of the running app:

| Language | Where | Purpose |
|---|---|---|
| Dart | `flutter_client/lib/`, `packages/mahjong_core/lib/`, `server/mp/lib/`, `server/bin/` | The app, its shared core, the multiplayer server and the telemetry ingest |
| Kotlin | `android/app/.../MainActivity.kt` | Thin Android host shim, generated by `flutter create` |
| Swift | `ios/Runner/` | Thin iOS host shim, generated by `flutter create` |
| Java | `android/.../GeneratedPluginRegistrant.java` | Auto-generated Android plugin registration |
| HTML | `web/index.html` | Static shell the Flutter web build mounts into |
| Python | `flutter_client/tools/`, `reports/sim_report.py`, `server/deploy/`, `mortal_sidecar/` | Offline tooling (tile art, font fingerprinting, web precompression, the HK win-model fit, the sim report), the deploy scripts, and the Mortal sidecar. The voice-clip generators are kept local. |
| Shell | `deploy.sh`, `clean.sh`, `reports/*.sh` | Deploy, cleanup and sim-run scripts |
| SQL | `server/migrations/`, `reports/sim_schema.sql` | Telemetry and sim-results database schemas |

---

## Deployment

### Web (production)

Production is deployed with `./deploy.sh`, and the web app deploys automatically
once CI passes on a push to `ericrxu_dev` (`.github/workflows/deploy.yml`).
Releases are versioned, health-checked and rolled back on failure. The full
runbook, including setup, manual targets and rollbacks, is
[`DEPLOYMENT_GUIDE.md`](DEPLOYMENT_GUIDE.md).

To build the web app yourself:

```sh
cd flutter_client
flutter build web --release        # -> build/web/  (static bundle)
```

Signing, store submission and other platform detail is in
[`flutter_client/DEPLOYMENT.md`](flutter_client/DEPLOYMENT.md).

### Android

```sh
flutter build appbundle --release            # -> build/app/outputs/bundle/release/app-release.aab  (Play Store)
flutter build apk --release --split-per-abi  # -> per-ABI APKs for sideloading
```

**Not set up yet.** A release build needs a keystore referenced from
`android/key.properties` and a `signingConfigs.release` block in
`android/app/build.gradle.kts`; neither exists, and the release build type still
uses the debug signing config. The app requests no permissions and collects no
data.

### iOS

Requires macOS and Xcode.

```sh
open ios/Runner.xcworkspace     # set Team and Bundle Identifier under Signing & Capabilities
flutter build ipa --release     # -> build/ios/ipa/*.ipa  (or archive via Xcode Organizer)
```

Upload to App Store Connect (Xcode Organizer → Distribute App, or Transporter);
the build appears in TestFlight after processing.

### Version and build number

Both come from one line in `flutter_client/pubspec.yaml`:

```yaml
version: 0.2.1+4     # 0.2.1 = version name, 4 = build number; bump +N on every store upload
```

---

## Credits

- **[Riichi-Trainer](https://github.com/Euophrys/Riichi-Trainer)** by Euophrys,
  for the shanten, ukeire and defense calculations.
- **[OpenRiichi](https://github.com/FluffyStuff/OpenRiichi)** by FluffyStuff, an
  open-source, cross-platform riichi mahjong client (GPLv3). TileSense began as a
  fork of it, and its riichi core was ported from OpenRiichi's Vala source: the
  round engine, tile model, wall, hand parsing, yaku/han/fu scoring, and the
  `SimpleBot` opponent logic.
- **[Training tool: Hitori Mahjong Simulator](https://pathofhouou.blogspot.com/2019/05/training-tool-hitori-mahjong-simulator.html)**
  on Path of Houou, for the EV comparisons (the guide's **EV (HMR)** column).
- **[Mortal](https://github.com/Equim-chan/Mortal)** by Equim-chan (AGPL-3.0), for
  the optional Mortal decision column, with the
  [mortal-298k](https://huggingface.co/VoidShine/mortal-298k) weights (AGPL-3.0).

### Playtesting and feedback

Thank you to the friends and players whose testing, suggestions and bug reports
helped improve TileSense.

- **Jesse C**: for identifying riichi exhaustive draws that wrongly advanced the
  dealer while the dealer was tenpai, and for introducing me to two valuable
  resources: [Hitori Mahjong Renshuuki (HMR)](https://pathofhouou.blogspot.com/2019/05/training-tool-hitori-mahjong-simulator.html),
  used to validate the baseline EV calculations, and
  [Euophrys's Mahjong Efficiency Trainer](https://euophrys.itch.io/mahjong-efficiency-trainer),
  which underpins TileSense's shanten and ukeire calculations.
- **Raymond M**: for identifying missed pinfu yaku scoring, illegal closed kans after
  declaring riichi, and lack of chi choices when more than 1 sequence was available; for requesting Auto-Pass functionality for no calls and for score screen UX layout enhancements.
- **Sherman L**: for suggesting a single-player rewind feature to revisit a
  decision, try a different action and explore the outcome.
- **Melissa R**: for suggesting larger buttons and more space between controls,
  especially on mobile.
- **Helen W**: for testing multiplayer from China and spotting slow home-screen
  loading, which prompted audio caching that cut startup time.
- **Vilay K**: for suggesting a slower pace of play, which directly inspired the pauses between calls and the adjustable bot speed. Vilay K's feedback, together with Robert K's, also shaped the `Learn to Play` module and the decision to start new players on the Hong Kong 0-point minimum.
- **Mark G**: for recommending [Flutter](https://flutter.dev/), Google’s amazing open-source framework for building apps, enabling more consistent UI across devices and operating systems while at the same time reducing duplicate code and enhancing maintainability.
- **Robert K**: for sharing a newcomer's perspective on mahjong, which led to the `Learn to Play` module for onboarding new players.

Thank you to everyone else who shared feedback. If I've missed you and you'd like
to be credited, please get in touch.

---

## License

TileSense is licensed under GPLv3. Its efficiency calculations are adapted from the
Riichi-Trainer algorithm, and its riichi core (round engine, tile model, wall, hand
parsing, scoring and `SimpleBot`) from OpenRiichi (also GPLv3). See
[`LICENSE`](LICENSE). Contributions welcome.

The optional Mortal sidecar runs [Mortal](https://github.com/Equim-chan/Mortal) and
its weights, both AGPL-3.0; anyone offering it to others over a network must offer
them Mortal's source.

The telemetry ingest's location lookup uses DB-IP's free "IP to City Lite"
database, licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/):
[IP Geolocation by DB-IP](https://db-ip.com). Credit it the same way on any chart or
report built from `sessions.geo_country`, `geo_region` or `geo_city`.
