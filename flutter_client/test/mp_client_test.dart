import 'dart:convert';
import 'dart:io';

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/net/mp_client.dart';

/// The connection watchdog: a server that has shown it sends heartbeats and
/// then goes quiet is treated as dead and reconnected, while heartbeats
/// themselves never reach the game.
void main() {
  late HttpServer server;
  final sockets = <WebSocket>[];

  setUp(() async {
    // flutter_test stubs out HTTP (and so WebSocket) traffic; this test
    // talks to a socket on localhost.
    HttpOverrides.global = null;
    sockets.clear();
    server = await HttpServer.bind('127.0.0.1', 0);
    server.transform(WebSocketTransformer()).listen(sockets.add);
  });

  tearDown(() async {
    for (final s in sockets) {
      await s.close();
    }
    await server.close(force: true);
  });

  test('a server that goes quiet after its heartbeat is reconnected',
      () async {
    final client = MpClient(
        endpoint: 'ws://127.0.0.1:${server.port}',
        silenceLimit: const Duration(milliseconds: 900));
    final seen = <String>[];
    client.messages.listen((m) => seen.add(m['type'] as String));

    await _until(() => sockets.isNotEmpty);
    sockets.first.add(jsonEncode({'type': 'heartbeat'}));
    sockets.first.add(jsonEncode({'type': 'state'}));

    // Silence: nothing more is sent. The client gives up on this socket,
    // then opens a second one (the retry waits two seconds).
    await _until(() => seen.contains('_connection_lost'));
    await _until(() => sockets.length >= 2, seconds: 6);
    expect(seen.where((t) => t == '_connection_lost'), hasLength(1),
        reason: 'one drop is announced once');
    expect(seen, contains('_reconnected'));
    expect(seen, contains('state'));
    expect(seen, isNot(contains('heartbeat')),
        reason: 'heartbeats are the client\'s business, not the game\'s');
    await client.close();
  });

  test('retries back off up to a cap',
      () async {
    // Nothing listens here, so every attempt fails.
    final dead = await HttpServer.bind('127.0.0.1', 0);
    final deadPort = dead.port;
    await dead.close(force: true);

    final client = MpClient(
        endpoint: 'ws://127.0.0.1:$deadPort',
        retryBase: const Duration(milliseconds: 100),
        retryMax: const Duration(milliseconds: 400),
        random: _Fixed(0.5)); // jitter factor 1.0
    final stamps = <DateTime>[];
    client.messages.listen((m) {
      if (m['type'] == '_reconnected') stamps.add(DateTime.now());
    });
    await _until(() => stamps.length >= 5, seconds: 8);
    await client.close();

    // Gaps between attempts: ~100, 200, 400, then capped at 400 (ms), each
    // plus the time a refused connection takes to fail.
    final gaps = [
      for (var i = 1; i < stamps.length; i++)
        stamps[i].difference(stamps[i - 1]).inMilliseconds
    ];
    expect(gaps[1], greaterThan(gaps[0] - 40), reason: '$gaps');
    expect(gaps[2], greaterThan(gaps[0] + 150), reason: '$gaps');
    expect(gaps.last, lessThan(700), reason: 'the delay is capped: $gaps');
  });

  test('the delay is jittered, not identical for every player', () async {
    final delays = <int>{};
    for (final r in [0.0, 0.5, 1.0]) {
      final dead = await HttpServer.bind('127.0.0.1', 0);
      final port = dead.port;
      await dead.close(force: true);
      final client = MpClient(
          endpoint: 'ws://127.0.0.1:$port',
          retryBase: const Duration(milliseconds: 400),
          random: _Fixed(r));
      final lost = DateTime.now();
      DateTime? back;
      client.messages.listen((m) {
        if (m['type'] == '_reconnected') back ??= DateTime.now();
      });
      await _until(() => back != null);
      delays.add(back!.difference(lost).inMilliseconds ~/ 50);
      await client.close();
    }
    expect(delays.length, greaterThan(1), reason: '$delays');
  });

  test('a server that never sends a heartbeat is never timed out', () async {
    final client = MpClient(
        endpoint: 'ws://127.0.0.1:${server.port}',
        silenceLimit: const Duration(milliseconds: 450));
    final seen = <String>[];
    client.messages.listen((m) => seen.add(m['type'] as String));
    await _until(() => sockets.isNotEmpty);
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(seen, isEmpty);
    expect(sockets.length, 1);
    await client.close();
  });
}

Future<void> _until(bool Function() test, {int seconds = 4}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (!test()) {
    if (DateTime.now().isAfter(end)) fail('timed out waiting');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

/// A [math.Random] that always answers [value].
class _Fixed implements math.Random {
  _Fixed(this.value);
  final double value;
  @override
  double nextDouble() => value;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}
