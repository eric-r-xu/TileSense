import 'package:mahjong_core/mahjong_core.dart';
import 'package:test/test.dart';
import 'package:tilesense_mp/room.dart';
import 'package:tilesense_mp/table_loop.dart';

/// Regression test for starting seats always matching join order (the room
/// creator was always East/dealt first, guests always dealt in join order).
/// `TableLoop.start` now randomizes who sits where before the first round —
/// this checks the two invariants that matter: every occupied guest keeps
/// their own seat *object* (so their character/name survive), just at a
/// possibly different index, and whoever was host before the shuffle is
/// still flagged as host afterward, wherever they landed.
void main() {
  Room roomWith(List<String> guestIds) {
    final room = Room(code: 'TEST01', ruleset: Ruleset.riichi, hanchan: false);
    for (var i = 0; i < guestIds.length; i++) {
      room.seats[i] = Seat(
        guestId: guestIds[i],
        name: guestIds[i],
        character: room.resolveCharacter(),
      );
    }
    return room;
  }

  test('every connected guest keeps their identity, just possibly reseated',
      () {
    final room = roomWith(['alice', 'bob', 'carol', 'dave']);
    TableLoop(room, botTurnPace: Duration.zero).start();

    expect(room.seats.map((s) => s!.guestId).toSet(),
        {'alice', 'bob', 'carol', 'dave'});
  });

  test('the host is still flagged as host after reseating, at their new index',
      () {
    // Alice created the room, so she started as hostSeat 0.
    final room = roomWith(['alice', 'bob', 'carol', 'dave']);
    TableLoop(room, botTurnPace: Duration.zero).start();

    final aliceSeat = room.seats.indexWhere((s) => s!.guestId == 'alice');
    expect(room.hostSeat, aliceSeat);
  });

  test('empty seats are still filled with bots after reseating', () {
    final room = roomWith(['alice', 'bob']); // seats 2 and 3 start empty
    TableLoop(room, botTurnPace: Duration.zero).start();

    expect(room.seats.every((s) => s != null), isTrue);
    expect(room.seats.where((s) => s!.isBot).length, 2);
    expect(room.seats.map((s) => s!.guestId).toSet().length, 4,
        reason: 'bots must not collide with a human or each other');
  });

  test('bots filling empty seats get distinct, unclaimed, random characters',
      () {
    final lineups = <String>{};
    for (var i = 0; i < 30; i++) {
      final room = roomWith(['alice']);
      final alices = room.seats[0]!.character;
      TableLoop(room, botTurnPace: Duration.zero).start();
      final bots = [
        for (final s in room.seats)
          if (s!.isBot) s.character
      ];
      expect(bots, hasLength(3));
      expect(bots.toSet(), hasLength(3), reason: 'no two bots share one');
      expect(bots, isNot(contains(alices)));
      expect(Room.allCharacters, containsAll(bots));
      lineups.add((bots..sort()).join(','));
    }
    expect(lineups.length, greaterThan(1),
        reason: 'not the same first-three characters every game');
  });
}
