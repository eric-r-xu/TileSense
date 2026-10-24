/// Builds `assets/quiz/daily.json`, the puzzles behind the daily quiz.
///
/// Riichi puzzles need a running Mortal sidecar (`mortal_sidecar/server.py`).
/// Run from flutter_client/ as a test, which gives it the Flutter libraries the
/// guide is built on:
///
///     QUIZ_MORTAL_URL=http://127.0.0.1:8790 QUIZ_COUNT=60 QUIZ_SEED=1 \
///         flutter test tools/build_quiz.dart
///
/// QUIZ_RULESET=hongKong makes Hong Kong puzzles instead. Mortal does not play
/// those rules, so no sidecar is needed: TileSense's own clear lead is the bar.
///
/// Every run first re-checks the puzzles already in the file and drops any that
/// no longer stand (see [puzzleProblem]), and a Hong Kong puzzle is kept only
/// if the guide answers it the same aggressively, defensively and by default.
///
/// QUIZ_COUNT is how many puzzles to add (default 60) and QUIZ_SEED picks the
/// random tables (default 1). Puzzles already in the file are kept, and the new
/// ones follow them, so a day's puzzle never changes under a player: grow the
/// pool with a new seed rather than rerunning an old one. QUIZ_OUT moves the
/// file; QUIZ_MARGIN sets the least lead over the next line (default 0.10).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:tilesense/game/mortal_advisor.dart';
import 'package:tilesense/logic/daily_quiz.dart';
import 'package:tilesense/logic/quiz_rules.dart';

import 'quiz_generator.dart';

void main() {
  test('build the daily quiz', () async {
    final env = Platform.environment;
    final ruleset = Ruleset.values.byName(env['QUIZ_RULESET'] ?? 'riichi');
    expect(kQuizRulesets, contains(ruleset), reason: 'no quiz for $ruleset');
    final url = env['QUIZ_MORTAL_URL'];
    if (ruleset.isRiichi && (url == null || url.isEmpty)) {
      fail('Set QUIZ_MORTAL_URL to the Mortal sidecar, e.g. '
          'http://127.0.0.1:8790');
    }
    final count = int.parse(env['QUIZ_COUNT'] ?? '60');
    final out = File(env['QUIZ_OUT'] ?? 'assets/quiz/daily.json');

    final existing = out.existsSync()
        ? [
            for (final p in (jsonDecode(out.readAsStringSync())
                as Map<String, Object?>)['puzzles']! as List)
              QuizPuzzle.fromJson(p as Map<String, Object?>),
          ]
        : <QuizPuzzle>[];

    // Puzzles that no longer stand (the guide has been retuned, or they predate
    // kan being offered or Hong Kong's style check) are dropped, so every
    // puzzle in the pool meets today's bar. QUIZ_KEEP_STALE=1 keeps them.
    final dropped = env['QUIZ_KEEP_STALE'] == '1'
        ? <String>[]
        : [
            for (final p in existing)
              if (puzzleProblem(p) case final why?) '${p.id}: $why',
          ];
    if (dropped.isNotEmpty) {
      // ignore: avoid_print
      print('dropping ${dropped.length} stale puzzles:\n${dropped.join('\n')}');
      existing.removeWhere((p) => dropped.any((d) => d.startsWith('${p.id}:')));
    }

    final advisor = ruleset.isRiichi ? MortalAdvisor(url!) : null;
    final generator = QuizGenerator(
      seed: int.parse(env['QUIZ_SEED'] ?? '1'),
      ruleset: ruleset,
      minMargin: double.parse(env['QUIZ_MARGIN'] ?? '0.10'),
      mortal: advisor == null ? null : askSidecar(advisor.advise),
    );
    // Ids count up within a ruleset, so a pool can grow without renumbering.
    // Counting on from the highest id, since dropped puzzles leave gaps.
    final prefix = QuizGenerator.idPrefix(ruleset);
    final last = existing
        .where((p) => p.ruleset == ruleset)
        .map((p) => int.parse(p.id.substring(prefix.length)))
        .fold(0, (a, b) => a > b ? a : b);
    final made = await generator.generate(count,
        firstNumber: last + 1, maxTries: count * 400);

    // ignore: avoid_print
    print(
        'kept ${made.length} of ${generator.tally.values.fold(0, (a, b) => a + b)} tables: '
        '${generator.tally}');
    out.parent.createSync(recursive: true);
    out.writeAsStringSync(const JsonEncoder.withIndent(' ').convert({
      'version': 1,
      'puzzles': [
        for (final p in [...existing, ...made]) p.toJson()
      ],
    }));
    expect(made, isNotEmpty);
  }, timeout: Timeout.none);
}
