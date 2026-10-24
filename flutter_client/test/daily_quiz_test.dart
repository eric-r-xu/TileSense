import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/tile.dart';
import 'package:tilesense/logic/efficiency_engine.dart'
    show PlayStyle, Strategy;
import 'package:tilesense/logic/quiz_rules.dart';
import 'package:tilesense/game/mortal_advisor.dart';
import 'package:tilesense/logic/daily_quiz.dart';
import 'package:tilesense/scenario/scenario.dart';

import '../tools/quiz_generator.dart';

/// A Mortal that says what TileSense says, or [lie] if given.
MortalAsk stand({QuizChoice Function(QuizChoice)? lie}) =>
    (table, {required call}) async {
      final c = QuizTable.fromScenario(table).pose();
      final theirs = lie?.call(tileSenseChoice(c)!) ?? tileSenseChoice(c)!;
      c.dispose();
      final reaction = switch (theirs.move) {
        QuizMove.discard || QuizMove.riichi => {
            'type': theirs.move == QuizMove.riichi ? 'reach' : 'dahai',
            'pai': _mjai(theirs.tile!),
          },
        QuizMove.pon => {'type': 'pon'},
        QuizMove.kan => {'type': 'daiminkan'},
        QuizMove.chi => {
            'type': 'chi',
            'pai': _mjai(TileType.values[theirs.tile!.index + 1]),
            'consumed': [
              _mjai(theirs.tile!),
              _mjai(TileType.values[theirs.tile!.index + 2]),
            ],
          },
        QuizMove.pass => {'type': 'none'},
      };
      return MortalAdvice.fromReply({
        'reaction': reaction,
        'riichi_discard': theirs.move == QuizMove.riichi
            ? {'type': 'dahai', 'pai': _mjai(theirs.tile!)}
            : null,
      }, call: call);
    };

String _mjai(TileType t) => switch (t) {
      TileType.haku => 'P',
      TileType.hatsu => 'F',
      TileType.chun => 'C',
      _ => t.code,
    };

void main() {
  test('a table survives JSON and posing', () async {
    final puzzles = await QuizGenerator(seed: 7, mortal: stand())
        .generate(4, maxTries: 400);
    expect(puzzles, isNotEmpty);
    for (final p in puzzles) {
      final again = QuizPuzzle.fromJson(
          jsonDecode(jsonEncode(p.toJson())) as Map<String, Object?>);
      expect(jsonEncode(again.toJson()), jsonEncode(p.toJson()));
      final sc = Scenario();
      p.table.applyTo(sc);
      expect(sc.problems(), isEmpty, reason: p.id);
    }
  });

  test('every puzzle has one right answer among its choices, found live',
      () async {
    final puzzles = await QuizGenerator(seed: 11, mortal: stand())
        .generate(12, maxTries: 1500);
    expect(puzzles.length, greaterThanOrEqualTo(6));
    for (final p in puzzles) {
      expect(p.choices.length, inInclusiveRange(3, 4), reason: p.id);
      expect(p.choices.toSet().length, p.choices.length, reason: p.id);
      final cut = p.riichiOption
          ? QuizChoice(QuizMove.discard, p.answer.tile)
          : p.answer;
      expect(p.choices.where((c) => c == cut), hasLength(1), reason: p.id);
      final c = p.pose();
      expect(tileSenseChoice(c), p.answer, reason: p.id);
      c.dispose();
    }
  });

  test('at most half the call puzzles are passes', () async {
    final puzzles = await QuizGenerator(seed: 5, mortal: stand())
        .generate(40, maxTries: 3000);
    final calls = puzzles.where((p) => p.kind == QuizKind.call).toList();
    final passes = calls.where((p) => p.answer.move == QuizMove.pass);
    expect(calls.length, greaterThanOrEqualTo(4));
    expect(passes.length * 2, lessThanOrEqualTo(calls.length));
  });

  test('a ready hand is a cut, then riichi or dama', () async {
    final puzzles = await QuizGenerator(seed: 21, mortal: stand())
        .generate(30, maxTries: 3000);
    final asking = puzzles.where((p) => p.riichiOption).toList();
    expect(asking, isNotEmpty);
    for (final p in asking) {
      final a = p.answer;
      expect(a.move, anyOf(QuizMove.riichi, QuizMove.discard));
      // Part one offers cuts (and a kan, if one could be declared), each cut
      // once; riichi comes after.
      final cuts = p.choices.where((c) => c.move != QuizMove.kan).toList();
      expect(cuts.every((c) => c.move == QuizMove.discard), isTrue,
          reason: p.id);
      expect(cuts.map((c) => c.tile).toSet(), hasLength(cuts.length),
          reason: p.id);
      expect(p.choices, contains(QuizChoice(QuizMove.discard, a.tile)),
          reason: p.id);
      // The right cut leaves the hand ready, which is what makes riichi
      // possible.
      final c = p.pose();
      expect(quizFacts(c, a)!.shanten, 0, reason: p.id);
      c.dispose();
    }
    for (final p in puzzles.where((p) => !p.riichiOption)) {
      expect(p.choices.where((c) => c.move == QuizMove.riichi), isEmpty,
          reason: p.id);
    }
  });

  group('scores', () {
    QuizTable table(
        {required Wind wind, required int dealer, List<int>? points}) {
      final base = QuizTable.fromJson({
        'roundWind': wind.name,
        'dealer': dealer,
        'dora': ['1m'],
        'wall': 40,
        'hand': [
          '1m',
          '2m',
          '3m',
          '4p',
          '5p',
          '6p',
          '7s',
          '8s',
          '9s',
          'E',
          'E',
          'B',
          'B',
          '5m'
        ],
        'ponds': [<String>[], <String>[], <String>[], <String>[]],
        if (points != null) 'points': points,
      });
      return base;
    }

    test('are kept through JSON, and omitted when level', () {
      final uneven = table(
          wind: Wind.south, dealer: 2, points: [18000, 32000, 25000, 25000]);
      expect(QuizTable.fromJson(uneven.toJson()).points,
          [18000, 32000, 25000, 25000]);
      expect(table(wind: Wind.east, dealer: 0).toJson().containsKey('points'),
          isFalse);
    });

    test('put the guide on placement in the last two hands, and only then', () {
      final scores = [18000, 32000, 25000, 25000];
      final last = table(wind: Wind.south, dealer: 2, points: scores).pose();
      expect(last.strategy, Strategy.placement);
      final early = table(wind: Wind.east, dealer: 0, points: scores).pose();
      expect(early.strategy, Strategy.points);
      // Level scores leave placement nothing to weigh, as in the builder.
      final level = table(wind: Wind.south, dealer: 2).pose();
      expect(level.strategy, Strategy.points);
      for (final c in [last, early, level]) {
        c.dispose();
      }
    });

    test('are read as a situation: place, gaps, timing, threat', () {
      final t = QuizTable.fromJson({
        'roundWind': 'south',
        'dealer': 3,
        'dora': ['1m'],
        'wall': 20,
        'hand': ['1m'],
        'ponds': [
          <String>[],
          <String>['1p', '2p', '3p'],
          <String>[],
          <String>[]
        ],
        'riichiAt': [-1, 1, -1, -1],
        'points': [22000, 30000, 25000, 23000],
      });
      final s = quizSituation(t);
      expect(s.rank, 4);
      expect(s.behindFirst, 8000);
      expect(s.handsLeft, 1);
      expect(s.placementFocus, isTrue);
      expect(s.stage, QuizStage.late);
      expect(s.riichiSeat, 1);
      expect(s.riichiTurnsAgo, 2);
      expect(s.isDealer, isFalse);
      final lead = quizSituation(QuizTable.fromJson({
        ...t.toJson(),
        'points': [30000, 22000, 25000, 23000],
      }));
      expect(lead.rank, 1);
      expect(lead.aheadOfNext, 5000);
      expect(lead.behindFirst, 0);
    });
  });

  test('a Mortal that disagrees makes no puzzles', () async {
    final liar = stand(
        lie: (a) => a.move == QuizMove.pass
            ? const QuizChoice(QuizMove.pon)
            : QuizChoice(QuizMove.discard,
                a.tile == TileType.ton ? TileType.nan : TileType.ton));
    final generator = QuizGenerator(seed: 3, mortal: liar);
    expect(await generator.generate(5, maxTries: 300), isEmpty);
    expect(generator.tally[Reject.disagree], greaterThan(0));
  });

  test('every shipped puzzle still has TileSense\'s answer as its answer', () {
    final file = File('assets/quiz/daily.json');
    final puzzles = [
      for (final p in (jsonDecode(file.readAsStringSync())
          as Map<String, Object?>)['puzzles']! as List)
        QuizPuzzle.fromJson(p as Map<String, Object?>),
    ];
    expect(puzzles, isNotEmpty);
    expect(puzzles.map((p) => p.id).toSet(), hasLength(puzzles.length));
    for (final p in puzzles) {
      // The same answer now, a kan offered wherever one could be declared,
      // and a Hong Kong answer that holds however the guide plays.
      expect(puzzleProblem(p), isNull, reason: p.id);
      final cut = p.riichiOption || p.answer.move == QuizMove.kan
          ? QuizChoice(
              p.answer.move == QuizMove.kan ? QuizMove.kan : QuizMove.discard,
              p.answer.tile)
          : p.answer;
      expect(p.choices.where((x) => x == cut), hasLength(1), reason: p.id);
    }
  });

  group('kan', () {
    Future<List<QuizPuzzle>> kanTables(Ruleset ruleset) async {
      final generator = QuizGenerator(
          seed: 4,
          ruleset: ruleset,
          kanShare: 1,
          mortal: ruleset.isRiichi ? stand() : null);
      return generator.generate(16, maxTries: 1500);
    }

    for (final ruleset in [Ruleset.riichi, Ruleset.hongKong]) {
      test('is a choice whenever it could be declared (${ruleset.name})',
          () async {
        final puzzles = await kanTables(ruleset);
        expect(puzzles.length, greaterThanOrEqualTo(8));
        final discards = puzzles.where((p) => p.kind == QuizKind.discard);
        final calls = puzzles.where((p) => p.kind == QuizKind.call);
        expect(discards, isNotEmpty);
        expect(calls, isNotEmpty);
        for (final p in discards) {
          final c = p.pose();
          final kan = kanOnOffer(c);
          expect(kan, isNotNull, reason: '${p.id} holds all four of a tile');
          expect(p.choices, contains(kan), reason: p.id);
          expect(p.choices.length, inInclusiveRange(3, 4), reason: p.id);
          // Naming the tile it kans, it is not mistaken for the cut.
          expect(p.choices.where((x) => x.move == QuizMove.kan), hasLength(1));
          c.dispose();
        }
        for (final p in calls) {
          // Three held and the fourth on offer: kan, pon or pass.
          expect(p.choices, contains(const QuizChoice(QuizMove.kan)),
              reason: p.id);
          expect(p.choices, contains(const QuizChoice(QuizMove.pon)),
              reason: p.id);
        }
        // The kan can be the right answer or a wrong one.
        expect(puzzles.map((p) => p.answer.move), contains(QuizMove.kan));
      });
    }

    test('a kan answer is stored, read back and explained', () async {
      final p = (await kanTables(Ruleset.hongKong)).firstWhere(
          (p) => p.answer.move == QuizMove.kan && p.kind == QuizKind.discard);
      final again = QuizPuzzle.fromJson(
          jsonDecode(jsonEncode(p.toJson())) as Map<String, Object?>);
      expect(again.answer, p.answer);
      expect(again.answer.tile, isNotNull, reason: 'which tile it kans');
      expect(again.riichiOption, isFalse);
      final c = p.pose();
      final facts = quizFacts(c, p.answer);
      expect(facts, isNotNull);
      expect(facts!.reason, isNotEmpty);
      c.dispose();
    });

    test('Mortal\'s kan reads as a kan on the tile it could kan', () {
      final reply = MortalAdvice.fromReply({
        'reaction': {
          'type': 'ankan',
          'consumed': ['5p', '5p', '5p', '5p']
        }
      }, call: false);
      expect(
          mortalChoice(reply, kind: QuizKind.discard, kanTile: TileType.pin5),
          const QuizChoice(QuizMove.kan, TileType.pin5));
      expect(mortalChoice(reply, kind: QuizKind.discard), isNull,
          reason: 'with no kan on the table there is nothing to name');
    });

    test('a Mortal who will not kan disagrees with a guide who does', () async {
      final stubborn = stand(
          lie: (a) => a.move == QuizMove.kan
              ? QuizChoice(QuizMove.discard, a.tile ?? TileType.ton)
              : a);
      final generator = QuizGenerator(seed: 4, mortal: stubborn, kanShare: 1);
      final puzzles = await generator.generate(12, maxTries: 800);
      expect(puzzles.where((p) => p.answer.move == QuizMove.kan), isEmpty);
    });
  });

  group('Hong Kong styles', () {
    test('the guide can be made to play aggressively or defensively', () async {
      final p = (await QuizGenerator(seed: 3, ruleset: Ruleset.hongKong)
              .generate(1, maxTries: 400))
          .single;
      final c = p.pose();
      expect(c.playStyle, PlayStyle.balanced);
      c.overrideStyle(PlayStyle.aggressive);
      expect(c.playStyle, PlayStyle.aggressive);
      c.overrideStyle(PlayStyle.defensive);
      expect(c.playStyle, PlayStyle.defensive);
      c.overrideStyle(null);
      expect(c.playStyle, PlayStyle.balanced);
      c.dispose();
    });

    test('every puzzle is answered the same by every style', () async {
      final puzzles = await QuizGenerator(seed: 8, ruleset: Ruleset.hongKong)
          .generate(20, maxTries: 1500);
      expect(puzzles.length, greaterThanOrEqualTo(10));
      for (final p in puzzles) {
        final c = p.pose();
        for (final style in PlayStyle.values) {
          c.overrideStyle(style);
          expect(tileSenseChoice(c), p.answer,
              reason: '${p.id} under ${style.label}');
        }
        c.dispose();
      }
    });

    test('a puzzle the styles would split is not a puzzle', () {
      // An answer that held only for the default style is flagged.
      final p = QuizPuzzle.fromJson(jsonDecode(
              File('assets/quiz/daily.json').readAsStringSync())['puzzles'][300]
          as Map<String, Object?>);
      expect(puzzleProblem(p), isNull);
      final wrong = QuizPuzzle(
          id: p.id,
          table: p.table,
          choices: p.choices,
          answer: p.choices.firstWhere((c) => c != p.answer));
      expect(puzzleProblem(wrong), isNotNull);
    });
  });

  group('Hong Kong', () {
    Future<List<QuizPuzzle>> make(int count, {int seed = 3}) =>
        QuizGenerator(seed: seed, ruleset: Ruleset.hongKong)
            .generate(count, maxTries: 600);

    test('puzzles are made without Mortal, on tables with no dora or riichi',
        () async {
      final puzzles = await make(6);
      expect(puzzles, hasLength(6));
      for (final p in puzzles) {
        expect(p.id, startsWith('hk'));
        expect(p.ruleset, Ruleset.hongKong);
        expect(p.riichiOption, isFalse);
        expect(p.mortalRanks, isEmpty);
        expect(p.table.dora, isEmpty);
        expect(p.table.riichiAt, everyElement(-1));
        expect(p.table.riichiSticks, 0);
        final c = p.pose();
        expect(c.ruleset, Ruleset.hongKong);
        expect(tileSenseChoice(c), p.answer, reason: p.id);
        c.dispose();
      }
    });

    test('a puzzle keeps its rules through JSON; riichi ones omit them',
        () async {
      final hk = (await make(1)).single;
      final again = QuizPuzzle.fromJson(
          jsonDecode(jsonEncode(hk.toJson())) as Map<String, Object?>);
      expect(again.ruleset, Ruleset.hongKong);
      expect(again.table.minimumFaan, hk.table.minimumFaan);
      expect(jsonEncode(again.toJson()), jsonEncode(hk.toJson()));

      final riichi = (await QuizGenerator(seed: 7, mortal: stand())
              .generate(1, maxTries: 400))
          .single;
      expect(riichi.toJson()['table'], isNot(contains('ruleset')),
          reason: 'the shipped riichi puzzles carry no ruleset key');
      expect(
          QuizPuzzle.fromJson(jsonDecode(jsonEncode(riichi.toJson()))
                  as Map<String, Object?>)
              .ruleset,
          Ruleset.riichi);
    });

    test('the shipped file has a pool of each', () {
      final puzzles = [
        for (final p
            in (jsonDecode(File('assets/quiz/daily.json').readAsStringSync())
                as Map<String, Object?>)['puzzles']! as List)
          QuizPuzzle.fromJson(p as Map<String, Object?>),
      ];
      final riichi = puzzles.where((p) => p.ruleset == Ruleset.riichi);
      final hk = puzzles.where((p) => p.ruleset == Ruleset.hongKong);
      // Five a day: a pool of this size is weeks of days before one repeats.
      expect(riichi.length, greaterThanOrEqualTo(kQuizPerDay * 60));
      expect(hk.length, greaterThanOrEqualTo(kQuizPerDay * 50));
      expect(riichi.every((p) => p.id.startsWith('q')), isTrue);
      expect(hk.every((p) => p.id.startsWith('hk')), isTrue);
      expect(hk.where((p) => p.kind == QuizKind.call), isNotEmpty);
    });

    test('rulesets without puzzles of their own take riichi\'s', () {
      expect(quizRulesetFor(Ruleset.riichi), Ruleset.riichi);
      expect(quizRulesetFor(Ruleset.hongKong), Ruleset.hongKong);
      for (final r in [Ruleset.taiwanese, Ruleset.sichuan, Ruleset.mcr]) {
        expect(quizRulesetFor(r), Ruleset.riichi, reason: r.name);
      }
    });
  });

  test('a day has five different puzzles, round the pool', () {
    final day = dailyIndexes(DateTime(2026, 10, 20), 60);
    expect(day, hasLength(kQuizPerDay));
    expect(day.toSet(), hasLength(kQuizPerDay));
    expect(dailyIndexes(DateTime(2026, 10, 20, 0, 5), 60),
        dailyIndexes(DateTime(2026, 10, 20, 23, 55), 60));
    // The next day picks up where this one stopped, so nothing repeats until
    // the whole pool has been played.
    expect(dailyIndexes(DateTime(2026, 10, 21), 60).first, (day.last + 1) % 60);
    final seen = <int>{};
    for (var d = 0; d < 12; d++) {
      seen.addAll(dailyIndexes(DateTime(2026, 10, 20 + d), 60));
    }
    expect(seen, hasLength(60));
    // A pool too small for a day gives each puzzle once.
    expect(dailyIndexes(DateTime(2026, 1, 1), 1), [0]);
    expect(dailyIndexes(DateTime(2026, 1, 1), 3).toSet(), {0, 1, 2});
  });

  test('Mortal replies read as choices', () {
    QuizChoice? read(Map<String, Object?> reply,
            {required bool call, required QuizKind kind}) =>
        mortalChoice(MortalAdvice.fromReply(reply, call: call), kind: kind);
    expect(
        read({
          'reaction': {'type': 'dahai', 'pai': 'P'}
        }, call: false, kind: QuizKind.discard),
        const QuizChoice(QuizMove.discard, TileType.haku));
    expect(
        read({
          'reaction': {
            'type': 'chi',
            'pai': '4m',
            'consumed': ['3m', '5m']
          }
        }, call: true, kind: QuizKind.call),
        const QuizChoice(QuizMove.chi, TileType.man3));
    expect(
        read({
          'reaction': {'type': 'hora'}
        }, call: false, kind: QuizKind.discard),
        isNull);
    expect(read({'reaction': null}, call: true, kind: QuizKind.call),
        const QuizChoice(QuizMove.pass));
  });
}
