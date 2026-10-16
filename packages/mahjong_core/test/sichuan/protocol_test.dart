import 'dart:convert';

import 'package:mahjong_core/mahjong_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

Map<String, dynamic> wireFor(Round round, int viewer) =>
    jsonDecode(jsonEncode(
            roundSnapshotToJson(round, reveal: (s) => s == viewer)))
        as Map<String, dynamic>;

Round newRound(int seed) => Round(
      seed: seed,
      dealer: 0,
      roundWind: Wind.east,
      startingPoints: List.filled(4, 0),
      ruleset: Ruleset.sichuan,
    );

void declareAll(Round round) {
  for (var i = 0; i < 4; i++) {
    round.declareVoidSuit(i, round.suggestVoidSuit(i));
  }
}

/// One step of bot play; false once the hand is over.
bool step(Round round, List<SimpleBot> bots) {
  if (round.finished) return false;
  if (round.phase == RoundPhase.callOffer) {
    final choices = <int, CallType>{};
    for (final opt in round.callOptions) {
      final c = bots[opt.seat]
          .decideCall(round, opt.seat, round.pendingDiscard!, opt.types);
      if (c != CallType.none) choices[opt.seat] = c;
    }
    round.resolveCalls(choices);
  } else if (round.phase == RoundPhase.discarding) {
    final seat = round.turn;
    final decision = bots[seat].decideTurn(round, seat);
    if (decision.tsumo) {
      round.declareTsumo(seat);
    } else if (decision.closedKan != null) {
      round.closedKan(seat, decision.closedKan!);
    } else if (decision.addedKan != null) {
      round.addKan(seat, decision.addedKan!);
    } else {
      round.discard(seat, decision.discard ?? round.legalDiscards(seat).first);
    }
  }
  return !round.finished;
}

void main() {
  group('Sichuan over the wire', () {
    test('the table waits on void suits without saying which', () {
      final round = newRound(3);
      expect(round.phase, RoundPhase.choosingVoidSuit);
      round.declareVoidSuit(2, 1);

      for (var viewer = 0; viewer < 4; viewer++) {
        final wire = wireFor(round, viewer);
        for (final sj in (wire['seats'] as List).cast<Map<String, dynamic>>()) {
          final seat = sj['seat'] as int;
          expect(sj['voidDeclared'], seat == 2);
          // Only the seat itself is told its suit.
          expect(sj.containsKey('voidSuit'), seat == 2 && viewer == 2,
              reason: 'seat $seat\'s suit reached viewer $viewer');
        }
        final mirror = buildRoundFromSnapshot(wire, mySeat: viewer);
        expect(mirror.phase, RoundPhase.choosingVoidSuit);
        expect(mirror.awaitingVoidSuit, isTrue);
        // The mirror knows who has declared, by local seat.
        final local = (2 - viewer + 4) % 4;
        for (var s = 0; s < 4; s++) {
          expect(mirror.hasDeclaredVoidSuit(s), s == local);
        }
        expect(mirror.seats[local].voidSuit, viewer == 2 ? 1 : isNull);
      }
    });

    test('a suit shows to everyone only after its seat first discards', () {
      final round = newRound(5);
      declareAll(round);
      final bots = [for (var i = 0; i < 4; i++) SimpleBot(50 + i)];

      var steps = 0;
      while (steps++ < 200 && step(round, bots)) {
        for (var viewer = 0; viewer < 4; viewer++) {
          final wire = wireFor(round, viewer);
          for (final sj
              in (wire['seats'] as List).cast<Map<String, dynamic>>()) {
            final seat = sj['seat'] as int;
            final s = round.seats[seat];
            expect(sj['voidDeclared'], isTrue);
            expect(sj['voidRevealed'], s.voidRevealed);
            expect(sj.containsKey('voidSuit'), seat == viewer || s.voidRevealed,
                reason: 'seat $seat\'s suit, viewer $viewer, step $steps');
            if (seat != viewer) {
              expect(sj.containsKey('passedHuValue'), isFalse);
            }
          }
        }
      }
      // Some seat did discard, or the test proves nothing.
      expect(round.seats.any((s) => s.voidRevealed), isTrue);
    });

    test('a mirror enforces the same void-first discards as the server', () {
      final round = newRound(9);
      declareAll(round);
      final bots = [for (var i = 0; i < 4; i++) SimpleBot(90 + i)];

      for (var n = 0; n < 60 && step(round, bots); n++) {
        if (round.phase != RoundPhase.discarding) continue;
        final viewer = round.turn;
        final mirror = buildRoundFromSnapshot(wireFor(round, viewer), mySeat: viewer);
        expect(mirror.seats[0].voidSuit, round.seats[viewer].voidSuit);
        expect(mirror.mustDiscardVoid(0), round.mustDiscardVoid(viewer));
        expect({for (final t in mirror.legalDiscards(0)) t.id},
            {for (final t in round.legalDiscards(viewer)) t.id});
      }
    });

    test('out seats, Hu order and the wall survive the trip', () {
      final round = fixture(wallTiles: tiles('1p 2p 3p 4p 5p 6p 7p 8p'));
      // Seat 0 holds a pung and a pair wait: 111m 222m 333m 444m 5m, wins on 5m.
      setHand(round, 0, '111m 222m 333m 444m 5m', drawn: '5m');
      round.declareTsumo(0);
      expect(round.seats[0].out, isTrue);

      for (var viewer = 0; viewer < 4; viewer++) {
        final wire = wireFor(round, viewer);
        final mirror = buildRoundFromSnapshot(wire, mySeat: viewer);
        expect(mirror.ruleset, Ruleset.sichuan);
        expect(mirror.wall, isA<SichuanWall>());
        expect(mirror.wall.remaining, round.wall.remaining);
        for (var s = 0; s < 4; s++) {
          final server = (s + viewer) % 4;
          expect(mirror.seats[s].out, round.seats[server].out);
          expect(mirror.seats[s].huOrder, round.seats[server].huOrder);
          expect(mirror.seats[s].points, round.seats[server].points);
        }
        // The next player is the next seat still in the hand.
        expect((mirror.turn + viewer) % 4, round.turn);
      }
    });

    test('a finished hand carries its Hu list, payments and next dealer', () {
      final round = fixture(wallTiles: tiles('1p 2p 3p 4p'));
      setHand(round, 0, '111m 222m 333m 444m 5m', drawn: '5m');
      round.declareTsumo(0);
      // Three more Hu ends it: seats 1-3 each win by self-draw in turn.
      for (final seat in [1, 2]) {
        setHand(round, seat, '111m 222m 333m 444m 5m', drawn: '5m');
        round.turn = seat;
        round.phase = RoundPhase.discarding;
        round.declareTsumo(seat);
      }
      expect(round.finished, isTrue);
      final result = round.result!;
      expect(result.kind, RoundEndKind.bloodBattle);
      expect(result.sichuanHu.length, 3);

      for (var viewer = 0; viewer < 4; viewer++) {
        final wire = jsonDecode(jsonEncode(
                roundSnapshotToJson(round, reveal: (s) => true)))
            as Map<String, dynamic>;
        final mirror = buildRoundFromSnapshot(wire, mySeat: viewer);
        int local(int server) => (server - viewer + 4) % 4;
        final got = mirror.result!;
        expect(got.kind, RoundEndKind.bloodBattle);
        expect(got.nextDealer, local(result.nextDealer!));
        expect([for (final h in got.sichuanHu) h.seat],
            [for (final h in result.sichuanHu) local(h.seat)]);
        expect([for (final h in got.sichuanHu) h.score.points],
            [for (final h in result.sichuanHu) h.score.points]);
        expect([for (final h in got.sichuanHu) h.selfDrawn],
            [for (final h in result.sichuanHu) h.selfDrawn]);
        expect(got.sichuanPayments.length, result.sichuanPayments.length);
        for (var i = 0; i < got.sichuanPayments.length; i++) {
          final a = got.sichuanPayments[i];
          final b = result.sichuanPayments[i];
          expect((a.kind, a.from, a.to, a.points, a.label),
              (b.kind, local(b.from), local(b.to), b.points, b.label));
        }
        expect(got.pointDeltas[0], result.pointDeltas[viewer]);
      }
    });

    test('an old snapshot with no Sichuan fields still loads', () {
      final round = newRound(1);
      declareAll(round);
      final wire = wireFor(round, 0);
      for (final sj in (wire['seats'] as List).cast<Map<String, dynamic>>()) {
        for (final k in [
          'voidDeclared',
          'voidRevealed',
          'voidSuit',
          'out',
          'huOrder',
          'passedHuValue',
        ]) {
          sj.remove(k);
        }
      }
      final mirror = buildRoundFromSnapshot(wire, mySeat: 0);
      expect(mirror.seats.every((s) => !s.out), isTrue);
    });
  });
}
