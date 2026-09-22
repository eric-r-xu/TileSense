/// The 136-tile wall: build, shuffle, deal, live-wall draws, and a dead wall
/// with progressively revealed dora / ura-dora indicators.
library;

import 'dart:math';

import 'tile.dart';

/// What a [Round] needs from a wall. Riichi uses [Wall]; Hong Kong uses
/// `HongKongWall`, which has flowers, no dead wall and no dora.
abstract interface class TileWall {
  int get remaining;
  bool get isEmpty;
  bool get canKan;

  /// 13 tiles to each of the four seats.
  List<List<Tile>> deal();

  /// The next ordinary draw.
  Tile drawLive();

  /// A replacement draw, after a kan (and, in Hong Kong, a flower).
  Tile drawDeadWall();

  List<TileType> doraIndicators();
  List<TileType> uraDoraIndicators();
  List<Tile?> deadWallDisplay({bool revealUra = false});
}

class Wall implements TileWall {
  Wall(int seed) : _rng = Random(seed) {
    _build();
  }

  /// A wall posed for a hand-built scenario, or for the multiplayer client's
  /// reconstruction of the server's real wall, rather than dealt out:
  /// exactly [remaining] tiles left in the live wall and exactly [dora]
  /// revealed as dora indicators, with [ura] beneath them once those are
  /// known too (round over, riichi win — see `protocol.dart`). Nothing is
  /// ever drawn from it — the scenario builder never advances a turn, and
  /// the online client only ever renders it — so only the count and the
  /// revealed indicators matter, not which physical tiles they are.
  /// [ura] left at its default renders as an unrevealed "?" wherever shown,
  /// same as any other not-yet-known tile — pass it once the round result
  /// actually carries it.
  Wall.posed({
    required int remaining,
    required List<TileType> dora,
    List<TileType> ura = const [],
  }) : _rng = Random(0) {
    _dead.addAll([
      for (var i = 0; i < 14; i++) Tile(-1 - i, TileType.blank),
    ]);
    for (var i = 0; i < dora.length && i < 5; i++) {
      _dead[4 + i * 2] = Tile(-100 - i, dora[i]);
    }
    for (var i = 0; i < ura.length && i < 5; i++) {
      _dead[5 + i * 2] = Tile(-300 - i, ura[i]);
    }
    _doraRevealed = dora.isEmpty ? 0 : dora.length.clamp(1, 5);
    _live.addAll([
      for (var i = 0; i < remaining; i++) Tile(-200 - i, TileType.blank),
    ]);
  }

  final Random _rng;

  /// Live wall, drawn from the end.
  final List<Tile> _live = [];

  /// 14-tile dead wall. Index 0..3 are the four kan-draw replacements; the dora
  /// indicators are at fixed positions 4,6,8,10,12 and ura at 5,7,9,11,13.
  final List<Tile> _dead = [];

  int _doraRevealed = 1;
  int _kanDraws = 0;

  @override
  int get remaining => _live.length;
  @override
  bool get isEmpty => _live.isEmpty;
  @override
  bool get canKan => _kanDraws < 4 && _live.isNotEmpty;

  void _build() {
    final tiles = <Tile>[];
    var id = 0;
    for (var t = 0; t < 34; t++) {
      final type = typeFrom34(t);
      for (var copy = 0; copy < 4; copy++) {
        // One red five per suit (the copy index 0 of the 5s).
        final aka = type.number == 5 && copy == 0;
        tiles.add(Tile(id++, type, aka: aka));
      }
    }
    tiles.shuffle(_rng);
    _dead.addAll(tiles.sublist(0, 14));
    _live.addAll(tiles.sublist(14));
  }

  /// Deal 13 tiles to each of the four seats (dealer first).
  @override
  List<List<Tile>> deal() {
    final hands = List.generate(4, (_) => <Tile>[]);
    for (var round = 0; round < 13; round++) {
      for (var seat = 0; seat < 4; seat++) {
        hands[seat].add(_live.removeLast());
      }
    }
    return hands;
  }

  @override
  Tile drawLive() => _live.removeLast();

  /// Draw a replacement tile after a kan and reveal the next dora indicator.
  @override
  Tile drawDeadWall() {
    final tile = _dead[_kanDraws];
    _kanDraws++;
    _doraRevealed++;
    // A kan also shortens the live wall by one (haitei bookkeeping).
    if (_live.isNotEmpty) _live.removeAt(0);
    return tile;
  }

  @override
  List<TileType> doraIndicators() =>
      [for (var i = 0; i < _doraRevealed; i++) _dead[4 + i * 2].type];

  @override
  List<TileType> uraDoraIndicators() =>
      [for (var i = 0; i < _doraRevealed; i++) _dead[5 + i * 2].type];

  /// The dead wall tiles, for the on-screen dead-wall strip. [revealUra] shows
  /// the ura indicators (only after a win with riichi).
  @override
  List<Tile?> deadWallDisplay({bool revealUra = false}) {
    return List<Tile?>.generate(14, (i) {
      if (i < 4) return null; // face-down kan draws
      final isDoraSlot = i >= 4 && i.isEven;
      final isUraSlot = i >= 5 && i.isOdd;
      final indicatorIndex = ((i - 4) ~/ 2);
      if (isDoraSlot && indicatorIndex < _doraRevealed) return _dead[i];
      if (isUraSlot && revealUra && indicatorIndex < _doraRevealed) {
        return _dead[i];
      }
      return null;
    });
  }
}
