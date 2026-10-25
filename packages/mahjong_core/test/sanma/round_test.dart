import 'package:mahjong_core/mahjong_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// Hands that can neither call nor win off anything the tests throw.
const _junkA = '19m 1258p 147s 1356z';
const _junkB = '19m 3669p 258s 2457z';

void main() {
  group('ruleset', () {
    const r = Ruleset.sanma;

    test('is three-player riichi with a flag of its own', () {
      expect(r.isSanma, isTrue);
      expect(r.isJapanese, isTrue);
      expect(r.isRiichi, isFalse);
      expect(r.isChineseStyle, isFalse);
      expect(r.playerCount, 3);
      expect(r.flagAsset, 'assets/flags/sanma.png');
      expect(r.startingPoints, 35000);
      expect(r.handsPerGame(fullGame: true), 6);
      expect(r.handsPerGame(fullGame: false), 3);
      expect(Ruleset.riichi.handsPerGame(fullGame: true), 8);
      expect(Ruleset.mcr.handsPerGame(fullGame: true), 16);
    });

    test('plays seats 0, 1 and 3, leaving the seat across empty', () {
      expect(r.activeSeats, [0, 1, 3]);
      expect(r.seatIsActive(2), isFalse);
      expect([for (final s in [0, 1, 3]) r.nextSeat(s)], [1, 3, 0]);
      expect(r.nextDealer(1), 3);
      // East, South, West round from the dealer; there is no North seat.
      expect([for (final s in [0, 1, 3]) r.seatWind(s, 0)],
          [Wind.east, Wind.south, Wind.west]);
      expect([for (final s in [3, 0, 1]) r.seatWind(s, 3)],
          [Wind.east, Wind.south, Wind.west]);
      // Four-player numbering is unchanged.
      expect(Ruleset.riichi.seatWind(2, 3), Wind.north);
      expect(Ruleset.riichi.nextSeat(1), 2);
    });

    test('an online player sees itself at 0 and the empty seat across', () {
      // Seen from seat 1: the player after it (3) is on its right, the one
      // before it (0) on its left.
      expect(r.relativeSeat(1, 1), 0);
      expect(r.relativeSeat(3, 1), 1);
      expect(r.relativeSeat(0, 1), 3);
      expect(r.relativeSeat(2, 1), 2);
      for (final viewer in [0, 1, 3]) {
        for (final seat in [0, 1, 2, 3]) {
          expect(r.absoluteSeat(r.relativeSeat(seat, viewer), viewer), seat);
        }
      }
      expect(Ruleset.riichi.relativeSeat(1, 2), 3);
    });
  });

  group('wall and deal', () {
    test('108 tiles without 2-8 man; one red five in pin and sou', () {
      final r = Round(
          seed: 7,
          dealer: 0,
          roundWind: Wind.east,
          startingPoints: List.filled(4, 35000),
          ruleset: Ruleset.sanma);
      expect(r.seats[2].hand, isEmpty);
      for (final seat in [0, 1, 3]) {
        expect(r.seats[seat].hand.length, seat == 0 ? 14 : 13);
      }
      final seen = [for (final s in r.seats) ...s.hand];
      final wall = r.wall as SanmaWall;
      while (!wall.isEmpty) {
        seen.add(wall.drawLive());
      }
      // 14 left in the dead wall.
      expect(seen, hasLength(108 - 14));
      expect(seen.every((t) => SanmaRules.inWall(t.type)), isTrue);
      expect(seen.where((t) => t.aka).every((t) => t.type.number == 5),
          isTrue);
      expect(seen.where((t) => t.aka && t.type.isMan), isEmpty);
      expect(SanmaRules.inWall(TileType.man1), isTrue);
      expect(SanmaRules.inWall(TileType.man9), isTrue);
      expect(SanmaRules.inWall(TileType.man5), isFalse);
    });

    test('turns go 0, 1, 3 and never to the empty seat', () {
      final r = Round(
          seed: 11,
          dealer: 0,
          roundWind: Wind.east,
          startingPoints: List.filled(4, 35000),
          ruleset: Ruleset.sanma);
      final order = <int>[];
      for (var i = 0; i < 9 && !r.finished; i++) {
        if (r.phase == RoundPhase.callOffer) r.resolveCalls(const {});
        if (r.phase != RoundPhase.discarding) break;
        order.add(r.turn);
        // Kita would change who is to play next; take the plain draw.
        final seat = r.seats[r.turn];
        r.discard(r.turn, seat.drawn ?? seat.hand.last);
      }
      expect(order.take(6), [0, 1, 3, 0, 1, 3]);
    });
  });

  test('there is no chi', () {
    final r = fixture();
    setHand(r, 0, _junkA, drawn: '5s');
    setHand(r, 1, '34s 19m 1258p 1356z');
    r.discard(0, r.seats[0].drawn!);
    expect(r.canChi(1, r.pendingDiscard!), isFalse);
    expect(r.callOptions.where((o) => o.types.contains(CallType.chi)),
        isEmpty);
  });

  group('kita', () {
    test('sets a North aside and draws a replacement, turning no dora', () {
      final r = fixture(replacements: tiles('2s 3s 4s 5s'));
      setHand(r, 0, '19m 1258p 147s 135z', drawn: '4z');
      final live = r.wall.remaining;
      expect(r.canKita(0), isTrue);
      r.declareKita(0);
      final s = r.seats[0];
      expect(s.kita.map((t) => t.type), [TileType.pei]);
      expect(s.hand.any((t) => t.type == TileType.pei), isFalse);
      expect(s.drawn!.type, TileType.sou2);
      expect(s.replacementDraw, isTrue, reason: 'a win on it is rinshan');
      expect(r.wall.doraIndicators(), hasLength(1));
      expect(r.wall.remaining, live - 1, reason: 'the haitei moves over');
      expect(r.phase, RoundPhase.discarding);
      expect(r.turn, 0);
    });

    test('is not offered without a North, or to four-player riichi', () {
      final r = fixture();
      setHand(r, 0, _junkA, drawn: '2p');
      expect(r.canKita(0), isFalse);
      expect(Ruleset.riichi.isSanma, isFalse);
    });

    test('a hand in riichi may set aside only the North it just drew', () {
      final r = fixture();
      setHand(r, 0, '123p 456p 789p 11s 4z', drawn: '9p');
      r.seats[0].riichi = true;
      expect(r.canKita(0), isFalse, reason: 'the held North is its wait');
      setHand(r, 0, '123p 456p 789p 11s 2s', drawn: '4z');
      expect(r.canKita(0), isTrue);
    });

    test('ends the first go-around and every ippatsu', () {
      final r = fixture();
      setHand(r, 0, '19m 1258p 147s 135z', drawn: '4z');
      r.seats[1].ippatsu = true;
      r.declareKita(0);
      expect(r.seats[1].ippatsu, isFalse);
      expect(r.canDeclareKyuushu(0), isFalse);
    });

    test('can be ronned, which is not chankan', () {
      final r = fixture();
      setHand(r, 0, '19m 1258p 147s 135z', drawn: '4z');
      setHand(r, 1, '123p 456p 789p 111s 4z');
      r.seats[1].riichi = true;
      r.declareKita(0);
      expect(r.kitaPending, isTrue);
      expect(r.callOptions.single.seat, 1);
      expect(r.callOptions.single.types, {CallType.ron});
      r.resolveCalls({1: CallType.ron});
      final res = r.result!;
      expect(res.kind, RoundEndKind.ron);
      expect(res.winners, [1]);
      expect(res.loser, 0);
      expect(res.score!.yaku.map((y) => y.name), isNot(contains('Chankan')));
      expect(r.seats[0].kita, isEmpty, reason: 'the North went to the winner');
    });

    test('passed up, it draws the replacement', () {
      final r = fixture(replacements: tiles('2s 3s 4s 5s'));
      setHand(r, 0, '19m 1258p 147s 135z', drawn: '4z');
      setHand(r, 1, '123p 456p 789p 111s 4z');
      r.seats[1].riichi = true;
      r.declareKita(0);
      r.resolveCalls(const {});
      expect(r.seats[0].drawn!.type, TileType.sou2);
      expect(r.seats[1].riichiFuriten, isTrue);
    });

    test('scores as dora, twice when the indicator points to North', () {
      final hand = tiles('234p 567p 789p 234s 5s');
      final win = tiles('5s').single;
      HandScore score(List<TileType> dora, int kita) => scoreHand(
          hand,
          win,
          const [],
          ScoreContext(
              roundWind: Wind.east,
              seatWind: Wind.south,
              isTsumo: false,
              closed: true,
              riichi: true,
              doraIndicators: dora,
              kita: kita,
              sanma: true),
          isDealer: false);
      int han(HandScore s, String name) =>
          s.yaku.where((y) => y.name == name).fold(0, (a, y) => a + y.han);
      final two = score(const [TileType.haku], 2);
      expect(han(two, 'Kita'), 2);
      expect(han(two, 'Dora'), 0);
      final pointed = score(const [TileType.shaa], 2);
      expect(han(pointed, 'Kita'), 2);
      expect(han(pointed, 'Dora'), 2);
    });
  });

  test('a 1m indicator makes 9m the dora', () {
    final hand = tiles('999m 234p 567p 234s 5s');
    final win = tiles('5s').single;
    HandScore score({required bool sanma}) => scoreHand(
        hand,
        win,
        const [],
        ScoreContext(
            roundWind: Wind.east,
            seatWind: Wind.south,
            isTsumo: false,
            closed: true,
            riichi: true,
            doraIndicators: const [TileType.man1],
            sanma: sanma),
        isDealer: false);
    int dora(HandScore s) =>
        s.yaku.where((y) => y.name == 'Dora').fold(0, (a, y) => a + y.han);
    expect(dora(score(sanma: true)), 3);
    expect(dora(score(sanma: false)), 0);
  });

  test('a self-draw is paid by the two others only: tsumo loss', () {
    final r = fixture(dealer: 0);
    setHand(r, 1, '123p 456p 789p 111s 2s', drawn: '2s');
    r.seats[1].riichi = true;
    r.turn = 1;
    r.declareTsumo(1);
    final res = r.result!;
    final score = res.score!;
    expect(res.pointDeltas[0], -score.dealerPays);
    expect(res.pointDeltas[3], -score.nonDealerPays);
    expect(res.pointDeltas[2], 0);
    expect(res.pointDeltas[1], score.dealerPays + score.nonDealerPays);
    expect(res.pointDeltas[1]! < score.points, isTrue,
        reason: 'less than the same hand by ron');
  });

  test('an exhaustive draw moves 2,000 between tenpai and noten', () {
    final r = fixture(live: const []);
    setHand(r, 0, '123p 456p 789p 111s 2s', drawn: '9m');
    setHand(r, 1, _junkA);
    setHand(r, 3, _junkB);
    expect(r.wall.remaining, 0);
    r.discard(0, r.seats[0].drawn!);
    if (r.phase == RoundPhase.callOffer) r.resolveCalls(const {});
    final res = r.result!;
    expect(res.kind, RoundEndKind.exhaustiveDraw);
    expect(res.tenpaiAtDraw, [0]);
    expect(res.pointDeltas[0], 2000);
    expect(res.pointDeltas[1], -1000);
    expect(res.pointDeltas[3], -1000);
    expect(res.pointDeltas[2], 0);
  });

  test('a snapshot keeps kita and the empty seat across, for any viewer', () {
    final r = fixture(replacements: tiles('2s 3s 4s 5s'));
    setHand(r, 0, '19m 1258p 147s 135z', drawn: '4z');
    r.declareKita(0);
    final json = roundSnapshotToJson(r, reveal: (s) => s == 1);
    final mine = buildRoundFromSnapshot(json, mySeat: 1);
    expect(mine.ruleset, Ruleset.sanma);
    // Server seat 0 sits on seat 1's left, local seat 3.
    expect(mine.seats[3].kita.map((t) => t.type), [TileType.pei]);
    expect(mine.seats[2].hand, isEmpty);
    expect(mine.dealer, 3);
    expect(mine.turn, 3);
    final wall = mine.wall as SanmaWall;
    // The fixture's dead wall holds four replacements; one is taken.
    expect(wall.replacementsLeft, 3);
    expect(wall.canKita, isTrue);
  });

  test('bots play whole hands: payments balance and the empty seat sits out',
      () {
    var wins = 0;
    var kitas = 0;
    for (var seed = 1; seed <= 80; seed++) {
      final dealer = const [0, 1, 3][seed % 3];
      final r = Round(
          seed: seed,
          dealer: dealer,
          roundWind: Wind.east,
          startingPoints: List.filled(4, 35000),
          ruleset: Ruleset.sanma);
      final bot = SimpleBot(seed);
      for (var step = 0; step < 400 && !r.finished; step++) {
        expect(r.turn, isNot(2), reason: 'seed $seed');
        if (r.phase == RoundPhase.callOffer) {
          expect(r.callOptions.every((o) => o.seat != 2), isTrue);
          r.resolveCalls({
            for (final o in r.callOptions)
              o.seat: bot.decideCall(r, o.seat, r.pendingDiscard!, o.types),
          });
          continue;
        }
        final turn = bot.decideTurn(r, r.turn);
        if (turn.tsumo) {
          r.declareTsumo(r.turn);
        } else if (turn.kita) {
          kitas++;
          r.declareKita(r.turn);
        } else if (turn.closedKan != null) {
          r.closedKan(r.turn, turn.closedKan!);
        } else if (turn.addedKan != null) {
          r.addKan(r.turn, turn.addedKan!);
        } else {
          r.discard(r.turn, turn.discard!, declareRiichi: turn.riichi);
        }
      }
      expect(r.finished, isTrue, reason: 'seed $seed');
      final res = r.result!;
      expect(r.seats[2].hand, isEmpty);
      expect(res.pointDeltas[2] ?? 0, 0, reason: 'seed $seed');
      final paid = res.pointDeltas.values.fold<int>(0, (a, b) => a + b);
      // Riichi sticks left on the table at a draw are the only imbalance.
      expect(paid + r.riichiSticks * 1000, 0, reason: 'seed $seed');
      if (res.winners.isNotEmpty) wins++;
    }
    expect(wins, greaterThan(10));
    expect(kitas, greaterThan(10), reason: 'Norths are set aside as kita');
  });
}
