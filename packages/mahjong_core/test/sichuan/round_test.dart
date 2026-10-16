import 'package:mahjong_core/mahjong_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

int _delta(Round r, int seat) => r.seats[seat].points;

void main() {
  group('ruleset', () {
    test('Sichuan is its own ruleset with a flag image and no emoji flag', () {
      const r = Ruleset.sichuan;
      expect(r.isSichuan, isTrue);
      expect(r.flagAsset, 'assets/flags/sichuan.png');
      expect(r.startingPoints, 0);
      expect(r.handsPerGame(fullGame: true), 8);
      expect(r.handsPerGame(fullGame: false), 4);
      expect(r.ronLabel, 'Hu');
      expect(r.totalMelds, 4);
      for (final other in Ruleset.values.where((x) => x != r)) {
        expect(other.flagAsset, isNull);
      }
    });
  });

  group('wall and deal', () {
    test('108 tiles, three suits, no honors or flowers', () {
      final r = Round(
          seed: 3,
          dealer: 0,
          roundWind: Wind.east,
          startingPoints: List.filled(4, 0),
          ruleset: Ruleset.sichuan);
      final all = [
        for (final s in r.seats) ...s.hand,
      ];
      expect(all, hasLength(52));
      expect(all.every((t) => t.type.isSuit), isTrue);
      expect(all.any((t) => t.aka), isFalse);
      expect(r.wall.remaining + 52, 108);
    });

    test('everyone names a void suit before the dealer draws', () {
      final r = Round(
          seed: 4,
          dealer: 2,
          roundWind: Wind.east,
          startingPoints: List.filled(4, 0),
          ruleset: Ruleset.sichuan);
      expect(r.awaitingVoidSuit, isTrue);
      expect(r.seats.every((s) => s.hand.length == 13), isTrue);
      for (var i = 0; i < 3; i++) {
        r.declareVoidSuit(i, r.suggestVoidSuit(i));
        expect(r.awaitingVoidSuit, isTrue);
      }
      expect(() => r.declareVoidSuit(0, 1), throwsStateError);
      r.declareVoidSuit(3, 0);
      expect(r.phase, RoundPhase.discarding);
      expect(r.turn, 2);
      expect(r.seats[2].hand, hasLength(14));
    });

    test('the suggested void suit is the one held least', () {
      final r = fixture();
      setHand(r, 0, '12m 12345p 123456s 1p');
      expect(r.suggestVoidSuit(0), 0);
    });
  });

  group('void suit', () {
    test('the void suit must be discarded before anything else', () {
      final r = fixture();
      setHand(r, 0, '123m 456m 789m 11p 23p', drawn: '9s');
      expect(r.mustDiscardVoid(0), isTrue);
      expect(r.legalDiscards(0).map((t) => t.type), [TileType.sou9]);
      final other = r.seats[0].hand.firstWhere((t) => t.type == TileType.man1);
      expect(() => r.discard(0, other), throwsStateError);
      r.discard(0, r.seats[0].drawn!);
      expect(r.seats[0].voidRevealed, isTrue);
    });

    test('a hand holding its void suit cannot win', () {
      final r = fixture();
      setHand(r, 0, '123m 456m 789m 11p 22p', drawn: '2p');
      expect(r.canTsumo(0), isTrue);
      setHand(r, 0, '123m 456m 789m 11p 22s', drawn: '2s');
      expect(r.canTsumo(0), isFalse);
      expect(r.waitsFor(0), isEmpty);
    });
  });

  group('calls', () {
    test('no chow is ever claimed off a discard', () {
      final r = fixture();
      setHand(r, 0, '123p 456p 789p 11m 22m', drawn: '1m');
      setHand(r, 1, '23m 456p 789p 123p 99m');
      setHand(r, 2, junk);
      setHand(r, 3, junk);
      final discard = r.seats[0].drawn!;
      expect(r.canChi(1, discard), isFalse);
      r.discard(0, discard);
      expect(r.callOptions.expand((o) => o.types), isNot(contains(CallType.chi)));
    });

    test('pung and kong are still claimed', () {
      final r = fixture(wallTiles: tiles('9m'));
      setHand(r, 0, '123p 456p 789p 11m 22m', drawn: '9p');
      setHand(r, 1, '99p 123m 456m 789m 11p 2p');
      setHand(r, 2, junk);
      setHand(r, 3, junk);
      r.discard(0, r.seats[0].drawn!);
      expect(
          r.callOptions
              .where((o) => o.seat == 1)
              .expand((o) => o.types)
              .toSet(),
          contains(CallType.pon));
    });
  });

  group('blood battle', () {
    Round multiHu() {
      final r = fixture(wallTiles: tiles('1m 9p 9p 9p'));
      setHand(r, 0, '123p 456p 789p 11m 22m', drawn: '5m');
      setHand(r, 1, '123p 456p 789p 99m 46m');
      setHand(r, 2, '123m 456m 789m 234m 5m');
      setHand(r, 3, '123p 456p 789p 11m 24m');
      return r;
    }

    test('two seats Hu on one discard, both are paid by the discarder', () {
      final r = multiHu();
      r.discard(0, r.seats[0].drawn!);
      expect(
          r.callOptions.where((o) => o.types.contains(CallType.ron)).map((o) => o.seat),
          [1, 2]);
      r.resolveCalls({1: CallType.ron, 2: CallType.ron});
      expect(r.finished, isFalse);
      expect([for (final h in r.sichuanHu) h.seat], [1, 2]);
      expect(r.seats[1].out && r.seats[2].out, isTrue);
      expect(_delta(r, 0), -5);
      expect(_delta(r, 1), 1);
      expect(_delta(r, 2), 4);
      // Play goes on to the next seat still in.
      expect(r.turn, 3);
      expect(r.phase, RoundPhase.discarding);
    });

    test('the third Hu ends the hand; multiple Hu on the first discard hands '
        'the deal to the discarder', () {
      final r = multiHu();
      r.discard(0, r.seats[0].drawn!);
      r.resolveCalls({1: CallType.ron, 2: CallType.ron});
      r.discard(3, r.seats[3].drawn!);
      r.resolveCalls({0: CallType.ron});
      expect(r.finished, isTrue);
      final res = r.result!;
      expect(res.kind, RoundEndKind.bloodBattle);
      expect(res.winners, [1, 2, 0]);
      expect(res.nextDealer, 0);
      expect(res.pointDeltas, {0: -4, 1: 1, 2: 4, 3: -1});
      expect(res.pointDeltas.values.fold<int>(0, (a, b) => a + b), 0);
    });

    test('a self-draw is paid hand value plus one by every other seat', () {
      final r = fixture(wallTiles: tiles('9p 9p'));
      setHand(r, 0, '123p 456p 789p 11m 22m', drawn: '2m');
      for (var i = 1; i < 4; i++) {
        setHand(r, i, junk);
      }
      expect(r.canTsumo(0), isTrue);
      r.declareTsumo(0);
      expect(_delta(r, 0), 6);
      for (var i = 1; i < 4; i++) {
        expect(_delta(r, i), -2);
      }
      expect(r.finished, isFalse);
      expect(r.seats[0].out, isTrue);
      expect(r.turn, 1);
    });

    test('the first Hu, by one seat, names that seat as the next dealer', () {
      final r = fixture();
      r.turn = 2;
      setHand(r, 2, '123p 456p 789p 11m 22m', drawn: '2m');
      for (final i in [0, 1, 3]) {
        setHand(r, i, junk);
      }
      r.declareTsumo(2);
      // The wall is empty, so the next draw ends the hand.
      expect(r.finished, isTrue);
      expect(r.result!.nextDealer, 2);
    });

    test('nobody Hu: the dealer stays', () {
      final r = fixture(dealer: 1);
      setHand(r, 1, '123p 456p 789p 11m 22m', drawn: '9m');
      for (final i in [0, 2, 3]) {
        setHand(r, i, junk);
      }
      r.discard(1, r.seats[1].drawn!);
      expect(r.finished, isTrue);
      expect(r.result!.winners, isEmpty);
      expect(r.result!.nextDealer, 1);
    });
  });

  group('skipping a Hu', () {
    Round passed() {
      final r = fixture(wallTiles: tiles('5m 9p'));
      setHand(r, 0, '123p 456p 789p 11m 22m', drawn: '5m');
      setHand(r, 1, '123p 456p 789p 99m 11m');
      setHand(r, 2, '123p 456p 789p 99m 46m');
      setHand(r, 3, '123p 456p 789p 11m 24m');
      return r;
    }

    test('a seat that passes a Hu cannot Hu the same tile from anyone else '
        'before its own turn', () {
      final r = passed();
      r.discard(0, r.seats[0].drawn!);
      expect(r.callOptions.map((o) => o.seat), [2]);
      r.resolveCalls({});
      expect(r.seats[2].passedHuValue, 1);
      // Seat 1 draws 5m and cuts it: seat 2 may not take it.
      expect(r.turn, 1);
      r.discard(1, r.seats[1].drawn!);
      expect(r.callOptions.any((o) => o.seat == 2), isFalse);
    });

    test('a discard worth more may still be claimed', () {
      final r = fixture(wallTiles: tiles('9p'));
      setHand(r, 2, '123m 456m 789m 234m 5m');
      final five = tiles('5m').single;
      r.seats[2].passedHuValue = 1;
      expect(r.canRon(2, five), isTrue);
      r.seats[2].passedHuValue = 4;
      expect(r.canRon(2, five), isFalse);
    });

    test('its own turn clears it', () {
      final r = passed();
      r.discard(0, r.seats[0].drawn!);
      r.resolveCalls({});
      r.discard(1, r.seats[1].drawn!);
      expect(r.turn, 2);
      expect(r.seats[2].passedHuValue, 0);
    });
  });

  group('kongs', () {
    Round afterConcealedKong({String s1 = junk}) {
      final r = fixture(wallTiles: tiles('8m'));
      setHand(r, 0, '7777p 123p 456p 11m 2m', drawn: '4m');
      setHand(r, 1, s1);
      setHand(r, 2, junk);
      setHand(r, 3, junk);
      return r;
    }

    test('a concealed kong is paid 2 by every other seat, to a ready kong '
        'declarer, at the end of the hand', () {
      final r = afterConcealedKong();
      expect(r.closedKanTypes(0), contains(TileType.pin7));
      r.closedKan(0, TileType.pin7);
      final kong = r.sichuanKongs.single;
      expect(kong.kind, SichuanKongKind.concealed);
      expect(kong.payers, [1, 2, 3]);
      expect(kong.each, 2);
      r.discard(0, r.seats[0].drawn ?? r.seats[0].hand.firstWhere((t) => t.type == TileType.man8));
      expect(r.finished, isTrue);
      // Ready for 2 points (a Root): three unready seats pay it, plus 2 each
      // for the kong.
      expect(r.result!.pointDeltas, {0: 12, 1: -4, 2: -4, 3: -4});
    });

    test('a kong declarer who finishes unready collects nothing', () {
      final r = afterConcealedKong();
      r.closedKan(0, TileType.pin7);
      // Break the hand: swap the waiting shape for junk.
      r.seats[0].hand = sortByType(tiles('147m 258p 369m 1p 5m'));
      r.discard(0, r.seats[0].hand.firstWhere((t) => t.type == TileType.man5));
      expect(r.finished, isTrue);
      expect(r.result!.pointDeltas.values.every((d) => d == 0), isTrue);
    });

    test('a Hu on the discard after a kong cancels the kong payment', () {
      final r = afterConcealedKong(s1: '123p 456p 789p 999m 7m');
      r.closedKan(0, TileType.pin7);
      r.discard(0, r.seats[0].hand.firstWhere((t) => t.type == TileType.man8));
      expect(r.callOptions.map((o) => o.seat), [1]);
      r.resolveCalls({1: CallType.ron});
      expect(r.sichuanKongs.single.voided, isTrue);
      // The kong replacement was the last tile, so the discard after it is
      // also Under the Sea: 2 fan, 4 points.
      expect(r.sichuanHu.single.score.names,
          {'Shoot after Kong', 'Under the Sea'});
      expect(r.finished, isTrue);
      final res = r.result!;
      expect(res.sichuanPayments.where((p) => p.kind == SichuanPaymentKind.kong), isEmpty);
      // s0 pays s1 4; the two unready seats each pay ready s0 2.
      expect(res.pointDeltas, {0: 0, 1: 4, 2: -2, 3: -2});
    });

    test('an added kong on a tile already held earns nothing', () {
      final r = fixture(wallTiles: tiles('9m'));
      r.seats[0].melds = [
        Meld(
            kind: MeldKind.triplet,
            low: TileType.pin7,
            concealed: false,
            calledFromSeatOffset: 1,
            tiles: tiles('777p'))
      ];
      setHand(r, 0, '123p 456p 11m 2m 7p', drawn: '4m');
      for (var i = 1; i < 4; i++) {
        setHand(r, i, junk);
      }
      expect(r.addedKanTypes(0), contains(TileType.pin7));
      r.addKan(0, TileType.pin7);
      expect(r.sichuanKongs.single.voided, isTrue);
    });

    test('an added kong on the tile just drawn is paid 1 by each other seat',
        () {
      final r = fixture(wallTiles: tiles('9m'));
      r.seats[0].melds = [
        Meld(
            kind: MeldKind.triplet,
            low: TileType.pin7,
            concealed: false,
            calledFromSeatOffset: 1,
            tiles: tiles('777p'))
      ];
      setHand(r, 0, '123p 456p 11m 24m', drawn: '7p');
      for (var i = 1; i < 4; i++) {
        setHand(r, i, junk);
      }
      r.addKan(0, TileType.pin7);
      final kong = r.sichuanKongs.single;
      expect(kong.kind, SichuanKongKind.added);
      expect(kong.voided, isFalse);
      expect(kong.each, 1);
      expect(kong.payers, [1, 2, 3]);
    });

    test('a robbed kong is cancelled; the robber is paid and goes out', () {
      final r = fixture(wallTiles: tiles('9m'));
      r.seats[0].melds = [
        Meld(
            kind: MeldKind.triplet,
            low: TileType.pin7,
            concealed: false,
            calledFromSeatOffset: 1,
            tiles: tiles('777p'))
      ];
      setHand(r, 0, '123p 456p 11m 24m', drawn: '7p');
      setHand(r, 1, '234m 567m 456p 99p 68p');
      setHand(r, 2, junk);
      setHand(r, 3, junk);
      r.addKan(0, TileType.pin7);
      expect(r.chankanPending, isTrue);
      r.resolveCalls({1: CallType.ron});
      expect(r.sichuanKongs.single.voided, isTrue);
      expect(r.sichuanHu.single.robbedKong, isTrue);
      expect(r.sichuanHu.single.score.names, contains('Robbing the Kong'));
      expect(r.seats[0].melds.single.kind, MeldKind.triplet);
      expect(_delta(r, 0), -2);
      expect(_delta(r, 1), 2);
      expect(r.turn, 2);
    });
  });

  group('the wall ends', () {
    test('unready seats pay each ready seat the value of its best hand', () {
      final r = fixture();
      setHand(r, 0, '123p 456p 789p 11m 22m', drawn: '9m');
      setHand(r, 1, '123m 456m 789m 234m 5m');
      setHand(r, 2, junk);
      setHand(r, 3, junk);
      r.discard(0, r.seats[0].drawn!);
      expect(r.callOptions, isEmpty);
      expect(r.finished, isTrue);
      expect(r.result!.pointDeltas, {0: 2, 1: 8, 2: -5, 3: -5});
      expect(r.result!.nextDealer, 0);
    });

    test('a wait on a tile whose four copies are all in your own hand is '
        'not ready', () {
      final r = fixture();
      // An exposed pung of 7p and a single 7p in hand: "waiting" on 7p for the
      // pair would be a fifth copy.
      r.seats[0].melds = [
        Meld(
            kind: MeldKind.triplet,
            low: TileType.pin7,
            concealed: false,
            calledFromSeatOffset: 1,
            tiles: tiles('777p'))
      ];
      r.seats[0].hand = sortByType(tiles('123m 456m 789m 7p'));
      expect(waitTilesSichuan(r.seats[0].hand, openMelds: 1), isNotEmpty);
      expect(r.sichuanReadyValue(0), 0);
      // The same hand with a different tile in hand is ready.
      r.seats[0].hand = sortByType(tiles('123m 456m 789m 8p'));
      expect(r.sichuanReadyValue(0), greaterThan(0));
    });

    test('a seat holding its void suit at the end pays 48 to each other seat '
        'if it discarded something else', () {
      final r = fixture();
      setHand(r, 0, '123m 456m 789m 11p 2p 9s', drawn: '8s');
      r.seats[0].allDiscards.add(tiles('1m').single);
      for (var i = 1; i < 4; i++) {
        setHand(r, i, junk);
      }
      r.discard(0, r.seats[0].hand.firstWhere((t) => t.type == TileType.sou9));
      expect(r.finished, isTrue);
      expect(r.result!.pointDeltas, {0: -144, 1: 48, 2: 48, 3: 48});
    });

    test('no penalty when every discard was the void suit', () {
      final r = fixture();
      setHand(r, 0, '123m 456m 789m 11p 2p 9s', drawn: '8s');
      for (var i = 1; i < 4; i++) {
        setHand(r, i, junk);
      }
      r.discard(0, r.seats[0].hand.firstWhere((t) => t.type == TileType.sou9));
      expect(r.finished, isTrue);
      expect(r.result!.pointDeltas.values.every((d) => d == 0), isTrue);
    });
  });

  group('the 48-point void-suit penalty', () {
    // discard() refuses to cut anything but the void suit while one is held,
    // so a seat can never *reach* the end holding void tiles after cutting
    // something else. These tests pose that end state directly: the seat's
    // recorded discards (allDiscards) include a non-void tile, as they would
    // if the rule were not enforced.
    const voidJunk = '147m 258p 369m 14p 7p 2s';

    Round penaltyTable() {
      final r = fixture();
      setHand(r, 0, '123m 456m 789m 11p 2p 9s', drawn: '8s');
      r.seats[0].allDiscards.add(tiles('1m').single);
      for (var i = 1; i < 4; i++) {
        setHand(r, i, junk);
      }
      return r;
    }

    int penalties(RoundResult res) => res.sichuanPayments
        .where((p) => p.kind == SichuanPaymentKind.penalty)
        .length;

    test('is 48 from the offender to each other seat, three payments', () {
      final r = penaltyTable();
      r.discard(0, r.seats[0].hand.firstWhere((t) => t.type == TileType.sou9));
      final res = r.result!;
      final lines = res.sichuanPayments
          .where((p) => p.kind == SichuanPaymentKind.penalty)
          .toList();
      expect([for (final l in lines) l.from], [0, 0, 0]);
      expect([for (final l in lines) l.to]..sort(), [1, 2, 3]);
      expect(lines.every((l) => l.points == SichuanRules.voidedSuitPenalty),
          isTrue);
      expect(SichuanRules.voidedSuitPenalty, 48);
      expect(res.pointDeltas, {0: -144, 1: 48, 2: 48, 3: 48});
    });

    test('is paid to a seat that already went out, too', () {
      final r = penaltyTable();
      r.seats[3]
        ..out = true
        ..huOrder = 1;
      r.discard(0, r.seats[0].hand.firstWhere((t) => t.type == TileType.sou9));
      expect(r.result!.pointDeltas, {0: -144, 1: 48, 2: 48, 3: 48});
    });

    test('two offenders each pay each other seat, and each other', () {
      final r = penaltyTable();
      setHand(r, 1, voidJunk);
      r.seats[1].allDiscards.add(tiles('4m').single);
      r.discard(0, r.seats[0].hand.firstWhere((t) => t.type == TileType.sou9));
      final res = r.result!;
      expect(penalties(res), 6);
      // Each pays 144 and collects 48 from the other.
      expect(res.pointDeltas, {0: -96, 1: -96, 2: 96, 3: 96});
      expect(res.pointDeltas.values.fold<int>(0, (a, b) => a + b), 0);
    });

    test('comes on top of unready-pays-ready, and the money still balances',
        () {
      final r = penaltyTable();
      setHand(r, 1, '123m 456m 789m 234m 5m'); // ready, worth 4 (full flush)
      r.discard(0, r.seats[0].hand.firstWhere((t) => t.type == TileType.sou9));
      final res = r.result!;
      // The offender pays 4 to the ready seat and 144 in penalties; the
      // other unready seats pay it 4 each and collect 48.
      expect(res.pointDeltas, {0: -148, 1: 60, 2: 44, 3: 44});
      expect(res.pointDeltas.values.fold<int>(0, (a, b) => a + b), 0);
      // The offender is never ready, whatever its tiles look like.
      expect(r.sichuanReadyValue(0), 0);
    });

    test('a seat holding void tiles forfeits its kong payments as well', () {
      final r = fixture(wallTiles: tiles('8m'));
      // A kong may be declared while void tiles are held (it is not a cut).
      setHand(r, 0, '7777p 123p 456p 11m 9s', drawn: '8s');
      r.seats[0].allDiscards.add(tiles('1m').single);
      for (var i = 1; i < 4; i++) {
        setHand(r, i, junk);
      }
      r.closedKan(0, TileType.pin7);
      expect(r.sichuanKongs.single.voided, isFalse);
      r.discard(0, r.seats[0].hand.firstWhere((t) => t.type == TileType.sou9));
      expect(r.finished, isTrue);
      final res = r.result!;
      expect(
          res.sichuanPayments.where((p) => p.kind == SichuanPaymentKind.kong),
          isEmpty,
          reason: 'not ready, so no kong payments');
      expect(res.pointDeltas, {0: -144, 1: 48, 2: 48, 3: 48});
    });

    test('with three seats out, the last one still pays the three winners', () {
      // Tiles left in the wall, so the win is not also Under the Sea.
      final r = fixture(wallTiles: tiles('9p 9p'));
      r.seats[1]
        ..out = true
        ..huOrder = 1;
      r.seats[2]
        ..out = true
        ..huOrder = 2;
      r.turn = 3;
      setHand(r, 3, '123p 456p 789p 11m 22m', drawn: '2m');
      setHand(r, 0, voidJunk);
      r.seats[0].allDiscards.add(tiles('1m').single);
      r.declareTsumo(3);
      expect(r.finished, isTrue);
      final res = r.result!;
      // 2 for the self-draw (hand value 1 + 1), then 48 to each of the others.
      expect(res.pointDeltas, {0: -146, 1: 48, 2: 48, 3: 50});
      expect(res.pointDeltas.values.fold<int>(0, (a, b) => a + b), 0);
    });

    test('no penalty if every discard was the void suit', () {
      final r = fixture();
      setHand(r, 0, '123m 456m 789m 11p 2p 9s', drawn: '8s');
      r.seats[0].allDiscards.add(tiles('5s').single);
      for (var i = 1; i < 4; i++) {
        setHand(r, i, junk);
      }
      r.discard(0, r.seats[0].hand.firstWhere((t) => t.type == TileType.sou9));
      expect(penalties(r.result!), 0);
    });

    test('no penalty for a seat that has not discarded anything else', () {
      final r = penaltyTable();
      r.seats[0].allDiscards.clear();
      r.discard(0, r.seats[0].hand.firstWhere((t) => t.type == TileType.sou9));
      expect(penalties(r.result!), 0);
    });

    test('no penalty once the void suit is gone from the hand', () {
      final r = fixture();
      setHand(r, 0, '123m 456m 789m 11p 2p 4m', drawn: '9s');
      r.seats[0].allDiscards.add(tiles('1m').single);
      for (var i = 1; i < 4; i++) {
        setHand(r, i, junk);
      }
      r.discard(0, r.seats[0].drawn!);
      expect(penalties(r.result!), 0);
    });

    test('a void-suit meld alone is not "in hand": no penalty', () {
      final r = fixture();
      r.seats[0].melds = [
        Meld(
            kind: MeldKind.triplet,
            low: TileType.sou5,
            concealed: false,
            calledFromSeatOffset: 1,
            tiles: tiles('555s'))
      ];
      setHand(r, 0, '123m 456m 789m 1p', drawn: '9p');
      r.seats[0].allDiscards.add(tiles('1m').single);
      for (var i = 1; i < 4; i++) {
        setHand(r, i, junk);
      }
      r.discard(0, r.seats[0].drawn!);
      expect(penalties(r.result!), 0);
    });

    test('a seat that went out is never penalised', () {
      final r = penaltyTable();
      r.seats[0].out = true;
      r.seats[0].huOrder = 1;
      r.turn = 1;
      setHand(r, 1, junk, drawn: '9m');
      r.discard(1, r.seats[1].drawn!);
      expect(penalties(r.result!), 0);
    });

    test('is listed in the payments the score screen shows', () {
      final r = penaltyTable();
      r.discard(0, r.seats[0].hand.firstWhere((t) => t.type == TileType.sou9));
      final res = r.result!;
      expect(res.sichuanPayments.map((p) => p.label).toSet(),
          contains('Void suit penalty'));
    });
  });

  group('bot self-play', () {
    Round play(int seed, {int dealer = 0}) {
      final round = Round(
        seed: seed,
        dealer: dealer,
        roundWind: Wind.east,
        startingPoints: List.filled(4, 0),
        ruleset: Ruleset.sichuan,
      );
      final bots = [for (var i = 0; i < 4; i++) SimpleBot(seed * 10 + i)];
      var guard = 0;
      while (!round.finished) {
        if (++guard > 6000) fail('seed $seed did not finish');
        switch (round.phase) {
          case RoundPhase.choosingVoidSuit:
            for (var i = 0; i < 4; i++) {
              round.declareVoidSuit(i, round.suggestVoidSuit(i));
            }
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
            expect(round.seats[seat].out, isFalse, reason: 'seed $seed');
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
          case RoundPhase.drawing:
          case RoundPhase.finished:
            break;
        }
      }
      return round;
    }

    test('every hand ends balanced, with legal Hu and no chows', () {
      var hu = 0;
      var threeHu = 0;
      for (var seed = 1; seed <= 80; seed++) {
        final round = play(seed, dealer: seed % 4);
        final res = round.result!;
        expect(res.kind, RoundEndKind.bloodBattle, reason: 'seed $seed');
        expect(res.pointDeltas.values.fold<int>(0, (a, b) => a + b), 0,
            reason: 'seed $seed');
        expect(res.winners.toSet(), hasLength(res.winners.length));
        expect(res.winners.length, lessThanOrEqualTo(3));
        expect(res.nextDealer, isNotNull);
        for (final h in res.sichuanHu) {
          hu++;
          final s = round.seats[h.seat];
          expect(s.out, isTrue);
          expect(h.score.valid, isTrue, reason: 'seed $seed');
          final v = s.voidSuit!;
          expect(s.melds.every((m) => m.low.suit != v), isTrue,
              reason: 'seed $seed: a winner held its void suit in a meld');
          expect([...s.hand].where((t) => t.type.suit == v), isEmpty,
              reason: 'seed $seed: a winner held its void suit');
        }
        for (final s in round.seats) {
          expect(s.melds.every((m) => !m.isSequence), isTrue,
              reason: 'seed $seed: nobody calls a chow');
        }
        if (res.winners.length == 3) threeHu++;
        // The rules make the void-suit penalty unreachable in real play:
        // discard() refuses anything but the void suit while one is held.
        expect(
            res.sichuanPayments
                .where((p) => p.kind == SichuanPaymentKind.penalty),
            isEmpty,
            reason: 'seed $seed: nobody should ever be penalised');
        // Money stays inside the table: every payment line is accounted for.
        final fromLines = <int, int>{for (var i = 0; i < 4; i++) i: 0};
        for (final p in res.sichuanPayments) {
          fromLines[p.from] = fromLines[p.from]! - p.points;
          fromLines[p.to] = fromLines[p.to]! + p.points;
        }
        expect(fromLines, res.pointDeltas, reason: 'seed $seed');
      }
      expect(hu, greaterThan(40), reason: 'bots should win plenty of hands');
      expect(threeHu, greaterThan(0), reason: 'bots should reach 3 Hu');
    });
  });
}

extension on HandScore {
  Set<String> get names => yaku.map((y) => y.name).toSet();
}
