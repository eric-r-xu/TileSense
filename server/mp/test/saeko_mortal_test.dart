import 'package:mahjong_core/mahjong_core.dart';
import 'package:test/test.dart';
import 'package:tilesense_mp/room.dart';
import 'package:tilesense_mp/table_loop.dart';

/// Multiplayer riichi seats Saeko and Nagomi among the bots (Saeko alone in
/// sanma), and — as in single player — every bot plays Mortal's moves when
/// the server has Mortal, Saeko on the 298k, falling back to SimpleBot
/// whenever Mortal's answer can't be played.
void main() {
  Room roomWith(String character, {Ruleset ruleset = Ruleset.riichi}) {
    final room = Room(code: 'SAEKO1', ruleset: ruleset, hanchan: false);
    room.seats[0] = Seat(
        guestId: 'alice',
        name: 'alice',
        character: room.resolveCharacter(character));
    return room;
  }

  test('a riichi room with open seats always seats a bot Saeko', () {
    for (var i = 0; i < 20; i++) {
      final room = roomWith('eric');
      TableLoop(room, botTurnPace: Duration.zero).start();
      final saeko = room.seats.where((s) => s!.character == 'saeko');
      expect(saeko, hasLength(1));
      expect(saeko.single!.isBot, isTrue);
    }
  });

  test('a riichi room with open seats always seats a bot Nagomi too', () {
    for (var i = 0; i < 20; i++) {
      final room = roomWith('eric');
      TableLoop(room, botTurnPace: Duration.zero).start();
      final nagomi = room.seats.where((s) => s!.character == 'nagomi');
      expect(nagomi, hasLength(1));
      expect(nagomi.single!.isBot, isTrue);
    }
  });

  test(
      'a player already Saeko keeps her; the bots are three others, '
      'starting with Nagomi', () {
    final room = roomWith('saeko');
    TableLoop(room, botTurnPace: Duration.zero).start();
    final bots = [
      for (final s in room.seats)
        if (s!.isBot) s.character
    ];
    expect(bots.toSet(), hasLength(3));
    expect(bots, isNot(contains('saeko')));
    expect(bots, contains('nagomi'));
  });

  test('a player already Nagomi keeps her; Saeko is still a bot', () {
    final room = roomWith('nagomi');
    TableLoop(room, botTurnPace: Duration.zero).start();
    final bots = [
      for (final s in room.seats)
        if (s!.isBot) s.character
    ];
    expect(bots, contains('saeko'));
    expect(bots, isNot(contains('nagomi')));
  });

  test('a sanma room with open seats always seats a bot Saeko', () {
    for (var i = 0; i < 20; i++) {
      final room = roomWith('eric', ruleset: Ruleset.sanma);
      TableLoop(room, botTurnPace: Duration.zero).start();
      final characters = [
        for (final s in room.seats)
          if (s != null) s.character
      ];
      expect(characters, contains('saeko'));
    }
  });

  test('bot Saeko discards what Mortal names, seeing only her own view',
      () async {
    final room = roomWith('eric');
    final named = <String>[];
    var calls = 0;
    late int saekoSeat;
    final loop = TableLoop(
      room,
      botTurnPace: Duration.zero,
      afterCallPace: Duration.zero,
      callDiscardHold: Duration.zero,
      disconnectGrace: Duration.zero,
      abandonGrace: const Duration(milliseconds: 400),
      continueTimeout: Duration.zero,
      continueLock: Duration.zero,
      // The other bots play Nagomi's model, so they never ask this one.
      nagomiMortal: (seat, events, {hanchan = true}) async {
        final last = events.last;
        if (last['type'] == 'tsumo' && last['actor'] == seat) {
          return {
            'reaction': {
              'type': 'dahai',
              'actor': seat,
              'pai': last['pai'],
              'tsumogiri': true,
            }
          };
        }
        return {'reaction': null};
      },
      mortal: (seat, events, {hanchan = true}) async {
        calls++;
        expect(seat, saekoSeat);
        final view = mjaiView(events, seat);
        final tehais = view[1]['tehais'] as List;
        for (var i = 0; i < 4; i++) {
          expect((tehais[i] as List).contains('?'), i != seat);
        }
        final last = events.last;
        if (last['type'] == 'tsumo' && last['actor'] == seat) {
          named.add(last['pai'] as String);
          return {
            'reaction': {
              'type': 'dahai',
              'actor': seat,
              'pai': last['pai'],
              'tsumogiri': true,
            }
          };
        }
        return {'reaction': null}; // pass any call
      },
    );
    loop.start();
    saekoSeat = room.seats.indexWhere((s) => s!.character == 'saeko');
    loop.handleDisconnect(0); // every seat a bot, so the hand plays itself
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(calls, greaterThan(0));
    // Whatever hand is on the table now: every Saeko discard in it was a
    // tile Mortal named.
    final pond = loop.round.seats[saekoSeat].allDiscards.map(mjaiTile);
    expect(named, containsAll(pond));
  });

  test('sanma: every bot asks with mjai seats 0-2 and sets Norths aside',
      () async {
    final room = roomWith('eric', ruleset: Ruleset.sanma);
    final seats = <int>{};
    var kitas = 0;
    final loop = TableLoop(
      room,
      botTurnPace: Duration.zero,
      afterCallPace: Duration.zero,
      callDiscardHold: Duration.zero,
      disconnectGrace: Duration.zero,
      abandonGrace: const Duration(milliseconds: 400),
      continueTimeout: Duration.zero,
      continueLock: Duration.zero,
      mortal: (seat, events, {hanchan = true}) async {
        seats.add(seat);
        final view = mjaiView(events, seat);
        expect(view[1]['tehais'], hasLength(3));
        final last = events.last;
        if (last['type'] == 'tsumo' && last['actor'] == seat) {
          if (last['pai'] == 'N') {
            kitas++;
            return {
              'reaction': {'type': 'nukidora', 'actor': seat, 'pai': 'N'}
            };
          }
          return {
            'reaction': {
              'type': 'dahai',
              'actor': seat,
              'pai': last['pai'],
              'tsumogiri': true,
            }
          };
        }
        return {'reaction': null};
      },
    );
    loop.start();
    final botSeats = [
      for (var i = 0; i < 4; i++)
        if (room.seats[i]?.isBot ?? false) i
    ];
    expect(botSeats, hasLength(2));
    loop.handleDisconnect(0);
    await Future<void>.delayed(const Duration(milliseconds: 300));

    // Both bots, Saeko and the other, play the sanma Mortal.
    expect(seats,
        {for (final b in botSeats) Ruleset.sanma.activeSeats.indexOf(b)});
    // Every North a bot drew went aside, none into its pond.
    for (final b in botSeats) {
      expect(
          loop.round.seats[b].allDiscards.where((t) => t.type == TileType.pei),
          isEmpty,
          reason: '$kitas kitas asked');
    }
  });
}
