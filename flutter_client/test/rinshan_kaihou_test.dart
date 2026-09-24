import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/meld.dart';
import 'package:mahjong_core/round.dart';
import 'package:mahjong_core/tile.dart';
import 'package:mahjong_core/wall.dart';

import 'helpers.dart';

/// A real riichi [Wall] whose kan replacement tiles are chosen by the test,
/// and whose live wall can be declared empty once the replacement is drawn —
/// everything else (dora indicators, kan count) is the real wall's.
class _FixtureWall implements TileWall {
  _FixtureWall(this.replacements);
  final Wall _inner = Wall(7);
  final List<TileType> replacements;
  var _next = 0;

  /// When true, the live wall reads as empty after the next replacement
  /// draw — the kan was declared on the very last live tile.
  bool emptyAfterReplacement = false;
  bool _empty = false;

  @override
  int get remaining => _empty ? 0 : _inner.remaining;
  @override
  bool get isEmpty => _empty || _inner.isEmpty;
  @override
  bool get canKan => _inner.canKan;
  @override
  List<List<Tile>> deal() => _inner.deal();
  @override
  Tile drawLive() => _inner.drawLive();
  @override
  Tile drawDeadWall() {
    _inner.drawDeadWall(); // keeps the dora / kan bookkeeping real
    if (emptyAfterReplacement) _empty = true;
    return Tile(900 + _next, replacements[_next++]);
  }

  @override
  List<TileType> doraIndicators() => _inner.doraIndicators();
  @override
  List<TileType> uraDoraIndicators() => _inner.uraDoraIndicators();
  @override
  List<Tile?> deadWallDisplay({bool revealUra = false}) =>
      _inner.deadWallDisplay(revealUra: revealUra);
}

/// Seat 0 on its own turn with [hand] (whose last tile is the one just
/// drawn) and [melds]; every other seat holds something harmless.
Round _round(_FixtureWall wall, String hand, {List<Meld> melds = const []}) {
  final round = Round(
    seed: 1,
    dealer: 0,
    roundWind: Wind.east,
    startingPoints: List.filled(4, 25000),
    wall: wall,
  );
  for (var i = 1; i < 4; i++) {
    round.seats[i]
      ..hand = parseTiles('19m 19p 19s ESWN')
      ..melds = []
      ..drawn = null;
  }
  final tiles = parseTiles(hand);
  round.seats[0]
    ..hand = tiles
    ..melds = [...melds]
    ..drawn = tiles.last;
  round.turn = 0;
  round.phase = RoundPhase.discarding;
  return round;
}

List<String> _yaku(Round round) =>
    [for (final y in round.result!.score!.yaku) y.name];

/// An open, called pon of 2m — no yaku of its own.
final _openPon = Meld(
  kind: MeldKind.triplet,
  low: TileType.man2,
  concealed: false,
  calledFromSeatOffset: 1,
  tiles: parseTiles('222m'),
);

void main() {
  test('a closed kan draws its replacement and can win on it', () {
    final wall = _FixtureWall([TileType.sou9]);
    final round = _round(wall, '456s 78s 55m 3333p', melds: [_openPon]);

    round.closedKan(0, TileType.pin3);
    expect(round.seats[0].drawn?.type, TileType.sou9,
        reason: 'the replacement tile comes off the dead wall');
    expect(round.seats[0].replacementDraw, isTrue);
    expect(round.wall.doraIndicators(), hasLength(2),
        reason: 'the kan flips a new dora indicator');

    // Open, no yakuhai, a terminal in it: rinshan kaihou is its only yaku,
    // so without it this hand could not win at all.
    expect(round.canTsumo(0), isTrue,
        reason: 'rinshan kaihou alone is a yaku');
    round.declareTsumo(0);
    expect(round.result!.kind, RoundEndKind.tsumo);
    expect(_yaku(round), contains('Rinshan Kaihou'));
  });

  test('rinshan kaihou adds a han on top of the hand\'s other yaku', () {
    final wall = _FixtureWall([TileType.sou9]);
    // Closed: menzen tsumo as well.
    final round = _round(wall, '456s 78s 55m 123p 3333p');
    round.closedKan(0, TileType.pin3);
    expect(round.canTsumo(0), isTrue);
    round.declareTsumo(0);
    expect(_yaku(round), containsAll(['Menzen Tsumo', 'Rinshan Kaihou']));
  });

  test('an added kan wins on its replacement too', () {
    final wall = _FixtureWall([TileType.sou9]);
    final round = _round(wall, '456s 78s 55m 123p 2m', melds: [_openPon]);
    round.addKan(0, TileType.man2);
    expect(round.seats[0].drawn?.type, TileType.sou9);
    expect(round.canTsumo(0), isTrue);
    round.declareTsumo(0);
    expect(_yaku(round), contains('Rinshan Kaihou'));
  });

  test('an ordinary draw after a kan is not rinshan', () {
    final wall = _FixtureWall([TileType.pei]);
    final round = _round(wall, '456s 78s 55m 123p 3333p');
    round.closedKan(0, TileType.pin3);
    // Discard the replacement; the next ordinary draw clears the flag.
    round.discard(0, round.seats[0].drawn!);
    expect(round.seats[0].replacementDraw, isFalse);
  });

  test('the replacement tile is never haitei, even off the last live tile',
      () {
    final wall = _FixtureWall([TileType.sou9])..emptyAfterReplacement = true;
    final round = _round(wall, '456s 78s 55m 123p 3333p');
    round.closedKan(0, TileType.pin3);
    expect(round.wall.isEmpty, isTrue);
    round.declareTsumo(0);
    final yaku = _yaku(round);
    expect(yaku, contains('Rinshan Kaihou'));
    expect(yaku.where((y) => y.toLowerCase().contains('haitei')), isEmpty,
        reason: 'a dead-wall tile is not the last tile of the live wall');
  });
}
