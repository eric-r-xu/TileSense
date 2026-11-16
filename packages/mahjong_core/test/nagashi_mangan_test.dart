import 'dart:convert';

import 'package:mahjong_core/mahjong_core.dart';
import 'package:test/test.dart';

import 'sanma/helpers.dart' show tiles;

Round fixture({
  int dealer = 0,
  int honba = 0,
  int sticks = 0,
  Ruleset ruleset = Ruleset.riichi,
  TileWall? wall,
}) {
  final round = Round.posed(
    dealer: dealer,
    roundWind: Wind.east,
    honba: honba,
    riichiSticks: sticks,
    wall: wall ??
        (ruleset.isSanma
            ? SanmaWall.posed(remaining: 0, dora: const [])
            : Wall.posed(remaining: 0, dora: const [])),
    startingPoints: [
      for (var i = 0; i < 4; i++)
        ruleset.seatIsActive(i)
            ? ruleset.startingPoints - (i == 0 ? sticks * 1000 : 0)
            : 0,
    ],
    ruleset: ruleset,
  );
  for (final seat in ruleset.activeSeats) {
    round.seats[seat].hand = tiles('19m 1258p 147s 1356z');
  }
  return round;
}

void river(Round round, int seat, String text) {
  final discards = tiles(text);
  round.seats[seat].pond = List.of(discards);
  round.seats[seat].allDiscards.addAll(discards);
}

RoundResult finish(Round round) {
  round.beginPosedPlay();
  expect(round.finished, isTrue);
  return round.result!;
}

void main() {
  for (var dealer = 0; dealer < 4; dealer++) {
    for (var recipient = 0; recipient < 4; recipient++) {
      test('dealer $dealer, recipient $recipient: mangan tsumo at a draw', () {
        final round = fixture(dealer: dealer);
        river(round, recipient, '19m 19p 19s 1234567z');
        final result = finish(round);
        expect(result.kind, RoundEndKind.exhaustiveDraw);
        expect(result.isNagashiMangan, isTrue);
        expect(result.winners, [recipient]);
        expect(result.tenpaiAtDraw, isEmpty);
        expect(result.score, isNull);
        expect(result.scores, isEmpty);
        expect(result.winTiles, isEmpty);
        expect(result.pointDeltas, {
          for (var seat = 0; seat < 4; seat++)
            seat: seat == recipient
                ? (recipient == dealer ? 12000 : 8000)
                : (recipient == dealer || seat == dealer ? -4000 : -2000),
        });
        expect(round.seats.fold<int>(0, (sum, s) => sum + s.points), 100000);
      });
    }
  }

  test('nagashi replaces tenpai payments and leaves honba/sticks out', () {
    final round = fixture(honba: 3, sticks: 2);
    round.seats[0].hand = tiles('234m 567m 234p 67p 88s');
    river(round, 1, '19m 123z');
    final result = finish(round);
    expect(result.tenpaiAtDraw, [0]);
    expect(result.pointDeltas, {0: -4000, 1: 8000, 2: -2000, 3: -2000});
    expect(round.riichiSticks, 2);
    expect(round.honba, 3);
    expect(round.seats.fold<int>(2000, (sum, s) => sum + s.points), 100000);
  });

  for (final (recipients, deltas) in [
    ([1, 2], [-8000, 6000, 6000, -4000]),
    ([0, 1], [8000, 4000, -6000, -6000]),
    ([0, 1, 2, 3], [0, 0, 0, 0]),
  ]) {
    test('multiple recipients $recipients pay each other independently', () {
      final round = fixture();
      for (final seat in recipients) {
        river(round, seat, '19m 123z');
      }
      final result = finish(round);
      expect(result.winners, recipients);
      expect(result.pointDeltas, {for (var i = 0; i < 4; i++) i: deltas[i]});
    });
  }

  test('an empty river does not qualify; normal tenpai payments still apply',
      () {
    final round = fixture();
    round.seats[0].hand = tiles('234m 567m 234p 67p 88s');
    final result = finish(round);
    expect(result.isNagashiMangan, isFalse);
    expect(result.winners, isEmpty);
    expect(result.pointDeltas, {0: 3000, 1: -1000, 2: -1000, 3: -1000});
  });

  test('a middle tile anywhere in the river disqualifies', () {
    final round = fixture();
    river(round, 1, '1m 5p 9s 123z');
    expect(finish(round).isNagashiMangan, isFalse);
  });

  for (final call in [CallType.chi, CallType.pon, CallType.kan]) {
    test('$call on a discard disqualifies only that discarder', () {
      // Open kan needs a live tile to replenish the dead wall. Its replacement
      // draw consumes that last live tile, so the caller's discard ends play.
      final wall = Wall(1);
      while (wall.remaining > (call == CallType.kan ? 1 : 0)) {
        wall.drawLive();
      }
      final round = fixture(wall: wall);
      river(round, 0, '19m');
      river(round, 2, '19p 123z');
      final discard = tiles(call == CallType.chi ? '1m' : '1z').single;
      round.seats[0].hand.add(discard);
      round.seats[0].drawn = discard;
      round.seats[1].hand = tiles(switch (call) {
        CallType.chi => '23m 19m 258p 1479s 56z',
        CallType.kan => '111z 19m 258p 147s 56z',
        _ => '11z 19m 258p 1479s 56z',
      });
      round.discard(0, discard);
      expect(
          round.callOptions.any((o) => o.seat == 1 && o.types.contains(call)),
          isTrue);
      round.resolveCalls({1: call});
      expect(round.seats[1].melds, hasLength(1));
      expect(round.seats[1].melds.single.tiles, contains(discard));
      expect(round.seats[0].closed, isTrue);
      expect(round.seats[0].pond.length, 2);
      expect(round.seats[0].allDiscards.length, 3);
      round.discard(
          1, round.seats[1].hand.firstWhere((t) => t.type == TileType.pin5));
      if (round.phase == RoundPhase.callOffer) round.resolveCalls({});
      expect(round.finished, isTrue);
      // Seat 0's remaining river still looks eligible, but its called-away
      // tile bars nagashi. Seat 2's unclaimed river remains eligible.
      expect(round.result!.winners, [2]);
      expect(
          round.result!.pointDeltas, {0: -4000, 1: -2000, 2: 8000, 3: -2000});
    });
  }

  test('an offered call that everyone passes does not disqualify', () {
    final round = fixture();
    river(round, 0, '19m');
    final discard = tiles('1z').single;
    round.seats[0].hand.add(discard);
    round.seats[0].drawn = discard;
    round.seats[1].hand = tiles('11z 19m 258p 1479s 56z');
    round.discard(0, discard);
    expect(round.canPon(1, discard), isTrue);
    round.resolveCalls({});
    expect(round.finished, isTrue);
    expect(round.seats[0].pond.length, 3);
    expect(round.seats[0].allDiscards.length, 3);
    expect(round.result!.winners, [0]);
  });

  for (final kind in [MeldKind.sequence, MeldKind.triplet, MeldKind.kan]) {
    test('an open $kind disqualifies the recipient', () {
      final round = fixture();
      river(round, 1, '19m 123z');
      round.seats[1].melds.add(Meld(
          kind: kind, low: TileType.pin1, concealed: false, tiles: const []));
      expect(finish(round).isNagashiMangan, isFalse);
    });
  }

  test('a concealed kan is allowed', () {
    final round = fixture();
    river(round, 1, '19m 123z');
    round.seats[1].hand = tiles('19m 258p 147s 56z');
    round.seats[1].melds.add(Meld(
        kind: MeldKind.kan,
        low: TileType.chun,
        concealed: true,
        tiles: tiles('7777z')));
    expect(finish(round).winners, [1]);
  });

  for (final type in [TileType.ton, TileType.pin5]) {
    test('the final discard $type is included before checking nagashi', () {
      final round = fixture();
      river(round, 3, '19m 123z');
      final discard = Tile(99999, type);
      round.turn = 3;
      round.seats[3].hand.add(discard);
      round.seats[3].drawn = discard;
      round.discard(3, discard);
      if (round.phase == RoundPhase.callOffer) round.resolveCalls({});
      expect(round.finished, isTrue);
      expect(round.result!.isNagashiMangan, type == TileType.ton);
    });
  }

  test('ron on the last discard takes precedence over nagashi', () {
    final round = fixture();
    river(round, 0, '19m 123z');
    round.seats[1].hand = tiles('234m 567m 234p 67p 88s');
    final discard = tiles('5p').single;
    round.turn = 3;
    round.seats[3].hand.add(discard);
    round.seats[3].drawn = discard;
    round.discard(3, discard);
    round.resolveCalls({1: CallType.ron});
    expect(round.result!.kind, RoundEndKind.ron);
    expect(round.result!.isNagashiMangan, isFalse);
    expect(round.result!.winners, [1]);
  });

  for (final ruleset in Ruleset.values.where((r) => !r.isJapanese)) {
    test('nagashi is not enabled for ${ruleset.name}', () {
      final round = fixture(ruleset: ruleset);
      river(round, 1, '19m 123z');
      expect(finish(round).isNagashiMangan, isFalse);
    });
  }

  group('sanma', () {
    const ruleset = Ruleset.sanma;
    for (final dealer in ruleset.activeSeats) {
      for (final recipient in ruleset.activeSeats) {
        test('dealer $dealer, recipient $recipient: tsumo loss', () {
          final round =
              fixture(ruleset: ruleset, dealer: dealer, honba: 3, sticks: 2);
          river(round, recipient, '19m 19p 19s 1234567z');
          // Kita changes neither the discard history nor the closed hand.
          round.seats[recipient].kita.addAll(tiles('44z'));
          final result = finish(round);
          expect(result.kind, RoundEndKind.exhaustiveDraw);
          expect(result.winners, [recipient]);
          expect(result.pointDeltas, {
            for (var seat = 0; seat < 4; seat++)
              seat: !ruleset.seatIsActive(seat)
                  ? 0
                  : seat == recipient
                      ? (recipient == dealer ? 8000 : 6000)
                      : (recipient == dealer || seat == dealer ? -4000 : -2000),
          });
          expect(round.seats[2].points, 0);
          expect(round.riichiSticks, 2);
          expect(
              round.seats.fold<int>(2000, (sum, s) => sum + s.points), 105000);
        });
      }
    }

    for (final (recipients, deltas) in [
      ([0, 1], [4000, 2000, 0, -6000]),
      ([1, 3], [-8000, 4000, 0, 4000]),
      ([0, 1, 3], [0, 0, 0, 0]),
    ]) {
      test('multiple recipients $recipients settle independently', () {
        final round = fixture(ruleset: ruleset);
        for (final recipient in recipients) {
          river(round, recipient, '19m 123z');
        }
        final result = finish(round);
        expect(result.winners, recipients);
        expect(result.pointDeltas, {for (var i = 0; i < 4; i++) i: deltas[i]});
      });
    }

    test('the empty seat never qualifies, even with a planted river', () {
      final round = fixture(ruleset: ruleset);
      river(round, 2, '19m 123z');
      expect(finish(round).winners, isEmpty);
      expect(round.seats[2].points, 0);
    });

    test('nagashi replaces the 2,000-point tenpai settlement', () {
      final round = fixture(ruleset: ruleset);
      round.seats[0].hand = tiles('234p 567p 234s 67s 88p');
      river(round, 1, '19m 123z');
      final result = finish(round);
      expect(result.tenpaiAtDraw, [0]);
      expect(result.pointDeltas, {0: -4000, 1: 6000, 2: 0, 3: -2000});
    });

    for (final call in [CallType.pon, CallType.kan]) {
      test('$call on a discard disqualifies that discarder', () {
        final round = fixture(
            ruleset: ruleset,
            wall: SanmaWall.fromTiles(
                live: call == CallType.kan ? tiles('9s') : [],
                replacements: tiles('6s'),
                indicators: tiles('12z')));
        river(round, 0, '19m');
        river(round, 3, '19p 123z');
        final discard = tiles('1z').single;
        round.seats[0].hand.add(discard);
        round.seats[0].drawn = discard;
        round.seats[1].hand = tiles(call == CallType.kan
            ? '111z 19m 258p 147s 56z'
            : '11z 19m 258p 1479s 56z');
        round.discard(0, discard);
        expect(
            round.callOptions.any((o) => o.seat == 1 && o.types.contains(call)),
            isTrue);
        round.resolveCalls({1: call});
        round.discard(
            1, round.seats[1].hand.firstWhere((t) => t.type == TileType.pin5));
        if (round.phase == RoundPhase.callOffer) round.resolveCalls({});
        expect(round.finished, isTrue);
        expect(round.result!.winners, [3]);
        expect(round.result!.pointDeltas, {0: -4000, 1: -2000, 2: 0, 3: 6000});
      });
    }

    test('online remapping keeps the empty seat out and dealer tenpai intact',
        () {
      final round = fixture(ruleset: ruleset, dealer: 3);
      round.seats[3].hand = tiles('234p 567p 234s 67s 88p');
      river(round, 0, '19m 123z');
      river(round, 1, '19p 456z');
      final result = finish(round);
      for (final viewer in ruleset.activeSeats) {
        final wire = jsonDecode(
                jsonEncode(roundSnapshotToJson(round, reveal: (_) => true)))
            as Map<String, dynamic>;
        final mirror = buildRoundFromSnapshot(wire, mySeat: viewer);
        int local(int seat) => ruleset.relativeSeat(seat, viewer);
        expect(mirror.result!.winners, [local(0), local(1)]);
        expect(mirror.result!.tenpaiAtDraw, [mirror.dealer]);
        expect(mirror.result!.pointDeltas, {
          for (final e in result.pointDeltas.entries) local(e.key): e.value,
        });
        expect(mirror.seats[2].points, 0);
      }
    });
  });

  test('nagashi recipients and dealer tenpai survive online seat remapping',
      () {
    final round = fixture();
    round.seats[0].hand = tiles('234m 567m 234p 67p 88s');
    river(round, 1, '19m 123z');
    river(round, 2, '19p 456z');
    final result = finish(round);
    for (var viewer = 0; viewer < 4; viewer++) {
      final wire = jsonDecode(
              jsonEncode(roundSnapshotToJson(round, reveal: (_) => true)))
          as Map<String, dynamic>;
      final mirror = buildRoundFromSnapshot(wire, mySeat: viewer);
      int local(int seat) => (seat - viewer + 4) % 4;
      expect(mirror.result!.isNagashiMangan, isTrue);
      expect(mirror.result!.winners, [local(1), local(2)]);
      expect(mirror.result!.tenpaiAtDraw, [mirror.dealer]);
      expect(mirror.result!.pointDeltas, {
        for (final e in result.pointDeltas.entries) local(e.key): e.value,
      });
    }
  });
}
