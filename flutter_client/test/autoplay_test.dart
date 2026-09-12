import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/logic/round.dart';
import 'package:tilesense/logic/tile.dart';
import 'helpers.dart';

void main() {
  testWidgets('autoplay uses the displayed Hong Kong recommendation',
      (tester) async {
    Sfx.i.enabled = false;
    final game = GameController(seed: 5);
    final round = game.round;
    final drawn = Tile(900, TileType.pei);
    round.seats[0]
      ..hand = [...parseTiles('123m 456p 789s 22m 55p'), drawn]
      ..drawn = drawn
      ..melds = [];
    round.turn = 0;
    round.phase = RoundPhase.discarding;
    game.setHandFocus(game.handFocus.next);
    final expected =
        game.report.lines.singleWhere((l) => l.recommended).discard;
    game.setAutoplay(true);
    await tester.pump(const Duration(milliseconds: 960));
    expect(round.seats[0].pond.last.type, expected);
    expect(round.seats[0].riichi, isFalse);
    game.dispose();
    Sfx.i.enabled = true;
  });
  testWidgets('a fully autoplayed round reaches an end state', (tester) async {
    Sfx.i.enabled = false;
    final game = GameController(seed: 11);
    try {
      game.setAutoplay(true);
      for (var i = 0; i < 500 && game.phase == GamePhase.playing; i++) {
        await tester.pump(const Duration(milliseconds: 960));
      }

      expect(game.phase, isNot(GamePhase.playing));
      expect(tester.takeException(), isNull);
    } finally {
      game.dispose();
      Sfx.i.enabled = true;
    }
  });
}
