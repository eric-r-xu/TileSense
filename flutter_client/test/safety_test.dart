import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/logic/efficiency_engine.dart';
import 'package:tilesense/logic/round.dart';
import 'package:tilesense/logic/safety.dart';
import 'package:tilesense/logic/tile.dart';
import 'package:tilesense/ui/efficiency_overlay.dart';

import 'helpers.dart';

Round freshRound() {
  final round = Round(
    seed: 1,
    dealer: 0,
    roundWind: Wind.east,
    honba: 0,
    riichiSticks: 0,
    startingPoints: List.filled(4, 25000),
  );
  for (final seat in round.seats) {
    seat.hand = parseTiles('234m 567m 234p 67p 88s');
    seat.drawn = null;
  }
  return round;
}

void discard(Round round, int seat, TileType type,
    {bool riichi = false, bool pass = true}) {
  final tile = Tile(900 + round.seats[seat].allDiscards.length, type);
  round.seats[seat]
    ..hand = [...parseTiles('234m 567m 234p 67p 88s'), tile]
    ..drawn = tile;
  round.turn = seat;
  round.phase = RoundPhase.discarding;
  round.discard(seat, tile, declareRiichi: riichi);
  if (pass && round.phase == RoundPhase.callOffer) round.resolveCalls({});
}

SafetyRating rating(Round round, int seat, TileType type) => rankSafety(
      [Tile(1000, type)],
      opponentDiscards:
          round.seats[seat].allDiscards.map((tile) => tile.type).toList(),
      passedDiscardsAfterRiichi:
          round.seats[seat].passedDiscardsAfterRiichi.toList(),
      visibleCounts34: List.filled(34, 0),
    ).single;

void main() {
  testWidgets('safety labels name the riichi opponent and explain genbutsu',
      (tester) async {
    Sfx.i.enabled = false;
    final game = GameController(seed: 1);
    try {
      game.round.seats[1].riichi = true;
      game.round.seats[2].riichi = true;
      final hand = parseTiles('1m 234m 567m 99s 78p 3p W 5s');
      final report = EfficiencyEngine().analyze(
        hand: hand,
        defenseHand: hand,
        visibleCounts34: toCounts34(hand),
        canRiichi: false,
        opponentRiichi: true,
        opponentDiscards: const [TileType.man1],
        valueContext: const EfficiencyValueContext(
          melds: [],
          roundWind: Wind.east,
          seatWind: Wind.east,
          isDealer: true,
          inRiichi: false,
          wallTilesRemaining: 40,
          doraIndicators: [],
        ),
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: EfficiencyOverlay(game: game, report: report),
          ),
        ),
      ));

      expect(find.text('Safety vs Grant (riichi only)'), findsOneWidget);
      expect(find.text('Genbutsu (riichi only)'), findsOneWidget);
      expect(find.textContaining('riichi opponent only'), findsOneWidget);
      // The glossary no longer restates what genbutsu is; the rating's own
      // label in the table carries it.
      expect(find.textContaining('their own discards'), findsNothing);
      // Every mention of Expected Value explains the number on hover: the
      // column heading, the glossary entry, and each row's own cell.
      Finder evTips({bool worked = false}) => find.byWidgetPredicate((w) {
            if (w is! Tooltip) return false;
            final t = w.richMessage?.toPlainText() ?? '';
            return t.contains('EV  =  chance of finishing') &&
                t.contains('THIS CUT') == worked;
          });
      expect(evTips(), findsNWidgets(2), reason: 'heading and glossary');
      expect(evTips(worked: true), findsNWidgets(report.lines.length),
          reason: 'one per discard row');

      // The general explainer surfaces, in plain English rather than symbols.
      tester.state<TooltipState>(evTips().first).ensureTooltipVisible();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('The average points this discard is worth'),
          findsOneWidget);
      expect(find.textContaining('EV  =  chance of finishing'), findsOneWidget);
      // Generalised: no tenpai/pre-tenpai split and no raw coefficients.
      expect(find.textContaining('pre-tenpai'), findsNothing);
      expect(find.textContaining('5800'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      game.dispose();
      Sfx.i.enabled = true;
    }
  });

  test('own pre-riichi and declaration discards remain genbutsu', () {
    final round = freshRound();
    discard(round, 1, TileType.man4);
    discard(round, 1, TileType.ton, riichi: true);

    expect(rating(round, 1, TileType.man4).rating, 15);
    expect(rating(round, 1, TileType.ton).rating, 15);
    expect(rating(round, 1, TileType.man4).label, 'Genbutsu (riichi only)');
  });

  test('other players discards qualify only after this opponents riichi', () {
    final round = freshRound();
    discard(round, 2, TileType.man4);
    discard(round, 1, TileType.ton, riichi: true);
    discard(round, 2, TileType.sou4);
    discard(round, 3, TileType.nan, riichi: true);
    discard(round, 0, TileType.pin4);

    expect(rating(round, 1, TileType.man4).isSafe, isFalse);
    expect(rating(round, 1, TileType.sou4).isSafe, isTrue);
    expect(rating(round, 3, TileType.sou4).isSafe, isFalse);
    expect(rating(round, 1, TileType.pin4).isSafe, isTrue);
    expect(rating(round, 3, TileType.pin4).isSafe, isTrue);
    expect(round.seats[0].passedDiscardsAfterRiichi, isEmpty);
    expect(freshRound().seats[1].passedDiscardsAfterRiichi, isEmpty);
  });

  test('a pending winning discard becomes genbutsu only after ron is passed',
      () {
    final round = freshRound();
    discard(round, 1, TileType.ton, riichi: true);
    discard(round, 2, TileType.pin5, pass: false);
    expect(round.phase, RoundPhase.callOffer);
    expect(rating(round, 1, TileType.pin5).isSafe, isFalse);

    round.resolveCalls({});
    expect(rating(round, 1, TileType.pin5).isSafe, isTrue);
  });

  test('a discard won by ron is never registered as passed', () {
    final round = freshRound();
    discard(round, 1, TileType.ton, riichi: true);
    discard(round, 2, TileType.pin5, pass: false);
    round.resolveCalls({1: CallType.ron});

    expect(round.finished, isTrue);
    expect(round.seats[1].passedDiscardsAfterRiichi,
        isNot(contains(TileType.pin5)));
  });

  test('post-riichi genbutsu survives a discard being called away', () {
    final round = freshRound();
    discard(round, 1, TileType.ton, riichi: true);
    round.seats[3].hand = parseTiles('44m 123s 456s 789s 12p');
    discard(round, 2, TileType.man4, pass: false);
    round.resolveCalls({3: CallType.pon});

    expect(round.seats[2].pond, isEmpty);
    expect(rating(round, 1, TileType.man4).isSafe, isTrue);
  });

  test('own genbutsu survives being called away before riichi', () {
    final round = freshRound();
    round.seats[3].hand = parseTiles('44m 123s 456s 789s 12p');
    discard(round, 1, TileType.man4, pass: false);
    round.resolveCalls({3: CallType.pon});
    expect(round.seats[1].pond, isEmpty);
    discard(round, 1, TileType.ton, riichi: true);

    expect(rating(round, 1, TileType.man4).isSafe, isTrue);
  });

  testWidgets(
      'your own discards are genbutsu only from the riichi declaration on',
      (tester) async {
    Sfx.i.enabled = false;
    final game = GameController(seed: 1);
    try {
      final round = game.round;
      final human = round.seats[kHumanSeat];

      // The rest of the hand keeps a spare 4p and 4s so both types stay in
      // the defence table after they have been cut once.
      void humanCut(Tile tile) {
        human.hand = [...parseTiles('1m 234m 567m 44p 44s'), tile];
        human.drawn = tile;
        round.turn = kHumanSeat;
        round.phase = RoundPhase.discarding;
        game.humanDiscard(tile);
        if (round.phase == RoundPhase.callOffer) round.resolveCalls({});
      }

      // You cut 4p while the table is still quiet.
      humanCut(Tile(900, TileType.pin4));

      final opp = round.seats[1];
      opp.hand = [
        ...parseTiles('234m 567m 234p 67p 88s'),
        Tile(901, TileType.ton)
      ];
      opp.drawn = Tile(901, TileType.ton);
      round.turn = 1;
      round.phase = RoundPhase.discarding;
      round.discard(1, Tile(901, TileType.ton), declareRiichi: true);
      if (round.phase == RoundPhase.callOffer) round.resolveCalls({});

      // ...and cut 4s once they are in riichi.
      humanCut(Tile(902, TileType.sou4));

      final byType = {for (final r in game.report.defense) r.type: r};
      expect(byType[TileType.pin4]?.isSafe, isFalse,
          reason: 'your own pre-riichi discard is not genbutsu');
      expect(byType[TileType.sou4]?.isSafe, isTrue,
          reason: 'your own discard that passed after their riichi is');
    } finally {
      game.dispose();
      Sfx.i.enabled = true;
    }
  });

  test('the guide does not assign safety scores without an opponent riichi',
      () {
    final hand = parseTiles('1m 234m 567m 99s 78p 3p W 5s');
    final report = EfficiencyEngine().analyze(
      hand: hand,
      defenseHand: hand,
      visibleCounts34: toCounts34(hand),
      canRiichi: false,
      opponentDiscards: const [TileType.man1],
      passedDiscardsAfterRiichi: const [TileType.shaa],
      valueContext: const EfficiencyValueContext(
        melds: [],
        roundWind: Wind.east,
        seatWind: Wind.east,
        isDealer: true,
        inRiichi: false,
        wallTilesRemaining: 40,
        doraIndicators: [],
      ),
    );

    expect(report.defending, isFalse);
    expect(report.defense, isEmpty);
    expect(report.lines.every((line) => line.safety == null), isTrue);
  });
}
