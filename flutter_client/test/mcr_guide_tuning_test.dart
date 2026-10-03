import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/mahjong_core.dart';
import 'package:tilesense/logic/efficiency_engine.dart';

import 'helpers.dart';

/// The MCR guide's call gate and its never-step-back rule
/// ([HongKongGuideTuning.mcrCallsOnlyToReady],
/// [HongKongGuideTuning.mcrNeverStepBack]). Each test sets the flag it
/// exercises, so these hold whatever the shipped defaults are.
void main() {
  final saved = (
    HongKongGuideTuning.mcrCallsOnlyToReady,
    HongKongGuideTuning.mcrNeverStepBack,
  );
  tearDown(() {
    HongKongGuideTuning.mcrCallsOnlyToReady = saved.$1;
    HongKongGuideTuning.mcrNeverStepBack = saved.$2;
  });

  EfficiencyValueContext context() => EfficiencyValueContext(
        ruleset: Ruleset.mcr,
        melds: const [],
        roundWind: Wind.east,
        seatWind: Wind.south,
        isDealer: false,
        inRiichi: false,
        wallTilesRemaining: 70,
        doraIndicators: const [],
        focus: HandFocus.speed,
      );

  CallAdvice pung(String hand, TileType offered) {
    final tiles = parseTiles(hand);
    final visible = toCounts34(tiles);
    visible[offered.index - 1]++;
    return EfficiencyEngine().adviseCall(
      hand: tiles,
      offered: Tile(999, offered),
      available: {GuidedAction.pon, GuidedAction.pass},
      visibleCounts34: visible,
      context: context(),
    );
  }

  // 456m 13p 8p 3s 678s 8s with a South pair: a South pung leaves the hand
  // one away from ready — progress, but not a hand worth 8 yet.
  const notReady = '456m 13p 8p 3s 678s 8s SS';

  test('a pung that does not reach a hand worth 8 is passed', () {
    HongKongGuideTuning.mcrCallsOnlyToReady = true;
    final advice = pung(notReady, TileType.nan);
    expect(advice.recommended, GuidedAction.pass);
    final option = advice.forAction(GuidedAction.pon)!;
    expect(option.eligible, isFalse);
    expect(option.reason, contains('8 points'));
  });

  test('without the gate the same pung is priced as progress', () {
    HongKongGuideTuning.mcrCallsOnlyToReady = false;
    final option = pung(notReady, TileType.nan).forAction(GuidedAction.pon)!;
    expect(option.eligible, isTrue);
    expect(option.expectedValue, greaterThan(0));
  });

  test('a pung onto a ready hand worth 8 stays on the table', () {
    // The two rules ship together: on its own the pre-ready estimate would
    // rather break the ready hand the pung makes than keep it, and the gate
    // would then see no ready hand to let through.
    HongKongGuideTuning.mcrCallsOnlyToReady = true;
    HongKongGuideTuning.mcrNeverStepBack = true;
    // A red dragon pung leaves a pure straight in man waiting on 5m: Pure
    // Straight (16) and Dragon Pung (2), well over the minimum. Whether it
    // beats passing on the closed straight is the value model's call; the
    // gate only has to leave it eligible.
    final option =
        pung('RR 123456789m 5m 9p', TileType.chun).forAction(GuidedAction.pon)!;
    expect(option.eligible, isTrue);
    expect(option.shantenAfter, 0);
    expect(option.expectedValue, greaterThan(0));
  });

  test('a calm hand never steps back toward a special shape', () {
    HongKongGuideTuning.mcrNeverStepBack = true;
    // One away; the guide used to break it for a wide two-away line
    // (mcr_guide_diag_test.dart).
    final hand = parseTiles('3m 66m 13p 6p 999p 22s 34s 2m');
    final report = EfficiencyEngine().analyze(
      hand: hand,
      visibleCounts34: toCounts34(hand),
      canRiichi: false,
      valueContext: context(),
    );
    final recommended = report.lines.firstWhere((l) => l.recommended);
    expect(recommended.shanten, report.currentShanten);
  });
}
