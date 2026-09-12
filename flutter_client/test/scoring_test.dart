import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/logic/meld.dart';
import 'package:tilesense/logic/scoring.dart';
import 'package:tilesense/logic/tile.dart';
import 'helpers.dart';

HandScore hkScore(String hand, String win,
        {bool self = false,
        List<Meld> melds = const [],
        List<TileType> flowers = const [],
        bool flowersEnabled = false,
        Wind seat = Wind.south,
        bool replacement = false,
        bool last = false,
        bool robbed = false,
        bool legacy = false}) =>
    scoreHand(
        parseTiles(hand),
        Tile(900, parseTypes(win).single),
        melds,
        ScoreContext(
            roundWind: Wind.east,
            seatWind: seat,
            isTsumo: self,
            closed: melds.every((m) => m.concealed),
            flowers: flowers,
            flowersEnabled: flowersEnabled,
            rinshan: replacement,
            haitei: last,
            chankan: robbed,
            riichi: legacy,
            ippatsu: legacy,
            doraIndicators: legacy ? [TileType.man1] : [],
            akaCount: legacy ? 3 : 0),
        isDealer: seat == Wind.east);

void main() {
  test('open zero-faan hand can win', () {
    final s = hkScore('456p 789s 22m 55p', '5p', melds: [
      Meld(kind: MeldKind.sequence, low: TileType.man1, concealed: false)
    ]);
    expect(s.valid, isTrue);
    expect(s.faan, 0);
    expect(s.points, 2);
  });
  test('no riichi, dora, red-five, ippatsu or fu scoring', () {
    final plain = hkScore('123m 456p 789s 22m 55p', '5p');
    final legacy = hkScore('123m 456p 789s 22m 55p', '5p', legacy: true);
    expect(legacy.points, plain.points);
    expect(legacy.faan, plain.faan);
    expect(legacy.fu, 0);
  });
  test('all sequences plus the concealed-hand bonus', () {
    expect(hkScore('123m 456p 789s 22m 45p', '6p').faan, 2);
    expect(
        hkScore('456p 789s 22m 45p', '6p', melds: [
          Meld(kind: MeldKind.sequence, low: TileType.man1, concealed: false)
        ]).faan,
        1);
  });
  test('dragon pung and double wind each score', () {
    expect(hkScore('123m 456p 789s 22m GG', 'G').faan, 2);
    expect(hkScore('123m 456p 789s 22m EE', 'E', seat: Wind.east).faan, 3);
  });
  test('all pungs, half flush, full flush', () {
    expect(hkScore('111m 444p 777s 22m 55p', '5p').faan, 4);
    expect(hkScore('123m 456m 999m SS NN', 'N').faan, 4);
    expect(hkScore('123m 456m 999m 22m 88m', '8m').faan, 8);
  });
  test('flush sees exposed melds in another suit', () {
    expect(
        hkScore('456m 999m 22m 88m', '8m', melds: [
          Meld(kind: MeldKind.sequence, low: TileType.pin1, concealed: false)
        ]).faan,
        0);
  });
  test('seven pairs scores four faan', () {
    expect(hkScore('11m 44m 77m 22p 99p 33s 7s', '7s').faan, 5);
  });
  test('little dragons includes its two dragon pungs once', () {
    final score = hkScore('123m 456p BBB GGG R', 'R');
    expect(score.faan, 6);
    expect(score.yaku.map((p) => p.name),
        ['Small Three Dragons', 'Concealed Hand']);
  });
  for (final hand in {
    'Thirteen Orphans': ('19m 19p 19s E S W N B G R', '1m'),
    'Nine Gates': ('1112345678999m', '5m'),
    'Big Three Dragons': ('BBB GGG RRR 123m E', 'E'),
    'Small Four Winds': ('EEE SSS WWW NN 12m', '3m'),
    'Big Four Winds': ('EEE SSS WWW NNN 1m', '1m'),
    'All Honours': ('EEE SSS BBB GGG R', 'R'),
    'All Terminals': ('111m 999m 111p 999p 1s', '1s'),
  }.entries) {
    test('${hand.key} matches the sheet', () {
      final score = hkScore(hand.value.$1, hand.value.$2);
      expect(score.valid, isTrue);
      final value = {
        'Thirteen Orphans': 13,
        'Nine Gates': 13,
        'Big Three Dragons': 8,
        'Small Four Winds': 6,
        'Big Four Winds': 13,
        'All Honours': 10,
        'All Terminals': 13
      }[hand.key]!;
      expect(score.yaku.singleWhere((p) => p.name == hand.key).faan, value);
      expect(score.points, HongKongRules.basePoints(score.faan) * 2);
    });
  }
  test('discard must complete the pair for four concealed triplets', () {
    expect(hkScore('111m 444p 777s 22m 55p', '5p').faan, 4);
    expect(hkScore('111m 444p 777s 22m 55p', '5p', self: true).faan, 10);
  });
  test('flower seat matching, sets, and no-flower bonus', () {
    const hand = '123m 456p 789s 22m 55p';
    expect(hkScore(hand, '5p', flowersEnabled: true).faan, 2);
    expect(
        hkScore(hand, '5p', flowersEnabled: true, flowers: [TileType.plum])
            .faan,
        1);
    expect(
        hkScore(hand, '5p',
            flowersEnabled: true,
            flowers: [TileType.orchid, TileType.summer]).faan,
        3);
    expect(
        hkScore(hand, '5p', flowersEnabled: true, flowers: [
          TileType.plum,
          TileType.orchid,
          TileType.chrysanthemum,
          TileType.bamboo
        ]).faan,
        4);
  });
  test('self draw, last tile, kong replacement and robbery', () {
    const hand = '123m 456p 789s 22m 55p';
    expect(hkScore(hand, '5p', self: true).faan, 2);
    expect(
        hkScore(hand, '5p', self: true, last: true, replacement: true).faan, 4);
    expect(hkScore(hand, '5p', robbed: true).faan, 2);
  });
  test('faan bands and cap', () {
    expect([for (var n = 0; n <= 13; n++) HongKongRules.basePoints(n)],
        [1, 2, 4, 8, 16, 24, 32, 48, 64, 96, 128, 192, 256, 384]);
  });
  test('malformed hand and fifth copies cannot win', () {
    expect(hkScore('123m 456p', '7s').valid, isFalse);
    expect(hkScore('11111m 234p 567s 88p', '8p').valid, isFalse);
  });
}
