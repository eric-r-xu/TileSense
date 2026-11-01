import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/scoring.dart';
import 'package:mahjong_core/tile.dart';

import 'helpers.dart';

void main() {
  HandScore score(
    String concealed13,
    String winTile, {
    bool tsumo = false,
    bool closed = true,
    bool riichi = false,
    Wind round = Wind.east,
    Wind seat = Wind.south,
    bool dealer = false,
    List<String> dora = const [],
  }) {
    final hand = parseTiles(concealed13);
    expect(hand.length, 13, reason: 'concealed hand must be 13 tiles');
    final win = parseTiles(winTile).single;
    final ctx = ScoreContext(
      roundWind: round,
      seatWind: seat,
      isTsumo: tsumo,
      closed: closed,
      riichi: riichi,
      doraIndicators: [for (final d in dora) parseTypes(d).single],
    );
    return scoreHand(hand, win, const [], ctx, isDealer: dealer);
  }

  test('riichi + pinfu + tsumo', () {
    final s = score('234m 567m 34p 33s 456s', '2p', tsumo: true, riichi: true);
    expect(s.valid, isTrue);
    expect(s.yaku.map((y) => y.name),
        containsAll(['Riichi', 'Menzen Tsumo', 'Pinfu', 'Tanyao']));
    expect(s.fu, 20);
  });

  group('pinfu on a terminal', () {
    test('9 finishing 789 from 78 is a two-sided wait', () {
      // Grant's hand: 4-8m waits on 3m, 6m and 9m; the 9m completes 789.
      final s = score('22m 45678m 22p 33p 44p', '9m', riichi: true);
      expect(s.yaku.map((y) => y.name),
          containsAll(['Riichi', 'Iipeiko', 'Pinfu']));
      expect(s.fu, 30);
      expect(s.han, 3);
    });

    test('1 finishing 123 from 23 is a two-sided wait', () {
      // Orderic's hand: 2-6m waits on 1m and 4m and 7m.
      final s = score('23456m 66789p 678s', '1m', riichi: true);
      expect(s.yaku.map((y) => y.name), containsAll(['Riichi', 'Pinfu']));
      expect(s.fu, 30);
      expect(s.han, 2);
    });

    test('12 waiting on 3 is still an edge wait, so no pinfu', () {
      final s = score('12m 456m 789m 234p 55s', '3m', riichi: true);
      expect(s.yaku.any((y) => y.name == 'Pinfu'), isFalse);
      // Edge wait: 20 + 10 menzen ron + 2.
      expect(s.fu, 40);
    });

    test('89 waiting on 7 is still an edge wait, so no pinfu', () {
      final s = score('89m 123m 456m 234p 55s', '7m', riichi: true);
      expect(s.yaku.any((y) => y.name == 'Pinfu'), isFalse);
      expect(s.fu, 40);
    });

    test('a wait that reads as ryanmen or kanchan takes the ryanmen', () {
      // 34456m + 5m: the 5m completes 345 from 34 (two-sided, 2m/5m), or
      // 456 from 46 (kanchan). The two-sided reading is the one that counts.
      final s = score('34m 456m 789m 234p 55s', '5m', riichi: true);
      expect(s.yaku.any((y) => y.name == 'Pinfu'), isTrue);
      expect(s.fu, 30);
    });
  });

  test('tanyao + pinfu closed ron', () {
    final s = score('234m 567m 234p 55p 78s', '6s');
    expect(s.valid, isTrue);
    expect(s.yaku.any((y) => y.name == 'Tanyao'), isTrue);
    expect(s.fu, 30);
  });

  test('yakuhai (green dragon) triplet', () {
    final s = score('234m 678m 234p 55s GG', 'G');
    expect(s.valid, isTrue);
    expect(s.yaku.any((y) => y.name.contains('Green Dragon')), isTrue);
  });

  test('chiitoitsu is 2 han 25 fu', () {
    final s = score('11m 44m 77m 22p 99p 33s 7s', '7s', riichi: true);
    expect(s.valid, isTrue);
    expect(s.yaku.any((y) => y.name == 'Chiitoitsu'), isTrue);
    expect(s.fu, 25);
  });

  group('seven pairs still takes the yaku for how it was won', () {
    // Sherman's hand: 22p 55p 33s 55s 88s 99s and a green dragon pair.
    HandScore win({
      bool riichi = false,
      bool doubleRiichi = false,
      bool ippatsu = false,
      bool tsumo = false,
      bool haitei = false,
      bool houtei = false,
    }) =>
        scoreHand(
          parseTiles('22p 55p 33s 55s 88s 99s G'),
          parseTiles('G').single,
          const [],
          ScoreContext(
            roundWind: Wind.east,
            seatWind: Wind.west,
            isTsumo: tsumo,
            closed: true,
            riichi: riichi,
            doubleRiichi: doubleRiichi,
            ippatsu: ippatsu,
            haitei: haitei,
            houtei: houtei,
            sanma: true,
          ),
          isDealer: false,
        );

    Map<String, int> yaku(HandScore s) => {for (final y in s.yaku) y.name: y.han};

    test('a plain win is just chiitoitsu', () {
      final s = win();
      expect(yaku(s), {'Chiitoitsu': 2});
      expect(s.han, 2);
      expect(s.fu, 25);
    });

    test('double riichi adds its 2 han', () {
      final s = win(doubleRiichi: true);
      expect(yaku(s), {'Double Riichi': 2, 'Chiitoitsu': 2});
      expect(s.han, 4);
      expect(s.fu, 25);
    });

    test('riichi, ippatsu, tsumo, haitei and houtei count too', () {
      expect(yaku(win(riichi: true))['Riichi'], 1);
      expect(yaku(win(riichi: true, ippatsu: true))['Ippatsu'], 1);
      expect(yaku(win(tsumo: true))['Menzen Tsumo'], 1);
      expect(yaku(win(tsumo: true, haitei: true))['Haitei Raoyue'], 1);
      expect(yaku(win(houtei: true))['Houtei Raoyui'], 1);
      expect(win(riichi: true, ippatsu: true, tsumo: true).han, 5);
    });

    /// A closed seven-pairs ron on [last], the other twelve tiles [rest].
    HandScore pairs(String rest, String last) => scoreHand(
          parseTiles(rest),
          parseTiles(last).single,
          const [],
          ScoreContext(
            roundWind: Wind.east,
            seatWind: Wind.south,
            isTsumo: false,
            closed: true,
          ),
          isDealer: false,
        );

    test('tanyao counts when every pair is a simple', () {
      final s = pairs('22p 44p 66p 33s 55s 77s 8s', '8s');
      expect(yaku(s), {'Chiitoitsu': 2, 'Tanyao': 1});
      expect(s.han, 3);
      expect(s.fu, 25);
    });

    test('one terminal or honor pair means no tanyao', () {
      expect(yaku(pairs('22p 44p 66p 33s 55s 77s 1s', '1s')).containsKey('Tanyao'),
          isFalse);
    });

    test('honroutou counts when every pair is a terminal or honor', () {
      final s = pairs('11m 99m 11p 99p 11s 99s E', 'E');
      expect(yaku(s), {'Chiitoitsu': 2, 'Honroutou': 2});
      expect(s.han, 4);
    });

    test('chinitsu and honitsu count at their closed values', () {
      final chinitsu = pairs('11p 22p 44p 55p 77p 88p 9p', '9p');
      expect(yaku(chinitsu), {'Chiitoitsu': 2, 'Chinitsu': 6});
      final honitsu = pairs('11m 99m EE SS WW BB G', 'G');
      // One suit and honors, and every pair a terminal or honor.
      expect(yaku(honitsu), {'Chiitoitsu': 2, 'Honroutou': 2, 'Honitsu': 3});
    });

    test('a seven-pair yakuman is unchanged by riichi', () {
      HandScore honors(bool riichi) => scoreHand(
            parseTiles('EE SS WW NN BB GG R'),
            parseTiles('R').single,
            const [],
            ScoreContext(
              roundWind: Wind.east,
              seatWind: Wind.south,
              isTsumo: false,
              closed: true,
              riichi: riichi,
            ),
            isDealer: false,
          );
      expect(honors(true).yakuman, honors(false).yakuman);
      expect(honors(true).yaku.any((y) => y.name == 'Riichi'), isFalse);
    });
  });

  test('kokushi is a yakuman worth 32000 for a non-dealer', () {
    final s = score('19m 19p 19s E S W N B G R', '1m');
    expect(s.yakuman, greaterThanOrEqualTo(1));
    expect(s.points, 32000);
  });

  test('chuuren poutou (dealer) is a yakuman', () {
    final s = score('11122345678m 99m', '9m', dealer: true, seat: Wind.east);
    expect(s.yakuman, greaterThanOrEqualTo(1));
    expect(s.points, 48000);
  });

  test('yakuless open hand is invalid', () {
    final s = score('234m 456m 789m 234p 9p', '9p', closed: false);
    expect(s.valid, isFalse);
  });

  test('dora only counts with a real yaku', () {
    final s = score('234m 567m 234p 55p 78s', '6s', dora: ['2m']); // indicator 2m -> dora 3m
    expect(s.valid, isTrue);
    expect(s.yaku.any((y) => y.name == 'Dora'), isTrue); // 2x 3m in hand
  });
}
