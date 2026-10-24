import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/logic/daily_quiz.dart' show kQuizPerDay;
import 'package:tilesense/logic/progress.dart';
import 'package:tilesense/main.dart';
import 'helpers.dart';

/// The daily quiz's way in from the welcome screen, and its streak.
void main() {
  late Map<String, String> storage;

  ProgressStore freshStore() =>
      ProgressStore(read: (k) => storage[k], write: (k, v) => storage[k] = v);

  setUp(() {
    storage = {};
    Sfx.i.enabled = false;
    ProgressStore.instance = freshStore();
    // A load cached by an earlier test belongs to that test's zone.
    rootBundle.evict('assets/quiz/daily.json');
  });
  tearDown(() => Sfx.i.enabled = true);

  group('the streak', () {
    final mon = DateTime(2026, 10, 19, 9);
    final tue = DateTime(2026, 10, 20, 22);
    final thu = DateTime(2026, 10, 22);

    test('counts days in a row, once a day', () {
      final s = freshStore()
        ..recordQuiz(mon, correct: true)
        ..recordQuiz(mon, correct: false); // a second answer the same day
      expect(s.value.quizStreakOn(mon), 1);
      expect(s.value.quizCorrect, isTrue, reason: 'the first answer counts');
      s.recordQuiz(tue, correct: false);
      expect(s.value.quizStreakOn(tue), 2);
      expect(s.value.quizBest, 2);
    });

    test('is kept until the day after the next one is missed', () {
      final s = freshStore()..recordQuiz(mon, correct: true);
      expect(s.value.quizStreakOn(tue), 1, reason: 'today can still be played');
      expect(s.value.quizStreakOn(thu), 0, reason: 'a day was missed');
      s.recordQuiz(thu, correct: true);
      expect(s.value.quizStreakOn(thu), 1);
      expect(s.value.quizBest, 1);
    });

    test('crosses a month end and survives a reload', () {
      final s = freshStore()
        ..recordQuiz(DateTime(2026, 10, 31), correct: true)
        ..recordQuiz(DateTime(2026, 11, 1), correct: true);
      expect(s.value.quizStreakOn(DateTime(2026, 11, 1)), 2);
      final again = freshStore();
      expect(again.value.quizStreakOn(DateTime(2026, 11, 1)), 2);
      expect(again.value.quizAnsweredOn(DateTime(2026, 11, 1)), isTrue);
    });

    test('an old record without quiz fields reads as no streak', () {
      final p = Progress.fromJson('{"wins":4,"hands":9}');
      expect(p.wins, 4);
      expect(p.quizStreakOn(DateTime.now()), 0);
    });
  });

  Future<void> pumpMenu(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(kDesignSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Lets the quiz's library and puzzle file load, up to a few seconds.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0;
        i < 100 && find.byKey(const Key('quizQuestion')).evaluate().isEmpty;
        i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Opens the quiz from the Learn popup.
  Future<void> openQuiz(WidgetTester tester) =>
      tapInPopup(tester, 'learnTile', find.byKey(const Key('dailyQuizCard')));

  String tileText(WidgetTester tester) => tester
      .widgetList<Text>(find.descendant(
          of: find.byKey(const Key('learnTile')), matching: find.byType(Text)))
      .map((t) => t.data)
      .join('|');

  testWidgets(
      'the Learn tile says the puzzle is waiting, and its popup opens the '
      'quiz and Back returns', (tester) async {
    await pumpMenu(tester);
    expect(tileText(tester), contains("Today's puzzles are ready"));
    expect(find.byKey(const Key('dailyQuizCard')), findsNothing,
        reason: 'the quiz is in the Learn popup, not a card of its own');
    expect(find.byKey(const Key('dailyQuizMascot')), findsNothing);

    await openPopup(tester, 'learnTile');
    expect(find.byKey(const Key('dailyQuizStreak')), findsNothing);
    await tester.tap(find.byKey(const Key('dailyQuizCard')));
    await tester.pump();
    await settle(tester);
    expect(find.byKey(const Key('quizQuestion')), findsOneWidget);
    await tester.tap(find.byKey(const Key('quizBack')));
    await tester.pump();
    expect(find.text('Single Player'), findsOneWidget);
  });

  testWidgets('the quiz is posed in the rules chosen, riichi where it has none',
      (tester) async {
    await pumpMenu(tester);

    // Hong Kong, the welcome screen's default, has puzzles of its own.
    await openPopup(tester, 'learnTile');
    expect(
        find.descendant(
            of: find.byKey(const Key('dailyQuizCard')),
            matching: find.text('Hong Kong')),
        findsWidgets);
    await tester.tap(find.byKey(const Key('dailyQuizCard')));
    await tester.pump();
    await settle(tester);
    expect(
        find.descendant(
            of: find.byKey(const Key('quizRulesBadge')),
            matching: find.text('Hong Kong')),
        findsWidgets);
    // Mortal does not play Hong Kong rules, so nothing here is Mortal's.
    expect(find.byKey(const Key('quizRiichi')), findsNothing);
    await tester.tap(find.byKey(const Key('quizChoice_0')));
    await tester.pump();
    expect(find.byKey(const Key('quizReveal')), findsOneWidget);
    expect(find.byKey(const Key('quizAgree')), findsNothing);
    expect(find.byKey(const Key('quizMortalLine')), findsNothing);
    await tester.tap(find.byKey(const Key('quizBack')));
    await tester.pump();

    // Riichi, and Taiwanese which has no pool yet, both get riichi puzzles.
    for (final ruleset in ['riichi', 'taiwanese']) {
      await tapInPopup(
          tester, 'rulesTile', find.byKey(Key('ruleset_$ruleset')));
      await openPopup(tester, 'learnTile');
      expect(
          find.descendant(
              of: find.byKey(const Key('dailyQuizCard')),
              matching: find.text('Riichi')),
          findsWidgets,
          reason: ruleset);
      await closePopup(tester);
    }
  });

  testWidgets(
      "on a phone the quiz's Back is thumb-sized, and repeated at the bottom "
      'of the panel', (tester) async {
    const iPhone = Size(852, 393);
    await tester.binding.setSurfaceSize(iPhone);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));
    await openQuiz(tester);
    await settle(tester);

    // Both are drawn at the canvas's ~0.48 scale, so 44pt is about 92 canvas
    // px: the bar has to be tall enough to give the top one that.
    final top = tester.getRect(find.byKey(const Key('quizBack')));
    final bottom = tester.getRect(find.byKey(const Key('quizBackBottom')));
    expect(top.height, greaterThanOrEqualTo(40));
    expect(bottom.height, greaterThanOrEqualTo(40));
    expect(bottom.bottom, greaterThan(top.bottom + 100),
        reason: 'the footer is down by the thumb, not up in the corner');

    await tester.tap(find.byKey(const Key('quizBackBottom')));
    await tester.pump();
    expect(find.text('Single Player'), findsOneWidget);
  });

  testWidgets('answering marks today done and starts the streak on the tile',
      (tester) async {
    await pumpMenu(tester);
    await openQuiz(tester);
    await settle(tester);
    // Five questions make a day; the streak waits for the fifth. Leaving
    // after the first leaves the day undone and starts it again.
    Future<void> answer() async {
      await tester.tap(find.byKey(const Key('quizChoice_0')));
      await tester.pump();
      // A puzzle may be a riichi-or-dama one, which asks a second part.
      if (find.byKey(const Key('quizRiichi')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('quizRiichi')));
        await tester.pump();
      }
    }

    await answer();
    await tester.tap(find.byKey(const Key('quizBack')));
    await tester.pump();
    expect(tileText(tester), isNot(contains('Done for today')),
        reason: 'a day half played is not done');
    await openQuiz(tester);
    await settle(tester);

    for (var q = 1; q <= kQuizPerDay; q++) {
      expect(find.text('Question $q of $kQuizPerDay'), findsOneWidget);
      await answer();
      await tester.tap(find.byKey(const Key('quizNext')));
      await tester.pump();
    }
    expect(find.byKey(const Key('quizResultsScore')), findsOneWidget);
    await tester.tap(find.byKey(const Key('quizBack')));
    await tester.pump();

    expect(tileText(tester),
        contains('Done for today. Back tomorrow! · 1-day streak'));
    await openPopup(tester, 'learnTile');
    expect(tester.widget<Text>(find.byKey(const Key('dailyQuizStatus'))).data,
        'Done for today. Back tomorrow!');
    expect(
        tester
            .widget<Text>(find.descendant(
                of: find.byKey(const Key('dailyQuizStreak')),
                matching: find.byType(Text)))
            .data,
        '1-day streak');
  });
}
