# TileSense Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- **A third ruleset: 🇹🇼 Taiwanese**, ported from the TileSenseTW fork and
  following the San Diego Mahjong Club's 16-tile cheat sheet: 16 tiles a seat,
  a 17-tile winning hand of 5 melds and a pair (or seven pairs and a pung),
  flat additive points with a 5-point minimum to declare hu, no dealer premium
  on the hand's own value but a separate 2/4/6 dealer win-streak bonus, and
  temporary-only furiten. It's in the welcome-screen picker, app-bar toggle,
  online lobby and builder, with a write-up at
  [`docs/TAIWANESE_RULES.md`](docs/TAIWANESE_RULES.md). The Taiwanese-only
  pieces live under `packages/mahjong_core/lib/taiwanese/`;
  `Ruleset.isChineseStyle` covers the table flow it shares with Hong Kong
  (flowers, no riichi, nothing callable off the last discard).
  - `hand_parse.dart` and `efficiency_calc.dart` take a `totalMelds` (4, or 5
    for Taiwanese, from `Ruleset.totalMelds`) instead of a hard-coded 4. The
    guide passes it through too, so its shanten, acceptance, waits and
    call acceptance count a Taiwanese hand against 5 melds rather than
    reading 16 tiles as a finished 4-meld hand.
  - The builder poses 16-tile hands (17 with the draw) under Taiwanese, and
    lists its waits at an exhaustive draw through the new `Round.waitsFor`.
  - A concealed kong is laid down completely face down (`Ruleset
    .hidesConcealedKongs`, Taiwanese only): other seats see four backs until
    the hand ends, the guide doesn't count its tiles as seen, and the
    multiplayer snapshot sends them to other players as blanks. Riichi and
    Hong Kong still show the middle two tiles.
  - **The guide now beats the bots under Taiwanese rules** — 0.146 of a
    placement ahead of `SimpleBot` in your seat over 800 held-out paired
    hanchan (p = 0.008), where it had been 0.26 behind (p = 0.001). It had
    been valuing every Taiwanese line at 0 (`_assessValue` checked for a
    13-tile hand), mixed Hong Kong chips with Taiwanese points, counted a
    self-draw's payment once, and scored every wait as an early win. It now
    prices everything in Taiwanese points, runs a call-aware win model
    (`WinModel.taiwanese`, chosen by `test/taiwanese_tuning_sweep_test.dart`),
    treats 4 exposed sets as a threat and charges a 7-point deal-in. Riichi
    and Hong Kong simulations reproduce their previous results exactly.
    Details in `flutter_client/BOT_STRATEGY.md`.
  - `guide_vs_bots_sim_test.dart` takes `SIM_RULESET` (riichi, hongKong or
    taiwanese).
  - Kyuushu kyuuhai is now gated on `isRiichi` rather than `!isHongKong`, so
    Taiwanese doesn't inherit it.
  - Unselected rulesets in the builder's chip row show just their flag (named
    on hover), so three options fit the tool bar two used to fill.

### Fixed
- **Pinfu was missed on a two-sided wait that finishes on a terminal, and
  wrongly given to edge waits.** `_isRyanmenWait` had its terminal cases
  inverted: 1 completing 123 from 23 and 9 completing 789 from 78 (both
  two-sided) counted as edge waits, while 3 completing 123 from 12 and 7
  completing 789 from 89 (the real penchan waits) counted as two-sided. It now
  matches the wait-fu rule beside it, and a wait that reads as two-sided as well
  as kanchan takes the two-sided reading and its 0 fu.
- **A riichi player could kan their way out of tenpai, then pay noten.**
  `_kanKeepsWait` compared the hand after a closed kan with itself, so every
  riichi kan passed. A kan that broke the wait left a riichi hand that was no
  longer tenpai — and it then paid the noten penalty at an exhaustive draw on
  top of its riichi stick. A riichi closed kan is now offered only for the tile
  just drawn, and only when the hand waits on exactly the same tiles before and
  after. This is the one place bots, the human player and the multiplayer server
  all get their closed-kan options.
- With auto-sort on, the just-drawn tile is no longer filed in among the sorted
  tiles: it stays at the far right, slightly spaced from the rest, exactly as it
  does with auto-sort off.
- **A riichi tsumo showed its winning tile twice on the result screen.**
  Every drawn tile is added to `seat.hand` on draw, win or not, so the
  self-drawn winning tile was already sitting in the hand `ScoringView`
  loops over — and then rendered *again*, highlighted, in the separate
  "winning tile" slot right after. The main loop's filter (`w.hand.where((t)
  => t != winTile)`) already existed for Hong Kong self-picks but was
  wrongly scoped to `hk` only; it now always applies, which is also a no-op
  for a ron (whose winning tile is never part of `w.hand` to begin with, so
  nothing to filter). New test: `flutter_client/test/scoring_view_test.dart`.
- **Hong Kong wins spoke a generic "win" line instead of ron/tsumo, offline
  and online.** `GameController._playRoundEndSfx` and `OnlineGameController
  .playRoundEndVoice` deliberately swapped in `VoiceKind.win` for Hong Kong,
  reasoning the ron/tsumo clips say the Japanese terms out loud. Riichi and
  Hong Kong now voice the same line for the same win kind — a discard win
  plays ron, a self-draw plays tsumo — even though Hong Kong's own button
  labels for the two stay "Win" / "Self-pick" (`Ruleset.ronLabel`/
  `tsumoLabel`, unchanged). The plain ron/tsumo blip (`SfxKind`) already
  played under both rulesets; only the spoken character line was gated.
  Updated `flutter_client/test/online_win_voice_test.dart`'s two Hong Kong
  cases; new `flutter_client/test/hong_kong/hk_win_voice_test.dart` covers
  the offline path.
- **Hong Kong hands almost never got the winner's celebratory "yeah" or the
  discarder's resigned acquiescement, offline or online.** Both
  `GameController._playRoundEndSfx` and `OnlineGameController
  .playRoundEndVoice` gated that chain on `HandScore.limitName` being
  non-empty — for riichi that means mangan+, exactly as intended, but Hong
  Kong's own `limitName` only flags the payment table's 13-faan cap, which
  an ordinary game essentially never reaches. Any Hong Kong win under that
  cap, however large, silently played only the plain win line. New
  `Ruleset.isBigHand(HandScore)` (`packages/mahjong_core/lib/ruleset.dart`)
  gives Hong Kong its own, actually-reachable threshold — 5+ faan, the same
  "scale stops just doubling" position mangan occupies among riichi hands —
  and both call sites now go through it. New test:
  `packages/mahjong_core/test/ruleset_test.dart`; extended
  `flutter_client/test/online_win_voice_test.dart` with a 5-faan case.
- **Multiplayer chi/pon/kan only ever played the plain call blip — no
  character voice line, unlike offline.** `OnlineGameController
  ._playCallSfx` detected the call (via `newMeldKind`) and played its `SfxKind`
  but never looked up the caller's character to voice it, the way
  `GameController._playCallSfx` always has. Pulled the caller-voicing logic
  into a new testable `OnlineGameController.playCallVoice`, mirroring
  `playRoundEndVoice`. New tests in
  `flutter_client/test/online_call_sfx_test.dart`.
- **Multiplayer always dealt in join order — the room's creator was always
  East and dealt first, guests always seated in the order they joined.**
  `TableLoop.start` now randomizes who sits where (`_shuffleSeats`) before
  filling any still-empty seat with a bot. Since a live connection's
  message handler used to cache its own seat number as an int at
  `join_room`/`create_room` time, reseating players out from under an
  already-open socket would have stranded it on the wrong index —
  `server.dart`'s handler now resolves a connection's current seat by guest
  ID on every message instead of caching it, so the reindexing needs no
  coordination with already-connected clients. New test:
  `server/mp/test/seat_shuffle_test.dart`; updated
  `room_flow_test.dart`'s disconnect/bot-takeover test, which had hardcoded
  the pre-shuffle join-order seat.
- **Multiplayer: whoever wasn't dealt server seat 0 saw the wrong player at
  their own "you" spot, and the wrong character controlling their
  neighbors.** `buildRoundFromSnapshot` deliberately rotates every seat
  index so the local `Round` always has "me" at local seat 0 — the
  assumption `TableView`/`HandView` are built on — but
  `OnlineGameController.seatLabel`/`characterForSeat` still compared that
  local seat number directly against `lobbySeats`, which is a plain,
  unrotated copy of the server's seat roster. The two only happened to
  agree when a player's real server seat *was* 0, which is why this went
  unnoticed until someone was dealt into a different one: they'd see
  whoever the server calls seat 0 labeled "(you)" and controlling their own
  portrait, with everyone else's positions similarly offset. Both methods
  now convert the local seat back to the real server seat
  (`(localSeat + mySeat) % 4`) before looking it up; `lastBotTakeoverSeat`
  (set straight from the server's own absolute seat number) is converted
  the other way when a `bot_takeover` message arrives, so it stays in the
  same local frame every other seat number this controller exposes uses.
  New test: `test/online_seat_rotation_test.dart`.
- **Multiplayer round-ends only ever played a plain chime — no character
  voice acting on a win, and nothing at all for a mangan+ deal-in.**
  `OnlineGameController._playRoundEndSfx` had intentionally dropped every
  voice line, reasoned as "the fixed bot-persona voice lines don't make
  sense once other seats are real people" — but every seat online already
  has a real, displayed persona (the lobby character picker, portraits at
  the table), so there was nothing mismatched about voicing it. It now
  chains the same way `GameController` does: the winner's line, a mangan+
  win adds their celebratory "yeah", and a mangan+ ron adds the discarder's
  resigned "acquiescement" — sourcing each seat's character from the
  server's assignment. Chi/pon/kan still only get the plain call blip (not
  yet their spoken line) — narrower scope, not a different rationale. New
  tests: `test/online_win_voice_test.dart`.
- **Multiplayer never played a sound for chi/pon/kan, in either ruleset.**
  `OnlineGameController`'s sound handling only ever covered discards and
  round-end wins (`_playTurnSfx`/`_playRoundEndSfx`) — calls had no path to
  `Sfx.i.play` at all. The protocol has no "seat N just called" signal the
  way it has `discardSerial`/`lastDiscardSeat` for a discard, so the new
  `OnlineGameController.newMeldKind` detects one the same way a reconnecting
  client would have to: comparing meld counts between the last snapshot and
  this one, per seat. Character voice lines remain intentionally dropped
  online (see the comment above `_playTurnSfx`) — this only restores the
  plain call blip every other action already had. New tests:
  `test/online_call_sfx_test.dart`.
- **Multiplayer: your own character could silently not match what you were
  actually assigned.** `Room.resolveCharacter` substitutes a different
  persona when the one you request is already taken by an earlier seat in
  the room, but `OnlineGameController.myCharacter` (and so the lobby's "you
  are ___" picker) kept showing the request rather than the assignment —
  every other seat's roster row, and the table once the game started, showed
  the real one, so the two visibly disagreed. `_applyRoomState` now
  reconciles the local guest identity to match `room_state`'s actual
  assignment for your own seat as soon as it arrives. New server-side
  regression test: `server/mp/test/room_flow_test.dart`.
- **A stalled audio fetch could permanently silence voice lines for the rest
  of the session.** `AudioBackend._load` (web) awaited `fetch` +
  `decodeAudioData` with no timeout. `Sfx._pumpVoice`'s watchdog only arms
  once a clip has *loaded*, so a request that never settled (a flaky
  connection, a backgrounded tab throttling network requests) never armed it
  either: `_voiceBusy` stayed `true` forever and every later line queued up
  silently behind it. `_load` now bounds the fetch/decode at 5s, turning a
  hang into an ordinary, already-handled failure that unblocks the queue.

### Added
- Chi now lets you choose the run when a discard could make several (3456m
  offered 5m gives 345m, 456m and 567m): one button per run, with the guide's
  pick starred while it is on. Previously the guide's choice was made for you.
- "Riichi available" now shows in the hand bar whenever riichi is legal, not
  only when the guide would declare it; it adds "recommended" only while the
  guide is on.
- The mascot now sits to the left of **Single Player** on the start screen, as a
  hint that the guide is part of offline play.
- The character-select screen has a **Game length** choice: hanchan (半庄,
  default) or East only (东风战).
- The mascot art is replaced everywhere it is used (in-app, favicon, PWA icons —
  now `-v3` to bust caches, README).
- **A third guide dial, Strategy: Points or Placement, riichi only.** Points
  is the reference model this whole engine was built and tuned against, and
  is unchanged. Placement (opt-in, `kDefaultStrategy` stays Points) runs
  every points-flavoured term — payout, riichi deposit, deal-in cost,
  commitment cost — through a new closed-form heuristic,
  `PlacementUtility.placementValue` (`lib/logic/placement_utility.dart`): a
  logistic in each opponent's score gap, scaled by hands left in the game, no
  simulation or opponent-hand modelling. `DiscardLine.placementExpectedValue`
  is always computed alongside `expectedValue` so the panel can show both;
  only the active dial's figure drives sorting and the recommendation. Riichi
  vs damaten is compared directly on placement value when the dial is on
  Placement, instead of the fixed points threshold Points uses. Hidden and
  pinned to Points under Hong Kong, same treatment as Style, for a different
  reason — see `flutter_client/BOT_STRATEGY.md` and
  `flutter_client/EXPECTED_VALUE.md#strategy--points-or-placement-riichi-only`.
  New tests: `flutter_client/test/placement_strategy_test.dart`.
- **An "EV (HMR)" comparison column beside Expected Value.**
  `DiscardLine.expectedValueHmr` is `winProbability × averagePoints` and
  nothing else — no honba/riichi-stick bonus, no risk, lock-in, commitment
  or Style/Focus term. It mirrors the "E.V." stat in HMR (Hitori Mahjong
  Renshuuki), a closed-source solo tsumo-only trainer with no code or data
  ties to this project: its E.V. was worked out empirically from its own
  simulation log as total points scored ÷ hands played, which is exactly
  win rate × average winning score, and it has no other terms because it
  has no other seats to add a bonus from or a deal-in to price. The column
  is purely informational — it never drives the recommendation — and both
  the header and each cell carry a tooltip working through the arithmetic,
  same as Expected Value's.
- **Tapping an EV (HMR) number opens charts of how it was made.** The cell
  is underlined and clickable; the tooltip stays on hover / long-press. The
  page (`lib/ui/ev_explainer_dialog.dart`, hand-drawn with `CustomPainter`
  so there is no new dependency) shows the chance of finishing turn by turn
  — cumulative line plus a per-turn bar chart, with the reached-tenpai line
  before tenpai — the inputs the estimator was given, what the win pays, and
  a waterfall carrying EV (HMR) up to the Expected Value column through
  honba/sticks, the Focus tilt, and each cost. Touch, drag or hover a chart
  for any turn's numbers. To feed it, `DiscardLine.winBreakdown`
  (`WinBreakdown` / `WinTurn` / `WinEstimator`) now records the per-turn
  series `_winChanceOverTurns`, `_winProbabilityFromShanten` and the
  tenpai lookahead were already computing and discarding; no number the
  guide produces changes. New tests:
  `flutter_client/test/ev_explainer_test.dart` (each line's series ends on
  its table win probability, the waterfall lands on Expected Value, tap →
  dialog).

### Changed
- **The STYLE, FOCUS, STRATEGY and PLACEMENT tooltips are bulleted, with real
  tables, and the Safety section is always in the guide.** Every heading
  tooltip now follows one layout — a one-line answer, bullets, a table where a
  reference table is in play, then the formula. New tables: typical ukeire by
  shanten (Ukeire / Accepts); deal-in chance by safety rating with what earns
  each rating (Safety, riichi and Hong Kong's own scale); risk weight, damaten
  bar and the payout each Style stays quiet from; what Speed counts a payout
  and a chance as (FOCUS, in chips under Hong Kong); and what ±8,000 points is
  worth at an even table, with a big lead, far behind, and on the last hand
  (PLACEMENT). The tables are real `Table` widgets inside the tooltip, so
  columns line up in any font, and every value is read from the engine. The
  Safety, Risk and Detail columns are no longer hidden until a riichi is out:
  they always show, with "—" when there is nothing to defend against, so their
  tooltips are reachable on any turn under either ruleset (Detail is 80px wide,
  down from 92, to keep the table inside the panel). New tests in
  `flutter_client/test/guide_tooltips_test.dart`.
- **The guide's glossary under the table is gone; every heading and dial
  that names a concept explains itself on hover instead.** Shanten / Away,
  Ukeire / Accepts, Safety, Risk, Detail, Placement, and the STYLE / FOCUS /
  STRATEGY dial names each carry a tooltip, and the GUIDE title keeps the
  legend with no heading of its own (green / yellow tile, the pause key — not
  shown in the scenario builder, which has none). The tooltips hold the
  heuristics behind each concept — the Speed payout and chance curves, the
  Style risk weights and damaten bars, the placement model with a worked
  example, the deal-in rate by rating, the commitment charge, the
  typical-ukeire table — read live from the engine through a new read-only
  `GuideConstants` (and `HandFocus` / `PlayStyle` / `PlacementUtility`), so
  retuning a constant cannot leave the text stale. Each section of the
  Expected Value tooltip now ends with a pointer to where its working lives.
  The pre-tenpai payout placeholders (3,900 / 5,800 closed, 2,000 / 2,900
  open) are named constants instead of inline literals, and the tap-through
  chart page states them. Also fixed a stale mention of the removed Value
  focus setting. New tests: `flutter_client/test/guide_tooltips_test.dart`;
  `safety_test.dart` and the two scenario tests now assert on the tooltips
  instead of the deleted bullets.
- **The Expected Value and EV (HMR) tooltips are shorter and quote the chance
  of finishing to two decimals.** Each general explainer is a few one-line
  parts instead of paragraphs (formula, then chance / payout / risk / focus),
  and the worked "THIS CUT" block now shows the multiplication behind its
  "so on average" row — `= 33.10% x (11,740 + 300)` — so the number can be
  checked by eye. The chance reads `33.10%` rather than `33%` (and the
  explainer dialog's headline matches). The HMR tooltip drops its long URL
  paragraph for a one-line description of what HMR's E.V. is; the link stays
  in `EXPECTED_VALUE.md`. No number changes. Tests:
  `flutter_client/test/ev_explainer_test.dart`.
- **The Style dial is hidden under Hong Kong rules and pinned to Balanced.**
  Style has no riichi or damaten left to weigh there — two of its three terms
  were already dead code — and a 14,000-game sweep (`_dialEffects` in
  `test/policy_sweep_test.dart`) found no placement effect from the third
  either (every pairwise style comparison Holm p = 1.0), while Speed still
  beat Balanced focus at every style (p ≤ 4e-5). `GameController` and
  `ScenarioController` now pin `playStyle` to Balanced on switching to Hong
  Kong and restore the prior riichi style on switching back; the app bar,
  builder toolbar and guide panel all hide the chip while Hong Kong is
  active. Riichi is unaffected. Details:
  `flutter_client/BOT_STRATEGY.md#style-does-nothing-under-hong-kong`.
- **Measured, and not adopted: a call-aware, self-play-calibrated Hong Kong
  win model.** `TileEfficiencyCalculator.callAcceptance` counts tiles a hand
  could pung or chow forward; the win model's constants now live in
  `WinModel` (riichi's are unchanged and pinned by a test); and
  `test/hong_kong/hk_calibration_data_test.dart` plus
  `tools/fit_hk_win_model.py` fit them to self-play. The fit predicted far
  better (held-out log loss 0.5575 → 0.5246) but played no better: 0.014 of a
  placement ahead of the shipped guide over 6000 paired games, p = 0.40.
  Calibration without calls played worse than the bot. The shipped model is
  unchanged. A 6000-game held-out run also revised the shipped guide's lead
  over the bot: **0.062 of a placement pooled over 10,000 held-out games**
  (±0.029, p = 2.6e-5), not the 0.116 first measured.
- **The Hong Kong guide now beats the bots.** It placed 0.063 behind
  `SimpleBot`; it now places ahead — 0.116 on its first 2000 held-out
  games, 0.062 pooled over later runs — 0.179 ahead of its old self. Two
  Hong Kong-only settings in `HongKongGuideTuning`: the pre-ready penalty on
  narrow hands is halved (a narrow hand can pung or chow forward), and a
  threat needs three exposed sets, not two. Per hand, steps away from ready
  fell from 1.84 to 0.76, hands reaching ready rose from 41% to 51%, turns
  defending fell from 2.96 to 0.58, and wins rose from 0.216 to 0.247 (the
  bot: 0.249) with 15% fewer deal-ins than the bot. New opt-in harnesses:
  `test/hong_kong/hk_guide_diag_test.dart` and
  `test/hong_kong/hk_tuning_sweep_test.dart`. Riichi is unaffected.
- **The guide starts on Aggressive / Speed under riichi, and Speed under Hong
  Kong** (Style is hidden there — see above). New games and the builder open
  on those defaults; switching rulesets restores whatever riichi's Style was
  set to. `EfficiencyValueContext` keeps Balanced / Balanced as its reference
  default. Evidence, in `flutter_client/BOT_STRATEGY.md`: in riichi every
  Speed and Balanced pairing beats the control bot (0.11–0.26 placement,
  Holm-corrected); in Hong Kong Speed beats Balanced focus at every style
  (p ≤ 4e-5, `_dialEffects`).
- `policy_sweep_test.dart` gained `SWEEP_RULESET` and Holm-corrected,
  best-arm comparisons.
- **Flowers and seasons are real tiles** — 梅 蘭 菊 竹 / 春 夏 秋 冬 with their
  pictures, in colour, and the seat number 1–4 in red top-right like the suit
  tiles. `tools/render_tiles.py` now renders them (plus a character layer);
  the 34 existing tile images are unchanged.
- **🇯🇵 Riichi / 🇭🇰 Hong Kong** flags on every ruleset toggle, with links to
  each ruleset's rules PDF on the welcome screen and a rules button in the
  game's app bar.

### Added
- **Hong Kong rules, alongside riichi.** A Riichi / Hong Kong toggle on the
  welcome screen, in the game's app bar (switching deals a new game) and in the
  builder. Hong Kong follows *HKMJ Cheat Sheet 1.0* with a 0-faan minimum:
  144 tiles with flowers and seasons, the sheet's faan patterns and New Style
  discarder-pays-all table, four-wind games, and no riichi, dora, furiten,
  honba or draw payments (`docs/HONG_KONG_RULES.md`). One shared engine
  branches on `Ruleset`; Hong Kong-only scoring, wall and safety live in
  `lib/logic/hong_kong/`. Riichi defaults and behaviour are unchanged: the
  178 existing riichi tests give identical results, with 101 Hong Kong tests
  and 4 toggle tests added.
- **Gameplay telemetry.** A new `server/` Dart service ingests
  match / round / decision batches into Postgres; the client
  (`lib/telemetry/`) buffers them and sends with `navigator.sendBeacon`
  (fire-and-forget, batched — a dead endpoint never touches gameplay). **On by
  default in release web builds**, pointed at `https://app.ericrxu.com/ingest`;
  debug builds, `flutter run`, and every VM test are inert. Opt out with
  `--dart-define=TELEMETRY=false`; repoint with `--dart-define=TELEMETRY_ENDPOINT`.
  Records whether the guide's recommended action was taken (`followed_guide`)
  and whether autoplay was on (`auto`). No raw IP is stored — only a keyed hash
  and a `/24`–`/48` prefix. Deploy runbook: `server/DEPLOYMENT.md`.
- **Chi is now part of the game.** The round offers it to the seat immediately
  after the discarder (and only that seat), bars it during riichi, and ranks it
  below pon, kan and ron. Where a discard could complete more than one run
  (holding 34567p and offered 5p), the guide scores each and takes the best, so
  the CHI button stays a single tap — `resolveCalls` gained an optional
  `chiLow` map naming the run a caller wants. The opponents still never chi:
  `SimpleBot` intentionally has no chi logic.
- The guide now advises on **calls**, not just discards: ron, chi, pon and
  closed / open kan. Every option is scored through the same expected-value model the
  discard table uses — the state it leaves you in once melds are counted — and
  then has to clear three hard rules: it must advance the hand, leave a yaku to
  finish on, and not commit you while a riichi is out and you are still behind.
  Kan must preserve the shape and a valid yaku path; its payoff (a fresh dora
  indicator) still helps the opponents too. The call prompt shows the verdict
  *and* the reasoning.
- Full riichi furiten rules on the Flutter client: own-discard furiten,
  temporary furiten from a passed-up winning discard (cleared on the next draw),
  and permanent riichi furiten. No seat — human or bot — can ron on a furiten
  wait, and the human seat shows a FURITEN marker on its placard and hand bar.
- On an exhaustive draw the score screen now opens every tenpai seat's hand and
  spells out its waits, as at a real ryuukyoku.
- `BOT_STRATEGY.md`: a plain-language comparison of the opponents' `SimpleBot`
  heuristic against the guide that plays your seat.
- `EXPECTED_VALUE.md`: a walkthrough of the expected-value model — the inputs,
  the pre-tenpai vs. tenpai estimators and their formulas, the riichi/damaten
  plan selection, the riichi-danger discount, and how calls are scored on the
  same scale.

### Changed
- The repository is Flutter-only; the retired desktop client and its build
  assets have been removed, along with stale documentation references.
- Unused voice source recordings now live under `tools/audio_sources/` instead
  of shipping in the Flutter asset bundle.
- **Autoplay now plays your seat from the guide**, not from the opponents'
  heuristic. It follows the recommended discard, the riichi/damaten verdict,
  the call advice and the concealed-kan verdict. Previously `_botOrAutoTurn`
  handed your seat to `SimpleBot` like any other, so the analysis on screen was
  display-only and Autoplay ignored it — despite the README documenting the
  opposite.
- The efficiency/EV guide and hand auto-sort are now both **off** by default, so
  a new game starts on the plain table with tiles in draw order. The clefairy
  button and the sort button (both in the hand bar) still turn them on
  per-session.
- The guide panel is now titled "GUIDE" (was "TILE SENSE GUIDE"), and its
  Expected Value column is narrower — it was the one column left unconstrained
  and ran far wider than it needed to.
- The clefairy guide-toggle now lives once, in the bottom bar just left of the
  GitHub link and sized to match it. Removed the duplicate clefairy marks from
  the app bar and the guide panel header.
- Flutter web: the browser tab icon is now clefairy instead of the default
  Flutter mark.
- Flutter client: a small "Built with Flutter" credit (the stock `FlutterLogo`
  widget, linking to flutter.dev) sits bottom-right of the hand bar, after the
  GitHub link.
- The Flutter client is now landscape-only on every target: `main()` locks
  orientation via `SystemChrome`, and the Android manifest, iOS `Info.plist`,
  and `web/manifest.json` are all pinned to landscape (bringing Android/iOS to
  parity with the web build's landscape gate). The web PWA manifest's
  background/theme colours now match the app's letterbox instead of the Flutter
  default blue.

### Fixed
- Guided kan advice now rejects a kan that would leave an open hand without a
  yaku, matching the existing pon/chi minimum.
- Web audio latency. Every voice line is a separate file that `audioplayers`
  fetches at the moment it wants to play it, and the bundle carried no
  `Cache-Control`, so each sound made a `304` round trip before it could start
  — barely noticeable on desktop, audible lag on mobile. `Sfx.preload()` now
  warms every clip through the browser's HTTP cache on the first gesture (in
  small batches, evicting the bytes so they aren't held in Dart memory too),
  and `DEPLOYMENT.md` documents the nginx side: media cached for a day, app
  shell still `no-cache` so deploys land.
- Dora sitting inside a **called meld** was never counted. `scoreHand` built its
  tile list from the concealed hand plus the winning tile only, so a ponned dora
  scored nothing and the honitsu/chinitsu suit check couldn't see a meld in a
  second suit. Every open hand was undervalued — a yakuhai pon carrying three
  dora was priced at ~770 points instead of ~5800.
- The pre-tenpai expected-value model spent the *whole* remaining wall on every
  step toward tenpai, so a wide 3-shanten hand scored higher than a narrow
  1-shanten one. The draws left are now shared across the steps still needed,
  which is what makes "call vs. stay put" comparable at all.
- A voice line's stall watchdog was armed before playback had even started, so
  a call whose audio failed outright (no plugin, or a blocked autoplay) left an
  8-second timer running with nothing to cancel it. It is now armed only once
  the clip is actually playing, which is the case it exists to cover.
- The guide panel's call recommendation ("Recommended: PON / PASS") was
  `SimpleBot`'s output presented as guide advice; it now comes from the
  expected-value advisor, as does the Autoplay discard hint.
- Flutter web: tiles no longer render blank on Chrome for mobile. Tile faces
  were drawn as Unicode Mahjong Tiles glyphs via `Text`, which depends on the
  browser having — and having already *loaded* — a font covering that block:
  missing on stock Android fonts entirely, and (even after bundling a subset
  font directly) still a race against asynchronous web font loading relative
  to first paint. Tile faces are now bundled PNGs (rasterized once at build
  time — see `tools/render_tiles.py`), which has no such dependency and
  renders identically everywhere.
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
