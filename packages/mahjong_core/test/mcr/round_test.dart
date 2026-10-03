import 'package:mahjong_core/mahjong_core.dart';
import 'package:test/test.dart';

Round _play(int seed, {int dealer = 0}) {
  final round = Round(
    seed: seed,
    dealer: dealer,
    roundWind: Wind.east,
    startingPoints: List.filled(4, Ruleset.mcr.startingPoints),
    ruleset: Ruleset.mcr,
  );
  final bots = [for (var i = 0; i < 4; i++) SimpleBot(seed * 10 + i)];
  var guard = 0;
  while (!round.finished) {
    if (++guard > 4000) fail('seed $seed did not finish');
    switch (round.phase) {
      case RoundPhase.callOffer:
        final choices = <int, CallType>{};
        for (final opt in round.callOptions) {
          final c = bots[opt.seat]
              .decideCall(round, opt.seat, round.pendingDiscard!, opt.types);
          if (c != CallType.none) choices[opt.seat] = c;
        }
        round.resolveCalls(choices);
      case RoundPhase.discarding:
        final seat = round.turn;
        expect(round.canRiichi(seat), isFalse);
        final decision = bots[seat].decideTurn(round, seat);
        if (decision.tsumo) {
          round.declareTsumo(seat);
        } else if (decision.closedKan != null) {
          round.closedKan(seat, decision.closedKan!);
        } else if (decision.addedKan != null) {
          round.addKan(seat, decision.addedKan!);
        } else {
          round.discard(
              seat, decision.discard ?? round.legalDiscards(seat).first);
        }
      case RoundPhase.drawing:
      case RoundPhase.finished:
        break;
    }
  }
  return round;
}

void main() {
  test('starts at zero, 16 hands in a full game, 4 in practice', () {
    expect(Ruleset.mcr.startingPoints, 0);
    expect(Ruleset.mcr.handsPerGame(fullGame: true), 16);
    expect(Ruleset.mcr.handsPerGame(fullGame: false), 4);
    // Existing variants keep their schedule.
    for (final r in [Ruleset.riichi, Ruleset.hongKong, Ruleset.taiwanese]) {
      expect(r.handsPerGame(fullGame: true), 8);
    }
  });

  test('bot self-play: one winner, 8-point minimum, exact payments', () {
    var wins = 0;
    for (var seed = 1; seed <= 60; seed++) {
      final round = _play(seed, dealer: seed % 4);
      final r = round.result!;
      final deltas = r.pointDeltas;
      expect(deltas.values.fold<int>(0, (a, b) => a + b), 0,
          reason: 'seed $seed');
      if (r.kind == RoundEndKind.exhaustiveDraw) {
        expect(deltas.values.every((d) => d == 0), isTrue,
            reason: 'seed $seed');
        continue;
      }
      wins++;
      expect(r.winners, hasLength(1), reason: 'seed $seed');
      final w = r.winners.single;
      final score = r.score!;
      expect(score.valid, isTrue);
      expect(score.mcrQualifyingPoints, greaterThanOrEqualTo(8));
      final total = score.han;
      expect(total, score.mcrQualifyingPoints! + score.mcrFlowerPoints!);
      for (var i = 0; i < 4; i++) {
        if (i == w) continue;
        final expected = r.kind == RoundEndKind.tsumo
            ? total + 8
            : (i == r.loser ? total + 8 : 8);
        expect(deltas[i], -expected, reason: 'seed $seed seat $i');
      }
    }
    expect(wins, greaterThan(0), reason: 'bots should win some hands');
  });
}
