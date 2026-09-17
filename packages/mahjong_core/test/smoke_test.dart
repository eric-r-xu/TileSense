// Proves the engine is playable with plain `dart test` — no Flutter SDK
// involved — which is the property the multiplayer game server relies on.
import 'package:mahjong_core/mahjong_core.dart';
import 'package:test/test.dart';

void _playToCompletion(Ruleset ruleset) {
  final round = Round(
    seed: 42,
    dealer: 0,
    roundWind: Wind.east,
    startingPoints: List.filled(4, ruleset.startingPoints),
    ruleset: ruleset,
  );
  final bots = [for (var i = 0; i < 4; i++) SimpleBot(100 + i)];

  var guard = 0;
  while (!round.finished) {
    guard++;
    if (guard > 4000) {
      fail('round did not finish within the step guard');
    }
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
      case RoundPhase.drawing:
      case RoundPhase.finished:
        break;
    }
  }

  expect(round.finished, isTrue);
  expect(round.result, isNotNull);
}

void main() {
  test('riichi: four SimpleBots play a full hand to completion', () {
    _playToCompletion(Ruleset.riichi);
  });

  test('hong kong: four SimpleBots play a full hand to completion', () {
    _playToCompletion(Ruleset.hongKong);
  });
}
