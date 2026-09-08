/// Privacy-light gameplay telemetry.
///
/// **On by default in release web builds.** [Telemetry.maybe] returns a live
/// instance for a `flutter build web --release` (real players), and `null`
/// otherwise — debug/profile builds, `flutter run`, every VM test, and any
/// non-web target. Override either way:
///   * `--dart-define=TELEMETRY=false`  disables it in a release build
///   * `--dart-define=TELEMETRY=true`   enables it in a debug build
///   * `--dart-define=TELEMETRY_ENDPOINT=<url>`  points it somewhere else
///     (default: the production ingest endpoint below)
///
/// Transport is `navigator.sendBeacon` only: fire-and-forget, no response is
/// awaited, a dead or slow endpoint is invisible to gameplay. Events are
/// buffered and flushed in small batches (on a timer, at round/match
/// boundaries, and on page-hide), never one request per action.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show kReleaseMode;

// Web bindings by default; the `dart:io` variant (VM tests, Android/iOS) gets an
// inert stub so `package:web` is never compiled off the web.
import 'src/platform_web.dart'
    if (dart.library.io) 'src/platform_stub.dart' as platform;

/// On for release builds unless `--dart-define=TELEMETRY=false`.
const bool _kEnabled = bool.fromEnvironment('TELEMETRY', defaultValue: kReleaseMode);
const String _kEndpoint = String.fromEnvironment(
  'TELEMETRY_ENDPOINT',
  defaultValue: 'https://app.ericrxu.com/ingest',
);
const String _kAppVersion =
    String.fromEnvironment('APP_VERSION', defaultValue: 'dev');

/// A random RFC-4122 v4 UUID string. Used for the persistent client id and for
/// per-match / per-round ids the server upserts on.
String newUuid() {
  final r = Random();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
  final s = [for (var i = 0; i < 16; i++) h(i)].join();
  return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}'
      '-${s.substring(16, 20)}-${s.substring(20)}';
}

class Telemetry {
  Telemetry._(this._endpoint) {
    _flushTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => _send(beacon: false));
  }

  /// The live instance, or `null` when telemetry is disabled (debug build
  /// without an explicit `TELEMETRY=true`, or `TELEMETRY=false`) or not running
  /// on the web. Callers use `_tel?.method(...)`.
  static Telemetry? maybe() {
    if (!_kEnabled || _kEndpoint.isEmpty || !platform.isWebPlatform) return null;
    return Telemetry._(_kEndpoint);
  }

  final String _endpoint;
  final String _sessionId = newUuid();
  final List<Map<String, Object?>> _buf = <Map<String, Object?>>[];
  Timer? _flushTimer;

  static const int _maxBuffered = 500;
  static const int _flushAt = 25;

  String get _clientId {
    const key = 'ts_client_id';
    final existing = platform.localStorageGet(key);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = newUuid();
    platform.localStorageSet(key, id);
    return id;
  }

  void _add(String type, Map<String, Object?> data) {
    _buf.add({
      'type': type,
      't': DateTime.now().toUtc().toIso8601String(),
      ...data,
    });
    if (_buf.length > _maxBuffered) {
      _buf.removeRange(0, _buf.length - _maxBuffered);
    }
    if (_buf.length >= _flushAt) _send(beacon: false);
  }

  // --- public event surface (all no-ops when maybe() returned null) ---------

  void matchStart({
    required String matchId,
    required int seed,
    required bool hanchan,
    required bool fastMode,
    required bool autoplay,
    required bool guideVisible,
  }) =>
      _add('match_start', {
        'match_id': matchId,
        'seed': seed,
        'hanchan': hanchan,
        'fast_mode': fastMode,
        'autoplay': autoplay,
        'guide_visible': guideVisible,
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

  /// One human turn action. [followedGuide] is `null` when the guide had no
  /// recommendation to compare against (e.g. it was still analysing).
  void humanDecision({
    required String matchId,
    required String roundId,
    required String kind, // 'discard' | 'call' | 'pass'
    String? tile,
    required bool auto,
    required bool guideVisible,
    String? guideReco,
    bool? followedGuide,
  }) =>
      _add('human_decision', {
        'match_id': matchId,
        'round_id': roundId,
        'kind': kind,
        'tile': tile,
        'auto': auto,
        'guide_visible': guideVisible,
        'guide_reco': guideReco,
        'followed_guide': followedGuide,
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
    required Map<int, int> pointDeltas,
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
        'point_deltas': [
          pointDeltas[0] ?? 0,
          pointDeltas[1] ?? 0,
          pointDeltas[2] ?? 0,
          pointDeltas[3] ?? 0,
        ],
        'tenpai_at_draw': tenpaiAtDraw,
        'dealer_kept': dealerKept,
      });

  void matchEnd({
    required String matchId,
    required String reason, // 'game_end' | 'new_game' | 'abandoned'
    List<int>? finalPoints,
    int? humanSeat,
    int? humanPlace,
  }) =>
      _add('match_end', {
        'match_id': matchId,
        'reason': reason,
        'final_points': finalPoints,
        'human_seat': humanSeat,
        'human_place': humanPlace,
      });

  void settingChange({
    String? matchId,
    required String setting,
    required Object value,
  }) =>
      _add('setting_change', {
        'match_id': matchId,
        'setting': setting,
        'value': value,
      });

  /// Best-effort synchronous flush for page-hide / dispose.
  void flushBeacon() => _send(beacon: true);

  void _send({required bool beacon}) {
    if (_buf.isEmpty) return;
    final events = List<Map<String, Object?>>.of(_buf);
    _buf.clear();
    final body = jsonEncode({
      'client_id': _clientId,
      'session_id': _sessionId,
      'app_version': _kAppVersion,
      'events': events,
    });
    try {
      final ok = platform.beaconSend(_endpoint, body);
      if (!ok && !beacon) {
        // Queue was full; keep the newest events for the next attempt.
        _buf.insertAll(0, events.take(_maxBuffered));
      }
    } catch (_) {
      // Never let telemetry surface an error into the app.
    }
  }

  void dispose() {
    _flushTimer?.cancel();
    flushBeacon();
  }
}
