import 'package:mahjong_core/mahjong_core.dart';
import 'package:test/test.dart';
import 'helpers.dart';

void main() {
  final fixtures = <int, HandScore Function()>{
    1: () => score('111z 222z 333z 444z 55z'),
    2: () => score('555z 666z 777z 123m 22p'),
    3: () => score('222s 333s 444s 666s 66z'),
    4: () => score('11123456789995m'),
    5: () => score('1111m 4444p 7777s 1111z 22p', kongs: {0, 1, 2, 3}),
    6: () => score('11223344556677m'),
    7: () => score('19m 19p 19s 12345677z'),
    8: () => score('111m 999m 111p 999p 11s', open: 1),
    9: () => score('111z 222z 333z 123m 44z'),
    10: () => score('555z 666z 123m 456p 77z'),
    11: () => score('111z 333z 555z 777z 22z', open: 1),
    12: () => score('111m 444p 777s 111z 22p'),
    13: () => score('123m 123m 789m 789m 55m'),
    14: () => score('234m 234m 234m 234m 77p'),
    15: () => score('222m 333m 444m 555m 77p', open: 1),
    16: () => score('123m 234m 345m 456m 99p'),
    17: () => score('1111m 4444p 7777s 234m 22p', kongs: {0, 1, 2}),
    18: () => score('111m 999p 111z 333z 99s', open: 1),
    19: () => score('11m 33m 55p 88p 22s 66s 77z'),
    20: () => score('147m 258p 3s 1234567z'),
    21: () => score('222m 444m 666p 888s 22p', open: 1),
    22: () => score('123m 345m 678m 999m 22m'),
    // Melded so the shifted-pungs reading cannot outscore it (§3.9.1).
    23: () => score('234m 234m 234m 678p 55s', open: 3),
    24: () => score('222m 333m 444m 789s 55p', open: 1),
    25: () => score('789m 789p 789s 999s 88m'),
    26: () => score('456m 456p 456s 444p 55m'),
    27: () => score('123m 123p 123s 111s 22m'),
    28: () => score('123m 456m 789m 456p 22s'),
    29: () => score('123m 789m 123p 789p 55s'),
    30: () => score('123m 345m 567m 789p 22s'),
    31: () => score('345m 456p 567s 555s 55m'),
    32: () => score('333m 333p 333s 789s 22m', open: 1),
    33: () => score('111m 444p 777s 123p 22s'),
    34: () => score('147m 258p 369s 12345z'),
    35: () => score('147m 258p 369s 123m 55z'),
    36: () => score('678m 789p 666s 999m 77p'),
    37: () => score('123m 234p 111s 444m 22p'),
    38: () => score('111z 222z 333z 456m 99p', open: 1),
    39: () => score('123m 456p 789s 444m 22s'),
    40: () => score('123p 456s 888p 999s 55z'),
    41: () => score('234m 234p 234s 789p 55s'),
    42: () => score('222m 333p 444s 789p 66m', open: 1),
    43: () =>
        score('123m 345p 777s 22z 678m', open: 1, last: false, winIndex: 8),
    44: () => score('123m 456p 789s 234p 66z', self: true),
    45: () => score('123m 456p 789s 234p 66z'),
    46: () => score('1111m 234p 567s 789p 22s',
        kongs: {0}, self: true, last: false, replacement: true),
    47: () => score('123m 456p 789s 234p 66z', robbed: true, last: false),
    48: () => score('1111m 4444p 789s 123p 22s', concealedKongs: {0, 1}),
    49: () => score('111m 444p 777s 111z 22p', open: 1),
    50: () => score('123m 456m 789m 111z 22m'),
    51: () => score('123m 234p 345s 789p 66m'),
    52: () => score('123m 456p 789s 111z 55z'),
    53: () => score('123m 456p 789s 222m 66z', open: 4),
    54: () => score('555z 666z 123m 456p 88s'),
    55: () => score('123m 789p 111s 111z 99m'),
    56: () => score('123m 456m 789m 345p 22s', self: true, last: false),
    57: () => score('1111m 4444p 789s 123p 22s', kongs: {0, 1}),
    58: () => score('123m 456p 789s 234p 66z', lastCopy: true),
    59: () => score('555z 123m 456p 789s 22m'),
    60: () => score('111z 123m 456p 789s 22m'),
    61: () => score('222z 123m 456p 789s 22m'),
    62: () => score('123m 456p 789s 234p 66z'),
    63: () => score('123m 456p 789s 234p 66m'),
    64: () => score('111m 123m 456p 789s 66z'),
    65: () => score('222m 222p 456s 789p 66z'),
    66: () => score('111m 444p 789s 123p 22s'),
    67: () => score('1111m 234p 567s 789p 22s', concealedKongs: {0}),
    68: () => score('234m 345p 456s 678p 22s'),
    69: () => score('123m 123m 456p 789s 66z'),
    70: () => score('123m 123p 456p 789s 66z'),
    71: () => score('123m 456m 234p 789s 66z'),
    72: () => score('123m 789m 234p 789s 66z'),
    73: () => score('111m 234p 567s 789p 22s'),
    74: () => score('1111m 234p 567s 789p 22s', kongs: {0}),
    75: () => score('123m 456m 234p 789p 66z'),
    76: () => score('111m 234p 567s 789p 22s'),
    77: () => score('123m 456p 789s 555z 22z', winIndex: 2),
    78: () => score('123m 456p 789s 555z 22z', winIndex: 1),
    79: () => score('123m 456p 789s 555z 22z'),
    80: () =>
        score('123m 456m 789m 555z 22m', open: 1, self: true, last: false),
    81: () => score('123m 456p 789s 234p 66z', flowers: 2),
  };
  for (final fan in mcrFans) {
    test('${fan.id}: ${fan.name}', () {
      final result = fixtures[fan.id]!();
      expect(result.valid, isTrue);
      expect(names(result), contains(fan.name));
      expect(result.yaku.fold<int>(0, (a, f) => a + f.han), result.han);
    });
  }
  test('under-minimum hand cannot qualify through flowers', () {
    final s =
        score('111m 234p 567s 789p 22s', last: false, open: 1, flowers: 8);
    expect(s.valid, isFalse);
  });
  test('flowers add to a valid hand and payments, not qualifying points', () {
    final base = score('123m 456p 789s 234p 66z');
    final flower = score('123m 456p 789s 234p 66z', flowers: 3);
    expect(flower.mcrQualifyingPoints, base.han);
    expect(flower.han, base.han + 3);
    expect(flower.points, base.points + 3);
  });
  test('seven pairs permits four identical tiles', () {
    expect(names(score('1111m 33p 55p 77s 22z 66z')), contains('Seven Pairs'));
  });
  test('fan exclusions and set accounting', () {
    final wind = names(fixtures[1]!());
    expect(wind, isNot(contains('All Pungs')));
    expect(wind, isNot(contains('Prevalent Wind')));
    final chow = names(fixtures[23]!());
    expect(chow, isNot(contains('Pure Double Chow')));
    final straight = score('123m 456m 789m 123m 55p');
    final extras = straight.yaku.where((y) => [
          'Pure Double Chow',
          'Short Straight',
          'Two Terminal Chows'
        ].contains(y.name));
    expect(extras.fold<int>(0, (a, f) => a + f.han), 1);
  });
  test('mixed kongs score six, not three', () {
    final result =
        score('1111m 4444p 789s 123p 22s', kongs: {0}, concealedKongs: {1});
    expect(
        result.yaku
            .firstWhere((f) => f.name == 'Melded and Concealed Kongs')
            .han,
        6);
    expect(names(result), isNot(contains('Melded Kong')));
  });
  test('robbing a kong excludes last copy', () {
    expect(
        names(score('123m 456p 789s 234p 66z', robbed: true, lastCopy: true)),
        isNot(contains('Last Tile')));
  });
  test('invalid tile counts and fifth copies cannot score', () {
    expect(score('123m 456p 789s 66z').valid, isFalse);
    expect(score('111m 111m 456p 789s 66z').valid, isFalse);
  });
}
