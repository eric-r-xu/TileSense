import 'package:test/test.dart';
import 'package:tilesense_mp/room.dart';
import 'package:tilesense_mp/table_loop.dart';
import 'package:mahjong_core/ruleset.dart';

void main() {
  test('discard clocks are 15, 30 or 60; anything else falls back to 30', () {
    for (final ok in [15, 30, 60]) {
      expect(Room.normalizeDiscardSeconds(ok), ok);
    }
    for (final bad in [null, 0, 10, 45, 3600, -1, '60', 60.0]) {
      expect(Room.normalizeDiscardSeconds(bad), 30, reason: '$bad');
    }
  });

  test('call clocks are 5, 10 or 20; anything else falls back to 10', () {
    for (final ok in [5, 10, 20]) {
      expect(Room.normalizeCallSeconds(ok), ok);
    }
    for (final bad in [null, 0, 15, 30, 3600, -1, '10', 10.0]) {
      expect(Room.normalizeCallSeconds(bad), 10, reason: '$bad');
    }
  });

  test('a room defaults to 30s/10s and reports both clocks in room_state', () {
    final def = Room(code: 'AAAA', ruleset: Ruleset.riichi, hanchan: true);
    expect(def.discardSeconds, 30);
    expect(def.callSeconds, 10);
    final json = Room(
            code: 'BBBB',
            ruleset: Ruleset.riichi,
            hanchan: true,
            discardSeconds: 60,
            callSeconds: 20)
        .roomStateJson();
    expect(json['discardSeconds'], 60);
    expect(json['callSeconds'], 20);
    // Older clients label the room from this.
    expect(json['timerSeconds'], 60);
    expect(json.containsKey('callBufferSeconds'), isFalse);
  });

  test('RoomManager normalizes the clocks it is given', () {
    final manager = RoomManager();
    final fast = manager.createRoom(
        hostGuestId: 'g',
        hostName: 'Host',
        ruleset: Ruleset.riichi,
        hanchan: true,
        discardSeconds: 15,
        callSeconds: 5);
    expect((fast.discardSeconds, fast.callSeconds), (15, 5));
    final bad = manager.createRoom(
        hostGuestId: 'h',
        hostName: 'Host',
        ruleset: Ruleset.riichi,
        hanchan: true,
        discardSeconds: 45,
        callSeconds: 15);
    expect((bad.discardSeconds, bad.callSeconds), (30, 10),
        reason: 'out-of-range falls back to the defaults');
  });

  test('the table loop constructs with any pace', () {
    for (final (discard, call) in [(15, 5), (30, 10), (60, 20)]) {
      final room = Room(
          code: 'CCCC',
          ruleset: Ruleset.riichi,
          hanchan: true,
          discardSeconds: discard,
          callSeconds: call);
      expect(() => TableLoop(room), returnsNormally);
    }
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
