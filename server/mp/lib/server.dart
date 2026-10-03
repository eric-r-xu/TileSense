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

/// Real client messages are a few hundred bytes; anything far larger is abuse.
const _maxMessageLength = 4096;

/// A backstop on live rooms so no flood of them can exhaust the process's
/// memory cap (see deploy/tilesense-mp.service).
const _maxRooms = 200;

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

    /// Releases this connection's seat: a lobby seat is freed, a seat in a
    /// running game starts its reconnect grace period.
    void detach() {
      final r = room;
      final s = currentSeat();
      room = null;
      guestId = null;
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
    }

    /// Attaches this connection to [seat] of a game already under way —
    /// after a dropped socket, or a player coming back after leaving. A seat
    /// a bot has taken over in the meantime is handed back, but only to the
    /// human who held it (see [Seat.reclaimableBy]).
    void rejoin(Room r, String requestedGuestId) {
      final s = r.seatIndexForGuest(requestedGuestId);
      if (s == null) {
        send(errorFrame('not_seated', 'you are not seated in this room'));
        return;
      }
      if (r.loop?.isBotControlled(s) ?? false) {
        if (!r.seats[s]!.reclaimableBy(requestedGuestId)) {
          send(errorFrame('seat_bot_controlled', 'this seat is bot-controlled'));
          return;
        }
        r.loop!.reclaimSeat(s);
      }
      if (room != null && room != r) detach();
      room = r;
      guestId = requestedGuestId;
      r.seats[s]!.send = send;
      r.broadcastRoomState();
      r.loop?.handleReconnect(s);
    }

    bool supportsMcr(Map<String, dynamic> msg) {
      final supported = msg['supportedRulesets'];
      if (supported is List && supported.length <= 16 && supported.contains('mcr')) return true;
      send(errorFrame('update_required', 'Update TileSense to play MCR.'));
      return false;
    }

    void handle(Map<String, dynamic> msg) {
      final type = msg['type'] as String?;
      switch (type) {
        case 'create_room':
          final requestedGuestId = msg['guestId'] as String?;
          if (requestedGuestId == null || requestedGuestId.isEmpty) {
            send(errorFrame('missing_guest_id', 'missing guestId'));
            return;
          }
          if (manager.roomCount >= _maxRooms) {
            send(errorFrame('server_full', 'server is full, try again shortly'));
            return;
          }
          // One connection holds at most one seat, so a socket can't pile up
          // rooms by creating or joining repeatedly.
          if (room != null) detach();
          final ruleset = msg['ruleset'] == 'mcr' ? Ruleset.mcr : msg['ruleset'] == 'hongKong'
              ? Ruleset.hongKong
              : msg['ruleset'] == 'taiwanese'
                  ? Ruleset.taiwanese
                  : Ruleset.riichi;
          if (ruleset.isMcr && !supportsMcr(msg)) return;
          final hanchan = msg['hanchan'] as bool? ?? true;
          final r = manager.createRoom(
            hostGuestId: requestedGuestId,
            hostName: _sanitizeName(msg['name']),
            ruleset: ruleset,
            hanchan: hanchan,
            // Clients from before the separate call clock send their turn
            // timer and "calls buffer" instead; both are valid choices here.
            discardSeconds: Room.normalizeDiscardSeconds(
                msg['discardSeconds'] ?? msg['timerSeconds']),
            callSeconds: Room.normalizeCallSeconds(
                msg['callSeconds'] ?? msg['callBufferSeconds']),
            minimumFaan: HongKongRules.normalizeMinimumFaan(msg['minimumFaan']),
            minimumPoints:
                TaiwaneseRules.normalizeMinimumPoints(msg['minimumPoints']),
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
            send(errorFrame('missing_room_or_guest', 'missing roomCode or guestId'));
            return;
          }
          final r = manager.find(code);
          if (r == null) {
            send(errorFrame('room_not_found', 'room not found'));
            return;
          }
          if (r.ruleset.isMcr && !supportsMcr(msg)) return;
          if (r.phase == RoomPhase.playing &&
              r.seatIndexForGuest(requestedGuestId) != null) {
            // Your own game, still going: the code (or a shared link) takes
            // you back to your seat.
            rejoin(r, requestedGuestId);
            return;
          }
          if (r.phase != RoomPhase.lobby) {
            send(errorFrame('room_started', 'that room has already started'));
            return;
          }
          if (room != null && room != r) detach();
          final existing = r.seatIndexForGuest(requestedGuestId);
          final openSeat = existing ?? r.firstOpenSeat();
          if (openSeat == null) {
            send(errorFrame('room_full', 'room is full'));
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
            send(errorFrame('not_host', 'only the host can start the game'));
            return;
          }
          r.loop = tableLoopFactory(r)..start();

        case 'reconnect':
          final code = msg['roomCode'] as String?;
          final requestedGuestId = msg['guestId'] as String?;
          if (code == null || requestedGuestId == null) {
            send(errorFrame('missing_room_or_guest', 'missing roomCode or guestId'));
            return;
          }
          final r = manager.find(code);
          if (r == null || r.phase == RoomPhase.ended) {
            send(errorFrame('room_gone', 'room no longer exists'));
            return;
          }
          if (r.ruleset.isMcr && !supportsMcr(msg)) return;
          rejoin(r, requestedGuestId);

        case 'room_status':
          // Read-only: can this guest rejoin that game? Lets the client offer
          // "Rejoin" only while there is something to rejoin. Attaches nothing.
          final code = msg['roomCode'] as String?;
          final requestedGuestId = msg['guestId'] as String?;
          if (code == null || requestedGuestId == null) {
            send(errorFrame('missing_room_or_guest', 'missing roomCode or guestId'));
            return;
          }
          final r = manager.find(code);
          final s = r?.seatIndexForGuest(requestedGuestId);
          send({
            'type': 'room_status',
            'roomCode': code,
            'rejoinable': r != null &&
                r.phase == RoomPhase.playing &&
                s != null &&
                r.seats[s]!.reclaimableBy(requestedGuestId),
          });

        case 'action':
        case 'continue_round':
          final r = room;
          final s = currentSeat();
          if (r == null || s == null) return;
          r.loop?.handleMessage(s, msg);

        default:
          send(errorFrame('unknown_type', 'unknown message type: $type'));
      }
    }

    webSocket.stream.listen(
      (raw) {
        if (raw is! String || raw.length > _maxMessageLength) {
          webSocket.sink.close();
          return;
        }
        Map<String, dynamic> msg;
        try {
          msg = jsonDecode(raw) as Map<String, dynamic>;
        } catch (_) {
          send(errorFrame('malformed', 'malformed message'));
          return;
        }
        try {
          handle(msg);
        } catch (e) {
          send(errorFrame('bad_request', 'bad request'));
        }
      },
      onDone: detach,
    );
  });
}
