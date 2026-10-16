/// Sichuan's 108-tile wall: man, pin and sou, four of each, with no honors,
/// no flowers and no red fives. Kong replacements come from the tail, as in
/// Hong Kong, and there is no dead wall and no dora.
library;

import 'dart:math';

import '../tile.dart';
import '../wall.dart';

class SichuanWall implements TileWall {
  SichuanWall(int seed, {Random? rng}) {
    var id = 0;
    for (var i = 0; i < 27; i++) {
      for (var copy = 0; copy < 4; copy++) {
        _live.add(Tile(id++, typeFrom34(i)));
      }
    }
    _live.shuffle(rng ?? Random(seed));
  }

  /// A wall posed for the scenario builder or an online client: only its count
  /// matters.
  SichuanWall.posed({required int remaining}) {
    _live.addAll(
        List.generate(remaining, (i) => Tile(-200 - i, TileType.blank)));
  }

  /// Deterministic wall for rule fixtures. The first entry is the next draw;
  /// the last is the first replacement.
  SichuanWall.fromTiles(List<Tile> tiles) {
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
