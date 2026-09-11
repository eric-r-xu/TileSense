import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/logic/round.dart';
import 'package:tilesense/logic/efficiency_engine.dart';
import 'package:tilesense/logic/tile.dart';
import 'package:tilesense/main.dart';

import 'helpers.dart';

/// The play-style dial. It scales what danger is charged and how readily a
/// hand is kept quiet, so it should move push/fold and riichi/damaten in one
/// direction each — without changing what any hand is actually worth.
void main() {
  EfficiencyReport read(
    String spec, {
    required PlayStyle style,
    List<TileType> pond = const [],
    List<TileType> dora = const [TileType.pei],
    int wall = 40,
    bool riichi = false,
  }) {
    final hand = parseTiles(spec);
    expect(hand.length, 14);
    final visible = toCounts34(hand);
    for (final t in [...pond, ...dora]) {
      visible[t.index - 1]++;
    }
    return EfficiencyEngine().analyze(
      hand: hand,
      visibleCounts34: visible,
      canRiichi: true,
      defenseHand: riichi ? hand : null,
      opponentRiichi: riichi,
      opponentDiscards: pond,
      valueContext: EfficiencyValueContext(
        melds: const [],
        roundWind: Wind.east,
        seatWind: Wind.south,
        isDealer: false,
        inRiichi: false,
        wallTilesRemaining: wall,
        doraIndicators: dora,
        style: style,
      ),
    );
  }

  group('what the dial moves', () {
    const spec = '234m 567m 234p 99s 45s 1m';
    const pond = [TileType.sou5, TileType.pin3];

    test('the more defensive the style, the dearer the same danger', () {
      double push(PlayStyle s) => read(spec, style: s, pond: pond, riichi: true)
          .lines
          .firstWhere((l) => l.shanten == 0)
          .expectedValue;

      // Same hand, same board — only what the risk is charged at changes.
      expect(push(PlayStyle.defensive), lessThan(push(PlayStyle.balanced)));
      expect(push(PlayStyle.balanced), lessThan(push(PlayStyle.aggressive)));
    });

    test('it does not change what the hand is worth', () {
      double points(PlayStyle s) =>
          read(spec, style: s, pond: pond, riichi: true)
              .lines
              .firstWhere((l) => l.shanten == 0)
              .averagePoints;
      expect(points(PlayStyle.defensive), points(PlayStyle.balanced));
      expect(points(PlayStyle.aggressive), points(PlayStyle.balanced));
    });

    test('aggressive pushes a hand the others fold', () {
      // The boundary case, on a hand where only the risk weighting can move
      // it: 345m 678m 234p 99s 45s is tenpai on 3s/6s the moment 1m goes, and
      // balanced and aggressive both land on the same RIICHI plan there. The
      // damaten gate is what would otherwise muddy this — a style whose bar
      // the hand clears is handed a lock-free damaten, which is a different
      // lever from the one under test.
      const readyAt = '345m 678m 234p 99s 45s 1m';
      EfficiencyReport at(PlayStyle s) => read(readyAt,
          style: s,
          pond: pond,
          dora: const [TileType.sou8],
          wall: 24,
          riichi: true);
      bool pushes(PlayStyle s) =>
          at(s).lines.firstWhere((l) => l.recommended).shanten == 0;

      expect(at(PlayStyle.balanced).lines.firstWhere((l) => l.shanten == 0)
          .valuePlan, at(PlayStyle.aggressive).lines
          .firstWhere((l) => l.shanten == 0).valuePlan,
          reason: 'same plan either way, so only riskWeight is in play');
      expect(pushes(PlayStyle.aggressive), isTrue);
      expect(pushes(PlayStyle.balanced), isFalse);
      expect(pushes(PlayStyle.defensive), isFalse);
    });

    test('defensive keeps a good hand quiet where the others declare', () {
      String plan(PlayStyle s) => read('123m 456m 789m 22p 45s 9s', style: s)
          .lines
          .firstWhere((l) => l.recommended)
          .valuePlan;
      // Nothing threatening here at all — the styles still differ, because
      // damaten keeps you able to fold later and riichi does not.
      expect(plan(PlayStyle.defensive), 'DAMATEN');
      expect(plan(PlayStyle.balanced), 'RIICHI');
      expect(plan(PlayStyle.aggressive), 'RIICHI');
    });
  });

  test('across many defending tables, the ordering holds', () {
    int notSafest(PlayStyle style) {
      final rng = Random(12345);
      var count = 0;
      for (var trial = 0; trial < 400; trial++) {
        final bag = <TileType>[
          for (var i = 0; i < 34; i++)
            for (var c = 0; c < 4; c++) typeFrom34(i),
        ]..shuffle(rng);
        var k = 0;
        final hand = [for (var i = 0; i < 14; i++) Tile(i, bag[k++])];
        final pond = [for (var i = 0; i < 4 + rng.nextInt(8); i++) bag[k++]];
        final dora = [bag[k++]];
        final visible = List<int>.filled(34, 0);
        for (final t in hand) {
          visible[t.type.index - 1]++;
        }
        for (final t in [...pond, ...dora]) {
          visible[t.index - 1]++;
        }
        final r = EfficiencyEngine().analyze(
          hand: hand,
          visibleCounts34: visible,
          canRiichi: true,
          defenseHand: hand,
          opponentRiichi: true,
          opponentDiscards: pond,
          valueContext: EfficiencyValueContext(
            melds: const [],
            roundWind: Wind.east,
            seatWind: Wind.south,
            isDealer: false,
            inRiichi: false,
            wallTilesRemaining: 8 + rng.nextInt(60),
            doraIndicators: dora,
            style: style,
          ),
        );
        if (r.lines.isEmpty || !r.defending || r.currentShanten <= 0) continue;
        final reco = r.lines.firstWhere((l) => l.recommended);
        final safest = r.lines
            .map((l) => l.safety?.rating ?? 0)
            .reduce((a, b) => a > b ? a : b);
        if ((reco.safety?.rating ?? 0) < safest) count++;
      }
      return count;
    }

    final defensive = notSafest(PlayStyle.defensive);
    final balanced = notSafest(PlayStyle.balanced);
    final aggressive = notSafest(PlayStyle.aggressive);
    expect(defensive, lessThanOrEqualTo(balanced),
        reason: 'defensive took the unsafe tile more often than balanced');
    expect(balanced, lessThan(aggressive),
        reason: 'aggressive did not push any more than balanced');
  });

  group('a call against a riichi is only worth it if you will push', () {
    // Ponning red reaches tenpai, but the tile it leaves you cutting is live
    // against the riichi. A style that will push it takes the call; one that
    // would fold straight afterwards gets nothing from opening up, and stays
    // closed. On a quiet board there is no danger to weigh, and the styles
    // agree.
    GuidedAction advise(
      String spec,
      PlayStyle style, {
      required List<TileType> dora,
      required int wall,
      bool riichi = true,
    }) {
      final hand = parseTiles(spec);
      final pond = parseTypes('9p 3s 6m N');
      final visible = toCounts34(hand)..[TileType.chun.index - 1] += 1;
      for (final t in [...pond, ...dora]) {
        visible[t.index - 1]++;
      }
      return EfficiencyEngine()
          .adviseCall(
            hand: hand,
            offered: Tile(999, TileType.chun),
            available: const {GuidedAction.pon},
            visibleCounts34: visible,
            context: EfficiencyValueContext(
              melds: const [],
              roundWind: Wind.east,
              seatWind: Wind.south,
              isDealer: false,
              inRiichi: false,
              wallTilesRemaining: wall,
              doraIndicators: dora,
              style: style,
            ),
            opponentRiichi: riichi,
            opponentDiscards: riichi ? pond : const [],
          )
          .recommended;
    }

    test('Defensive is the first to turn it down', () {
      // Red is dora, so the hand is worth pushing — to anyone who does not
      // charge double for the danger.
      GuidedAction at(PlayStyle s, {bool riichi = true}) =>
          advise('1m 234m 567m 78p 99s RR', s,
              dora: const [TileType.hatsu], wall: 50, riichi: riichi);
      expect(at(PlayStyle.defensive), GuidedAction.pass);
      expect(at(PlayStyle.balanced), GuidedAction.pon);
      expect(at(PlayStyle.aggressive), GuidedAction.pon);
      for (final s in PlayStyle.values) {
        expect(at(s, riichi: false), GuidedAction.pon,
            reason: '${s.label} turned it down with nothing to fear');
      }
    });

    test('Aggressive is the last to', () {
      // No dora and little wall left: only the style that halves the danger
      // still finds the push worth it.
      GuidedAction at(PlayStyle s) => advise('9m 234m 567m 78p 99s RR', s,
          dora: const [TileType.pei], wall: 14);
      expect(at(PlayStyle.defensive), GuidedAction.pass);
      expect(at(PlayStyle.balanced), GuidedAction.pass);
      expect(at(PlayStyle.aggressive), GuidedAction.pon);
    });
  });

  testWidgets('the game exposes the dial and it drives the guide',
      (tester) async {
    await tester.binding.setSurfaceSize(kDesignSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Start'));
    await tester.pump(const Duration(milliseconds: 100));

    // Read off the button itself: the bar carries two dials now, and they both
    // start on a setting called "Balanced".
    expect(labelOf(const Key('playStyle')), 'Balanced');
    expect(labelOf(const Key('handFocus')), 'Balanced');

    await tester.tap(find.byKey(const Key('playStyle')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(labelOf(const Key('playStyle')), 'Aggressive');
    expect(labelOf(const Key('handFocus')), 'Balanced',
        reason: 'cycling one dial moved the other');

    await tester.tap(find.byKey(const Key('playStyle')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(labelOf(const Key('playStyle')), 'Defensive');

    // And the focus dial cycles on its own.
    await tester.tap(find.byKey(const Key('handFocus')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(labelOf(const Key('handFocus')), 'Value');
    expect(labelOf(const Key('playStyle')), 'Defensive');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('the setting reaches the guide, and so Autoplay', (tester) async {
    // Autoplay plays the guide's recommended line, so proving the setting
    // changes the report proves it changes Autoplay.
    Sfx.i.enabled = false;
    final game = GameController(seed: 7);
    try {
      final round = game.round;
      // Put a riichi opponent out so the risk terms are live.
      round.seats[1].riichi = true;
      round.seats[1].pond.add(Tile(800, TileType.pin9));
      round.seats[1].allDiscards.add(round.seats[1].pond.last);
      round.seats[kHumanSeat].hand =
          parseTiles('1m 234m 567m 99s 78p 33p W 5s');
      round.turn = kHumanSeat;
      round.phase = RoundPhase.discarding;

      double topEv(PlayStyle style) {
        game.setPlayStyle(style);
        return game.report.lines
            .firstWhere((l) => l.recommended)
            .expectedValue;
      }

      final defensive = topEv(PlayStyle.defensive);
      final balanced = topEv(PlayStyle.balanced);
      final aggressive = topEv(PlayStyle.aggressive);
      expect(game.playStyle, PlayStyle.aggressive);
      expect({defensive, balanced, aggressive}.length, 3,
          reason: 'the style did not reach the report at all');
      expect(defensive, lessThan(aggressive));
    } finally {
      game.dispose();
      Sfx.i.enabled = true;
    }
  });

  testWidgets('the builder exposes it too', (tester) async {
    await tester.binding.setSurfaceSize(kDesignSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('openBuilder')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(labelOf(const Key('builderPlayStyle')), 'Balanced');
    await tester.tap(find.byKey(const Key('builderPlayStyle')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(labelOf(const Key('builderPlayStyle')), 'Aggressive');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('the guide carries a synced copy of the dial', (tester) async {
    await tester.binding.setSurfaceSize(kDesignSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Start'));
    await tester.pump(const Duration(milliseconds: 100));
    // The guide is off by default; the clefairy mark opens it.
    await tester.tap(find.byKey(const Key('guideToggle')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(labelOf(const Key('playStyle')), 'Balanced');

    // Guide -> app bar.
    await tester.tap(find.byKey(const Key('guidePlayStyle_aggressive')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(labelOf(const Key('playStyle')), 'Aggressive');

    // App bar -> guide: cycling past aggressive lands on defensive, and the
    // guide's own chip has to be the one showing as picked.
    await tester.tap(find.byKey(const Key('playStyle')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(labelOf(const Key('playStyle')), 'Defensive');
    expect(guideChipPicked(tester, PlayStyle.defensive), isTrue);
    expect(guideChipPicked(tester, PlayStyle.aggressive), isFalse);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('rotating to portrait and back keeps the same match',
      (tester) async {
    // The gate reads MediaQuery, which follows the view rather than
    // setSurfaceSize — so drive the view here.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = kDesignSize;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Start'));
    await tester.pump(const Duration(milliseconds: 100));

    // Move the dial off its default so we can tell a surviving match from a
    // freshly built one.
    await tester.tap(find.byKey(const Key('playStyle')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(labelOf(const Key('playStyle')), 'Aggressive');

    // Portrait: the rotate prompt covers the table, and the welcome screen
    // must not come back.
    tester.view.physicalSize = Size(kDesignSize.height, kDesignSize.width);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Rotate your device'), findsOneWidget);

    // Back to landscape: same match, same setting, no welcome screen.
    tester.view.physicalSize = kDesignSize;
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Rotate your device'), findsNothing);
    expect(find.text('Start'), findsNothing);
    expect(labelOf(const Key('playStyle')), 'Aggressive');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}

/// The label a cycling play-style button is currently showing.
String labelOf(Key key) => (find
        .descendant(of: find.byKey(key), matching: find.byType(Text))
        .evaluate()
        .first
        .widget as Text)
    .data!;

/// Whether the guide panel's chip for [style] is rendering as the picked one —
/// picked chips draw their label in the style's own colour, the rest grey out.
bool guideChipPicked(WidgetTester tester, PlayStyle style) {
  final text = tester.widget<Text>(find.descendant(
    of: find.byKey(Key('guidePlayStyle_${style.name}')),
    matching: find.byType(Text),
  ));
  return text.style?.color == playStyleColor(style);
}
