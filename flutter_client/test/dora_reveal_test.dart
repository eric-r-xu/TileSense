import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/logic/meld.dart';
import 'package:tilesense/logic/round.dart';
import 'package:tilesense/logic/tile.dart';

import 'helpers.dart';

/// A dora indicator is flipped by a kan and by nothing else: one at the start,
/// one more for each kan, and never more than four kans' worth.
void main() {
  Round freshRound() => Round(
        seed: 3,
        dealer: 0,
        roundWind: Wind.east,
        honba: 0,
        riichiSticks: 0,
        startingPoints: List.filled(4, 25000),
      );

  int indicators(Round r) => r.wall.doraIndicators().length;

  test('a closed kan flips exactly one', () {
    final r = freshRound();
    expect(indicators(r), 1);

    r.seats[0].hand = [
      ...parseTiles('1111m 234p 567p 99s'),
      Tile(900, TileType.sou1),
    ];
    r.seats[0].drawn = Tile(900, TileType.sou1);
    r.turn = 0;
    r.phase = RoundPhase.discarding;
    r.closedKan(0, TileType.man1);
    expect(indicators(r), 2);

    r.seats[0].hand = [
      ...parseTiles('2222p 345s 678s 9s'),
      Tile(901, TileType.sou9),
    ];
    r.seats[0].drawn = Tile(901, TileType.sou9);
    r.turn = 0;
    r.phase = RoundPhase.discarding;
    r.closedKan(0, TileType.pin2);
    expect(indicators(r), 3);
  });

  test('an added kan nobody can rob does not leave the window open', () {
    // The chankan flag used to survive an unrobbable added kan, so the next
    // discard that offered any call took the chankan branch in resolveCalls
    // instead of its own: a second replacement tile, and a dora indicator that
    // no kan had earned.
    final r = freshRound();
    r.seats[0].melds = [
      Meld(
        kind: MeldKind.triplet,
        low: TileType.man1,
        concealed: false,
        calledFromSeatOffset: 1,
        tiles: parseTiles('111m'),
      ),
    ];
    r.seats[0].hand = [
      ...parseTiles('234p 567p 99s 45s'),
      Tile(900, TileType.man1),
    ];
    r.turn = 0;
    r.phase = RoundPhase.discarding;
    r.addKan(0, TileType.man1);
    expect(indicators(r), 2, reason: 'the kan itself flips one');

    // An ordinary discard somebody can call on. It has nothing to do with the
    // kan and must not flip anything.
    r.seats[1].hand = parseTiles('55s 123m 456m 789m 1p');
    r.seats[0].hand = [...r.seats[0].hand, Tile(901, TileType.sou5)];
    r.turn = 0;
    r.phase = RoundPhase.discarding;
    r.discard(0, Tile(901, TileType.sou5));
    expect(r.phase, RoundPhase.callOffer);
    r.resolveCalls({});
    expect(indicators(r), 2,
        reason: 'an ordinary discard flipped a dora indicator');
  });
}
