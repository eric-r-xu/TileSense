/// Thin WebSocket wrapper for the multiplayer game server: decodes every
/// incoming frame to JSON on one broadcast stream, and reconnects on a drop
/// so a flaky connection doesn't end the game — `OnlineGameController` reacts
/// to the synthetic `_reconnected` event by resending `reconnect` with its
/// room code and guest id.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:web_socket_channel/web_socket_channel.dart';

class MpClient {
  /// [endpoint], [silenceLimit], [retryBase], [retryMax] and [random] are for
  /// tests; the app uses the defaults.
  MpClient({
    String? endpoint,
    Duration silenceLimit = defaultSilenceLimit,
    Duration retryBase = const Duration(seconds: 1),
    Duration retryMax = const Duration(seconds: 15),
    math.Random? random,
  })  : _uri = Uri.parse(endpoint ?? _endpoint),
        _silenceLimit = silenceLimit,
        _retryBase = retryBase,
        _retryMax = retryMax,
        _random = random ?? math.Random() {
    _connect();
  }

  final Uri _uri;
  final Duration _silenceLimit;
  final Duration _retryBase;
  final Duration _retryMax;
  final math.Random _random;

  /// Failed attempts in a row since the last time a socket opened.
  int _attempts = 0;

  /// How long to wait before the next try: doubling from [_retryBase] up to
  /// [_retryMax], each jittered by +-25%, so a server restart does not bring
  /// every player back in the same instant, and a server that stays down is
  /// not hammered.
  Duration _retryDelay() {
    final exp = _retryBase * (1 << _attempts.clamp(0, 10));
    final capped = exp > _retryMax ? _retryMax : exp;
    return capped * (0.75 + _random.nextDouble() * 0.5);
  }

  /// The production server by default (mirrors how `telemetry.dart` defaults
  /// to the production ingest endpoint) — override for local dev with
  /// `--dart-define=MP_ENDPOINT=ws://localhost:8789`.
  static const String _endpoint = String.fromEnvironment(
    'MP_ENDPOINT',
    defaultValue: 'wss://app.ericrxu.com/tilesense/mp/',
  );

  late WebSocketChannel _channel;
  StreamSubscription<dynamic>? _sub;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  Timer? _reconnectTimer;
  bool _closed = false;

  /// How long the server may stay silent, once it has shown it sends
  /// `heartbeat`s, before the connection is treated as dead. Browsers answer
  /// the server's pings without telling the page, so a half-dead socket
  /// (a sleeping laptop, a lost Wi-Fi) would otherwise look open forever.
  /// An older server never sends one, so it is never timed out.
  static const Duration defaultSilenceLimit = Duration(seconds: 45);

  Timer? _watchdog;
  DateTime? _lastFrame;
  bool _heartbeats = false;

  /// Every decoded server message, plus two synthetic ones this client emits
  /// itself: `{'type': '_connection_lost'}` right when the socket drops, and
  /// `{'type': '_reconnected'}` once a fresh socket is open (at which point
  /// the caller should resend `reconnect`).
  Stream<Map<String, dynamic>> get messages => _controller.stream;

  void _connect() {
    _heartbeats = false;
    _lastFrame = DateTime.now();
    _watchdog?.cancel();
    final channel = WebSocketChannel.connect(_uri);
    _channel = channel;
    // The channel is returned before the socket is actually open — sending
    // on its sink before `ready` completes throws (silently, if nothing
    // awaits it). A failure here (bad host, refused connection) also only
    // ever surfaces through `ready`, never through `stream`, so this is also
    // the only way an unreachable server gets detected on the first attempt.
    channel.ready.then((_) {
      if (identical(channel, _channel)) _attempts = 0;
    }, onError: (Object _) => _handleDrop(channel));
    _sub = channel.stream.listen(
      (raw) {
        _lastFrame = DateTime.now();
        try {
          final msg = jsonDecode(raw as String) as Map<String, dynamic>;
          if (msg['type'] == 'heartbeat') {
            _heartbeats = true;
            _armWatchdog();
            return;
          }
          _controller.add(msg);
        } catch (_) {
          // Malformed frame — ignore rather than crash the connection.
        }
      },
      onDone: () => _handleDrop(channel),
      onError: (Object _) => _handleDrop(channel),
      cancelOnError: true,
    );
  }

  /// Starts the silence check, only once a server has shown it sends
  /// heartbeats, so a connection to one that doesn't carries no timer.
  void _armWatchdog() {
    if (_watchdog?.isActive ?? false) return;
    _watchdog = Timer.periodic(_silenceLimit ~/ 9, (_) {
      final last = _lastFrame;
      if (_closed || !_heartbeats || last == null) return;
      if (DateTime.now().difference(last) < _silenceLimit) return;
      // Silent for too long: drop this socket and start over. Disarmed first,
      // or it would trip again and again, each time pushing the retry back.
      _watchdog?.cancel();
      _heartbeats = false;
      _sub?.cancel();
      _channel.sink.close();
      _handleDrop();
    });
  }

  /// [from] is the socket that dropped; one already replaced by a newer
  /// socket closing late must not start another round of retries.
  void _handleDrop([WebSocketChannel? from]) {
    if (_closed || _controller.isClosed) return;
    if (from != null && !identical(from, _channel)) return;
    // One drop is often reported twice (a failed open, then the close): the
    // retry is already on its way.
    if (_reconnectTimer?.isActive ?? false) return;
    _controller.add(const {'type': '_connection_lost'});
    final delay = _retryDelay();
    _attempts++;
    _reconnectTimer = Timer(delay, () {
      if (_closed) return;
      _connect();
      _controller.add(const {'type': '_reconnected'});
    });
  }

  void send(Map<String, dynamic> message) {
    final channel = _channel;
    // Deferred until the socket is actually open (see `_connect`); on any
    // other platform/version where `ready` is already complete this just
    // runs on the next microtask, so it's not a meaningful delay either way.
    channel.ready.then((_) {
      if (_closed || !identical(channel, _channel)) return;
      try {
        channel.sink.add(jsonEncode({...message,
          if (const ['create_room', 'join_room', 'reconnect'].contains(message['type']))
            'supportedRulesets': ['riichi', 'hongKong', 'taiwanese', 'mcr'],
        }));
      } catch (_) {
        // The next drop/reconnect cycle will surface this; nothing to do here.
      }
    }, onError: (Object _) {
      // `_connect`'s own `ready.catchError` already handles this failure.
    });
  }

  Future<void> close() async {
    _closed = true;
    _reconnectTimer?.cancel();
    _watchdog?.cancel();
    await _sub?.cancel();
    await _channel.sink.close();
    if (!_controller.isClosed) await _controller.close();
  }
}
