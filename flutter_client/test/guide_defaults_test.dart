import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/logic/efficiency_engine.dart';

void main() {
  for (final initial in Ruleset.values) {
    testWidgets('${initial.name} starts with validated guide defaults',
        (tester) async {
      Sfx.i.enabled = false;
      final game = GameController(seed: 5, ruleset: initial);
      try {
        expect(game.playStyle,
            initial.isRiichi ? PlayStyle.aggressive : PlayStyle.balanced);
        expect(game.handFocus, HandFocus.speed);
        expect(game.strategy, Strategy.points);
        // Includes Chinese -> Chinese -> riichi with no saved riichi dials.
        for (final next in [
          Ruleset.hongKong,
          Ruleset.taiwanese,
          Ruleset.riichi
        ]) {
          game.setRuleset(next);
          expect(game.playStyle,
              next.isRiichi ? PlayStyle.aggressive : PlayStyle.balanced);
          expect(game.handFocus, HandFocus.speed);
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
}
