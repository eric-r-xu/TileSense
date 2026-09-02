import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/logic/bot.dart';
import 'package:tilesense/logic/round.dart';
import 'package:tilesense/logic/tile.dart';

void main() {
  test('a seeded round played entirely by bots reaches an end state', () {
    for (var seed = 0; seed < 25; seed++) {
      final round = Round(
        seed: seed,
        dealer: 0,
        roundWind: Wind.east,
        honba: 0,
        riichiSticks: 0,
        startingPoints: List.filled(4, 25000),
      );
      final bots = [for (var i = 0; i < 4; i++) SimpleBot(seed + i)];

      var guard = 0;
      while (!round.finished && guard++ < 400) {
        switch (round.phase) {
          case RoundPhase.discarding:
            final d = bots[round.turn].decideTurn(round, round.turn);
            if (d.tsumo) {
              round.declareTsumo(round.turn);
            } else if (d.closedKan != null) {
              round.closedKan(round.turn, d.closedKan!);
            } else {
              round.discard(
                round.turn,
                d.discard ?? round.legalDiscards(round.turn).first,
                declareRiichi: d.riichi,
              );
            }
            break;
          case RoundPhase.callOffer:
            final choices = <int, CallType>{};
            for (final opt in round.callOptions) {
              final c = bots[opt.seat]
                  .decideCall(round, opt.seat, round.pendingDiscard!, opt.types);
              if (c != CallType.none) choices[opt.seat] = c;
            }
            round.resolveCalls(choices);
            break;
          case RoundPhase.drawing:
          case RoundPhase.finished:
            break;
        }
      }

      expect(round.finished, isTrue, reason: 'seed $seed did not finish');
      final total =
          round.seats.fold<int>(0, (a, s) => a + s.points) + round.riichiSticks * 1000;
      expect(total, 100000, reason: 'points not conserved for seed $seed');
    }
  });
}
