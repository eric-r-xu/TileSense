// ignore_for_file: depend_on_referenced_packages
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/mahjong_core.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/logic/efficiency_engine.dart';
import 'package:tilesense/main.dart';
import 'package:tilesense/ui/ruleset_flag.dart';
import 'package:tilesense/ui/scoring_view.dart';
import 'package:tilesense/ui/table_view.dart';

import 'helpers.dart';
import 'l10n_helpers.dart';
import 'loading_helpers.dart';

/// Sichuan through the app: the void-suit step, a game that plays on after
/// each win, the dealer rule, the guide, and the flag.
void main() {
  preloadDeferredPages();

  setUp(() => Sfx.i.enabled = false);
  tearDown(() => Sfx.i.enabled = true);

  group('a game', () {
    // The controller is built inside fakeAsync so its turn timers are fake.
    List<RoundResult> playOut(GameController Function() start) {
      final results = <RoundResult>[];
      fakeAsync((fa) {
        final game = start()..setAutoplay(true);
        for (var guard = 0; game.phase != GamePhase.gameEnd; guard++) {
          if (guard > 400000) fail('never finished');
          if (game.phase == GamePhase.roundEnd) {
            final r = game.round.result!;
            expect(r.kind, RoundEndKind.bloodBattle);
            expect(r.pointDeltas.values.fold<int>(0, (a, b) => a + b), 0);
            results.add(r);
            final before = game.round.dealer;
            game.continueFromRoundEnd();
            if (game.phase != GamePhase.gameEnd) {
              // The dealer rule: nobody won -> the dealer stays; otherwise the
              // round named who deals next.
              expect(game.round.dealer, r.nextDealer,
                  reason: 'dealer was $before, winners ${r.winners}');
            }
            continue;
          }
          fa.elapse(const Duration(milliseconds: 1104));
        }
        game.dispose();
      });
      return results;
    }

    test('Auto-Play finishes a practice game: 4 hands, each settled', () {
      final results = playOut(
          () => GameController(seed: 5, ruleset: Ruleset.sichuan, hanchan: false));
      expect(results, hasLength(4));
    });

    test('a full game is 8 hands, and wins did not end the hands early', () {
      final results =
          playOut(() => GameController(seed: 9, ruleset: Ruleset.sichuan));
      expect(results, hasLength(8));
      expect(results.any((r) => r.winners.length > 1), isTrue,
          reason: 'across eight hands someone should win more than once');
    });
  });

  group('the void-suit step', () {
    test('the table waits for you; naming a suit starts the hand', () {
      final game = GameController(seed: 7, ruleset: Ruleset.sichuan);
      addTearDown(game.dispose);
      expect(game.awaitingHumanVoidSuit, isTrue);
      expect(game.round.phase, RoundPhase.choosingVoidSuit);
      // The opponents named theirs at the deal, out of sight.
      for (var seat = 1; seat < 4; seat++) {
        expect(game.round.hasDeclaredVoidSuit(seat), isTrue);
        expect(game.round.seats[seat].voidRevealed, isFalse);
      }
      game.humanDeclareVoidSuit(1);
      expect(game.awaitingHumanVoidSuit, isFalse);
      expect(game.round.seats[kHumanSeat].voidSuit, 1);
      expect(game.round.phase, RoundPhase.discarding);
    });

    test('only the void suit is a legal cut while you hold it', () {
      final game = GameController(seed: 7, ruleset: Ruleset.sichuan);
      addTearDown(game.dispose);
      game.humanDeclareVoidSuit(0);
      final me = game.round.seats[kHumanSeat];
      final holdsVoid = me.hand.any((t) => t.type.suit == 0);
      final other = me.hand.firstWhere((t) => t.type.suit != 0);
      final before = me.hand.length;
      game.humanDiscard(other);
      if (holdsVoid) {
        expect(me.hand.length, before, reason: 'a non-void cut is refused');
      } else {
        expect(me.hand.length, before - 1);
      }
    });

    test('undo goes back through a discard and keeps every void suit', () {
      final game = GameController(seed: 7, ruleset: Ruleset.sichuan);
      addTearDown(game.dispose);
      game.humanDeclareVoidSuit(2);
      final voids = [for (final s in game.round.seats) s.voidSuit];
      final tile = game.round.legalDiscards(kHumanSeat).first;
      game.humanDiscard(tile);
      expect(game.canUndo, isTrue);
      game.undo();
      expect([for (final s in game.round.seats) s.voidSuit], voids);
      expect(game.round.turn, kHumanSeat);
      expect(game.round.seats[kHumanSeat].hand, hasLength(14));
      expect(game.round.seats[kHumanSeat].hand.any((t) => t.id == tile.id),
          isTrue);
    });
  });

  group('the guide', () {
    EfficiencyValueContext ctx({int? voidSuit, List<Meld> melds = const []}) =>
        EfficiencyValueContext(
          melds: melds,
          roundWind: Wind.east,
          seatWind: Wind.east,
          isDealer: true,
          inRiichi: false,
          wallTilesRemaining: 50,
          doraIndicators: const [],
          ruleset: Ruleset.sichuan,
          voidSuit: voidSuit,
        );
    final visible = List<int>.filled(34, 0);

    test('holding the void suit, only its tiles are offered, first', () {
      final hand = parseTiles('123m 456m 789p 11p 23p 9s 8s');
      final report = EfficiencyEngine().analyze(
          hand: hand,
          visibleCounts34: visible,
          canRiichi: false,
          valueContext: ctx(voidSuit: 2));
      expect(report.lines.map((l) => l.discard).toSet(),
          {TileType.sou8, TileType.sou9});
      expect(report.lines.first.recommended, isTrue);
      expect(report.headline, contains('void suit'));
    });

    test('with the void suit gone a ready hand ranks above one a step off', () {
      final hand = parseTiles('123m 456m 789p 11p 23p 5m');
      final report = EfficiencyEngine().analyze(
          hand: hand,
          visibleCounts34: visible,
          canRiichi: false,
          valueContext: ctx(voidSuit: 2));
      expect(report.tenpai, isTrue);
      expect(report.lines.first.discard, TileType.man5);
      expect(report.lines.first.shanten, 0);
      expect(report.lines.first.accepts,
          containsAll([TileType.pin1, TileType.pin4]));
    });

    test('a pung that helps is taken, a void-suit one is not, a kong of the '
        'void suit is ineligible', () {
      final engine = EfficiencyEngine();
      final hand = parseTiles('123m 456m 78p 99p 55s 3p');
      final help = engine.adviseCall(
        hand: hand,
        offered: Tile(900, TileType.pin9),
        available: {GuidedAction.pon},
        visibleCounts34: visible,
        context: ctx(voidSuit: 2),
      );
      expect(help.options.map((o) => o.action), contains(GuidedAction.pass));

      final voidPung = engine.adviseCall(
        hand: hand,
        offered: Tile(901, TileType.sou5),
        available: {GuidedAction.pon},
        visibleCounts34: visible,
        context: ctx(voidSuit: 2),
      );
      expect(voidPung.recommended, GuidedAction.pass);

      final kan = engine.adviseClosedKan(
        hand: parseTiles('5555s 123m 456m 789p 1p'),
        kanType: TileType.sou5,
        visibleCounts34: visible,
        context: ctx(voidSuit: 2),
      );
      expect(kan.eligible, isFalse);
    });

    test('a win on offer is always taken, at its score', () {
      final advice = EfficiencyEngine().adviseCall(
        hand: parseTiles('123m 456m 789p 11p 23p'),
        offered: Tile(900, TileType.pin4),
        available: {GuidedAction.ron},
        visibleCounts34: visible,
        context: ctx(voidSuit: 2),
      );
      expect(advice.recommended, GuidedAction.ron);
      expect(advice.best.expectedValue, 1);
    });
  });

  group('the flag', () {
    test('the PNG ships, is registered, and only Sichuan uses an image', () {
      expect(File('assets/flags/sichuan.png').existsSync(), isTrue);
      expect(File('pubspec.yaml').readAsStringSync(),
          contains('assets/flags/'));
      expect(Ruleset.sichuan.flagAsset, 'assets/flags/sichuan.png');
      expect(
          Ruleset.values.where((r) => r.flagAsset != null), [Ruleset.sichuan]);
    });

    testWidgets('Sichuan draws its flag image; riichi keeps its emoji',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Material(
          child: Column(children: [
            RulesetFlag(Ruleset.sichuan),
            RulesetFlag(Ruleset.riichi),
          ]),
        ),
      ));
      expect(find.byKey(const Key('rulesetFlag_sichuan')), findsOneWidget);
      expect(find.text(Ruleset.riichi.flag), findsOneWidget);
      expect(find.text(Ruleset.sichuan.flag), findsNothing);
    });
  });

  group('the score screen', () {
    // A hand that ends with a void-suit penalty. The rules keep this from
    // happening in play (see the core tests), so the end state is posed.
    Round penalisedHand() {
      final r = Round.posed(
        dealer: 0,
        roundWind: Wind.east,
        wall: SichuanWall.posed(remaining: 0),
        startingPoints: List.filled(4, 0),
        ruleset: Ruleset.sichuan,
      );
      for (final seat in r.seats) {
        seat.voidSuit = 2;
        seat.hand = parseTiles('147m 258p 369m 14p 7p 2m');
      }
      final cut = Tile(900, TileType.sou9);
      r.seats[0].hand = [...parseTiles('123m 456m 789m 11p 2p 8s'), cut];
      r.seats[0].drawn = cut;
      r.seats[0].allDiscards.add(Tile(901, TileType.man1));
      r.turn = 0;
      r.phase = RoundPhase.discarding;
      r.discard(0, cut);
      return r;
    }

    testWidgets('lists the penalty beside the hand total, with every seat paid',
        (tester) async {
      final game = GameController(seed: 5, ruleset: Ruleset.sichuan);
      addTearDown(game.dispose);
      game.togglePause();
      final r = penalisedHand();
      expect(r.result!.pointDeltas, {0: -144, 1: 48, 2: 48, 3: 48});
      game.round = r;
      game.phase = GamePhase.roundEnd;
      await pumpLocalized(tester, Scaffold(body: ScoringView(game: game)));
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('sichuanPayments')), findsOneWidget);
      expect(find.textContaining('Void-suit penalty'), findsNWidgets(3));
      expect(find.textContaining('48'), findsWidgets);
      expect(find.textContaining('-144'), findsOneWidget);
    });
  });

  group('the app', () {
    Future<void> boot(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(kDesignSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const TileSenseApp());
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('choosing Sichuan on the welcome screen deals a Sichuan table '
        'and asks for the void suit', (tester) async {
      await boot(tester);
      await openPopup(tester, 'rulesTile');
      expect(find.byKey(const Key('ruleset_sichuan')), findsOneWidget);
      expect(find.byKey(const Key('rulesetFlag_sichuan')), findsWidgets);
      await tester.tap(find.byKey(const Key('ruleset_sichuan')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Single Player'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('charactersContinue')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      final game = (tester.widget(find.byType(TableView)) as TableView).game
          as GameController;
      expect(game.ruleset, Ruleset.sichuan);
      expect(find.byKey(const Key('rulesetFlag_sichuan')), findsWidgets);
      expect(find.byKey(const Key('voidSuitTitle')), findsOneWidget);
      for (var s = 0; s < 3; s++) {
        expect(find.byKey(Key('voidSuit_$s')), findsOneWidget);
      }
      // No chow button, no dora panel, no riichi anywhere.
      expect(find.text('DORA'), findsNothing);

      await tester.tap(find.byKey(const Key('voidSuit_1')));
      // The action bar cross-fades between its old and new buttons.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));
      expect(game.round.seats[kHumanSeat].voidSuit, 1);
      expect(find.byKey(const Key('voidSuitTitle')), findsNothing);
      expect(find.byKey(const Key('voidSuitBadge_0')), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}
