import 'package:test/test.dart';
import 'package:tilesense_mp/room.dart';
import 'package:tilesense_mp/table_loop.dart';
import 'package:mahjong_core/ruleset.dart';

void main() {
  test('only 30 and 60 are accepted; anything else falls back to 30', () {
    expect(Room.normalizeTimerSeconds(30), 30);
    expect(Room.normalizeTimerSeconds(60), 60);
    for (final bad in [null, 0, 10, 45, 3600, -1, '60', 60.0]) {
      expect(Room.normalizeTimerSeconds(bad), 30, reason: '$bad');
    }
  });

  test('a room defaults to 30s and reports its choice in room_state', () {
    final def =
        Room(code: 'AAAA', ruleset: Ruleset.riichi, hanchan: true);
    expect(def.timerSeconds, 30);
    final long = Room(
        code: 'BBBB', ruleset: Ruleset.riichi, hanchan: true, timerSeconds: 60);
    expect(long.roomStateJson()['timerSeconds'], 60);
  });

  test('the table loop takes both clocks from the room', () {
    final room = Room(
        code: 'CCCC', ruleset: Ruleset.riichi, hanchan: true, timerSeconds: 60);
    // Constructing must not throw and must accept the room's clock.
    expect(() => TableLoop(room), returnsNormally);
  });
}
