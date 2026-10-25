import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/round.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/tile.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/l10n/app_language.dart';
import 'package:tilesense/logic/progress.dart';
import 'package:tilesense/main.dart';
import 'package:tilesense/ui/beginner_guide.dart';

import 'helpers.dart';

/// Counting the hands you win, and offering one step up at a time.
void main() {
  late Map<String, String> storage;

  ProgressStore freshStore() =>
      ProgressStore(read: (k) => storage[k], write: (k, v) => storage[k] = v);

  setUp(() {
    storage = {};
    Sfx.i.enabled = false;
    ProgressStore.instance = freshStore();
    ProgressStore.nudgesEnabled = true;
    BeginnerGuide.set(true);
  });
  tearDown(() {
    ProgressStore.nudgesEnabled = false;
    BeginnerGuide.set(false);
    Sfx.i.enabled = true;
  });

  Progress wins(int n, {Set<Nudge> done = const {}, bool muted = false}) =>
      Progress(wins: n, hands: n * 2, done: done, muted: muted);

  Nudge? due(Progress p,
          {bool simple = true,
          Ruleset ruleset = Ruleset.hongKong,
          int faan = 0}) =>
      dueNudge(p, simpleGuide: simple, ruleset: ruleset, minimumFaan: faan);

  group('record', () {
    test('survives a round trip, and anything unreadable starts fresh', () {
      final p = Progress(
          wins: 4, hands: 9, done: {Nudge.fullGuide}, muted: true);
      final back = Progress.fromJson(p.toJson());
      expect((back.wins, back.hands, back.muted), (4, 9, true));
      expect(back.done, {Nudge.fullGuide});

      for (final bad in [null, '', 'not json', '[1,2]', '{"wins":"x"}']) {
        final fresh = Progress.fromJson(bad);
        expect((fresh.wins, fresh.hands, fresh.muted), (0, 0, false),
            reason: '$bad');
        expect(fresh.done, isEmpty, reason: '$bad');
      }
    });

    test('the store counts, saves each change, and tells its listeners', () {
      final store = freshStore();
      var told = 0;
      store.addListener(() => told++);
      store.recordHand(won: true);
      store.recordHand(won: false);
      expect((store.value.wins, store.value.hands), (1, 2));
      store.finish(Nudge.fullGuide);
      store.mute();
      expect(told, 4);

      // A new store reads back what the last one saved.
      final again = freshStore();
      expect((again.value.wins, again.value.hands), (1, 2));
      expect(again.value.done, {Nudge.fullGuide});
      expect(again.value.muted, isTrue);
    });
  });

  group('which suggestion is due', () {
    test('nothing before the first threshold', () {
      expect(due(wins(kFullGuideWins - 1)), isNull);
    });

    test('they come in order as wins mount, each once', () {
      expect(due(wins(kFullGuideWins)), Nudge.fullGuide);
      expect(due(wins(kHigherMinimumWins, done: {Nudge.fullGuide})),
          Nudge.higherMinimum);
      expect(
          due(wins(kNewRulesetWins,
              done: {Nudge.fullGuide, Nudge.higherMinimum})),
          Nudge.newRuleset);
      expect(
          due(wins(99, done: {...Nudge.values})), isNull);
    });

    test('one at a time: the earliest that is open', () {
      expect(due(wins(kNewRulesetWins)), Nudge.fullGuide);
    });

    test('a suggestion that no longer makes sense is skipped', () {
      // Already on the full guide: nothing to switch to.
      expect(due(wins(kFullGuideWins), simple: false), isNull);
      // Past the minimum already, or not Hong Kong: no minimum to raise.
      expect(
          due(wins(kHigherMinimumWins, done: {Nudge.fullGuide}), faan: 1),
          isNull);
      expect(
          due(wins(kHigherMinimumWins, done: {Nudge.fullGuide}),
              ruleset: Ruleset.riichi),
          isNull);
      // Nowhere further to go from Riichi.
      expect(
          due(wins(kNewRulesetWins, done: {...Nudge.values}.difference({Nudge.newRuleset})),
              ruleset: Ruleset.riichi),
          isNull);
    });

    test('Stop suggesting ends them all', () {
      expect(due(wins(50, muted: true)), isNull);
    });

    test('the next ruleset along', () {
      expect(nextRuleset(Ruleset.hongKong), Ruleset.taiwanese);
      expect(nextRuleset(Ruleset.taiwanese), Ruleset.riichi);
      expect(nextRuleset(Ruleset.riichi), isNull);
    });
  });

  group('counting at the table', () {
    /// You hold a complete hand, with the winning tile just drawn.
    GameController onWin() {
      final game = GameController(seed: 4, ruleset: Ruleset.hongKong)
        ..autoWin = false;
      final drawn = Tile(900, TileType.sou5);
      game.round.seats[kHumanSeat]
        ..hand = [...parseTiles('123m 456m 789m 345p 5s'), drawn]
        ..drawn = drawn
        ..melds = [];
      game.round.turn = kHumanSeat;
      game.round.phase = RoundPhase.discarding;
      game.togglePause();
      return game;
    }

    test('a hand you win counts as a win', () {
      final game = onWin();
      try {
        game.humanTsumo();
        expect(game.phase, GamePhase.roundEnd);
        game.continueFromRoundEnd();
        expect((ProgressStore.instance.value.wins,
            ProgressStore.instance.value.hands), (1, 1));
      } finally {
        game.dispose();
      }
    });

    test('a hand the guide played for you does not', () {
      final game = onWin();
      try {
        game.setAutoplay(true);
        game.setAutoplay(false); // off again before the win: still not yours
        game.humanTsumo();
        game.continueFromRoundEnd();
        expect((ProgressStore.instance.value.wins,
            ProgressStore.instance.value.hands), (0, 1));
      } finally {
        game.dispose();
      }
    });

    test('Auto-Play in one hand does not spoil the next', () {
      final game = onWin();
      try {
        game.setAutoplay(true);
        game.setAutoplay(false);
        game.humanTsumo();
        game.continueFromRoundEnd();

        // The next hand, played by hand.
        final drawn = Tile(901, TileType.sou5);
        game.round.seats[kHumanSeat]
          ..hand = [...parseTiles('123m 456m 789m 345p 5s'), drawn]
          ..drawn = drawn
          ..melds = [];
        game.round.turn = kHumanSeat;
        game.round.phase = RoundPhase.discarding;
        game.humanTsumo();
        game.continueFromRoundEnd();
        expect((ProgressStore.instance.value.wins,
            ProgressStore.instance.value.hands), (1, 2));
      } finally {
        game.dispose();
      }
    });
  });

  group('the menu card', () {
    Future<void> boot(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(kDesignSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const TileSenseApp());
      await tester.pump(const Duration(milliseconds: 100));
    }

    void earn(int n) {
      for (var i = 0; i < n; i++) {
        ProgressStore.instance.recordHand(won: true);
      }
    }

    String text(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const Key('nudgeText'))).data!;

    testWidgets('no card for a new player', (tester) async {
      await boot(tester);
      expect(find.byKey(const Key('nudgeCard')), findsNothing);
    });

    testWidgets('the full-guide suggestion switches the guide, once',
        (tester) async {
      earn(kFullGuideWins);
      await boot(tester);
      expect(text(tester), contains('won $kFullGuideWins hands'));
      expect(text(tester), contains('full guide'));
      expect(BeginnerGuide.on.value, isTrue);

      await tester.tap(find.byKey(const Key('nudgeAction')));
      await tester.pump();
      expect(BeginnerGuide.on.value, isFalse);
      expect(find.byKey(const Key('nudgeCard')), findsNothing);
      expect(ProgressStore.instance.value.done, {Nudge.fullGuide});
    });

    testWidgets('the minimum suggestion changes the next game\'s minimum',
        (tester) async {
      earn(kHigherMinimumWins);
      ProgressStore.instance.finish(Nudge.fullGuide);
      await boot(tester);
      expect(text(tester), contains('1 faan minimum'));

      await tester.tap(find.byKey(const Key('nudgeAction')));
      await tester.pump();
      expect(find.byKey(const Key('nudgeCard')), findsNothing);

      await tester.tap(find.text('Single Player'));
      await tester.pump();
      final selected = tester
          .widget<OutlinedButton>(find.byKey(const Key('minimumFaan_1')))
          .style!
          .side!
          .resolve({})!
          .width;
      expect(selected, 2, reason: 'the 1 faan minimum is now chosen');
    });

    testWidgets('the ruleset suggestion selects the next ruleset',
        (tester) async {
      earn(kNewRulesetWins);
      ProgressStore.instance
        ..finish(Nudge.fullGuide)
        ..finish(Nudge.higherMinimum);
      await boot(tester);
      expect(text(tester), contains('Taiwanese'));

      await tester.tap(find.byKey(const Key('nudgeAction')));
      await tester.pump();
      expect(taglineRules('Taiwanese'),
          findsOneWidget);
    });

    testWidgets('Not now retires one; Stop suggesting retires them all',
        (tester) async {
      earn(kNewRulesetWins);
      await boot(tester);
      await tester.tap(find.byKey(const Key('nudgeNotNow')));
      await tester.pump();
      expect(BeginnerGuide.on.value, isTrue, reason: 'nothing was changed');
      expect(text(tester), contains('1 faan minimum'),
          reason: 'the next one is offered');

      await tester.tap(find.byKey(const Key('nudgeStop')));
      await tester.pump();
      expect(find.byKey(const Key('nudgeCard')), findsNothing);
      expect(ProgressStore.instance.value.muted, isTrue);
    });

    testWidgets('every suggestion fits, in every language, on a desktop and '
        'a phone', (tester) async {
      addTearDown(
          () => AppLanguageController.instance.select(AppLanguage.english));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final done in [
        <Nudge>{},
        {Nudge.fullGuide},
        {Nudge.fullGuide, Nudge.higherMinimum},
      ]) {
        for (final size in [kDesignSize, const Size(844, 390)]) {
          for (final language in AppLanguage.values) {
            AppLanguageController.instance.select(language);
            ProgressStore.instance = freshStore();
            earn(kNewRulesetWins);
            for (final n in done) {
              ProgressStore.instance.finish(n);
            }
            await tester.binding.setSurfaceSize(size);
            await tester.pumpWidget(const TileSenseApp());
            await tester.pump(const Duration(milliseconds: 100));
            expect(find.byKey(const Key('nudgeCard')), findsOneWidget,
                reason: '${language.name} $size $done');
            expect(tester.takeException(), isNull,
                reason: '${language.name} $size $done');
            await tester.pumpWidget(const SizedBox());
          }
        }
      }
    });

    testWidgets('it stays out of the way when suggestions are switched off',
        (tester) async {
      ProgressStore.nudgesEnabled = false;
      earn(kNewRulesetWins);
      await boot(tester);
      expect(find.byKey(const Key('nudgeCard')), findsNothing);
    });
  });
}
