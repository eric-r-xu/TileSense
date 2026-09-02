import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/logic/scoring.dart';
import 'package:tilesense/logic/tile.dart';

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
