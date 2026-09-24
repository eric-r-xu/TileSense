/// Presentation timing shared by the offline client and multiplayer server.
library;

/// Call announcements hold play 50% longer than the previous 863 ms pause.
const Duration kCallPause = Duration(microseconds: 1294500);

/// Time to read each visible score page before automatically continuing.
const Duration kScorePageDelay = Duration(seconds: 25);
