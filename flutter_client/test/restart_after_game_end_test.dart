import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/main.dart';
import 'package:tilesense/ui/table_view.dart';

/// Menu > Single Player > Start picks up the game left under way, but a game
/// that has ended must not come back: a tester saw the last game's final
/// scores under the characters they had just picked, until New Game.
void main() {
  setUp(() => Sfx.i.enabled = false);
  tearDown(() => Sfx.i.enabled = true);

  Future<GameController> startGame(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(kDesignSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Single Player'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('charactersContinue')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    return (tester.widget(find.byType(TableView).first) as TableView).game
        as GameController;
  }

  /// Menu, then Single Player and Start; with [pick], a different character
  /// for seat 1 on the way, as the tester did.
  Future<void> leaveAndComeBack(WidgetTester tester, GameController game,
      {bool pick = false}) async {
    await tester.tap(find.byKey(const Key('backToMenu')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Single Player'));
    await tester.pump();
    if (pick) {
      final other =
          kSelectableCharacters.firstWhere((c) => c != game.seatCharacters[1]);
      await tester.tap(find.byKey(Key('seatCharacterPick_1_${other.name}')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('charactersContinue')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
  }

  testWidgets(
      'a finished game is not resumed: Start deals a new one for the new '
      'characters', (tester) async {
    final game = await startGame(tester);
    final start = game.ruleset.startingPoints;
    // The game has ended with these final scores.
    game.tablePoints[0] = 56300;
    game.tablePoints[1] = 19100;
    game.phase = GamePhase.gameEnd;
    final before = game.seatCharacters[1];

    await leaveAndComeBack(tester, game, pick: true);

    expect(find.byType(TableView), findsOneWidget);
    expect(game.seatCharacters[1], isNot(before),
        reason: 'the new character is seated');
    expect(game.phase, GamePhase.playing, reason: 'a new game, not game over');
    expect(game.tablePoints[0], start,
        reason: 'the last game\'s scores are gone');
    expect(game.tablePoints[1], start);
    expect(game.paused, isFalse);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('a finished game is not resumed with nothing changed either',
      (tester) async {
    final game = await startGame(tester);
    game.tablePoints[0] = 56300;
    game.phase = GamePhase.gameEnd;

    await leaveAndComeBack(tester, game);

    expect(game.phase, GamePhase.playing);
    expect(game.tablePoints[0], game.ruleset.startingPoints);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('a game still under way is resumed, scores and all',
      (tester) async {
    final game = await startGame(tester);
    game.tablePoints[0] = 31000;

    await leaveAndComeBack(tester, game);

    expect(game.phase, isNot(GamePhase.gameEnd));
    expect(game.tablePoints[0], 31000, reason: 'the same game carries on');
    expect(game.paused, isFalse, reason: 'Start un-pauses it');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
