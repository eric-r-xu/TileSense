import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/round.dart' show MinimumShortfall;
import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/tile.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/logic/efficiency_engine.dart';
import 'package:tilesense/scenario/scenario_controller.dart';
import 'package:tilesense/ui/beginner_guide.dart';
import 'package:tilesense/ui/efficiency_overlay.dart';
import 'package:tilesense/ui/tile_face.dart';

import 'helpers.dart';
import 'l10n_helpers.dart';

/// The guide's simple view: one best discard in plain words, in place of the
/// table of shanten, EV and safety figures, switchable back to that table.
void main() {
  EfficiencyReport report(String hand, {Ruleset ruleset = Ruleset.hongKong}) {
    final tiles = parseTiles(hand);
    return EfficiencyEngine().analyze(
      hand: tiles,
      visibleCounts34: toCounts34(tiles),
      canRiichi: false,
      valueContext: EfficiencyValueContext(
        melds: const [],
        roundWind: Wind.east,
        seatWind: Wind.east,
        isDealer: true,
        inRiichi: false,
        wallTilesRemaining: 40,
        doraIndicators: const [],
        ruleset: ruleset,
      ),
    );
  }

  setUp(() {
    Sfx.i.enabled = false;
    BeginnerGuide.set(true);
  });
  tearDown(() {
    BeginnerGuide.set(false);
    Sfx.i.enabled = true;
  });

  String text(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data!;

  /// How many of the meter's steps are lit (in [color], when given).
  int filledSteps(WidgetTester tester, {Color? color}) {
    var n = 0;
    for (var i = 0; i < SimpleGuideBody.meterSteps; i++) {
      final box = tester.widget<Container>(find.byKey(Key('meterStep_$i')));
      final c = (box.decoration as BoxDecoration).color!;
      if (color != null ? c == color : c.a > 0.5) n++;
    }
    return n;
  }

  Future<void> pumpPanel(WidgetTester tester, EfficiencyReport r) =>
      pumpLocalized(
        tester,
        Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: EfficiencyOverlay(game: ScenarioController(), report: r),
          ),
        ),
      );

  group('outlook', () {
    test('a hand one tile from winning is waiting, whatever else it holds',
        () {
      final r = report('123m 456m 789m 34p 55p 9s');
      final best = simpleChoices(r).first;
      expect(best.recommended, isTrue);
      expect(outlookOf(best, r), DiscardOutlook.waiting);
      expect(best.discard, TileType.sou9);
    });

    test('a discard that breaks the hand moves it further away', () {
      final r = report('123m 456m 789m 34p 55p 9s');
      final worse = r.lines.firstWhere((l) => l.shanten > r.currentShanten);
      expect(outlookOf(worse, r), DiscardOutlook.furtherAway);
    });

    test('the choices are the pick, then at most two others', () {
      final r = report('1m 234m 567m 99s 78p 3p W 5s');
      final choices = simpleChoices(r);
      expect(choices, hasLength(3));
      expect(choices.first.recommended, isTrue);
      expect(choices.skip(1).any((l) => l.recommended), isFalse);
    });
  });

  testWidgets('the simple view names the best discard and leaves out the '
      'table', (tester) async {
    await pumpPanel(tester, report('123m 456m 789m 34p 55p 9s'));
    expect(find.byKey(const Key('simpleGuide')), findsOneWidget);
    expect(find.text('Best discard'), findsOneWidget);
    expect(find.textContaining('Leaves you waiting for'), findsWidgets);
    expect(find.text('TileSense EV'), findsNothing);
    expect(find.text('Risk'), findsNothing);
    expect(find.text('Simple'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the chip switches to the full table and back, and the choice '
      'is remembered', (tester) async {
    await pumpPanel(tester, report('123m 456m 789m 34p 55p 9s'));
    await tester.tap(find.byKey(const Key('guideViewToggle')));
    await tester.pump();
    expect(BeginnerGuide.on.value, isFalse);
    expect(find.byKey(const Key('simpleGuide')), findsNothing);
    expect(find.text('TileSense EV'), findsOneWidget);
    expect(find.text('Full'), findsOneWidget);

    await tester.tap(find.byKey(const Key('guideViewToggle')));
    await tester.pump();
    expect(BeginnerGuide.on.value, isTrue);
    expect(find.byKey(const Key('simpleGuide')), findsOneWidget);
    expect(find.text('TileSense EV'), findsNothing);
  });

  testWidgets('it reads the same on a Riichi hand, without jargon',
      (tester) async {
    await pumpPanel(
        tester, report('123m 456m 789m 34p 55p 9s', ruleset: Ruleset.riichi));
    expect(find.byKey(const Key('simpleGuide')), findsOneWidget);
    expect(find.text('RIICHI'), findsNothing);
    expect(find.text('DAMATEN'), findsNothing);
  });

  group('distance meter', () {
    test('counts the tiles a hand still needs, and names the winning ones',
        () {
      final ready = report('123m 456m 789m 34p 55p 9s');
      expect(tilesAway(ready), 1);
      expect(winningTiles(ready).toSet(), {TileType.pin2, TileType.pin5});

      final far = report('1m 234m 567m 99s 78p 3p W 5s');
      expect(tilesAway(far), greaterThan(1));
      expect(winningTiles(far), isEmpty,
          reason: 'no winning tiles to name until one draw from a win');
    });

    testWidgets('a hand one tile away fills the bar and shows what wins',
        (tester) async {
      await pumpPanel(tester, report('123m 456m 789m 34p 55p 9s'));
      expect(text(tester, 'simpleGuideStatus'), '1 tile away from winning');
      expect(find.byKey(const Key('simpleGuideWaits')), findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const Key('simpleGuideWaits')),
              matching: find.byType(TileFace)),
          findsNWidgets(2));
      expect(find.byKey(const Key('simpleGuideWaitsLabel')), findsOneWidget);
      expect(filledSteps(tester), SimpleGuideBody.meterSteps - 1);
    });

    testWidgets('a hand further out shows fewer steps and no winning tiles',
        (tester) async {
      final far = report('1m 234m 567m 99s 78p 3p W 5s');
      await pumpPanel(tester, far);
      expect(text(tester, 'simpleGuideStatus'),
          '${tilesAway(far)} tiles away from winning');
      expect(find.byKey(const Key('simpleGuideWaits')), findsNothing);
      expect(filledSteps(tester),
          SimpleGuideBody.meterSteps - tilesAway(far).clamp(0, 6));
    });

    testWidgets('a complete hand says so, with the whole bar green',
        (tester) async {
      // The report only ranks discards; the caller says the hand has won.
      await pumpLocalized(
          tester,
          Scaffold(
              body: SimpleGuideBody(
                  report: report('123m 456m 789m 345p 55s'),
                  complete: true)));
      expect(text(tester, 'simpleGuideStatus'), 'Your hand is complete!');
      expect(find.byKey(const Key('simpleGuideWaits')), findsNothing);
      expect(filledSteps(tester), SimpleGuideBody.meterSteps);
      expect(filledSteps(tester, color: const Color(0xff43a047)),
          SimpleGuideBody.meterSteps);
    });

    testWidgets('warns when the hand is too cheap to win at this table',
        (tester) async {
      final r = report('123m 456m 789m 34p 55p 9s');
      await pumpLocalized(
          tester,
          Scaffold(
              body: SimpleGuideBody(
                  report: r, shortfall: MinimumShortfall.dead)));
      expect(find.byKey(const Key('simpleGuideShortfall')), findsOneWidget);
      expect(find.textContaining('cannot win as it stands'), findsOneWidget);

      await pumpLocalized(
          tester, Scaffold(body: SimpleGuideBody(report: r)));
      expect(find.byKey(const Key('simpleGuideShortfall')), findsNothing);
    });
  });
}
