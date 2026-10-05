import 'package:mahjong_core/mahjong_core.dart';
import 'package:test/test.dart';
import 'package:tilesense_mp/room.dart';
import 'package:tilesense_mp/table_loop.dart';

/// Multiplayer riichi seats Saeko among the bots, and — as in single player
/// — she plays Mortal's moves when the server has Mortal, falling back to
/// SimpleBot whenever Mortal's answer can't be played.
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

  test('a player already Saeko keeps her; the bots are three others', () {
    final room = roomWith('saeko');
    TableLoop(room, botTurnPace: Duration.zero).start();
    final bots = [
      for (final s in room.seats)
        if (s!.isBot) s.character
    ];
    expect(bots.toSet(), hasLength(3));
    expect(bots, isNot(contains('saeko')));
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
      mortal: (seat, events) async {
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
}
