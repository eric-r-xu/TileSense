import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/taiwanese/taiwanese_rules.dart';
import 'package:tilesense/logic/auto_dials.dart';
import 'package:tilesense/logic/efficiency_engine.dart';

void main() {
  for (final goal in Goal.values) {
    test('${goal.name} picks the measured best fixed arm', () {
      expect(autoDials(goal, Ruleset.riichi, minimumPoints: 5), (
        style: PlayStyle.aggressive,
        focus: HandFocus.speed,
        strategy: Strategy.points,
      ));
      expect(autoDials(goal, Ruleset.hongKong, minimumPoints: 5), (
        style: PlayStyle.balanced,
        focus: HandFocus.speed,
        strategy: Strategy.points,
      ));
      for (final m in TaiwaneseRules.minimumPointsChoices) {
        expect(autoDials(goal, Ruleset.taiwanese, minimumPoints: m), (
          style: PlayStyle.balanced,
          focus: m >= 5 ? HandFocus.balanced : HandFocus.speed,
          strategy: Strategy.points,
        ));
      }
    });
  }
}
