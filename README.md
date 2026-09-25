# <img width="35" height="35" alt="tileSense" src="https://github.com/user-attachments/assets/5b178736-39e4-489d-9bc5-3ffa7f927057" /> TileSense 


<img width="215" height="215" alt="TileSensor" src="flutter_client/assets/tilesensor.png" />

--- 

[Play the live web app](https://app.ericrxu.com/tilesense/)

A mahjong **tile-efficiency trainer** for **Japanese riichi** and **Hong Kong**
rules. Play single player against bots with a live guide grading every discard —
shanten, ukeire (tile acceptance), probability-weighted point value, and the
recommended tile — and ranking your hand by safety once an opponent threatens.
Play online with friends too, bots filling any empty seat — multiplayer has no
guide, so nobody gets an assist the others lack.

Pick 🇯🇵 Riichi, 🇭🇰 Hong Kong or 🇹🇼 Taiwanese on the welcome screen, or switch
at any time from the game's app bar (which deals a new game) or the builder's
chip row. Riichi is the default. Hong Kong follows *HKMJ Cheat Sheet 1.0* with a
**0-faan minimum** by default, or 1, 2 or 3 faan; see [Hong Kong rules](docs/HONG_KONG_RULES.md). Taiwanese is
16-tile mahjong (5 melds and a pair) with flat, additive points and a
**5-point (tai) minimum** by default, or 1 or 3; see [Taiwanese rules](docs/TAIWANESE_RULES.md). One-page
references: [Riichi.pdf](https://app.ericrxu.com/static/Riichi.pdf),
[HK.pdf](https://app.ericrxu.com/static/HK.pdf),
[Taiwanese.pdf](https://app.ericrxu.com/static/Taiwanese.pdf).

This repo contains the cross-platform **Flutter** app (`flutter_client/`) for
web, Android, and iOS, its shared pure-Dart core (`packages/mahjong_core/`),
and the multiplayer game server (`server/mp/`) it plays online against.

The shanten/ukeire math follows the Riichi-Trainer algorithm; the rules, bots,
and 2D layout are maintained as part of TileSense.

---

## Quick start

Install the
[Flutter SDK](https://docs.flutter.dev/get-started/install) (≥ 3.3, tested on
3.47), then from `flutter_client/` run `flutter pub get` once and:

| Platform | Command | Prerequisites |
|---|---|---|
| Web | `flutter run -d chrome` | Chrome (or `-d web-server` for any browser) |
| Android | `flutter run -d android` | Android SDK + a running emulator or a USB device |
| iOS | `flutter run -d ios` | macOS + Xcode + a booted Simulator or a plugged-in iPhone |

Details, emulator/simulator launch, and release/store builds are in
[The Flutter app](#the-flutter-app-flutter_client) below.

---

## Three rulesets, one engine

`packages/mahjong_core/lib/ruleset.dart` defines `Ruleset.riichi`,
`Ruleset.hongKong` and `Ruleset.taiwanese`. The round, guide, bots, scenario builder and UI are shared
— offline and online alike — and branch on the ruleset only where the games
differ. Hong Kong-only logic lives in `packages/mahjong_core/lib/hong_kong/`:

| File | What it holds |
|---|---|
| `hong_kong_rules.dart` | Minimum-faan choices, the payment table, starting chips, Seven Pairs switch |
| `hong_kong_scoring.dart` | Faan patterns and payments (`scoreHongKongHand`, `scoreFlowerWin`) |
| `hong_kong_wall.dart` | The 144-tile wall with flowers and tail replacements |
| `hong_kong_safety.dart` | Risk estimates with no discard immunity |

Taiwanese-only logic sits alongside it in
`packages/mahjong_core/lib/taiwanese/`:

| File | What it holds |
|---|---|
| `taiwanese_rules.dart` | Minimum-points choices, the dealer win-streak bonus, starting points |
| `taiwanese_scoring.dart` | Point patterns and payments (`scoreTaiwaneseHand`) |
| `taiwanese_wall.dart` | The 144-tile wall, dealt 16 to a seat |
| `taiwanese_hand_parse.dart` | Five-set hand parsing (`totalMelds` 5) |

Everything else — shanten and acceptance, win-probability modelling, call
mechanics, the table and hand widgets — is the same code for both. Riichi tests
live in `flutter_client/test/`, Hong Kong tests in
`flutter_client/test/hong_kong/`, Taiwanese coverage in
`flutter_client/test/taiwanese_tuning_sweep_test.dart` and the shared
ruleset tests in `packages/mahjong_core/test/`;
`flutter_client/test/ruleset_toggle_test.dart` covers the switch itself.

---

## The Flutter app (`flutter_client/`)

### What it does

- A shuffled wall — 136 tiles under riichi, 144 with flowers under Hong Kong
  and Taiwanese — and a full offline round vs three bots: draws,
  discards, **chi**, **pon** and **closed kan**, riichi, tsumo, ron, and
  exhaustive draw with tenpai payments.
- A **live efficiency guide**: for every tile in your hand — resulting shanten,
  ukeire count, accepted tiles, and expected value. In tenpai, EV scores every
  live wait (including yaku, han/fu, visible dora, tsumo/ron, and dealer value)
  and weights it by remaining copies and estimated win probability. Before
  tenpai, it uses completion probability and a dealer/open-hand value estimate.
  Best-efficiency, best-EV, and recommended discards are highlighted, with a
  riichi/damaten plan at tenpai. Honba and the riichi deposits already on the
  table are counted too: they pay out on any win, so they scale with the
  chance of winning rather than with what the hand is worth. Against a live
  riichi each discard is also charged what it can cost you: its chance of
  dealing in, from its own safety rating, times what that hand pays, plus the
  turns that choosing it commits you to. Folding therefore wins on the numbers
  when the hand is not worth pushing, rather than by a separate rule. The panel
  shows the charge as a Risk column beside the value it came off. A second,
  standalone **EV (HMR)** column shows the same win-probability-times-average-
  score product with none of that pricing folded in — the "E.V." stat from
  HMR (Hitori Mahjong Renshuuki), a closed-source solo trainer with no code or
  data ties to this project, worked out from its own simulation log purely
  for comparison; it never drives the recommendation. See also:
  [Training tool: Hitori Mahjong Simulator](https://pathofhouou.blogspot.com/2019/05/training-tool-hitori-mahjong-simulator.html).
- A **defensive panel** when an opponent is in riichi: each tile rated 0–15
  (genbutsu / suji / one-chance / honor-by-copies) with a short reason; the
  recommendation switches to the safest discard. Scores refer only to the
  named riichi opponent: genbutsu includes their own discards (even before
  riichi) and other players' discards they passed after declaring riichi.
- End-of-round scoring: yaku list, han/fu, dora/ura/aka, limit hands and
  yakuman, and the point transfers.
- An **Autoplay** toggle that plays your seat with the recommended discard.
- A **play style** — defensive, balanced or aggressive — that changes how
  dearly the guide prices danger and how readily it keeps a hand quiet rather
  than declaring riichi, and a **focus** — Speed or Balanced — that tilts
  chance of finishing against payout. Neither changes what a hand is worth, and
  both steer Autoplay through the same scores. Both start on
  **Aggressive / Speed** under riichi, chosen from the sweeps below. Hong Kong
  has no riichi or damaten for play style to weigh, and a sweep found no
  placement effect from it either, so that dial is hidden and pinned to
  Balanced under **both** Hong Kong and Taiwanese — only focus (**Speed**) is
  exposed there.
- A third dial, **strategy** — Points or Placement, riichi only, starting on
  Points — that changes what "worth" means rather than how danger is priced:
  Placement runs every points-flavoured number through a heuristic model of
  how it moves the chance of finishing above each other seat, given the
  scores on the table right now, and can take a damaten a hand would riichi
  for the points, or the reverse. Opt-in and not yet swept against the bots
  the way style and focus's defaults were; hidden and pinned to Points under
  Hong Kong and Taiwanese alike, same as style. Details:
  [`EXPECTED_VALUE.md`](flutter_client/EXPECTED_VALUE.md#strategy--points-or-placement-riichi-only).
- **🇯🇵 Riichi, 🇭🇰 Hong Kong and 🇹🇼 Taiwanese rules**, chosen on the welcome
  screen or from the app bar, each with a one-page rules PDF
  ([Riichi](https://app.ericrxu.com/static/Riichi.pdf),
  [Hong Kong](https://app.ericrxu.com/static/HK.pdf),
  [Taiwanese](https://app.ericrxu.com/static/Taiwanese.pdf)). Hong Kong plays
  with a **0-faan minimum** by default — any complete hand, even a chicken
  hand, may be declared — or a 1-, 2- or 3-faan minimum, plus flower and season tiles and the New Style discarder-pays-all
  table. Taiwanese deals 16 tiles a seat for a 17-tile, 5-meld winning hand,
  scores flat additive points with a **5-point minimum** by default (1 or 3
  tai can be chosen instead), and adds a dealer
  win-streak bonus. Every ruleset plays a hanchan (East and South) by default,
  with an East-only option.
- **Play Online**: a private room for up to four humans, any empty seat
  filled by a bot. There is no guide here — nobody gets an assist the other
  seats lack — so this is the offline game's own guide UI, minus the guide.
- A **Custom Hand & Context Builder**, on its own screen from the start
  page: pose any table by hand — your tiles, every seat's discards and calls,
  the dora indicators, the wall counter, your seat wind (East deals) and who is
  in riichi — and the same guide scores it. A 14-tile hand gets a discard recommendation; 13 tiles plus
  a tile on offer gets a call recommendation. Nothing on the table can exceed
  four copies, and it runs no game behind it: no bots, no turn timer, no
  autoplay.

### How the guide does against the bots

Every figure below is Autoplay (the guide on Aggressive / Speed) sitting in
your seat, compared game-by-game with a **control** — `SimpleBot` itself in
your seat — on identical seeds. The Hong Kong and Taiwanese runs use three
`SimpleBot` opponents; the riichi runs use `FoldingBot`, which gets out of the
way of a riichi instead of feeding it (`SIM_FOLD=1`), so the two are not
directly comparable. Placement
is 1–4, lower is better; "better" below means the guide finishes that much
higher, on average, than the bot would have. Method, tables and re-run commands:
[`BOT_STRATEGY.md`](flutter_client/BOT_STRATEGY.md#how-the-guide-measures-up).

**🇯🇵 Riichi — the guide wins.**

| Measurement | Guide vs. bot |
|---|---|
| 3000 paired hanchan | **0.211 of a placement better**, p = 4e-16 |
| Style × Focus sweep, 2000 East games and 800 hanchan, Holm-corrected | Every Speed and Balanced pairing **0.11–0.26 better** |

Measured at `e850241`, 2026-09-12. Since then `ca4d8ee` (2026-09-24) taught the
guide to price every live riichi rather than only the first; re-measuring the
same configuration put it at **0.279** of a placement ahead, with deal-ins down
0.0515 per hanchan (p = 5e-13).

**🇭🇰 Hong Kong — the guide wins clearly.** On 6000 held-out East-only games
(seeds 300000+, 2026-09-24) it finishes **0.270 ± 0.036 of a placement ahead
of the bot** (p < 1e-6), and 0.492 ahead at a 3-faan minimum. It wins 0.310
hands per hand played to the bot's 0.253 and deals in less. What changed:
while no opponent is a threat it no longer breaks a hand up to get further
from ready, and it takes any call that brings the hand closer — the bot's
speed — while its own valuation and defence still pick among those lines.
That alone was worth 0.163 of a placement over the previous guide; six other
ideas measured at nothing and were left off
([`BOT_STRATEGY.md`](flutter_client/BOT_STRATEGY.md#round-6-8-the-bots-speed-the-guides-judgement)).

The earlier result, before that change, on three sets of seeds that no tuning
round used (East-only games, 0-faan minimum), measured at `df2627a` /
`91b989a`, 2026-09-15:

| Held-out run | Guide avg place | Bot avg place | Guide vs. bot | Wins / hand (guide · bot) |
|---|---|---|---|---|
| 2000 games, seeds 13000+ | 2.369 | 2.486 | 0.116 better, p = 4.2e-4 | 0.259 · 0.264 |
| 2000 games, seeds 60000+ | 2.428 | 2.514 | 0.086 better, p = 9.0e-3 | 0.253 · 0.258 |
| 6000 games, seeds 100000+ | 2.437 | 2.473 | 0.036 better, p = 0.059 | 0.250 · 0.262 |
| **All three, pooled (10,000 games)** | | | **0.062 ± 0.029 better, p = 2.6e-5** | |

The edge is real but modest — about 0.06 of a placement; the first run
overstated it. Before its Hong Kong tuning the same guide placed *behind* the
bot (by 0.063 and 0.050 on the first two seed sets): riichi's pre-ready model
kept breaking up close hands for wider ones, and it treated almost every
opponent as a threat, so it defended and refused calls. A softer narrow-hand
penalty and a three-set threat fixed both. It now wins about as often as the
bot while dealing in about 15% less.

*Tried and not adopted:* a win model that also counts pung and chow
acceptance, with its constants fitted to 159k guide decisions. It predicts
outcomes far better, but in a 6000-game head-to-head it finished only 0.014
of a placement ahead of the shipped guide (± 0.033, p = 0.40) — no measurable
gain — so the shipped model stays.

**🇹🇼 Taiwanese — the guide wins**, held out on seeds no tuning run used
(800 paired hanchan, `SimpleBot` opponents). Measured at `9f04de9`, 2026-09-23:

| Measurement | Guide vs. bot |
|---|---|
| Placement | **0.146 better**, ± 0.108, p = 0.008 |
| Final points | **+4.3**, ± 2.9, p = 0.004 |
| Against the table (2.5 = even) | 2.313, p = 2e-6; 1st 31.1%, 4th 20.3% |

The confidence interval is nearly as wide as the effect — 800 games is a
thinner base than the other two rulesets rest on. Before the Taiwanese fixes
the guide was 0.26 of a placement *behind* the bot: `_assessValue` only priced
13-tile hands, so every 16-tile line scored zero, which tied every discard and
made it refuse every call. Interestingly, the call-aware win model Hong Kong
measured and rejected is the one Taiwanese ships — a five-set hand leans on
calls far more than a four-set one.

*Play style, measured and dropped:* a 14,000-game sweep found style has no
placement effect under Hong Kong, so the dial is hidden and pinned to Balanced
there — focus still matters. Numbers and method:
[`BOT_STRATEGY.md`](flutter_client/BOT_STRATEGY.md#style-does-nothing-under-hong-kong).

Scoring covers the common yaku, the standard fu table and the full yakuman set;
rare fu edge cases and some double-yakuman rules are approximated. No replays
yet.

### Run

Install the [Flutter SDK](https://docs.flutter.dev/get-started/install) (≥ 3.3,
tested on 3.47). One-time setup:

```sh
cd flutter_client
flutter pub get
flutter doctor        # install/fix whatever it flags for the platforms you want
```

`flutter run` launches in debug with hot reload — press `r` to reload, `R` to
restart, `q` to quit. Add `--release` for a performance build. `flutter devices`
lists every target currently attached.

**Web**

```sh
flutter run -d chrome                        # launches in Chrome
flutter run -d web-server --web-port 8080    # serve at http://localhost:8080 for any browser
```

**Android** — needs the Android SDK (via Android Studio) plus either an emulator
or a physical device with USB debugging on:

```sh
flutter emulators                     # list installed emulators
flutter emulators --launch <id>       # boot one (or start it from Android Studio)
flutter devices                       # confirm it appears
flutter run -d android
```

**iOS** — macOS + Xcode only. First run on a physical device: open
`ios/Runner.xcworkspace` once and set a Signing Team under *Signing &
Capabilities*.

```sh
open -a Simulator                     # boot the iOS Simulator, or plug in an iPhone
flutter devices                       # confirm it appears
flutter run -d ios
```

The `web/`, `android/`, and `ios/` folders are committed; if one goes missing,
regenerate it with `flutter create .` in `flutter_client/`.

### Check

```sh
flutter analyze
flutter test
```

### Layout

```
packages/mahjong_core/lib/   pure Dart core, unit-tested, shared by the app
                              and the multiplayer server — tile model, wall,
                              shanten+ukeire, hand parsing, scoring, safety
                              model, SimpleBot, round state machine

flutter_client/lib/
  logic/    efficiency_engine.dart — the guide's scoring-aware discard EV
            placement_utility.dart — the model behind Strategy: Placement
  game/     game_controller.dart (offline) / online_game_controller.dart
  net/      multiplayer client (WebSocket)
  scenario/ the Custom Hand & Context Builder's state
  ui/       table, hand, efficiency overlay, scoring screen, tile widget

server/mp/lib/   the multiplayer game server (table_loop.dart)
```

### Languages

The app, its shared core, and the multiplayer server are a single **Dart**
codebase. Everything else is either Flutter-generated platform glue or
offline tooling, not hand-maintained app code:

| Language | Where | Purpose |
|---|---|---|
| Dart | `flutter_client/lib/`, `packages/mahjong_core/lib/`, `server/mp/lib/` | The app, its shared core, and the multiplayer server |
| Kotlin | `android/app/.../MainActivity.kt` | Thin Android host shim, generated by `flutter create` |
| Swift | `ios/Runner/` | Thin iOS host shim, generated by `flutter create` |
| Java | `android/.../GeneratedPluginRegistrant.java` | Auto-generated Android plugin registration |
| HTML | `web/index.html` | Static shell the Flutter web build mounts into |
| Python | `flutter_client/tools/mkastaroth.py`, `flutter_client/tools/render_tiles.py` | Offline asset generation (voice clips, tile art) — not part of the running app |
| Shell | `ios/Flutter/flutter_export_environment.sh` | Flutter-generated iOS build env script |

---

## Deployment (web / Android / iOS)

Full step-by-step instructions — signing, store submission, CI — are in
**[`flutter_client/DEPLOYMENT.md`](flutter_client/DEPLOYMENT.md)**. The essentials:

### Web

```sh
cd flutter_client
flutter build web --release                 # -> build/web/  (static bundle)
flutter build web --release --base-href /sub-path/   # if not hosted at domain root
```

Deploy `build/web/` to any static host (GitHub Pages, Netlify, Firebase
Hosting, …). Add an SPA fallback so deep links serve `index.html`. Bump
`version:` in `pubspec.yaml` so the service worker updates clients.

### Android

```sh
flutter build appbundle --release           # -> build/app/outputs/bundle/release/app-release.aab  (Play Store)
flutter build apk --release --split-per-abi  # -> per-ABI APKs for sideloading
```

**Not set up yet.** A release build would need a keystore referenced from
`android/key.properties` and a `signingConfigs.release` block in
`android/app/build.gradle.kts`; neither exists, and the release buildType still
uses the debug signing config. The app requests no permissions and collects no
data.

### iOS / iPhone

Requires macOS + Xcode.

```sh
open ios/Runner.xcworkspace     # set Team + Bundle Identifier under Signing & Capabilities
flutter build ipa --release     # -> build/ios/ipa/*.ipa  (or archive via Xcode Organizer)
```

Upload to App Store Connect (Xcode Organizer → Distribute App, or Transporter)
→ the build shows up in TestFlight after processing.

### Version / build number

Both come from one line in `flutter_client/pubspec.yaml`:

```yaml
version: 0.2.1+4     # 0.2.1 = version name, 4 = build number — bump +N on every store upload
```

---

## License

TileSense is licensed under GPLv3. Its efficiency calculations are adapted from
the Riichi-Trainer algorithm. See
[`LICENSE`](LICENSE). Contributions welcome.

The telemetry ingest's location lookup uses DB-IP's free "IP to City Lite"
database, licensed under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/):
[IP Geolocation by DB-IP](https://db-ip.com). Credit it the same way on any
chart or report built from `sessions.geo_country`, `geo_region` or
`geo_city`.
