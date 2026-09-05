# <img width="35" height="35" alt="tileSense" src="https://github.com/user-attachments/assets/5b178736-39e4-489d-9bc5-3ffa7f927057" /> TileSense 


<img width="215" height="215" alt="clefairy" src="https://github.com/user-attachments/assets/448af05c-3065-46d3-9c4e-73c267c7a1ae" />

--- 

[Flutter Desktop Web App](https://app.ericrxu.com/tilesense/)

A Japanese mahjong (riichi) **tile-efficiency trainer**: play offline hands
against bots while a live guide grades every discard — shanten, ukeire (tile
acceptance), probability-weighted point value, and the recommended tile — and,
when an opponent declares riichi, ranks your hand by safety.

This repo contains the cross-platform **Flutter** app for web, Android, iOS,
and desktop under `flutter_client/`.

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
  riichi/damaten plan at tenpai.
- A **defensive panel** when an opponent is in riichi: each tile rated 0–15
  (genbutsu / suji / one-chance / honor-by-copies) with a short reason; the
  recommendation switches to the safest discard.
- End-of-round scoring: yaku list, han/fu, dora/ura/aka, limit hands and
  yakuman, and the point transfers.
- An **Autoplay** toggle that plays your seat with the recommended discard.

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
version: 0.2.0+2     # 0.2.0 = version name, 2 = build number — bump +N on every store upload
```

---

## License

TileSense is licensed under GPLv3. Its efficiency calculations follow the
Riichi-Trainer algorithm. See
[`LICENSE`](LICENSE). Contributions welcome.
