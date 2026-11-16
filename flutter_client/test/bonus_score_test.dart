import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/game_timing.dart';
import 'package:mahjong_core/mahjong_core.dart';
import 'package:tilesense/game/call_callout.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/l10n/l10n.dart';
import 'package:tilesense/main.dart' show canvasSizeFor;
import 'package:tilesense/ui/scoring_view.dart';

import 'helpers.dart';

Round fixture(Ruleset ruleset,
    {String outcome = 'tsumo', int honba = 2, int sticks = 3}) {
  final round = Round.posed(
    dealer: 0,
    roundWind: Wind.east,
    honba: honba,
    riichiSticks: sticks,
    ruleset: ruleset,
    wall: ruleset.isSanma
        ? SanmaWall.posed(remaining: 0, dora: const [])
        : Wall.posed(remaining: 0, dora: const []),
    startingPoints: [
      for (var i = 0; i < 4; i++)
        ruleset.seatIsActive(i) ? ruleset.startingPoints : 0,
    ],
  );
  for (final s in round.activeSeats) {
    s.hand = parseTiles('19m 1258p 147s EWBG');
  }
  if (outcome == 'draw' || outcome == 'nagashi') {
    if (outcome == 'nagashi') {
      final river = parseTiles('19m ESW');
      round.seats[1].pond = river;
      round.seats[1].allDiscards.addAll(river);
    }
    round.beginPosedPlay();
  } else {
    round.seats[1].hand = parseTiles('234p 567s 234s 67p 88s');
    const win = Tile(900, TileType.pin5);
    if (outcome == 'tsumo') {
      round.seats[1].hand.add(win);
      round.seats[1].drawn = win;
      round.turn = 1;
      round.declareTsumo(1);
    } else {
      if (outcome == 'multiple ron') {
        round.seats[3].hand = parseTiles('234p 567s 234s 67p 88s');
      }
      round.seats[0].hand.add(win);
      round.seats[0].drawn = win;
      round.discard(0, win);
      round.resolveCalls({
        1: CallType.ron,
        if (outcome == 'multiple ron') 3: CallType.ron,
      });
    }
  }
  return round;
}

void main() {
  setUp(() {
    Sfx.i.enabled = false;
    CallCallout.i.clear();
  });
  tearDown(() => Sfx.i.enabled = true);

  Future<void> showResult(WidgetTester tester, Round round,
      Future<void> Function(GameController) check,
      {Locale locale = const Locale('en'),
      Size size = const Size(1400, 1000)}) async {
    final game = GameController(seed: 5, ruleset: round.ruleset)..paused = true;
    game.round = round;
    game.phase = GamePhase.roundEnd;
    await tester.binding.setSurfaceSize(size);
    try {
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Match the app's fixed canvas, which is scaled to fit a phone.
        home: Scaffold(
            body: FittedBox(
                child: SizedBox(
          width: canvasSizeFor(size).width,
          height: canvasSizeFor(size).height,
          child: ScoringView(game: game, autoContinue: false),
        ))),
      ));
      await tester.pump(kWinScorePause);
      await tester.pump();
      await check(game);
      expect(tester.takeException(), isNull);
    } finally {
      game.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.binding.setSurfaceSize(null);
    }
  }

  void expectRow(Key key, String label, int points, AppLocalizations l10n) {
    final row = find.byKey(key);
    expect(
        find.descendant(of: row, matching: find.text(label)), findsOneWidget);
    expect(
        find.descendant(
            of: row, matching: find.text('+${l10n.scorePointMany(points)}')),
        findsOneWidget);
  }

  for (final ruleset in [Ruleset.riichi, Ruleset.sanma]) {
    for (final locale in AppLocalizations.supportedLocales) {
      for (final size in [const Size(1400, 1000), const Size(390, 844)]) {
        testWidgets('${ruleset.name} bonus lines in $locale at $size',
            (tester) async {
          await showResult(tester, fixture(ruleset), locale: locale, size: size,
              (game) async {
            final l10n = lookupAppLocalizations(locale);
            expect(find.text(l10n.scoreBonusesTo(game.seatLabel(1))),
                findsOneWidget);
            expectRow(const Key('scoreHonbaPayout'), l10n.scoreHonbaPayout,
                ruleset.isSanma ? 400 : 600, l10n);
            expectRow(const Key('scoreRiichiStickPayout'),
                l10n.scoreRiichiStickPayout, 3000, l10n);
          });
        });
      }
    }

    for (final online in [false, true]) {
      testWidgets('${ruleset.name} multiple ron pages, online=$online',
          (tester) async {
        var round = fixture(ruleset, outcome: 'multiple ron');
        if (online) {
          final wire = jsonDecode(
                  jsonEncode(roundSnapshotToJson(round, reveal: (_) => true)))
              as Map<String, dynamic>;
          round = buildRoundFromSnapshot(wire, mySeat: 3);
        }
        await showResult(tester, round, (game) async {
          final l10n = lookupAppLocalizations(const Locale('en'));
          expect(
              find.text(l10n
                  .scoreBonusesTo(game.seatLabel(round.result!.winners[0]))),
              findsOneWidget);
          expectRow(
              const Key('scoreHonbaPayout'), l10n.scoreHonbaPayout, 600, l10n);
          expectRow(const Key('scoreRiichiStickPayout'),
              l10n.scoreRiichiStickPayout, 3000, l10n);
          await tester.ensureVisible(find.byKey(const Key('scoreContinue')));
          await tester.tap(find.byKey(const Key('scoreContinue')));
          await tester.pump();
          expect(
              find.text(l10n
                  .scoreBonusesTo(game.seatLabel(round.result!.winners[1]))),
              findsOneWidget);
          expectRow(
              const Key('scoreHonbaPayout'), l10n.scoreHonbaPayout, 0, l10n);
          expectRow(const Key('scoreRiichiStickPayout'),
              l10n.scoreRiichiStickPayout, 0, l10n);
        });
      });
    }

    for (final outcome in ['ron', 'nagashi']) {
      testWidgets('${ruleset.name} $outcome explicitly shows zero bonuses',
          (tester) async {
        await showResult(
            tester,
            fixture(ruleset,
                outcome: outcome,
                honba: outcome == 'nagashi' ? 2 : 0,
                sticks: outcome == 'nagashi' ? 3 : 0), (game) async {
          final l10n = lookupAppLocalizations(const Locale('en'));
          expectRow(
              const Key('scoreHonbaPayout'), l10n.scoreHonbaPayout, 0, l10n);
          expectRow(const Key('scoreRiichiStickPayout'),
              l10n.scoreRiichiStickPayout, 0, l10n);
        });
      });
    }

    testWidgets('${ruleset.name} ordinary draws have no bonus recipient',
        (tester) async {
      await showResult(tester, fixture(ruleset, outcome: 'draw'), (game) async {
        expect(find.byKey(const Key('scoreJapaneseBonuses')), findsNothing);
      });
    });
  }

  testWidgets('Chinese-style results do not show Japanese bonus lines',
      (tester) async {
    await showResult(tester, fixture(Ruleset.hongKong), (game) async {
      expect(find.byKey(const Key('scoreJapaneseBonuses')), findsNothing);
    });
  });
}
