import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/main.dart';

/// Startup cost: the welcome screen must not build a [GameController].
///
/// Creating one deals a wall, sorts four hands and runs the first efficiency
/// report — the single most expensive thing the app does — and on the web that
/// used to happen while the menu was still painting. It is now deferred until
/// the player actually starts a table, behind a loading screen. Nothing else
/// asserts that, so without this test the eager `late final GameController`
/// could come back unnoticed.
void main() {
  setUp(() => Sfx.i.enabled = false);
  tearDown(() => Sfx.i.enabled = true);

  testWidgets('no game is built until the player starts one', (tester) async {
    var built = 0;
    GameController spy(
        Ruleset ruleset, List<Character> seats, int dealer, bool hanchan) {
      built++;
      return GameController(
        ruleset: ruleset,
        seatCharacters: seats,
        startingDealer: dealer,
        hanchan: hanchan,
      );
    }

    // GamePage below the app's `_FixedCanvas`, so give it that canvas: the
    // welcome screen is laid out for 1600x820 and overflows the default
    // 800x600 test surface.
    await tester.binding.setSurfaceSize(kDesignSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: GamePage(createGame: spy)));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Single Player'), findsOneWidget);
    expect(built, 0, reason: 'the menu alone must not deal a hand');

    await tester.tap(find.text('Single Player'));
    await tester.pump();
    expect(built, 0, reason: 'still only picking characters');

    await tester.tap(find.byKey(const Key('charactersContinue')));
    await tester.pump(); // the loading frame, before any dealing

    // The loading screen is painted in this frame; `_startOffline` waits on
    // `endOfFrame`, so the dealing happens off the back of it — which is the
    // point, and also why `built` is allowed to have ticked over by now.
    expect(find.text('Preparing your table…'), findsOneWidget);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(built, 1);
    expect(find.text('Preparing your table…'), findsNothing);
  });
}
