/// Fuzhou's 144-tile wall: the 136 ordinary tiles (winds and dragons included)
/// plus the eight flowers and seasons, dealt 16 to a seat.
///
/// The last [FuzhouRules.deadWallSize] tiles are set apart. Nobody draws from
/// them; the dealer flips the last one face up as the Gold indicator once the
/// flowers are replaced (see [revealGold]). The hand is a draw when the live
/// wall runs out. Replacement draws, for a flower or a kong, come from the
/// tail end of the live wall.
library;

import 'dart:math';

import '../tile.dart';
import '../wall.dart';
import 'fuzhou_rules.dart';

class FuzhouWall implements TileWall {
  FuzhouWall(int seed, {Random? rng}) {
    var id = 0;
    for (var i = 0; i < 34; i++) {
      for (var copy = 0; copy < 4; copy++) {
        _live.add(Tile(id++, typeFrom34(i)));
      }
    }
    for (final t in TileType.values.where((t) => t.isBonus)) {
      _live.add(Tile(id++, t));
    }
    _live.shuffle(rng ?? Random(seed));
    _dead.addAll(_live.sublist(0, FuzhouRules.deadWallSize));
    _live.removeRange(0, FuzhouRules.deadWallSize);
  }

  /// A wall posed for the scenario builder or an online client's rebuild of
  /// the server's wall: only its count and the revealed Gold matter.
  FuzhouWall.posed({required int remaining, Tile? gold}) {
    _live.addAll(
        List.generate(remaining, (i) => Tile(-200 - i, TileType.blank)));
    _gold = gold;
  }

  /// Deterministic wall for rule fixtures. The first entry of [tiles] is the
  /// next draw; the last is the first replacement. [gold] is what the dealer
  /// will flip (a plain tile of an arbitrary type by default).
  FuzhouWall.fromTiles(List<Tile> tiles, {Tile? gold}) {
    _live.addAll(tiles.reversed);
    _dead.add(gold ?? const Tile(-300, TileType.man1));
  }

  final List<Tile> _live = [];
  final List<Tile> _dead = [];
  Tile? _gold;

  /// The face-up Gold indicator, once flipped.
  Tile? get goldIndicator => _gold;

  /// Flips the last tile of the dead wall as the Gold indicator.
  Tile revealGold() => _gold = _dead.last;

  @override
  int get remaining => _live.length;
  @override
  bool get isEmpty => _live.isEmpty;
  @override
  bool get canKan => _live.isNotEmpty;

  @override
  List<List<Tile>> deal() => List.generate(
      4, (_) => List.generate(FuzhouRules.handSize, (_) => drawLive()));
  @override
  Tile drawLive() => _live.removeLast();
  @override
  Tile drawDeadWall() => _live.removeAt(0);

  @override
  List<TileType> doraIndicators() => const [];
  @override
  List<TileType> uraDoraIndicators() => const [];

  /// The dead wall, with the flipped Gold indicator shown face up: the real
  /// tile once revealed, the rest as unknown.
  @override
  List<Tile?> deadWallDisplay({bool revealUra = false}) =>
      [if (_gold != null) _gold];
}
