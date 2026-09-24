import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/meld.dart';
import 'package:mahjong_core/tile.dart';
import 'package:tilesense/logic/efficiency_engine.dart';
import '../helpers.dart';
import 'hk_helpers.dart';

void main() {
  final wasStep = HongKongGuideTuning.neverStepBack;
  final wasCalls = HongKongGuideTuning.takeShantenCalls;
  tearDown(() {
    HongKongGuideTuning.neverStepBack = wasStep;
    HongKongGuideTuning.takeShantenCalls = wasCalls;
  });

  // Logged by `hk_guide_diag_test.dart`: the guide broke this 3-away hand up
  // for a wider 4-away one.
  const stepBackHand = '1m 2m 4m 5m 7m 8m 4p 3s 3s 9s B G R 7s';

  test('with neverStepBack a calm hand keeps as close to ready as it is', () {
    HongKongGuideTuning.neverStepBack = false;
    final free = hkReport(stepBackHand, wall: 77);
    expect(free.lines.firstWhere((l) => l.recommended).shanten,
        greaterThan(free.currentShanten),
        reason: 'the fixture must actually step back without the switch');
    HongKongGuideTuning.neverStepBack = true;
    final kept = hkReport(stepBackHand, wall: 77);
    expect(kept.lines.firstWhere((l) => l.recommended).shanten,
        kept.currentShanten);
    expect(kept.lines.first.recommended, isTrue,
        reason: 'the recommendation still leads the panel');
  });

  test('neverStepBack leaves a defending hand to price its own fold', () {
    HongKongGuideTuning.neverStepBack = true;
    final hand = parseTiles(stepBackHand);
    final report = EfficiencyEngine().analyze(
      hand: hand,
      visibleCounts34: toCounts34(hand),
      canRiichi: false,
      valueContext: hkContext(wall: 77),
      defenseHand: hand,
      opponentRiichi: true,
    );
    expect(report.defending, isTrue);
    expect(report.lines.firstWhere((l) => l.recommended),
        same(report.lines.first));
  });

  // Also logged: an open hand one step from ready turned down the pung that
  // makes it ready.
  CallAdvice advisePung({bool threat = false}) {
    final hand = parseTiles('1m 1m 5p 6p 7p 8p 5s 6s 7s 8s');
    final counts = toCounts34(hand);
    counts[TileType.man1.index - 1]++;
    return EfficiencyEngine().adviseCall(
      hand: hand,
      offered: Tile(900, TileType.man1),
      available: {GuidedAction.pon},
      visibleCounts34: counts,
      opponentRiichi: threat,
      context: hkContext(melds: [
        Meld(kind: MeldKind.sequence, low: TileType.man2, concealed: false)
      ]),
    );
  }

  test('with takeShantenCalls a calm hand takes a call that advances it', () {
    HongKongGuideTuning.takeShantenCalls = true;
    final advice = advisePung();
    expect(advice.forAction(GuidedAction.pon)!.shantenAfter,
        lessThan(advice.forAction(GuidedAction.pass)!.shantenAfter));
    expect(advice.recommended, GuidedAction.pon);
  });

  test('takeShantenCalls changes nothing while a threat is out', () {
    HongKongGuideTuning.takeShantenCalls = false;
    final without = advisePung(threat: true).recommended;
    HongKongGuideTuning.takeShantenCalls = true;
    expect(advisePung(threat: true).recommended, without);
  });
}
