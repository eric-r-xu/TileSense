/// Best-effort multiplayer session telemetry: forwards match/round/seat
/// events to the same ingest service (`server/bin/server.dart`) the browser
/// client posts to for single-player, so multiplayer data lands in the same
/// Postgres tables (see `server/migrations/0003_multiplayer.sql`).
///
/// The mp game server is the authoritative writer here — one record per
/// shared match, from the server that computed it, rather than up to four
/// browsers each independently reporting their own view of the same match.
/// See `server/DEPLOYMENT.md` section 3 for how the two services are wired
/// together in production.
///
/// Off by default: [MpTelemetry.maybe] returns null unless `INGEST_URL` is
/// set, so nothing changes for a deployment that hasn't configured it — the
/// same opt-in shape as the browser client's own `Telemetry.maybe()`. Every
/// send is fire-and-forget with errors swallowed: a slow or dead ingest
/// service must never stall or crash a live game.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// A random RFC-4122 v4 UUID — the server-side twin of the client's
/// `newUuid()` in `flutter_client/lib/telemetry/telemetry.dart`. Duplicated
/// rather than shared: this is a separate, dart:io-only package the
/// Flutter-facing one cannot depend on.
String newUuid() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
  final s = [for (var i = 0; i < 16; i++) h(i)].join();
  return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}'
      '-${s.substring(16, 20)}-${s.substring(20)}';
}

/// How a batch is actually sent — swappable so tests can capture what would
/// have gone out without a real HTTP round trip. The default POSTs `body` as
/// JSON to `url` and gives up after a few seconds either way.
typedef IngestPoster = Future<void> Function(String url, String body);

Future<void> _defaultPost(String url, String body) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
  try {
    final req = await client.postUrl(Uri.parse(url));
    req.headers.set('content-type', 'application/json');
    req.write(body);
    await req.close().timeout(const Duration(seconds: 5));
  } finally {
    client.close(force: true);
  }
}

class MpTelemetry {
  MpTelemetry._(
    this._ingestUrl, {
    required this.hostGuestId,
    required this.hostSessionId,
    IngestPoster post = _defaultPost,
  }) : _post = post {
    _flushTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => unawaited(_flush()));
  }

  final String _ingestUrl;
  final IngestPoster _post;
  Timer? _flushTimer;

  /// The identity every batch from this match is posted under — the host's
  /// own guest/session pair, since a room always has a real human host (bots
  /// only ever fill an otherwise-empty seat, never the host's).
  final String hostGuestId;
  final String hostSessionId;

  final List<Map<String, Object?>> _buf = [];
  static const int _flushAt = 25;

  /// The live instance for one match, or null when `INGEST_URL` is unset —
  /// entirely inert, matching the client's own `Telemetry.maybe()` shape.
  /// [env] and [post] are test seams; production callers omit both.
  static MpTelemetry? maybe({
    required String hostGuestId,
    required String hostSessionId,
    Map<String, String>? env,
    IngestPoster? post,
  }) {
    final url = (env ?? Platform.environment)['INGEST_URL'];
    if (url == null || url.isEmpty) return null;
    return MpTelemetry._(
      url,
      hostGuestId: hostGuestId,
      hostSessionId: hostSessionId,
      post: post ?? _defaultPost,
    );
  }

  void _add(String type, Map<String, Object?> data) {
    _buf.add({
      'type': type,
      't': DateTime.now().toUtc().toIso8601String(),
      ...data,
    });
    if (_buf.length >= _flushAt) unawaited(_flush());
  }

  // --- public event surface --------------------------------------------

  /// [seatCharacters]/[seatIsBot]/[seatGuestIds] are one entry per seat
  /// (index = seat), null where nothing applies (a still-empty seat can't
  /// happen here — [participants] is only ever called once every seat has
  /// been filled, humans or bots). [participants] is every human seat's
  /// session — see `match_participants` in the schema.
  void matchStart({
    required String matchId,
    required String roomCode,
    required String ruleset,
    required bool hanchan,
    required int timerSeconds,
    required List<String?> seatCharacters,
    required List<bool> seatIsBot,
    required List<String?> seatGuestIds,
    required List<Map<String, String>> participants,
  }) =>
      _add('match_start', {
        'match_id': matchId,
        'mode': 'multiplayer',
        'room_code': roomCode,
        'ruleset': ruleset,
        'hanchan': hanchan,
        'timer_seconds': timerSeconds,
        'seat_characters': seatCharacters,
        'seat_is_bot': seatIsBot,
        'seat_guest_ids': seatGuestIds,
        'participants': participants,
      });

  void roundStart({
    required String matchId,
    required String roundId,
    required int roundIndex,
    required String roundWind,
    required int handNumber,
    required int dealerSeat,
    required int honba,
    required int riichiSticks,
  }) =>
      _add('round_start', {
        'match_id': matchId,
        'round_id': roundId,
        'round_index': roundIndex,
        'round_wind': roundWind,
        'hand_number': handNumber,
        'dealer_seat': dealerSeat,
        'honba': honba,
        'riichi_sticks': riichiSticks,
      });

  /// One human seat's turn action — discard, call or pass. There is no
  /// guide in multiplayer, so unlike the client's own `humanDecision` there
  /// is nothing to report following or not; [auto] is always false, since a
  /// bot-decided (timed-out or bot-converted) action is a bot's decision,
  /// not a human one, and is left unreported here — same as single-player
  /// only ever reports the human seat's own choices, never the bots'.
  void humanDecision({
    required String matchId,
    required String roundId,
    required int actorSeat,
    required String kind, // 'discard' | 'call' | 'pass'
    String? tile,
  }) =>
      _add('human_decision', {
        'match_id': matchId,
        'round_id': roundId,
        'actor_seat': actorSeat,
        'kind': kind,
        'tile': tile,
        'auto': false,
      });

  void roundEnd({
    required String matchId,
    required String roundId,
    required String endKind,
    required List<int> winners,
    int? loser,
    int? han,
    int? fu,
    int? points,
    List<String> yaku = const [],
    required List<int> pointDeltas,
    List<int> tenpaiAtDraw = const [],
    required bool dealerKept,
  }) =>
      _add('round_end', {
        'match_id': matchId,
        'round_id': roundId,
        'end_kind': endKind,
        'winners': winners,
        'loser': loser,
        'han': han,
        'fu': fu,
        'points': points,
        'yaku': yaku,
        'point_deltas': pointDeltas,
        'tenpai_at_draw': tenpaiAtDraw,
        'dealer_kept': dealerKept,
      });

  void matchEnd({
    required String matchId,
    required String reason, // 'game_end' — the only reason mp reports today
    required List<int> finalPoints,
    required List<int> seatPlaces,
  }) =>
      _add('match_end', {
        'match_id': matchId,
        'reason': reason,
        'final_points': finalPoints,
        'seat_places': seatPlaces,
      });

  /// A seat joining, leaving, reconnecting, or being converted to a bot —
  /// recorded as a generic timestamped event (kind `seat_event`), the same
  /// way the client records a `setting_change`.
  void seatEvent({
    required String matchId,
    required int actorSeat,
    required String event, // 'bot_takeover' | 'reconnected'
    String? guestId,
    String? reason,
  }) =>
      _add('seat_event', {
        'match_id': matchId,
        'actor_seat': actorSeat,
        'event': event,
        'guest_id': guestId,
        'reason': reason,
      });

  /// Push whatever is buffered now — used at match end so the terminal
  /// event is never stranded for up to 15s in an idle room.
  Future<void> flush() => _flush();

  Future<void> _flush() async {
    if (_buf.isEmpty) return;
    final events = List<Map<String, Object?>>.of(_buf);
    _buf.clear();
    final body = jsonEncode({
      'client_id': hostGuestId,
      'session_id': hostSessionId,
      'app_version': 'mp',
      'events': events,
    });
    try {
      await _post(_ingestUrl, body);
    } catch (_) {
      // Best-effort — never let a dead ingest service affect the game loop.
    }
  }

  Future<void> dispose() async {
    _flushTimer?.cancel();
    await _flush();
  }
}
