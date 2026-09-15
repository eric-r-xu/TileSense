# <img width="35" height="35" alt="tileSense" src="https://github.com/user-attachments/assets/5b178736-39e4-489d-9bc5-3ffa7f927057" /> TileSense 


<img width="215" height="215" alt="clefairy" src="https://github.com/user-attachments/assets/448af05c-3065-46d3-9c4e-73c267c7a1ae" />

--- 

[Play the live web app](https://app.ericrxu.com/tilesense/)

A mahjong **tile-efficiency trainer** for **Japanese riichi** and **Hong Kong**
rules: play offline hands against bots while a live guide grades every discard
— shanten, ukeire (tile acceptance), probability-weighted point value, and the
recommended tile — and, when an opponent threatens, ranks your hand by safety.

Pick 🇯🇵 Riichi or 🇭🇰 Hong Kong on the welcome screen, or switch at any time
from the game's app bar (which deals a new game) or the builder's chip row.
Riichi is the default. Hong Kong follows *HKMJ Cheat Sheet 1.0* with a
**0-faan minimum**; see [Hong Kong rules](docs/HONG_KONG_RULES.md). One-page
references: [Riichi.pdf](https://app.ericrxu.com/static/Riichi.pdf),
[HK.pdf](https://app.ericrxu.com/static/HK.pdf).

This repo contains the cross-platform **Flutter** app for web, Android, and iOS
under `flutter_client/`.

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

## Two rulesets, one engine

`lib/logic/ruleset.dart` defines `Ruleset.riichi` and `Ruleset.hongKong`. The
round, guide, bots, scenario builder and UI are shared and branch on the
ruleset only where the games differ. Hong Kong-only logic lives in
`lib/logic/hong_kong/`:

| File | What it holds |
|---|---|
| `hong_kong_rules.dart` | Minimum faan, the payment table, starting chips, Seven Pairs switch |
| `hong_kong_scoring.dart` | Faan patterns and payments (`scoreHongKongHand`, `scoreFlowerWin`) |
| `hong_kong_wall.dart` | The 144-tile wall with flowers and tail replacements |
| `hong_kong_safety.dart` | Risk estimates with no discard immunity |

Everything else — shanten and acceptance, win-probability modelling, call
mechanics, the table and hand widgets — is the same code for both. Riichi tests
live in `test/`, Hong Kong tests in `test/hong_kong/`, and
`test/ruleset_toggle_test.dart` covers the switch itself.

---

## The Flutter app (`flutter_client/`)

### What it does

- A shuffled 136-tile wall and a full offline round vs three bots: draws,
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
  shows the charge as a Risk column beside the value it came off.
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
  **Aggressive / Speed**, chosen from the sweeps below.
- **🇯🇵 Riichi and 🇭🇰 Hong Kong rules**, chosen on the welcome screen or from
  the app bar, each with a one-page rules PDF
  ([Riichi](https://app.ericrxu.com/static/Riichi.pdf),
  [Hong Kong](https://app.ericrxu.com/static/HK.pdf)). Hong Kong plays with a
  **0-faan minimum** — any complete hand, even a chicken hand, may be declared
  — plus flower and season tiles, the New Style discarder-pays-all table, and
  four-wind games.

### How the guide does against the bots

Measured with `test/policy_sweep_test.dart` on identical seeds against a
`SimpleBot` control in your seat (details and tables in
[`BOT_STRATEGY.md`](flutter_client/BOT_STRATEGY.md#how-the-guide-measures-up)):

- **Riichi — it wins.** Every Speed and Balanced Style × Focus pairing beat
  the control bot by 0.11–0.26 of a placement, over 2000 East games and again
  800 hanchan, Holm-corrected; overall the guide went from 0.247 of a placement
  worse than the bot to 0.211 better (3000 paired hanchan, p = 4e-16).
- **Hong Kong — it wins too.** Over 2000 East-only games on held-out seeds,
  the guide places **0.116 of a placement better** than the bot
  (p = 4.2e-4). It first trailed the bot: riichi's pre-ready model kept
  breaking up close hands for wider ones, and it treated almost every
  opponent as a threat, so it defended and refused calls. A softer
  narrow-hand penalty and a three-set threat, chosen over two tuning rounds,
  lifted wins per hand from 0.219 to 0.259 (the bot: 0.264) while dealing in
  15% less than the bot. Aggressive / Speed is also the best of the six
  Style × Focus pairings for Hong Kong.
- A **Custom Hand & Context Builder**, on its own screen from the start
  page: pose any table by hand — your tiles, every seat's discards and calls,
  the dora indicators, the wall counter, your seat wind (East deals) and who is
  in riichi — and the same guide scores it. A 14-tile hand gets a discard recommendation; 13 tiles plus
  a tile on offer gets a call recommendation. Nothing on the table can exceed
  four copies, and it runs no game behind it: no bots, no turn timer, no
  autoplay.

Scoring covers the common yaku, the standard fu table and the full yakuman set;
rare fu edge cases and some double-yakuman rules are approximated. No
networking, lobby, or replays.

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
flutter_client/lib/
  logic/   pure Dart, unit-tested — tile model, wall, shanten+ukeire,
           hand parsing, scoring, safety model, SimpleBot, round state machine
  game/    game_controller.dart — round + bots + async turn loop (ChangeNotifier)
  ui/      table, hand, efficiency overlay, scoring screen, tile widget
```

### Languages

The app itself is a single **Dart** codebase — every file under `lib/` (game
logic, UI, everything). Everything else is either Flutter-generated platform
glue or offline tooling, not hand-maintained app code:

| Language | Where | Purpose |
|---|---|---|
| Dart | `flutter_client/lib/` | The app — logic, game loop, UI |
| Kotlin | `android/app/.../MainActivity.kt` | Thin Android host shim, generated by `flutter create` |
| Swift | `ios/Runner/` | Thin iOS host shim, generated by `flutter create` |
| Java | `android/.../GeneratedPluginRegistrant.java` | Auto-generated Android plugin registration |
| HTML | `web/index.html` | Static shell the Flutter web build mounts into |
| Python | `tools/mkastaroth.py`, `tools/render_tiles.py` | Offline asset generation (voice clips, tile art) — not part of the running app |
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

Needs a release keystore referenced from `android/key.properties` and a
`signingConfigs.release` block in `android/app/build.gradle` (set `applicationId`
and `minSdk` there too). The app requests no permissions and collects no data.

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
