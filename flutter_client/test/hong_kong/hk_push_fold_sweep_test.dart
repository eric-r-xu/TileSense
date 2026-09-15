import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/logic/efficiency_engine.dart';
import 'package:tilesense/logic/tile.dart';
import 'hk_helpers.dart';

void main() {
  test(
      'random public tables produce finite, legal recommendations with no immunity',
      () {
    final rng = Random(42);
    for (var trial = 0; trial < 150; trial++) {
      final bag = [
        for (var i = 0; i < 34; i++)
          for (var n = 0; n < 4; n++) typeFrom34(i)
      ]..shuffle(rng);
      final hand = [for (var i = 0; i < 14; i++) Tile(i, bag[i])];
      final report = EfficiencyEngine().analyze(
          hand: hand,
          visibleCounts34: toCounts34(hand),
          canRiichi: false,
          opponentRiichi: true,
          defenseHand: hand,
          valueContext: hkContext());
      expect(report.lines.where((l) => l.recommended), hasLength(1));
      expect(report.lines.every((l) => l.expectedValue.isFinite), isTrue);
      expect(report.defense.any((s) => s.isSafe), isFalse);
      expect(report.lines.every((l) => l.riichiLockCost == 0), isTrue);
      expect(report.recommendRiichi, isFalse);
    }
  });
}
