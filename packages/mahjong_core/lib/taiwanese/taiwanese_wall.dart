/// Taiwanese's 144-tile wall: the same 136 ordinary tiles plus eight flowers
/// and seasons Hong Kong deals with — see `hong_kong_wall.dart` for why a
/// separate dead-wall buffer isn't modelled. The only difference is the deal
/// itself: 16 tiles to each seat (not 13), so that the dealer's first ordinary
/// draw — already how `Round` gives every dealer their extra tile — brings
/// East to the ruleset's 17-tile hand.
library;

import 'dart:math';

import '../tile.dart';
import '../wall.dart';

class TaiwaneseWall implements TileWall {
  TaiwaneseWall(int seed) {
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
  TaiwaneseWall.posed({required int remaining}) {
    _live.addAll(
        List.generate(remaining, (i) => Tile(-200 - i, TileType.blank)));
  }

  /// Deterministic wall for rule fixtures. The first entry is the next draw;
  /// the last is the first replacement.
  TaiwaneseWall.fromTiles(List<Tile> tiles) {
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
      List.generate(4, (_) => List.generate(16, (_) => drawLive()));
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
