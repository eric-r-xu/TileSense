# TileSense Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Fixed
- Flutter web: tiles no longer render blank on Chrome for Android. The faces are
  Unicode Mahjong Tiles glyphs, which stock Android fonts don't cover, so
  CanvasKit had been falling back to a runtime Noto download that failed
  whenever the network was slow, blocked, or offline. A ~34 KB subset of Noto
  Sans Symbols 2 (the mahjong block only) is now bundled and pinned as the tile
  font, so tiles render offline and look identical across browsers.
- Flutter web: sound now plays reliably on mobile Safari and mobile Chrome, not
  just desktop. Each `Sfx` player drives its own `AudioContext`, which starts
  suspended until resumed from a user gesture; the unlock/prime now happens via
  a native DOM listener attached directly to `window` (`lib/game/
  gesture_unlock_web.dart`) instead of through Flutter's own pointer-event
  pipeline, which on strict mobile browsers was one hop too many for the
  eventual `resume()` call to still count as gesture-linked — and it keeps
  priming on every gesture rather than only the first, since mobile Safari in
  particular can need more than one attempt, or a context can be re-suspended
  later. Every play call also dropped its redundant `stop()`-before-`play()`
  (`AudioPlayer.play()` already restarts from the beginning on its own),
  removing another `await` between a tap and the actual native `play()`. The
  voice channel still runs a serial queue so overlapping lines (e.g. a call
  line into the round-end chain) can't abort each other's `play()`.
- Flutter client: layout no longer varies by browser — a tap-heavy centre
  status block rendered taller and the rotate-to-landscape prompt's line
  spacing looked looser on some mobile browsers (Chrome in particular) than
  others (Safari, Firefox). Every browser sets its own default text-scale
  factor independently of the page's own layout, and this app is authored
  entirely in fixed logical pixels scaled as one unit — so the fix pins
  `MediaQuery.textScaler` to `TextScaler.noScaling` app-wide, matching the
  fixed-canvas design instead of at the mercy of each browser's default.
- Flutter client: ura dora is now actually revealed. The dead-wall's ura row was
  wired up but never shown (its `revealUra` flag was never set), so a riichi win
  never displayed which tiles counted; it now reveals once a riichi hand wins
  the round. The score screen also lists the dora (and, on a riichi win, ura
  dora) indicator tiles themselves next to the han count, not just the "Dora N"
  line.
- Flutter client: an opponent's hand and everything centred around it (portrait,
  placard, melds) no longer visibly shifts every time that seat draws then
  discards. The concealed-hand strip now reserves a fixed footprint for the
  largest case (13 resting tiles + the drawn tile) instead of growing and
  shrinking with the tile count, so the seat only settles once the discard-cut
  animation shows whether it was the drawn tile or one from the hand.

### Added
- Flutter client now enforces full riichi furiten rules: own-discard furiten,
  temporary furiten from a passed-up winning discard (cleared on the next draw),
  and permanent riichi furiten. No seat — human or bot — can ron on a furiten
  wait, and the human seat shows a FURITEN marker on its placard and hand bar.
- On an exhaustive draw the score screen now opens every tenpai seat's hand and
  spells out its waits, as at a real ryuukyoku.

### Changed
- Flutter client: the efficiency/EV guide and hand auto-sort are now both **off**
  by default, so a new game starts on the plain table with tiles in draw order.
  The clefairy button and the sort button (both in the hand bar) still turn
  them on per-session.
- Flutter client: the guide panel is now titled "GUIDE" (was "TILE SENSE
  GUIDE"), and its Expected Value column is narrower — it was the one column
  left unconstrained and ran far wider than it needed to.
- Flutter client: the clefairy guide-toggle now lives once, in the bottom bar
  just left of the GitHub link and sized to match it. Removed the duplicate
  clefairy marks from the app bar and the guide panel header.
- Flutter client is now landscape-only on every target: `main()` locks
  orientation via `SystemChrome`, and the Android manifest, iOS `Info.plist`,
  and `web/manifest.json` are all pinned to landscape (bringing Android/iOS to
  parity with the web build's landscape gate). The web PWA manifest's
  background/theme colours now match the app's letterbox instead of the Flutter
  default blue.
- Vendored the `Engine/` rendering engine directly into the repo instead of a
  git submodule pointing at a personal fork; it now tracks
  [FluffyStuff/Engine](https://github.com/FluffyStuff/Engine) as its upstream,
  with local macOS build fixes and a `Container.process_paused` addition kept in
  tree. Removed `.gitmodules`.

## [0.2.1.1] - 2020-05-04

### Fixed
- Rendering issue on AMD GPUs.

## [0.2.1.0] - 2020-04-24

### Added
- Changelog file.
- Table texture selection option in options menu.
- Feature to persist window state between runs.
- Meson build scripts.
- More verbose debug log
- Compile and runtime option for data search directory
- About menu
- Game start animation

### Changed
- Disabled background music by default.
- Moved Engine project into a subfolder as a git submodule.
- Statically build Engine into executable file.
- Move shaders from GLSL 120 to GLES 100 for better macOS support.
- Changed audio backend to use SDLMixer instead of SFML audio.

### Fixed
- Compilation and runtime for linux and macOS.
- Game scene lights over/under exposing tiles.

### Removed
- Makefile build scripts.

## [0.2.0.3] - 2020-04-11

### Fixed
- Decision time option being applied by remote server.

## 0.2.0.2 - 2020-04-11 [YANKED]

### Added
- Variable decision time option, between 2 and 120 seconds.

## [0.2.0.1] - 2020-04-11

### Changed
- Revision numbers no longer considered for version compatibility.

### Fixed
- Some broken debug code.

## 0.2.0.0 - 2020-04-10 [YANKED]

### Added
- An animation system for both 3D and 2D scenes.
- A new shader system for auto generating shaders.
- A wrapper framework for 3D scenes, which automates many 3D tasks.

### Changed
- Merged the development branch which contained many bug fixes and impromevents.
- Improved networking and serialization system.
- Split up Engine into its own proper library.
- Rewrite of game scenes and menus.

### Fixed
- Accumulation of many bugs and defects.

## [0.1.3.2] - 2018-03-31

### Fixed
- Yaku calculations with called tiles.

## [0.1.3.1] - 2017-06-11

### Fixed
- Bug which caused slow loading of the main game scene.

## [0.1.3.0] - 2016-12-05

### Added
- Initial TileSense release.
