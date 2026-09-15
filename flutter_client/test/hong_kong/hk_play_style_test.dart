import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/logic/efficiency_engine.dart';
import 'hk_helpers.dart';

void main() {
  test('style scales risk but never changes Hong Kong hand value', () {
    const hand = '1m 234m 567m 99s 78p 3p W 5s';
    final reports = [
      for (final s in PlayStyle.values) hkReport(hand, threat: true, style: s)
    ];
    for (final line in reports[1].lines) {
      final defensive =
          reports[0].lines.singleWhere((l) => l.discard == line.discard);
      final aggressive =
          reports[2].lines.singleWhere((l) => l.discard == line.discard);
      expect(defensive.averagePoints, line.averagePoints);
      expect(aggressive.averagePoints, line.averagePoints);
      expect(defensive.dealInCost, greaterThanOrEqualTo(line.dealInCost));
      expect(aggressive.dealInCost, lessThanOrEqualTo(line.dealInCost));
      expect(defensive.riichiLockCost, 0);
    }
  });
  test('no threat means style alone does not change value', () {
    const hand = '123m 456p 789s 22m 55p N';
    final balanced = hkReport(hand);
    for (final style in PlayStyle.values) {
      final report = hkReport(hand, style: style);
      for (final line in balanced.lines) {
        expect(
            report.lines
                .singleWhere((l) => l.discard == line.discard)
                .expectedValue,
            line.expectedValue);
      }
    }
  });
}
