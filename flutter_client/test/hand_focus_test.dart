import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/logic/efficiency_engine.dart';
import 'hk_helpers.dart';

void main() {
  test('focus leaves scoring and win probabilities unchanged', () {
    const hand = '123m 456p 789s 22m 55p N';
    final plain = hkReport(hand);
    for (final focus in HandFocus.values) {
      final report = hkReport(hand, focus: focus);
      for (final line in plain.lines) {
        final other =
            report.lines.singleWhere((l) => l.discard == line.discard);
        expect(other.averagePoints, line.averagePoints);
        expect(other.winProbability, line.winProbability);
        expect(other.expectedValue.isFinite, isTrue);
      }
    }
  });
  test('speed compresses payout differences, value expands them', () {
    const small = 8.0, big = 128.0;
    expect(HandFocus.speed.worth(big) / HandFocus.speed.worth(small),
        lessThan(big / small));
    expect(HandFocus.value.worth(big) / HandFocus.value.worth(small),
        greaterThan(big / small));
    expect(HandFocus.balanced.worth(big), big);
  });
  test('withMelds preserves flowers, style and focus', () {
    final c = hkContext(style: PlayStyle.aggressive, focus: HandFocus.value);
    final next = c.withMelds([]);
    expect(next.style, c.style);
    expect(next.focus, c.focus);
    expect(next.flowers, c.flowers);
    expect(next.winBonus, 0);
  });
}
