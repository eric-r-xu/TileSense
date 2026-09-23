import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mahjong_core/mahjong_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';
import 'package:tilesense_mp/room.dart';
import 'package:tilesense_mp/server.dart';
import 'package:tilesense_mp/table_loop.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// A short-timeout [TableLoop] factory so disconnect/timeout paths resolve
/// in milliseconds instead of tens of real seconds.
TableLoop _fastLoop(Room room) => TableLoop(
      room,
      turnTimeout: const Duration(seconds: 2),
      callTimeout: const Duration(milliseconds: 500),
      disconnectGrace: const Duration(milliseconds: 400),
      continueTimeout: const Duration(milliseconds: 500),
      botTurnPace: Duration.zero,
    );

Future<HttpServer> _startServer(RoomManager manager) async {
  final handler = const Pipeline()
      .addHandler(buildMultiplayerHandler(manager, tableLoopFactory: _fastLoop));
  return shelf_io.serve(handler, '127.0.0.1', 0);
}

/// Buffers every message a socket receives (so a `waitFor` issued after the
/// message already arrived still finds it) and broadcasts them live for
/// concurrent waiters.
class TestClient {
  TestClient(this.channel) {
    _sub = channel.stream.listen((raw) {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      log.add(msg);
      if (!_controller.isClosed) _controller.add(msg);
    });
  }

  static Future<TestClient> connect(int port) async => TestClient(
      IOWebSocketChannel.connect(Uri.parse('ws://127.0.0.1:$port')));

  final WebSocketChannel channel;
  late final StreamSubscription<void> _sub;
  final List<Map<String, dynamic>> log = [];
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  void send(Map<String, dynamic> msg) => channel.sink.add(jsonEncode(msg));

  Future<Map<String, dynamic>> waitFor(
    bool Function(Map<String, dynamic>) test, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    for (final m in log) {
      if (test(m)) return m;
    }
    return _controller.stream.firstWhere(test).timeout(timeout);
  }

  Future<void> close() async {
    await _sub.cancel();
    await channel.sink.close();
  }
}

/// A minimal autoplay loop for a test client: discards whatever is legal,
/// takes a free win, and passes every call. Just enough to make real games
/// progress without needing real strategy.
StreamSubscription<void> _autoplay(TestClient client) {
  return client._controller.stream.listen((msg) {
    if (msg['type'] != 'state') return;
    final mySeat = msg['yourSeat'] as int;
    final round = buildRoundFromSnapshot(
        msg['round'] as Map<String, dynamic>, mySeat: mySeat);
    if (round.phase == RoundPhase.callOffer &&
        round.callOptions.any((o) => o.seat == 0)) {
      client.send({'type': 'action', 'kind': 'pass_call'});
      return;
    }
    if (round.turn != 0 || round.phase != RoundPhase.discarding) return;
    if (round.canFlowerWin(0)) {
      client.send({'type': 'action', 'kind': 'pass_flower_win'});
      return;
    }
    if (round.canTsumo(0)) {
      client.send({'type': 'action', 'kind': 'tsumo'});
      return;
    }
    final tile = round.legalDiscards(0).first;
    client.send({
      'type': 'action',
      'kind': 'discard',
      'tileId': tile.id,
      'riichi': false,
    });
  });
}

void main() {
  test('two humans + two bots play a full hand with no hand leakage, then continue',
      () async {
    final manager = RoomManager();
    final server = await _startServer(manager);
    addTearDown(server.close);

    final a = await TestClient.connect(server.port);
    final b = await TestClient.connect(server.port);
    addTearDown(a.close);
    addTearDown(b.close);

    a.send({
      'type': 'create_room',
      'guestId': 'guest-a',
      'name': 'Alice',
      'ruleset': 'riichi',
      'hanchan': false,
    });
    final created = await a.waitFor((m) => m['type'] == 'room_state');
    final code = created['code'] as String;

    b.send({
      'type': 'join_room',
      'roomCode': code,
      'guestId': 'guest-b',
      'name': 'Bob',
    });
    await b.waitFor((m) => m['type'] == 'room_state' && m['yourSeat'] == 1);
    await a.waitFor((m) =>
        m['type'] == 'room_state' &&
        (m['seats'] as List).where((s) => s['connected'] == true).length == 2);

    a.send({'type': 'start_game'});
    await a.waitFor((m) =>
        m['type'] == 'room_state' && m['phase'] == 'playing');

    final aSub = _autoplay(a);
    final bSub = _autoplay(b);
    addTearDown(aSub.cancel);
    addTearDown(bSub.cancel);

    // Every `state` broadcast to A must never carry B's (or a bot's) real
    // hand — the central redaction-leak check.
    final leakCheck = a._controller.stream.listen((msg) {
      if (msg['type'] != 'state' && msg['type'] != 'round_result') return;
      final reveal = msg['type'] == 'round_result';
      final mySeat = msg['yourSeat'] as int;
      for (final sj in (msg['round'] as Map<String, dynamic>)['seats'] as List) {
        final seatMap = sj as Map<String, dynamic>;
        final seat = seatMap['seat'] as int;
        final shouldBeRevealed = reveal || seat == mySeat;
        expect(seatMap['handRevealed'], shouldBeRevealed,
            reason: 'seat $seat handRevealed wrong for viewer $mySeat');
        expect(seatMap.containsKey('hand'), shouldBeRevealed,
            reason: 'seat $seat leaked/withheld its hand for viewer $mySeat');
      }
    });
    addTearDown(leakCheck.cancel);

    final result = await a.waitFor((m) => m['type'] == 'round_result',
        timeout: const Duration(seconds: 20));

    // Round end reveals every seat's real hand to everyone.
    for (final sj in (result['round'] as Map<String, dynamic>)['seats'] as List) {
      expect((sj as Map<String, dynamic>)['handRevealed'], isTrue);
    }
    expect(result['round']['result'], isNotNull);

    if (result['gamePhase'] == 'roundEnd') {
      a.send({'type': 'continue_round'});
      final next = await a.waitFor(
          (m) => m['type'] == 'state' || m['type'] == 'room_state',
          timeout: const Duration(seconds: 5));
      expect(next, isNotNull);
    }
  });

  test('a disconnected seat converts to bot control after the grace period',
      () async {
    final manager = RoomManager();
    final server = await _startServer(manager);
    addTearDown(server.close);

    final a = await TestClient.connect(server.port);
    final b = await TestClient.connect(server.port);
    addTearDown(a.close);

    a.send({
      'type': 'create_room',
      'guestId': 'guest-a',
      'name': 'Alice',
      'ruleset': 'riichi',
      'hanchan': false,
    });
    final created = await a.waitFor((m) => m['type'] == 'room_state');
    final code = created['code'] as String;

    b.send({
      'type': 'join_room',
      'roomCode': code,
      'guestId': 'guest-b',
      'name': 'Bob',
    });
    await a.waitFor((m) =>
        m['type'] == 'room_state' &&
        (m['seats'] as List).where((s) => s['connected'] == true).length == 2);

    a.send({'type': 'start_game'});
    await a.waitFor((m) => m['type'] == 'room_state' && m['phase'] == 'playing');
    // `start_game` randomizes seats, so Bob's own post-start broadcast (never
    // his pre-start join order) says which one is actually his.
    final bobsSeat = (await b.waitFor(
        (m) => m['type'] == 'room_state' && m['phase'] == 'playing'))['yourSeat'] as int;

    final aSub = _autoplay(a);
    addTearDown(aSub.cancel);

    await b.close(); // Bob's seat drops without leaving cleanly

    final takeover = await a.waitFor((m) => m['type'] == 'bot_takeover',
        timeout: const Duration(seconds: 5));
    expect(takeover['seat'], bobsSeat);

    // The table keeps playing afterwards instead of stalling on that seat.
    final progressed = await a.waitFor(
        (m) => m['type'] == 'state' || m['type'] == 'round_result',
        timeout: const Duration(seconds: 10));
    expect(progressed, isNotNull);
  });

  for (final character in [
    'eric',
    'erika',
    'melissa',
    'matityahu',
    'sherman',
    'saeko',
  ]) {
    test(
        'a guest requesting already-taken $character is assigned a '
        'different one, reported in room_state', () async {
      // Regression test for a bug where the client kept showing "you are
      // ${requested}" after `Room.resolveCharacter` silently substituted a
      // different persona on a collision (see `OnlineGameController
      // .myCharacter`) — the mismatch this covers is server-side: whatever a
      // colliding guest is assigned must actually be what `room_state` reports
      // for their own seat, since the client now trusts that value verbatim.
      final manager = RoomManager();
      final server = await _startServer(manager);
      addTearDown(server.close);

      final a = await TestClient.connect(server.port);
      final b = await TestClient.connect(server.port);
      addTearDown(a.close);
      addTearDown(b.close);

      a.send({
        'type': 'create_room',
        'guestId': 'guest-a',
        'name': 'Alice',
        'character': character,
        'ruleset': 'riichi',
        'hanchan': false,
      });
      final created = await a.waitFor((m) => m['type'] == 'room_state');
      final code = created['code'] as String;
      expect(
        (created['seats'] as List).firstWhere((s) => s['seat'] == 0)['character'],
        character,
        reason: 'first request in an empty room is never contested',
      );

      b.send({
        'type': 'join_room',
        'roomCode': code,
        'guestId': 'guest-b',
        'name': 'Bob',
        'character': character, // already taken by seat 0
      });
      final joined =
          await b.waitFor((m) => m['type'] == 'room_state' && m['yourSeat'] == 1);
      final bCharacter =
          (joined['seats'] as List).firstWhere((s) => s['seat'] == 1)['character']
              as String;

      expect(bCharacter, isNot(character),
          reason: 'seat 0 already has it — resolveCharacter must not hand out '
              'the same persona twice');
      expect(bCharacter, isNotEmpty);
    });
  }
}
