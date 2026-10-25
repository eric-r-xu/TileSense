/// Sanma's 108-tile wall: riichi's tiles without the 2-8 man, one red five in
/// pin and sou, and a 14-tile dead wall that serves eight replacement draws
/// (kans and kita together) before its first dora indicator.
///
/// As at a real table, every replacement draw moves the last tile of the live
/// wall (the haitei tile) over to the dead wall, so the dead wall stays at 14
/// and the live wall shortens by one. Those moved tiles are where the fourth
/// and fifth dora indicators (and their ura) come from.
library;

import 'dart:math';

import '../tile.dart';
import '../wall.dart';
import 'sanma_rules.dart';

class SanmaWall implements TileWall {
  SanmaWall(int seed, {Random? rng}) {
    final tiles = <Tile>[];
    var id = 0;
    for (var t = 0; t < 34; t++) {
      final type = typeFrom34(t);
      if (!SanmaRules.inWall(type)) continue;
      for (var copy = 0; copy < 4; copy++) {
        // One red five in pin and sou; there is no 5m.
        tiles.add(Tile(id++, type, aka: type.number == 5 && copy == 0));
      }
    }
    tiles.shuffle(rng ?? Random(seed));
    _replacements.addAll(tiles.sublist(0, SanmaRules.replacementDraws));
    _indicators.addAll(tiles.sublist(SanmaRules.replacementDraws, 14));
    _live.addAll(tiles.sublist(14));
  }

  /// Deterministic wall for rule fixtures: [live] in draw order (the first
  /// entry dealt or drawn first), then the eight [replacements] in order, and
  /// [indicators] as dora/ura pairs (dora first).
  SanmaWall.fromTiles({
    required List<Tile> live,
    List<Tile> replacements = const [],
    List<Tile> indicators = const [],
  }) {
    _live.addAll(live.reversed);
    _replacements.addAll(replacements);
    _indicators.addAll(indicators);
  }

  /// A wall posed for the scenario builder or an online client, which only
  /// renders it and asks what it allows: [remaining] tiles live, [dora] (and
  /// [ura]) revealed, and [replacementsLeft] dead-wall draws still to take,
  /// of which [kansLeft] may be kans.
  SanmaWall.posed({
    required int remaining,
    required List<TileType> dora,
    List<TileType> ura = const [],
    int replacementsLeft = SanmaRules.replacementDraws,
    int kansLeft = 4,
  }) {
    _live.addAll([
      for (var i = 0; i < remaining; i++) Tile(-200 - i, TileType.blank),
    ]);
    _replacements.addAll([
      for (var i = 0; i < SanmaRules.replacementDraws; i++)
        Tile(-400 - i, TileType.blank),
    ]);
    _replacementsTaken =
        (SanmaRules.replacementDraws - replacementsLeft).clamp(0, 8);
    _kans = (4 - kansLeft).clamp(0, 4);
    for (var i = 0; i < dora.length; i++) {
      _indicators
        ..add(Tile(-100 - i, dora[i]))
        ..add(Tile(-300 - i, i < ura.length ? ura[i] : TileType.blank));
    }
    _posedDora = dora.length;
  }

  final List<Tile> _live = [];

  /// The indicators a posed wall shows, however many kans it allows.
  int? _posedDora;

  /// Replacement draws still to take, for [SanmaWall.posed] on the client.
  int get replacementsLeft => _replacements.length - _replacementsTaken;

  /// Kans still allowed.
  int get kansLeft => 4 - _kans;

  /// Dead-wall replacement draws, taken from the front.
  final List<Tile> _replacements = [];

  /// Dora and ura indicators, in pairs: dora at even indices, ura after it.
  final List<Tile> _indicators = [];

  int _replacementsTaken = 0;
  int _kans = 0;

  @override
  int get remaining => _live.length;
  @override
  bool get isEmpty => _live.isEmpty;

  bool get _canReplace =>
      _replacementsTaken < _replacements.length && _live.isNotEmpty;

  /// Four kans at most, as in riichi, and a replacement left to draw.
  @override
  bool get canKan => _kans < 4 && _canReplace;

  /// Whether a North can be set aside: a replacement is left to draw.
  bool get canKita => _canReplace;

  /// 13 tiles to each of the three players; the empty seat gets none.
  @override
  List<List<Tile>> deal() {
    final hands = List.generate(4, (_) => <Tile>[]);
    for (var round = 0; round < 13; round++) {
      for (var seat = 0; seat < 4; seat++) {
        if (seat == SanmaRules.emptySeat) continue;
        hands[seat].add(_live.removeLast());
      }
    }
    return hands;
  }

  @override
  Tile drawLive() => _live.removeLast();

  /// A replacement after a kan: it also turns the next dora indicator.
  @override
  Tile drawDeadWall() {
    _kans++;
    return _replace();
  }

  /// A replacement after kita, which turns no indicator.
  Tile drawKitaReplacement() => _replace();

  Tile _replace() {
    final tile = _replacements[_replacementsTaken++];
    // The haitei tile moves to the dead wall to keep it at 14.
    if (_live.isNotEmpty) _indicators.add(_live.removeAt(0));
    return tile;
  }

  int get _doraRevealed =>
      _posedDora ?? min(1 + _kans, _indicators.length ~/ 2);

  @override
  List<TileType> doraIndicators() =>
      [for (var i = 0; i < _doraRevealed; i++) _indicators[i * 2].type];

  @override
  List<TileType> uraDoraIndicators() =>
      [for (var i = 0; i < _doraRevealed; i++) _indicators[i * 2 + 1].type];

  /// Laid out as [Wall.deadWallDisplay] is, so the table draws it the same
  /// way: four face-down slots, then dora at 4, 6, 8, 10, 12 and ura after
  /// each.
  @override
  List<Tile?> deadWallDisplay({bool revealUra = false}) =>
      List<Tile?>.generate(14, (i) {
        if (i < 4) return null;
        final k = (i - 4) ~/ 2;
        if (k >= _doraRevealed) return null;
        if (i.isEven) return _indicators[k * 2];
        return revealUra ? _indicators[k * 2 + 1] : null;
      });
}
