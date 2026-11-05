import 'package:mahjong_core/mahjong_core.dart';
import 'package:test/test.dart';
import 'package:tilesense_mp/mortal.dart';
import 'package:tilesense_mp/room.dart';
import 'package:tilesense_mp/table_loop.dart';

/// A bot Nagomi plays the fine-tuned model from her own sidecar in four-player
/// riichi (hanchan or East only), falls back to Saeko's Mortal and then to
/// SimpleBot, and stays on SimpleBot in sanma. Saeko keeps the server's Mortal.
void main() {
  /// A room with a human and a bot Nagomi; [TableLoop.start]
  /// seats Saeko (the first bot it fills) and one more bot.
  Room roomWithNagomi(
      {Ruleset ruleset = Ruleset.riichi, bool hanchan = false}) {
    final room = Room(code: 'NAGOMI', ruleset: ruleset, hanchan: hanchan);
    room.seats[0] = Seat(
        guestId: 'alice',
        name: 'alice',
        character: room.resolveCharacter('eric'));
    room.seats[1] = Seat(guestId: 'bot-1', name: 'Nagomi', character: 'nagomi')
      ..isBot = true
      ..filledByBot = true;
    return room;
  }

  /// Plays the tile Mortal's seat just drew, passes every call.
  Future<Map<String, Object?>> tsumogiri(
      int seat, List<MjaiEvent> events) async {
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
  }

  TableLoop loopFor(Room room, {MortalAsk? mortal, MortalAsk? nagomi}) =>
      TableLoop(
        room,
        botTurnPace: Duration.zero,
        afterCallPace: Duration.zero,
        callDiscardHold: Duration.zero,
        disconnectGrace: Duration.zero,
        abandonGrace: const Duration(milliseconds: 400),
        continueTimeout: Duration.zero,
        continueLock: Duration.zero,
        mortal: mortal,
        nagomiMortal: nagomi,
      );

  /// Starts the table and lets the hand play itself out with every seat a
  /// bot. [TableLoop.start] shuffles the occupied seats, so Nagomi's seat is
  /// only known afterwards; returns it.
  Future<int> playOut(TableLoop loop) async {
    loop.start();
    final room = loop.room;
    final nagomi = room.seats.indexWhere((s) => s?.character == 'nagomi');
    loop.handleDisconnect(room.seats.indexWhere((s) => s?.guestId == 'alice'));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return nagomi;
  }

  test('Nagomi asks her own Mortal; Saeko asks the server\'s', () async {
    final room = roomWithNagomi();
    final nagomiAsked = <int>{}, saekoAsked = <int>{};
    final loop = loopFor(room, mortal: (seat, events, {hanchan = true}) {
      saekoAsked.add(seat);
      return tsumogiri(seat, events);
    }, nagomi: (seat, events, {hanchan = true}) {
      nagomiAsked.add(seat);
      return tsumogiri(seat, events);
    });
    final nagomiSeat = await playOut(loop);
    final saekoSeat = room.seats.indexWhere((s) => s?.character == 'saeko');

    expect(nagomiAsked, {nagomiSeat});
    expect(saekoAsked, {saekoSeat});
  });

  test('the table is told whether it is a hanchan or East only', () async {
    for (final hanchan in [true, false]) {
      final room = roomWithNagomi(hanchan: hanchan);
      final told = <bool>{};
      final loop = loopFor(room, nagomi: (seat, events, {hanchan = true}) {
        told.add(hanchan);
        return tsumogiri(seat, events);
      });
      await playOut(loop);
      expect(told, {hanchan}, reason: 'hanchan: $hanchan');
    }
  });

  test('Nagomi falls back to Saeko\'s Mortal when her own fails', () async {
    final room = roomWithNagomi();
    final saekoServerAsked = <int>{};
    final loop = loopFor(room, mortal: (seat, events, {hanchan = true}) {
      saekoServerAsked.add(seat);
      return tsumogiri(seat, events);
    }, nagomi: (seat, events, {hanchan = true}) async {
      throw StateError('Nagomi sidecar down');
    });
    final nagomiSeat = await playOut(loop);

    expect(saekoServerAsked, contains(nagomiSeat),
        reason: 'Nagomi was answered by Saeko\'s Mortal');
  });

  test('Nagomi plays Saeko\'s Mortal when the server has no Nagomi sidecar',
      () async {
    final room = roomWithNagomi();
    final asked = <int>{};
    final loop = loopFor(room, mortal: (seat, events, {hanchan = true}) {
      asked.add(seat);
      return tsumogiri(seat, events);
    });
    final nagomiSeat = await playOut(loop);

    expect(asked, contains(nagomiSeat));
  });

  test('with both Mortals failing Nagomi still plays, on SimpleBot', () async {
    final room = roomWithNagomi();
    Future<Map<String, Object?>> down(int seat, List<MjaiEvent> events,
            {bool hanchan = true}) async =>
        throw StateError('down');
    final loop = loopFor(room, mortal: down, nagomi: down);
    final nagomiSeat = await playOut(loop);

    expect(loop.round.seats[nagomiSeat].allDiscards, isNotEmpty);
  });

  test('sanma: Nagomi has no model and never asks Mortal', () async {
    final room = roomWithNagomi(ruleset: Ruleset.sanma);
    var nagomiCalls = 0;
    final saekoAsked = <int>{};
    final loop = loopFor(room, mortal: (seat, events, {hanchan = true}) {
      saekoAsked.add(seat);
      return tsumogiri(seat, events);
    }, nagomi: (seat, events, {hanchan = true}) async {
      nagomiCalls++;
      return {'reaction': null};
    });
    final nagomiSeat = await playOut(loop);

    expect(nagomiCalls, 0);
    final nagomiMjaiSeat = Ruleset.sanma.activeSeats.indexOf(nagomiSeat);
    expect(saekoAsked, isNotEmpty);
    expect(saekoAsked, isNot(contains(nagomiMjaiSeat)));
  });

  test('MortalClient.maybe reads MORTAL_NAGOMI_URL only for Nagomi', () {
    const env = {'MORTAL_NAGOMI_URL': 'http://127.0.0.1:8792'};
    expect(MortalClient.maybe(nagomi: true, env: env), isNotNull);
    expect(MortalClient.maybe(env: env), isNull);
    expect(
        MortalClient.maybe(
            nagomi: true, env: {'MORTAL_URL': 'http://127.0.0.1:8790'}),
        isNull);
  });
}
