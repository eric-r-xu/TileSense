import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/round.dart';
import 'package:mahjong_core/tile.dart';
import 'package:mahjong_core/wall.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/main.dart' show kDesignSize;
import 'package:tilesense/ui/scoring_view.dart';
import 'package:tilesense/ui/tile_face.dart';

import 'helpers.dart';

/// Regression test: a riichi tsumo's drawn winning tile is already part of
/// `seat.hand` (every draw gets added there, win or not — see
/// `Round._acceptDraw`), so the result screen's hand row must leave it out
/// of the plain tile loop and render it only once, highlighted, via the
/// separate `winTile` slot. It used to render there *and* again in the
/// plain loop, showing the same tile twice. Hong Kong already had this
/// covered (`hk_ui_test.dart`'s "renders a self-picked tile once"); this is
/// the riichi case.
void main() {
  testWidgets('a riichi tsumo renders its winning tile once, not twice',
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
      game.phase = GamePhase.roundEnd;
      await tester.binding.setSurfaceSize(kDesignSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: ScoringView(game: game))));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byWidgetPredicate((w) => w is TileFace && w.tile == win),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      game.dispose();
      Sfx.i.enabled = true;
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }
  });
}
