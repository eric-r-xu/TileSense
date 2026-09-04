import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/logic/bot.dart';
import 'package:tilesense/logic/hand_parse.dart';
import 'package:tilesense/logic/round.dart';
import 'package:tilesense/logic/tile.dart';

import 'helpers.dart';

/// A fresh round with a closed tanyao/pinfu tenpai on 5p/8p planted on seat 1,
/// and seat 2 armed to discard [feed] (defaults to 5p, one of the waits) as its
/// just-drawn tile. Returns the round and the exact tile seat 2 will cut.
(Round, Tile) _furitenScenario({required bool waiterRiichi, TileType feed = TileType.pin5}) {
  final round = Round(
    seed: 1,
    dealer: 0,
    roundWind: Wind.east,
    honba: 0,
    riichiSticks: 0,
    startingPoints: List.filled(4, 25000),
  );
  round.seats[1].hand = sortByType(parseTiles('234m 567m 234p 67p 88s'));
  round.seats[1].melds = [];
  round.seats[1].riichi = waiterRiichi;

  final feedTile = Tile(900, feed);
  round.seats[2].hand = [...parseTiles('123m 456m 789m 111s 2p'), feedTile];
  round.seats[2].drawn = feedTile;
  round.turn = 2;
  round.phase = RoundPhase.discarding;
  return (round, feedTile);
}

/// Run the call phase with everyone passing, if a discard opened one.
void _passAnyCalls(Round round) {
  if (round.phase == RoundPhase.callOffer) round.resolveCalls({});
}

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

  test('a wait tile in your own discards is furiten and bars ron on any wait',
      () {
    final (round, _) = _furitenScenario(waiterRiichi: false);
    // Sanity: the planted hand is tenpai on 5p / 8p and can normally ron.
    expect(round.isFuriten(1), isFalse);
    expect(round.canRon(1, Tile(1, TileType.pin5)), isTrue);

    // Seat 1 has itself discarded an 8p earlier in the round.
    round.seats[1].allDiscards.add(Tile(2, TileType.pin8));

    expect(round.isFuriten(1), isTrue);
    // Furiten bars ron on *every* wait, not just the discarded one.
    expect(round.canRon(1, Tile(3, TileType.pin5)), isFalse);
    expect(round.canRon(1, Tile(4, TileType.pin8)), isFalse);
  });

  test('passing up a winning discard causes temporary furiten until next draw',
      () {
    final (round, feed) = _furitenScenario(waiterRiichi: false);
    expect(round.canRon(1, feed), isTrue);

    round.discard(2, feed); // seat 2 cuts a 5p...
    _passAnyCalls(round); // ...and nobody claims it.

    expect(round.seats[1].tempFuriten, isTrue);
    expect(round.seats[1].riichiFuriten, isFalse,
        reason: 'not in riichi, so the furiten is only temporary');
    expect(round.isFuriten(1), isTrue);
    expect(round.canRon(1, Tile(5, TileType.pin5)), isFalse);
    expect(round.canRon(1, Tile(6, TileType.pin8)), isFalse,
        reason: 'temporary furiten also bars the other side of the wait');

    // Temporary furiten clears once seat 1 draws again.
    var guard = 0;
    while (!round.finished &&
        !(round.turn == 1 && round.phase == RoundPhase.discarding) &&
        guard++ < 40) {
      if (round.phase == RoundPhase.callOffer) {
        round.resolveCalls({});
      } else if (round.phase == RoundPhase.discarding) {
        round.discard(round.turn, round.seats[round.turn].drawn!);
      } else {
        break;
      }
    }
    if (round.turn == 1 && !round.finished) {
      expect(round.seats[1].tempFuriten, isFalse,
          reason: 'a fresh draw ends temporary furiten');
    }
  });

  test('a riichi hand that passes a winning discard is permanently furiten', () {
    final (round, feed) = _furitenScenario(waiterRiichi: true);
    expect(round.canRon(1, feed), isTrue);

    round.discard(2, feed);
    _passAnyCalls(round);

    expect(round.seats[1].riichiFuriten, isTrue);
    expect(round.isFuriten(1), isTrue);
    expect(round.canRon(1, Tile(7, TileType.pin8)), isFalse);

    // Even after the temporary flag would clear on a later draw, riichi
    // furiten holds for the rest of the round.
    round.seats[1].tempFuriten = false;
    expect(round.isFuriten(1), isTrue,
        reason: 'riichi furiten never clears');
    expect(round.canRon(1, Tile(8, TileType.pin5)), isFalse);
  });

  test('an exhaustive draw reports every tenpai seat with a real wait', () {
    var sawDraw = false;
    for (var seed = 0; seed < 120 && !sawDraw; seed++) {
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
              round.discard(round.turn,
                  d.discard ?? round.legalDiscards(round.turn).first,
                  declareRiichi: d.riichi);
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

      final r = round.result!;
      if (r.kind != RoundEndKind.exhaustiveDraw) continue;
      sawDraw = true;

      // The score screen reveals exactly these seats' hands and their waits, so
      // each must genuinely be tenpai with a non-empty wait to display.
      for (final seat in r.tenpaiAtDraw) {
        final s = round.seats[seat];
        final waits = waitTiles(s.hand, openMelds: s.melds.length);
        expect(waits, isNotEmpty,
            reason: 'seed $seed seat $seat listed tenpai but has no wait');
      }
      // And nobody tenpai was left off the list.
      for (var seat = 0; seat < 4; seat++) {
        final s = round.seats[seat];
        final tenpai = isTenpai(s.hand, openMelds: s.melds.length);
        expect(r.tenpaiAtDraw.contains(seat), tenpai,
            reason: 'seed $seed seat $seat tenpai=$tenpai but list membership '
                'disagrees');
      }
    }
    expect(sawDraw, isTrue, reason: 'no exhaustive draw in the first 120 seeds');
  });
}
