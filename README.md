# <img width="35" height="35" alt="tileSense" src="https://github.com/user-attachments/assets/5b178736-39e4-489d-9bc5-3ffa7f927057" /> TileSense 


<img width="215" height="215" alt="clefairy" src="https://github.com/user-attachments/assets/448af05c-3065-46d3-9c4e-73c267c7a1ae" />

--- 

A **Hong Kong mahjong tile-efficiency trainer** with a **0-faan minimum**.
Play offline against three bots while the guide compares discards, accepted tiles,
and expected chip value. Scoring follows the supplied **HKMJ Cheat Sheet 1.0**,
including its New Style “discarder pays all” payment table and 13+ faan cap.

The Flutter app for web, Android, and iOS lives under `flutter_client/`.
The shape calculator retains its GPL-licensed Riichi-Trainer ancestry; gameplay,
scoring, and advice now use Hong Kong rules.

See [the complete rules and table interpretations](docs/HONG_KONG_RULES.md).

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

## The Flutter app (`flutter_client/`)

### What it does

- A shuffled 144-tile wall with automatic flower/season replacements; chow,
  pung, exposed/concealed/added kong, self-pick, and discard wins.
- Zero-faan chicken hands are legal. No riichi, furiten, dora, fu, deposits,
  dealer multiplier, or draw payments.
- The supplied faan table, replacement-aware pattern stacking, optional
  seven/eight-flower wins, double-kong replacements, and special hands.
- Exact scoring of live ready-hand waits, estimated value before readiness,
  and public-information risk estimates without discard immunity.
- Autoplay follows the guide. Speed/value focus and defensive/aggressive
  preferences remain available.
- A Custom Hand & Context Builder with ordinary tiles, calls, discards,
  flowers/seasons, wall count, and seat/round winds.
- Four-wind games by default, or East-only practice. Scores and chip transfers
  appear at the end of each hand.

See [rules](docs/HONG_KONG_RULES.md), [guide value model](flutter_client/EXPECTED_VALUE.md),
and [bot strategy](flutter_client/BOT_STRATEGY.md) for precise behavior and limits.
There is no multiplayer lobby or replay system. Optional telemetry remains off
unless enabled explicitly in the build.

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
and `minSdk` there too). Gameplay is offline; optional telemetry is controlled by build flags.

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
