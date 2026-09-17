import 'dart:convert';

import 'package:mahjong_core/mahjong_core.dart';
import 'package:test/test.dart';

void main() {
  for (final ruleset in [Ruleset.riichi, Ruleset.hongKong]) {
    test('${ruleset.name}: round-trips a live snapshot through JSON for every viewer',
        () {
      final round = Round(
        seed: 7,
        dealer: 0,
        roundWind: Wind.east,
        startingPoints: List.filled(4, ruleset.startingPoints),
        ruleset: ruleset,
      );
      final bots = [for (var i = 0; i < 4; i++) SimpleBot(200 + i)];

      // Play a handful of turns so hands, ponds and (maybe) melds are non-trivial.
      for (var step = 0; step < 12 && !round.finished; step++) {
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
            final tile = decision.discard ?? round.legalDiscards(seat).first;
            round.discard(seat, tile, declareRiichi: decision.riichi);
          }
        }
      }

      for (var viewer = 0; viewer < 4; viewer++) {
        final json = roundSnapshotToJson(round, reveal: (s) => s == viewer);
        // Must be JSON-safe (encodable) — a redaction leak that puts a real
        // Tile object or similar non-primitive into another seat's slot would
        // throw here.
        final wire = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

        // No other seat's real tile ids should be observable by this viewer.
        for (final sj in wire['seats'] as List) {
          final map = sj as Map<String, dynamic>;
          final seat = map['seat'] as int;
          if (seat != viewer) {
            expect(map.containsKey('hand'), isFalse,
                reason: 'seat $seat leaked its hand to viewer $viewer');
          }
        }

        final mirror = buildRoundFromSnapshot(wire, mySeat: viewer);
        expect(mirror.seats[0].hand.length, round.seats[viewer].hand.length);
        expect(mirror.turn, (round.turn - viewer + 4) % 4);
        expect(mirror.ruleset, ruleset);

        // The viewer's own hand must be byte-for-byte the real hand.
        final realIds = round.seats[viewer].hand.map((t) => t.id).toSet();
        final mirrorIds = mirror.seats[0].hand.map((t) => t.id).toSet();
        expect(mirrorIds, realIds);
      }

      if (round.finished) {
        final json = roundSnapshotToJson(round, reveal: (s) => true);
        final wire = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
        final mirror = buildRoundFromSnapshot(wire, mySeat: 0);
        expect(mirror.result, isNotNull);
        expect(mirror.result!.kind, round.result!.kind);
      }
    });
  }
}
