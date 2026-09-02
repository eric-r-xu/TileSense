import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/logic/efficiency_calc.dart';
import 'package:tilesense/logic/hand_parse.dart';
import 'package:tilesense/logic/tile.dart';

import 'helpers.dart';

void main() {
  final calc = TileEfficiencyCalculator();

  ({int count, List<TileType> tiles}) accept(String spec) {
    final tiles = parseTiles(spec);
    final concealed = toTrainerCounts(tiles);
    final visible = toCounts34(tiles);
    final remaining = trainerCountsFromTypeCounts(
      [for (var i = 0; i < 34; i++) 4 - visible[i]],
    );
    final r = calc.acceptance(concealed, remaining);
    return (count: r.count, tiles: r.tiles.map(typeFromTrainerIndex).toList());
  }

  test('tanki wait accepts 3 tiles', () {
    final r = accept('123m 456m 789m 123p 5p');
    expect(r.tiles, [TileType.pin5]);
    expect(r.count, 3); // one 5p already in hand
  });

  test('ryanmen wait accepts both ends', () {
    final r = accept('123m 456m 789m 34p 55p');
    expect(r.tiles.toSet(), {TileType.pin2, TileType.pin5});
    // 4 x 2p + (4 - 2 held) x 5p = 6
    expect(r.count, 6);
  });

  test('waitTiles agrees with acceptance for a kanchan', () {
    final hand = parseTiles('123m 456m 789m 13p 55p');
    expect(waitTiles(hand).toSet(), {TileType.pin2});
  });

  test('shanpon wait accepts two types', () {
    final r = accept('123m 456m 789m 99p 55s');
    expect(r.tiles.toSet(), {TileType.pin9, TileType.sou5});
    expect(r.count, 4); // 2 + 2 remaining
  });
}
