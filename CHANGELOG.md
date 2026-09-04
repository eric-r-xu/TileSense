# TileSense Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- Flutter client now enforces full riichi furiten rules: own-discard furiten,
  temporary furiten from a passed-up winning discard (cleared on the next draw),
  and permanent riichi furiten. No seat — human or bot — can ron on a furiten
  wait, and the human seat shows a FURITEN marker on its placard and hand bar.
- On an exhaustive draw the score screen now opens every tenpai seat's hand and
  spells out its waits, as at a real ryuukyoku.

### Changed
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
