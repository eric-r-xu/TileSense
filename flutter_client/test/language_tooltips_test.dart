import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/tile.dart';
import 'package:tilesense/l10n/app_language.dart';
import 'package:tilesense/l10n/l10n.dart';
import 'package:tilesense/logic/efficiency_engine.dart';
import 'package:tilesense/scenario/scenario_controller.dart';
import 'package:tilesense/ui/efficiency_overlay.dart';
import 'package:tilesense/ui/tilesensor.dart';

import 'helpers.dart';
import 'l10n_helpers.dart';

void main() {
  tearDown(() => AppLanguageController.instance.select(AppLanguage.english));

  testWidgets(
      'mascot tooltip changes language in place, keeping brand emphasis',
      (tester) async {
    await pumpLocalized(
        tester,
        const Scaffold(
          body: TileSensorTooltip(child: Text('mascot')),
        ));
    for (final language in [...AppLanguage.values, AppLanguage.english]) {
      AppLanguageController.instance.select(language);
      await tester.pumpAndSettle();
      final l10n = lookupAppLocalizations(language.locale);
      final tip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tip.richMessage!.toPlainText(),
          l10n.mascotIntro('TileSensor', 'TileSense'));
      final runs = (tip.richMessage! as TextSpan)
          .children!
          .whereType<TextSpan>()
          .where((s) => s.style?.fontWeight == FontWeight.w800);
      expect(runs.map((s) => s.text), ['TileSensor', 'TileSense']);
      tester.state<TooltipState>(find.byType(Tooltip)).ensureTooltipVisible();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      Tooltip.dismissAllToolTips();
      await tester.pump(const Duration(milliseconds: 300));
    }
  });

  for (final ruleset in Ruleset.values) {
    testWidgets('${ruleset.name}: guide tooltips follow language changes',
        (tester) async {
      final game = ScenarioController()..setRuleset(ruleset);
      final hand = parseTiles('1m 234m 567m 99s 78p 3p W 5s');
      final report = EfficiencyEngine().analyze(
        hand: hand,
        defenseHand: hand,
        visibleCounts34: toCounts34(hand),
        canRiichi: false,
        opponentRiichi: true,
        opponentDiscards: const [TileType.man1],
        valueContext: EfficiencyValueContext(
          melds: const [],
          roundWind: Wind.east,
          seatWind: Wind.east,
          isDealer: true,
          inRiichi: false,
          wallTilesRemaining: 40,
          doraIndicators: const [],
          ruleset: ruleset,
        ),
      );
      await pumpLocalized(
          tester,
          Scaffold(
            body: Align(
                alignment: Alignment.topLeft,
                child: EfficiencyOverlay(game: game, report: report)),
          ));
      final state = tester.state(find.byType(EfficiencyOverlay));
      for (final language in [...AppLanguage.values, AppLanguage.english]) {
        AppLanguageController.instance.select(language);
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(EfficiencyOverlay)), same(state),
            reason: 'tooltips must refresh without recreating the guide');
        final l10n = lookupAppLocalizations(language.locale);
        final tips = tester.widgetList<Tooltip>(find.byType(Tooltip)).toList();
        final text = tips
            .map((t) => t.richMessage?.toPlainText() ?? t.message!)
            .join('\n');
        expect(text, contains(l10n.guideGreenBody));
        expect(text, contains(l10n.tipFinishBody));
        expect(text, contains(l10n.tipOrdinaryNote));
        expect(text, contains(l10n.tipDetailBody));
        expect(text, contains(l10n.tipHmrBody));
        expect(
            text,
            contains(l10n.tipRiskBody(ruleset.isHongKong
                ? '${l10n.tipChipsUnit[0].toUpperCase()}${l10n.tipChipsUnit.substring(1)}'
                : '${l10n.tipPointsUnit[0].toUpperCase()}${l10n.tipPointsUnit.substring(1)}')));
        if (!ruleset.isChineseStyle) {
          expect(text, contains(l10n.tipYakuBody));
        }
        if (language != AppLanguage.english) {
          for (final english in [
            'How many tiles',
            'What Mortal',
            'How safe',
            'The average',
            'Each bar:',
            'Higher is better',
            'WHAT THE WIN PAYS'
          ]) {
            expect(text, isNot(contains(english)));
          }
        }
        expect(
            text, contains(l10n.tipThisCut(report.lines.first.discard.code)));
        expect(
            text,
            contains(l10n.tipRankBody(
              l10n.tipRankOrder('TileSense EV', l10n.tipHigherFirst),
              l10n.tipRankOrder(
                  ruleset.isChineseStyle
                      ? l10n.tipAwayLabel
                      : l10n.tipShantenLabel,
                  l10n.tipLowerFirst),
              l10n.tipRankOrder(
                  ruleset.isChineseStyle
                      ? l10n.tipAcceptsLabel
                      : l10n.tipUkeireLabel,
                  l10n.tipHigherFirst),
            )));
        final safety = find.byWidgetPredicate((w) =>
            w is Tooltip &&
            (w.richMessage?.toPlainText().startsWith(l10n.tipSafetyTitle) ??
                false));
        expect(safety, findsOneWidget);
        tester.state<TooltipState>(safety).ensureTooltipVisible();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text(l10n.tipRating), findsOneWidget);
        expect(
            find.text(
                ruleset.isChineseStyle ? l10n.tipHkRating14 : l10n.tipRating15),
            findsOneWidget);
        expect(find.text(ruleset.isChineseStyle ? '14' : '15'), findsWidgets);
        expect(tester.takeException(), isNull);
        Tooltip.dismissAllToolTips();
        await tester.pump(const Duration(milliseconds: 300));
        if (!ruleset.isChineseStyle) {
          final placement = find.byWidgetPredicate((w) =>
              w is Tooltip &&
              (w.richMessage
                      ?.toPlainText()
                      .startsWith(l10n.tipPlacementTitle) ??
                  false));
          tester.state<TooltipState>(placement.first).ensureTooltipVisible();
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text(l10n.tipEven), findsOneWidget);
          expect(find.textContaining(l10n.mathSpread), findsWidgets);
          expect(find.text('+8,000'), findsOneWidget);
          expect(tester.takeException(), isNull);
          Tooltip.dismissAllToolTips();
          await tester.pump(const Duration(milliseconds: 300));
        }
      }
      await tester.pumpWidget(const SizedBox());
      game.dispose();
    });
  }
}
