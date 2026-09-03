import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/logic/efficiency_engine.dart';
import 'package:tilesense/logic/tile.dart';

import 'helpers.dart';

void main() {
  const discard = TileType.sou9;

  DiscardLine analyzeTenpai({
    required bool isDealer,
    bool canRiichi = false,
    List<TileType> doraIndicators = const [],
  }) {
    final hand = parseTiles('123m 456m 789m 34p 55p 9s');
    final visible = toCounts34(hand);
    for (final indicator in doraIndicators) {
      visible[indicator.index - 1]++;
    }

    final report = EfficiencyEngine().analyze(
      hand: hand,
      visibleCounts34: visible,
      canRiichi: canRiichi,
      valueContext: EfficiencyValueContext(
        melds: const [],
        roundWind: Wind.east,
        seatWind: isDealer ? Wind.east : Wind.south,
        isDealer: isDealer,
        inRiichi: false,
        wallTilesRemaining: 40,
        doraIndicators: doraIndicators,
      ),
    );
    return report.lines.singleWhere((line) => line.discard == discard);
  }

  test('tenpai EV uses the scoring result', () {
    final base = analyzeTenpai(isDealer: false);
    final withDora = analyzeTenpai(
      isDealer: false,
      doraIndicators: const [TileType.man1], // 2m is dora.
    );

    expect(base.shanten, 0);
    expect(base.expectedValue, greaterThan(0));
    expect(base.averagePoints, greaterThan(0));
    expect(withDora.averagePoints, greaterThan(base.averagePoints));
    expect(withDora.expectedValue, greaterThan(base.expectedValue));
  });

  test('dealer status increases expected value for the same waits', () {
    final nonDealer = analyzeTenpai(isDealer: false);
    final dealer = analyzeTenpai(isDealer: true);

    expect(dealer.averagePoints, greaterThan(nonDealer.averagePoints));
    expect(dealer.expectedValue, greaterThan(nonDealer.expectedValue));
  });

  test('riichi value and its 1000-point risk inform the plan', () {
    final line = analyzeTenpai(isDealer: false, canRiichi: true);

    expect(line.valuePlan, 'RIICHI');
    expect(line.recommendRiichi, isTrue);
    expect(line.expectedValue, greaterThan(0));
  });
}
