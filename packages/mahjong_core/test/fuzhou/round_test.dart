import 'package:mahjong_core/mahjong_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('the deal', () {
    test('16 tiles each, then the Gold is flipped and the dealer draws', () {
      final r = fixture(gold: Tile(-1, type('5s')), draws: tiles('1m'));
      expect(r.goldIndicator!.type, type('5s'));
      expect(r.goldTypes, {type('5s')});
      expect(r.seats[1].hand.length, 16);
      expect(r.seats[0].hand.length, 17); // the dealer's first draw
      expect(r.phase, RoundPhase.discarding);
      expect(r.turn, 0);
    });

    test('a real wall deals 144 tiles with 18 held back', () {
      final r = Round(
          seed: 3,
          dealer: 0,
          roundWind: Wind.east,
          startingPoints: List.filled(4, 500),
          ruleset: Ruleset.fuzhou);
      final dealt = r.seats.fold<int>(
          0, (a, s) => a + s.hand.length + s.flowers.length + s.melds.length);
      // Every tile is somewhere: in hand, exposed, in the live wall, or in
      // the 18 held back (the Gold indicator among them).
      expect(r.wall.remaining + dealt + FuzhouRules.deadWallSize, 144);
      expect(r.goldIndicator, isNotNull);
      for (final s in r.seats) {
        expect(s.hand.any((t) => FuzhouRules.isFlower(t.type) && !r.isGold(t.type)),
            isFalse,
            reason: 'every flower, honors included, is exposed');
      }
    });

    test('honors are flowers, and replaced from the wall', () {
      final deal = <Tile>[];
      final hands = [
        tiles('147m 147p 147s 258m 258p 3s'),
        tiles('147m 147p 147s 258m 258p 3s'),
        tiles('147m 147p 147s 258m 258p 3s'),
        tiles('147m 147p 147s 258m 258p 3s'),
      ];
      // Dealer's first tile is the East wind.
      hands[0][0] = Tile(900, TileType.ton);
      for (final h in hands) {
        deal.addAll(h);
      }
      // The replacement is the tail of the wall; the draw is the head.
      final wall = FuzhouWall.fromTiles([
        ...deal,
        ...tiles('9m'), // the dealer's draw
        Tile(901, TileType.sou9), // the replacement for the East flower
      ], gold: Tile(-300, TileType.pin9));
      final r = Round(
          seed: 1,
          dealer: 0,
          roundWind: Wind.east,
          startingPoints: List.filled(4, 500),
          ruleset: Ruleset.fuzhou,
          wall: wall);
      expect(r.seats[0].flowers.map((t) => t.type), [TileType.ton]);
      expect(r.seats[0].hand.any((t) => t.type == TileType.ton), isFalse);
      expect(r.seats[0].hand.any((t) => t.id == 901), isTrue);
    });

    test('a Gold flower is kept in hand as a wild, not replaced', () {
      final r = fixture(gold: Tile(-1, TileType.ton), draws: tiles('1m'));
      expect(r.goldTypes, {TileType.ton});
      expect(r.isFlowerTile(TileType.ton), isFalse);
      expect(r.isFlowerTile(TileType.nan), isTrue);
      expect(r.isFlowerTile(TileType.plum), isTrue);
      expect(r.isFlowerTile(type('5s')), isFalse);
    });

    test('flipping a flower or season makes the other seven wild', () {
      final r = fixture(gold: Tile(-1, TileType.plum), draws: tiles('1m'));
      expect(r.goldTypes.length, 7);
      expect(r.isFlowerTile(TileType.plum), isTrue,
          reason: 'only the other seven are gold');
      expect(r.isFlowerTile(TileType.orchid), isFalse);
    });
  });

  group('Robbing the Gold', () {
    Round robbed({int dealer = 0}) {
      final deal = <Tile>[];
      // Seat 1 is ready: 123m 456m 789m 123p 456p + 1s... needs a pair.
      final ready = tiles('123m 456m 789m 123p 456p 9s');
      final junk = tiles(junk16);
      for (var i = 0; i < 4; i++) {
        deal.addAll(i == 1 ? ready : tiles(junk16));
      }
      expect(junk.length, 16);
      final wall = FuzhouWall.fromTiles([...deal, ...tiles('2m')],
          gold: Tile(-1, type('5s')));
      return Round(
          seed: 1,
          dealer: dealer,
          roundWind: Wind.east,
          startingPoints: List.filled(4, 500),
          ruleset: Ruleset.fuzhou,
          wall: wall);
    }

    test('a ready seat wins on the flipped Gold before anyone draws', () {
      final r = robbed();
      expect(r.finished, isTrue);
      expect(r.result!.kind, RoundEndKind.tsumo);
      expect(r.result!.winners, [1]);
      expect(r.result!.label, 'Robbing the Gold');
      expect(names(r.result!.score!), contains('Robbing the Gold'));
      // Self-draw: the other three each pay the same.
      final score = r.result!.score!.points;
      expect(r.result!.pointDeltas[1], score * 3);
      for (final i in [0, 2, 3]) {
        expect(r.result!.pointDeltas[i], -score);
      }
      expect(r.seats[0].hand.length, 16, reason: 'nobody has drawn');
    });

    test('the dealer is asked first', () {
      final r = robbed(dealer: 1);
      expect(r.result!.winners, [1]);
    });

    test('no one ready, no robbery', () {
      final r = fixture(gold: Tile(-1, type('5s')), draws: tiles('2m'));
      expect(r.finished, isFalse);
    });
  });

  group('flow', () {
    test('a discarded Gold can not be claimed, and bars winning on discards',
        () {
      final r = fixture(gold: Tile(-1, type('5s')), draws: tiles('2m 3m'));
      setHand(r, 0, '147m 147p 147s 258m 258p 3s', drawn: '5s');
      final goldTile = r.seats[0].drawn!;
      // Seat 1 is ready on 3p/6p, and would take a plain tile.
      r.seats[1].hand = sortByType(tiles('123m 456m 789m 123p 45p 99s'));
      r.discard(0, goldTile);
      expect(r.seats[0].goldDiscarded, isTrue);
      expect(r.callOptions, isEmpty, reason: 'a Gold is never on offer');
    });

    test('a seat that threw a Gold may only win by self-draw', () {
      final r = fixture(gold: Tile(-1, type('5s')), draws: tiles('2m 3m'));
      r.seats[2].goldDiscarded = true;
      // Seat 2 is ready on 9s.
      r.seats[2].hand = sortByType(tiles('123m 456m 789m 123p 456p 9s'));
      r.seats[0].hand = sortByType(tiles('9s 147m 147p 147s 258m 258p 3s 1m'));
      r.seats[0].drawn = r.seats[0].hand.first;
      expect(r.canRon(2, Tile(900, type('9s'))), isFalse);
      r.seats[2].goldDiscarded = false;
      expect(r.canRon(2, Tile(900, type('9s'))), isTrue);
    });

    test('Gold tiles in hand are wild: a win with one', () {
      final r = fixture(gold: Tile(-1, type('5s')), draws: tiles('2m 3m'));
      // 15 naturals + a Gold: 123m 456m 789m 123p 45p 99s + gold, win on 6p/3p.
      r.seats[0].hand =
          sortByType(tiles('123m 456m 789m 123p 4p 99s 5s 5p'));
      r.seats[0].drawn = r.seats[0].hand.firstWhere((t) => t.type == type('5p'));
      expect(r.canTsumo(0), isTrue);
      r.declareTsumo(0);
      expect(r.result!.kind, RoundEndKind.tsumo);
      expect(points(r.result!.score!, 'Gold Points'), 1);
    });

    test('chows can not use a Gold from the hand, pungs can not either', () {
      final r = fixture(gold: Tile(-1, type('5s')), draws: tiles('2m 3m'));
      // Seat 1 holds 4s 6s and a Gold 5s: the Gold is wild, not a 5s to chow.
      r.seats[1].hand = sortByType(tiles('46s 5s 147m 147p 258m 258p 3m'));
      expect(r.chiSequences(1, Tile(901, type('3s'))), isEmpty);
      // Seat 1 holds two 5s... both gold: no pung of the Gold.
      r.seats[1].hand = sortByType(tiles('55s 147m 147p 258m 258p 369m 3s'));
      r.pendingDiscardSeat = 0;
      expect(r.canPon(1, Tile(902, type('5s'))), isFalse);
      // A natural pair pungs as usual.
      r.seats[1].hand = sortByType(tiles('99s 147m 147p 258m 258p 369m 3s'));
      expect(r.canPon(1, Tile(903, type('9s'))), isTrue);
    });

    test('a concealed kong needs four natural tiles', () {
      final r = fixture(gold: Tile(-1, type('5s')), draws: tiles('2m 3m'));
      r.seats[0].hand = sortByType(tiles('5555s 147m 147p 258m 258p 3s'));
      expect(r.closedKanTypes(0), isEmpty);
      r.seats[0].hand = sortByType(tiles('9999s 147m 147p 258m 258p 3s'));
      expect(r.closedKanTypes(0), [type('9s')]);
    });

    test('a win off a discard is paid by the discarder alone', () {
      final r = fixture(gold: Tile(-1, type('5s')), draws: tiles('2m 3m'));
      // Seat 2 is ready on 9s; seat 0 discards it.
      r.seats[2].hand = sortByType(tiles('123m 456m 789m 123p 456p 9s'));
      final nine = tiles('9s').single;
      r.seats[0].hand = [...r.seats[0].hand, nine];
      r.seats[0].drawn = nine;
      r.discard(0, nine);
      expect(r.phase, RoundPhase.callOffer);
      expect(r.callOptions.single.seat, 2);
      r.resolveCalls({2: CallType.ron});
      final res = r.result!;
      expect(res.kind, RoundEndKind.ron);
      expect(res.winners, [2]);
      final pts = res.score!.points;
      expect(res.pointDeltas[2], pts);
      expect(res.pointDeltas[0], -pts);
      expect(res.pointDeltas[1], 0);
      expect(res.pointDeltas[3], 0);
    });

    test('only one seat wins a discard: the closest in turn to the discarder',
        () {
      final r = fixture(gold: Tile(-1, type('5s')), draws: tiles('2m 3m'));
      r.seats[1].hand = sortByType(tiles('123m 456m 789m 123p 456p 9s'));
      r.seats[2].hand = sortByType(tiles('123m 456m 789m 123p 456p 9s'));
      final nine = tiles('9s').single;
      r.seats[0].hand = [...r.seats[0].hand, nine];
      r.seats[0].drawn = nine;
      r.discard(0, nine);
      expect(r.callOptions.map((o) => o.seat), unorderedEquals([1, 2]));
      r.resolveCalls({1: CallType.ron, 2: CallType.ron});
      expect(r.result!.winners, [1]);
      expect(r.result!.pointDeltas[2], 0);
    });

    test('a first discard that wins is Blessing of Earth', () {
      final r = fixture(gold: Tile(-1, type('5s')), draws: tiles('2m 3m'));
      r.seats[2].hand = sortByType(tiles('123m 456m 789m 123p 456p 9s'));
      final nine = tiles('9s').single;
      r.seats[0].hand = [...r.seats[0].hand, nine];
      r.seats[0].drawn = nine;
      r.discard(0, nine);
      r.resolveCalls({2: CallType.ron});
      expect(names(r.result!.score!), contains('Blessing of Earth'));
    });

    test('a dealer self-draw on the first turn is Blessing of Heaven', () {
      final r = fixture(gold: Tile(-1, type('5s')), draws: tiles('9s'));
      expect(r.seats[0].drawn, isNotNull);
      r.seats[0].hand = sortByType(tiles('123m 456m 789m 123p 456p 9s 9s'));
      r.seats[0].drawn = r.seats[0].hand.last;
      expect(r.canTsumo(0), isTrue);
      r.declareTsumo(0);
      expect(names(r.result!.score!), contains('Blessing of Heaven'));
    });

    test('the dealer\'s streak is a point a win', () {
      final r = fixture(
          gold: Tile(-1, type('5s')), draws: tiles('9s'), honba: 2);
      r.seats[0].hand = sortByType(tiles('123m 456m 789m 123p 456p 9s 9s'));
      r.seats[0].drawn = r.seats[0].hand.last;
      r.declareTsumo(0);
      expect(points(r.result!.score!, 'Dealer Continuation'), 2);
    });

    test('the hand is drawn when the live wall runs out, with nothing paid',
        () {
      final r = fixture(gold: Tile(-1, type('5s')), draws: tiles('2m'));
      // Burn the dealer's draw, then nothing is left.
      expect(r.wall.remaining, 0);
      final t = r.seats[0].drawn!;
      r.discard(0, t);
      expect(r.finished, isTrue);
      expect(r.result!.kind, RoundEndKind.exhaustiveDraw);
      expect(r.result!.pointDeltas.values.every((v) => v == 0), isTrue);
    });

    test('there is no minimum, no riichi and no furiten', () {
      final r = fixture(gold: Tile(-1, type('5s')), draws: tiles('2m 3m'));
      expect(r.canRiichi(0), isFalse);
      expect(r.isFuriten(1), isFalse);
      expect(r.minimumShortfall(1), MinimumShortfall.none);
    });
  });

  group('bot self-play', () {
    test('many deals finish, balance to zero and win only on whole hands', () {
      var wins = 0, draws = 0, robbed = 0;
      for (var seed = 0; seed < 40; seed++) {
        final round = Round(
          seed: seed,
          dealer: seed % 4,
          roundWind: Wind.east,
          honba: seed % 3,
          startingPoints: List.filled(4, Ruleset.fuzhou.startingPoints),
          ruleset: Ruleset.fuzhou,
        );
        final bots = [for (var i = 0; i < 4; i++) SimpleBot(seed * 10 + i)];
        var guard = 0;
        while (!round.finished) {
          if (++guard > 4000) fail('seed $seed did not finish');
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
              final d = bots[seat].decideTurn(round, seat);
              if (d.tsumo) {
                round.declareTsumo(seat);
              } else if (d.closedKan != null) {
                round.closedKan(seat, d.closedKan!);
              } else if (d.addedKan != null) {
                round.addKan(seat, d.addedKan!);
              } else {
                round.discard(seat, d.discard ?? round.legalDiscards(seat).first);
              }
            default:
              break;
          }
        }
        final r = round.result!;
        expect(r.pointDeltas.values.fold<int>(0, (a, b) => a + b), 0,
            reason: 'seed $seed must balance');
        if (r.kind == RoundEndKind.exhaustiveDraw) {
          draws++;
          continue;
        }
        wins++;
        if (r.label == 'Robbing the Gold') robbed++;
        for (final w in r.winners) {
          final s = round.seats[w];
          expect(r.scores.first.valid, isTrue);
          if (r.label != 'Robbing the Gold') {
            final winTileCounted = r.kind == RoundEndKind.tsumo ? 0 : 1;
            expect(s.hand.length + s.melds.length * 3 + winTileCounted, 17,
                reason: 'seed $seed seat $w');
          }
        }
        // A ron is paid by the discarder alone.
        if (r.kind == RoundEndKind.ron) {
          final losers = r.pointDeltas.entries.where((e) => e.value < 0);
          expect(losers.length, 1);
          expect(losers.single.key, r.loser);
        }
      }
      expect(wins, greaterThan(20), reason: 'bots should finish many hands');
      // ignore: avoid_print
      print('fuzhou self-play: $wins wins ($robbed robbed), $draws draws');
    });
  });

  group('ruleset', () {
    test('Fuzhou plays 16 tiles to five melds', () {
      const r = Ruleset.fuzhou;
      expect(r.totalMelds, 5);
      expect(r.concealedHandSize, 16);
      expect(r.isChineseStyle, isTrue);
      expect(r.playerCount, 4);
      expect(r.startingPoints, FuzhouRules.startingPoints);
      expect(r.ronLabel, 'Hu');
      expect(r.flagAsset, 'assets/flags/fuzhou.png');
    });
  });
}
