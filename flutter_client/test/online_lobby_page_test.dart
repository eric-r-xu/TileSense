import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:tilesense/game/online_game_controller.dart';
import 'package:tilesense/game/sfx.dart' show Character, kCharacterName;
import 'package:tilesense/main.dart' show kDesignSize;
import 'package:tilesense/ui/character_picker.dart';
import 'package:tilesense/ui/online_lobby_page.dart';

/// The pre-room setup screen: it runs two columns side by side (rather than
/// one long stack) specifically so it fits in `kDesignSize`'s 820px height
/// with no scrolling, and the name field is meant to track whichever
/// character is selected until the player types their own.
void main() {
  Future<void> pump(WidgetTester tester, OnlineGameController game) async {
    await tester.binding.setSurfaceSize(kDesignSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: kDesignSize.width,
          height: kDesignSize.height,
          child: OnlineLobbyPage(
            controller: game,
            initialRuleset: Ruleset.riichi,
            onExit: () {},
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('the setup screen renders at design size with no overflow',
      (tester) async {
    final game = OnlineGameController();
    await pump(tester, game);

    expect(tester.takeException(), isNull);
    // Both halves of the two-column layout are on screen at once — the
    // whole point of the rework — not one revealed only after scrolling.
    expect(find.text('Create a room'), findsOneWidget);
    expect(find.text('Choose your character'), findsOneWidget);
    expect(find.text('Join a room'), findsOneWidget);

    game.dispose();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('the name field defaults to the selected character',
      (tester) async {
    final game = OnlineGameController();
    await pump(tester, game);

    final startCharacter = game.myCharacter;
    final nameField = tester.widget<TextField>(find.byType(TextField).first);
    expect(nameField.controller!.text, kCharacterName[startCharacter]);

    // Picking a different character while the name is still a default moves
    // the name along with it.
    final other = Character.values.firstWhere((c) => c != startCharacter);
    final option = find.descendant(
      of: find.byType(CharacterRow),
      matching: find.text(kCharacterName[other]!),
    );
    await tester.tap(option.first);
    await tester.pump();

    final updated = tester.widget<TextField>(find.byType(TextField).first);
    expect(updated.controller!.text, kCharacterName[other]);

    game.dispose();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
      'typing a custom name stops it from following the character choice',
      (tester) async {
    final game = OnlineGameController();
    await pump(tester, game);

    await tester.enterText(find.byType(TextField).first, 'Kirby');
    await tester.pump();

    final startCharacter = game.myCharacter;
    final other = Character.values.firstWhere((c) => c != startCharacter);
    final option = find.descendant(
      of: find.byType(CharacterRow),
      matching: find.text(kCharacterName[other]!),
    );
    await tester.tap(option.first);
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller!.text, 'Kirby',
        reason: 'a typed name should survive switching characters');

    game.dispose();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
