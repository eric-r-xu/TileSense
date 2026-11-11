import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/meld.dart';
import 'package:mahjong_core/round.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/sanma/sanma_rules.dart';
import 'package:mahjong_core/tile.dart';
import 'package:tilesense/scenario/play_out.dart';
import 'package:tilesense/scenario/scenario_controller.dart';

import 'package:tilesense/l10n/l10n.dart';
import 'package:tilesense/l10n/mahjong_terms.dart';
import 'package:tilesense/main.dart';
import 'package:tilesense/ui/builder_tour.dart';
import 'package:tilesense/ui/scenario_page.dart';
import 'package:tilesense/ui/table_view.dart';

import 'loading_helpers.dart';
import 'scenario_test.dart' show fill;

/// Plays as a human who declares any win, passes every call and discards the
/// tile just drawn.
void autoPlay(PlayOutSession p) {
  for (var i = 0; i < 500 && !p.finished; i++) {
    expect(p.guideNote, isNull);
    if (p.humanCall != null) {
      final ron = p.humanCall!.types.contains(CallType.ron);
      p.answerCall(ron ? CallType.ron : CallType.none);
    } else if (p.canTsumo) {
      p.tsumo();
    } else if (p.flowerWinPending) {
      p.passFlowerWin();
    } else if (p.canKita) {
      p.kita();
    } else if (p.humanToDiscard) {
      p.discard(p.round.seats[0].hand.last);
    } else {
      fail('session is stuck: ${p.round.phase}');
    }
  }
}

void main() {
  preloadDeferredPages();

  testWidgets('Play starts a hand in the builder, a tap discards, Edit returns',
      (tester) async {
    await tester.binding.setSurfaceSize(kDesignSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('openBuilder')));
    await pumpLoadedPage(tester);

    final c = tester.widget<TableView>(find.byType(TableView)).game
        as ScenarioController;
    c.edit((s) {
      s.clear();
      fill(s, s.hand, '234m 456p 789s EE 67p');
    });
    await tester.pump();

    await tester.tap(find.byKey(const Key('builderPlay')));
    await tester.pump();
    expect(find.byKey(const Key('playStatus')), findsOneWidget);
    expect(tester.widget<TableView>(find.byType(TableView)).game,
        isA<PlayOutSession>());
    final session =
        tester.widget<TableView>(find.byType(TableView)).game as PlayOutSession;
    expect(session.humanToDiscard, isTrue);
    expect(session.round.seats[0].hand.length, 14);

    // Tapping the drawn tile discards it; the bots then play to your turn.
    final drawn = session.round.seats[0].drawn!;
    await tester.tap(find.byKey(Key('playTile${drawn.id}')));
    await tester.pump();
    // A bot may have called it away, so count what was ever discarded.
    expect(session.round.seats[0].allDiscards.length, 1);
    // The opponents have not moved yet: they take their turns one at a time.
    expect(session.botsToMove || session.finished, isTrue);
    await tester.pump(const Duration(seconds: 6));
    expect(
        session.finished || session.humanToDiscard || session.humanCall != null,
        isTrue);

    if (session.finished) {
      // A bot won in those few turns: the results screen covers the bar, and
      // has its own way back to the table.
      await tester.pump(const Duration(seconds: 2));
      await tester.ensureVisible(find.byKey(const Key('playResultEdit')));
      await tester.tap(find.byKey(const Key('playResultEdit')));
    } else {
      await tester.tap(find.byKey(const Key('playStop')));
    }
    await tester.pump();
    expect(find.byKey(const Key('playStatus')), findsNothing);
    expect(tester.widget<TableView>(find.byType(TableView)).game,
        isA<ScenarioController>());
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('a won hand shows the results screen, with a way on',
      (tester) async {
    await tester.binding.setSurfaceSize(kDesignSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('openBuilder')));
    await pumpLoadedPage(tester);

    final c = tester.widget<TableView>(find.byType(TableView)).game
        as ScenarioController;
    // Three each of Chun, Haku, Hatsu and East and a pair of North: already
    // complete, so the first thing to do on your turn is declare it.
    c.edit((s) {
      s.clear();
      fill(s, s.hand, 'RRR BBB GGG EEE NN');
    });
    await tester.pump();
    await tester.tap(find.byKey(const Key('builderPlay')));
    await tester.pump();

    PlayOutSession session() =>
        tester.widget<TableView>(find.byType(TableView)).game as PlayOutSession;
    expect(session().canTsumo, isTrue);
    expect(find.byKey(const Key('scoreContinue')), findsNothing);

    session().tsumo();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(session().humanWon, isTrue);
    // The game's own results screen, without its auto-continue countdown.
    expect(find.byKey(const Key('scoreContinue')), findsOneWidget);
    expect(find.text('New wall'), findsOneWidget);
    expect(find.byKey(const Key('scoreCountdown')), findsNothing);
    expect(find.byKey(const Key('scorePause')), findsNothing);

    // The same wall: the hand is dealt again and can be won again.
    await tester.ensureVisible(find.byKey(const Key('playResultReplay')));
    await tester.tap(find.byKey(const Key('playResultReplay')));
    await tester.pump();
    expect(find.byKey(const Key('scoreContinue')), findsNothing);
    expect(session().canTsumo, isTrue);

    // A new wall is a new session.
    final before = session();
    session().tsumo();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.ensureVisible(find.byKey(const Key('scoreContinue')));
    await tester.tap(find.byKey(const Key('scoreContinue')));
    await tester.pump();
    await tester.pump();
    expect(session(), isNot(same(before)));
    expect(find.byKey(const Key('scoreContinue')), findsNothing);

    // Edit hand goes back to the posed table.
    session().tsumo();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.ensureVisible(find.byKey(const Key('playResultEdit')));
    await tester.tap(find.byKey(const Key('playResultEdit')));
    await tester.pump();
    expect(find.byKey(const Key('builderPlay')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('on a phone, the play bar fits and its buttons stay on screen',
      (tester) async {
    await tester.binding.setSurfaceSize(kDesignSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    BuilderTour.markSeen();
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(1.35)),
        child: child!,
      ),
      home: ScenarioPage(onExit: () {}),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    final c = tester.widget<TableView>(find.byType(TableView)).game
        as ScenarioController;
    c.edit((s) {
      s.clear();
      fill(s, s.hand, '234m 456p 789s EE 67p');
    });
    await tester.pump();
    await tester.tap(find.byKey(const Key('builderPlay')));
    await tester.pump();
    final p =
        tester.widget<TableView>(find.byType(TableView)).game as PlayOutSession;

    // The seat on your left cuts a 5p: you may chi it (two ways), or pass.
    p.discard(p.round.seats[0].hand.last);
    final cut = Tile(9000, TileType.pin5);
    // (A bot may have claimed that discard; settle it, then stage the scene.)
    if (p.round.phase == RoundPhase.callOffer) p.round.resolveCalls({});
    expect(p.round.phase, RoundPhase.discarding);
    p.round.turn = 3;
    p.round.seats[3].hand = [...p.round.seats[3].hand, cut];
    p.round.discard(3, cut);
    p.notifyListeners();
    await tester.pump();
    expect(p.humanCall, isNotNull);

    final view = Offset.zero & kDesignSize;
    for (final key in ['playPass', 'playReset', 'playStop', 'playStatus']) {
      final rect = tester.getRect(find.byKey(Key(key)));
      expect(view.contains(rect.topLeft) && view.contains(rect.bottomRight),
          isTrue,
          reason: '$key is at $rect');
    }
    // Big enough to tap on a phone.
    expect(tester.getRect(find.byKey(const Key('playPass'))).height,
        greaterThanOrEqualTo(60));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  test('the play bar speaks every language the app does', () {
    final byLocale = {
      for (final l in const [
        Locale('en'),
        Locale('ja'),
        Locale('zh'),
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ])
        l: lookupAppLocalizations(l)
    };
    final turn = {
      for (final e in byLocale.entries) e.key: e.value.playStatusTurn(40)
    };
    for (final t in turn.values) {
      expect(t, contains('40'));
    }
    // Four different texts, not English four times.
    expect(turn.values.toSet().length, 4);
    expect({for (final l in byLocale.values) l.playEditHand}.length, 4);
    expect(byLocale[const Locale('ja')]!.playStatusCall('下家', '5p'),
        contains('5p'));
    // The seats and calls it names are the app's own words.
    expect(
        byLocale[const Locale('ja')]!.callLabel(CallType.ron, Ruleset.riichi),
        'ロン');
  });

  ScenarioController posed() {
    final c = ScenarioController(askMortal: false, scoreWins: true);
    c.edit((s) {
      fill(s, s.hand, '234m 456p 789s EE 67p');
      s.wallRemaining = 40;
    });
    return c;
  }

  test('a posed hand plays out to a result on every seed', () {
    for (var seed = 0; seed < 30; seed++) {
      final c = posed();
      final p = PlayOutSession(c, seed: seed, stepDelay: Duration.zero);
      expect(p.round.seats[0].hand.length, anyOf(13, 14));
      autoPlay(p);
      expect(p.finished, isTrue, reason: 'seed $seed');
      expect(p.result, isNotNull);
      p.dispose();
      c.dispose();
    }
  });

  test('the guide reads each of your turns while a hand is played out', () {
    final c = posed();
    final p = PlayOutSession(c, seed: 5, stepDelay: Duration.zero);
    var reads = 0;
    for (var i = 0; i < 200 && !p.finished; i++) {
      if (p.humanCall != null) {
        // A call on offer is answered by the guide too.
        expect(p.recommendedCall, isNotNull);
        p.answerCall(CallType.none);
      } else if (p.canTsumo) {
        p.tsumo();
      } else if (p.humanToDiscard) {
        expect(p.guideNote, isNull);
        final best = p.report.lines.where((l) => l.recommended);
        expect(best, isNotEmpty);
        reads++;
        // Follow the guide.
        final pick = p.round.seats[0].hand
            .firstWhere((t) => t.type == best.first.discard);
        p.discard(pick);
      }
    }
    expect(reads, greaterThan(0));
    p.dispose();
    c.dispose();
  });

  test('reset replays the same wall', () {
    final c = posed();
    final p = PlayOutSession(c, seed: 7, stepDelay: Duration.zero);
    final first = [for (final t in p.round.seats[0].hand) t.type];
    autoPlay(p);
    p.reset();
    expect([for (final t in p.round.seats[0].hand) t.type], first);
    expect(p.finished, isFalse);
  });

  test('the wall is as long as the scenario says', () {
    final c = posed();
    final p = PlayOutSession(c, seed: 3, stepDelay: Duration.zero);
    // One tile was already drawn on the way in.
    expect(p.round.wall.remaining, lessThanOrEqualTo(40));
    expect(p.round.wall.remaining, greaterThan(30));
  });

  testWidgets('opponents take their turns one at a time, not all at once',
      (tester) async {
    final c = posed();
    final p = PlayOutSession(c, seed: 3);
    int botDiscards() => [
          for (var i = 1; i < 4; i++) p.round.seats[i].allDiscards.length
        ].fold(0, (a, b) => a + b);

    expect(p.humanToDiscard, isTrue);
    p.discard(p.round.seats[0].hand.last);
    // Nothing has moved yet: the table is waiting on the first opponent.
    expect(botDiscards(), 0);
    expect(p.botsToMove, isTrue);
    expect(p.actingSeat, isNotNull);

    // Then one move per step, never several at once.
    var last = 0;
    var steps = 0;
    while (p.botsToMove && steps < 20) {
      await tester.pump(const Duration(milliseconds: 700));
      final now = botDiscards();
      expect(now - last, lessThanOrEqualTo(1), reason: 'step $steps');
      last = now;
      steps++;
    }
    // Three seats, so at least three moves before it is your turn again.
    expect(steps, greaterThanOrEqualTo(3));
    expect(p.finished || p.humanToDiscard || p.humanCall != null, isTrue);
    p.dispose();
    c.dispose();
  });

  test('the red fives left in the wall are dealt, one per suit', () {
    final c = posed();
    // Pin one red five down: the other two are still among the unseen tiles.
    c.edit((s) => s.hand.add(s.mint(TileType.pin5, aka: true)));
    final seen = <TileType>{};
    for (var seed = 0; seed < 30; seed++) {
      final round = c.buildPlayRound(Random(seed));
      // Everything that can be looked at: the opponents' hands, the live wall
      // and the first replacement draws.
      final tiles = <Tile>[
        for (final seat in round.seats.skip(1)) ...seat.hand,
        for (var i = 0; i < 4; i++) round.wall.drawDeadWall(),
      ];
      while (!round.wall.isEmpty) {
        tiles.add(round.wall.drawLive());
      }
      final reds = [
        for (final t in tiles)
          if (t.aka) t.type
      ];
      // Never a second red in a suit, and never the one already placed.
      expect(reds.toSet().length, reds.length, reason: 'seed $seed');
      expect(reds, isNot(contains(TileType.pin5)), reason: 'seed $seed');
      seen.addAll(reds);
    }
    expect(seen, {TileType.man5, TileType.sou5});
    c.dispose();
  });

  test('a posed Sanma table starts with as many dora showing as were posed',
      () {
    final c = ScenarioController(askMortal: false, scoreWins: true);
    c.setRuleset(Ruleset.sanma);
    c.edit((s) {
      s.dora
        ..clear()
        ..addAll([TileType.pin1, TileType.sou9, TileType.pin3]);
      fill(s, s.hand, '1p 2p 3p 4p 5p 6p 7p 8p 9p 1s 2s 3s 4s');
    });
    final round = c.buildPlayRound(Random(1));
    expect(round.wall.doraIndicators(),
        [TileType.pin1, TileType.sou9, TileType.pin3]);
    c.dispose();
  });

  test('you can add to your own pon, and abort on nine kinds', () {
    final c = ScenarioController(askMortal: false, scoreWins: true);
    c.edit((s) {
      fill(s, s.hand, '1m 234p 567p 789s');
      s.seats[0].melds.add(Meld(
        kind: MeldKind.triplet,
        low: TileType.man1,
        concealed: false,
        calledFromSeatOffset: 1,
      ));
    });
    final p = PlayOutSession(c, seed: 4, stepDelay: Duration.zero);
    expect(p.addedKans, [TileType.man1]);
    p.addKan(TileType.man1);
    expect(p.round.seats[0].melds.any((m) => m.kind == MeldKind.kan), isTrue);
    p.dispose();

    final c2 = ScenarioController(askMortal: false, scoreWins: true);
    c2.edit((s) => fill(s, s.hand, '19m 19p 19s ESWN BGR'));
    final q = PlayOutSession(c2, seed: 4, stepDelay: Duration.zero);
    expect(q.canKyuushu, isTrue);
    q.kyuushu();
    expect(q.finished, isTrue);
    expect(q.result!.kind, RoundEndKind.abortiveDraw);
    q.dispose();
    c.dispose();
    c2.dispose();
  });

  for (final rules in Ruleset.values) {
    test('${rules.name}: a posed hand plays out to a result', () {
      for (var seed = 0; seed < 10; seed++) {
        final c = ScenarioController(askMortal: false, scoreWins: true);
        c.setRuleset(rules);
        c.edit((s) {
          s.wallRemaining = 30;
          if (rules.isFuzhou) {
            s.dora
              ..clear()
              ..add(TileType.man1);
          }
          // The first tiles the game has, two of each, to the hand size.
          final types = [
            for (final t in TileType.values)
              if (t.isPlayingTile &&
                  ((!rules.isSichuan && !rules.isFuzhou) || t.isSuit) &&
                  (!rules.isSanma || SanmaRules.inWall(t)))
                t
          ];
          for (var i = 0; s.hand.length < rules.concealedHandSize; i++) {
            s.hand.add(s.mint(types[(i * 5) % types.length]));
          }
        });
        final p = PlayOutSession(c, seed: seed, stepDelay: Duration.zero);
        autoPlay(p);
        expect(p.finished, isTrue, reason: '${rules.name} seed $seed');
        expect(p.result, isNotNull);
        p.dispose();
        c.dispose();
      }
    });
  }
}
