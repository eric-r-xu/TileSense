import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/taiwanese/taiwanese_rules.dart';
import 'package:tilesense/logic/auto_dials.dart';
import 'package:tilesense/logic/efficiency_engine.dart';

void main() {
  test('riichi plays for points, then placement in the final two hands', () {
    for (final handsLeft in [8, 5, 3]) {
      expect(autoDials(Ruleset.riichi, minimumPoints: 5, handsLeft: handsLeft), (
        style: PlayStyle.aggressive,
        focus: HandFocus.speed,
        strategy: Strategy.points,
      ));
    }
    for (final handsLeft in [2, 1]) {
      expect(autoDials(Ruleset.riichi, minimumPoints: 5, handsLeft: handsLeft), (
        style: PlayStyle.balanced,
        focus: HandFocus.speed,
        strategy: Strategy.placement,
      ));
    }
  });

  test('Hong Kong and Taiwanese keep their measured fixed dials', () {
    for (final handsLeft in [8, 1]) {
      expect(
          autoDials(Ruleset.hongKong, minimumPoints: 5, handsLeft: handsLeft), (
        style: PlayStyle.balanced,
        focus: HandFocus.speed,
        strategy: Strategy.points,
      ));
      for (final m in TaiwaneseRules.minimumPointsChoices) {
        expect(
            autoDials(Ruleset.taiwanese,
                minimumPoints: m, handsLeft: handsLeft), (
          style: PlayStyle.balanced,
          focus: m >= 5 ? HandFocus.balanced : HandFocus.speed,
          strategy: Strategy.points,
        ));
      }
    }
  });
}
