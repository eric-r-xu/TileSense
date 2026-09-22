/// The WebSocket connection layer: turns raw JSON messages into calls on
/// [RoomManager] / [Room] / [TableLoop]. One connection is at most one seat
/// in at most one room for its whole life — no spectators, no mid-game
/// joins.
library;

import 'dart:convert';

import 'package:mahjong_core/mahjong_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'room.dart';
import 'table_loop.dart';

const _maxNameLength = 24;

String _sanitizeName(Object? raw) {
  final s = (raw is String ? raw : '').trim();
  if (s.isEmpty) return 'Guest';
  return s.length > _maxNameLength ? s.substring(0, _maxNameLength) : s;
}

/// [tableLoopFactory] builds the [TableLoop] a room starts with; tests
/// override it to inject short timeouts (see [TableLoop]'s constructor).
Handler buildMultiplayerHandler(
  RoomManager manager, {
  TableLoop Function(Room room) tableLoopFactory = TableLoop.new,
}) {
  return webSocketHandler((WebSocketChannel webSocket) {
    Room? room;
    // The seat a connection occupies is looked up by guest ID on every use
    // rather than cached as an int at join time: `TableLoop.start` randomizes
    // seat assignment (see `_shuffleSeats`), which would otherwise strand an
    // already-connected socket on its pre-shuffle index.
    String? guestId;

    int? currentSeat() {
      final r = room;
      final g = guestId;
      return r == null || g == null ? null : r.seatIndexForGuest(g);
    }

    void send(Map<String, dynamic> message) {
      try {
        webSocket.sink.add(jsonEncode(message));
      } catch (_) {
        // Socket already closing; the onDone handler below will clean up.
      }
    }

    void handle(Map<String, dynamic> msg) {
      final type = msg['type'] as String?;
      switch (type) {
        case 'create_room':
          final requestedGuestId = msg['guestId'] as String?;
          if (requestedGuestId == null || requestedGuestId.isEmpty) {
            send({'type': 'error', 'message': 'missing guestId'});
            return;
          }
          final ruleset =
              msg['ruleset'] == 'hongKong' ? Ruleset.hongKong : Ruleset.riichi;
          final hanchan = msg['hanchan'] as bool? ?? true;
          final r = manager.createRoom(
            hostGuestId: requestedGuestId,
            hostName: _sanitizeName(msg['name']),
            ruleset: ruleset,
            hanchan: hanchan,
            timerSeconds: Room.normalizeTimerSeconds(msg['timerSeconds']),
            hostCharacter: msg['character'] as String?,
          );
          room = r;
          guestId = requestedGuestId;
          r.seats[0]!.send = send;
          r.broadcastRoomState();

        case 'join_room':
          final code = msg['roomCode'] as String?;
          final requestedGuestId = msg['guestId'] as String?;
          if (code == null || requestedGuestId == null) {
            send({'type': 'error', 'message': 'missing roomCode or guestId'});
            return;
          }
          final r = manager.find(code);
          if (r == null) {
            send({'type': 'error', 'message': 'room not found'});
            return;
          }
          if (r.phase != RoomPhase.lobby) {
            send({'type': 'error', 'message': 'that room has already started'});
            return;
          }
          final existing = r.seatIndexForGuest(requestedGuestId);
          final openSeat = existing ?? r.firstOpenSeat();
          if (openSeat == null) {
            send({'type': 'error', 'message': 'room is full'});
            return;
          }
          r.seats[openSeat] ??= Seat(
            guestId: requestedGuestId,
            name: _sanitizeName(msg['name']),
            character: r.resolveCharacter(msg['character'] as String?),
          );
          room = r;
          guestId = requestedGuestId;
          r.seats[openSeat]!.send = send;
          r.broadcastRoomState();

        case 'leave_room':
          final r = room;
          final s = currentSeat();
          if (r == null || s == null || r.phase != RoomPhase.lobby) return;
          r.seats[s] = null;
          if (s == r.hostSeat) {
            final next = r.seats.indexWhere((seat) => seat != null);
            if (next >= 0) r.hostSeat = next;
          }
          r.broadcastRoomState();
          manager.collectIfAbandoned(r);
          room = null;
          guestId = null;

        case 'start_game':
          final r = room;
          final s = currentSeat();
          if (r == null ||
              s == null ||
              s != r.hostSeat ||
              r.phase != RoomPhase.lobby) {
            send({
              'type': 'error',
              'message': 'only the host can start the game'
            });
            return;
          }
          r.loop = tableLoopFactory(r)..start();

        case 'reconnect':
          final code = msg['roomCode'] as String?;
          final requestedGuestId = msg['guestId'] as String?;
          if (code == null || requestedGuestId == null) {
            send({'type': 'error', 'message': 'missing roomCode or guestId'});
            return;
          }
          final r = manager.find(code);
          if (r == null) {
            send({'type': 'error', 'message': 'room no longer exists'});
            return;
          }
          final s = r.seatIndexForGuest(requestedGuestId);
          if (s == null) {
            send({
              'type': 'error',
              'message': 'you are not seated in this room'
            });
            return;
          }
          if (r.loop?.isBotControlled(s) ?? false) {
            send({
              'type': 'error',
              'message': 'this seat is now bot-controlled'
            });
            return;
          }
          room = r;
          guestId = requestedGuestId;
          r.seats[s]!.send = send;
          r.broadcastRoomState();
          r.loop?.handleReconnect(s);

        case 'action':
        case 'continue_round':
          final r = room;
          final s = currentSeat();
          if (r == null || s == null) return;
          r.loop?.handleMessage(s, msg);

        default:
          send({'type': 'error', 'message': 'unknown message type: $type'});
      }
    }

    webSocket.stream.listen(
      (raw) {
        Map<String, dynamic> msg;
        try {
          msg = jsonDecode(raw as String) as Map<String, dynamic>;
        } catch (_) {
          send({'type': 'error', 'message': 'malformed message'});
          return;
        }
        try {
          handle(msg);
        } catch (e) {
          send({'type': 'error', 'message': 'bad request'});
        }
      },
      onDone: () {
        final r = room;
        final s = currentSeat();
        if (r == null || s == null) return;
        r.seats[s]?.send = null;
        if (r.loop != null) {
          r.loop!.handleDisconnect(s);
        } else {
          r.seats[s] = null;
          if (s == r.hostSeat) {
            final next = r.seats.indexWhere((seat) => seat != null);
            if (next >= 0) r.hostSeat = next;
          }
          r.broadcastRoomState();
          manager.collectIfAbandoned(r);
        }
      },
    );
  });
}
