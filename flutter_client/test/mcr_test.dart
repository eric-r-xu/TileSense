// ignore_for_file: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/mahjong_core.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/scenario/scenario_controller.dart';

import 'helpers.dart';

/// MCR through the app: the guide plays it with the MCR scorer, and the game
/// runs its own schedule (dealer passes every hand, winds advance every four).
void main() {
  // The controller is built inside fakeAsync so its turn timers are fake.
  List<(int, Wind)> playOut(GameController Function() start) {
    final hands = <(int, Wind)>[];
    fakeAsync((fa) {
      final game = start()..setAutoplay(true);
      for (var guard = 0; game.phase != GamePhase.gameEnd; guard++) {
        if (guard > 400000) fail('never finished');
        if (game.phase == GamePhase.roundEnd) {
          final r = game.round.result!;
          expect(r.pointDeltas.values.fold<int>(0, (a, b) => a + b), 0);
          if (r.score case final s? when r.winners.isNotEmpty) {
            expect(s.mcrQualifyingPoints, greaterThanOrEqualTo(8));
          }
          hands.add((game.round.dealer, game.round.roundWind));
          game.continueFromRoundEnd();
          continue;
        }
        fa.elapse(const Duration(milliseconds: 1104));
      }
      game.dispose();
    });
    return hands;
  }

  setUp(() => Sfx.i.enabled = false);
  tearDown(() => Sfx.i.enabled = true);

  test('Auto-Play finishes an MCR practice game: a hand per dealer, East only',
      () {
    expect(
        playOut(() =>
            GameController(seed: 11, ruleset: Ruleset.mcr, hanchan: false)),
        [for (var d = 0; d < 4; d++) (d, Wind.east)]);
  });

  test('a full MCR game is 16 hands through all four winds', () {
    expect(playOut(() => GameController(seed: 2, ruleset: Ruleset.mcr)), [
      for (final w in Wind.values)
        for (var d = 0; d < 4; d++) (d, w)
    ]);
  });

  test('the builder analyses an MCR hand', () {
    final c = ScenarioController()..setRuleset(Ruleset.mcr);
    c.edit((s) {
      for (final t in parseTypes('1m 234m 567m 99s 78p 33p W')) {
        s.hand.add(s.mint(t));
      }
    });
    expect(c.round.ruleset, Ruleset.mcr);
    expect(c.blockedReason, isNull);
    expect(c.report.lines, isNotEmpty);
    expect(c.report.lines.any((l) => l.recommended), isTrue);
  });
}
