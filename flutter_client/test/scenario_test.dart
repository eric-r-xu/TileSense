import 'loading_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/game/game_controller.dart' show kHumanSeat;
import 'package:mahjong_core/meld.dart';
import 'package:mahjong_core/round.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/tile.dart';
import 'package:tilesense/main.dart';
import 'package:tilesense/scenario/scenario.dart';
import 'package:tilesense/scenario/scenario_controller.dart';
import 'package:tilesense/ui/efficiency_overlay.dart';
import 'package:tilesense/ui/scenario_page.dart';
import 'package:tilesense/ui/table_view.dart';
import 'package:tilesense/ui/tile_face.dart';

import 'helpers.dart';

void fill(Scenario s, List<Tile> into, String spec) {
  for (final t in parseTypes(spec)) {
    into.add(s.mint(t));
  }
}

void main() {
  preloadDeferredPages();

  group('scenario validity', () {
    test('nothing may appear more than four times across the whole table', () {
      final c = ScenarioController();
      // Three 1m in hand, one in a pond, and 1m is also the dora indicator.
      c.edit((s) {
        fill(s, s.hand, '111m 234m 567m 99s 78p 3p');
        fill(s, s.seats[2].pond, '1m');
      });
      expect(c.scenario.used(TileType.man1), 5);
      expect(c.blockedReason, contains('More than 4 copies'));
      expect(c.blockedReason, contains('1m'));
      expect(c.report.lines, isEmpty);

      // Drop the dora clash and it scores.
      c.edit((s) => s.dora
        ..clear()
        ..add(TileType.pei));
      expect(c.scenario.used(TileType.man1), 4);
      expect(c.blockedReason, isNull);
      expect(c.report.lines, isNotEmpty);
    });

    test('remainingCopies counts hand, ponds, melds and dora together', () {
      final s = Scenario();
      s.dora
        ..clear()
        ..add(TileType.sou4);
      expect(s.remainingCopies(TileType.sou4), 3);
      fill(s, s.hand, '4s');
      expect(s.remainingCopies(TileType.sou4), 2);
      fill(s, s.seats[1].pond, '4s');
      expect(s.remainingCopies(TileType.sou4), 1);
      s.seats[2].melds.add(
          Meld(kind: MeldKind.triplet, low: TileType.sou4, concealed: false));
      expect(s.remainingCopies(TileType.sou4), -2);
      expect(s.problems().first, contains('4s'));
    });

    test('a hand is 14 with a draw, or 13 waiting on a call — less 3 per call',
        () {
      final s = Scenario();
      fill(s, s.hand, '234m 567m 99s 78p 3p W');
      expect(s.hand.length, 12);
      expect(s.problems().first, contains('holds 12 tiles'));

      fill(s, s.hand, '1m');
      expect(s.problems(), isEmpty, reason: '13 is a legal call-decision hand');
      expect(s.isDiscardRead, isFalse);

      fill(s, s.hand, '2m');
      expect(s.problems(), isEmpty, reason: '14 is a legal discard hand');
      expect(s.isDiscardRead, isTrue);

      // One pon eats three concealed tiles.
      s.seats[0].melds.add(
          Meld(kind: MeldKind.triplet, low: TileType.pei, concealed: false));
      expect(s.concealedTarget(withDraw: true), 11);
      expect(s.problems().first, contains('it needs 10'));
    });

    test('riichi needs a discard to declare on and a closed hand', () {
      final s = Scenario();
      fill(s, s.hand, '1m 234m 567m 99s 78p 33p W');
      s.seats[1].riichi = true;
      expect(s.problems().any((p) => p.contains('no discards')), isTrue);

      fill(s, s.seats[1].pond, '9p');
      s.seats[1].riichiPondIndex = 0;
      expect(s.problems(), isEmpty);

      s.seats[1].melds.add(
          Meld(kind: MeldKind.triplet, low: TileType.chun, concealed: false));
      expect(s.problems().any((p) => p.contains('open call')), isTrue);
    });
  });

  group('genbutsu on a posed table', () {
    test('only discards later in turn order than the declaration count', () {
      final s = Scenario();
      s.dealer = 0;
      // Grant (seat 1) discards three tiles and riichis on the last one.
      fill(s, s.seats[1].pond, '1m 2m 3m');
      s.seats[1].riichi = true;
      s.seats[1].riichiPondIndex = 2;
      // You (seat 0) discard four; only those after Grant's 3rd turn passed.
      fill(s, s.seats[0].pond, '1p 2p 3p 4p');

      // Grant's 3rd discard is turn 2*4+1 = 9. Your discards are turns 0,4,8,12.
      expect(s.turnOf(1, 2), 9);
      expect(s.turnOf(0, 3), 12);
      final passed = s.passedAfterRiichi(1);
      expect(passed, contains(TileType.pin4));
      expect(passed, isNot(contains(TileType.pin3)));
      expect(passed, isNot(contains(TileType.pin1)));
    });

    test('the guide reads their pond plus what passed as genbutsu', () {
      final c = ScenarioController();
      c.edit((s) {
        fill(s, s.hand, '1m 234m 567m 99s 78p 33p W');
        s.dora
          ..clear()
          ..add(TileType.pei);
        fill(s, s.seats[1].pond, '9p W');
        s.seats[1].riichi = true;
        s.seats[1].riichiPondIndex = 1;
      });
      expect(c.blockedReason, isNull);
      expect(c.safetyOpponentSeat, 1);
      expect(c.report.defending, isTrue);
      final byType = {for (final r in c.report.defense) r.type: r};
      expect(byType[TileType.shaa]?.isSafe, isTrue,
          reason: 'W is in Grant\'s own pond');
      expect(byType[TileType.man1]?.isSafe, isFalse);
    });
  });

  group('what the guide is asked', () {
    test('14 tiles gets a discard recommendation', () {
      final c = ScenarioController();
      c.edit((s) {
        fill(s, s.hand, '1m 234m 567m 99s 78p 33p W');
        s.dora
          ..clear()
          ..add(TileType.pei);
      });
      expect(c.blockedReason, isNull);
      expect(c.report.lines, isNotEmpty);
      expect(c.report.lines.any((l) => l.recommended), isTrue);
      expect(c.awaitingHumanCall, isFalse);
    });

    test('13 tiles plus a tile on offer gets a call recommendation', () {
      final c = ScenarioController();
      c.edit((s) {
        fill(s, s.hand, '1m 234m 567m 99s 78p WW');
        s.dora
          ..clear()
          ..add(TileType.pei);
        s.offered = s.mint(TileType.shaa);
        s.offeredFrom = 2;
      });
      expect(c.blockedReason, isNull);
      expect(c.awaitingHumanCall, isTrue);
      expect(c.humanCallOption!.types, contains(CallType.pon));
      expect(c.recommendedCall, isNotNull);
      expect(c.recommendedCallReason, isNotEmpty);
    });

    test('13 tiles with nothing on offer asks for the tile', () {
      final c = ScenarioController();
      c.edit((s) {
        fill(s, s.hand, '1m 234m 567m 99s 78p WW');
        s.dora
          ..clear()
          ..add(TileType.pei);
      });
      expect(c.blockedReason, contains('tile an opponent just discarded'));
    });

    test('an uncallable offer says so rather than scoring nothing', () {
      final c = ScenarioController();
      c.edit((s) {
        fill(s, s.hand, '1m 234m 567m 99s 78p 3p W');
        s.dora
          ..clear()
          ..add(TileType.pei);
        s.offered = s.mint(TileType.chun);
        s.offeredFrom = 2;
      });
      expect(c.blockedReason, contains('cannot call'));
    });
  });

  group('your seat wind', () {
    test('setting it moves the dealer button, and East is the dealer', () {
      final s = Scenario();
      expect(s.seatWind, Wind.east, reason: 'you start as dealer');
      expect(s.isDealer, isTrue);
      expect(s.dealer, kHumanSeat);

      for (final wind in [Wind.south, Wind.west, Wind.north, Wind.east]) {
        s.seatWind = wind;
        expect(s.seatWind, wind, reason: 'round-trips through the dealer seat');
        expect(s.isDealer, wind == Wind.east);
      }
    });

    test('the table and the guide both see it', () {
      final c = ScenarioController();
      c.edit((s) {
        fill(s, s.hand, '1m 234m 567m 99s 78p 33p W');
        s.dora
          ..clear()
          ..add(TileType.pei);
        s.seatWind = Wind.south;
      });
      expect(c.round.seats[kHumanSeat].wind, Wind.south);
      expect(c.round.seats[kHumanSeat].isDealer, isFalse);
      final asSouth = c.report.lines.firstWhere((l) => l.recommended);

      c.edit((s) => s.seatWind = Wind.east);
      expect(c.round.seats[kHumanSeat].wind, Wind.east);
      expect(c.round.seats[kHumanSeat].isDealer, isTrue);
      final asDealer = c.report.lines.firstWhere((l) => l.recommended);

      // Dealer hands pay half again, so the same tiles are worth more.
      expect(asDealer.averagePoints, greaterThan(asSouth.averagePoints));
      expect(asDealer.expectedValue, greaterThan(asSouth.expectedValue));
    });

    testWidgets('the builder exposes it', (tester) async {
      await tester.binding.setSurfaceSize(kDesignSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const TileSenseApp());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('openBuilder')));
      await pumpLoadedPage(tester);

      // The starting wind is random; set it to East, which deals, from the
      // Menu, whose East segment carries the dealer's star.
      ScenarioController builder() =>
          tester.widget<TableView>(find.byType(TableView)).game
              as ScenarioController;
      await tapBuilderMenu(tester, 'builderMenuSeatWind_east');
      expect(builder().round.seats[kHumanSeat].isDealer, isTrue);
      await tapBuilderMenu(tester, 'builderMenuSeatWind_south');
      expect(builder().scenario.seatWind, Wind.south);
      expect(builder().round.seats[kHumanSeat].isDealer, isFalse);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });

  group('minimum points', () {
    test('the posed round carries the minimum, and Clear keeps it', () {
      final c = ScenarioController()..setRuleset(Ruleset.hongKong);
      c.edit((s) => s.minimumFaan = 3);
      expect(c.round.minimumFaan, 3);
      c.setRuleset(Ruleset.taiwanese);
      c.edit((s) => s.minimumPoints = 1);
      expect(c.round.minimumPoints, 1);
      c.edit((s) => s.clear());
      expect(c.scenario.minimumFaan, 3);
      expect(c.scenario.minimumPoints, 1);
    });

    testWidgets('the Menu offers each rule\'s own minimum', (tester) async {
      await tester.binding.setSurfaceSize(kDesignSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const TileSenseApp());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('openBuilder')));
      await pumpLoadedPage(tester);
      ScenarioController builder() =>
          tester.widget<TableView>(find.byType(TableView)).game
              as ScenarioController;

      await tapBuilderMenu(tester, 'builderMenuRuleset_hongKong');
      await tapBuilderMenu(tester, 'builderMenuMinFaan_2');
      expect(builder().round.minimumFaan, 2);

      await tapBuilderMenu(tester, 'builderMenuRuleset_taiwanese');
      await tapBuilderMenu(tester, 'builderMenuMinTai_3');
      expect(builder().round.minimumPoints, 3);

      // Riichi has no minimum to pick.
      await tapBuilderMenu(tester, 'builderMenuRuleset_riichi');
      await tester.tap(find.byKey(const Key('phoneMenu')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Min '), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });

  group('the builder screen', () {
    testWidgets('opens from the welcome screen and scores a random table',
        (tester) async {
      await tester.binding.setSurfaceSize(kDesignSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const TileSenseApp());
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('openBuilder')));
      await pumpLoadedPage(tester);
      expect(find.byType(ScenarioPage), findsOneWidget);
      // The guide is always on here, and the table is the real one.
      expect(find.byType(EfficiencyOverlay), findsOneWidget);
      expect(find.byType(TableView), findsOneWidget);
      // No live-game controls.
      expect(find.textContaining('Auto-Play'), findsNothing);
      expect(find.byTooltip('Pause'), findsNothing);
      // No pause key here, so the GUIDE legend doesn't advertise one.
      final guideTip = find.byWidgetPredicate((w) =>
          w is Tooltip &&
          (w.richMessage?.toPlainText().startsWith('GUIDE\n') ?? false));
      expect(guideTip, findsOneWidget);
      expect(
          (tester.widget<Tooltip>(guideTip).richMessage as TextSpan)
              .toPlainText(),
          isNot(contains('Esc')));

      await tapBuilderMenu(tester, 'builderMenuRandom');
      expect(find.textContaining('Scored:'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets(
        'the across seat is centred up in the bar, and the setup is in the '
        'Menu, as on a phone', (tester) async {
      await tester.binding.setSurfaceSize(kDesignSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const TileSenseApp());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('openBuilder')));
      await pumpLoadedPage(tester);

      final bar = find.byType(AppBar);
      final seat = find.byKey(const Key('acrossSeat'));
      expect(find.descendant(of: bar, matching: seat), findsOneWidget);
      final table = tester.getRect(find.byType(TableView));
      expect((tester.getRect(seat).center.dx - table.center.dx).abs(),
          lessThan(4));
      // Just the placard: the builder draws no portrait.
      expect(tester.getSize(seat).height, greaterThanOrEqualTo(28),
          reason: 'drawn at full size, not squeezed by the bar');

      expect(find.byTooltip('Back to start'), findsNothing);
      expect(tester.getRect(find.byKey(const Key('phoneMenu'))).top,
          greaterThan(table.bottom),
          reason: 'the Menu is in the editor band');
      await tapBuilderMenu(tester, 'builderMenuRandom');
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
      await pumpLoadedPage(tester);
      await tapBuilderMenu(tester, 'builderMenuRandom');

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
      await tapBuilderMenu(tester, 'builderMenuBack');
      expect(find.text('Single Player'), findsOneWidget);
      expect(find.byType(ScenarioPage), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });

  group('the builder on a landscape iPhone', () {
    const iPhone = Size(852, 393);

    Future<void> openBuilder(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(iPhone);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const TileSenseApp());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.ensureVisible(find.byKey(const Key('openBuilder')));
      await tester.tap(find.byKey(const Key('openBuilder')));
      await pumpLoadedPage(tester);
    }

    Future<void> tapInSheet(WidgetTester tester, String key) async {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.tap(find.byKey(Key(key)));
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('one Menu button under the right thumb replaces the tool bar',
        (tester) async {
      await openBuilder(tester);
      expect(find.byKey(const Key('seatWind')), findsNothing);
      expect(find.byKey(const Key('builderRuleset_riichi')), findsNothing);
      expect(find.byTooltip('Back to start'), findsNothing);

      final menu = tester.getRect(find.byKey(const Key('phoneMenu')));
      expect(menu.width, greaterThanOrEqualTo(44));
      expect(menu.height, greaterThanOrEqualTo(44));
      expect(iPhone.width - menu.right, greaterThanOrEqualTo(16),
          reason: 'clear of the right edge, which a raised case covers');
      expect(menu.top, greaterThan(iPhone.height / 2),
          reason: 'within reach of a thumb');
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('the across seat sits up in the bar, as in the game',
        (tester) async {
      await openBuilder(tester);
      final seat = find.byKey(const Key('acrossSeat'));
      expect(find.descendant(of: find.byType(AppBar), matching: seat),
          findsOneWidget);
      expect(find.byKey(const Key('acrossHand')), findsOneWidget);
      final table = tester.getRect(find.byType(TableView));
      expect((tester.getRect(seat).center.dx - table.center.dx).abs(),
          lessThan(4),
          reason: 'centred over the table, over the across pond');
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('the editor band\'s tiles and chips are big enough to tap',
        (tester) async {
      await openBuilder(tester);
      await tester.tap(find.byKey(const Key('phoneMenu')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const Key('builderMenuRandom')));
      await tester.pump(const Duration(milliseconds: 500));

      Size chip(Finder label) => tester.getSize(
          find.ancestor(of: label, matching: find.byType(InkWell)).first);

      final palette = find.byWidgetPredicate((w) =>
          w is TileFace &&
          w.tile == null &&
          w.type == typeFrom34(0) &&
          w.size == TileSize.normal);
      final tile = tester.getSize(palette.first);
      expect(tile.width, greaterThanOrEqualTo(29));
      expect(tile.height, greaterThanOrEqualTo(39.5));

      for (final label in [
        find.textContaining('Your hand ('),
        find.text('Red 5'),
        find.textContaining('pond (').first,
      ]) {
        expect(chip(label).height, greaterThanOrEqualTo(44));
        expect(chip(label).width, greaterThanOrEqualTo(44));
      }

      // Every ruleset's table still fits above the taller band — the
      // Taiwanese side hands run longest.
      for (final r in Ruleset.values) {
        (tester.widget<TableView>(find.byType(TableView)).game
                as ScenarioController)
            .setRuleset(r);
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull, reason: r.name);
      }
      await tester.tap(find.byKey(const Key('phoneMenu')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const Key('builderMenuRuleset_riichi')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('builderMenuRandom')));
      await tester.pump(const Duration(milliseconds: 500));

      // The calls slot's chi/pon/kan picker.
      await tester.tap(find.textContaining('calls (').first);
      await tester.pump(const Duration(milliseconds: 100));
      expect(chip(find.text(Ruleset.riichi.ponLabel)).height,
          greaterThanOrEqualTo(44));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('the Menu sheet sets up the table at full size',
        (tester) async {
      await openBuilder(tester);
      final page = tester.state(find.byType(ScenarioPage));
      Scenario scenario() =>
          (tester.widget<TableView>(find.byType(TableView)).game
                  as ScenarioController)
              .scenario;

      await tester.tap(find.byKey(const Key('phoneMenu')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      for (final key in [
        'builderMenuRandom',
        'builderMenuBack',
        'builderMenuWall_plus',
      ]) {
        expect(tester.getSize(find.byKey(Key(key))).height,
            greaterThanOrEqualTo(48),
            reason: key);
      }

      await tapInSheet(tester, 'builderMenuRuleset_riichi');
      expect(scenario().ruleset, Ruleset.riichi);
      await tapInSheet(tester, 'builderMenuSeatWind_east');
      expect(scenario().seatWind, Wind.east);
      await tapInSheet(tester, 'builderMenuRoundWind_south');
      expect(scenario().roundWind, Wind.south);
      final honba = scenario().honba;
      await tapInSheet(tester, 'builderMenuHonba_plus');
      expect(scenario().honba, honba + 1);

      // Hong Kong has no honba or riichi sticks.
      await tapInSheet(tester, 'builderMenuRuleset_hongKong');
      expect(scenario().ruleset, Ruleset.hongKong);
      expect(find.byKey(const Key('builderMenuHonba_plus')), findsNothing);
      expect(find.byKey(const Key('builderMenuSticks_plus')), findsNothing);

      // Random closes the sheet onto the table it just posed.
      await tapInSheet(tester, 'builderMenuRandom');
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('builderMenuDone')), findsNothing);
      expect(find.textContaining('Scored:'), findsOneWidget);
      expect(page.mounted, isTrue);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}
