/// Thin WebSocket wrapper for the multiplayer game server: decodes every
/// incoming frame to JSON on one broadcast stream, and reconnects on a drop
/// so a flaky connection doesn't end the game — `OnlineGameController` reacts
/// to the synthetic `_reconnected` event by resending `reconnect` with its
/// room code and guest id.
library;

import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class MpClient {
  MpClient() {
    _connect();
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

  /// Every decoded server message, plus two synthetic ones this client emits
  /// itself: `{'type': '_connection_lost'}` right when the socket drops, and
  /// `{'type': '_reconnected'}` once a fresh socket is open (at which point
  /// the caller should resend `reconnect`).
  Stream<Map<String, dynamic>> get messages => _controller.stream;

  void _connect() {
    final channel = WebSocketChannel.connect(Uri.parse(_endpoint));
    _channel = channel;
    // The channel is returned before the socket is actually open — sending
    // on its sink before `ready` completes throws (silently, if nothing
    // awaits it). A failure here (bad host, refused connection) also only
    // ever surfaces through `ready`, never through `stream`, so this is also
    // the only way an unreachable server gets detected on the first attempt.
    channel.ready.catchError((Object _) => _handleDrop());
    _sub = channel.stream.listen(
      (raw) {
        try {
          _controller.add(jsonDecode(raw as String) as Map<String, dynamic>);
        } catch (_) {
          // Malformed frame — ignore rather than crash the connection.
        }
      },
      onDone: _handleDrop,
      onError: (Object _) => _handleDrop(),
      cancelOnError: true,
    );
  }

  void _handleDrop() {
    if (_closed || _controller.isClosed) return;
    _controller.add(const {'type': '_connection_lost'});
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), () {
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
        channel.sink.add(jsonEncode(message));
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
    await _sub?.cancel();
    await _channel.sink.close();
    if (!_controller.isClosed) await _controller.close();
  }
}
