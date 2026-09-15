import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/logic/efficiency_calc.dart';
import 'package:tilesense/logic/efficiency_engine.dart';

import '../helpers.dart';

void main() {
  final calc = TileEfficiencyCalculator();
  final fourOfEach = List<int>.filled(38, 4);

  ({int pung, int chow}) calls(String spec, [List<int>? remaining]) =>
      calc.callAcceptance(toTrainerCounts(parseTiles(spec)),
          remaining ?? fourOfEach);

  group('callAcceptance', () {
    test('counts pairs that pung forward and partial runs that chow forward',
        () {
      // Two pairs: punging either keeps the other as the pair. Chowable:
      // 3m and 6m (45m), 8m (79m), 6p (57p).
      final r = calls('11m 45m 79m 22p 57p 3s 8s E');
      expect(r.pung, 8);
      expect(r.chow, 16);
    });

    test('a lone pair does not pung forward — it would lose the pair', () {
      // 11m is the only pair; punging it trades the pair for a set and the
      // hand is no closer. 3m (24m) and 8p (79p) chow forward.
      final r = calls('11m 345p 678s 24m 79p E');
      expect(r.pung, 0);
      expect(r.chow, 8);
    });

    test('only live copies count', () {
      final remaining = List<int>.of(fourOfEach)
        ..[trainerIndexOf(parseTiles('1m').single.type)] = 1
        ..[trainerIndexOf(parseTiles('8m').single.type)] = 0;
      final r = calls('11m 45m 79m 22p 57p 3s 8s E', remaining);
      expect(r.pung, 1 + 4, reason: '1m has one live copy, 2p four');
      expect(r.chow, 4 + 4 + 4, reason: '8m is dead; 3m, 6m and 6p are live');
    });

    test('honours are never chowed', () {
      final r = calls('EE SS WW 123m 456p N');
      expect(r.chow, 0);
      expect(r.pung, greaterThan(0));
    });

    test('a ready hand has nothing to call toward', () {
      final r = calls('123m 456p 789s 11s 45p');
      expect(r.pung, 0);
      expect(r.chow, 0);
    });
  });

  test('riichi keeps its original win-model constants', () {
    // The Hong Kong model is swapped in by ruleset; riichi must not move.
    const r = WinModel.riichi;
    expect(r.typicalWidth, [5, 14, 25, 43, 63, 73, 80]);
    expect(EfficiencyEngine.typicalUkeireByShanten, r.typicalWidth);
    expect(r.stepWidth, [8, 20, 28, 35, 40, 44, 48]);
    expect(r.survivesTurn, 0.955);
    expect(r.waitInheritance, 0.5);
    expect(r.winChancesPerTurn, 1.0);
    expect(r.narrowPenalty, 1.0);
    expect(r.stepTries, 1.0);
    expect(r.countsCalls, isFalse);
  });
}
