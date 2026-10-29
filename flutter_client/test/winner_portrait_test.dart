import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/round.dart';
import 'package:mahjong_core/tile.dart';
import 'package:mahjong_core/wall.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/main.dart' show kDesignSize;
import 'package:tilesense/ui/table_view.dart';

import 'helpers.dart';

/// Behind the result panel, the seat that won keeps a ringed, pulsing
/// portrait so it can still be found when the panel is see-through.
void main() {
  testWidgets('only the hand winner\'s portrait is ringed on the result screen',
      (tester) async {
    Sfx.i.enabled = false;
    final game = GameController(seed: 5);
    game.togglePause();
    try {
      final r = Round.posed(
        dealer: 0,
        roundWind: Wind.east,
        wall: Wall.posed(remaining: 0, dora: const []),
        startingPoints: List.filled(4, 25000),
      );
      final win = Tile(900, TileType.pin5);
      r.turn = 1;
      r.seats[1].hand = [...parseTiles('123m 456p 789s 22m 55p'), win];
      r.seats[1].drawn = win;
      r.declareTsumo(1);
      game.round = r;
      await tester.binding.setSurfaceSize(kDesignSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Future<void> show() => tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: MediaQuery(
                  data: const MediaQueryData(
                      size: Size(1600, 820), disableAnimations: true),
                  child: ListenableBuilder(
                      listenable: game,
                      builder: (_, __) => TableView(game: game))))));
      await show();
      await tester.pump();
      expect(find.byKey(const ValueKey('winnerPulse1')), findsNothing);

      game.phase = GamePhase.roundEnd;
      game.notifyListeners();
      await tester.pump();
      expect(find.byKey(const ValueKey('winnerPulse1')), findsOneWidget);
      expect(find.byKey(const ValueKey('winnerPulse0')), findsNothing);
      expect(find.byKey(const ValueKey('winnerPulse2')), findsNothing);
    } finally {
      game.dispose();
      Sfx.i.enabled = true;
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }
  });
}
