import 'dart:math';

import 'package:mahjong_core/mahjong_core.dart';
import 'package:test/test.dart';

void main() {
  test('a posed round with a playable wall can be drawn on and discarded', () {
    final hand = [
      for (var i = 0; i < 13; i++) Tile(i, TileType.values[i % 9]),
    ];
    final unseen = [
      for (var i = 0; i < 100; i++) Tile(1000 + i, TileType.values[i % 34]),
    ];
    final wall = Wall.playable(
        unseen: unseen, dora: [TileType.man1], rng: Random(1));
    final round = Round.posed(
        dealer: 0,
        roundWind: Wind.east,
        wall: wall,
        startingPoints: List.filled(4, 25000));
    round.seats[0].hand = hand;
    for (var i = 1; i < 4; i++) {
      round.seats[i].hand = [
        for (var k = 0; k < 13; k++) Tile(2000 + i * 20 + k, TileType.pin1),
      ];
    }
    final before = wall.remaining;
    round.beginPosedPlay();
    expect(round.phase, RoundPhase.discarding);
    expect(round.seats[0].hand.length, 14);
    expect(wall.remaining, before - 1);
    expect(wall.doraIndicators(), [TileType.man1]);
    round.discard(0, round.seats[0].hand.first);
    expect(round.seats[0].pond.length, 1);
  });
}
