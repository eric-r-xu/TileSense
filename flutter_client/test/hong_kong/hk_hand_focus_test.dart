import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/logic/efficiency_engine.dart';
import 'package:mahjong_core/tile.dart';
import 'hk_helpers.dart';
import 'package:mahjong_core/ruleset.dart';

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
  test('speed compresses payout differences around a chip-sized pivot', () {
    const hk = Ruleset.hongKong;
    const small = 8.0, big = 128.0;
    expect(HandFocus.speed.worth(big, ruleset: hk) /
            HandFocus.speed.worth(small, ruleset: hk),
        lessThan(big / small));
    expect(HandFocus.balanced.worth(big, ruleset: hk), big);
    // Pivoting on riichi's 5000 would read every chip payout as tiny and
    // inflate it; the Hong Kong pivot leaves a 32-chip hand where it is.
    expect(HandFocus.speed.worth(32, ruleset: hk), closeTo(32, 1e-9));
    expect(HandFocus.speed.worth(32), greaterThan(32));
  });
  test('withMelds preserves ruleset, flowers, style and focus', () {
    final c = hkContext(
        style: PlayStyle.aggressive,
        focus: HandFocus.speed,
        flowers: [TileType.plum]);
    final next = c.withMelds([]);
    expect(next.ruleset, Ruleset.hongKong);
    expect(next.style, c.style);
    expect(next.focus, c.focus);
    expect(next.flowers, c.flowers);
    expect(next.winBonus, 0);
  });
}
