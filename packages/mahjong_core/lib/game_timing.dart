/// Presentation timing shared by the offline client and multiplayer server.
library;

/// Call announcements hold play 50% longer than the previous 863 ms pause.
const Duration kCallPause = Duration(microseconds: 1294500);

/// Time to read each visible score page before automatically continuing.
const Duration kScorePageDelay = Duration(seconds: 20);

/// Extra hold after a win (tsumo or ron), on top of the call bubble, before
/// the score panel covers the table — time to see the winning tile land.
const Duration kWinScorePause = Duration(milliseconds: 500);
