import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/logic/meld.dart';
import 'package:tilesense/logic/round.dart';
import 'package:tilesense/logic/tile.dart';

import 'helpers.dart';

/// Chi in the round engine: who may call it, which run gets taken, and where
/// it sits in the call priority order.
void main() {
  Round freshRound() => Round(
        seed: 1,
        dealer: 0,
        roundWind: Wind.east,
        honba: 0,
        riichiSticks: 0,
        startingPoints: List.filled(4, 25000),
      );

  /// Seat 3 cuts [fed]; seat 0 sits directly after it, so seat 0 is the only
  /// seat that may chi.
  (Round, Tile) discardFromLeftOf0({
    required String seat0Hand,
    TileType fed = TileType.pin5,
  }) {
    final round = freshRound();
    round.seats[0]
      ..hand = parseTiles(seat0Hand)
      ..drawn = null
      ..melds = [];
    final fedTile = Tile(900, fed);
    round.seats[3]
      ..hand = [...parseTiles('123m 456m 789m 111s 2p'), fedTile]
      ..drawn = fedTile;
    round.turn = 3;
    round.phase = RoundPhase.discarding;
    round.discard(3, fedTile);
    return (round, fedTile);
  }

  Set<CallType> typesFor(Round round, int seat) =>
      round.callOptions
          .where((o) => o.seat == seat)
          .expand((o) => o.types)
          .toSet();

  group('who may chi', () {
    test('only the seat immediately after the discarder', () {
      // Both seat 0 and seat 1 hold 4p6p, but seat 3 discarded, so only
      // seat 0 — its kamicha — is offered the chi.
      final round = freshRound();
      for (final seat in [0, 1]) {
        round.seats[seat]
          ..hand = parseTiles('46p 123m 456m 789m 99s')
          ..drawn = null
          ..melds = [];
      }
      final fed = Tile(900, TileType.pin5);
      round.seats[3]
        ..hand = [...parseTiles('123m 456m 789m 111s 2p'), fed]
        ..drawn = fed;
      round.turn = 3;
      round.phase = RoundPhase.discarding;
      round.discard(3, fed);

      expect(typesFor(round, 0), contains(CallType.chi));
      expect(typesFor(round, 1), isNot(contains(CallType.chi)));
    });

    test('not while in riichi', () {
      final round = freshRound();
      round.seats[0]
        ..hand = parseTiles('46p 123m 456m 789m 99s')
        ..drawn = null
        ..melds = []
        ..riichi = true;
      final fed = Tile(900, TileType.pin5);
      round.seats[3]
        ..hand = [...parseTiles('123m 456m 789m 111s 2p'), fed]
        ..drawn = fed;
      round.turn = 3;
      round.phase = RoundPhase.discarding;
      round.discard(3, fed);

      expect(typesFor(round, 0), isNot(contains(CallType.chi)));
    });

    test('honours can never be chi\'d', () {
      final (round, _) = discardFromLeftOf0(
        seat0Hand: '123m 456m 789m 99s RR',
        fed: TileType.chun,
      );
      expect(typesFor(round, 0), isNot(contains(CallType.chi)));
    });

    test('a run that would wrap past 9 is not offered', () {
      // 8p9p + a 1p cannot make a run.
      final (round, _) = discardFromLeftOf0(
        seat0Hand: '89p 123m 456m 789m 99s',
        fed: TileType.pin1,
      );
      expect(typesFor(round, 0), isNot(contains(CallType.chi)));
    });
  });

  group('choosing the run', () {
    test('every possible run is listed', () {
      final (round, fed) = discardFromLeftOf0(seat0Hand: '34567p 123m 456m 99s');
      // Offered 5p while holding 34567p: 345p, 456p and 567p are all makeable.
      expect(
        round.chiSequences(0, fed).toSet(),
        {TileType.pin3, TileType.pin4, TileType.pin5},
      );
    });

    test('the requested run is the one taken', () {
      final (round, _) = discardFromLeftOf0(seat0Hand: '34567p 123m 456m 99s');
      round.resolveCalls(
        {0: CallType.chi},
        chiLow: {0: TileType.pin5}, // 5p6p7p, spending the 6p and 7p
      );

      final meld = round.seats[0].melds.single;
      expect(meld.kind, MeldKind.sequence);
      expect(meld.low, TileType.pin5);
      expect(meld.concealed, isFalse);
      expect(meld.types, [TileType.pin5, TileType.pin6, TileType.pin7]);
    });

    test('an impossible request falls back to a run the hand can make', () {
      final (round, _) = discardFromLeftOf0(seat0Hand: '46p 123m 456m 789m 99s');
      round.resolveCalls(
        {0: CallType.chi},
        chiLow: {0: TileType.sou1}, // nonsense
      );
      expect(round.seats[0].melds.single.low, TileType.pin4);
    });
  });

  group('applying the call', () {
    test('takes the tile, spends the hand tiles, and passes the turn', () {
      final (round, fed) = discardFromLeftOf0(seat0Hand: '46p 123m 456m 789m 99s');
      final pondBefore = round.seats[3].pond.length;

      round.resolveCalls({0: CallType.chi}, chiLow: {0: TileType.pin4});

      final seat = round.seats[0];
      expect(seat.melds.single.types,
          [TileType.pin4, TileType.pin5, TileType.pin6]);
      expect(seat.melds.single.tiles, contains(fed));
      // The 4p and 6p left the concealed hand.
      expect(seat.hand.where((t) => t.type == TileType.pin4), isEmpty);
      expect(seat.hand.where((t) => t.type == TileType.pin6), isEmpty);
      // The tile was claimed out of the discarder's pond.
      expect(round.seats[3].pond.length, pondBefore - 1);
      // The caller is now on turn, and discards rather than draws.
      expect(round.turn, 0);
      expect(round.phase, RoundPhase.discarding);
      expect(seat.drawn, isNull);
      expect(seat.closed, isFalse);
    });
  });

  group('call priority', () {
    test('pon beats chi', () {
      final round = freshRound();
      round.seats[0]
        ..hand = parseTiles('46p 123m 456m 789m 99s')
        ..drawn = null
        ..melds = [];
      round.seats[1]
        ..hand = parseTiles('55p 123m 456m 789m 99s')
        ..drawn = null
        ..melds = [];
      final fed = Tile(900, TileType.pin5);
      round.seats[3]
        ..hand = [...parseTiles('123m 456m 789m 111s 2p'), fed]
        ..drawn = fed;
      round.turn = 3;
      round.phase = RoundPhase.discarding;
      round.discard(3, fed);

      round.resolveCalls(
        {0: CallType.chi, 1: CallType.pon},
        chiLow: {0: TileType.pin4},
      );

      expect(round.seats[1].melds.single.kind, MeldKind.triplet);
      expect(round.seats[0].melds, isEmpty);
      expect(round.turn, 1);
    });
  });

  test('a chi-only offer still opens (and closes) the call window', () {
    final (round, _) = discardFromLeftOf0(seat0Hand: '46p 123m 456m 789m 99s');
    expect(round.phase, RoundPhase.callOffer);

    round.resolveCalls({}); // everyone passes
    expect(round.phase, isNot(RoundPhase.callOffer));
    expect(round.seats[0].melds, isEmpty);
  });
}
