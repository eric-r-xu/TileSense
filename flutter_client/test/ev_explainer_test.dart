import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/tile.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/logic/efficiency_engine.dart';
import 'package:tilesense/ui/efficiency_overlay.dart';
import 'package:tilesense/ui/ev_explainer_dialog.dart';

import 'helpers.dart';

EfficiencyReport analyzeHand(
  String spec, {
  bool canRiichi = false,
  bool opponentRiichi = false,
  List<TileType> opponentDiscards = const [],
  int honba = 0,
  int riichiSticks = 0,
  int wall = 40,
}) {
  final hand = parseTiles(spec);
  expect(hand.length, 14);
  return EfficiencyEngine().analyze(
    hand: hand,
    defenseHand: opponentRiichi ? hand : null,
    visibleCounts34: toCounts34(hand),
    canRiichi: canRiichi,
    opponentRiichi: opponentRiichi,
    opponentDiscards: opponentDiscards,
    valueContext: EfficiencyValueContext(
      melds: const [],
      roundWind: Wind.east,
      seatWind: Wind.east,
      isDealer: true,
      inRiichi: false,
      wallTilesRemaining: wall,
      doraIndicators: const [],
      honba: honba,
      riichiSticks: riichiSticks,
    ),
  );
}

void main() {
  // A tenpai hand (cut the 9s), a hand a step or two out, and a scattered one
  // — so every estimator gets exercised.
  const hands = {
    'tenpai': '123m 456m 789m 34p 55p 9s',
    'one away': '123m 456m 78m 34p 55p 99s',
    'far': '1m 4m 7m 1p 4p 7p 1s 4s 7s E S W N R',
  };

  group('the series behind win probability', () {
    for (final entry in hands.entries) {
      test('${entry.key}: ends on the number in the table', () {
        final report = analyzeHand(entry.value, canRiichi: true);
        var charted = 0;
        for (final line in report.lines) {
          final b = line.winBreakdown;
          if (b == null) continue;
          charted++;
          expect(b.turns, isNotEmpty);
          expect(b.win, closeTo(line.winProbability, 1e-9),
              reason: 'cut ${line.discard.code} (${b.estimator})');
          var previous = 0.0;
          var total = 0.0;
          for (final t in b.turns) {
            expect(t.cumulative, greaterThanOrEqualTo(previous - 1e-12));
            expect(t.cumulative, lessThanOrEqualTo(1.0));
            expect(t.hit, greaterThanOrEqualTo(0));
            expect(t.alive, inInclusiveRange(0.0, 1.0));
            previous = t.cumulative;
            total += t.hit;
          }
          expect(total, closeTo(line.winProbability, 1e-9),
              reason: 'per-turn hits must add up to the total');
          expect(b.turns.first.turn, 1);
          expect(b.turns.length, b.draws);
        }
        expect(charted, greaterThan(0));
      });
    }

    test('the right estimator is named for where the hand stands', () {
      for (final spec in hands.values) {
        for (final line in analyzeHand(spec, canRiichi: true).lines) {
          final b = line.winBreakdown;
          if (b == null) continue;
          if (line.shanten == 0) {
            expect(b.estimator, WinEstimator.tenpai,
                reason: 'a ready hand is a wait, not a walk');
            expect(b.turns.first.reachedTenpai, isNull);
          } else {
            expect(b.estimator, isNot(WinEstimator.tenpai),
                reason: 'stepping out of tenpai is a walk');
            expect(b.turns.first.reachedTenpai, isNotNull);
            expect(b.shanten, greaterThan(0));
          }
        }
      }
      // The tenpai hand offers a ready cut and lines that step back from it,
      // so both kinds turn up in one report.
      final kinds = analyzeHand(hands['tenpai']!, canRiichi: true)
          .lines
          .map((l) => l.winBreakdown?.estimator)
          .toSet();
      expect(kinds, contains(WinEstimator.tenpai));
      expect(
          kinds,
          anyOf(contains(WinEstimator.shantenWalk),
              contains(WinEstimator.tenpaiLookahead)));
      expect(
          analyzeHand(hands['far']!).lines.first.winBreakdown!.estimator,
          WinEstimator.shantenWalk);
    });

    test('a shorter wall leaves fewer turns to chart', () {
      final full = analyzeHand(hands['tenpai']!, wall: 60);
      final late = analyzeHand(hands['tenpai']!, wall: 12);
      int turns(EfficiencyReport r) => r.lines
          .singleWhere((l) => l.discard == TileType.sou9)
          .winBreakdown!
          .turns
          .length;
      expect(turns(late), lessThan(turns(full)));
    });
  });

  group('the EV waterfall', () {
    void expectReconciles(DiscardLine line) {
      final steps = evWaterfall(line);
      expect(steps.first.total, isTrue);
      expect(steps.first.delta, closeTo(line.expectedValueHmr, 1e-9));
      expect(steps.last.total, isTrue);
      expect(steps.last.delta, closeTo(line.expectedValue, 1e-9));
      final running = steps.first.delta +
          steps
              .where((s) => !s.total)
              .fold<double>(0, (sum, s) => sum + s.delta);
      expect(running, closeTo(line.expectedValue, 0.5),
          reason: 'cut ${line.discard.code}: bars must land on the column');
    }

    test('every line lands on its Expected Value', () {
      for (final spec in hands.values) {
        for (final line in analyzeHand(spec, canRiichi: true).lines) {
          expectReconciles(line);
        }
      }
    });

    test('with honba, sticks and a riichi to defend against', () {
      final report = analyzeHand(
        '1m 234m 567m 99s 78p 3p W 5s',
        opponentRiichi: true,
        opponentDiscards: const [TileType.man1],
        honba: 2,
        riichiSticks: 1,
      );
      var sawRisk = false;
      var sawBonus = false;
      for (final line in report.lines) {
        expectReconciles(line);
        final labels = evWaterfall(line).map((s) => s.label);
        sawRisk |= labels.contains('deal-in risk');
        sawBonus |= labels.contains('honba + sticks');
      }
      expect(sawRisk, isTrue, reason: 'a live riichi should charge some cut');
      expect(sawBonus, isTrue);
    });

    test('a line with nothing to win is just its two totals', () {
      final line = DiscardLine(
        discard: TileType.man1,
        shanten: 3,
        ukeire: 0,
        accepts: const [],
        expectedValue: 0,
        averagePoints: 0,
        valuePlan: 'DEFENSE',
        recommendRiichi: false,
      );
      expect(evWaterfall(line).map((s) => s.label),
          ['EV (HMR)', 'TileSense EV']);
    });
  });

  group('tapping the EV (HMR) cell', () {
    /// Pumps the panel over a live [GameController], runs [body], and tears the
    /// game down before the test ends — its turn loop keeps a timer alive that
    /// the framework would otherwise flag.
    Future<void> withOverlay(
      WidgetTester tester,
      Future<void> Function(DiscardLine first) body,
    ) async {
      Sfx.i.enabled = false;
      final game = GameController(seed: 1);
      try {
        final report = analyzeHand(hands['tenpai']!, canRiichi: true);
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: EfficiencyOverlay(game: game, report: report),
            ),
          ),
        ));
        await body(report.lines.first);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        game.dispose();
        Sfx.i.enabled = true;
      }
    }

    Finder cellOf(DiscardLine line) =>
        find.byKey(ValueKey('ev-hmr-${line.discard.code}'));

    testWidgets('opens the explainer for that row, charts and all',
        (tester) async {
      await withOverlay(tester, (line) async {
        expect(find.byKey(const Key('ev-explainer')), findsNothing);

        await tester.tap(cellOf(line));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('ev-explainer')), findsOneWidget);
        expect(find.textContaining('How EV (HMR) is made'), findsOneWidget);
        expect(find.textContaining('cut ${line.discard.code}'), findsOneWidget);
        // The headline product is the same number the cell shows.
        expect(
            find.textContaining(
                '=  ${_thousands(line.expectedValueHmr.round())}'),
            findsOneWidget);
        expect(find.byKey(const Key('ev-win-chart')), findsOneWidget);
        expect(find.byKey(const Key('ev-hit-chart')), findsOneWidget);
        expect(find.byKey(const Key('ev-waterfall')), findsOneWidget);
        expect(find.text('TileSense EV'), findsWidgets);
      });
    });

    testWidgets('touching a chart reads out that turn, and Close dismisses it',
        (tester) async {
      await withOverlay(tester, (line) async {
        await tester.tap(cellOf(line));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('ev-readout')), findsNothing);
        final chart = find.byKey(const Key('ev-win-chart'));
        await tester.ensureVisible(chart);
        await tester.pumpAndSettle();
        await tester.tapAt(tester.getTopLeft(chart) + const Offset(120, 60));
        await tester.pump();
        expect(find.byKey(const Key('ev-readout')), findsOneWidget);
        expect(find.textContaining('finished by now'), findsOneWidget);

        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('ev-explainer')), findsNothing);
      });
    });

    testWidgets('fits a phone without overflowing', (tester) async {
      tester.view
        ..physicalSize = const Size(390 * 3, 700 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await withOverlay(tester, (line) async {
        await tester.tap(cellOf(line));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('ev-explainer')), findsOneWidget);
      });
    });

    testWidgets('the tooltip is still there beside the tap', (tester) async {
      await withOverlay(tester, (line) async {
        final tip =
            find.ancestor(of: cellOf(line), matching: find.byType(Tooltip));
        expect(tip, findsOneWidget);
        final text =
            (tester.widget<Tooltip>(tip).richMessage as TextSpan).toPlainText();
        expect(text, allOf(contains('EV (HMR)'), contains('THIS CUT')));
        // The chance is quoted to two decimals, and matches the engine.
        final chance = '${(line.winProbability * 100).toStringAsFixed(2)}%';
        expect(text, contains('chance of finishing      $chance'));
        expect(RegExp(r'\d+\.\d{2}%').hasMatch(text), isTrue);
      });
    });

    testWidgets('the TileSense EV tooltip shows its multiplication',
        (tester) async {
      await withOverlay(tester, (line) async {
        final tips = find.byWidgetPredicate((w) =>
            w is Tooltip &&
            (w.richMessage?.toPlainText().contains('THIS CUT') ?? false) &&
            (w.richMessage!.toPlainText().startsWith('TILESENSE EV')));
        expect(tips, findsWidgets);
        final text = tester
            .widget<Tooltip>(tips.first)
            .richMessage!
            .toPlainText();
        final chance = '${(line.winProbability * 100).toStringAsFixed(2)}%';
        expect(text, contains('so on average'));
        expect(text, contains('= $chance × '));
        // Shorter than before: the general explainer stays a screenful.
        final general = text.substring(0, text.indexOf('THIS CUT'));
        expect(general.length, lessThan(900));
      });
    });

    testWidgets('a line with no winning hand says so instead of charting',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EvExplainerDialog(
            line: DiscardLine(
              discard: TileType.man1,
              shanten: 3,
              ukeire: 0,
              accepts: const [],
              expectedValue: 0,
              averagePoints: 0,
              valuePlan: 'YAKU NEEDED',
              recommendRiichi: false,
            ),
          ),
        ),
      ));
      expect(find.textContaining('No winning hand'), findsWidgets);
      expect(find.byKey(const Key('ev-win-chart')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

String _thousands(int n) {
  final s = n.abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}
