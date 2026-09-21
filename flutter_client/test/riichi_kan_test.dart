import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/hand_parse.dart';
import 'package:mahjong_core/round.dart';
import 'package:mahjong_core/tile.dart';

import 'helpers.dart';

/// A riichi hand is tenpai by definition, so a closed kan declared under riichi
/// may never change what it is waiting on. Once it did — the check compared the
/// hand after the kan with itself — and a riichi player could kan their way out
/// of tenpai, then pay noten at the exhaustive draw with a riichi stick already
/// on the table.
void main() {
  /// A riichi seat 0 holding [concealed] (13 tiles) and having just drawn
  /// [drawn].
  Round riichiHand(String concealed, String drawn) {
    final r = Round(
      seed: 3,
      dealer: 0,
      roundWind: Wind.east,
      honba: 0,
      riichiSticks: 0,
      startingPoints: List.filled(4, 25000),
    );
    // A distinct id, as every tile has in a real game.
    final tile = Tile(900, parseTiles(drawn).single.type);
    r.seats[0]
      ..hand = [...parseTiles(concealed), tile]
      ..drawn = tile
      ..riichi = true;
    r.turn = 0;
    r.phase = RoundPhase.discarding;
    return r;
  }

  test('a riichi kan that breaks tenpai is not offered', () {
    // Waits on 3m/6m; 111p is also the 11p pair and 123p, so the kan leaves
    // nothing to wait on.
    final r = riichiHand('45m 111p 23p 445566s', '1p');
    expect(waitTiles(parseTiles('45m 111p 23p 445566s')),
        [TileType.man3, TileType.man6],
        reason: 'the hand is tenpai before the kan');
    expect(r.closedKanTypes(0), isEmpty);
  });

  test('a riichi kan that keeps the wait is offered', () {
    // Waits on 7s alone; setting 555s aside leaves 68s waiting on the same.
    final r = riichiHand('555s 68s 234m 567m 99p', '5s');
    expect(r.closedKanTypes(0), [TileType.sou5]);
  });

  test('a riichi kan is only of the tile just drawn', () {
    // Four 5s in the hand, but the draw was a 9p: nothing may be kanned.
    final r = riichiHand('555s 68s 234m 567m 99p', '9p');
    r.seats[0].hand = [...r.seats[0].hand, Tile(901, TileType.sou5)];
    expect(r.closedKanTypes(0), isEmpty);
  });

  test('without riichi the same four tiles can be kanned freely', () {
    final r = riichiHand('45m 111p 23p 445566s', '1p');
    r.seats[0].riichi = false;
    expect(r.closedKanTypes(0), [TileType.pin1]);
  });
}
