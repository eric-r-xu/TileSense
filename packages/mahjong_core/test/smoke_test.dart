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

  test('taiwanese: four SimpleBots play a full hand to completion', () {
    _playToCompletion(Ruleset.taiwanese);
  });

  test(
      'taiwanese: deals 16 tiles to every seat, and 17 to the dealer once '
      'their opening draw lands', () {
    final round = Round(
      seed: 1,
      dealer: 0,
      roundWind: Wind.east,
      startingPoints: List.filled(4, Ruleset.taiwanese.startingPoints),
      ruleset: Ruleset.taiwanese,
    );
    // Every flower drawn — during the deal or the dealer's own opening draw
    // — is replaced one-for-one and moves to `flowers`, so `hand` alone
    // already holds exactly the real tiles: 16 dealt, 17 for the dealer once
    // their draw (however many flowers it chained through) lands.
    for (var seat = 0; seat < 4; seat++) {
      final expected = seat == round.dealer ? 17 : 16;
      expect(round.seats[seat].hand.length, expected, reason: 'seat $seat');
    }
  });

  test(
      'taiwanese: plays many seeds without ever winning below the minimum '
      'points, or with a hand shorter than 17 tiles', () {
    for (var seed = 0; seed < 30; seed++) {
      final round = Round(
        seed: seed,
        dealer: seed % 4,
        roundWind: Wind.east,
        startingPoints: List.filled(4, Ruleset.taiwanese.startingPoints),
        ruleset: Ruleset.taiwanese,
      );
      final bots = [for (var i = 0; i < 4; i++) SimpleBot(seed * 10 + i)];
      var guard = 0;
      while (!round.finished) {
        guard++;
        if (guard > 4000) fail('round did not finish within the step guard');
        switch (round.phase) {
          case RoundPhase.callOffer:
            final choices = <int, CallType>{};
            for (final opt in round.callOptions) {
              final c = bots[opt.seat].decideCall(
                  round, opt.seat, round.pendingDiscard!, opt.types);
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
      final result = round.result!;
      if (result.kind == RoundEndKind.ron || result.kind == RoundEndKind.tsumo) {
        for (final score in result.scores) {
          expect(score.valid, isTrue);
          expect(score.han, greaterThanOrEqualTo(TaiwaneseRules.defaultMinimumPoints));
        }
        // 5 melds and a pair (or seven pairs and a pung) is 17 tiles: each
        // meld reserves 3 (a kong's extra tile is balanced by its own
        // replacement draw, same as riichi and Hong Kong's 14-tile math), a
        // self-drawn winning tile is already counted in the winner's hand, a
        // ron'd one is not.
        for (final w in result.winners) {
          final seat = round.seats[w];
          final meldSlots = seat.melds.length * 3;
          final winTileCounted = result.kind == RoundEndKind.tsumo ? 0 : 1;
          expect(seat.hand.length + meldSlots + winTileCounted, 17,
              reason: 'seat $w\'s winning hand');
        }
      }
    }
  });
}
