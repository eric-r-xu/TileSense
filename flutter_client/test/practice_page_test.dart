import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/tile.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/l10n/app_language.dart';
import 'package:tilesense/logic/practice_drills.dart';
import 'package:tilesense/main.dart';
import 'package:tilesense/ui/practice_page.dart';
import 'package:tilesense/ui/tile_face.dart';

import 'l10n_helpers.dart';

/// The practice hands as a player meets them: answer, see why, move on.
void main() {
  setUp(() => Sfx.i.enabled = false);
  tearDown(() => Sfx.i.enabled = true);

  Future<void> pumpPage(WidgetTester tester, Ruleset r,
          {Size size = const Size(1600, 820)}) =>
      pumpLocalized(
          tester, PracticePage(ruleset: r, onExit: () {}),
          size: size);

  String text(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data!;

  /// Taps [target], scrolled into view first: on a short window the Back
  /// footer leaves the question less room, and it scrolls.
  Future<void> tapVisible(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.tap(target);
  }

  /// A wrong answer for [d], where there is one to give.
  Future<void> answerWrong(WidgetTester tester, PracticeDrill d) async {
    switch (d.kind) {
      case DrillKind.winningTile:
        final wrong = d.optionTiles.firstWhere((t) => !d.isWinningTile(t));
        await tapVisible(
            tester, find.byKey(Key('practiceOption_${wrong.code}')));
      case DrillKind.discard:
        final i = d.hand.indexWhere((t) => !d.discardLeavesReady(t));
        await tapVisible(tester, find.byKey(Key('practiceTile_$i')));
      case DrillKind.claim:
        final wrong =
            ClaimChoice.values.firstWhere((c) => c != d.correctClaim);
        await tapVisible(
            tester, find.byKey(Key('practiceClaim_${wrong.name}')));
    }
    await tester.pump();
  }

  Future<void> answerRight(WidgetTester tester, PracticeDrill d) async {
    switch (d.kind) {
      case DrillKind.winningTile:
        final right = d.optionTiles.firstWhere(d.isWinningTile);
        await tester.tap(find.byKey(Key('practiceOption_${right.code}')));
      case DrillKind.discard:
        final i = d.hand.indexWhere(d.discardLeavesReady);
        await tester.tap(find.byKey(Key('practiceTile_$i')));
      case DrillKind.claim:
        await tester
            .tap(find.byKey(Key('practiceClaim_${d.correctClaim.name}')));
    }
    await tester.pump();
  }

  testWidgets('answering every question right scores them all',
      (tester) async {
    await pumpPage(tester, Ruleset.hongKong);
    final drills = practiceDrillsFor(Ruleset.hongKong);
    for (final (i, d) in drills.indexed) {
      expect(text(tester, 'practiceProgress'), '${i + 1} of ${drills.length}');
      expect(find.byKey(const Key('practiceFeedback')), findsNothing);
      await answerRight(tester, d);
      expect(text(tester, 'practiceVerdict'), 'Correct!', reason: d.id);
      expect(text(tester, 'practiceWhy'), isNotEmpty, reason: d.id);
      await tester.tap(find.byKey(const Key('practiceNext')));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: d.id);
    }
    expect(text(tester, 'practiceResult'),
        'You got ${drills.length} of ${drills.length} right.');
  });

  testWidgets('a wrong answer says so, and marks the right one',
      (tester) async {
    await pumpPage(tester, Ruleset.hongKong);
    final d = practiceDrillsFor(Ruleset.hongKong).first;
    await answerWrong(tester, d);
    expect(text(tester, 'practiceVerdict'), 'Not quite.');

    Color? colourOf(TileType t) => tester
        .widget<TileFace>(find.descendant(
            of: find.byKey(Key('practiceOption_${t.code}')),
            matching: find.byType(TileFace)))
        .highlightColor;
    final right = d.optionTiles.firstWhere(d.isWinningTile);
    final wrong = d.optionTiles.firstWhere((t) => !d.isWinningTile(t));
    expect(colourOf(right), const Color(0xff43a047));
    expect(colourOf(wrong), const Color(0xffe53935));
  });

  testWidgets('the first answer stands, and the score counts only the right',
      (tester) async {
    await pumpPage(tester, Ruleset.hongKong);
    final drills = practiceDrillsFor(Ruleset.hongKong);
    await answerWrong(tester, drills.first);
    // A second tap on the right tile changes nothing.
    final right = drills.first.optionTiles.firstWhere(drills.first.isWinningTile);
    await tester.tap(find.byKey(Key('practiceOption_${right.code}')),
        warnIfMissed: false);
    await tester.pump();
    expect(text(tester, 'practiceVerdict'), 'Not quite.');

    await tester.tap(find.byKey(const Key('practiceNext')));
    await tester.pump();
    for (final d in drills.skip(1)) {
      await answerRight(tester, d);
      await tester.tap(find.byKey(const Key('practiceNext')));
      await tester.pump();
    }
    expect(text(tester, 'practiceResult'),
        'You got ${drills.length - 1} of ${drills.length} right.');

    await tester.tap(find.byKey(const Key('practiceAgain')));
    await tester.pump();
    expect(text(tester, 'practiceProgress'), '1 of ${drills.length}');
    expect(find.byKey(const Key('practiceFeedback')), findsNothing);
  });

  testWidgets('the call drills use the ruleset\'s own words', (tester) async {
    for (final (r, chow, pung) in [
      (Ruleset.hongKong, 'Chow', 'Pung'),
      (Ruleset.riichi, 'Chi', 'Pon'),
    ]) {
      await pumpPage(tester, r);
      final drills = practiceDrillsFor(r);
      for (final d in drills.takeWhile((d) => d.kind != DrillKind.claim)) {
        await answerRight(tester, d);
        await tester.tap(find.byKey(const Key('practiceNext')));
        await tester.pump();
      }
      expect(find.text(chow), findsOneWidget, reason: r.name);
      expect(find.text(pung), findsOneWidget, reason: r.name);
      expect(find.text('Pass'), findsOneWidget, reason: r.name);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('Sichuan gets fewer questions and no chow', (tester) async {
    await pumpPage(tester, Ruleset.sichuan);
    expect(text(tester, 'practiceProgress'), '1 of 5');
    final drills = practiceDrillsFor(Ruleset.sichuan);
    for (final d in drills) {
      if (d.kind == DrillKind.claim) {
        expect(find.byKey(const Key('practiceClaim_chow')), findsNothing);
      }
      await answerRight(tester, d);
      await tester.tap(find.byKey(const Key('practiceNext')));
      await tester.pump();
    }
    expect(text(tester, 'practiceResult'), 'You got 5 of 5 right.');
  });

  testWidgets('it opens from the welcome screen and Back returns',
      (tester) async {
    await tester.binding.setSurfaceSize(kDesignSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('practiceLink')));
    await tester.pump();
    expect(find.byKey(const Key('practiceQuestion')), findsOneWidget);

    await tester.tap(find.byKey(const Key('practiceBack')));
    await tester.pump();
    expect(find.byKey(const Key('practiceQuestion')), findsNothing);
    expect(find.text('Single Player'), findsOneWidget);
  });

  testWidgets('Back is also at the bottom mid-drill, and gives way to the '
      "results screen's own", (tester) async {
    await tester.binding.setSurfaceSize(kDesignSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('practiceLink')));
    await tester.pump();

    expect(find.byKey(const Key('practiceBackBottom')), findsOneWidget);
    await tester.tap(find.byKey(const Key('practiceBackBottom')));
    await tester.pump();
    expect(find.byKey(const Key('practiceQuestion')), findsNothing);
    expect(find.text('Single Player'), findsOneWidget);
  });

  testWidgets('every question fits, in every language, on a desktop and a '
      'phone', (tester) async {
    addTearDown(
        () => AppLanguageController.instance.select(AppLanguage.english));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in [kDesignSize, const Size(844, 390)]) {
      for (final language in AppLanguage.values) {
        AppLanguageController.instance.select(language);
        await pumpPage(tester, Ruleset.hongKong, size: size);
        for (final d in practiceDrillsFor(Ruleset.hongKong)) {
          expect(tester.takeException(), isNull,
              reason: '${language.name} $size ${d.id} before');
          await answerWrong(tester, d);
          expect(tester.takeException(), isNull,
              reason: '${language.name} $size ${d.id} after');
          await tester.ensureVisible(find.byKey(const Key('practiceNext')));
          await tester.tap(find.byKey(const Key('practiceNext')));
          await tester.pump();
        }
        expect(find.byKey(const Key('practiceResult')), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      }
    }
  });
}
