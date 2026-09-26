import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:tilesense/game/online_game_controller.dart';
import 'package:tilesense/game/sfx.dart' show Character, kCharacterName;
import 'package:tilesense/main.dart' show kDesignSize;
import 'package:tilesense/ui/character_picker.dart';
import 'package:tilesense/ui/online_game_page.dart';
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

  testWidgets('Create and Join each carry an emoji on the left of the title',
      (tester) async {
    final game = OnlineGameController();
    await pump(tester, game);

    for (final (emojiKey, title) in [
      ('createRoomEmoji', 'Create a room'),
      ('joinRoomEmoji', 'Join a room'),
    ]) {
      final emoji = tester.getRect(find.byKey(Key(emojiKey)));
      final label = tester.getRect(find.text(title));
      expect(emoji.right, lessThanOrEqualTo(label.left),
          reason: '$title\'s emoji should sit to its left');
      expect((emoji.center.dy - label.center.dy).abs(), lessThan(4),
          reason: 'on the same line as $title');
    }
    expect(tester.takeException(), isNull);

    game.dispose();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('Hong Kong rooms pick a 0-3 minimum faan, with no overflow',
      (tester) async {
    final game = OnlineGameController();
    await pump(tester, game);

    expect(find.byKey(const Key('onlineMinimumFaan_0')), findsNothing,
        reason: 'riichi has no faan minimum to pick');
    await tester.tap(find.byKey(const Key('onlineRuleset_hongKong')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('onlineMinimumFaan_3')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('createRoom')));
    await tester.pump();
    expect(game.ruleset, Ruleset.hongKong);
    expect(game.minimumFaan, 3);

    game.dispose();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('Taiwanese rooms pick a 1, 3 or 5 tai minimum, with no overflow',
      (tester) async {
    final game = OnlineGameController();
    await pump(tester, game);

    expect(find.byKey(const Key('onlineMinimumPoints_5')), findsNothing,
        reason: 'riichi has no minimum to pick');
    await tester.tap(find.byKey(const Key('onlineRuleset_taiwanese')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('onlineMinimumFaan_0')), findsNothing);
    await tester.tap(find.byKey(const Key('onlineMinimumPoints_3')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('createRoom')));
    await tester.pump();
    expect(game.ruleset, Ruleset.taiwanese);
    expect(game.minimumPoints, 3);

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

  group('the online table', () {
    /// [phone] boosts the text the way the fitted canvas does on a phone,
    /// which is what `isPhoneLayout` reads.
    Future<void> pumpTable(WidgetTester tester, OnlineGameController game,
        {required VoidCallback onExit, bool phone = false}) async {
      await tester.binding.setSurfaceSize(kDesignSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(phone ? 1.35 : 1)),
          child: child!,
        ),
        home: OnlineGamePage(controller: game, onExit: onExit),
      ));
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('Leave is a big labelled button that asks first mid-game',
        (tester) async {
      final game = OnlineGameController();
      var exited = false;
      await pumpTable(tester, game, onExit: () => exited = true);

      final leave = find.byKey(const Key('onlineLeave'));
      expect(tester.getSize(leave).height, greaterThanOrEqualTo(40));
      expect(tester.getSize(leave).width, greaterThanOrEqualTo(44));
      expect(find.byKey(const Key('clientIdButton')), findsOneWidget);

      await tester.tap(leave);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Leave this game?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('leaveStay')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(exited, isFalse, reason: 'Stay keeps you at the table');

      await tester.tap(leave);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('leaveConfirm')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(exited, isTrue);

      game.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('a phone gets Leave, Sound and Client ID in its Menu',
        (tester) async {
      final game = OnlineGameController();
      await pumpTable(tester, game, onExit: () {}, phone: true);

      expect(find.byKey(const Key('onlineLeave')), findsNothing);
      expect(find.byKey(const Key('clientIdButton')), findsNothing);
      await tester.tap(find.byKey(const Key('phoneMenu')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      for (final key in [
        'onlineMenuLeave',
        'onlineMenuSound',
        'onlineMenuClientId'
      ]) {
        expect(tester.getSize(find.byKey(Key(key))).height,
            greaterThanOrEqualTo(48),
            reason: key);
      }
      await tester.tap(find.byKey(const Key('onlineMenuClientId')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('clientIdValue')), findsOneWidget);
      expect(tester.takeException(), isNull);

      game.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}
