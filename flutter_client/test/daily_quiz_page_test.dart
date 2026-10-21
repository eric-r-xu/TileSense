import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/logic/daily_quiz.dart';
import 'package:tilesense/logic/progress.dart';
import 'package:tilesense/ui/daily_quiz_page.dart';

import 'l10n_helpers.dart';

/// The daily quiz as a player meets it: look, choose, learn why.
void main() {
  setUp(() => Sfx.i.enabled = false);
  tearDown(() => Sfx.i.enabled = true);

  final puzzles = [
    for (final p
        in (jsonDecode(File('assets/quiz/daily.json').readAsStringSync())
            as Map<String, Object?>)['puzzles']! as List)
      QuizPuzzle.fromJson(p as Map<String, Object?>),
  ];
  QuizPuzzle first(bool Function(QuizPuzzle) test) => puzzles.firstWhere(test);

  Future<void> pumpPuzzle(WidgetTester tester, QuizPuzzle puzzle,
      {void Function(QuizPuzzle, QuizChoice, bool)? onAnswered}) async {
    await pumpLocalized(tester,
        DailyQuizPage(puzzle: puzzle, onExit: () {}, onAnswered: onAnswered),
        size: const Size(1600, 820));
  }

  String text(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data!;

  /// Answers with [c] as a player would. On a riichi-or-dama puzzle that is
  /// the cut, then (if the cut leaves you ready and so asks) riichi or dama.
  Future<void> choose(WidgetTester tester, QuizPuzzle p, QuizChoice c) async {
    final i =
        p.choices.indexWhere((x) => p.riichiOption ? x.tile == c.tile : x == c);
    await tester.tap(find.byKey(Key('quizChoice_$i')));
    await tester.pump();
    if (find.byKey(const Key('quizSecondPart')).evaluate().isNotEmpty &&
        find.byKey(const Key('quizVerdict')).evaluate().isEmpty) {
      await tester.tap(find
          .byKey(Key(c.move == QuizMove.riichi ? 'quizRiichi' : 'quizDama')));
      await tester.pump();
    }
  }

  /// A choice that is wrong: another cut on a riichi-or-dama puzzle (whatever
  /// riichi call follows), otherwise any choice but the answer.
  QuizChoice wrongChoice(QuizPuzzle p) => p.choices.firstWhere(
      (c) => p.riichiOption ? c.tile != p.answer.tile : c != p.answer);

  testWidgets(
      'three different characters sit left, right and across; you '
      'have none', (tester) async {
    final puzzle = first((p) => p.kind == QuizKind.discard);
    await pumpPuzzle(tester, puzzle);
    final shown = [
      for (final image in tester.widgetList<Image>(find.byType(Image)))
        if (image.image case AssetImage(:final assetName)
            when kCharacterPortrait.containsValue(assetName))
          assetName,
    ];
    expect(shown, hasLength(3));
    expect(shown.toSet(), hasLength(3), reason: 'unique characters');
    // The across seat's portrait and score are up in the bar.
    final across = find.byKey(const Key('acrossSeat'));
    expect(across, findsOneWidget);
    expect(
        find.descendant(
            of: across,
            matching: find.textContaining('${puzzle.table.points[2]}')),
        findsOneWidget);
    expect(find.descendant(of: across, matching: find.byType(Image)),
        findsOneWidget);
    // Your own seat shows a placard and no portrait.
    final own = find.byKey(const Key('ownSeat'));
    expect(own, findsOneWidget);
    expect(
        find.descendant(of: own, matching: find.byType(Image)), findsNothing);
  });

  testWidgets('says riichi only, and Back is also at the bottom of the panel',
      (tester) async {
    var exits = 0;
    await pumpLocalized(
        tester,
        DailyQuizPage(
            puzzle: first((p) => p.kind == QuizKind.discard),
            onExit: () => exits++),
        size: const Size(1600, 820));
    expect(find.text('Riichi (Japanese) mahjong rules only'), findsOneWidget);

    await tester.tap(find.byKey(const Key('quizBackBottom')));
    await tester.pump();
    expect(exits, 1);
  });

  testWidgets('a ready hand is two questions: the cut, then riichi or dama',
      (tester) async {
    final puzzle = first((p) => p.riichiOption);
    QuizChoice? told;
    await pumpPuzzle(tester, puzzle, onAnswered: (_, c, __) => told = c);

    // Part one is only the cuts; riichi and dama are not on offer yet.
    expect(find.byKey(const Key('quizSecondPart')), findsNothing);
    expect(find.byKey(const Key('quizRiichi')), findsNothing);
    final cuts = puzzle.choices.length;
    expect(find.byKey(Key('quizChoice_${cuts - 1}')), findsOneWidget);

    // The right cut asks the second part, and nothing is decided yet.
    final i = puzzle.choices.indexWhere((c) => c.tile == puzzle.answer.tile);
    await tester.tap(find.byKey(Key('quizChoice_$i')));
    await tester.pump();
    expect(find.byKey(const Key('quizSecondPart')), findsOneWidget);
    expect(text(tester, 'quizAskRiichi'), contains('Riichi'));
    expect(find.byKey(const Key('quizVerdict')), findsNothing);
    expect(told, isNull);

    // The right cut with the wrong call is wrong, and Mortal's line says what
    // it does about riichi rather than ranking the cut.
    final wrongCall =
        puzzle.answer.move == QuizMove.riichi ? 'quizDama' : 'quizRiichi';
    await tester.tap(find.byKey(Key(wrongCall)));
    await tester.pump();
    expect(text(tester, 'quizVerdict'), 'Not quite.');
    expect(told!.tile, puzzle.answer.tile);
    expect(told!.move, isNot(puzzle.answer.move));
    expect(text(tester, 'quizMortalLine'), contains('Mortal'));
    expect(text(tester, 'quizMortalLine'), isNot(contains('ranks')));
  });

  testWidgets('both parts right is correct', (tester) async {
    final puzzle = first((p) => p.riichiOption);
    bool? correct;
    await pumpPuzzle(tester, puzzle, onAnswered: (_, __, ok) => correct = ok);
    await choose(tester, puzzle, puzzle.answer);
    expect(text(tester, 'quizVerdict'), 'Correct!');
    expect(correct, isTrue);
  });

  testWidgets(
      'the reveal says how late it is, where you stand and who '
      'threatens', (tester) async {
    final puzzle = first((p) => p.table.points.toSet().length > 1);
    await pumpPuzzle(tester, puzzle);
    expect(find.byKey(const Key('quizSituation')), findsNothing);
    await choose(tester, puzzle, wrongChoice(puzzle));
    final shown = [
      for (final t in tester.widgetList<Text>(find.descendant(
          of: find.byKey(const Key('quizSituation')),
          matching: find.byType(Text))))
        t.data!,
    ].join('\n');
    expect(shown, contains('tiles left in the wall'));
    expect(shown, contains('Placement: '));
    expect(shown, contains('of 4'));
    expect(shown, anyOf(contains('dealer'), contains('not the dealer')));
    expect(shown, anyOf(contains('in riichi'), contains('Nobody else')));
    expect(
        shown,
        anyOf(contains('TileSense plays for points'),
            contains('your finishing place')));
  });

  testWidgets('an answer is reported once, and a replay says it is not first',
      (tester) async {
    final puzzle = first((p) => p.kind == QuizKind.discard && !p.riichiOption);
    final store = ProgressStore(read: (_) => null, write: (_, __) {});
    final sent = <Map<String, Object?>>[];

    Future<void> answerOnce(QuizChoice c) async {
      // A fresh page each time, as when the player comes back.
      await tester.pumpWidget(const SizedBox());
      await pumpLocalized(
          tester,
          DailyQuizScreen(
              onExit: () {},
              puzzles: Future.value([puzzle]),
              progress: store,
              onTelemetry: sent.add),
          size: const Size(1600, 820));
      await tester.pump();
      await tester.pump();
      await choose(tester, puzzle, c);
    }

    final wrong = wrongChoice(puzzle);
    await answerOnce(wrong);
    await answerOnce(puzzle.answer);

    expect(sent, hasLength(2));
    expect(sent[0], {
      'puzzle_id': puzzle.id,
      'puzzle_kind': 'discard',
      'choice': '$wrong',
      'answer': '${puzzle.answer}',
      'correct': false,
      'riichi_option': false,
      'day': dayKey(DateTime.now()),
      'streak': 1,
      'first_today': true,
    });
    expect(sent[1]['correct'], isTrue);
    expect(sent[1]['first_today'], isFalse);
    expect(sent[1]['streak'], 1);
  });

  for (final kind in QuizKind.values) {
    final puzzle = first((p) => p.kind == kind);

    testWidgets('${kind.name}: the right answer is confirmed and explained',
        (tester) async {
      QuizChoice? told;
      bool? correct;
      await pumpPuzzle(tester, puzzle, onAnswered: (_, c, ok) {
        told = c;
        correct = ok;
      });
      expect(find.byKey(const Key('quizReveal')), findsNothing);
      expect(find.byKey(Key('quizChoice_${puzzle.choices.length - 1}')),
          findsOneWidget);

      await choose(tester, puzzle, puzzle.answer);
      expect(text(tester, 'quizVerdict'), 'Correct!');
      expect(find.byKey(const Key('quizAgree')), findsOneWidget);
      expect(find.byKey(const Key('quizFacts')), findsOneWidget);
      expect(find.byKey(const Key('quizMortalLine')), findsOneWidget);
      expect(told, puzzle.answer);
      expect(correct, isTrue);
    });

    testWidgets('${kind.name}: a wrong answer shows the best move beside it',
        (tester) async {
      bool? correct;
      await pumpPuzzle(tester, puzzle, onAnswered: (_, __, ok) => correct = ok);
      final wrong = wrongChoice(puzzle);
      await choose(tester, puzzle, wrong);
      expect(text(tester, 'quizVerdict'), 'Not quite.');
      expect(correct, isFalse);
      expect(find.byKey(const Key('quizAgree')), findsOneWidget);

      // Answered once: a second tap changes nothing.
      await tester.tap(find.byKey(const Key('quizChoice_0')));
      await tester.pump();
      expect(text(tester, 'quizVerdict'), 'Not quite.');
    });
  }
}
