import 'loading_helpers.dart';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/tile.dart' show Wind;
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/main.dart';
import 'package:tilesense/ui/character_select_page.dart';
import 'package:tilesense/ui/scenario_page.dart';
import 'package:tilesense/ui/table_view.dart';

Future<void> _boot(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(kDesignSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const TileSenseApp());
  await tester.pump(const Duration(milliseconds: 100));
}

String _name(WidgetTester tester, int seat) =>
    tester.widget<Text>(find.byKey(Key('seatCharacterName_$seat'))).data!;

void main() {
  preloadDeferredPages();

  test('randomSeatCharacters draws four distinct characters', () {
    for (var seed = 0; seed < 50; seed++) {
      final picks = randomSeatCharacters(Random(seed));
      expect(picks, hasLength(4));
      expect(picks.toSet(), hasLength(4));
    }
    expect({for (var s = 0; s < 50; s++) ...randomSeatCharacters(Random(s))},
        hasLength(greaterThan(4)),
        reason: 'the draw should not be the same four every time');
  });

  test('seat winds follow the dealer round the table', () {
    // Dealer at seat 0: you are East, then South/West/North counter-clockwise.
    expect([for (var s = 0; s < 4; s++) seatStartingWind(s, 0)],
        [Wind.east, Wind.south, Wind.west, Wind.north]);
    // Across deals: you are West, right is North, across is East, left South.
    expect([for (var s = 0; s < 4; s++) seatStartingWind(s, 2)],
        [Wind.west, Wind.north, Wind.east, Wind.south]);
    expect({for (var s = 0; s < 40; s++) randomStartingDealer(Random(s))},
        {0, 1, 2, 3});
  });

  testWidgets('the guide mascot is the Single Player button\'s icon',
      (tester) async {
    await _boot(tester);
    final button = find.widgetWithText(ElevatedButton, 'Single Player');
    final mascot = find.descendant(
        of: button, matching: find.byKey(const Key('startGuideMascot')));
    expect(mascot, findsOneWidget);
    expect(tester.getRect(mascot).right,
        lessThanOrEqualTo(tester.getRect(find.text('Single Player')).left));
  });

  testWidgets('character select picks hanchan (default) or East only',
      (tester) async {
    await _boot(tester);
    await tester.tap(find.text('Single Player'));
    await tester.pump();

    bool selected(String key) {
      final b = tester.widget<OutlinedButton>(find.byKey(Key(key)));
      return b.style!.side!.resolve({})!.width == 2;
    }

    expect(selected('lengthHanchan'), isTrue);
    expect(selected('lengthEastOnly'), isFalse);

    await tester.tap(find.byKey(const Key('lengthEastOnly')));
    await tester.pump();
    expect(selected('lengthEastOnly'), isTrue);
    expect(selected('lengthHanchan'), isFalse);

    await tester.tap(find.byKey(const Key('lengthHanchan')));
    await tester.pump();
    expect(selected('lengthHanchan'), isTrue);
  });

  testWidgets('Hong Kong alone offers a 0-3 minimum faan, and the game uses it',
      (tester) async {
    await _boot(tester);
    await tester.tap(find.text('Single Player'));
    await tester.pump();

    bool selected(String key) {
      final b = tester.widget<OutlinedButton>(find.byKey(Key(key)));
      return b.style!.side!.resolve({})!.width == 2;
    }

    expect(find.byKey(const Key('minimumFaan_0')), findsNothing,
        reason: 'riichi has no faan minimum to pick');
    await tester.tap(find.byKey(const Key('startRuleset_hongKong')));
    await tester.pump();
    expect(selected('minimumFaan_0'), isTrue, reason: '0 is the default');

    await tester.tap(find.byKey(const Key('minimumFaan_2')));
    await tester.pump();
    expect(selected('minimumFaan_2'), isTrue);
    expect(selected('minimumFaan_0'), isFalse);

    await tester.tap(find.byKey(const Key('charactersContinue')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final game = tester.widget<TableView>(find.byType(TableView)).game
        as GameController;
    expect(game.ruleset, Ruleset.hongKong);
    expect(game.minimumFaan, 2);
    expect(game.round.minimumFaan, 2);
    expect(find.textContaining('2 faan min'), findsOneWidget);
  });

  testWidgets('offline goes through character select, with the old defaults',
      (tester) async {
    await _boot(tester);
    expect(find.text('CHOOSE YOUR CHARACTERS'), findsNothing,
        reason: 'the welcome screen no longer hosts the picker');

    await tester.tap(find.text('Single Player'));
    await tester.pump();
    expect(find.text('CHOOSE YOUR CHARACTERS'), findsOneWidget);

    // Each seat is labelled with its starting wind and where it sits.
    const winds = ['East', 'South', 'West', 'North'];
    const positions = ['YOU', 'Right', 'Across', 'Left'];
    const defaults = ['Orderic', 'Grant', 'Hubert', 'Astaroth'];
    const kanji = ['東', '南', '西', '北'];
    for (var seat = 0; seat < 4; seat++) {
      expect(tester.widget<Text>(find.byKey(Key('seatWind_$seat'))).data,
          winds[seat]);
      expect(tester.widget<Text>(find.byKey(Key('seatWindKanji_$seat'))).data,
          kanji[seat]);
      expect(tester.widget<Text>(find.byKey(Key('seatPosition_$seat'))).data,
          positions[seat]);
      expect(_name(tester, seat), defaults[seat]);
    }

    // Picking changes that seat only.
    await tester.tap(find.byKey(const Key('seatCharacterPick_1_erika')));
    await tester.pump();
    expect(_name(tester, 1), 'Erika');
    expect(_name(tester, 0), 'Orderic');

    await tester.tap(find.byKey(const Key('seatCharacterPick_0_melissa')));
    await tester.pump();
    expect(_name(tester, 0), 'Melissa');

    await tester.tap(find.byKey(const Key('seatCharacterPick_2_matityahu')));
    await tester.pump();
    expect(_name(tester, 2), 'Matityahu');

    await tester.tap(find.byKey(const Key('seatCharacterPick_3_sherman')));
    await tester.pump();
    expect(_name(tester, 3), 'Sherman');

    await tester.tap(find.byKey(const Key('charactersContinue')));
    await tester.pump(); // Render the startup/loading frame.
    // The table is created after a loading frame.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final table = tester.widget<TableView>(find.byType(TableView));
    expect(table.game.characterForSeat(1), Character.erika);
    expect(table.game.characterForSeat(0), Character.melissa);
    expect(table.game.characterForSeat(2), Character.matityahu);
    expect(table.game.characterForSeat(3), Character.sherman);
  });

  testWidgets('you are not fixed as East: pick a wind and the deal follows',
      (tester) async {
    await _boot(tester);
    await tester.tap(find.text('Single Player'));
    await tester.pump();

    await tester.tap(find.byKey(const Key('startWind_west')));
    await tester.pump();
    // You (seat 0) are West; Across (seat 2) is East and deals.
    const winds = ['West', 'North', 'East', 'South'];
    for (var seat = 0; seat < 4; seat++) {
      expect(tester.widget<Text>(find.byKey(Key('seatWind_$seat'))).data,
          winds[seat]);
    }
    expect(tester.widget<Text>(find.byKey(const Key('seatWindKanji_0'))).data,
        '西');
    expect(tester.widget<Text>(find.byKey(const Key('dealerNote'))).data,
        contains('across'));

    await tester.tap(find.byKey(const Key('charactersContinue')));
    await tester.pump(); // Render the startup/loading frame.
    // The table is created after a loading frame.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final game = tester.widget<TableView>(find.byType(TableView)).game;
    expect(game.round.dealer, 2);
    expect(game.round.seats[0].wind, Wind.west);
    expect(game.round.seats[2].wind, Wind.east);
  });

  testWidgets('randomize reshuffles the characters, and Back leaves',
      (tester) async {
    await _boot(tester);
    await tester.tap(find.text('Single Player'));
    await tester.pump();

    final winds = <String>{};
    var changed = false;
    for (var i = 0; i < 30; i++) {
      winds.add(tester.widget<Text>(find.byKey(const Key('seatWind_0'))).data!);
      await tester.tap(find.byKey(const Key('randomizeCharacters')));
      await tester.pump();
      final names = [for (var s = 0; s < 4; s++) _name(tester, s)];
      expect(names.toSet(), hasLength(4));
      changed |= names.join() != 'OrdericGrantHubertAstaroth';
    }
    expect(changed, isTrue);
    expect(winds.length, greaterThan(1),
        reason: 'randomize should move your starting wind too');

    await tester.tap(find.byKey(const Key('charactersBack')));
    await tester.pump();
    expect(find.text('Single Player'), findsOneWidget);
    expect(find.byType(CharacterSelectPage), findsNothing);
  });

  testWidgets('sound is on by default, and the checkbox turns it off',
      (tester) async {
    addTearDown(() => Sfx.i.enabled = true);
    await _boot(tester);
    expect(Sfx.i.enabled, isTrue);

    await tester.tap(find.text('Single Player'));
    await tester.pump();
    Checkbox box() => tester.widget<Checkbox>(find.descendant(
        of: find.byKey(const Key('soundCheckbox')),
        matching: find.byType(Checkbox)));
    expect(box().value, isTrue);

    await tester.tap(find.byKey(const Key('soundCheckbox')));
    await tester.pump();
    expect(box().value, isFalse);
    expect(Sfx.i.enabled, isFalse);

    // The table's own toggle agrees with what was chosen here.
    await tester.tap(find.byKey(const Key('charactersContinue')));
    await tester.pump(); // Render the startup/loading frame.
    // The table is created after a loading frame.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
        tester
            .widget<Icon>(find.descendant(
                of: find.byKey(const Key('soundToggle')),
                matching: find.byType(Icon)))
            .icon,
        Icons.volume_off);
  });

  testWidgets('the builder skips character select and draws four characters',
      (tester) async {
    await _boot(tester);
    await tester.tap(find.byKey(const Key('openBuilder')));
    await pumpLoadedPage(tester);
    expect(find.byType(CharacterSelectPage), findsNothing);
    expect(find.byType(ScenarioPage), findsOneWidget);
    final game = tester.widget<TableView>(find.byType(TableView)).game;
    expect({for (var i = 0; i < 4; i++) game.characterForSeat(i)}.length, 4);
  });
}
