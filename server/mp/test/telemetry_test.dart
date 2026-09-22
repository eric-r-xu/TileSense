import 'dart:convert';

import 'package:mahjong_core/mahjong_core.dart';
import 'package:test/test.dart';
import 'package:tilesense_mp/room.dart';
import 'package:tilesense_mp/table_loop.dart';
import 'package:tilesense_mp/telemetry.dart';

/// Multiplayer session telemetry: [MpTelemetry] itself (batching, gating on
/// `INGEST_URL`, the shape of each event type), and [TableLoop] actually
/// calling it at the right moments during a real, directly-driven game —
/// the same style [Room]/[TableLoop] construction `seat_shuffle_test.dart`
/// uses, rather than the full WebSocket harness `room_flow_test.dart` needs,
/// since nothing here cares about the network layer.
void main() {
  group('MpTelemetry', () {
    test('maybe() is null unless INGEST_URL is set — off by default', () {
      expect(
        MpTelemetry.maybe(hostGuestId: 'g', hostSessionId: 's', env: const {}),
        isNull,
      );
      expect(
        MpTelemetry.maybe(
            hostGuestId: 'g',
            hostSessionId: 's',
            env: const {'INGEST_URL': ''}),
        isNull,
      );
      expect(
        MpTelemetry.maybe(
            hostGuestId: 'g',
            hostSessionId: 's',
            env: const {'INGEST_URL': 'http://example.invalid/ingest'}),
        isNotNull,
      );
    });

    test('flush() posts one batch, under the host identity, then clears it',
        () async {
      final posts = <(String, String)>[];
      final tel = MpTelemetry.maybe(
        hostGuestId: 'host-guest',
        hostSessionId: 'host-session',
        env: const {'INGEST_URL': 'http://example.invalid/ingest'},
        post: (url, body) async => posts.add((url, body)),
      )!;
      addTearDown(tel.dispose);

      tel.roundStart(
        matchId: 'm1',
        roundId: 'r1',
        roundIndex: 0,
        roundWind: 'east',
        handNumber: 1,
        dealerSeat: 0,
        honba: 0,
        riichiSticks: 0,
      );
      await tel.flush();

      expect(posts, hasLength(1));
      final (url, body) = posts.single;
      expect(url, 'http://example.invalid/ingest');
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      expect(decoded['client_id'], 'host-guest');
      expect(decoded['session_id'], 'host-session');
      final events = decoded['events'] as List;
      expect(events, hasLength(1));
      expect(events.single['type'], 'round_start');
      expect(events.single['match_id'], 'm1');

      // The batch was cleared — a second flush with nothing new sends nothing.
      await tel.flush();
      expect(posts, hasLength(1));
    });

    test('matchStart carries mode, room code and every seat array', () async {
      final posts = <(String, String)>[];
      final tel = MpTelemetry.maybe(
        hostGuestId: 'host',
        hostSessionId: 'hs',
        env: const {'INGEST_URL': 'http://x.invalid/ingest'},
        post: (url, body) async => posts.add((url, body)),
      )!;
      addTearDown(tel.dispose);

      tel.matchStart(
        matchId: 'm',
        roomCode: 'ABCD12',
        ruleset: 'riichi',
        hanchan: true,
        timerSeconds: 30,
        seatCharacters: const ['eric', 'grant', null, null],
        seatIsBot: const [false, false, true, true],
        seatGuestIds: const ['g0', 'g1', null, null],
        participants: const [
          {'seat': '0', 'sessionId': 's0', 'guestId': 'g0'},
          {'seat': '1', 'sessionId': 's1', 'guestId': 'g1'},
        ],
      );
      await tel.flush();

      final event = (jsonDecode(posts.single.$2)
          as Map<String, dynamic>)['events'][0] as Map<String, dynamic>;
      expect(event['mode'], 'multiplayer');
      expect(event['room_code'], 'ABCD12');
      expect(event['timer_seconds'], 30);
      expect(event['seat_is_bot'], [false, false, true, true]);
      expect(event['seat_guest_ids'], ['g0', 'g1', null, null]);
      expect(event['participants'], hasLength(2));
    });

    test('events buffer until 25, then flush without waiting for the timer',
        () async {
      var posts = 0;
      final tel = MpTelemetry.maybe(
        hostGuestId: 'host',
        hostSessionId: 'hs',
        env: const {'INGEST_URL': 'http://x.invalid/ingest'},
        post: (url, body) async => posts++,
      )!;
      addTearDown(tel.dispose);

      for (var i = 0; i < 25; i++) {
        tel.seatEvent(
            matchId: 'm', actorSeat: 0, event: 'reconnected', guestId: 'g');
      }
      // The 25th call triggers an unawaited flush; give it a turn to run.
      await Future<void>.delayed(Duration.zero);
      expect(posts, 1);
    });
  });

  group('TableLoop wired to MpTelemetry', () {
    Room roomWith(List<String> guestIds) {
      final room = Room(code: 'GAME01', ruleset: Ruleset.riichi, hanchan: true);
      for (var i = 0; i < guestIds.length; i++) {
        room.seats[i] = Seat(
          guestId: guestIds[i],
          name: guestIds[i],
          character: room.resolveCharacter(),
        );
      }
      return room;
    }

    test(
        'starting a game posts match_start (with participants) and '
        'round_start', () async {
      final events = <Map<String, dynamic>>[];
      final room = roomWith(['alice', 'bob', 'carol', 'dave']);
      final tel = MpTelemetry.maybe(
        hostGuestId: 'alice',
        hostSessionId: 'alice-session',
        env: const {'INGEST_URL': 'http://x.invalid/ingest'},
        post: (url, body) async {
          final batch = jsonDecode(body) as Map<String, dynamic>;
          events.addAll((batch['events'] as List).cast<Map<String, dynamic>>());
        },
      )!;
      addTearDown(tel.dispose);

      TableLoop(room, botTurnPace: Duration.zero, telemetry: tel).start();
      await tel.flush();

      final start = events.singleWhere((e) => e['type'] == 'match_start');
      expect(start['mode'], 'multiplayer');
      expect(start['room_code'], 'GAME01');
      final participants =
          (start['participants'] as List).cast<Map<String, dynamic>>();
      expect(participants.map((p) => p['guestId']).toSet(),
          {'alice', 'bob', 'carol', 'dave'});
      // The host's own participant session must match the batch's own
      // envelope identity (see `match_participants` in the schema).
      expect(
        participants.singleWhere((p) => p['guestId'] == 'alice')['sessionId'],
        'alice-session',
      );

      final roundStart = events.singleWhere((e) => e['type'] == 'round_start');
      expect(roundStart['match_id'], start['match_id']);
      expect(roundStart['round_index'], 0);
    });

    test('a human discard is reported with the real actor seat', () async {
      final events = <Map<String, dynamic>>[];
      final room = roomWith(['alice', 'bob', 'carol', 'dave']);
      final tel = MpTelemetry.maybe(
        hostGuestId: 'alice',
        hostSessionId: 'alice-session',
        env: const {'INGEST_URL': 'http://x.invalid/ingest'},
        post: (url, body) async {
          final batch = jsonDecode(body) as Map<String, dynamic>;
          events.addAll((batch['events'] as List).cast<Map<String, dynamic>>());
        },
      )!;
      addTearDown(tel.dispose);

      final loop = TableLoop(room, botTurnPace: Duration.zero, telemetry: tel);
      loop.start();
      // Let `_run()` reach the point where it is awaiting the seat on turn —
      // everything up to that await is synchronous, so one empty turn of
      // the event loop is enough.
      await Future<void>.delayed(Duration.zero);

      final seat = loop.round.turn;
      final tile = loop.round.legalDiscards(seat).first;
      loop.handleMessage(seat, {
        'type': 'action',
        'kind': 'discard',
        'tileId': tile.id,
        'riichi': false,
      });
      await Future<void>.delayed(Duration.zero);
      await tel.flush();

      final decision = events.singleWhere((e) => e['type'] == 'human_decision');
      expect(decision['actor_seat'], seat);
      expect(decision['kind'], 'discard');
      expect(decision['tile'], tile.code);
      expect(decision['auto'], false);
    });

    test('a bot-converted-while-pending seat reports no human_decision at all',
        () async {
      // Three humans, one bot from the start: the bot's own turns are never
      // reported — only genuine human choices are, matching single-player,
      // which never reports its bots' decisions either.
      final events = <Map<String, dynamic>>[];
      final room = roomWith(['alice', 'bob', 'carol']); // seat 3 stays a bot
      final tel = MpTelemetry.maybe(
        hostGuestId: 'alice',
        hostSessionId: 'alice-session',
        env: const {'INGEST_URL': 'http://x.invalid/ingest'},
        post: (url, body) async {
          final batch = jsonDecode(body) as Map<String, dynamic>;
          events.addAll((batch['events'] as List).cast<Map<String, dynamic>>());
        },
      )!;
      addTearDown(tel.dispose);

      TableLoop(room, botTurnPace: Duration.zero, telemetry: tel).start();
      await tel.flush();

      final start = events.singleWhere((e) => e['type'] == 'match_start');
      // Only the three humans are participants — the bot seat is excluded.
      expect((start['participants'] as List).length, 3);
      expect((start['seat_is_bot'] as List).where((b) => b == true).length, 1);
    });
  });
}
