# <img width="35" height="35" alt="tileSense" src="https://github.com/user-attachments/assets/5b178736-39e4-489d-9bc5-3ffa7f927057" /> TileSense 


<img width="215" height="215" alt="TileSensor" src="flutter_client/assets/tilesensor.png" />

--- 

[Play online](https://app.ericrxu.com/tilesense/)

A mahjong single and multiplayer game as well as a custom hand builder with decision-stats and autoplay.

Pick 🇯🇵 Riichi, 🇭🇰 Hong Kong or 🇹🇼 Taiwanese on the welcome screen, or switch
at any time from the game's app bar (which deals a new game) or the builder's
chip row. Riichi is the default; see [Riichi rules](docs/JAPANESE_RIICHI_RULES.md). Hong Kong follows *HKMJ Cheat Sheet 1.0* with a
**0-faan minimum** by default, or 1, 2 or 3 faan; see [Hong Kong rules](docs/HONG_KONG_RULES.md). Taiwanese is
16-tile mahjong (5 melds and a pair) with flat, additive points and a
**5-point (tai) minimum** by default, or 1 or 3; see [Taiwanese rules](docs/TAIWANESE_RULES.md). One-page
references: [Riichi.pdf](https://app.ericrxu.com/static/Riichi.pdf),
[HK.pdf](https://app.ericrxu.com/static/HK.pdf),
[Taiwanese.pdf](https://app.ericrxu.com/static/Taiwanese.pdf).

This repo contains the cross-platform **Flutter** app (`flutter_client/`) for
web, Android, and iOS, its shared pure-Dart core (`packages/mahjong_core/`),
and the multiplayer game server (`server/mp/`) it plays online against.

The shanten/ukeire math follows the Riichi-Trainer algorithm; the riichi core —
round engine, tile model, wall, hand parsing, scoring and the opponents'
`SimpleBot` — is adapted from OpenRiichi; the Hong Kong and
Taiwanese rules and the 2D layout are maintained as part of TileSense.

---

## Quick start

Install the
[Flutter SDK](https://docs.flutter.dev/get-started/install), then from `flutter_client/` run `flutter pub get` once and:

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
`Ruleset.hongKong` and `Ruleset.taiwanese`. The round, guide, bots, scenario builder and UI are mostly shared 

---

## The Flutter app (`flutter_client/`)

### What it does

- A shuffled wall — 136 tiles under riichi, 144 with flowers under Hong Kong
  and Taiwanese — and a full offline round vs three bots: draws,
  discards, **chi**, **pon** and **kan**, riichi, tsumo, ron, and
  exhaustive draw with tenpai payments.
- A **live recommendation guide**: for every tile in your hand — resulting shanten,
  ukeire count, accepted tiles, and expected value. 
  - In tenpai, EV scores every live wait and weights it by remaining copies and estimated win probability. 
  - Before tenpai, it uses completion probability and a dealer/open-hand value estimate.
  - Recommended actions based on the guide are highlighted, with a riichi/damaten plan at tenpai. 
  - Honba and the riichi deposits (Riichi only) already on the table are counted too: they pay out on any win. 
  - Against an opponent riichi, each discard is also charged what it can cost you: its chance of
  dealing in, from its own safety rating, times what that hand pays, plus the
  turns that choosing it commits you to. 
  - Folding therefore wins on the numbers when the hand is not worth pushing, rather than by a separate rule. 
  - The panel shows the charge as a Risk column beside the value it came off. 
  - A second, standalone **EV (HMR)** column shows the same win-probability-times-average-
  score product 
    — the "E.V." stat from [HMR (Hitori Mahjong Renshuuki)](https://pathofhouou.blogspot.com/2019/05/training-tool-hitori-mahjong-simulator.html), a solo trainer with no code or data ties to this project, worked out from its own simulation log purely for validated comparison (it never drives the recommendation)
- A **defensive panel** when an opponent is in riichi
- End-of-round scoring: yaku list, han/fu, dora/ura/aka, limit hands and
  yakuman, and the point transfers.
- An **Auto-Play** toggle that plays your seat with the recommended discard/action.
- A **goal** — Win Rate, Points or Placement, starting on **Placement** —
  that the guide and Auto-Play play for. 
  - The goal picks three underlying dials from simulated games against the bots (`logic/auto_dials.dart`)
  - **Play Style** — defensive, balanced or aggressive — how the guide
    prices danger and how readily it keeps a hand quiet rather than declaring
    riichi
  - **Focus** — Speed or Balanced — which tilts chance of finishing against
    payout
  - **Strategy** — Points or Placement — 
    - Placement runs every a heuristic model of how it moves the chance of finishing above each other seat. Details: [`EXPECTED_VALUE.md`](flutter_client/EXPECTED_VALUE.md#strategy--points-or-placement-riichi-only).

  Under riichi, Win Rate and Points play **Aggressive / Speed / Points** and
  Placement plays **Balanced / Speed / Points**. 

  Hong Kong and Taiwanese pin style to Balanced and strategy to Points; focus is Speed, except Balanced at Taiwanese's 5-tai minimum. 

  The Custom Hand & Context Builder has no game to win, so it keeps the three dials to set by hand.

- **🇯🇵 Riichi, 🇭🇰 Hong Kong and 🇹🇼 Taiwanese rules**, chosen on the welcome
  screen or from the app bar, each with the associated rules PDF
  ([Riichi](https://app.ericrxu.com/static/Riichi.pdf),
  [Hong Kong](https://app.ericrxu.com/static/HK.pdf),
  [Taiwanese](https://app.ericrxu.com/static/Taiwanese.pdf)). 

  - Hong Kong plays with a **0-faan minimum** by default
  - Taiwanese deals 16 tiles a seat for a 17-tile, 5-meld winning hand,
  scores flat additive points with a **5-point minimum** by default (1 or 3
  tai can be chosen instead), and adds a dealer win-streak bonus. 
  - Every ruleset plays a hanchan (East and South) by default, with an East-only option.
- **Play Online**: 
  - a private room for up to four humans, any empty seat filled by a bot. 
  - There is intentionally no guide or auto-play here 
- A **Custom Hand & Context Builder**: 
  - on its own screen from the start page
  - pose any table by hand (your tiles, every seat's discards and calls, the dora indicators and who is in riichi (Riichi only), the wall counter, and your seat wind (East deals) and the same guide scores it. 

Scoring covers the common yaku, the standard fu table and the full yakuman set;
rare fu edge cases and some double-yakuman rules are approximated. No replays
yet.

### Run

Install the [Flutter SDK](https://docs.flutter.dev/get-started/install).
One-time setup:

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
            auto_dials.dart — the dials each Goal plays
  game/     game_controller.dart (offline) / online_game_controller.dart
  net/      multiplayer client (WebSocket)
  scenario/ the Custom Hand & Context Builder's state
  telemetry/ gameplay telemetry client
  ui/       table, hand, efficiency overlay, scoring screen, tile widget

server/mp/lib/   the multiplayer game server (table_loop.dart)
server/bin/      the telemetry ingest (server.dart)
reports/         bot-simulation runs and the stats report
```

### Languages

The app, its shared core, the multiplayer server and the telemetry ingest are
a single **Dart** codebase. Everything else is either Flutter-generated
platform glue or offline and deploy tooling, not part of the running app:

| Language | Where | Purpose |
|---|---|---|
| Dart | `flutter_client/lib/`, `packages/mahjong_core/lib/`, `server/mp/lib/`, `server/bin/` | The app, its shared core, the multiplayer server and the telemetry ingest |
| Kotlin | `android/app/.../MainActivity.kt` | Thin Android host shim, generated by `flutter create` |
| Swift | `ios/Runner/` | Thin iOS host shim, generated by `flutter create` |
| Java | `android/.../GeneratedPluginRegistrant.java` | Auto-generated Android plugin registration |
| HTML | `web/index.html` | Static shell the Flutter web build mounts into |
| Python | `flutter_client/tools/`, `reports/sim_report.py`, `server/deploy/` | Offline tooling — tile art, font fingerprinting, web precompression, the HK win-model fit, the sim report, and deploy scripts (the voice-clip generators are kept local) |
| Shell | `deploy.sh`, `clean.sh`, `reports/*.sh`, `server/deploy/` | Deploy, cleanup and sim-run scripts |
| SQL | `server/migrations/`, `reports/sim_schema.sql` | Telemetry and sim-results database schemas |

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

## Credits

- **[Riichi-Trainer](https://github.com/Euophrys/Riichi-Trainer)** by
  Euophrys, for the shanten, ukeire and defense calculations.
- **[OpenRiichi](https://github.com/FluffyStuff/OpenRiichi)** by FluffyStuff,
  an open-source, cross-platform riichi mahjong client (GPLv3). TileSense
  began as a fork of it, and its riichi core was ported from OpenRiichi's
  Vala source: the round engine, tile model, wall, hand parsing, yaku/han/fu
  scoring, and the `SimpleBot` opponent logic.
- **[Training tool: Hitori Mahjong Simulator](https://pathofhouou.blogspot.com/2019/05/training-tool-hitori-mahjong-simulator.html)**
  on Path of Houou, for the EV calculation comparisons (the guide's
  **EV (HMR)** column).

### Playtesting and feedback

Thank you to the friends and players whose testing, suggestions, and bug reports
helped improve TileSense.

- **Jesse C** — For identifying riichi exhaustive draws that incorrectly advanced
  the dealer despite the dealer being in tenpai, and introducing me to two valuable
  resources: [Hitori Mahjong Renshuuki (HMR)](https://pathofhouou.blogspot.com/2019/05/training-tool-hitori-mahjong-simulator.html),
  used to validate baseline EV calculations, and
  [Euophrys’s Mahjong Efficiency Trainer](https://euophrys.itch.io/mahjong-efficiency-trainer),
  which underpins TileSense’s shanten and ukeire calculations.
- **Raymond M** — For identifying errors in pinfu scoring, illegal closed kans
  after declaring riichi, and missing choices when multiple chi combinations were
  available.
- **Sherman L** — For suggesting a single-player rewind feature that lets players
  revisit a decision, try a different action, and explore the outcome.
- **Melissa R** — For suggesting larger buttons and more space between controls,
  especially on mobile.
- **Helen W** — For testing multiplayer from China and identifying slow
  home-screen loading, which prompted audio caching improvements to reduce startup
  time.
- **Vilay K** — For suggesting a slower pace of play, which inspired pauses
  between calls and an adjustable bot-speed setting.
- **Mark G** — For recommending Flutter, which helps TileSense stay compatible
  across all screen sizes.

Thank you to everyone else who shared feedback. If I’ve missed you and you’d like
to be credited, please get in touch.

---

## License

TileSense is licensed under GPLv3. Its efficiency calculations are adapted from
the Riichi-Trainer algorithm, and its riichi core (round engine, tile model,
wall, hand parsing, scoring and `SimpleBot`) from OpenRiichi (also GPLv3). See
[`LICENSE`](LICENSE). Contributions welcome.

The telemetry ingest's location lookup uses DB-IP's free "IP to City Lite"
database, licensed under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/):
[IP Geolocation by DB-IP](https://db-ip.com). Credit it the same way on any
chart or report built from `sessions.geo_country`, `geo_region` or
`geo_city`.
