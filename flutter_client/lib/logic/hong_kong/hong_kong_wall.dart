/// Hong Kong's 144-tile wall: the 136 ordinary tiles plus eight flowers and
/// seasons. Replacement draws for flowers and kongs come from the tail. There
/// is no reserved dead wall, no dora and no red five.
library;

import 'dart:math';

import '../tile.dart';
import '../wall.dart';

class HongKongWall implements TileWall {
  HongKongWall(int seed) {
    var id = 0;
    for (var i = 0; i < 34; i++) {
      for (var copy = 0; copy < 4; copy++) {
        _live.add(Tile(id++, typeFrom34(i)));
      }
    }
    for (final t in TileType.values.where((t) => t.isBonus)) {
      _live.add(Tile(id++, t));
    }
    _live.shuffle(Random(seed));
  }

  /// A wall posed for the scenario builder: only its count matters.
  HongKongWall.posed({required int remaining}) {
    _live.addAll(
        List.generate(remaining, (i) => Tile(-200 - i, TileType.blank)));
  }

  /// Deterministic wall for rule fixtures. The first entry is the next draw;
  /// the last is the first replacement.
  HongKongWall.fromTiles(List<Tile> tiles) {
    _live.addAll(tiles.reversed);
  }

  final List<Tile> _live = [];

  @override
  int get remaining => _live.length;
  @override
  bool get isEmpty => _live.isEmpty;
  @override
  bool get canKan => _live.isNotEmpty;

  @override
  List<List<Tile>> deal() =>
      List.generate(4, (_) => List.generate(13, (_) => drawLive()));
  @override
  Tile drawLive() => _live.removeLast();
  @override
  Tile drawDeadWall() => _live.removeAt(0);

  @override
  List<TileType> doraIndicators() => const [];
  @override
  List<TileType> uraDoraIndicators() => const [];
  @override
  List<Tile?> deadWallDisplay({bool revealUra = false}) => const [];
}
