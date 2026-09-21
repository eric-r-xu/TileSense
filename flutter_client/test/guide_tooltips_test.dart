import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/tile.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/logic/efficiency_engine.dart';
import 'package:tilesense/logic/placement_utility.dart';
import 'package:tilesense/ui/efficiency_overlay.dart';
import 'package:tilesense/ui/ev_explainer_dialog.dart';

import 'helpers.dart';

/// The guide's headings and dials each explain themselves in a tooltip, in
/// place of the glossary that used to sit under the table — bulleted, with a
/// real table wherever a reference table is in play, and with the engine's own
/// numbers rather than copies.
void main() {
  EfficiencyValueContext context({Ruleset ruleset = Ruleset.riichi}) =>
      EfficiencyValueContext(
        melds: const [],
        roundWind: Wind.east,
        seatWind: Wind.east,
        isDealer: true,
        inRiichi: false,
        wallTilesRemaining: 40,
        doraIndicators: const [],
        ruleset: ruleset,
      );

  /// A hand facing a live riichi, so the safety columns have something to say.
  EfficiencyReport defending() {
    final hand = parseTiles('1m 234m 567m 99s 78p 3p W 5s');
    return EfficiencyEngine().analyze(
      hand: hand,
      defenseHand: hand,
      visibleCounts34: toCounts34(hand),
      canRiichi: false,
      opponentRiichi: true,
      opponentDiscards: const [TileType.man1],
      valueContext: context(),
    );
  }

  /// A hand with nobody to defend against.
  EfficiencyReport quiet({Ruleset ruleset = Ruleset.riichi}) {
    final hand = parseTiles('123m 456m 789m 34p 55p 9s');
    return EfficiencyEngine().analyze(
      hand: hand,
      visibleCounts34: toCounts34(hand),
      canRiichi: true,
      valueContext: context(ruleset: ruleset),
    );
  }

  Future<void> withPanel(
    WidgetTester tester,
    Future<void> Function(GameController game) body, {
    bool showGameControls = true,
    EfficiencyReport? report,
    Ruleset ruleset = Ruleset.riichi,
  }) async {
    Sfx.i.enabled = false;
    final game = GameController(seed: 1);
    try {
      if (ruleset.isHongKong) game.setRuleset(ruleset);
      game.round.seats[1].riichi = true;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: EfficiencyOverlay(
              game: game,
              report: report ?? defending(),
              showGameControls: showGameControls,
            ),
          ),
        ),
      ));
      await body(game);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      game.dispose();
      Sfx.i.enabled = true;
    }
  }

  Finder tooltipTitled(String title) => find.byWidgetPredicate((w) =>
      w is Tooltip &&
      (w.richMessage?.toPlainText().startsWith('$title\n') ?? false));

  /// Opens the tooltip whose text starts with [title], so its table cells and
  /// bullets are actually on screen to be read.
  Future<void> openTip(WidgetTester tester, String title) async {
    Tooltip.dismissAllToolTips();
    await tester.pump();
    final finder = tooltipTitled(title);
    expect(finder, findsWidgets, reason: 'no tooltip titled $title');
    tester.state<TooltipState>(finder.first).ensureTooltipVisible();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Finder text(String s) => find.textContaining(s);

  String thousands(num v) {
    final n = v.round();
    final digits = n.abs().toString();
    final buf = StringBuffer(n < 0 ? '-' : '');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  String rate(double v) => '${(v * 100).toStringAsFixed(1)}%';
  String signed(double v) =>
      '${v < 0 ? '−' : '+'}${v.abs().toStringAsFixed(2)}';

  testWidgets('the glossary under the table is gone', (tester) async {
    await withPanel(tester, (_) async {
      expect(find.textContaining('• '), findsNothing);
      expect(find.textContaining('Esc — pause'), findsNothing);
      expect(find.textContaining('Green tile'), findsNothing);
    });
  });

  testWidgets('every heading that names a concept carries its own tooltip',
      (tester) async {
    await withPanel(tester, (_) async {
      const headings = {
        'Shanten': 'SHANTEN',
        'Ukeire': 'UKEIRE',
        'TileSense EV': 'TILESENSE EV',
        'EV (HMR)': 'EV (HMR)',
        'Placement': 'PLACEMENT',
        'Safety': 'SAFETY',
        'Risk': 'RISK',
        'Detail': 'DETAIL',
      };
      for (final entry in headings.entries) {
        final tip = find.ancestor(
            of: find.text(entry.key), matching: find.byType(Tooltip));
        expect(tip, findsWidgets, reason: '${entry.key} has no tooltip');
        final message =
            (tester.widget<Tooltip>(tip.first).richMessage as TextSpan)
                .toPlainText();
        expect(message, startsWith('${entry.value}\n'),
            reason: '${entry.key} should explain itself');
      }
    });
  });

  group('the Safety section is always there', () {
    testWidgets('with nobody to defend against, riichi', (tester) async {
      await withPanel(tester, (_) async {
        final report = quiet();
        expect(report.defending, isFalse, reason: 'fixture must be quiet');
        for (final heading in ['Safety', 'Risk', 'Detail']) {
          expect(find.text(heading), findsOneWidget,
              reason: '$heading is missing while nothing is defended against');
          expect(
              find.ancestor(
                  of: find.text(heading), matching: find.byType(Tooltip)),
              findsWidgets);
        }
        // Their cells read "—" rather than the columns vanishing: one each of
        // Safety, Risk and Detail per row.
        expect(find.text('—'), findsNWidgets(3 * report.lines.length));
      }, report: quiet());
    });

    testWidgets('and still with a riichi to defend against', (tester) async {
      await withPanel(tester, (_) async {
        for (final heading in ['Safety', 'Risk', 'Detail']) {
          expect(find.text(heading), findsOneWidget);
        }
      });
    });

    testWidgets('and under Hong Kong rules', (tester) async {
      await withPanel(tester, (_) async {
        for (final heading in ['Away', 'Accepts', 'Safety', 'Risk', 'Detail']) {
          expect(find.text(heading), findsOneWidget,
              reason: '$heading missing under Hong Kong');
        }
        await openTip(tester, 'SAFETY');
        expect(text('How risky a tile is to cut'), findsOneWidget);
        expect(text('no furiten'), findsOneWidget);
        expect(text('${HongKongGuideTuning.threatExposedSets} or more'),
            findsOneWidget);
        // The Hong Kong rating table: honors by copies unseen, terminals,
        // suit tiles — and never a certain 0.0%.
        expect(find.text('Terminal'), findsOneWidget);
        expect(find.text('Suit tile'), findsOneWidget);
        expect(find.text('Honor, none unseen'), findsOneWidget);
        expect(find.text('0.0%'), findsNothing,
            reason: 'nothing is certainly safe in Hong Kong');
        expect(text('16 chips'), findsWidgets);
      }, report: quiet(ruleset: Ruleset.hongKong), ruleset: Ruleset.hongKong);
    });

    testWidgets('the table still fits the panel with all three columns',
        (tester) async {
      await withPanel(tester, (_) async {
        // The table's fixed columns must fit inside the panel's padding, or it
        // spills over the panel's border.
        final panel = tester.getSize(find
            .descendant(
                of: find.byType(EfficiencyOverlay),
                matching: find.byType(Container))
            .first);
        final table = tester.getSize(find.byType(Table).first);
        // The panel pads 12px each side.
        expect(panel.width, greaterThan(400), reason: 'measured the panel');
        expect(table.width, lessThanOrEqualTo(panel.width - 24 + 0.01),
            reason: 'table ${table.width} vs panel ${panel.width}');
      }, report: quiet());
    });
  });

  testWidgets('STYLE reads as bullets and a table, with the live numbers',
      (tester) async {
    await withPanel(tester, (_) async {
      await openTip(tester, 'STYLE');
      expect(text('How much danger the guide will take on'), findsOneWidget);
      // Bullets.
      expect(text('folds sooner, and stays quiet on cheaper hands'),
          findsOneWidget);
      expect(text('pushes further, and declares riichi more often'),
          findsOneWidget);
      expect(
          text('this dial is hidden and pinned to Balanced'), findsOneWidget);
      // Table: every style, its weights, and what it works out to.
      for (final style in PlayStyle.values) {
        // At least the dial's chip and the table row ('Balanced' is also a
        // Focus chip).
        expect(find.text(style.label), findsAtLeastNWidgets(2));
        // ('×2.00' is both Defensive's risk weight and Aggressive's bar.)
        expect(
            find.text('×${style.riskWeight.toStringAsFixed(2)}'), findsWidgets);
        expect(
            find.text('×${style.damatenBar.toStringAsFixed(2)}'), findsWidgets);
        final quietFrom =
            '${thousands(GuideConstants.damatenMinPoints * style.damatenBar)} '
            '(${thousands(GuideConstants.dealerDamatenMinPoints * style.damatenBar)} dealer)';
        expect(find.text(quietFrom), findsOneWidget);
      }
      expect(find.text('Risk weight'), findsWidgets);
      expect(find.text('Stays quiet from'), findsOneWidget);
    });
  });

  testWidgets('FOCUS shows what Speed does as a table, in the live numbers',
      (tester) async {
    await withPanel(tester, (_) async {
      await openTip(tester, 'FOCUS');
      expect(
          text('Which hand to chase when two lines are close'), findsOneWidget);
      expect(text('prefers the likelier cheap hand'), findsOneWidget);
      expect(text('no tilt: plain chance × payout'), findsOneWidget);
      const speed = HandFocus.speed;
      for (final pts in [2000.0, 5000.0, 8000.0, 16000.0]) {
        expect(find.text(thousands(speed.worth(pts))), findsWidgets,
            reason: 'Speed counts $pts as ${speed.worth(pts)}');
      }
      for (final chance in [0.05, 0.15, 0.25, 0.5]) {
        expect(find.text(rate(speed.chanceWorth(chance))), findsWidgets);
      }
      // The exponent is a real superscript, not a caret in the text.
      expect(find.text('${speed.curve}'), findsOneWidget);
      expect(text('^${speed.curve}'), findsNothing);
    });
  });

  testWidgets('formulas are one line each, with real sub- and superscripts',
      (tester) async {
    await withPanel(tester, (_) async {
      await openTip(tester, 'PLACEMENT');
      // Every equation is a single unwrapped line, however long.
      for (final lead in ['worth(gain) = ', 'u(score) = ', 'spread = ']) {
        final eq = find.textContaining(lead);
        expect(eq, findsOneWidget, reason: lead);
        expect(tester.widget<Text>(eq).softWrap, isFalse);
      }
      // "3 other seats" hangs below the sum as a subscript widget.
      expect(find.text('3 other seats'), findsOneWidget);
    });
  });

  testWidgets('the shanten tooltip only says what 0 means', (tester) async {
    await withPanel(tester, (_) async {
      final tip = find.byWidgetPredicate((w) =>
          w is Tooltip &&
          (w.richMessage?.toPlainText().startsWith('SHANTEN\n') ?? false));
      final text = (tester.widget<Tooltip>(tip.first).richMessage as TextSpan)
          .toPlainText();
      expect(text, contains('(0 means tenpai)'));
      expect(text, isNot(contains('Higher')));
      expect(text, isNot(contains('win')));
    });
  });

  testWidgets('FOCUS uses chips under Hong Kong', (tester) async {
    await withPanel(tester, (_) async {
      await openTip(tester, 'FOCUS');
      expect(text('32 chips'), findsOneWidget, reason: 'the HK pivot');
      expect(text('5,000'), findsNothing);
      expect(find.text('Payout'), findsOneWidget);
    }, report: quiet(ruleset: Ruleset.hongKong), ruleset: Ruleset.hongKong);
  });

  testWidgets('STRATEGY is a small table plus bullets', (tester) async {
    await withPanel(tester, (_) async {
      await openTip(tester, 'STRATEGY');
      // Once as the dial's chip, once as the table row.
      expect(find.text('Points'), findsNWidgets(2));
      expect(find.text('Placement'), findsWidgets);
      expect(find.text('what it pays, on average'), findsOneWidget);
      expect(text('finishing above each other seat'), findsOneWidget);
      expect(text('Style and Focus'), findsOneWidget);
      expect(text('always Points — this dial is hidden'), findsOneWidget);
    });
  });

  testWidgets(
      'PLACEMENT tables what 8,000 points is worth, from the real model',
      (tester) async {
    await withPanel(tester, (_) async {
      await openTip(tester, 'PLACEMENT');
      expect(text('How a line moves your chance of finishing'), findsOneWidget);
      expect(text('scaled up ×1,000'), findsOneWidget);
      expect(text('not a simulation'), findsOneWidget);

      double gain(List<int> table, int hands, double pts) =>
          PlacementUtility(tablePoints: table, mySeat: 0, handsRemaining: hands)
              .valueOf(pts);
      final even = gain(const [25000, 25000, 25000, 25000], 8, 8000);
      final lead = gain(const [45000, 20000, 18000, 17000], 8, 8000);
      expect(find.text(signed(even)), findsWidgets);
      expect(find.text(signed(lead)), findsWidgets);
      expect(find.text(signed(-even)), findsWidgets);
      for (final scene in [
        'Even table',
        'Big lead',
        'Far behind',
        'Even table, last hand',
        'Big lead, last hand',
      ]) {
        expect(find.text(scene), findsOneWidget);
      }
      expect(lead, lessThan(even),
          reason: 'a big lead should make the same points worth less');
      expect(text('spread'), findsWidgets);
    });
  });

  testWidgets('SAFETY tables the deal-in chance for each rating, riichi',
      (tester) async {
    await withPanel(tester, (_) async {
      await openTip(tester, 'SAFETY');
      expect(
          text('How safe a tile is to cut against a riichi'), findsOneWidget);
      expect(text('cannot win their hand'), findsOneWidget);
      for (final (r, label) in const [
        (15, 'Genbutsu — already discarded by that player'),
        (13, 'Honor, 1 live'),
        (12, 'Double suji'),
        (2, 'Non-suji middle tile'),
      ]) {
        expect(find.text(label), findsOneWidget);
        expect(find.text('$r'), findsWidgets);
        expect(find.text(rate(GuideConstants.dealInRate(r))), findsWidgets);
      }
      expect(GuideConstants.dealInRate(0), 0.07);
      expect(GuideConstants.dealInRate(15), 0.0);
      expect(text('5,800'), findsOneWidget);
      expect(text('8,700'), findsOneWidget);
    });
  });

  testWidgets('RISK lists what goes into it, riichi and Hong Kong',
      (tester) async {
    await withPanel(tester, (_) async {
      await openTip(tester, 'RISK');
      expect(text('from the tile\'s Safety rating'), findsOneWidget);
      expect(text('${(GuideConstants.pushCommitment * 100).round()}%'),
          findsWidgets);
      expect(text('${GuideConstants.riichiPushHorizon}'), findsOneWidget);
      expect(text('Style weight'), findsWidgets);
      for (final style in PlayStyle.values) {
        expect(text(style.riskWeight.toStringAsFixed(2)), findsWidgets);
      }
    });
    await withPanel(tester, (_) async {
      await openTip(tester, 'RISK');
      expect(text('16 chips'), findsWidgets);
      expect(text('Style weight'), findsNothing,
          reason: 'there is no Style dial under Hong Kong');
    }, report: quiet(ruleset: Ruleset.hongKong), ruleset: Ruleset.hongKong);
  });

  testWidgets('UKEIRE tables the typical width, in both rulesets',
      (tester) async {
    await withPanel(tester, (_) async {
      await openTip(tester, 'UKEIRE');
      for (final v in GuideConstants.typicalUkeire) {
        expect(find.text(v.round().toString()), findsWidgets);
      }
      expect(find.text('Shanten'), findsWidgets);
      expect(text('Means, not medians'), findsOneWidget);
      expect(find.textContaining('Ending first'), findsNothing,
          reason: 'the end-of-hand rate is explained under TileSense EV');
    });
    await withPanel(tester, (_) async {
      await openTip(tester, 'ACCEPTS');
      expect(text('bring you closer to ready'), findsOneWidget);
      expect(find.text('43'), findsWidgets);
    }, report: quiet(ruleset: Ruleset.hongKong), ruleset: Ruleset.hongKong);
  });

  testWidgets(
      'EV (HMR) sits left of TileSense EV, and TileSense EV says what EV is',
      (tester) async {
    await withPanel(tester, (_) async {
      expect(find.text('Expected Value'), findsNothing);
      expect(tester.getTopLeft(find.text('EV (HMR)')).dx,
          lessThan(tester.getTopLeft(find.text('TileSense EV')).dx));
      final message = (tester
              .widget<Tooltip>(tooltipTitled('TILESENSE EV').first)
              .richMessage as TextSpan)
          .toPlainText();
      expect(message, contains('(EV = Expected Value)'));
    });
  });

  testWidgets('the EV (HMR) tooltip links to the HMR write-up', (tester) async {
    await withPanel(tester, (_) async {
      final span = (tester
          .widget<Tooltip>(tooltipTitled('EV (HMR)').first)
          .richMessage as TextSpan);
      TextSpan? link;
      span.visitChildren((s) {
        if (s is TextSpan && s.recognizer != null) link = s;
        return true;
      });
      expect(link, isNotNull, reason: 'an embedded, tappable link');
      expect(link!.text, contains('Hitori Mahjong Renshuuki'));
    });
  });

  testWidgets('the TileSense EV tooltip points at where each part is worked',
      (tester) async {
    await withPanel(tester, (_) async {
      final message = (tester
              .widget<Tooltip>(tooltipTitled('TILESENSE EV').first)
              .richMessage as TextSpan)
          .toPlainText();
      expect(message, contains('hover Ukeire'));
      expect(message, contains('hover Risk and Safety'));
      expect(message, contains('hover FOCUS'));
      expect(message, contains('tap the EV (HMR) number'));
    });
  });

  testWidgets('the GUIDE title keeps the legend that has no heading',
      (tester) async {
    await withPanel(tester, (_) async {
      await openTip(tester, 'GUIDE');
      expect(text('the recommended discard'), findsOneWidget);
      expect(text('the tile you just drew'), findsOneWidget);
      expect(text('pause the game'), findsOneWidget);
    });
    await withPanel(tester, (_) async {
      await openTip(tester, 'GUIDE');
      expect(text('the recommended discard'), findsOneWidget);
      expect(text('pause the game'), findsNothing,
          reason: 'the scenario builder has no pause key');
    }, showGameControls: false);
  });

  testWidgets('Hong Kong words its headings and hides the riichi-only dials',
      (tester) async {
    await withPanel(tester, (_) async {
      for (final entry in {'Away': 'AWAY', 'Accepts': 'ACCEPTS'}.entries) {
        final tip = find.ancestor(
            of: find.text(entry.key), matching: find.byType(Tooltip));
        expect(tip, findsWidgets, reason: '${entry.key} has no tooltip');
        expect(
            (tester.widget<Tooltip>(tip.first).richMessage as TextSpan)
                .toPlainText(),
            startsWith('${entry.value}\n'));
      }
      // Style and Strategy have nothing to weigh under Hong Kong rules;
      // Placement is not wired up for it either.
      expect(find.text('STYLE'), findsNothing);
      expect(find.text('STRATEGY'), findsNothing);
      expect(find.text('Placement'), findsNothing);
      expect(find.text('FOCUS'), findsOneWidget);
      expect(find.textContaining('• '), findsNothing);
    }, report: quiet(ruleset: Ruleset.hongKong), ruleset: Ruleset.hongKong);
  });

  testWidgets('the tap-through page shows the payout heuristic before tenpai',
      (tester) async {
    Sfx.i.enabled = false;
    try {
      final hand = parseTiles('1m 4m 7m 1p 4p 7p 1s 4s 7s E S W N R');
      final report = EfficiencyEngine().analyze(
        hand: hand,
        visibleCounts34: toCounts34(hand),
        canRiichi: false,
        valueContext: context(),
      );
      final far = report.lines.first;
      expect(far.shanten, greaterThan(0));
      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: EvExplainerDialog(line: far))));
      final note =
          tester.widget<Text>(find.byKey(const Key('ev-payout-heuristic')));
      expect(note.data, contains('${GuideConstants.doraValueMultiple}'));
      expect(note.data, contains('3,900'));
      expect(note.data, contains('5,800'));

      // Hong Kong quotes its own basis instead.
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: EvExplainerDialog(line: far, hongKong: true))));
      final hk =
          tester.widget<Text>(find.byKey(const Key('ev-payout-heuristic')));
      expect(hk.data, contains('flush'));
      expect(hk.data, isNot(contains('3,900')));
    } finally {
      Sfx.i.enabled = true;
    }
  });
}
