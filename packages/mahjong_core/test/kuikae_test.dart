import 'dart:convert';

import 'package:mahjong_core/mahjong_core.dart';
import 'package:test/test.dart';

import 'sanma/helpers.dart' show tiles;

Round offer(String hand, TileType called,
    {Ruleset ruleset = Ruleset.riichi, List<Meld> melds = const []}) {
  final round = Round(
    seed: 7,
    dealer: 0,
    roundWind: Wind.east,
    startingPoints: List.filled(4, ruleset.startingPoints),
    ruleset: ruleset,
  );
  for (final seat in round.seats) {
    seat.hand = tiles('19m 1258p 147s 1356z');
    seat.drawn = null;
    seat.melds = [];
  }
  round.seats[0]
    ..hand = tiles(hand)
    ..melds = List.of(melds);
  final fed = Tile(99999, called);
  round.seats[3].hand.add(fed);
  round.seats[3].drawn = fed;
  round.turn = 3;
  round.phase = RoundPhase.discarding;
  round.discard(3, fed);
  return round;
}

Set<TileType> legalTypes(Round round) =>
    round.legalDiscards(0).map((t) => t.type).toSet();

void main() {
  for (final ruleset in [Ruleset.riichi, Ruleset.sanma]) {
    for (final red in [false, true]) {
      test(
          '${ruleset.name}: pon blocks the remaining ${red ? 'red' : 'ordinary'} '
          'copy and rejects it without changing the table', () {
        final round =
            offer('555p 19m 28s 136p 123z', TileType.pin5, ruleset: ruleset);
        final hand = round.seats[0].hand;
        final last = hand.lastIndexWhere((t) => t.type == TileType.pin5);
        hand[last] = Tile(hand[last].id, TileType.pin5, aka: red);
        round.resolveCalls({0: CallType.pon});

        final forbidden =
            round.seats[0].hand.singleWhere((t) => t.type == TileType.pin5);
        expect(forbidden.aka, red);
        expect(round.legalDiscards(0), isNot(contains(forbidden)));
        expect(round.seats[1].kuikaeForbidden, isEmpty);
        final before =
            jsonEncode(roundSnapshotToJson(round, reveal: (_) => true));
        expect(() => round.discard(0, forbidden), throwsStateError);
        expect(jsonEncode(roundSnapshotToJson(round, reveal: (_) => true)),
            before);
        final decision = SimpleBot(9).decideTurn(round, 0);
        expect(round.legalDiscards(0), contains(decision.discard));

        round.discard(0, round.legalDiscards(0).first);
        expect(round.seats[0].kuikaeForbidden, isEmpty);
        expect(round.legalDiscards(0), contains(forbidden),
            reason: 'the restriction lasts for one discard only');
      });
    }
  }

  for (final (called, low, forbidden, allowed) in [
    (
      TileType.pin1,
      TileType.pin1,
      {TileType.pin1, TileType.pin4},
      TileType.ton
    ),
    (
      TileType.pin4,
      TileType.pin2,
      {TileType.pin1, TileType.pin4},
      TileType.ton
    ),
    (TileType.pin3, TileType.pin2, {TileType.pin3}, TileType.pin1),
  ]) {
    test(
        'chi ${called.name} into ${low.name}: same-type and alternate-end '
        'restrictions follow the chosen run', () {
      final round = offer('12345p 19m 147s 125z', called);
      round.resolveCalls({0: CallType.chi}, chiLow: {0: low});
      expect(round.seats[0].kuikaeForbidden, forbidden);
      expect(legalTypes(round).intersection(forbidden), isEmpty);
      expect(legalTypes(round), contains(allowed));
      for (final tile
          in round.seats[0].hand.where((t) => forbidden.contains(t.type))) {
        expect(() => round.discard(0, tile), throwsStateError);
      }
    });
  }

  test('different chi choices on the same discard have different restrictions',
      () {
    for (final low in [TileType.pin2, TileType.pin3, TileType.pin4]) {
      final round = offer('123456p 19m 147s 12z', TileType.pin4);
      round.resolveCalls({0: CallType.chi}, chiLow: {0: low});
      expect(legalTypes(round).contains(TileType.pin1), low != TileType.pin2);
      expect(round.seats[0].kuikaeForbidden.contains(TileType.pin7),
          low == TileType.pin4);
    }
  });

  test('edge chi never wraps the restriction into another suit or honors', () {
    expect(kuikaeForbiddenDiscards(TileType.pin7, chiLow: TileType.pin7),
        {TileType.pin7});
    expect(kuikaeForbiddenDiscards(TileType.pin3, chiLow: TileType.pin1),
        {TileType.pin3});
  });

  test('a chi with no legal following discard is not offered', () {
    final melds = [
      for (final type in [TileType.ton, TileType.nan, TileType.haku])
        Meld(kind: MeldKind.triplet, low: type, concealed: false),
    ];
    final round = offer('2344p', TileType.pin1, melds: melds);
    expect(round.chiSequences(0, Tile(99999, TileType.pin1)), isEmpty);
    expect(round.callOptions.where((o) => o.seat == 0).expand((o) => o.types),
        isNot(contains(CallType.chi)));
  });

  for (final ruleset in [Ruleset.riichi, Ruleset.sanma]) {
    test('${ruleset.name}: kan and kita cannot bypass the required discard',
        () {
      final round =
          offer('555p 2222s 19m 146p 4z', TileType.pin5, ruleset: ruleset);
      round.resolveCalls({0: CallType.pon});
      expect(round.closedKanTypes(0), isEmpty);
      expect(round.addedKanTypes(0), isEmpty);
      expect(() => round.closedKan(0, TileType.sou2), throwsStateError);
      expect(() => round.addKan(0, TileType.pin5), throwsStateError);
      expect(round.canKita(0), isFalse);
      expect(() => round.declareKita(0), throwsStateError);
      expect(round.seats[0].kuikaeForbidden, {TileType.pin5});
    });

    test('${ruleset.name}: open kan draws a replacement without kuikae', () {
      final round =
          offer('555p 19m 28s 136p 123z', TileType.pin5, ruleset: ruleset);
      round.resolveCalls({0: CallType.kan});
      expect(round.seats[0].drawn, isNotNull);
      expect(round.seats[0].kuikaeForbidden, isEmpty);
      expect(round.legalDiscards(0), round.seats[0].hand);
    });

    test('${ruleset.name}: snapshots preserve the caller restriction privately',
        () {
      final round =
          offer('555p 19m 28s 136p 123z', TileType.pin5, ruleset: ruleset);
      round.resolveCalls({0: CallType.pon});
      for (final viewer in ruleset.activeSeats) {
        final wire = jsonDecode(jsonEncode(
                roundSnapshotToJson(round, reveal: (seat) => seat == viewer)))
            as Map<String, dynamic>;
        final mirror = buildRoundFromSnapshot(wire, mySeat: viewer);
        final localCaller = ruleset.relativeSeat(0, viewer);
        if (viewer == 0) {
          expect(legalTypes(mirror), legalTypes(round));
          expect(mirror.seats[localCaller].kuikaeForbidden, {TileType.pin5});
        } else {
          expect(
              (wire['seats'] as List)[0], isNot(contains('kuikaeForbidden')));
          expect(mirror.seats[localCaller].kuikaeForbidden, isEmpty);
        }
      }
      final older = roundSnapshotToJson(round, reveal: (_) => true);
      for (final seat in older['seats'] as List) {
        (seat as Map).remove('kuikaeForbidden');
      }
      expect(buildRoundFromSnapshot(older, mySeat: 0).seats[0].kuikaeForbidden,
          isEmpty);
    });
  }

  test('the restriction is gone on the caller\'s next draw', () {
    final round = offer('1234p 19m 147s 1256z', TileType.pin1);
    round.resolveCalls({0: CallType.chi}, chiLow: {0: TileType.pin1});
    final cut = round.seats[0].hand.firstWhere((t) => t.type == TileType.ton);
    round.discard(0, cut);
    while (round.turn != 0 || round.phase != RoundPhase.discarding) {
      if (round.phase == RoundPhase.callOffer) {
        round.resolveCalls({});
      } else {
        round.discard(round.turn, round.seats[round.turn].drawn!);
      }
    }
    expect(round.seats[0].kuikaeForbidden, isEmpty);
    expect(legalTypes(round), containsAll([TileType.pin1, TileType.pin4]));
  });

  test('Hong Kong calls retain their unrestricted following discards', () {
    final round =
        offer('1234p 19m 147s 1256z', TileType.pin1, ruleset: Ruleset.hongKong);
    round.resolveCalls({0: CallType.chi}, chiLow: {0: TileType.pin1});
    expect(round.seats[0].kuikaeForbidden, isEmpty);
    expect(legalTypes(round), containsAll([TileType.pin1, TileType.pin4]));
  });
}
