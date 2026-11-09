// ignore_for_file: depend_on_referenced_packages
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/mahjong_core.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/online_game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/l10n/app_language.dart';
import 'package:tilesense/l10n/l10n.dart';
import 'package:tilesense/l10n/mahjong_terms.dart';
import 'package:tilesense/logic/efficiency_engine.dart';
import 'package:tilesense/logic/fuzhou_guide.dart';
import 'package:tilesense/main.dart';
import 'package:tilesense/scenario/scenario.dart';
import 'package:tilesense/scenario/scenario_controller.dart';
import 'package:tilesense/ui/online_lobby_page.dart';
import 'package:tilesense/ui/ruleset_flag.dart';
import 'package:tilesense/ui/scenario_page.dart';
import 'package:tilesense/ui/table_view.dart';
import 'package:tilesense/ui/tile_face.dart';

import 'helpers.dart';
import 'lobby_helpers.dart';
import 'loading_helpers.dart';

/// Fuzhou through the app: the picker, the flag, a game with a Gold, the
/// table's Gold indicator, wild tiles drawn on gold, the guide, the builder
/// and the online lobby.
void main() {
  preloadDeferredPages();

  AppLocalizations l10nFor(AppLanguage language) =>
      lookupAppLocalizations(language.locale);

  setUp(() => Sfx.i.enabled = false);
  tearDown(() => Sfx.i.enabled = true);

  Future<void> boot(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(kDesignSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('the ruleset', () {
    test('is flagged with the Fuzhou logo, which ships', () {
      expect(File('assets/flags/fuzhou.png').existsSync(), isTrue);
      expect(Ruleset.fuzhou.flagAsset, 'assets/flags/fuzhou.png');
      expect(Ruleset.fuzhou.flag, isEmpty);
      expect(File('pubspec.yaml').readAsStringSync(), contains('assets/flags/'));
    });

    testWidgets('draws its flag image, riichi keeps its emoji', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Material(
          child: Column(children: [
            RulesetFlag(Ruleset.fuzhou),
            RulesetFlag(Ruleset.riichi),
          ]),
        ),
      ));
      expect(find.byKey(const Key('rulesetFlag_fuzhou')), findsOneWidget);
      expect(find.text(Ruleset.riichi.flag), findsOneWidget);
    });

    test('is named in every language', () {
      expect(l10nFor(AppLanguage.english).rulesetName(Ruleset.fuzhou), 'Fuzhou');
      for (final language in AppLanguage.values.skip(1)) {
        expect(l10nFor(language).rulesetName(Ruleset.fuzhou), '福州',
            reason: language.name);
      }
    });

    test('names every scoring line in English and the other languages', () {
      final en = l10nFor(AppLanguage.english);
      const lines = [
        'Base Points',
        'Flower Points',
        'Full Bloom',
        'Gold Points',
        'Dealer Continuation',
        'Open Kong',
        'Concealed Kong',
        'Doubled',
        'All Sequences',
        'One Flower',
        'Golden Pair',
        'Three Gold Knockdown',
        'Golden Dragon',
        'Robbing the Gold',
        'Blessing of Heaven',
        'Blessing of Earth',
      ];
      for (final name in lines) {
        expect(en.scoringName(name, Ruleset.fuzhou), name);
        for (final language in AppLanguage.values.skip(1)) {
          expect(l10nFor(language).scoringName(name, Ruleset.fuzhou),
              isNot(name),
              reason: '${language.name} has a word for $name');
        }
      }
    });
  });

  group('the picker', () {
    testWidgets('the welcome screen offers Fuzhou and starts a Fuzhou table',
        (tester) async {
      await boot(tester);
      await tapInPopup(
          tester, 'rulesTile', find.byKey(const Key('ruleset_fuzhou')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(taglineRules('Fuzhou'), findsOneWidget);

      await tester.tap(find.text('Single Player'));
      await tester.pump();
      // The character screen lists it too, with the welcome screen's pick
      // selected.
      expect(find.byKey(const Key('startRuleset_fuzhou')), findsOneWidget);
      await tester.tap(find.byKey(const Key('charactersContinue')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      final table = tester.widget<TableView>(find.byType(TableView));
      expect(table.game.round.ruleset, Ruleset.fuzhou);
      expect(table.game.round.goldIndicator, isNotNull);
      expect(find.byKey(const Key('goldIndicator')), findsOneWidget);
      // No dora here: the Gold takes the corner.
      expect(find.text('DORA'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('the character screen can switch to Fuzhou', (tester) async {
      await boot(tester);
      await tester.tap(find.text('Single Player'));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('startRuleset_fuzhou')));
      await tester.tap(find.byKey(const Key('startRuleset_fuzhou')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('charactersContinue')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      expect(tester.widget<TableView>(find.byType(TableView)).game.round.ruleset,
          Ruleset.fuzhou);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('the online lobby offers Fuzhou, and its Rules button follows',
        (tester) async {
      final game = OnlineGameController();
      addTearDown(game.dispose);
      await tester.binding.setSurfaceSize(kDesignSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: kDesignSize.width,
            height: kDesignSize.height,
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
      await pickOnlineRuleset(tester, Ruleset.fuzhou);
      expect(onlineRulesetShown(tester), Ruleset.fuzhou);
    });
  });

  group('a game', () {
    test('deals 16 tiles, flips the Gold, and shows it to the guide', () {
      final game = GameController(seed: 11, ruleset: Ruleset.fuzhou);
      addTearDown(game.dispose);
      final round = game.round;
      expect(round.goldIndicator, isNotNull);
      expect(round.goldTypes, isNotEmpty);
      for (final s in round.seats) {
        final size = s.hand.length + s.melds.length * 3;
        expect(size, s.seat == round.turn ? 17 : 16, reason: 'seat ${s.seat}');
      }
      expect(game.playStyle, PlayStyle.balanced);
    });

    test('the dealer keeps the deal by winning, and a draw passes it', () {
      ({int dealer, int roundNumber, int honba}) after(
              {required bool draw, required bool kept, int honba = 0}) =>
          GameController.rotateAfterRound(
            exhaustiveDraw: draw,
            dealerKept: kept,
            dealer: 0,
            roundNumber: 2,
            honba: honba,
            ruleset: Ruleset.fuzhou,
          );
      // Dealer wins: stays, streak grows.
      expect(after(draw: false, kept: true, honba: 1),
          (dealer: 0, roundNumber: 2, honba: 2));
      // Someone else wins: the deal passes and the streak resets.
      expect(after(draw: false, kept: false, honba: 3),
          (dealer: 1, roundNumber: 3, honba: 0));
      // A draw passes the deal too (the controller says the dealer is not
      // kept on a Fuzhou draw).
      expect(after(draw: true, kept: false, honba: 2),
          (dealer: 1, roundNumber: 3, honba: 0));
    });

    test('Auto-Play finishes a practice game, every hand balanced', () {
      final ends = <RoundEndKind>[];
      fakeAsync((fa) {
        final game = GameController(
            seed: 5, ruleset: Ruleset.fuzhou, hanchan: false)
          ..setAutoplay(true);
        for (var guard = 0; game.phase != GamePhase.gameEnd; guard++) {
          if (guard > 400000) fail('never finished');
          if (game.phase == GamePhase.roundEnd) {
            final r = game.round.result!;
            expect(r.pointDeltas.values.fold<int>(0, (a, b) => a + b), 0);
            ends.add(r.kind);
            game.continueFromRoundEnd();
            continue;
          }
          fa.elapse(const Duration(milliseconds: 1104));
        }
        game.dispose();
      });
      expect(ends, isNotEmpty);
    });
  });

  group('wild tiles', () {
    testWidgets('are drawn on gold wherever a Gold scope covers them',
        (tester) async {
      Color? face(Finder f) {
        for (final c in tester.widgetList<Container>(f)) {
          final d = c.decoration;
          if (d is BoxDecoration && d.color != null) return d.color;
        }
        return null;
      }

      await tester.pumpWidget(MaterialApp(
        home: Material(
          child: Row(children: [
            GoldScope(
              types: {TileType.man5},
              child: Builder(
                  builder: (_) => const TileFace(
                      key: Key('wild'), type: TileType.man5)),
            ),
            GoldScope(
              types: {TileType.man5},
              child: const TileFace(key: Key('plain'), type: TileType.man6),
            ),
            const TileFace(key: Key('unscoped'), type: TileType.man5),
          ]),
        ),
      ));
      Finder faceOf(String key) => find.descendant(
          of: find.byKey(Key(key)), matching: find.byType(Container));
      final wild = face(faceOf('wild'));
      expect(wild, const Color(0xfff2d36b));
      expect(face(faceOf('plain')), isNot(wild));
      expect(face(faceOf('unscoped')), isNot(wild));
    });

    testWidgets('the table shows the Gold indicator face up', (tester) async {
      await tester.binding.setSurfaceSize(kDesignSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final game = GameController(seed: 11, ruleset: Ruleset.fuzhou);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: TableView(game: game)),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('goldIndicator')), findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const Key('goldIndicator')),
              matching: find.byType(TileFace)),
          findsOneWidget);
      expect(find.text('Gold'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      game.dispose();
      await tester.pump();
    });
  });

  group('the guide', () {
    EfficiencyValueContext ctx(Set<TileType> gold, {int wall = 60}) =>
        EfficiencyValueContext(
          melds: const [],
          roundWind: Wind.east,
          seatWind: Wind.east,
          isDealer: true,
          inRiichi: false,
          wallTilesRemaining: wall,
          doraIndicators: const [],
          ruleset: Ruleset.fuzhou,
          goldTypes: gold,
          goldLeft: 2,
        );

    List<int> seen(List<Tile> hand) {
      final c = List<int>.filled(34, 0);
      for (final t in hand) {
        c[t.type.index - 1]++;
      }
      return c;
    }

    test('keeps the Gold and cuts the stray tile', () {
      // Ready on 3p/6p... plus a loose 9s to cut; the gold 5s is wild.
      final hand = parseTiles('123m 456m 789m 123p 45p 9s 99s 5s')
          .toList(); // 17 tiles
      final report = EfficiencyEngine().analyze(
        hand: hand,
        visibleCounts34: seen(hand),
        canRiichi: false,
        valueContext: ctx({TileType.sou5}),
      );
      expect(report.lines, isNotEmpty);
      final best = report.lines.first;
      expect(best.discard, isNot(TileType.sou5),
          reason: 'a Gold is wild: throwing it locks you to self-draw');
      expect(best.shanten, lessThanOrEqualTo(0));
      expect(report.tenpai, isTrue);
    });

    test('a hand holding a Gold is one step closer than the same without', () {
      // 16 tiles: four sets, a pair and two loose tiles. A natural 5s is a
      // loose tile; a Gold 5s joins the 4p.
      final hand = parseTiles('123m 456m 789m 123p 4p 99s 5s');
      int shantenOf(Set<TileType> gold) =>
          FuzhouEfficiency.shanten(hand, openMelds: 0, gold: gold);
      expect(shantenOf(const {}), 1);
      expect(shantenOf({TileType.sou5}), 0);
    });

    test('a ready hand takes a self-draw and a win off a discard', () {
      final hand = parseTiles('123m 456m 789m 123p 456p 9s 9s');
      final win = EfficiencyEngine().adviseTsumo(
        hand: hand,
        drawn: hand.last,
        context: ctx({TileType.sou5}),
      );
      expect(win.action, GuidedAction.tsumo);
      expect(win.expectedValue, greaterThan(0));

      final ready = parseTiles('123m 456m 789m 123p 456p 9s');
      final call = EfficiencyEngine().adviseCall(
        hand: ready,
        offered: Tile(901, TileType.sou9),
        available: {GuidedAction.ron},
        visibleCounts34: seen(ready),
        context: ctx({TileType.sou5}),
      );
      expect(call.recommended, GuidedAction.ron);
    });

    test('win chance rises with more draws and never exceeds one', () {
      final few = FuzhouGuide.reach(2, 4, 0.2);
      final many = FuzhouGuide.reach(2, 12, 0.2);
      expect(many, greaterThan(few));
      expect(many, lessThanOrEqualTo(1));
      expect(FuzhouGuide.reach(0, 3, 0.5), 1);
      expect(FuzhouGuide.reach(3, 2, 0.9), 0);
    });
  });

  group('the builder', () {
    void fill(Scenario s, List<Tile> into, String spec) {
      for (final t in parseTypes(spec)) {
        into.add(s.mint(t));
      }
    }

    test('asks for the Gold, and counts it with the flowers', () {
      final s = Scenario()
        ..ruleset = Ruleset.fuzhou
        ..clear();
      expect(s.problems().any((p) => p.contains('Gold')), isTrue);
      s.dora.add(TileType.sou5);
      expect(s.goldTypes, {TileType.sou5});
      // One 5s is the indicator; three more can be held as wilds.
      expect(s.remainingCopies(TileType.sou5), 3);
      // An East is a flower, out of the same four copies.
      s.seats[0].flowers.add(s.mint(TileType.ton));
      expect(s.remainingCopies(TileType.ton), 3);
      // A natural honor can't sit in hand.
      fill(s, s.hand, 'E');
      expect(s.problems().any((p) => p.contains('flowers')), isTrue);
    });

    test('scores a posed Fuzhou win, Gold wild and flowers counted', () {
      final c = ScenarioController(askMortal: false, scoreWins: true)
        ..setRuleset(Ruleset.fuzhou);
      addTearDown(c.dispose);
      c.edit((s) {
        s.dora.add(TileType.sou5);
        // 123m 456m 789m 123p 4p 6p 99s + a Gold 5s standing for the 5p.
        fill(s, s.hand, '123m 456m 789m 123p 46p 99s 5s');
        // 6 flowers.
        for (final t in [
          TileType.plum,
          TileType.orchid,
          TileType.spring,
          TileType.summer,
          TileType.ton,
          TileType.nan,
        ]) {
          s.seats[0].flowers.add(s.mint(t));
        }
        s.winType = TileType.sou9;
      });
      expect(c.blockedReason, isNull, reason: '${c.blockedReason}');
      final win = c.win!;
      expect(win.wins, isTrue);
      // (5 + 6 flowers + 1 Gold) x 2 + 10 for All Sequences.
      expect(win.score.points, 34);
      expect(win.score.yaku.map((y) => y.name), contains('All Sequences'));
    });

    test('the guide reads a Fuzhou discard with a wild in hand', () {
      final c = ScenarioController()..setRuleset(Ruleset.fuzhou);
      addTearDown(c.dispose);
      c.edit((s) {
        s.dora.add(TileType.sou5);
        fill(s, s.hand, '123m 456m 789m 123p 4p 99s 1s 5s');
      });
      expect(c.blockedReason, isNull, reason: '${c.blockedReason}');
      expect(c.report.lines, isNotEmpty);
      expect(c.report.lines.first.discard, isNot(TileType.sou5));
    });

    testWidgets('the builder screen has a Gold chip that sets the Gold',
        (tester) async {
      await tester.binding.setSurfaceSize(kDesignSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const TileSenseApp());
      await tester.pump(const Duration(milliseconds: 100));
      await tapInPopup(
          tester, 'rulesTile', find.byKey(const Key('ruleset_fuzhou')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('openBuilder')));
      await pumpLoadedPage(tester);
      expect(find.byType(ScenarioPage), findsOneWidget);
      expect(find.byKey(const Key('goldIndicator')), findsOneWidget);
      expect(find.byKey(const Key('builderGold')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
