import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/tile.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/main.dart';
import 'package:tilesense/ui/learn_to_play_page.dart';
import 'package:tilesense/ui/rules_reader.dart';
import 'package:tilesense/ui/table_tour.dart';
import 'package:tilesense/ui/table_view.dart';
import 'package:tilesense/ui/tile_face.dart';

import 'helpers.dart';
import 'l10n_helpers.dart';

/// The table tour over a newcomer's first hand, and the phone-size tiles the
/// teaching screens draw.
void main() {
  setUp(() {
    Sfx.i.enabled = false;
    TableTour.autoShow = true;
    TableTour.reset();
  });
  tearDown(() {
    Sfx.i.enabled = true;
    TableTour.autoShow = false;
  });

  Future<void> boot(WidgetTester tester, {Size size = kDesignSize}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> startGame(WidgetTester tester) async {
    await tester.tap(find.text('Single Player'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('charactersContinue')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
  }

  GameController gameOf(WidgetTester tester) =>
      (tester.widget(find.byType(TableView).first) as TableView).game
          as GameController;

  testWidgets('the first hand opens the tour, paused; its five steps end it',
      (tester) async {
    await boot(tester);
    await startGame(tester);
    expect(find.byKey(const Key('tableTour')), findsOneWidget);
    expect(gameOf(tester).paused, isTrue, reason: 'the table waits');
    expect(find.text('PAUSED', findRichText: true), findsNothing,
        reason: 'no pause cover over what the tour points at');
    for (var step = 0; step < 5; step++) {
      expect(find.byKey(Key('tableTourStep_$step')), findsOneWidget);
      if (step == 1) {
        expect(find.byKey(const Key('tableTourLegend')), findsOneWidget);
      }
      // Only the rulebook step has the button that opens it.
      expect(find.byKey(const Key('tableTourOpenRules')),
          step == 3 ? findsOneWidget : findsNothing);
      await tester.tap(find.byKey(const Key('tableTourNext')));
      await tester.pump();
    }
    expect(find.byKey(const Key('tableTour')), findsNothing);
    expect(gameOf(tester).paused, isFalse, reason: 'play resumes');
    expect(TableTour.shouldAutoShow, isFalse);
  });

  testWidgets(
      'the rulebook step opens the rules and leaves the tour where it was',
      (tester) async {
    await boot(tester);
    await startGame(tester);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const Key('tableTourNext')));
      await tester.pump();
    }
    expect(find.byKey(const Key('tableTourStep_3')), findsOneWidget);
    expect(find.text('The rulebook'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tableTourOpenRules')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(RulesReader), findsOneWidget);
    expect(tester.widget<RulesReader>(find.byType(RulesReader)).ruleset,
        gameOf(tester).ruleset);

    await tester.tap(find.byKey(const Key('rulesReaderClose')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(RulesReader), findsNothing);
    expect(find.byKey(const Key('tableTourStep_3')), findsOneWidget);
    expect(gameOf(tester).paused, isTrue, reason: 'still held for the tour');
  });

  testWidgets('on a phone the rulebook step sends you to Menu, then Rules',
      (tester) async {
    await boot(tester, size: const Size(852, 393));
    await startGame(tester);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const Key('tableTourNext')));
      await tester.pump();
    }
    expect(find.byKey(const Key('tableTourStep_3')), findsOneWidget);
    expect(find.textContaining('Open Menu, then Rules'), findsOneWidget);
    expect(find.byKey(const Key('tableTourOpenRules')), findsOneWidget);
  });

  testWidgets('Skip ends it for good; the Learn popup brings it back',
      (tester) async {
    await boot(tester);
    await startGame(tester);
    await tester.tap(find.byKey(const Key('tableTourSkip')));
    await tester.pump();
    expect(find.byKey(const Key('tableTour')), findsNothing);
    expect(TableTour.shouldAutoShow, isFalse);

    // Back to the welcome screen: Learn > Table tour starts a game with it.
    await tester.tap(find.byKey(const Key('backToMenu')));
    await tester.pump();
    await tapInPopup(
        tester, 'learnTile', find.byKey(const Key('tableTourLink')));
    await tester.tap(find.byKey(const Key('charactersContinue')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(find.byKey(const Key('tableTour')), findsOneWidget);
  });

  testWidgets('on a phone the Menu sheet replays it', (tester) async {
    TableTour.markSeen();
    await boot(tester, size: const Size(852, 393));
    await startGame(tester);
    expect(find.byKey(const Key('tableTour')), findsNothing);
    await tester.tap(find.byKey(const Key('phoneMenu')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(find.byKey(const Key('phoneMenuTableTour')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('phoneMenuTableTour')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('tableTour')), findsOneWidget);
  });

  group('teaching tiles', () {
    double indexSize(WidgetTester tester) => tester
        .widget<Text>(find.descendant(
            of: find.byType(TileFace), matching: find.byType(Text)))
        .style!
        .fontSize!;

    testWidgets('the red index grows with the tile and with a phone boost',
        (tester) async {
      Future<double> sizeAt(double scale, double textScale) async {
        await tester.pumpWidget(MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: TileFace(
                  type: TileType.man5, size: TileSize.large, scale: scale),
            ),
          ),
        ));
        return indexSize(tester);
      }

      final desk = await sizeAt(1.65, 1.0);
      expect(desk, greaterThan(15), reason: 'no longer capped at 15');
      final phone = await sizeAt(1.65, 1.35);
      expect(phone, greaterThan(desk));
      expect(phone, lessThanOrEqualTo(64 * 1.65 * 0.30 + 0.001),
          reason: 'kept within 30% of the tile');
    });

    testWidgets('Learn to Play shows the tiles card in two rows',
        (tester) async {
      await pumpLocalized(
          tester,
          LearnToPlayPage(
              ruleset: Ruleset.riichi, onFinish: () {}, onBack: () {}),
          size: kDesignSize);
      await tester.tap(find.byKey(const Key('learnNext')));
      await tester.pump();
      final card = find.byKey(const Key('learnTiles_1'));
      expect(find.descendant(of: card, matching: find.byType(Row)),
          findsNWidgets(2));
    });
  });
}
