import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/logic/round.dart';
import 'package:tilesense/logic/tile.dart';
import 'package:tilesense/logic/wall.dart';
import 'helpers.dart';

void main() {
  test('144 unique tiles, eight bonuses, no red fives or dead wall', () {
    final wall = Wall(42);
    final tiles = <Tile>[];
    while (!wall.isEmpty) {
      tiles.add(wall.drawLive());
    }
    expect(tiles, hasLength(144));
    expect(tiles.map((t) => t.id).toSet(), hasLength(144));
    expect(tiles.where((t) => t.type.isBonus), hasLength(8));
    expect(tiles.any((t) => t.aka), isFalse);
    for (var i = 0; i < 34; i++) {
      expect(tiles.where((t) => t.type == typeFrom34(i)), hasLength(4));
    }
    expect(wall.doraIndicators(), isEmpty);
    expect(wall.uraDoraIndicators(), isEmpty);
    expect(wall.deadWallDisplay(), isEmpty);
  });
  test('kong draws from tail, replaces chained flowers, and reveals no dora',
      () {
    final replacement = Tile(990, TileType.pin8);
    final wall = Wall.fromTiles([
      Tile(980, TileType.man9),
      replacement,
      Tile(991, TileType.plum),
      Tile(992, TileType.spring)
    ]);
    final r = Round.posed(
        dealer: 0,
        roundWind: Wind.east,
        wall: wall,
        startingPoints: List.filled(4, 1000));
    r.seats[0].hand = parseTiles('1111m 234p 567p 789s E');
    r.closedKan(0, TileType.man1);
    expect(r.seats[0].drawn, replacement);
    expect(r.seats[0].flowers.map((t) => t.type),
        [TileType.spring, TileType.plum]);
    expect(r.seats[0].hand, hasLength(11));
    expect(wall.remaining, 1);
    expect(wall.doraIndicators(), isEmpty);
  });
  test('flower-only remainder exhausts the round without a phantom draw', () {
    final r = Round.posed(
        dealer: 0,
        roundWind: Wind.east,
        wall: Wall.fromTiles([Tile(991, TileType.plum)]),
        startingPoints: List.filled(4, 1000));
    r.seats[0].hand = [Tile(990, TileType.pin8)];
    r.discard(0, r.seats[0].hand.single);
    expect(r.finished, isTrue);
    expect(r.seats[1].flowers.single.type, TileType.plum);
    expect(r.seats[1].drawn, isNull);
  });
  test('dealing replaces bonus tiles before the first discard', () {
    for (var seed = 0; seed < 40; seed++) {
      final r = Round(
          seed: seed,
          dealer: 0,
          roundWind: Wind.east,
          startingPoints: List.filled(4, 1000));
      expect(r.seats[0].hand, hasLength(14));
      for (final s in r.seats.skip(1)) {
        expect(s.hand, hasLength(13));
      }
      expect(r.seats.expand((s) => s.hand).every((t) => t.type.isPlayingTile),
          isTrue);
      expect(
          r.wall.remaining +
              r.seats.fold<int>(
                  0, (int n, s) => n + s.hand.length + s.flowers.length),
          144);
    }
  });
}
