import 'dart:convert';

import 'package:mahjong_core/mahjong_core.dart';
import 'package:mahjong_core/taiwanese/taiwanese_wall.dart';
import 'package:test/test.dart';

Meld _chow(TileType t) =>
    Meld(kind: MeldKind.sequence, low: t, concealed: false);
Meld _pung(TileType t) =>
    Meld(kind: MeldKind.triplet, low: t, concealed: false);

/// Twelve discards into the hand, seat 1 (South, dealer 0), four sets exposed and ready on 5m/8m with a pair
/// of North. Each flower is a point and a self-draw adds one, so with one
/// flower the hand is worth 1 on a discard and 2 self-drawn; with two, 2 and
/// 3.
Round _table(int minimumPoints, {int flowers = 1}) {
  final r = Round.posed(
    ruleset: Ruleset.taiwanese,
    minimumPoints: minimumPoints,
    dealer: 0,
    roundWind: Wind.east,
    wall: TaiwaneseWall.fromTiles([
      for (var i = 0; i < 20; i++)
        Tile(
            500 + i,
            const [
              TileType.man2,
              TileType.pin9,
              TileType.sou2,
              TileType.haku
            ][i % 4]),
    ]),
    startingPoints: List.filled(4, 1000),
  );
  // Three times round the table on throwaway tiles first: a posed table has
  // seen no discards, and a win inside the first ten earns "Win Within N
  // Discards" (+10 or +5), which would clear every minimum.
  for (final seat in r.seats) {
    seat.hand = [Tile(600 + seat.seat, TileType.chun)];
  }
  for (var i = 0; i < 12; i++) {
    final seat = r.seats[r.turn];
    r.discard(r.turn, seat.drawn ?? seat.hand.first);
    if (r.phase == RoundPhase.callOffer) r.resolveCalls({});
  }
  r.seats[1].melds = [
    _chow(TileType.man1),
    _chow(TileType.pin4),
    _pung(TileType.sou9),
    _chow(TileType.sou3),
  ];
  r.seats[1].hand = [
    Tile(1, TileType.man6),
    Tile(2, TileType.man7),
    Tile(3, TileType.pei),
    Tile(4, TileType.pei),
  ];
  r.seats[1].flowers = [
    Tile(11, TileType.plum),
    if (flowers > 1) Tile(12, TileType.bamboo),
  ];
  return r;
}

bool _canSelfDraw(Round r) {
  final win = Tile(900, TileType.man8);
  r.turn = 1;
  r.phase = RoundPhase.discarding;
  r.seats[1].hand.add(win);
  r.seats[1].drawn = win;
  return r.canTsumo(1);
}

void main() {
  test('choices are 1, 3 and 5; anything else falls back to 5', () {
    for (final n in [1, 3, 5]) {
      expect(TaiwaneseRules.normalizeMinimumPoints(n), n);
    }
    for (final bad in [null, 0, 2, 4, 6, -1, '3', 3.0]) {
      expect(TaiwaneseRules.normalizeMinimumPoints(bad), 5, reason: '$bad');
    }
    expect(_table(TaiwaneseRules.defaultMinimumPoints).minimumPoints, 5);
  });

  test('a discard win needs the table minimum', () {
    for (final (minimum, legal) in [(1, true), (3, false), (5, false)]) {
      expect(_table(minimum).canRon(1, Tile(900, TileType.man8)), legal,
          reason: 'minimum $minimum');
    }
  });

  test('a self-draw point and more flowers count toward it', () {
    for (final (minimum, flowers, legal) in [
      (1, 1, true), // 2 points
      (3, 1, false),
      (3, 2, true), // 3 points
      (5, 2, false),
    ]) {
      expect(_canSelfDraw(_table(minimum, flowers: flowers)), legal,
          reason: 'minimum $minimum, $flowers flowers');
    }
  });

  test('scoreTaiwaneseHand defaults to the sheet\'s 5', () {
    final r = _table(1);
    final score = scoreTaiwaneseHand(
      r.seats[1].hand,
      Tile(900, TileType.man8),
      r.seats[1].melds,
      ScoreContext(
        roundWind: Wind.east,
        seatWind: Wind.south,
        isTsumo: false,
        closed: false,
        flowers: const [TileType.plum],
        discardCount: 20,
      ),
      isDealer: false,
    );
    expect(score.valid, isFalse);
  });

  test('the snapshot carries the minimum to the client', () {
    final round = Round(
      seed: 3,
      dealer: 0,
      roundWind: Wind.east,
      startingPoints: List.filled(4, 1000),
      ruleset: Ruleset.taiwanese,
      minimumPoints: 1,
    );
    final wire = jsonDecode(
            jsonEncode(roundSnapshotToJson(round, reveal: (s) => s == 0)))
        as Map<String, dynamic>;
    expect(buildRoundFromSnapshot(wire, mySeat: 0).minimumPoints, 1);
    // An older server that never sent it means the old 5-point table.
    wire.remove('minimumPoints');
    expect(buildRoundFromSnapshot(wire, mySeat: 0).minimumPoints, 5);
  });

  test('bots finish seeded games at every minimum and conserve points', () {
    for (final minimum in TaiwaneseRules.minimumPointsChoices) {
      for (var seed = 0; seed < 20; seed++) {
        final r = Round(
          ruleset: Ruleset.taiwanese,
          minimumPoints: minimum,
          seed: seed,
          dealer: seed % 4,
          roundWind: Wind.east,
          startingPoints: List.filled(4, 1000),
        );
        final bots = List.generate(4, (i) => SimpleBot(seed + i));
        var steps = 0;
        while (!r.finished && steps++ < 800) {
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
        expect(r.finished, isTrue, reason: 'min $minimum seed $seed');
        expect(r.seats.fold(0, (int sum, s) => sum + s.points), 4000);
        for (final score in r.result!.scores) {
          expect(score.han, greaterThanOrEqualTo(minimum),
              reason: 'min $minimum seed $seed');
        }
      }
    }
  });
}
