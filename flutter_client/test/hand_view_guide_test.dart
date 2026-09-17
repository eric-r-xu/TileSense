import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/ui/hand_view.dart';

/// Multiplayer has no TileSense guide: [OnlineGamePage] builds `HandView`
/// with no `onToggleGuide`, and that alone must be enough to hide the guide
/// button entirely — there is no separate "multiplayer" flag to keep in
/// sync. This is the one place that guarantee is exercised without needing
/// a live connection (`OnlineGameController` can't be built in a test).
void main() {
  testWidgets('omitting onToggleGuide hides the guide button', (tester) async {
    final game = GameController(seed: 1);
    game.togglePause();
    try {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: HandView(game: game)),
      ));
      await tester.pump();

      expect(find.byKey(const Key('bottomGuideToggle')), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      game.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }
  });

  testWidgets('supplying onToggleGuide keeps the guide button, as offline does',
      (tester) async {
    final game = GameController(seed: 1);
    game.togglePause();
    try {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: HandView(game: game, onToggleGuide: () {})),
      ));
      await tester.pump();

      expect(find.byKey(const Key('bottomGuideToggle')), findsOneWidget);
    } finally {
      game.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }
  });
}
