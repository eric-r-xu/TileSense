// ignore_for_file: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
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
        // A new game's first hand plays for points: Aggressive under riichi;
        // Hong Kong and Taiwanese pin Balanced.
        expect(game.playStyle,
            initial.isRiichi ? PlayStyle.aggressive : PlayStyle.balanced);
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
          expect(game.playStyle,
              next.isRiichi ? PlayStyle.aggressive : PlayStyle.balanced);
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

  testWidgets('a hand-set dial leaves automatic mode, keeping the others',
      (tester) async {
    Sfx.i.enabled = false;
    final game = GameController(
        seed: 5, ruleset: Ruleset.taiwanese, minimumPoints: 5);
    try {
      expect(game.dialsAuto, isTrue);
      game.setStrategy(Strategy.placement);
      expect(game.dialsAuto, isFalse);
      // The other two keep what automatic mode was playing, not the raw
      // defaults.
      expect(game.handFocus, HandFocus.balanced);
      expect(game.strategy, Strategy.placement);
    } finally {
      game.dispose();
      Sfx.i.enabled = true;
    }
  });

  testWidgets('online play sets its dials the same way', (tester) async {
    final game = OnlineGameController()
      ..ruleset = Ruleset.taiwanese
      ..minimumPoints = 5;
    try {
      expect(game.playStyle, PlayStyle.balanced);
      expect(game.handFocus, HandFocus.balanced);
      game.setPlayStyle(PlayStyle.defensive);
      expect(game.dialsAuto, isFalse);
      expect(game.handFocus, HandFocus.balanced);
    } finally {
      game.dispose();
      await tester.pump(const Duration(seconds: 3));
    }
  });

  test('riichi switches to placement for the final two hands', () {
    Sfx.i.enabled = false;
    fakeAsync((fa) {
      final game = GameController(seed: 3, hanchan: false)..setAutoplay(true);
      // The dials each hand of an East-only game was played with.
      final byHand = <int, (PlayStyle, Strategy)>{};
      for (var guard = 0; game.phase != GamePhase.gameEnd; guard++) {
        if (guard > 100000) fail('never finished');
        byHand.putIfAbsent(
            game.roundNumber, () => (game.playStyle, game.strategy));
        if (game.phase == GamePhase.roundEnd) {
          game.continueFromRoundEnd();
          continue;
        }
        fa.elapse(const Duration(milliseconds: 1104));
      }
      game.dispose();
      for (final entry in byHand.entries) {
        final end = entry.key >= 4 - kPlacementHands;
        expect(entry.value,
            end
                ? (PlayStyle.balanced, Strategy.placement)
                : (PlayStyle.aggressive, Strategy.points),
            reason: 'hand ${entry.key + 1}');
      }
      expect(byHand.keys, containsAll([0, 3]),
          reason: 'played into the final hands');
    });
    Sfx.i.enabled = true;
  });
}
