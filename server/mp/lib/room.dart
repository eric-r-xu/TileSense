/// Room/lobby model: private room codes, guest seats, host-starts-game,
/// bot fill-in for empty seats. One [Room] owns at most one [TableLoop] for
/// its whole life — a room never plays a second game.
library;

import 'dart:math';

import 'package:mahjong_core/mahjong_core.dart';

import 'table_loop.dart';

/// Room codes avoid 0/O/1/I so a spoken or handwritten code is unambiguous.
const _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

enum RoomPhase { lobby, playing, ended }

/// One connected (or disconnected-but-not-yet-bot) player.
class Seat {
  Seat({required this.guestId, required this.name, required this.character});

  String guestId;
  String name;
  bool isBot = false;

  /// Which of [Room.allCharacters] this seat renders as — the same avatar
  /// and display name on every client. See [Room.resolveCharacter].
  String character;

  /// Set while a live WebSocket is attached to this seat; null when
  /// disconnected (whether or not it has been converted to a bot yet).
  void Function(Map<String, dynamic> message)? send;

  bool get connected => send != null;
}

class Room {
  Room({
    required this.code,
    required this.ruleset,
    required this.hanchan,
    this.timerSeconds = defaultTimerSeconds,
    this.minimumFaan = HongKongRules.defaultMinimumFaan,
  });

  /// The per-action clock (a turn's discard, or an offered call) a room may
  /// pick from when it is created; see [normalizeTimerSeconds].
  static const int defaultTimerSeconds = 30;
  static const List<int> timerChoices = [30, 60];

  /// Anything other than a listed choice falls back to the default, so a
  /// missing or hand-edited value can never produce a zero or huge clock.
  static int normalizeTimerSeconds(Object? v) =>
      v is int && timerChoices.contains(v) ? v : defaultTimerSeconds;

  final String code;
  final Ruleset ruleset;
  final bool hanchan;

  /// Seconds each human gets per discard and per call offer.
  final int timerSeconds;

  /// Hong Kong only: the fewest faan a hand needs to win, picked by the host.
  final int minimumFaan;
  RoomPhase phase = RoomPhase.lobby;
  int hostSeat = 0;
  final List<Seat?> seats = List<Seat?>.filled(4, null);
  TableLoop? loop;

  /// Called when the room has no game in progress and no seat is connected —
  /// the manager uses this to garbage-collect abandoned rooms.
  void Function()? onIdleEmpty;

  /// The player-selectable personas (see the client's `Character` enum
  /// in `lib/game/sfx.dart`, which this list's spelling must match).
  /// [resolveCharacter]'s fallback already guarantees a bot-filled seat gets
  /// whatever's unclaimed in [allCharacters], so nothing needs holding back
  /// from human selection for that.
  static const List<String> selectableCharacters = [
    'eric',
    'orderic',
    'astaroth',
    'grant',
    'hubert',
    'erika',
    'melissa',
    'matityahu',
    'sherman',
    'saeko',
  ];
  static const List<String> allCharacters = selectableCharacters;

  static const Map<String, String> characterName = {
    'eric': 'Eric',
    'orderic': 'Orderic',
    'astaroth': 'Astaroth',
    'grant': 'Grant',
    'hubert': 'Hubert',
    'erika': 'Erika',
    'melissa': 'Melissa',
    'matityahu': 'Matityahu',
    'sherman': 'Sherman',
    'saeko': 'Saeko',
  };

  /// Picks the character a new seat renders as: [requested] if it's one of
  /// the selectable personas and nobody else at this table already has
  /// it, otherwise the first unclaimed character in the same pool
  /// — always available, since a room seats at most four. Keeps every
  /// client's avatar/name for a given seat identical and collision-free
  /// without a round trip: whoever asks first gets first pick.
  String resolveCharacter([String? requested]) {
    final used = {
      for (final s in seats)
        if (s != null) s.character
    };
    if (requested != null &&
        selectableCharacters.contains(requested) &&
        !used.contains(requested)) {
      return requested;
    }
    for (final c in allCharacters) {
      if (!used.contains(c)) return c;
    }
    return allCharacters.first; // unreachable: 6 characters, at most 4 seats
  }

  int? seatIndexForGuest(String guestId) {
    for (var i = 0; i < 4; i++) {
      if (seats[i]?.guestId == guestId) return i;
    }
    return null;
  }

  int? firstOpenSeat() {
    for (var i = 0; i < 4; i++) {
      if (seats[i] == null) return i;
    }
    return null;
  }

  bool get isFull => firstOpenSeat() == null;

  bool get anyConnected => seats.any((s) => s?.connected ?? false);

  void broadcastRoomState() {
    for (var i = 0; i < 4; i++) {
      final seat = seats[i];
      if (seat?.send == null) continue;
      seat!.send!(roomStateJson(yourSeat: i));
    }
  }

  Map<String, dynamic> roomStateJson({int? yourSeat}) => {
        'type': 'room_state',
        'code': code,
        'ruleset': ruleset.name,
        'hanchan': hanchan,
        'timerSeconds': timerSeconds,
        'minimumFaan': minimumFaan,
        'phase': phase.name,
        if (yourSeat != null) 'yourSeat': yourSeat,
        'seats': [
          for (var i = 0; i < 4; i++)
            {
              'seat': i,
              'name': seats[i]?.name,
              'character': seats[i]?.character,
              'isBot': seats[i]?.isBot ?? false,
              'isHost': i == hostSeat,
              'connected': seats[i]?.connected ?? false,
            }
        ],
      };

  void sendError(int seat, String message) {
    seats[seat]?.send?.call({'type': 'error', 'message': message});
  }
}

class RoomManager {
  final Map<String, Room> _rooms = {};
  final Random _rng = Random.secure();

  Room? find(String code) => _rooms[code.toUpperCase()];

  Room createRoom({
    required String hostGuestId,
    required String hostName,
    required Ruleset ruleset,
    required bool hanchan,
    int timerSeconds = Room.defaultTimerSeconds,
    int minimumFaan = HongKongRules.defaultMinimumFaan,
    String? hostCharacter,
  }) {
    final code = _freshCode();
    final room = Room(
        code: code,
        ruleset: ruleset,
        hanchan: hanchan,
        timerSeconds: Room.normalizeTimerSeconds(timerSeconds),
        minimumFaan: HongKongRules.normalizeMinimumFaan(minimumFaan));
    room.seats[0] = Seat(
      guestId: hostGuestId,
      name: hostName,
      character: room.resolveCharacter(hostCharacter),
    );
    room.onIdleEmpty = () => _rooms.remove(code);
    _rooms[code] = room;
    return room;
  }

  String _freshCode() {
    String code;
    do {
      code = String.fromCharCodes(List.generate(6,
          (_) => _codeAlphabet.codeUnitAt(_rng.nextInt(_codeAlphabet.length))));
    } while (_rooms.containsKey(code));
    return code;
  }

  /// Removes a room once it has no game in progress and nobody connected —
  /// called after a lobby-phase leave/disconnect empties the last seat.
  void collectIfAbandoned(Room room) {
    if (room.phase == RoomPhase.lobby && !room.anyConnected) {
      _rooms.remove(room.code);
    }
  }

  /// Flushes every in-progress room's buffered telemetry — called once, on
  /// process shutdown, so a deploy's `systemctl restart` never strands up
  /// to 15s of already-recorded rounds/discards that were only sitting in
  /// memory. A no-op per room with no game running yet, or telemetry off.
  Future<void> flushAllTelemetry() => Future.wait([
        for (final room in _rooms.values)
          if (room.loop != null) room.loop!.flushTelemetry(),
      ]);
}
