import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:tilesense/game/online_game_controller.dart';
import 'package:tilesense/game/sfx.dart' show Character, kCharacterName;
import 'package:tilesense/main.dart' show TileSenseApp, kDesignSize;
import 'package:tilesense/net/guest_identity.dart';
import 'package:tilesense/ui/character_picker.dart';
import 'package:tilesense/ui/online_game_page.dart';
import 'package:tilesense/ui/online_lobby_page.dart';

import 'loading_helpers.dart';
import 'lobby_helpers.dart';

/// The pre-room setup screen: it runs two columns side by side (rather than
/// one long stack) specifically so it fits in `kDesignSize`'s 820px height
/// with no scrolling, and the name field is meant to track whichever
/// character is selected until the player types their own.
void main() {
  preloadDeferredPages();
  Future<void> pump(WidgetTester tester, OnlineGameController game) async {
    await tester.binding.setSurfaceSize(kDesignSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: kDesignSize.width,
          height: kDesignSize.height,
          // Rebuilt on every controller change, as `OnlinePage` does.
          child: AnimatedBuilder(
            animation: game,
            builder: (_, __) => OnlineLobbyPage(
              controller: game,
              initialRuleset: Ruleset.riichi,
              onExit: () {},
            ),
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

  testWidgets('one Pace choice sets both the discard and the call clock',
      (tester) async {
    final game = OnlineGameController();
    await pump(tester, game);

    // The old separate pickers are gone.
    expect(find.text('Calls buffer'), findsNothing);
    expect(find.text('40s per turn · 10s to call'), findsOneWidget,
        reason: 'Standard is the default');
    for (final ruleset in [
      Ruleset.hongKong,
      Ruleset.taiwanese,
      Ruleset.mcr,
      Ruleset.riichi,
    ]) {
      await pickOnlineRuleset(tester, ruleset);
      expect(tester.takeException(), isNull, reason: ruleset.name);
      expect(find.byKey(const Key('pace_relaxed')), findsOneWidget);
    }
    await tester.tap(find.byKey(const Key('pace_fast')));
    await tester.pump();
    expect(find.text('20s per turn · 5s to call'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pace_relaxed')));
    await tester.pump();
    expect(find.text('80s per turn · 20s to call'), findsOneWidget);
    await tester.tap(find.byKey(const Key('createRoom')));
    await tester.pump();
    expect((game.discardSeconds, game.callSeconds), (60, 20));

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
    await pickOnlineRuleset(tester, Ruleset.hongKong);
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
    await pickOnlineRuleset(tester, Ruleset.taiwanese);
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

  testWidgets('Rules and Game length are dropdowns that set the new room',
      (tester) async {
    final game = OnlineGameController();
    await pump(tester, game);

    // The old ruleset buttons and full-game switch are gone.
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.text('Rules'), findsOneWidget);
    expect(find.text('Game length'), findsOneWidget);
    expect(onlineRulesetShown(tester), Ruleset.riichi);
    expect(find.text('半庄 Hanchan'), findsOneWidget, reason: 'full by default');

    // MCR names its own lengths.
    await pickOnlineRuleset(tester, Ruleset.mcr);
    expect(onlineRulesetShown(tester), Ruleset.mcr);
    expect(find.text('Full game · 16 hands'), findsOneWidget);
    await pickLobbyDropdown(tester, const Key('onlineLengthDropdown'),
        const Key('onlineLength_east'));
    expect(find.text('East practice · 4 hands'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('createRoom')));
    await tester.pump();
    expect(game.ruleset, Ruleset.mcr);
    expect(game.hanchan, isFalse);

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

  testWidgets('Adri can be selected for a new online room', (tester) async {
    final game = OnlineGameController();
    await pump(tester, game);
    await tester.tap(find.descendant(
      of: find.byType(CharacterRow),
      matching: find.text('Adri'),
    ));
    await tester.pump();
    expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'Adri');
    await tester.tap(find.byKey(const Key('createRoom')));
    await tester.pump();
    expect(game.myCharacter, Character.adri);
    expect(tester.takeException(), isNull);
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

    testWidgets('the bar names the rules and minimum top right, phone or not',
        (tester) async {
      for (final phone in [false, true]) {
        for (final (ruleset, faan, tai, label) in [
          (Ruleset.riichi, 0, 5, '🇯🇵'),
          (Ruleset.hongKong, 0, 5, '🇭🇰'),
          (Ruleset.hongKong, 3, 5, '🇭🇰 3 faan'),
          (Ruleset.taiwanese, 0, 3, '🇹🇼 3 tai'),
        ]) {
          final game = OnlineGameController()
            ..ruleset = ruleset
            ..minimumFaan = faan
            ..minimumPoints = tai;
          await pumpTable(tester, game, onExit: () {}, phone: phone);
          final badge = find.byKey(const Key('rulesetBadge'));
          expect(tester.widget<Text>(badge).data, label,
              reason: '$ruleset, phone: $phone');
          final bar = tester.getRect(find.byType(AppBar));
          final r = tester.getRect(badge);
          expect(r.left, greaterThan(bar.center.dx),
              reason: 'on the right of the bar');
          expect(r.top, greaterThanOrEqualTo(bar.top));
          expect(r.bottom, lessThanOrEqualTo(bar.bottom));
          expect(tester.takeException(), isNull);
          game.dispose();
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
        }
      }
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

  group('rejoining a game left while it was still going', () {
    tearDown(() => GuestIdentity.load().saveActiveRoom(null));

    testWidgets('the lobby offers Rejoin once the server says the game is on',
        (tester) async {
      GuestIdentity.load().saveActiveRoom('ABCD');
      final game = OnlineGameController();
      await pump(tester, game);
      // Nothing until the server has answered: the game may be long over.
      expect(find.byKey(const Key('rejoinBanner')), findsNothing);

      game.debugReceive(
          {'type': 'room_status', 'roomCode': 'ABCD', 'rejoinable': true});
      await tester.pump();
      expect(find.byKey(const Key('rejoinBanner')), findsOneWidget);
      expect(find.textContaining('room ABCD'), findsOneWidget);
      final rejoin = tester.getSize(find.byKey(const Key('rejoinGame')));
      expect(rejoin.height, greaterThanOrEqualTo(44));
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('rejoinGame')));
      await tester.pump();
      expect(game.rejoining, isTrue);
      expect(find.text('Rejoining your game…'), findsOneWidget);

      // The server takes you back: the room is playing again.
      game.debugReceive({
        'type': 'room_state',
        'code': 'ABCD',
        'ruleset': 'riichi',
        'hanchan': true,
        'phase': 'playing',
        'yourSeat': 2,
        'seats': [
          for (var i = 0; i < 4; i++)
            {
              'seat': i,
              'name': 'P$i',
              'character': null,
              'isBot': i != 2,
              'isHost': i == 0,
              'connected': i == 2,
            }
        ],
      });
      expect(game.rejoining, isFalse);
      expect(game.roomPhase, RoomLifecycle.playing);
      expect(GuestIdentity.load().activeRoomCode, 'ABCD');

      game.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('the main menu offers Rejoin, which reopens that game',
        (tester) async {
      await tester.binding.setSurfaceSize(kDesignSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const TileSenseApp());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('rejoinOnline')), findsNothing);
      await tester.pumpWidget(const SizedBox());

      GuestIdentity.load().saveActiveRoom('ABCD');
      await tester.pumpWidget(const TileSenseApp());
      await tester.pump(const Duration(milliseconds: 100));
      final rejoin = find.byKey(const Key('rejoinOnline'));
      expect(rejoin, findsOneWidget);
      expect(find.textContaining('Room ABCD'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(rejoin);
      await pumpUntilFound(tester, find.text('Rejoining your game…'));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a server without room_status is no error, and no reason to '
        'forget the game', (tester) async {
      GuestIdentity.load().saveActiveRoom('ABCD');
      final game = OnlineGameController();
      await pump(tester, game);
      // The main menu's Rejoin is under way when the probe's answer arrives.
      game.rejoinRoom('ABCD');
      game.debugReceive(
          {'type': 'error', 'message': 'unknown message type: room_status'});
      await tester.pump();
      expect(game.lastError, isNull);
      expect(game.rejoining, isTrue, reason: 'the rejoin itself goes on');
      expect(GuestIdentity.load().activeRoomCode, 'ABCD');
      expect(find.byType(SnackBar), findsNothing);

      game.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('a game that has ended is forgotten, not offered',
        (tester) async {
      GuestIdentity.load().saveActiveRoom('ABCD');
      final game = OnlineGameController();
      await pump(tester, game);
      game.debugReceive(
          {'type': 'room_status', 'roomCode': 'ABCD', 'rejoinable': false});
      await tester.pump();
      expect(find.byKey(const Key('rejoinBanner')), findsNothing);
      expect(GuestIdentity.load().activeRoomCode, isNull);

      game.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('a failed rejoin says the game has ended and forgets it',
        (tester) async {
      GuestIdentity.load().saveActiveRoom('ABCD');
      final game = OnlineGameController();
      await pump(tester, game);
      game.rejoinRoom('ABCD');
      await tester.pump();
      expect(find.text('Rejoining your game…'), findsOneWidget);

      game.debugReceive({'type': 'error', 'message': 'room no longer exists'});
      await tester.pump();
      expect(game.rejoining, isFalse);
      expect(game.lastError, 'That game has ended');
      expect(GuestIdentity.load().activeRoomCode, isNull);
      expect(find.byKey(const Key('rejoinBanner')), findsNothing);

      game.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}
