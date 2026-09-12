import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/logic/round.dart';
import 'package:tilesense/logic/meld.dart';
import 'package:tilesense/logic/scoring.dart';
import 'package:tilesense/logic/tile.dart';
import 'package:tilesense/logic/wall.dart';
import 'helpers.dart';

Round posed(List<Tile> tiles) => Round.posed(
    dealer: 0,
    roundWind: Wind.east,
    wall: Wall.fromTiles(tiles),
    startingPoints: List.filled(4, 1000));
void main() {
  test('initial-deal flower choice resumes dealing and preserves all 144 tiles',
      () {
    final pool = <Tile>[];
    final source = Wall(14);
    while (!source.isEmpty) {
      pool.add(source.drawLive());
    }
    final bonuses = pool.where((t) => t.type.isBonus).take(7).toList();
    pool.removeWhere(bonuses.contains);
    final ordinary = pool.where((t) => t.type.isPlayingTile).take(45).toList();
    pool.removeWhere(ordinary.contains);
    final r = Round(
        seed: 0,
        dealer: 2,
        roundWind: Wind.east,
        startingPoints: List.filled(4, 1000),
        wall: Wall.fromTiles([
          ...ordinary.take(26),
          ...bonuses,
          ...ordinary.skip(26).take(6),
          ...ordinary.skip(32),
          ...pool.where((t) => t.type.isBonus),
          ...pool.where((t) => t.type.isPlayingTile),
        ]));
    expect(r.canFlowerWin(2), isTrue);
    expect(r.seats[2].flowers, hasLength(7));
    expect(r.seats[2].hand, hasLength(12));
    r.passFlowerWin(2);
    // The final flower is now the dealer's ordinary draw, then replaced.
    expect(r.canFlowerWin(2), isTrue);
    r.passFlowerWin(2);
    expect(r.turn, 2);
    expect(r.seats[2].hand, hasLength(14));
    expect(r.seats[2].flowers, hasLength(8));
    for (final seat in r.seats.where((s) => s.seat != 2)) {
      expect(seat.hand, hasLength(13));
    }
    expect(
        r.wall.remaining +
            r.seats
                .fold<int>(0, (n, s) => n + s.hand.length + s.flowers.length),
        144);
  });

  test('round scoring recognizes first-turn Heaven, Earth and Man', () {
    Round fresh() => Round(
        seed: 4,
        dealer: 0,
        roundWind: Wind.east,
        startingPoints: List.filled(4, 1000));
    final win = Tile(900, TileType.pin5);
    final ready = parseTiles('123m 456p 789s 22m 55p');
    final heaven = fresh();
    heaven.seats[0].hand = [...ready, win];
    heaven.seats[0].drawn = win;
    heaven.declareTsumo(0);
    expect(
        heaven.result!.score!.yaku.any((p) => p.name == 'Blessing of Heaven'),
        isTrue);

    final earth = fresh();
    earth.seats[0].hand = [win];
    earth.seats[1].hand = ready;
    earth.discard(0, win);
    earth.resolveCalls({1: CallType.ron});
    expect(earth.result!.score!.yaku.any((p) => p.name == 'Blessing of Earth'),
        isTrue);

    final man = fresh();
    man.seats[0].hand = [Tile(901, TileType.man9)];
    man.discard(0, man.seats[0].hand.single);
    if (man.phase == RoundPhase.callOffer) man.resolveCalls({});
    man.seats[1].hand = [...ready, win];
    man.seats[1].drawn = win;
    man.declareTsumo(1);
    expect(man.result!.score!.yaku.any((p) => p.name == 'Blessing of Man'),
        isTrue);
    expect(man.result!.score!.yaku.any((p) => p.name == 'Blessing of Heaven'),
        isFalse);
  });

  Round flowerFixture() {
    final r = posed([
      Tile(900, TileType.autumn),
      Tile(901, TileType.pin8),
      Tile(902, TileType.winter)
    ]);
    r.seats[0].hand = [Tile(903, TileType.man9)];
    r.seats[1].hand = parseTiles('123m 456p 789s 22m 55p');
    r.seats[1].flowers = [
      for (var i = 35; i < 41; i++) Tile(800 + i, TileType.values[i])
    ];
    r.discard(0, r.seats[0].hand.single);
    return r;
  }

  test('seventh flower offers a win before replacement; passing offers eighth',
      () {
    final r = flowerFixture();
    expect(r.canFlowerWin(1), isTrue);
    expect(r.seats[1].flowers, hasLength(7));
    expect(r.wall.remaining, 2);
    expect(r.legalDiscards(1), isEmpty);
    expect(() => r.discard(1, r.seats[1].hand.first), throwsStateError);
    r.passFlowerWin(1);
    expect(r.canFlowerWin(1), isTrue);
    expect(r.seats[1].flowers, hasLength(8));
    expect(r.wall.remaining, 1);
    r.declareTsumo(1);
    expect(r.result!.label, 'Eight Flowers');
    expect(r.result!.score!.faan, 8);
    expect(r.result!.pointDeltas, {0: -64, 1: 192, 2: -64, 3: -64});
  });
  test('seven flowers can win with an incomplete hand', () {
    final r = flowerFixture();
    r.declareTsumo(1);
    expect(r.result!.score!.faan, 3);
    expect(r.result!.pointDeltas, {0: -8, 1: 24, 2: -8, 3: -8});
    expect(r.result!.winTiles, isEmpty);
  });
  test('passing both flower wins resumes the original draw exactly once', () {
    final r = flowerFixture();
    r.passFlowerWin(1);
    r.passFlowerWin(1);
    expect(r.canFlowerWin(1), isFalse);
    expect(r.seats[1].drawn!.type, TileType.pin8);
    expect(r.seats[1].hand, hasLength(14));
    expect(r.phase, RoundPhase.discarding);
    expect(() => r.passFlowerWin(1), throwsStateError);
  });
  test(
      'double kong uses the first replacement tile and replaces self-pick bonus',
      () {
    final r = posed([
      Tile(990, TileType.man9),
      Tile(992, TileType.pin3),
      Tile(991, TileType.pin2)
    ]);
    r.seats[0].hand = parseTiles('1111m 222p 33p 456s EE');
    r.closedKan(0, TileType.man1);
    expect(r.seats[0].drawn!.type, TileType.pin2);
    r.closedKan(0, TileType.pin2);
    expect(r.seats[0].drawn!.type, TileType.pin3);
    expect(r.seats[0].kongChain, 2);
    expect(r.canTsumo(0), isTrue);
    r.declareTsumo(0);
    final patterns = r.result!.score!.yaku;
    expect(
        patterns.singleWhere((p) => p.name == 'Double Kong Replacement').faan,
        9);
    expect(
        patterns.any((p) =>
            p.name == 'Self-Pick' || p.name == 'Win by Kong Replacement'),
        isFalse);
  });
  test('a different held kong does not qualify as double replacement', () {
    final r = posed([
      Tile(990, TileType.man9),
      Tile(992, TileType.pin3),
      Tile(991, TileType.pin8)
    ]);
    r.seats[0].hand = parseTiles('1111m 2222p 33p 456s E');
    r.closedKan(0, TileType.man1);
    r.closedKan(0, TileType.pin2);
    expect(r.seats[0].kongChain, 1);
  });
  test(
      'multiple discard wins charge only the discarder and keep scores aligned',
      () {
    final r = posed([Tile(990, TileType.sou1)]);
    final win = Tile(900, TileType.pin5);
    for (final seat in [1, 2]) {
      r.seats[seat].hand = parseTiles('456p 789s 22m 55p');
      r.seats[seat].melds = [
        Meld(kind: MeldKind.sequence, low: TileType.man1, concealed: false)
      ];
      r.seats[seat].flowers = [
        Tile(910 + seat, seat == 1 ? TileType.plum : TileType.orchid)
      ];
    }
    r.seats[0].hand = [win];
    r.discard(0, win);
    r.resolveCalls({2: CallType.ron, 1: CallType.ron});
    expect(r.result!.winners, [1, 2]);
    expect(r.result!.scores.map((s) => s.points), [2, 2]);
    expect(r.result!.pointDeltas, {0: -4, 1: 2, 2: 2, 3: 0});
  });
  test('special winning conditions and seven-pairs stacking match the sheet',
      () {
    final hand = parseTiles('123m 456p 789s 22m 55p');
    HandScore score(
            {bool self = true,
            bool dealer = false,
            bool heaven = false,
            bool earth = false,
            bool man = false}) =>
        scoreHand(
            hand,
            Tile(900, TileType.pin5),
            [],
            ScoreContext(
                roundWind: Wind.east,
                seatWind: dealer ? Wind.east : Wind.south,
                isTsumo: self,
                closed: true,
                heavenly: heaven,
                earthly: earth,
                blessingOfMan: man),
            isDealer: dealer);
    expect(
        score(heaven: true, dealer: true)
            .yaku
            .any((p) => p.name == 'Blessing of Heaven' && p.faan == 13),
        isTrue);
    expect(
        score(self: false, earth: true)
            .yaku
            .any((p) => p.name == 'Blessing of Earth' && p.faan == 13),
        isTrue);
    expect(
        score(man: true)
            .yaku
            .any((p) => p.name == 'Blessing of Man' && p.faan == 13),
        isTrue);
    final pairs = scoreHand(
        parseTiles('EE SS WW NN BB GG R'),
        Tile(900, TileType.chun),
        [],
        ScoreContext(
            roundWind: Wind.east,
            seatWind: Wind.south,
            isTsumo: false,
            closed: true,
            flowersEnabled: false),
        isDealer: false);
    expect(pairs.faan, 15); // 4 pairs + 10 honours + 1 concealed
    expect(pairs.points, 768);
  });
}
