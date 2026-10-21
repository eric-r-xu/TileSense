import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/logic/progress.dart';
import 'package:tilesense/main.dart';

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

  testWidgets(
      'the card opens the quiz and Back '
      'returns', (tester) async {
    await pumpMenu(tester);
    expect(find.byKey(const Key('dailyQuizMascot')), findsOneWidget);
    expect(find.byKey(const Key('dailyQuizStreak')), findsNothing);

    for (final entry in ['dailyQuizCard']) {
      await tester.tap(find.byKey(Key(entry)));
      await settle(tester);
      expect(find.byKey(const Key('quizQuestion')), findsOneWidget,
          reason: entry);
      await tester.tap(find.byKey(const Key('quizBack')));
      await tester.pump();
      expect(find.text('Single Player'), findsOneWidget);
    }
  });

  testWidgets(
      'the card and the quiz say it is riichi only, whatever rules are chosen',
      (tester) async {
    await pumpMenu(tester);
    final choice = find.byKey(const Key('ruleset_hongKong'));
    await tester.ensureVisible(choice);
    await tester.tap(choice);
    await tester.pump();
    expect(
        find.descendant(
            of: find.byKey(const Key('dailyQuizCard')),
            matching: find.text('Riichi (Japanese) mahjong rules only')),
        findsOneWidget);

    await tester.tap(find.byKey(const Key('dailyQuizCard')));
    await settle(tester);
    expect(find.byKey(const Key('riichiOnlyBadge')), findsOneWidget);
    expect(find.text('Riichi (Japanese) mahjong rules only'), findsOneWidget);
  });

  testWidgets(
      "on a phone the quiz's Back is thumb-sized, and repeated at the bottom "
      'of the panel', (tester) async {
    const iPhone = Size(852, 393);
    await tester.binding.setSurfaceSize(iPhone);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('dailyQuizCard')));
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

  testWidgets('answering marks today done and starts the streak on the card',
      (tester) async {
    await pumpMenu(tester);
    await tester.tap(find.byKey(const Key('dailyQuizCard')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('quizChoice_0')));
    await tester.pump();
    // Today's puzzle may be a riichi-or-dama one, which asks a second part.
    if (find.byKey(const Key('quizRiichi')).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const Key('quizRiichi')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('quizBack')));
    await tester.pump();

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
