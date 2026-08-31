# OpenRiichi Flutter 2D client

This is a separate Flutter executable, intentionally independent of the Vala/Meson build. It uses the existing project's 2D layout as a design reference: a local hand at the bottom, concealed opponents, a central discard table, wall counter, and tap-to-discard controls.

## Run

Install the [Flutter SDK](https://docs.flutter.dev/get-started/install), then run:

```sh
cd flutter_client
flutter pub get
flutter run
```

Use `flutter run -d ios`, `flutter run -d android`, or a connected simulator/device. The Flutter tool will generate the Android and iOS platform folders when needed (`flutter create .`).

## Implemented gameplay

- A locally shuffled 136-tile wall and four dealt hands
- Human draw/discard turns with touch-friendly 2D tiles
- Three automated opponents, sequential turns, discards, wall exhaustion, and visible ponds
- Tsumo detection for standard four-meld-and-pair hands, seven pairs, and thirteen orphans
- A new-round control and responsive phone/tablet layout

## Deliberately not yet shared with the desktop client

The original client has a full authoritative server, its own custom `Serializable` protocol, calls (chi/pon/kan), riichi/furiten, scoring, replays, lobby, and settings. Those must be ported and tested as a protocol/rules subsystem—not approximated in a UI layer—before this client can interoperate with the Vala server. The existing Vala source is left untouched.
