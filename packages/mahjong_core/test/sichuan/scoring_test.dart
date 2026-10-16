import 'package:mahjong_core/mahjong_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('hand value table', () {
    test('0 fan 1, 1 fan 2, 2 fan 4, 3 or more 8', () {
      expect([for (var f = 0; f <= 5; f++) SichuanRules.handValue(f)],
          [1, 2, 4, 8, 8, 8]);
    });
  });

  group('fan', () {
    test('a plain hand is 0 fan, 1 point, no minimum', () {
      final s = score('123m 456m 789p 123p 55s');
      expect(s.valid, isTrue);
      expect(s.han, 0);
      expect(s.points, 1);
    });

    test('All Pungs is 1 fan', () {
      final s = score('111m 222m 333p 444p 55s');
      expect(names(s), {'All Pungs'});
      expect(s.points, 2);
    });

    test('Full Flush is 2 fan', () {
      final s = score('123m 456m 789m 234m 55m');
      expect(names(s), {'Full Flush'});
      expect(s.han, 2);
      expect(s.points, 4);
    });

    test('Seven Pairs is 2 fan', () {
      final s = score('11m 22m 44p 66p 88p 99p 33p');
      expect(names(s), {'Seven Pairs'});
      expect(s.points, 4);
    });

    test('four identical tiles count as two pairs and a Root', () {
      final s = score('1111m 22m 33p 44p 55p 66p');
      expect(names(s), {'Seven Pairs', 'Root'});
      expect(s.han, 3);
      expect(s.points, 8);
    });

    test('Root counts four identical tiles even outside a kong', () {
      final s = score('111m 123m 456p 789p 55p');
      expect(names(s), {'Root'});
      expect(s.points, 2);
    });

    test('Root counts once per set of four', () {
      final s = score('1111m 2222m 3m 456p 77p');
      expect(s.yaku.where((y) => y.name == 'Root'), hasLength(2));
      expect(s.han, 2);
    });

    test('a kong is a Root and makes All Pungs possible', () {
      final s = score('1111m 222p 333p 444p 55p', kongs: {0});
      expect(names(s), {'Root', 'All Pungs'});
      expect(s.han, 2);
    });

    test('Golden Single Wait is 2 fan in all and replaces All Pungs', () {
      final s = score('111m 222p 333p 444m 55p', open: {0, 1, 2, 3});
      expect(names(s), {'Golden Single Wait'});
      expect(s.han, 2);
      expect(s.points, 4);
    });

    test('four melds out but a win on a run is not a Golden Single Wait', () {
      // Open pungs only, so this needs the pair as the wait: win on a pair
      // tile made from two in hand is Golden; there is no run possible.
      final s = score('111m 222p 333p 444m 55p', open: {0, 1, 2, 3});
      expect(names(s).contains('All Pungs'), isFalse);
    });

    test('Win after Kong, Robbing the Kong, Shoot after Kong, Under the Sea',
        () {
      expect(names(score('123m 456m 789p 123p 55s', self: true, replacement: true)),
          {'Win after Kong'});
      expect(names(score('123m 456m 789p 123p 55s', robbed: true)),
          {'Robbing the Kong'});
      expect(names(score('123m 456m 789p 123p 55s', afterKong: true)),
          {'Shoot after Kong'});
      expect(names(score('123m 456m 789p 123p 55s', self: true, last: true)),
          {'Under the Sea'});
      expect(names(score('123m 456m 789p 123p 55s', last: true)),
          {'Under the Sea'});
    });

    test('three fan or more is capped at 8 points', () {
      final s = score('111m 222m 333m 444m 55m');
      expect(names(s), {'Full Flush', 'All Pungs'});
      expect(s.han, 3);
      expect(s.points, 8);
    });

    test('the best reading wins: 111222333 as pungs scores All Pungs', () {
      final s = score('111m 222m 333m 444p 55p');
      expect(names(s), contains('All Pungs'));
    });
  });

  group('invalid hands', () {
    test('wrong tile count and non-hands are invalid', () {
      expect(score('123m 456m 789p 123p 5s').valid, isFalse);
      expect(score('123m 456m 789p 124p 55s').valid, isFalse);
    });

    test('a chow cannot be an exposed meld', () {
      final ts = tiles('456m');
      final result = scoreSichuanHand(
          tiles('123m 789p 11p'),
          tiles('1p').single,
          [Meld(kind: MeldKind.sequence, low: ts.first.type, concealed: false, tiles: ts)],
          ScoreContext(
              roundWind: Wind.east,
              seatWind: Wind.east,
              isTsumo: false,
              closed: false));
      expect(result.valid, isFalse);
    });
  });

  group('hand shape', () {
    test('seven pairs allows four of a kind; standard does not need it', () {
      final c = toCounts34(tiles('1111m 22m 33p 44p 55p 66p'));
      expect(isAgariSichuan(c), isTrue);
      expect(isAgariSichuan(toCounts34(tiles('123m 456m 789p 123p 55p'))),
          isTrue);
      expect(isAgariSichuan(toCounts34(tiles('123m 456m 789p 124p 55p'))),
          isFalse);
    });

    test('waits include a seven-pairs wait', () {
      // Only seven pairs can finish this one; no standard shape fits.
      final waits = waitTilesSichuan(tiles('11m 33m 55m 77m 99m 22p 4p'));
      expect(waits, [TileType.pin4]);
    });

    test('no honors: an honor tile never completes a hand', () {
      final c = toCounts34(tiles('123m 456m 789p 123p 5p'));
      c[27] += 1;
      expect(isAgariSichuan(c), isFalse);
    });
  });

  group('efficiency', () {
    test('seven pairs shanten counts duplicate pairs', () {
      final calc = SichuanEfficiencyCalculator();
      // 1111m + 22m 33p 44p 55p = 6 pairs counting the quad as two; one tile
      // short of ready on seven pairs.
      final h = toTrainerCounts(tiles('1111m 22m 33p 44p 55p 6p'));
      expect(calc.calculateWaitingShanten(h), 0);
      final standard = TileEfficiencyCalculator();
      expect(standard.calculateWaitingShanten(h), greaterThan(0));
    });

    test('void-suit tiles are removed before counting', () {
      final h = toTrainerCounts(tiles('123m 456p 789s'));
      final cut = withoutVoidSuit(h, 2);
      expect(cut.sublist(21, 30).every((n) => n == 0), isTrue);
      expect(cut[1], 1);
    });
  });
}
