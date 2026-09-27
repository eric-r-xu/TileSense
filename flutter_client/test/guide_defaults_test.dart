import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/online_game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/logic/auto_dials.dart';
import 'package:tilesense/logic/efficiency_engine.dart';

void main() {
  for (final initial in Ruleset.values) {
    testWidgets('${initial.name} starts with validated guide defaults',
        (tester) async {
      Sfx.i.enabled = false;
      final game = GameController(seed: 5, ruleset: initial);
      try {
        // The default goal is Placement, which plays Balanced everywhere.
        expect(game.playStyle, PlayStyle.balanced);
        // Taiwanese starts at 5 tai, where Balanced focus measured ahead.
        expect(game.handFocus,
            initial.isTaiwanese ? HandFocus.balanced : HandFocus.speed);
        expect(game.strategy, Strategy.points);
        // Includes Chinese -> Chinese -> riichi with no saved riichi dials.
        for (final next in [
          Ruleset.hongKong,
          Ruleset.taiwanese,
          Ruleset.riichi
        ]) {
          game.setRuleset(next);
          expect(game.playStyle, PlayStyle.balanced);
          expect(game.handFocus,
              next.isTaiwanese ? HandFocus.balanced : HandFocus.speed);
          expect(game.strategy, Strategy.points);
        }
      } finally {
        game.dispose();
        Sfx.i.enabled = true;
      }
    });
  }

  testWidgets('switching rules preserves explicitly chosen riichi settings',
      (tester) async {
    Sfx.i.enabled = false;
    final game = GameController(seed: 5);
    try {
      game.setPlayStyle(PlayStyle.defensive);
      game.setHandFocus(HandFocus.balanced);
      game.setStrategy(Strategy.placement);
      game.setRuleset(Ruleset.hongKong);
      game.setRuleset(Ruleset.taiwanese);
      expect(game.playStyle, PlayStyle.balanced);
      expect(game.strategy, Strategy.points);
      game.setRuleset(Ruleset.riichi);
      expect(game.playStyle, PlayStyle.defensive);
      expect(game.handFocus, HandFocus.balanced);
      expect(game.strategy, Strategy.placement);
    } finally {
      game.dispose();
      Sfx.i.enabled = true;
    }
  });

  testWidgets('a hand-set dial leaves goal mode and setGoal resumes it',
      (tester) async {
    Sfx.i.enabled = false;
    final game = GameController(
        seed: 5, ruleset: Ruleset.taiwanese, minimumPoints: 5);
    try {
      expect(game.goalDriven, isTrue);
      game.setStrategy(Strategy.placement);
      expect(game.goalDriven, isFalse);
      // The other two keep what the goal was playing, not the raw defaults.
      expect(game.handFocus, HandFocus.balanced);
      expect(game.strategy, Strategy.placement);
      game.setGoal(Goal.points);
      expect(game.goalDriven, isTrue);
      expect(game.strategy, Strategy.points);
    } finally {
      game.dispose();
      Sfx.i.enabled = true;
    }
  });

  testWidgets('online play follows the goal the same way', (tester) async {
    final game = OnlineGameController()
      ..ruleset = Ruleset.taiwanese
      ..minimumPoints = 5;
    try {
      expect(game.playStyle, PlayStyle.balanced);
      expect(game.handFocus, HandFocus.balanced);
      game.setPlayStyle(PlayStyle.defensive);
      expect(game.goalDriven, isFalse);
      expect(game.handFocus, HandFocus.balanced);
      game.setGoal(Goal.placement);
      expect(game.goalDriven, isTrue);
      expect(game.playStyle, PlayStyle.balanced);
    } finally {
      game.dispose();
      await tester.pump(const Duration(seconds: 3));
    }
  });
}
