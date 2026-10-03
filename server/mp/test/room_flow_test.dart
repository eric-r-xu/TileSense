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
      abandonGrace: const Duration(milliseconds: 600),
      continueTimeout: const Duration(milliseconds: 500),
      botTurnPace: Duration.zero,
      continueLock: Duration.zero,
      callDiscardHold: Duration.zero,
      afterCallPace: Duration.zero,
    );

Future<HttpServer> _startServer(RoomManager manager,
    {TableLoop Function(Room room) loop = _fastLoop}) async {
  final handler = const Pipeline()
      .addHandler(buildMultiplayerHandler(manager, tableLoopFactory: loop));
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
/// takes a free win, and passes every call — or, without [answerCalls],
/// leaves every call offer to run out. Just enough to make real games
/// progress without needing real strategy.
StreamSubscription<void> _autoplay(TestClient client,
    {bool answerCalls = true}) {
  return client._controller.stream.listen((msg) {
    if (msg['type'] != 'state') return;
    final mySeat = msg['yourSeat'] as int;
    final round = buildRoundFromSnapshot(
        msg['round'] as Map<String, dynamic>, mySeat: mySeat);
    if (round.phase == RoundPhase.callOffer &&
        round.callOptions.any((o) => o.seat == 0)) {
      if (answerCalls) client.send({'type': 'action', 'kind': 'pass_call'});
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
  taiwaneseRoomMain();
  mcrRoomMain();
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
    'matthew',
    'smurf',
    'ricky',
    'finley',
    'adri',
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

  Map<String, dynamic> createMsg(String guestId) => {
        'type': 'create_room',
        'guestId': guestId,
        'name': guestId,
        'ruleset': 'riichi',
        'hanchan': false,
      };

  /// Polls until [done] holds — for server-side effects no socket is told of.
  Future<void> eventually(bool Function() done) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!done()) {
      if (DateTime.now().isAfter(deadline)) fail('condition never held');
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  test('creating a second room on one socket frees the first', () async {
    final manager = RoomManager();
    final server = await _startServer(manager);
    addTearDown(server.close);
    final a = await TestClient.connect(server.port);
    addTearDown(a.close);

    a.send(createMsg('guest-a'));
    final first = (await a.waitFor((m) => m['type'] == 'room_state'))['code'];
    a.send(createMsg('guest-a'));
    await a.waitFor((m) => m['type'] == 'room_state' && m['code'] != first);

    expect(manager.find(first as String), isNull);
    expect(manager.roomCount, 1);
  });

  test('re-joining your own lobby keeps the room registered', () async {
    final manager = RoomManager();
    final server = await _startServer(manager);
    addTearDown(server.close);
    final a = await TestClient.connect(server.port);
    addTearDown(a.close);

    a.send(createMsg('guest-a'));
    final code =
        (await a.waitFor((m) => m['type'] == 'room_state'))['code'] as String;
    a.log.clear();
    a.send({'type': 'join_room', 'roomCode': code, 'guestId': 'guest-a'});
    await a.waitFor((m) => m['type'] == 'room_state');

    expect(manager.find(code), isNotNull);
  });

  test('a game whose only human leaves is ended and freed', () async {
    final manager = RoomManager();
    final server = await _startServer(manager);
    addTearDown(server.close);
    final a = await TestClient.connect(server.port);

    a.send(createMsg('guest-a'));
    final code =
        (await a.waitFor((m) => m['type'] == 'room_state'))['code'] as String;
    a.send({'type': 'start_game'});
    await a.waitFor((m) => m['type'] == 'room_state' && m['phase'] == 'playing');
    final room = manager.find(code)!;

    await a.close();
    await eventually(() => manager.find(code) == null);
    expect(room.phase, RoomPhase.ended);
  });

  /// Creates a room for [guestId] alone and starts it (three bots fill in).
  Future<(TestClient, String)> startSolo(int port, String guestId) async {
    final a = await TestClient.connect(port);
    a.send(createMsg(guestId));
    final code =
        (await a.waitFor((m) => m['type'] == 'room_state'))['code'] as String;
    a.send({'type': 'start_game'});
    await a.waitFor((m) => m['type'] == 'room_state' && m['phase'] == 'playing');
    return (a, code);
  }

  test("an older client's turn timer and calls buffer become the two clocks",
      () async {
    final manager = RoomManager();
    final server = await _startServer(manager);
    addTearDown(server.close);
    final a = await TestClient.connect(server.port);
    addTearDown(a.close);
    a.send({
      ...createMsg('guest-a'),
      'timerSeconds': 60,
      'callBufferSeconds': 20,
    });
    final state = await a.waitFor((m) => m['type'] == 'room_state');
    expect(state['discardSeconds'], 60);
    expect(state['callSeconds'], 20);
  });

  test('a call offer left to run out is passed, with no strike', () async {
    final manager = RoomManager();
    final server = await _startServer(manager,
        loop: (room) => TableLoop(
              room,
              turnTimeout: const Duration(seconds: 2),
              callTimeout: const Duration(milliseconds: 150),
              continueTimeout: const Duration(milliseconds: 100),
              botTurnPace: Duration.zero,
              continueLock: Duration.zero,
              callDiscardHold: Duration.zero,
              afterCallPace: Duration.zero,
            ));
    addTearDown(server.close);
    final a = await TestClient.connect(server.port);
    addTearDown(a.close);
    // Hong Kong: chow and pung offers come often, and a bot deciding them
    // (the old timeout behaviour) would take one as soon as it helps.
    a.send({...createMsg('guest-a'), 'ruleset': 'hongKong', 'hanchan': true});
    await a.waitFor((m) => m['type'] == 'room_state');
    a.send({'type': 'start_game'});
    final sub = _autoplay(a, answerCalls: false);
    addTearDown(sub.cancel);

    final offered = <int>{};
    final done = Completer<void>();
    final watch = a._controller.stream.listen((m) {
      if (m['type'] == 'round_result') {
        a.send({'type': 'continue_round'});
        return;
      }
      if (m['type'] != 'state') return;
      final round = buildRoundFromSnapshot(m['round'] as Map<String, dynamic>,
          mySeat: m['yourSeat'] as int);
      expect(round.seats[0].melds, isEmpty,
          reason: 'nobody may call for a seat that let its offers run out');
      if (round.phase == RoundPhase.callOffer &&
          round.callOptions.any((o) => o.seat == 0)) {
        offered.add(m['discardSerial'] as int);
        if (offered.length >= 6 && !done.isCompleted) done.complete();
      }
    });
    addTearDown(watch.cancel);
    await done.future.timeout(const Duration(seconds: 60));
    expect(a.log.where((m) => m['type'] == 'bot_takeover'), isEmpty,
        reason: 'expired call offers are not strikes');
  }, timeout: const Timeout(Duration(seconds: 90)));

  test(
    'a call window looks like the next turn to everyone without an offer',
    () async {
      final manager = RoomManager();
      final server = await _startServer(
        manager,
        loop: (room) => TableLoop(
          room,
          turnTimeout: const Duration(seconds: 30),
          callTimeout: const Duration(seconds: 5),
          botTurnPace: Duration.zero,
          callDiscardHold: Duration.zero,
          afterCallPace: Duration.zero,
        ),
      );
      addTearDown(server.close);
      // Control all four seats: random deals and bot calls need not produce
      // two unclaimed windows followed by a human turn, even in a full game.
      final clients = <TestClient>[];
      for (var i = 0; i < 4; i++) {
        final client = await TestClient.connect(server.port);
        clients.add(client);
        addTearDown(client.close);
      }
      clients.first.send({
        ...createMsg('guest-0'),
        'ruleset': 'hongKong',
        'hanchan': true,
      });
      final code = (await clients.first.waitFor(
        (m) => m['type'] == 'room_state',
      ))['code'] as String;
      for (var i = 1; i < clients.length; i++) {
        clients[i].send({
          'type': 'join_room',
          'roomCode': code,
          'guestId': 'guest-$i',
        });
        await clients[i].waitFor((m) => m['type'] == 'room_state');
      }
      clients.first.send({'type': 'start_game'});
      final bySeat = <int, TestClient>{};
      for (final client in clients) {
        final state = await client.waitFor((m) => m['type'] == 'state');
        bySeat[state['yourSeat'] as int] = client;
      }
      final loop = manager.find(code)!.loop!;
      // Keep the seat the loop is already waiting on, with a reproducible wall.
      final round = loop.round = Round(
        seed: 0,
        dealer: loop.round.turn,
        roundWind: Wind.east,
        startingPoints: List.filled(4, Ruleset.hongKong.startingPoints),
        ruleset: Ruleset.hongKong,
      );
      var tileId = 1000;
      for (var serial = 1; serial <= 2; serial++) {
        final discarder = round.turn;
        final next = (discarder + 1) % 4;
        final caller = (discarder + 2) % 4;
        // Scattered hands cannot win on East. Only the caller has its pair,
        // guaranteeing a pon offer that leaves the next player waiting to draw.
        for (final seat in round.seats) {
          seat.hand = [
            for (final type in [
              TileType.man1,
              TileType.man3,
              TileType.man5,
              TileType.man7,
              TileType.man9,
              TileType.pin1,
              TileType.pin3,
              TileType.pin5,
              TileType.pin7,
              TileType.pin9,
              TileType.sou1,
              seat.seat == caller ? TileType.ton : TileType.sou3,
              seat.seat == caller ? TileType.ton : TileType.sou5,
            ])
              Tile(tileId++, type),
          ];
          seat.drawn = null;
        }
        final tile = Tile(tileId++, TileType.ton);
        round.seats[discarder].hand.add(tile);
        round.seats[discarder].drawn = tile;
        bySeat[discarder]!.send({
          'type': 'action',
          'kind': 'discard',
          'tileId': tile.id,
        });

        final deadlines = <int, int>{};
        for (var seat = 0; seat < 4; seat++) {
          final state = await bySeat[seat]!.waitFor(
            (m) =>
                m['type'] == 'state' &&
                m['discardSerial'] == serial &&
                m['turnDeadlineMs'] != null,
          );
          final snapshot = state['round'] as Map<String, dynamic>;
          final options = (snapshot['callOptions'] as List).cast<Map>();
          expect(
            options.every((o) => o['seat'] == seat),
            isTrue,
            reason: 'seat $seat was shown another seat\'s call offer',
          );
          deadlines[seat] = state['turnDeadlineMs'] as int;
          if (seat == caller) {
            expect(snapshot['phase'], 'callOffer');
            expect(options, hasLength(1));
            expect(options.single['types'], contains('pon'));
          } else {
            expect(options, isEmpty);
            expect(snapshot['phase'], seat == next ? 'drawing' : 'discarding');
            expect(snapshot['turn'], next);
            expect(snapshot['pendingDiscard'], isNull);
            expect(snapshot['pendingDiscardSeat'], isNull);
          }
        }
        for (var seat = 0; seat < 4; seat++) {
          if (seat != caller) expect(deadlines[seat], deadlines[next]);
        }
        expect(deadlines[caller], lessThan(deadlines[next]!));

        bySeat[caller]!.send({'type': 'action', 'kind': 'pass_call'});
        final drawn = await bySeat[next]!.waitFor(
          (m) =>
              m['type'] == 'state' &&
              m['discardSerial'] == serial &&
              m['round']['phase'] == 'discarding' &&
              m['round']['turn'] == next,
        );
        expect(
          drawn['turnDeadlineMs'],
          deadlines[next],
          reason: 'an unclaimed window must carry its clock into the next turn',
        );
        expect(round.turn, next);
        expect(round.phase, RoundPhase.discarding);
      }
    },
  );

  test('every error carries a code a client can translate, and its message',
      () async {
    final manager = RoomManager();
    final server = await _startServer(manager);
    addTearDown(server.close);
    final a = await TestClient.connect(server.port);
    addTearDown(a.close);
    a.send({'type': 'join_room', 'roomCode': 'ZZZZ', 'guestId': 'guest-a'});
    final notFound = await a.waitFor((m) => m['type'] == 'error');
    expect(notFound['code'], 'room_not_found');
    expect(notFound['message'], 'room not found');
    a.log.clear();
    a.channel.sink.add('not json');
    final malformed = await a.waitFor((m) => m['type'] == 'error');
    expect(malformed['code'], 'malformed');
    expect(malformed['message'], isNotEmpty);
  });

  test('a player a bot took over for gets their seat back on reconnect',
      () async {
    final manager = RoomManager();
    final server = await _startServer(manager);
    addTearDown(server.close);
    final (a, code) = await startSolo(server.port, 'guest-a');
    final room = manager.find(code)!;
    final seat = room.seatIndexForGuest('guest-a')!;

    await a.close();
    await eventually(() => room.loop!.isBotControlled(seat));

    final back = await TestClient.connect(server.port);
    addTearDown(back.close);
    back.send({'type': 'reconnect', 'roomCode': code, 'guestId': 'guest-a'});
    final state = await back.waitFor((m) => m['type'] == 'room_state');
    expect(state['yourSeat'], seat);
    expect((state['seats'] as List)[seat]['isBot'], isFalse);
    await back.waitFor((m) => m['type'] == 'state' && m['yourSeat'] == seat);
    expect(room.loop!.isBotControlled(seat), isFalse);

    // Back in time: the all-bot abandon timer no longer ends the game.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    expect(manager.find(code), isNotNull);
    expect(room.phase, RoomPhase.playing);
  });

  test('joining your own started game by its code takes you back to your seat',
      () async {
    final manager = RoomManager();
    final server = await _startServer(manager);
    addTearDown(server.close);
    final (a, code) = await startSolo(server.port, 'guest-a');
    final seat = manager.find(code)!.seatIndexForGuest('guest-a');
    await a.close();

    final back = await TestClient.connect(server.port);
    addTearDown(back.close);
    back.send({'type': 'join_room', 'roomCode': code, 'guestId': 'guest-a'});
    final state = await back.waitFor((m) => m['type'] == 'room_state');
    expect(state['phase'], 'playing');
    expect(state['yourSeat'], seat);
    await back.waitFor((m) => m['type'] == 'state');

    // Someone else still can't join a game under way.
    final other = await TestClient.connect(server.port);
    addTearDown(other.close);
    other.send({'type': 'join_room', 'roomCode': code, 'guestId': 'guest-z'});
    final err = await other.waitFor((m) => m['type'] == 'error');
    expect(err['message'], 'that room has already started');
    expect(err['code'], 'room_started');
  });

  test("a bot's own seat can't be claimed with its bot guest id", () async {
    final manager = RoomManager();
    final server = await _startServer(manager);
    addTearDown(server.close);
    final (a, code) = await startSolo(server.port, 'guest-a');
    addTearDown(a.close);
    final room = manager.find(code)!;
    final bot = room.seats.indexWhere((s) => s!.filledByBot);
    final botId = room.seats[bot]!.guestId;

    final thief = await TestClient.connect(server.port);
    addTearDown(thief.close);
    thief.send({'type': 'room_status', 'roomCode': code, 'guestId': botId});
    final status = await thief.waitFor((m) => m['type'] == 'room_status');
    expect(status['rejoinable'], isFalse);
    thief.send({'type': 'reconnect', 'roomCode': code, 'guestId': botId});
    final err = await thief.waitFor((m) => m['type'] == 'error');
    expect(err['message'], 'this seat is bot-controlled');
    expect(err['code'], 'seat_bot_controlled');
    expect(room.seats[bot]!.isBot, isTrue);
    expect(room.seats[bot]!.connected, isFalse);
  });

  test('room_status says whether a guest can rejoin', () async {
    final manager = RoomManager();
    final server = await _startServer(manager);
    addTearDown(server.close);
    final (a, code) = await startSolo(server.port, 'guest-a');
    addTearDown(a.close);

    final probe = await TestClient.connect(server.port);
    addTearDown(probe.close);
    Future<bool> ask(String roomCode, String guestId) async {
      probe.log.clear();
      probe.send(
          {'type': 'room_status', 'roomCode': roomCode, 'guestId': guestId});
      final m = await probe.waitFor((m) => m['type'] == 'room_status');
      return m['rejoinable'] as bool;
    }

    expect(await ask(code, 'guest-a'), isTrue);
    expect(await ask(code, 'guest-z'), isFalse);
    expect(await ask('NOPE', 'guest-a'), isFalse);
    // Asking attaches nothing: the probe socket holds no seat.
    expect(manager.find(code)!.seats.where((s) => s!.connected).length, 1);
  });

  test("Continue is held until the score lock is up, and pressing twice is fine",
      () async {
    const lock = Duration(milliseconds: 800);
    final manager = RoomManager();
    final server = await _startServer(manager,
        loop: (room) => TableLoop(
              room,
              turnTimeout: const Duration(seconds: 2),
              callTimeout: const Duration(milliseconds: 500),
              continueTimeout: const Duration(seconds: 30),
              botTurnPace: Duration.zero,
              continueLock: lock,
            ));
    addTearDown(server.close);
    final (a, _) = await startSolo(server.port, 'guest-a');
    addTearDown(a.close);
    final sub = _autoplay(a);
    addTearDown(sub.cancel);

    final result = await a.waitFor((m) => m['type'] == 'round_result',
        timeout: const Duration(seconds: 20));
    if (result['gamePhase'] != 'roundEnd') return; // the game ended outright
    await sub.cancel(); // no more turns to play until the next hand
    final shownAt = DateTime.now();
    a.log.clear();
    a.send({'type': 'continue_round'});
    a.send({'type': 'continue_round'});

    await a.waitFor((m) => m['type'] == 'state',
        timeout: const Duration(seconds: 10));
    // A win also waits out the clients' reveal; a draw only the lock.
    expect(DateTime.now().difference(shownAt),
        greaterThanOrEqualTo(lock - const Duration(milliseconds: 50)));
    // A second Continue used to complete an already-completed Completer,
    // which threw and came back as "bad request".
    expect(
        a.log.where(
            (m) => m['type'] == 'error' && m['message'] == 'bad request'),
        isEmpty);
  });

  test("a bot's call holds the taken discard, then waits out its bubble",
      () async {
    const hold = Duration(milliseconds: 300);
    const afterCall = Duration(milliseconds: 400);
    final manager = RoomManager();
    final server = await _startServer(manager,
        loop: (room) => TableLoop(
              room,
              turnTimeout: const Duration(seconds: 2),
              callTimeout: const Duration(milliseconds: 500),
              continueTimeout: const Duration(milliseconds: 100),
              continueLock: Duration.zero,
              botTurnPace: const Duration(milliseconds: 20),
              callDiscardHold: hold,
              afterCallPace: afterCall,
            ));
    addTearDown(server.close);
    final a = await TestClient.connect(server.port);
    addTearDown(a.close);
    // Hong Kong: bots pon and chow freely, so calls come quickly.
    a.send({...createMsg('guest-a'), 'ruleset': 'hongKong', 'hanchan': true});
    await a.waitFor((m) => m['type'] == 'room_state');
    a.send({'type': 'start_game'});
    final sub = _autoplay(a);
    addTearDown(sub.cancel);

    // Each measured bot call: how long the taken tile had been on the table,
    // and how long the caller's bubble had before its next discard.
    final measured = <({int held, int after})>[];
    final sw = Stopwatch()..start();
    final done = Completer<void>();
    List<int>? melds, ponds;
    int? serial;
    var discardAt = 0;
    ({int seat, int at, int held})? call;
    final watch = a._controller.stream.listen((m) {
      if (m['type'] == 'round_result') {
        melds = null;
        serial = null;
        call = null;
        a.send({'type': 'continue_round'});
        return;
      }
      if (m['type'] != 'state') return;
      final t = sw.elapsedMilliseconds;
      final seats =
          ((m['round'] as Map)['seats'] as List).cast<Map<String, dynamic>>();
      final nowMelds = [for (final s in seats) (s['melds'] as List).length];
      final nowPonds = [for (final s in seats) (s['pond'] as List).length];
      final nowSerial = m['discardSerial'] as int;
      if (serial != null && nowSerial > serial!) {
        final c = call;
        if (c != null && m['lastDiscardSeat'] == c.seat) {
          measured.add((held: c.held, after: t - c.at));
          call = null;
          if (measured.length >= 3 && !done.isCompleted) done.complete();
        }
        discardAt = t;
      }
      if (melds != null) {
        for (var s = 0; s < 4; s++) {
          // A call: a new meld, its own pond unchanged (a kan from the hand
          // on its own turn is left out — it took no discard).
          if (s != m['yourSeat'] &&
              nowMelds[s] > melds![s] &&
              nowPonds[s] == ponds![s] &&
              nowSerial == serial) {
            call = (seat: s, at: t, held: t - discardAt);
          }
        }
      }
      melds = nowMelds;
      ponds = nowPonds;
      serial = nowSerial;
    });
    addTearDown(watch.cancel);

    await done.future.timeout(const Duration(seconds: 60));
    const slack = 40; // timer and socket jitter on a loaded machine
    for (final c in measured) {
      expect(c.held, greaterThanOrEqualTo(hold.inMilliseconds - slack),
          reason: 'the called tile should be seen landing first');
      expect(c.after, greaterThanOrEqualTo(afterCall.inMilliseconds - slack),
          reason: "the caller's next discard waits out its bubble");
    }
  });

  test('an oversized message closes the socket', () async {
    final manager = RoomManager();
    final server = await _startServer(manager);
    addTearDown(server.close);
    final a = await TestClient.connect(server.port);
    addTearDown(a.close);

    a.channel.sink.add('x' * 5000);
    await a.channel.sink.done.timeout(const Duration(seconds: 5));
    expect(a.channel.closeCode, isNotNull);
  });

  test('room creation is refused once the server is full', () async {
    final manager = RoomManager();
    for (var i = 0; i < 200; i++) {
      manager.createRoom(
          hostGuestId: 'filler-$i',
          hostName: 'Filler',
          ruleset: Ruleset.riichi,
          hanchan: false);
    }
    final server = await _startServer(manager);
    addTearDown(server.close);
    final a = await TestClient.connect(server.port);
    addTearDown(a.close);

    a.send(createMsg('guest-a'));
    final error = await a.waitFor((m) => m['type'] == 'error');
    expect(error['message'], contains('server is full'));
    expect(error['code'], 'server_full');
    expect(manager.roomCount, 200);
  });
}

/// A Taiwanese room must deal Taiwanese hands: 16 tiles a seat, 17 for the
/// seat on turn, both over the wire and in the client's rebuilt [Round].
void taiwaneseRoomMain() {
  test('a Taiwanese room deals 16-tile hands (17 on turn) to every seat',
      () async {
    final manager = RoomManager();
    final server = await _startServer(manager);
    addTearDown(server.close);

    final a = await TestClient.connect(server.port);
    addTearDown(a.close);
    a.send({
      'type': 'create_room',
      'guestId': 'guest-a',
      'name': 'Alice',
      'ruleset': 'taiwanese',
      'hanchan': false,
    });
    final created = await a.waitFor((m) => m['type'] == 'room_state');
    expect(created['ruleset'], 'taiwanese');

    a.send({'type': 'start_game'});
    final state = await a.waitFor((m) => m['type'] == 'state',
        timeout: const Duration(seconds: 10));
    final roundJson = state['round'] as Map<String, dynamic>;
    expect(roundJson['ruleset'], 'taiwanese');

    final mySeat = state['yourSeat'] as int;
    final round = buildRoundFromSnapshot(roundJson, mySeat: mySeat);
    expect(round.ruleset, Ruleset.taiwanese);
    for (final s in round.seats) {
      final size = s.hand.length + s.melds.length * 3;
      expect(size, s.seat == round.turn ? 17 : 16,
          reason: 'seat ${s.seat} (turn ${round.turn})');
    }
  });
}

/// MCR (Mahjong Competition Rules) rooms.
void mcrRoomMain() {
  test('MCR rooms need a client that lists MCR support; other rooms do not',
      () async {
    final manager = RoomManager();
    final server = await _startServer(manager);
    addTearDown(server.close);
    final current = await TestClient.connect(server.port);
    final old = await TestClient.connect(server.port);
    addTearDown(current.close);
    addTearDown(old.close);
    const supported = ['riichi', 'hongKong', 'taiwanese', 'mcr'];

    old.send({
      'type': 'create_room',
      'guestId': 'guest-old',
      'name': 'Old',
      'ruleset': 'mcr',
    });
    final refused = await old.waitFor((m) => m['type'] == 'error');
    expect(refused['code'], 'update_required');

    current.send({
      'type': 'create_room',
      'guestId': 'guest-new',
      'name': 'New',
      'ruleset': 'mcr',
      'supportedRulesets': supported,
    });
    final created = await current.waitFor((m) => m['type'] == 'room_state');
    final code = created['code'] as String;
    expect(manager.find(code)?.ruleset, Ruleset.mcr);

    old.log.clear();
    old.send({
      'type': 'join_room',
      'roomCode': code,
      'guestId': 'guest-old',
      'name': 'Old',
    });
    final joinRefused = await old.waitFor((m) => m['type'] == 'error');
    expect(joinRefused['code'], 'update_required');
    expect(manager.find(code)!.seatIndexForGuest('guest-old'), isNull);

    // The same old client still creates a riichi room as before.
    old.log.clear();
    old.send({
      'type': 'create_room',
      'guestId': 'guest-old',
      'name': 'Old',
      'ruleset': 'riichi',
    });
    expect((await old.waitFor((m) => m['type'] == 'room_state'))['code'],
        isNot(code));
  });

  test('an MCR table plays a hand to its result', () async {
    final manager = RoomManager();
    final server = await _startServer(manager);
    addTearDown(server.close);
    final a = await TestClient.connect(server.port);
    addTearDown(a.close);
    a.send({
      'type': 'create_room',
      'guestId': 'guest-a',
      'name': 'Alice',
      'ruleset': 'mcr',
      'hanchan': false,
      'supportedRulesets': ['riichi', 'hongKong', 'taiwanese', 'mcr'],
    });
    await a.waitFor((m) => m['type'] == 'room_state');
    a.send({'type': 'start_game'});
    final sub = _autoplay(a);
    addTearDown(sub.cancel);
    final result = await a.waitFor((m) => m['type'] == 'round_result',
        timeout: const Duration(seconds: 30));
    final deltas =
        (result['round']['result']['pointDeltas'] as Map).values.cast<int>();
    expect(deltas.fold<int>(0, (x, y) => x + y), 0);
  });
}
