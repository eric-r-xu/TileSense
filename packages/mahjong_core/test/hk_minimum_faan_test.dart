import 'dart:convert';

import 'package:mahjong_core/mahjong_core.dart';
import 'package:test/test.dart';

/// Seat 1 (South, dealer 0) ready on 2m/5p with an open chow and a
/// non-matching flower: a chicken hand — 0 faan on a discard, 1 (Self-Pick)
/// on a self-draw.
Round _chickenTable(int minimumFaan) {
  final r = Round.posed(
    ruleset: Ruleset.hongKong,
    minimumFaan: minimumFaan,
    dealer: 0,
    roundWind: Wind.east,
    wall: HongKongWall.fromTiles([Tile(990, TileType.sou1)]),
    startingPoints: List.filled(4, 1000),
  );
  r.seats[1].hand = [
    Tile(1, TileType.pin4), Tile(2, TileType.pin5), Tile(3, TileType.pin6), //
    Tile(4, TileType.sou7), Tile(5, TileType.sou8), Tile(6, TileType.sou9),
    Tile(7, TileType.man2), Tile(8, TileType.man2),
    Tile(9, TileType.pin5), Tile(10, TileType.pin5),
  ];
  r.seats[1].melds = [
    Meld(kind: MeldKind.sequence, low: TileType.man1, concealed: false)
  ];
  r.seats[1].flowers = [Tile(11, TileType.plum)];
  return r;
}

void main() {
  test('choices are 0-3; anything else falls back to 0', () {
    for (final n in [0, 1, 2, 3]) {
      expect(HongKongRules.normalizeMinimumFaan(n), n);
    }
    for (final bad in [null, -1, 4, 13, '2', 2.0]) {
      expect(HongKongRules.normalizeMinimumFaan(bad), 0, reason: '$bad');
    }
    expect(
        Round.posed(
          ruleset: Ruleset.hongKong,
          dealer: 0,
          roundWind: Wind.east,
          wall: HongKongWall.fromTiles(const []),
          startingPoints: List.filled(4, 1000),
        ).minimumFaan,
        0);
  });

  test('a discard win below the minimum is not offered', () {
    expect(_chickenTable(0).canRon(1, Tile(900, TileType.pin5)), isTrue);
    expect(_chickenTable(1).canRon(1, Tile(900, TileType.pin5)), isFalse);
  });

  test('the self-pick faan can lift a hand to the minimum', () {
    for (final (minimum, legal) in [(1, true), (2, false), (3, false)]) {
      final r = _chickenTable(minimum);
      final win = Tile(900, TileType.pin5);
      r.turn = 1;
      r.seats[1].hand.add(win);
      r.seats[1].drawn = win;
      expect(r.canTsumo(1), legal, reason: 'minimum $minimum');
    }
  });

  test('each faan of the hand counts toward the minimum', () {
    // No flowers adds 1 faan: 1 on a discard.
    for (final (minimum, legal) in [(0, true), (1, true), (2, false)]) {
      final r = _chickenTable(minimum);
      r.seats[1].flowers = [];
      expect(r.canRon(1, Tile(900, TileType.pin5)), legal,
          reason: 'minimum $minimum');
    }
    // A red dragon pung on top: 2 faan on a discard, 3 on a self-pick.
    for (final (minimum, legal) in [(2, true), (3, false)]) {
      final r = _chickenTable(minimum);
      r.seats[1].flowers = [];
      r.seats[1].melds = [
        ...r.seats[1].melds,
        Meld(kind: MeldKind.triplet, low: TileType.chun, concealed: false),
      ];
      r.seats[1].hand.removeRange(0, 3);
      expect(r.canRon(1, Tile(900, TileType.pin5)), legal,
          reason: 'minimum $minimum');
    }
  });

  test('a ron claimed under the minimum cannot win', () {
    final r = _chickenTable(1);
    final win = Tile(900, TileType.pin5);
    r.seats[0].hand = [win];
    r.discard(0, win);
    if (r.phase == RoundPhase.callOffer) r.resolveCalls({1: CallType.ron});
    expect(r.result?.kind, isNot(RoundEndKind.ron));
  });

  test('the snapshot carries the minimum to the client', () {
    final round = Round(
      seed: 3,
      dealer: 0,
      roundWind: Wind.east,
      startingPoints: List.filled(4, 1000),
      ruleset: Ruleset.hongKong,
      minimumFaan: 3,
    );
    final wire = jsonDecode(
            jsonEncode(roundSnapshotToJson(round, reveal: (s) => s == 0)))
        as Map<String, dynamic>;
    expect(buildRoundFromSnapshot(wire, mySeat: 0).minimumFaan, 3);
    // An older server that never sent it means the old 0-faan table.
    wire.remove('minimumFaan');
    expect(buildRoundFromSnapshot(wire, mySeat: 0).minimumFaan, 0);
  });

  test('bots finish seeded games at every minimum and conserve chips', () {
    for (final minimum in HongKongRules.minimumFaanChoices) {
      for (var seed = 0; seed < 20; seed++) {
        final r = Round(
          ruleset: Ruleset.hongKong,
          minimumFaan: minimum,
          seed: seed,
          dealer: seed % 4,
          roundWind: Wind.east,
          startingPoints: List.filled(4, 1000),
        );
        final bots = List.generate(4, (i) => SimpleBot(seed + i));
        var steps = 0;
        while (!r.finished && steps++ < 500) {
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
        final score = r.result!.score;
        if (score != null && r.result!.kind != RoundEndKind.exhaustiveDraw) {
          expect(score.faan, greaterThanOrEqualTo(minimum),
              reason: 'min $minimum seed $seed');
        }
      }
    }
  });
}
