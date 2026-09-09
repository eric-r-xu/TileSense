import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/game/game_controller.dart' show kHumanSeat;
import 'package:tilesense/logic/meld.dart';
import 'package:tilesense/logic/round.dart';
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
      s.seats[2].melds.add(Meld(
          kind: MeldKind.triplet, low: TileType.sou4, concealed: false));
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
      s.seats[0].melds.add(Meld(
          kind: MeldKind.triplet, low: TileType.pei, concealed: false));
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

      s.seats[1].melds.add(Meld(
          kind: MeldKind.triplet, low: TileType.chun, concealed: false));
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
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Seat 東 ★'), findsOneWidget, reason: 'dealer by default');
      await tester.tap(find.byKey(const Key('seatWind')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Seat 南'), findsOneWidget);
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

      final page =
          tester.widget<TableView>(find.byType(TableView)).game;
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
