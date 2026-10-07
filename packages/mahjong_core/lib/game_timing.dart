/// Presentation timing shared by the offline client and multiplayer server.
library;

/// Call announcements hold play 50% longer than the previous 863 ms pause.
const Duration kCallPause = Duration(microseconds: 1294500);

/// Time to read each visible score page before automatically continuing.
const Duration kScorePageDelay = Duration(seconds: 20);

/// Extra hold after a win (tsumo or ron), on top of the call bubble, before
/// the score panel covers the table — time to see the winning tile land.
const Duration kWinScorePause = Duration(milliseconds: 500);

/// Online, how long the score panel's Continue stays locked after it appears,
/// so one player can't skip the scores before the others have read them.
const Duration kScoreContinueLock = Duration(seconds: 6);

/// Online, the least time between two discards landing on the table when the
/// server's updates arrive in a burst after a lag: just under the pond's
/// 480 ms travel animation, so each tile is seen landing in turn.
const Duration kReplayGap = Duration(milliseconds: 420);

/// The shorter gap a long backlog replays at, so the table catches up fast.
const Duration kReplayCatchUpGap = Duration(milliseconds: 200);

/// How long a discard stays on the table, untouched, before a bot reacts to it
/// (chi / pon / kan / ron), so viewers get to see the tile land.
const Duration kBotCallHold = Duration(milliseconds: 700);
