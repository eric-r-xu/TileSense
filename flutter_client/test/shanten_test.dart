import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/logic/efficiency_calc.dart';
import 'package:tilesense/logic/hand_parse.dart';

import 'helpers.dart';

void main() {
  final calc = TileEfficiencyCalculator();

  int shanten(String spec) =>
      calc.calculateWaitingShanten(toTrainerCounts(parseTiles(spec)));

  group('standard shanten', () {
    test('complete 13-tile hand is tenpai (0)', () {
      expect(shanten('123m 456m 789m 123p 5p'), 0);
    });

    test('ryanmen tenpai is 0', () {
      expect(shanten('123m 456m 789m 34p 55p'), 0);
    });

    test('three melds + two kanchan, no pair, is 1-shanten', () {
      expect(shanten('123m 456m 789m 24p 68p'), 1);
    });

    test('opening hand is several shanten', () {
      expect(shanten('19m 19p 19s 123s 55s EE'), greaterThanOrEqualTo(2));
    });
  });

  group('seven pairs', () {
    test('six pairs + a floater is chiitoitsu tenpai', () {
      expect(shanten('11m 33m 55m 77m 99p 22s 4s'), 0);
    });
  });

  group('thirteen orphans', () {
    test('13-sided kokushi wait is tenpai', () {
      expect(shanten('19m 19p 19s E S W N B G R'), 0);
    });

    test('kokushi with a pair is also tenpai', () {
      expect(shanten('119m 19p 19s E S W N B G'), 0);
    });
  });

  group('agari detection', () {
    test('4 melds + pair completes', () {
      expect(isAgari(counts34Of('123m 456m 789m 123p 55p')), isTrue);
    });

    test('seven pairs completes', () {
      expect(isAgari(counts34Of('11m 33m 55m 77m 99m 22p 33s')), isTrue);
    });

    test('kokushi completes', () {
      expect(isAgari(counts34Of('119m 19p 19s E S W N B G R')), isTrue);
    });

    test('incomplete hand does not', () {
      expect(isAgari(counts34Of('123m 456m 789m 13p 55p')), isFalse);
    });
  });
}
