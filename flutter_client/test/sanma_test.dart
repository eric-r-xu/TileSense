// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/mahjong_core.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/online_game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/logic/auto_dials.dart';
import 'package:tilesense/logic/efficiency_engine.dart';
import 'package:tilesense/logic/quiz_rules.dart';
import 'package:tilesense/ui/daily_quiz_page.dart';
import 'package:tilesense/logic/daily_quiz.dart' show QuizPuzzle;
import 'package:tilesense/main.dart';
import 'package:tilesense/scenario/scenario.dart';
import 'package:tilesense/ui/character_select_page.dart';
import 'package:tilesense/ui/ruleset_flag.dart';
import 'package:tilesense/ui/table_view.dart';

import 'helpers.dart';
import 'l10n_helpers.dart';
import 'loading_helpers.dart';

/// Sanma, three-player riichi, through the app: a game of three, kita, the
/// empty seat across, the flag and its tooltips, the builder and online
/// seating.
void main() {
  preloadDeferredPages();

  setUp(() => Sfx.i.enabled = false);
  tearDown(() => Sfx.i.enabled = true);

  group('a game', () {
    test('Auto-Play finishes an East-only game of three', () {
      final results = <RoundResult>[];
      var kita = 0;
      fakeAsync((fa) {
        final game = GameController(
            seed: 3, ruleset: Ruleset.sanma, hanchan: false)
          ..setAutoplay(true);
        expect(game.tablePoints, [35000, 35000, 0, 35000]);
        for (var guard = 0; game.phase != GamePhase.gameEnd; guard++) {
          if (guard > 400000) fail('never finished');
          expect(game.round.turn, isNot(2));
          if (game.phase == GamePhase.roundEnd) {
            final r = game.round.result!;
            expect(r.pointDeltas[2] ?? 0, 0);
            expect(game.round.seats[2].hand, isEmpty);
            kita += [for (final s in game.round.seats) s.kita.length]
                .fold(0, (a, b) => a + b);
            results.add(r);
            game.continueFromRoundEnd();
            expect(game.round.dealer, isNot(2));
            continue;
          }
          fa.elapse(const Duration(milliseconds: 1104));
        }
        expect(game.tablePoints[2], 0);
        game.dispose();
      });
      // Three hands a wind, one per player: renchan can add more.
      expect(results.length, greaterThanOrEqualTo(3));
      expect(kita, greaterThan(0), reason: 'Norths are set aside as kita');
    });

    test('your Kita sets a North aside and draws again; undo takes it back',
        () {
      for (var seed = 1; seed < 200; seed++) {
        final game = GameController(seed: seed, ruleset: Ruleset.sanma);
        if (!game.humanCanKita) {
          game.dispose();
          continue;
        }
        final me = game.round.seats[kHumanSeat];
        final norths = me.hand.where((t) => t.type == TileType.pei).length;
        game.humanKita();
        expect(me.kita, hasLength(1));
        expect(me.hand.where((t) => t.type == TileType.pei).length,
            norths - 1 + (me.drawn?.type == TileType.pei ? 1 : 0));
        expect(me.hand, hasLength(14), reason: 'the replacement is drawn');
        expect(game.canUndo, isTrue);
        game.undo();
        expect(game.round.seats[kHumanSeat].kita, isEmpty);
        game.dispose();
        return;
      }
      fail('no seed dealt you a North');
    });

    test('the dealer passes round three seats, and a North seat is never '
        'yours', () {
      final game = GameController(seed: 1, ruleset: Ruleset.sanma)
        ..setStartingDealer(2);
      addTearDown(game.dispose);
      // Seat 2 is empty under sanma: the next player deals.
      expect(game.round.dealer, 3);
      expect(game.humanStartingWind, Wind.south);
      expect(game.round.seats.map((s) => s.wind).toSet(),
          containsAll([Wind.east, Wind.south, Wind.west]));
      final rot = GameController.rotateAfterRound(
          exhaustiveDraw: false,
          dealerKept: false,
          dealer: 1,
          roundNumber: 1,
          honba: 0,
          ruleset: Ruleset.sanma);
      expect(rot.dealer, 3);
    });

    test('plays riichi\'s early dials for points throughout', () {
      for (final hands in [6, 2, 1]) {
        final d = autoDials(Ruleset.sanma, minimumPoints: 0, handsLeft: hands);
        expect(d.style, PlayStyle.aggressive);
        expect(d.strategy, Strategy.points);
      }
    });
  });

  group('the guide', () {
    test('counts no 2-8 man as left to draw', () {
      final visible = List<int>.filled(34, 0);
      SanmaRules.countRemovedTiles(visible);
      final report = EfficiencyEngine().analyze(
        hand: parseTiles('19m 123p 456p 789p 11s 2s'),
        visibleCounts34: visible,
        canRiichi: true,
        valueContext: const EfficiencyValueContext(
          melds: [],
          roundWind: Wind.east,
          seatWind: Wind.south,
          isDealer: false,
          inRiichi: false,
          wallTilesRemaining: 50,
          doraIndicators: [TileType.man1],
          ruleset: Ruleset.sanma,
        ),
      );
      for (final line in report.lines) {
        expect(
            line.accepts.where((t) => t.isMan && t.number > 1 && t.number < 9),
            isEmpty,
            reason: 'cutting ${line.discard.code}');
      }
    });
  });

  group('the flag', () {
    test('the PNG ships and only sanma and Sichuan use an image', () {
      expect(File('assets/flags/sanma.png').existsSync(), isTrue);
      expect(Ruleset.values.where((r) => r.flagAsset != null).toSet(),
          {Ruleset.sanma, Ruleset.sichuan});
    });

    testWidgets('says it is three-player mahjong on hover', (tester) async {
      await pumpLocalized(tester, const Center(child: RulesetFlag(Ruleset.sanma)));
      expect(find.byKey(const Key('rulesetFlag_sanma')), findsOneWidget);
      final tip =
          tester.widget<Tooltip>(find.byKey(const Key('sanmaFlagTooltip')));
      expect(tip.message, contains('3-player'));
      // Inside a tooltip of its own it stays quiet.
      await pumpLocalized(tester,
          const Center(child: RulesetFlag(Ruleset.sanma, tooltip: false)));
      expect(find.byKey(const Key('sanmaFlagTooltip')), findsNothing);
    });
  });

  group('the builder', () {
    test('has no 2-8 man, no seat across, and takes kita', () {
      final s = Scenario()
        ..ruleset = Ruleset.sanma
        ..clear();
      expect(s.remainingCopies(TileType.man5), 0);
      // One 1m is the default dora indicator.
      expect(s.remainingCopies(TileType.man1), 3);
      expect(s.remainingCopies(TileType.man9), 4);
      expect(s.points, [35000, 35000, 0, 35000]);
      expect(s.maxWall, 55);
      s.seats[1].kita.add(s.mint(TileType.pei));
      expect(s.remainingCopies(TileType.pei), 3);
      s.seats[2].pond.add(s.mint(TileType.pin1));
      expect(s.problems(), contains(contains('Nobody sits across')));
      s.seats[2].pond.clear();
      s.hand.add(s.mint(TileType.man5));
      expect(s.problems(), contains(contains('2–8 man')));
    });

    test('a seat wind of North leaves you West: there is no North seat', () {
      final s = Scenario()
        ..ruleset = Ruleset.sanma
        ..clear();
      s.seatWind = Wind.west;
      expect(s.seatWind, Wind.west);
      s.seatWind = Wind.north;
      expect(s.seatWind, Wind.west);
    });
  });

  group('online', () {
    final seats = [
      for (final (seat, name) in [(0, 'Ann'), (1, 'Bo'), (3, 'Cy')])
        LobbySeat(
          seat: seat,
          name: name,
          character: Character.eric,
          isBot: false,
          isHost: seat == 0,
          connected: true,
        ),
      const LobbySeat(
        seat: 2,
        name: null,
        character: null,
        isBot: false,
        isHost: false,
        connected: false,
        inactive: true,
      ),
    ];

    test('the player after you is on your right, the one before on your left',
        () {
      String label(int mySeat, int local) => OnlineGameController
          .labelForLocalSeat(seats, mySeat, local, ruleset: Ruleset.sanma);
      expect(label(1, 0), contains('Bo'));
      expect(label(1, 1), 'Cy');
      expect(label(1, 3), 'Ann');
      expect(label(1, 2), contains('three'));
      expect(
          OnlineGameController.localTablePoints(
              [30000, 40000, 0, 35000], 1,
              ruleset: Ruleset.sanma),
          [40000, 35000, 0, 30000]);
    });
  });

  group('the daily quiz', () {
    test('sanma has none; every other ruleset does', () {
      expect(hasDailyQuiz(Ruleset.sanma), isFalse);
      for (final r in Ruleset.values.where((r) => !r.isSanma)) {
        expect(hasDailyQuiz(r), isTrue, reason: r.name);
      }
    });

    testWidgets('the quiz screen poses no riichi puzzle under sanma',
        (tester) async {
      final file = jsonDecode(File('assets/quiz/daily.json').readAsStringSync())
          as Map<String, Object?>;
      final riichi = QuizPuzzle.fromJson(
          (file['puzzles']! as List).first as Map<String, Object?>);
      await pumpLocalized(
          tester,
          DailyQuizScreen(
              onExit: () {},
              ruleset: Ruleset.sanma,
              puzzles: Future.value([riichi])),
          size: kDesignSize);
      await tester.pump();
      expect(find.byKey(const Key('quizUnavailable')), findsOneWidget);
      expect(find.byKey(const Key('quizQuestion')), findsNothing);
    });

    testWidgets('the Learn tile and popup say there is no quiz for sanma',
        (tester) async {
      await tester.binding.setSurfaceSize(kDesignSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const TileSenseApp());
      await tester.pump(const Duration(milliseconds: 100));
      await tapInPopup(tester, 'rulesTile', find.byKey(const Key('ruleset_sanma')));
      expect(
          find.descendant(
              of: find.byKey(const Key('learnTile')),
              matching: find.text('No daily quiz for Sanma')),
          findsOneWidget);
      await openPopup(tester, 'learnTile');
      expect(find.byKey(const Key('dailyQuizUnavailable')), findsOneWidget);
      expect(find.byKey(const Key('dailyQuizCard')), findsNothing);
      await closePopup(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });

  group('the app', () {
    testWidgets('choosing sanma seats three, with nobody across',
        (tester) async {
      await tester.binding.setSurfaceSize(kDesignSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const TileSenseApp());
      await tester.pump(const Duration(milliseconds: 100));
      await openPopup(tester, 'rulesTile');
      expect(find.byKey(const Key('ruleset_sanma')), findsOneWidget);
      expect(find.byKey(const Key('rulesetFlag_sanma')), findsWidgets);
      expect(find.text('3-player riichi: no chi, kita, no 2–8 man'),
          findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('ruleset_sanma')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('ruleset_sanma')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Single Player'));
      await tester.pump();

      // Three seat cards, and no North to start on.
      expect(find.byKey(const Key('seatCard_2')), findsNothing);
      expect(find.byKey(const Key('seatCard_1')), findsOneWidget);
      expect(find.byKey(const Key('startWind_north')), findsNothing);
      expect(find.byKey(const Key('startWind_west')), findsOneWidget);
      expect(seatStartingWind(3, 0, ruleset: Ruleset.sanma), Wind.west);

      await tester.tap(find.byKey(const Key('charactersContinue')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      final game = (tester.widget(find.byType(TableView).first) as TableView)
          .game as GameController;
      expect(game.ruleset, Ruleset.sanma);
      expect(find.byKey(const Key('emptyAcrossSeat')), findsWidgets);
      expect(find.text('DORA'), findsWidgets);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}
