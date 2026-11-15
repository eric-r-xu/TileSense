import 'package:mahjong_core/mahjong_core.dart';
import 'package:test/test.dart';

import 'sanma/helpers.dart' show tiles;

Round settle({
  required Ruleset ruleset,
  required int discarder,
  required List<int> winners,
  int honba = 3,
  int sticks = 2,
}) {
  final round = Round(
    seed: 7,
    dealer: 0,
    roundWind: Wind.east,
    honba: honba,
    riichiSticks: sticks,
    startingPoints: List.filled(4, ruleset.startingPoints),
    ruleset: ruleset,
  );
  for (final seat in round.seats) {
    seat.hand = [];
    seat.drawn = null;
    seat.melds = [];
  }
  // Distinct legal hands on the same East tanki: two pure straights and
  // one chanta, with no fifth copies among the planted winning hands.
  const hands = [
    '123p 456p 789p 456s 1z',
    '123s 456s 789s 456p 1z',
    '123p 789p 123s 789s 1z',
  ];
  for (var i = 0; i < winners.length; i++) {
    round.seats[winners[i]].hand = tiles(hands[i]);
  }
  final discarded = tiles('1z').single;
  round.seats[discarder].hand = [
    ...tiles('222z 333z 444z 555z 6z'),
    discarded,
  ];
  round.seats[discarder].drawn = discarded;
  round.turn = discarder;
  round.phase = RoundPhase.discarding;
  round.discard(discarder, discarded);
  for (final winner in winners) {
    expect(
        round.callOptions
            .any((o) => o.seat == winner && o.types.contains(CallType.ron)),
        isTrue);
  }
  // The requested winner order deliberately need not match turn order.
  round.resolveCalls({for (final winner in winners) winner: CallType.ron});
  return round;
}

void expectPayments(Round round, int discarder, List<int> orderedWinners,
    {int honba = 3, int sticks = 2}) {
  final result = round.result!;
  expect(result.winners, orderedWinners);
  var handPayments = 0;
  for (var i = 0; i < orderedWinners.length; i++) {
    final winner = orderedWinners[i];
    final handPoints = result.scores[i].points;
    handPayments += handPoints;
    expect(result.pointDeltas[winner],
        handPoints + (i == 0 ? honba * 300 + sticks * 1000 : 0));
  }
  expect(result.pointDeltas[discarder], -handPayments - honba * 300);
  expect(result.pointDeltas.values.reduce((a, b) => a + b), sticks * 1000);
  expect(round.riichiSticks, 0);
  for (final seat in round.ruleset.activeSeats) {
    expect(round.seats[seat].points,
        round.ruleset.startingPoints + result.pointDeltas[seat]!);
  }
}

void main() {
  for (final ruleset in [Ruleset.riichi, Ruleset.sanma]) {
    for (final discarder in ruleset.activeSeats) {
      test(
          '${ruleset.name}: double ron after seat $discarder pays honba once '
          'to the nearest winner, including wraparound', () {
        final near = ruleset.nextSeat(discarder);
        final far = ruleset.nextSeat(near);
        final round = settle(
            ruleset: ruleset, discarder: discarder, winners: [far, near]);
        expectPayments(round, discarder, [near, far]);
      });
    }

    test('${ruleset.name}: single ron still receives all honba', () {
      final round = settle(ruleset: ruleset, discarder: 3, winners: [1]);
      expectPayments(round, 3, [1]);
    });
  }

  for (var discarder = 0; discarder < 4; discarder++) {
    test('triple ron after seat $discarder pays only one honba bonus', () {
      final ordered = [for (var n = 1; n < 4; n++) (discarder + n) % 4];
      final round = settle(
          ruleset: Ruleset.riichi,
          discarder: discarder,
          winners: ordered.reversed.toList());
      expectPayments(round, discarder, ordered);
    });
  }

  test('zero honba leaves hand payments and stick collection intact', () {
    final round = settle(
        ruleset: Ruleset.riichi, discarder: 2, winners: [1, 3], honba: 0);
    expectPayments(round, 2, [3, 1], honba: 0);
  });

  test('the nearest winner receives honba even when the next seat did not win',
      () {
    final round =
        settle(ruleset: Ruleset.riichi, discarder: 0, winners: [3, 2]);
    expectPayments(round, 0, [2, 3]);
  });
}
