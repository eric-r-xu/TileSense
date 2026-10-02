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
    final def = Room(code: 'AAAA', ruleset: Ruleset.riichi, hanchan: true);
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

  test('only 10 and 20 are accepted for the call buffer; else falls back to 10',
      () {
    expect(Room.normalizeCallBufferSeconds(10), 10);
    expect(Room.normalizeCallBufferSeconds(20), 20);
    for (final bad in [null, 0, 15, 3600, -1, '10', 10.0]) {
      expect(Room.normalizeCallBufferSeconds(bad), 10, reason: '$bad');
    }
  });

  test('a room defaults to a 10s call buffer and reports it in room_state',
      () {
    final def = Room(code: 'FFFF', ruleset: Ruleset.riichi, hanchan: true);
    expect(def.callBufferSeconds, 10);
    final long = Room(
        code: 'GGGG',
        ruleset: Ruleset.riichi,
        hanchan: true,
        callBufferSeconds: 20);
    expect(long.roomStateJson()['callBufferSeconds'], 20);
  });

  test('RoomManager normalizes the call buffer it is given', () {
    final manager = RoomManager();
    final room = manager.createRoom(
        hostGuestId: 'g',
        hostName: 'Host',
        ruleset: Ruleset.riichi,
        hanchan: true,
        callBufferSeconds: 20);
    expect(room.roomStateJson()['callBufferSeconds'], 20);
    final bad = manager.createRoom(
        hostGuestId: 'h',
        hostName: 'Host',
        ruleset: Ruleset.riichi,
        hanchan: true,
        callBufferSeconds: 15);
    expect(bad.callBufferSeconds, 10, reason: 'out-of-range falls back to 10');
  });

  test('the table loop still constructs with a non-default call buffer', () {
    final room = Room(
        code: 'HHHH',
        ruleset: Ruleset.riichi,
        hanchan: true,
        timerSeconds: 60,
        callBufferSeconds: 20);
    expect(() => TableLoop(room), returnsNormally);
  });

  test('a Hong Kong room carries its minimum faan to room_state', () {
    final def = Room(code: 'DDDD', ruleset: Ruleset.hongKong, hanchan: true);
    expect(def.roomStateJson()['minimumFaan'], 0);
    final manager = RoomManager();
    final room = manager.createRoom(
        hostGuestId: 'g',
        hostName: 'Host',
        ruleset: Ruleset.hongKong,
        hanchan: true,
        minimumFaan: 3);
    expect(room.roomStateJson()['minimumFaan'], 3);
    final bad = manager.createRoom(
        hostGuestId: 'h',
        hostName: 'Host',
        ruleset: Ruleset.hongKong,
        hanchan: true,
        minimumFaan: 9);
    expect(bad.minimumFaan, 0, reason: 'out-of-range falls back to 0');
  });

  test('a Taiwanese room carries its minimum tai to room_state', () {
    final def = Room(code: 'EEEE', ruleset: Ruleset.taiwanese, hanchan: true);
    expect(def.roomStateJson()['minimumPoints'], 5);
    final manager = RoomManager();
    final room = manager.createRoom(
        hostGuestId: 'g',
        hostName: 'Host',
        ruleset: Ruleset.taiwanese,
        hanchan: true,
        minimumPoints: 1);
    expect(room.roomStateJson()['minimumPoints'], 1);
    final bad = manager.createRoom(
        hostGuestId: 'h',
        hostName: 'Host',
        ruleset: Ruleset.taiwanese,
        hanchan: true,
        minimumPoints: 2);
    expect(bad.minimumPoints, 5, reason: 'not a choice: falls back to 5');
  });
}
