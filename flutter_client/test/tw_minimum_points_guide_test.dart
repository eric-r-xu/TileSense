import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/mahjong_core.dart';
import 'package:tilesense/logic/efficiency_engine.dart';

import 'helpers.dart';

void main() {
  // Four sets exposed; cutting the 9s leaves 67m + a North pair, ready on
  // 5m/8m. Each flower is a point and a self-draw adds one, so with one
  // flower a win is worth 1 off a discard and 2 self-drawn; with two, 2 and 3.
  final melds = [
    Meld(kind: MeldKind.sequence, low: TileType.man1, concealed: false),
    Meld(kind: MeldKind.sequence, low: TileType.pin4, concealed: false),
    Meld(kind: MeldKind.triplet, low: TileType.sou9, concealed: false),
    Meld(kind: MeldKind.sequence, low: TileType.sou3, concealed: false),
  ];

  DiscardLine cut9s(int minimumPoints, {int flowers = 1}) {
    final hand = parseTiles('67m NN 9s');
    final visible = toCounts34(hand);
    for (final m in melds) {
      for (final t in m.types) {
        visible[t.index - 1]++;
      }
    }
    return EfficiencyEngine()
        .analyze(
          hand: hand,
          visibleCounts34: visible,
          canRiichi: false,
          valueContext: EfficiencyValueContext(
            ruleset: Ruleset.taiwanese,
            melds: melds,
            roundWind: Wind.east,
            seatWind: Wind.south,
            isDealer: false,
            inRiichi: false,
            // Well past the first ten discards, so no early-win bonus.
            wallTilesRemaining: 40,
            doraIndicators: const [],
            flowers: [TileType.plum, if (flowers > 1) TileType.bamboo],
            minimumPoints: minimumPoints,
          ),
        )
        .lines
        .firstWhere((l) => l.discard == TileType.sou9);
  }

  test('a ready hand is worth something only at minimums it can clear', () {
    final any = cut9s(1);
    expect(any.shanten, 0);
    expect(any.expectedValue, greaterThan(0));
    expect(any.reason, contains('1 points'));

    final dead = cut9s(3);
    expect(dead.valuePlan, 'NO LIVE WAIT');
    expect(dead.expectedValue, lessThanOrEqualTo(0));
  });

  test('a wait that clears the minimum only self-drawn stays live', () {
    // 2 points off a discard, 3 self-drawn: at a 3-point table only the wall
    // can finish it, at 5 nothing can.
    final selfDrawOnly = cut9s(3, flowers: 2);
    expect(selfDrawOnly.valuePlan, 'READY');
    expect(selfDrawOnly.expectedValue, greaterThan(0));
    expect(cut9s(5, flowers: 2).valuePlan, 'NO LIVE WAIT');
  });
}
