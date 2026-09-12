import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/logic/bot.dart';
import 'package:tilesense/logic/round.dart';
import 'package:tilesense/logic/meld.dart';
import 'package:tilesense/logic/tile.dart';
import 'package:tilesense/logic/wall.dart';
import 'helpers.dart';

Round fixture({List<Tile> wall = const []}) => Round.posed(
    dealer: 0,
    roundWind: Wind.east,
    wall: Wall.fromTiles(wall),
    startingPoints: List.filled(4, 1000));

void main() {
  test('seeded games finish, conserve chips and keep bonus tiles out of hands',
      () {
    for (var seed = 0; seed < 60; seed++) {
      final r = Round(
          seed: seed,
          dealer: seed % 4,
          roundWind: Wind.east,
          startingPoints: List.filled(4, 1000));
      final bots = List.generate(4, (i) => SimpleBot(seed + i));
      var steps = 0;
      while (!r.finished && steps++ < 500) {
        for (final s in r.seats) {
          expect(s.hand.every((t) => t.type.isPlayingTile), isTrue);
          expect(s.flowers.every((t) => t.type.isBonus), isTrue);
          expect(s.riichi, isFalse);
        }
        if (r.phase == RoundPhase.callOffer) {
          r.resolveCalls({
            for (final opt in r.callOptions)
              opt.seat: bots[opt.seat]
                  .decideCall(r, opt.seat, r.pendingDiscard!, opt.types)
          });
        } else {
          final move = bots[r.turn].decideTurn(r, r.turn);
          if (move.tsumo) {
            r.declareTsumo(r.turn);
          } else if (move.closedKan != null) {
            r.closedKan(r.turn, move.closedKan!);
          } else if (move.addedKan != null) {
            r.addKan(r.turn, move.addedKan!);
          } else {
            r.discard(r.turn, move.discard!);
          }
        }
      }
      expect(r.finished, isTrue, reason: 'seed $seed');
      expect(r.seats.fold(0, (int sum, s) => sum + s.points), 4000);
      expect(r.result!.pointDeltas.values.reduce((a, b) => a + b), 0);
    }
  });
  test('no own-discard or temporary furiten restriction', () {
    final r = fixture(wall: [Tile(950, TileType.man9)]);
    r.seats[2].hand = parseTiles('123m 456p 789s 22m 55p');
    r.seats[2].allDiscards.add(Tile(901, TileType.pin5));
    r.seats[2].tempFuriten = true;
    expect(r.canRon(2, Tile(902, TileType.pin5)), isTrue);
    expect(r.isFuriten(2), isFalse);
    r.seats[0].hand = [Tile(903, TileType.pin5)];
    r.discard(0, r.seats[0].hand.single);
    r.resolveCalls({});
    expect(r.canRon(2, Tile(904, TileType.pin5)), isTrue);
  });
  test('no riichi action or locked discard', () {
    final r = fixture();
    r.seats[0].hand = parseTiles('12m');
    r.seats[0].drawn = r.seats[0].hand.last;
    expect(r.canRiichi(0), isFalse);
    expect(r.legalDiscards(0), hasLength(2));
    expect(() => r.discard(0, r.seats[0].hand.first, declareRiichi: true),
        throwsUnsupportedError);
    expect(r.seats[0].points, 1000);
  });
  test('wall exhaustion makes no ready-hand transfers', () {
    final r = fixture();
    r.seats[0].hand = [Tile(900, TileType.man9)];
    r.seats[1].hand = parseTiles('123m 456p 789s 22m 55p');
    r.discard(0, r.seats[0].hand.single);
    if (r.phase == RoundPhase.callOffer) r.resolveCalls({});
    expect(r.result!.kind, RoundEndKind.exhaustiveDraw);
    expect(r.result!.pointDeltas, {0: 0, 1: 0, 2: 0, 3: 0});
  });
  test('discarder alone pays twice the sheet value', () {
    final r = fixture(wall: [Tile(990, TileType.sou1)]);
    final win = Tile(900, TileType.pin5);
    r.seats[1].hand = parseTiles('456p 789s 22m 55p');
    r.seats[1].melds = [
      Meld(kind: MeldKind.sequence, low: TileType.man1, concealed: false)
    ];
    r.seats[1].flowers = [
      Tile(901, TileType.plum)
    ]; // nonmatching: chicken hand
    r.seats[0].hand = [win];
    r.discard(0, win);
    r.resolveCalls({1: CallType.ron});
    expect(r.result!.score!.faan, 0);
    expect(r.result!.pointDeltas, {0: -2, 1: 2, 2: 0, 3: 0});
  });
  test('self draw pays equally, with no dealer multiplier', () {
    final r = fixture(wall: [Tile(990, TileType.sou1)]);
    final win = Tile(900, TileType.pin5);
    r.turn = 1;
    r.seats[1].hand = [...parseTiles('123m 456p 789s 22m 55p'), win];
    r.seats[1].drawn = win;
    r.seats[1].flowers = [Tile(901, TileType.plum)];
    r.declareTsumo(1);
    expect(r.result!.pointDeltas, {0: -4, 1: 12, 2: -4, 3: -4});
  });
  test('invalid call choice cannot manufacture a winner', () {
    final r = fixture(wall: [Tile(990, TileType.sou1)]);
    final win = Tile(900, TileType.pin5);
    r.seats[1].hand = parseTiles('55p');
    r.seats[0].hand = [win];
    r.discard(0, win);
    r.resolveCalls({2: CallType.ron});
    expect(r.finished, isFalse);
  });
}
