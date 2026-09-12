/// Hong Kong's 144-tile wall. Bonus and kong replacements come from the tail;
/// there is no reserved dead wall, dora, or red five.
library;

import 'dart:math';
import 'tile.dart';

class Wall {
  Wall(int seed) {
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
  Wall.posed({required int remaining, List<TileType> dora = const []}) {
    _live.addAll(
        List.generate(remaining, (i) => Tile(-200 - i, TileType.blank)));
  }

  /// Deterministic wall for rule fixtures. The first entry is the next draw.
  Wall.fromTiles(List<Tile> tiles) {
    _live.addAll(tiles.reversed);
  }
  final List<Tile> _live = [];
  int get remaining => _live.length;
  bool get isEmpty => _live.isEmpty;
  bool get canKan => _live.isNotEmpty;
  List<List<Tile>> deal() =>
      List.generate(4, (_) => List.generate(13, (_) => drawLive()));
  Tile drawLive() => _live.removeLast();
  Tile drawDeadWall() => _live.removeAt(0);
  // Legacy read APIs return no indicators in HK mahjong.
  List<TileType> doraIndicators() => const [];
  List<TileType> uraDoraIndicators() => const [];
  List<Tile?> deadWallDisplay({bool revealUra = false}) => const [];
}
