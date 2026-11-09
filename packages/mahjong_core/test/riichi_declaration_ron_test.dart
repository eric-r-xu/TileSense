import 'package:mahjong_core/mahjong_core.dart';
import 'package:test/test.dart';

/// A riichi only takes effect once its declaration tile has passed unclaimed:
/// if that tile is ronned, the declarer keeps their 1000 and no stick is left
/// for the winner.
void main() {
  var id = 0;
  List<Tile> tiles(List<TileType> ts) => [for (final x in ts) Tile(id++, x)];

  Round table({int sticks = 0}) {
    final r = Round(
        seed: 1,
        dealer: 0,
        roundWind: Wind.east,
        riichiSticks: sticks,
        startingPoints: List.filled(4, 25000));
    r.turn = 0;
    r.phase = RoundPhase.discarding;
    // Seat 0 holds 123m 456m 789m 123p + 5s 9s and riichis cutting the 9s.
    r.seats[0].hand = tiles([
      TileType.man1, TileType.man2, TileType.man3, TileType.man4, //
      TileType.man5, TileType.man6, TileType.man7, TileType.man8,
      TileType.man9, TileType.pin1, TileType.pin2, TileType.pin3,
      TileType.sou5, TileType.sou9,
    ]);
    r.seats[0].drawn = r.seats[0].hand.last;
    // Seat 1 is in riichi on 234p 567p 345s 678s, waiting on 9s.
    r.seats[1].hand = tiles([
      TileType.pin2, TileType.pin3, TileType.pin4, TileType.pin5, //
      TileType.pin6, TileType.pin7, TileType.sou3, TileType.sou4,
      TileType.sou5, TileType.sou6, TileType.sou7, TileType.sou8,
      TileType.sou9,
    ]);
    r.seats[1].riichi = true;
    return r;
  }

  test('ronning the declaration tile: the riichi fails and the 1000 is kept',
      () {
    final r = table();
    r.discard(0, r.seats[0].hand.last, declareRiichi: true);
    expect(r.seats[0].points, 24000);
    expect(r.riichiSticks, 1);
    expect(r.callOptions.single.seat, 1);

    r.resolveCalls({1: CallType.ron});
    final win = r.result!.score!.points;
    expect(r.result!.pointDeltas[1], win,
        reason: 'the winner gets the hand, and no stick that never existed');
    expect(r.result!.pointDeltas[0], -win);
    expect(r.seats[0].points, 25000 - win);
    expect(r.riichiSticks, 0);
    expect(r.seats[0].riichi, isFalse);
    expect(r.result!.pointDeltas.values.fold<int>(0, (a, b) => a + b), 0);
  });

  test('sticks from earlier riichis still go to the winner', () {
    final r = table(sticks: 2);
    r.discard(0, r.seats[0].hand.last, declareRiichi: true);
    r.resolveCalls({1: CallType.ron});
    final win = r.result!.score!.points;
    expect(r.result!.pointDeltas[1], win + 2000);
    expect(r.result!.pointDeltas[0], -win);
    expect(r.riichiSticks, 0);
  });

  test('a riichi that passed is still paid out on a later ron', () {
    final r = table();
    r.discard(0, r.seats[0].hand.last, declareRiichi: true);
    r.resolveCalls({}); // nobody rons
    expect(r.riichiSticks, 1);
    expect(r.seats[0].riichi, isTrue);
  });
}
