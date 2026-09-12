import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/logic/meld.dart';
import 'package:tilesense/logic/tile.dart';
import 'package:tilesense/main.dart';
import 'package:tilesense/scenario/scenario.dart';
import 'package:tilesense/scenario/scenario_controller.dart';
import 'package:tilesense/ui/efficiency_overlay.dart';
import 'package:tilesense/ui/scenario_page.dart';
import 'package:tilesense/ui/table_view.dart';
import 'helpers.dart';

void fill(Scenario s, List<Tile> into, String spec) {
  for (final t in parseTypes(spec)) {
    into.add(s.mint(t));
  }
}

void main() {
  test('ordinary tile counts exclude removed dora indicators', () {
    final s = Scenario();
    fill(s, s.hand, '111m 234m 567p 99s 78p 3p');
    fill(s, s.seats[2].pond, '1m');
    expect(s.used(TileType.man1), 4);
    expect(s.isValid, isTrue);
    fill(s, s.seats[3].pond, '1m');
    expect(s.problems().first, contains('More than 4 copies'));
  });
  test('bonus tiles are unique and stored separately from the hand', () {
    final s = Scenario();
    fill(s, s.hand, '123m 456p 789s 22m 55p N');
    s.seats[0].flowers.add(s.mint(TileType.plum));
    expect(s.remainingCopies(TileType.plum), 0);
    expect(s.visibleCounts34().reduce((a, b) => a + b), 14);
    s.seats[1].flowers.add(s.mint(TileType.plum));
    expect(s.problems().any((p) => p.contains('Only one Plum')), isTrue);
  });
  test('melds reduce concealed target and seat winds reach the guide', () {
    final c = ScenarioController();
    addTearDown(c.dispose);
    c.edit((s) {
      s.seatWind = Wind.south;
      s.seats[0].melds.add(
          Meld(kind: MeldKind.sequence, low: TileType.man1, concealed: false));
      fill(s, s.hand, '456p 789s 22m 55p N');
      s.seats[0].flowers.add(s.mint(TileType.plum));
    });
    expect(c.blockedReason, isNull);
    expect(c.round.seats[0].wind, Wind.south);
    expect(c.round.seats[0].flowers.single.type, TileType.plum);
    expect(c.scenario.concealedTarget(withDraw: true), 11);
    expect(c.report.lines, isNotEmpty);
    expect(c.report.recommendRiichi, isFalse);
  });
  group('the builder screen', () {
    testWidgets('opens from the welcome screen and scores a random table',
        (tester) async {
      await tester.binding.setSurfaceSize(kDesignSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const TileSenseApp());
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('openBuilder')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ScenarioPage), findsOneWidget);
      // The guide is always on here, and the table is the real one.
      expect(find.byType(EfficiencyOverlay), findsOneWidget);
      expect(find.byType(TableView), findsOneWidget);
      // No live-game controls.
      expect(find.textContaining('Auto-Play'), findsNothing);
      expect(find.byTooltip('Pause'), findsNothing);
      expect(find.text('• Esc — pause the game'), findsNothing);

      await tester.tap(find.text('Random'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Scored:'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('is isolated: no game runs behind it', (tester) async {
      await tester.binding.setSurfaceSize(kDesignSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const TileSenseApp());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('openBuilder')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Random'));
      await tester.pump(const Duration(milliseconds: 100));

      final page = tester.widget<TableView>(find.byType(TableView)).game;
      final posed = [
        for (final seat in page.round.seats) [for (final t in seat.pond) t.code]
      ];

      // A live game would have a turn timer here; the builder has none, so the
      // tree settles and nothing on the table moves on its own.
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
      await tester.pump(const Duration(seconds: 5));
      final after = [
        for (final seat in page.round.seats) [for (final t in seat.pond) t.code]
      ];
      expect(after, posed, reason: 'no bot took a turn behind the builder');

      // Leaving drops back to the welcome screen with the game still unstarted.
      await tester.tap(find.byTooltip('Back to start'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Start'), findsOneWidget);
      expect(find.byType(ScenarioPage), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}
