import 'dart:convert';

import 'package:mahjong_core/mahjong_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  test('the Gold indicator and a Gold discard cross the wire to every viewer',
      () {
    final round = fixture(gold: Tile(-1, type('5s')), draws: tiles('2m 3m'));
    round.seats[2].goldDiscarded = true;
    for (var viewer = 0; viewer < 4; viewer++) {
      final wire = jsonDecode(jsonEncode(
              roundSnapshotToJson(round, reveal: (s) => s == viewer)))
          as Map<String, dynamic>;
      final mirror = buildRoundFromSnapshot(wire, mySeat: viewer);
      expect(mirror.ruleset, Ruleset.fuzhou);
      expect(mirror.goldIndicator!.type, type('5s'));
      expect(mirror.goldTypes, {type('5s')});
      expect(mirror.isFlowerTile(TileType.nan), isTrue);
      expect(mirror.wall, isA<FuzhouWall>());
      expect(mirror.seats[(2 - viewer + 4) % 4].goldDiscarded, isTrue);
      expect(mirror.seats[(3 - viewer + 4) % 4].goldDiscarded, isFalse);
    }
  });

  test('a flower Gold rebuilds as the other seven flowers', () {
    final round = fixture(gold: Tile(-1, TileType.plum), draws: tiles('2m'));
    final wire = jsonDecode(jsonEncode(
            roundSnapshotToJson(round, reveal: (s) => s == 0)))
        as Map<String, dynamic>;
    final mirror = buildRoundFromSnapshot(wire, mySeat: 0);
    expect(mirror.goldTypes, round.goldTypes);
  });

  test('before the flip nothing is sent', () {
    final round = Round.posed(
        dealer: 0,
        roundWind: Wind.east,
        startingPoints: List.filled(4, 500),
        ruleset: Ruleset.fuzhou,
        wall: FuzhouWall.posed(remaining: 50));
    final wire = roundSnapshotToJson(round, reveal: (s) => s == 0);
    expect(wire.containsKey('goldIndicator'), isFalse);
  });
}
