import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/game_timing.dart';
import 'package:mahjong_core/mahjong_core.dart';
import 'package:tilesense/game/call_callout.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/l10n/l10n.dart';
import 'package:tilesense/ui/scoring_view.dart';
import 'package:tilesense/ui/tile_face.dart';

import 'helpers.dart';

Round nagashiRound(
    {required int dealer,
    required bool tenpai,
    required List<int> recipients,
    Ruleset ruleset = Ruleset.riichi}) {
  final round = Round.posed(
    dealer: dealer,
    roundWind: Wind.east,
    honba: 2,
    riichiSticks: 1,
    ruleset: ruleset,
    wall: ruleset.isSanma
        ? SanmaWall.posed(remaining: 0, dora: const [])
        : Wall.posed(remaining: 0, dora: const []),
    startingPoints: [
      for (var i = 0; i < 4; i++)
        ruleset.seatIsActive(i)
            ? ruleset.startingPoints - (i == 0 ? 1000 : 0)
            : 0
    ],
  );
  for (final s in round.activeSeats) {
    s.hand = parseTiles('19m 1258p 147s EWB G');
  }
  if (tenpai) {
    round.seats[dealer].hand = parseTiles('234p 567p 234s 67s 88p');
  }
  for (final seat in recipients) {
    final pond = parseTiles('19m 19p 19s ESW');
    round.seats[seat].pond = pond;
    round.seats[seat].allDiscards.addAll(pond);
  }
  round.beginPosedPlay();
  expect(round.result!.isNagashiMangan, isTrue);
  return round;
}

void main() {
  setUp(() {
    Sfx.i.enabled = false;
    CallCallout.i.clear();
  });
  tearDown(() => Sfx.i.enabled = true);

  for (final ruleset in [Ruleset.riichi, Ruleset.sanma]) {
    for (final dealer in ruleset.activeSeats) {
      for (final tenpai in [true, false]) {
        for (final dealerQualifies in [true, false]) {
          test(
              '${ruleset.name}: dealer $dealer: tenpai=$tenpai, nagashi=$dealerQualifies',
              () {
            final game = GameController(
                seed: 5, startingDealer: dealer, ruleset: ruleset)
              ..paused = true;
            addTearDown(game.dispose);
            final round = nagashiRound(
              dealer: dealer,
              ruleset: ruleset,
              tenpai: tenpai,
              recipients: [dealerQualifies ? dealer : ruleset.nextSeat(dealer)],
            );
            expect(round.result!.tenpaiAtDraw.contains(dealer), tenpai);
            game.round = round;
            game.phase = GamePhase.roundEnd;
            game.continueFromRoundEnd();
            expect(
                game.round.dealer, tenpai ? dealer : ruleset.nextSeat(dealer));
            expect(game.roundNumber, tenpai ? 0 : 1);
            expect(game.dealerRepeat, tenpai ? 1 : 0);
            // The controller's honba starts at zero; a drawn hand adds one.
            expect(game.honba, 1);
            expect(game.round.riichiSticks, 1);
          });
        }
      }
    }

    for (final locale in AppLocalizations.supportedLocales) {
      testWidgets(
          '${ruleset.name}: nagashi result shows discards and payments in $locale',
          (tester) async {
        final game = GameController(seed: 5, ruleset: ruleset)..paused = true;
        game.round = nagashiRound(
            dealer: 0,
            ruleset: ruleset,
            tenpai: false,
            recipients: [1, ruleset.isSanma ? 3 : 2]);
        game.phase = GamePhase.roundEnd;
        await tester.binding.setSurfaceSize(const Size(1400, 1000));
        try {
          await tester.pumpWidget(MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ScoringView(game: game, autoContinue: false)),
          ));
          await tester.pump(kWinScorePause);
          await tester.pump();
          final l10n = lookupAppLocalizations(locale);
          expect(find.text('${l10n.resultNagashiMangan}  (1 / 2)'),
              findsOneWidget);
          final block = find.byKey(const Key('scoreNagashi'));
          expect(find.descendant(of: block, matching: find.byType(TileFace)),
              findsNWidgets(game.round.seats[1].pond.length));
          expect(find.text(l10n.nagashiSettlement), findsOneWidget);
          expect(find.byKey(const Key('scoreBreakdown')), findsNothing);
          expect(find.byKey(const Key('scorePayments')), findsOneWidget);
          if (ruleset.isSanma) {
            expect(find.textContaining(game.seatLabel(2)), findsNothing);
          }
          expect(tester.takeException(), isNull);

          await tester.ensureVisible(find.byKey(const Key('scoreContinue')));
          await tester.tap(find.byKey(const Key('scoreContinue')));
          await tester.pump();
          expect(find.text('${l10n.resultNagashiMangan}  (2 / 2)'),
              findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          game.dispose();
          await tester.pumpWidget(const SizedBox());
          await tester.binding.setSurfaceSize(null);
        }
      });
    }
  }
}
