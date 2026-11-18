import 'package:mahjong_core/mahjong_core.dart';
import 'package:test/test.dart';

import 'sanma/helpers.dart' show tiles;

/// A four-player riichi round with every seat emptied, seat [turn] to
/// discard. Tests plant hands and melds directly.
Round blank({int turn = 0, int honba = 0}) {
  final round = Round(
    seed: 11,
    dealer: 0,
    roundWind: Wind.east,
    honba: honba,
    startingPoints: List.filled(4, 25000),
  );
  for (final s in round.seats) {
    s.hand = [];
    s.drawn = null;
    s.melds = [];
  }
  round.turn = turn;
  round.phase = RoundPhase.discarding;
  return round;
}

Meld kan(String t, {bool concealed = false}) {
  final ts = tiles(t);
  return Meld(
      kind: MeldKind.kan,
      low: ts.first.type,
      concealed: concealed,
      calledFromSeatOffset: concealed ? null : 2,
      tiles: ts);
}

Meld pon(String t, {int from = 2}) {
  final ts = tiles(t);
  return Meld(
      kind: MeldKind.triplet,
      low: ts.first.type,
      concealed: false,
      calledFromSeatOffset: from,
      tiles: ts);
}

void main() {
  group('suukaikan', () {
    Round fourthKan({required bool sameSeat}) {
      final round = blank();
      final kanSeat = round.seats[sameSeat ? 0 : 1];
      kanSeat.melds = [kan('2222z'), kan('3333z'), kan('4444z')];
      if (!sameSeat) round.seats[1].hand = tiles('5678s');
      round.seats[0].hand = [
        ...tiles('1111m'),
        ...(sameSeat ? tiles('9p') : tiles('9p 258s 147p 369m')),
      ];
      // Seat 2 could pon the 9p.
      round.seats[2].hand = tiles('99p 123m 456m 789m 5z');
      round.closedKan(0, TileType.man1);
      final nine = round.seats[0].hand.firstWhere((t) => t.type == TileType.pin9);
      round.discard(0, nine);
      return round;
    }

    test('a fourth kan split between seats aborts after the next discard', () {
      final round = fourthKan(sameSeat: false);
      expect(round.finished, isTrue);
      expect(round.result!.kind, RoundEndKind.abortiveDraw);
      expect(round.result!.label, contains('Suukaikan'));
      expect(round.result!.pointDeltas.values.every((d) => d == 0), isTrue);
    });

    test('four kans by one seat play on', () {
      final round = fourthKan(sameSeat: true);
      expect(round.finished, isFalse);
      // Pon is still offered on the discard.
      expect(round.callOptions.single.types, contains(CallType.pon));
    });

    test('the discard after the fourth kan can still be ronned', () {
      final round = blank();
      round.seats[1].melds = [kan('2222z'), kan('3333z'), kan('4444z')];
      round.seats[1].hand = tiles('5678s');
      round.seats[0].hand = tiles('1111m 9p 258s 147p 369m');
      round.seats[2].hand = tiles('9p 123m 456m 789m 789s');
      round.seats[3].hand = tiles('99p 123p 456p 234s 6z');
      round.closedKan(0, TileType.man1);
      final nine =
          round.seats[0].hand.firstWhere((t) => t.type == TileType.pin9);
      round.discard(0, nine);
      expect(round.phase, RoundPhase.callOffer);
      // Only ron is on offer: seat 3's pon is withheld.
      expect(round.callOptions.map((o) => o.seat), [2]);
      expect(round.callOptions.single.types, {CallType.ron});
      round.resolveCalls({2: CallType.ron});
      expect(round.result!.kind, RoundEndKind.ron);
    });
  });

  group('delayed kan dora', () {
    test('a closed kan turns its indicator at once', () {
      final round = blank();
      round.seats[0].hand = tiles('1111m 9p 258s 147p 369m');
      round.closedKan(0, TileType.man1);
      expect(round.wall.doraIndicators(), hasLength(2));
    });

    test('an added kan turns its indicator only on the discard', () {
      final round = blank();
      round.seats[0].melds = [pon('555z')];
      round.seats[0].hand = tiles('5z 9p 258s 147p 369m');
      round.addKan(0, TileType.haku);
      expect(round.phase, RoundPhase.discarding);
      expect(round.wall.doraIndicators(), hasLength(1));
      final nine =
          round.seats[0].hand.firstWhere((t) => t.type == TileType.pin9);
      round.discard(0, nine);
      expect(round.wall.doraIndicators(), hasLength(2));
    });

    test('an open kan turns its indicator only on the discard', () {
      final round = blank(turn: 3);
      final six = tiles('6z').single;
      round.seats[3].hand = [six, ...tiles('123m')];
      round.seats[0].hand = tiles('666z 9p 258s 147p 369m');
      round.discard(3, six);
      round.resolveCalls({0: CallType.kan});
      expect(round.turn, 0);
      expect(round.wall.doraIndicators(), hasLength(1));
      final nine =
          round.seats[0].hand.firstWhere((t) => t.type == TileType.pin9);
      round.discard(0, nine);
      expect(round.wall.doraIndicators(), hasLength(2));
    });

    test('a kan declared before the discard turns the held-back indicator',
        () {
      final round = blank();
      round.seats[0].melds = [pon('555z')];
      round.seats[0].hand = tiles('5z 1111m 9p 147p 369m');
      round.addKan(0, TileType.haku);
      expect(round.wall.doraIndicators(), hasLength(1));
      round.closedKan(0, TileType.man1);
      expect(round.wall.doraIndicators(), hasLength(3));
    });
  });

  group('pao', () {
    /// Seat 0 (dealer) pons the third dragon off seat 2, then waits on 3m/6m.
    Round daisangen({int honba = 0}) {
      final round = blank(turn: 2, honba: honba);
      round.seats[0].melds = [pon('555z'), pon('666z')];
      round.seats[0].hand = tiles('77z 45m 99m 9p');
      final red = tiles('7z').single;
      round.seats[2].hand = [red, ...tiles('123s')];
      round.discard(2, red);
      round.resolveCalls({0: CallType.pon});
      expect(round.seats[0].paoSeat, 2);
      final nine =
          round.seats[0].hand.firstWhere((t) => t.type == TileType.pin9);
      round.discard(0, nine);
      if (round.phase == RoundPhase.callOffer) round.resolveCalls({});
      return round;
    }

    test('tsumo: the liable seat pays the whole yakuman and the honba', () {
      final round = daisangen(honba: 1);
      // Pose the self-draw directly.
      final draw = tiles('6m').single;
      final s = round.seats[0];
      s.hand = [...s.hand, draw];
      s.drawn = draw;
      round.turn = 0;
      round.phase = RoundPhase.discarding;
      round.declareTsumo(0);
      final r = round.result!;
      expect(r.paoPayers, {0: 2});
      expect(r.pointDeltas, {0: 48300, 1: 0, 2: -48300, 3: 0});
    });

    test('ron by another seat: the discarder and liable seat split it', () {
      final round = daisangen();
      final six = tiles('6m').single;
      round.seats[1].hand = [six, ...tiles('123s')];
      round.seats[1].drawn = six;
      round.turn = 1;
      round.phase = RoundPhase.discarding;
      round.discard(1, six);
      round.resolveCalls({0: CallType.ron});
      final r = round.result!;
      expect(r.paoPayers, {0: 2});
      expect(r.pointDeltas, {0: 48000, 1: -24000, 2: -24000, 3: 0});
    });

    test('ron by the liable seat: it pays everything', () {
      final round = daisangen();
      final six = tiles('6m').single;
      round.seats[2].hand = [six, ...tiles('12s')];
      round.seats[2].drawn = six;
      round.turn = 2;
      round.phase = RoundPhase.discarding;
      round.discard(2, six);
      round.resolveCalls({0: CallType.ron});
      expect(round.result!.pointDeltas, {0: 48000, 1: 0, 2: -48000, 3: 0});
    });

    test('daisuushii: the fourth wind pon makes the feeder liable', () {
      final round = blank(turn: 3);
      round.seats[0].melds = [pon('111z'), pon('222z'), pon('333z')];
      round.seats[0].hand = tiles('44z 5p 9p');
      final north = tiles('4z').single;
      round.seats[3].hand = [north, ...tiles('123s')];
      round.discard(3, north);
      round.resolveCalls({0: CallType.pon});
      expect(round.seats[0].paoSeat, 3);
      expect(round.seats[0].paoYaku, 'Daisuushii');
    });
  });

  group('kokushi robs a closed kan', () {
    Round ankan() {
      final round = blank();
      round.seats[0].hand = tiles('1111z 9p 258s 147p 369m');
      // Kokushi tenpai on East.
      round.seats[1].hand = tiles('19m 19p 19s 234567z 9m');
      // An ordinary tanki on East may not rob it.
      round.seats[2].hand = tiles('1z 123m 456m 789m 234p');
      round.closedKan(0, TileType.ton);
      return round;
    }

    test('only the kokushi hand is offered ron', () {
      final round = ankan();
      expect(round.phase, RoundPhase.callOffer);
      expect(round.chankanPending, isTrue);
      expect(round.callOptions.map((o) => o.seat), [1]);
      round.resolveCalls({1: CallType.ron});
      final r = round.result!;
      expect(r.kind, RoundEndKind.ron);
      expect(r.winners, [1]);
      expect(r.score!.yaku.map((y) => y.name), contains('Kokushi Musou'));
      // The kan was robbed, so it turned no indicator.
      expect(round.wall.doraIndicators(), hasLength(1));
    });

    test('passed, the kan completes and the kokushi hand is furiten', () {
      final round = ankan();
      round.resolveCalls({});
      expect(round.phase, RoundPhase.discarding);
      expect(round.turn, 0);
      expect(round.wall.doraIndicators(), hasLength(2));
      expect(round.seats[1].tempFuriten, isTrue);
      expect(round.seats[2].tempFuriten, isFalse);
    });

    test('no kokushi waiting: the closed kan goes straight through', () {
      final round = blank();
      round.seats[0].hand = tiles('1111z 9p 258s 147p 369m');
      round.seats[2].hand = tiles('1z 123m 456m 789m 234p');
      round.closedKan(0, TileType.ton);
      expect(round.phase, RoundPhase.discarding);
      expect(round.wall.doraIndicators(), hasLength(2));
    });
  });
}
