import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/logic/bot.dart';
import 'package:tilesense/logic/hand_parse.dart';
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

  test('after riichi a discard is forced to tsumogiri (the drawn tile)', () {
    // Find a seed where the dealer can declare riichi on the first draw.
    for (var seed = 0; seed < 200; seed++) {
      final round = Round(
        seed: seed,
        dealer: 0,
        roundWind: Wind.east,
        honba: 0,
        riichiSticks: 0,
        startingPoints: List.filled(4, 25000),
      );
      if (round.phase != RoundPhase.discarding || round.turn != 0) continue;
      if (!round.canRiichi(0)) continue;

      // Declare riichi with a wait-keeping discard.
      final tenpai = [
        for (final t in round.seats[0].hand)
          if (isTenpai(([...round.seats[0].hand]..remove(t)), openMelds: 0)) t
      ];
      if (tenpai.isEmpty) continue;
      round.discard(0, tenpai.first, declareRiichi: true);
      expect(round.seats[0].riichi, isTrue);

      // Advance to seat 0's next discard turn.
      var guard = 0;
      while (!(round.phase == RoundPhase.discarding && round.turn == 0) &&
          !round.finished &&
          guard++ < 200) {
        switch (round.phase) {
          case RoundPhase.discarding:
            round.discard(round.turn, round.seats[round.turn].drawn!);
            break;
          case RoundPhase.callOffer:
            round.resolveCalls({});
            break;
          case RoundPhase.drawing:
          case RoundPhase.finished:
            guard = 200;
            break;
        }
      }
      if (round.finished || round.turn != 0) continue;

      final drawn = round.seats[0].drawn!;
      // Try to cut a different tile from hand.
      final other = round.seats[0].hand.firstWhere((t) => t.id != drawn.id,
          orElse: () => drawn);
      final poolBefore = round.seats[0].pond.length;
      round.discard(0, other);
      // The drawn tile went out, not the one we asked for.
      expect(round.seats[0].pond[poolBefore].id, drawn.id,
          reason: 'riichi hand must tsumogiri');
      return; // one successful scenario is enough
    }
  });
}
