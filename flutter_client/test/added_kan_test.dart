import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/logic/bot.dart';
import 'package:tilesense/logic/meld.dart';
import 'package:tilesense/logic/round.dart';
import 'package:tilesense/logic/tile.dart';

import 'helpers.dart';

/// A fresh round with every hand cleared to something harmless, so tests can
/// plant exactly the melds/hands they need without other seats accidentally
/// being tenpai on the tile under test.
Round _freshRound() {
  final round = Round(
    seed: 1,
    dealer: 0,
    roundWind: Wind.east,
    honba: 0,
    riichiSticks: 0,
    startingPoints: List.filled(4, 25000),
  );
  for (var i = 0; i < 4; i++) {
    round.seats[i]
      ..hand = parseTiles('19m 19p 19s ESWN')
      ..melds = []
      ..drawn = null;
  }
  return round;
}

void main() {
  group('addedKanTypes', () {
    test('finds an open pon this seat can extend', () {
      final round = _freshRound();
      round.seats[0]
        ..melds = [
          Meld(
            kind: MeldKind.triplet,
            low: TileType.pin5,
            concealed: false,
            calledFromSeatOffset: 1,
            tiles: parseTiles('555p'),
          ),
        ]
        ..hand = parseTiles('123m 456m 789m 5p 9s');

      expect(round.addedKanTypes(0), [TileType.pin5]);
    });

    test('is empty without a matching tile in hand', () {
      final round = _freshRound();
      round.seats[0]
        ..melds = [
          Meld(
            kind: MeldKind.triplet,
            low: TileType.pin5,
            concealed: false,
            tiles: parseTiles('555p'),
          ),
        ]
        ..hand = parseTiles('123m 456m 789m 9s');

      expect(round.addedKanTypes(0), isEmpty);
    });

    test('is empty while in riichi', () {
      final round = _freshRound();
      round.seats[0]
        ..melds = [
          Meld(
            kind: MeldKind.triplet,
            low: TileType.pin5,
            concealed: false,
            tiles: parseTiles('555p'),
          ),
        ]
        ..hand = parseTiles('123m 456m 789m 5p 9s')
        ..riichi = true;

      expect(round.addedKanTypes(0), isEmpty);
    });
  });

  test(
      'addKan upgrades the pon, reveals a new dora indicator, and draws a '
      'replacement when no one can chankan', () {
    final round = _freshRound();
    final seat = round.seats[0];
    seat.melds = [
      Meld(
        kind: MeldKind.triplet,
        low: TileType.pin5,
        concealed: false,
        calledFromSeatOffset: 1,
        tiles: parseTiles('555p'),
      ),
    ];
    seat.hand = parseTiles('123m 456m 789m 5p 9s');
    round.turn = 0;
    round.phase = RoundPhase.discarding;

    final doraCountBefore = round.wall.doraIndicators().length;

    round.addKan(0, TileType.pin5);

    expect(round.phase, RoundPhase.discarding,
        reason: 'no one could chankan, so the kan completes immediately');
    expect(round.turn, 0);
    expect(seat.melds, hasLength(1));
    expect(seat.melds.single.kind, MeldKind.kan);
    expect(seat.melds.single.addedKan, isTrue);
    expect(seat.melds.single.tiles, hasLength(4));
    expect(round.wall.doraIndicators().length, doraCountBefore + 1);
    expect(seat.drawn, isNotNull, reason: 'the rinshan replacement draw');
    expect(seat.hand.any((t) => t.type == TileType.pin5), isFalse,
        reason: 'the 4th 5p moved into the meld, not still in hand');
  });

  test('chankan lets another seat ron the tile before the kan completes', () {
    final round = _freshRound();
    round.seats[0]
      ..melds = [
        Meld(
          kind: MeldKind.triplet,
          low: TileType.haku,
          concealed: false,
          calledFromSeatOffset: 1,
          tiles: parseTiles('BBB'),
        ),
      ]
      ..hand = parseTiles('123m 456m 789m 9s B');
    // Tanki wait on haku with no other yaku at all — only the Chankan yaku
    // itself can validate this ron.
    round.seats[1]
      ..hand = parseTiles('123m 456m 789m 123p B')
      ..melds = [];
    round.turn = 0;
    round.phase = RoundPhase.discarding;

    round.addKan(0, TileType.haku);

    expect(round.phase, RoundPhase.callOffer);
    expect(round.callOptions, hasLength(1));
    expect(round.callOptions.single.seat, 1);
    expect(round.callOptions.single.types, {CallType.ron});

    round.resolveCalls({1: CallType.ron});

    expect(round.phase, RoundPhase.finished);
    expect(round.result!.kind, RoundEndKind.ron);
    expect(round.result!.winners, [1]);
    expect(round.result!.label, 'Chankan');
    expect(
      round.result!.score!.yaku.any((y) => y.name == 'Chankan'),
      isTrue,
    );
  });

  test('declining a chankan completes the kan and marks the misser furiten',
      () {
    final round = _freshRound();
    round.seats[0]
      ..melds = [
        Meld(
          kind: MeldKind.triplet,
          low: TileType.haku,
          concealed: false,
          calledFromSeatOffset: 1,
          tiles: parseTiles('BBB'),
        ),
      ]
      ..hand = parseTiles('123m 456m 789m 9s B');
    round.seats[1]
      ..hand = parseTiles('123m 456m 789m 123p B')
      ..melds = [];
    round.turn = 0;
    round.phase = RoundPhase.discarding;

    round.addKan(0, TileType.haku);
    expect(round.phase, RoundPhase.callOffer);

    round.resolveCalls({});

    expect(round.phase, RoundPhase.discarding);
    expect(round.turn, 0, reason: 'the kan-caller keeps their turn');
    expect(round.seats[0].melds.single.kind, MeldKind.kan);
    expect(round.seats[1].tempFuriten, isTrue,
        reason: 'passed up a tile that actually completed their wait');
  });

  test('SimpleBot always takes an available added kan', () {
    final round = _freshRound();
    round.seats[0]
      ..melds = [
        Meld(
          kind: MeldKind.triplet,
          low: TileType.pin5,
          concealed: false,
          tiles: parseTiles('555p'),
        ),
      ]
      ..hand = parseTiles('123m 456m 789m 5p 9s');
    round.turn = 0;
    round.phase = RoundPhase.discarding;

    final decision = SimpleBot(1).decideTurn(round, 0);
    expect(decision.addedKan, TileType.pin5);
  });
}
