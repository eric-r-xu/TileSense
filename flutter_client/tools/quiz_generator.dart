/// Makes daily-quiz puzzles out of random tables, keeping only the ones
/// TileSense and Mortal answer the same way, with a clear margin. Under Hong
/// Kong rules there is no Mortal to ask, so TileSense's clear margin is all
/// that is asked of a table. Driven by
/// `build_quiz.dart`; split out so tests can run it with a stand-in Mortal.
library;

import 'dart:math';

import 'package:mahjong_core/mjai.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/tile.dart';
import 'package:tilesense/game/mortal_advisor.dart' show MortalAdvice;
import 'package:tilesense/logic/daily_quiz.dart';
import 'package:tilesense/scenario/scenario.dart';
import 'package:tilesense/scenario/scenario_controller.dart';
import 'package:tilesense/scenario/scenario_mjai.dart';

/// Mortal's advice for the posed table, or null when no history fits it.
typedef MortalAsk = Future<MortalAdvice?> Function(Scenario table,
    {required bool call});

/// Asks a real Mortal sidecar through the same mjai history the guide uses.
MortalAsk askSidecar(
        Future<MortalAdvice> Function(List<MjaiEvent>, {required bool call})
            advise) =>
    (table, {required call}) async {
      final events = scenarioMjaiEvents(table);
      return events == null ? null : advise(events, call: call);
    };

/// Why a table did not become a puzzle, for the tally.
enum Reject {
  unreadable,
  noClearAnswer,
  tooClose,
  fewChoices,
  mortalSilent,
  disagree,

  /// A call puzzle whose answer is pass, once passes are half the calls.
  tooManyPasses,
}

class QuizGenerator {
  QuizGenerator({
    required int seed,
    this.mortal,
    this.ruleset = Ruleset.riichi,
    this.minMargin = 0.10,
  })  : assert(mortal != null || !ruleset.isRiichi, 'riichi needs Mortal'),
        _random = Random(seed);

  /// Mortal's second opinion; null under rules it does not play.
  final MortalAsk? mortal;

  /// The rules the tables are played under.
  final Ruleset ruleset;

  /// The least lead TileSense's pick must have over the next line, as a
  /// fraction of its expected value.
  final double minMargin;
  final Random _random;

  // Call puzzles made so far, by whether the answer is to let the tile go.
  // Passing is the easy guess, so no more than half may be passes.
  int _passes = 0;
  int _calls = 0;

  /// How many tables ended in each way, filled as [attempt] runs.
  final Map<Reject?, int> tally = {};

  /// Tries one random table of [kind]; null when it is not worth asking.
  Future<QuizPuzzle?> attempt(String id, QuizKind kind) async {
    final c = ScenarioController(askMortal: false);
    final table = randomTable(_random, kind, ruleset: ruleset);
    c.edit(table.applyTo);
    QuizPuzzle? out;
    final why = await _judge(id, c, kind, (p) => out = p);
    tally[why] = (tally[why] ?? 0) + 1;
    c.dispose();
    return out;
  }

  Future<Reject?> _judge(String id, ScenarioController c, QuizKind kind,
      void Function(QuizPuzzle) accept) async {
    if (c.blockedReason != null) return Reject.unreadable;
    final answer = tileSenseChoice(c);
    if (answer == null) return Reject.noClearAnswer;

    final double margin;
    final List<QuizChoice> choices;
    var riichiOption = false;
    if (kind == QuizKind.discard) {
      final lines = c.report.lines;
      final best = lines.firstWhere((l) => l.recommended);
      final rest = [
        for (final l in lines)
          if (!l.recommended) l
      ]..sort((a, b) => b.expectedValue.compareTo(a.expectedValue));
      if (rest.length < 3) return Reject.fewChoices;
      final top = max(best.expectedValue.abs(), 1.0);
      margin = (best.expectedValue - rest.first.expectedValue) / top;
      // A cut that leaves a ready hand is a two-part question: which cut,
      // then riichi or dama. The stored choices are just the cuts; the page
      // asks riichi or dama once a cut that leaves you ready is picked.
      riichiOption = ruleset.isRiichi && best.shanten == 0;
      choices = [
        QuizChoice(QuizMove.discard, answer.tile),
        for (final l in rest) QuizChoice(QuizMove.discard, l.discard),
      ].take(4).toList();
    } else {
      final options = c.callAdvice!.options;
      choices = callChoices(c);
      if (choices.length < 3) return Reject.fewChoices;
      margin = options.length < 2
          ? 0
          : (options[0].expectedValue - options[1].expectedValue) /
              max(options[0].expectedValue.abs(), 1.0);
      if (!choices.contains(answer)) return Reject.noClearAnswer;
    }
    if (margin < minMargin) return Reject.tooClose;

    final ask = mortal;
    final MortalAdvice? advice;
    if (ask == null) {
      advice = null;
    } else {
      advice = await ask(c.scenario, call: kind == QuizKind.call);
      final theirs = advice == null ? null : mortalChoice(advice, kind: kind);
      if (theirs == null) return Reject.mortalSilent;
      if (theirs != answer) return Reject.disagree;
    }

    if (kind == QuizKind.call) {
      final pass = answer.move == QuizMove.pass;
      if (pass && (_passes + 1) * 2 > _calls + 1) return Reject.tooManyPasses;
      _calls++;
      if (pass) _passes++;
    }

    accept(QuizPuzzle(
      id: id,
      table: QuizTable.fromScenario(c.scenario),
      choices: choices..shuffle(_random),
      answer: answer,
      mortalRanks: advice?.ranks ?? const {},
      margin: margin,
      riichiOption: riichiOption,
    ));
    return null;
  }

  /// The id prefix for [ruleset]: riichi's are `q0001`, the original ones.
  static String idPrefix(Ruleset ruleset) => ruleset.isRiichi ? 'q' : 'hk';

  /// Puzzles of alternating kinds until [count] are made or [maxTries] tables
  /// have been asked about. Ids continue from [firstNumber].
  Future<List<QuizPuzzle>> generate(int count,
      {int firstNumber = 1, int maxTries = 5000}) async {
    final out = <QuizPuzzle>[];
    for (var tries = 0; out.length < count && tries < maxTries; tries++) {
      // Mostly discards: they are what a hand is mostly made of.
      final kind = _random.nextInt(3) == 0 ? QuizKind.call : QuizKind.discard;
      final id = '${idPrefix(ruleset)}'
          '${(firstNumber + out.length).toString().padLeft(4, '0')}';
      final puzzle = await attempt(id, kind);
      if (puzzle != null) out.add(puzzle);
    }
    return out;
  }
}

// --- random tables ----------------------------------------------------

/// A random mid-game table. The hand is a finished hand with a few tiles
/// swapped for others, so it sits one to four steps from ready rather than
/// being the junk a plain deal usually is.
QuizTable randomTable(Random r, QuizKind kind,
    {Ruleset ruleset = Ruleset.riichi}) {
  final riichi = ruleset.isRiichi;
  // Copies of each playing tile still unplaced, indexed by type - 1.
  final left = List.filled(34, 4);
  bool has(TileType t) => left[t.index - 1] > 0;
  TileType take(TileType t) {
    left[t.index - 1]--;
    return t;
  }

  TileType at(int i) => TileType.values[i];

  // A finished 14-tile hand: four sets and a pair, from one or two suits and
  // a few honors.
  final suits = [0, 1, 2]..shuffle(r);
  final pool = suits.take(r.nextBool() ? 1 : 2).toList();
  TileType suited(int suit, int n) =>
      at([TileType.man1, TileType.pin1, TileType.sou1][suit].index + n - 1);
  List<TileType> hand;
  while (true) {
    final tryLeft = List.of(left);
    final tiles = <TileType>[];
    bool grab(TileType t) {
      if (tryLeft[t.index - 1] == 0) return false;
      tryLeft[t.index - 1]--;
      tiles.add(t);
      return true;
    }

    var ok = true;
    for (var s = 0; s < 4 && ok; s++) {
      final honor = r.nextInt(5) == 0;
      if (honor) {
        final t = at(TileType.ton.index + r.nextInt(7));
        ok = grab(t) && grab(t) && grab(t);
      } else if (r.nextInt(10) < 7) {
        final suit = pool[r.nextInt(pool.length)];
        final n = 1 + r.nextInt(7);
        ok = grab(suited(suit, n)) &&
            grab(suited(suit, n + 1)) &&
            grab(suited(suit, n + 2));
      } else {
        final t = suited(pool[r.nextInt(pool.length)], 1 + r.nextInt(9));
        ok = grab(t) && grab(t) && grab(t);
      }
    }
    if (ok) {
      final pair = r.nextInt(6) == 0
          ? at(TileType.ton.index + r.nextInt(7))
          : suited(pool[r.nextInt(pool.length)], 1 + r.nextInt(9));
      ok = grab(pair) && grab(pair);
    }
    if (ok && tiles.length == 14) {
      hand = tiles;
      break;
    }
  }
  for (final t in hand) {
    take(t);
  }

  // Swap 1-4 tiles for random ones the table can still spare.
  final swaps = 1 + r.nextInt(4);
  for (var i = 0; i < swaps; i++) {
    TileType t;
    do {
      t = at(1 + r.nextInt(34));
    } while (!has(t));
    final k = r.nextInt(hand.length);
    left[hand[k].index - 1]++;
    hand[k] = take(t);
  }

  hand.shuffle(r);
  TileType? offered;
  int offeredFrom = 1;
  if (kind == QuizKind.call) {
    // Put back one tile to make 13, and offer one that could be called.
    final back = hand.removeLast();
    left[back.index - 1]++;
    // Most often offer a tile that could be pon'd and chi'd both, so there
    // is a real choice to make and passing is not the only sensible answer.
    bool held(TileType t) => hand.contains(t);
    final either = [
      for (final t in hand.toSet())
        if (t.isSuit &&
            has(t) &&
            hand.where((h) => h == t).length >= 2 &&
            [(-2, -1), (-1, 1), (1, 2)].any((d) =>
                t.number + d.$1 >= 1 &&
                t.number + d.$2 <= 9 &&
                held(suited(t.suit, t.number + d.$1)) &&
                held(suited(t.suit, t.number + d.$2))))
          t,
    ];
    final both = either.isNotEmpty && r.nextInt(4) > 0;
    final pivot =
        both ? either[r.nextInt(either.length)] : hand[r.nextInt(hand.length)];
    var candidate = pivot;
    if (!both && pivot.isSuit && r.nextBool()) {
      final n = pivot.number + (const [-2, -1, 1, 2])[r.nextInt(4)];
      if (n >= 1 && n <= 9) candidate = suited(pivot.suit, n);
    }
    if (!has(candidate)) candidate = pivot;
    if (!has(candidate)) {
      do {
        candidate = at(1 + r.nextInt(34));
      } while (!has(candidate));
    }
    offered = take(candidate);
    // Only the player on your left can be chowed from.
    offeredFrom = !both && (r.nextInt(3) == 0 || candidate == pivot)
        ? 1 + r.nextInt(3)
        : 3;
  } else {
    // The drawn tile goes last; the rest are in order.
    final drawn = hand.removeAt(r.nextInt(hand.length));
    hand.sort((a, b) => a.index.compareTo(b.index));
    hand.add(drawn);
  }
  if (kind == QuizKind.call) hand.sort((a, b) => a.index.compareTo(b.index));

  // One dora indicator; Hong Kong has none.
  final dora = <TileType>[];
  if (riichi) {
    TileType indicator;
    do {
      indicator = at(1 + r.nextInt(34));
    } while (!has(indicator));
    dora.add(take(indicator));
  }

  // Ponds: the same number of turns for every seat. Early cuts lean on
  // terminals and honors, as real ones do.
  final turns = 4 + r.nextInt(10);
  final ponds = List.generate(4, (_) => <TileType>[]);
  for (var seat = 0; seat < 4; seat++) {
    for (var i = 0; i < turns; i++) {
      final weights = [
        for (var k = 0; k < 34; k++)
          left[k] * (at(k + 1).isTerminalOrHonor ? 2 : 1),
      ];
      var pick = r.nextInt(weights.reduce((a, b) => a + b));
      var k = 0;
      while (pick >= weights[k]) {
        pick -= weights[k++];
      }
      ponds[seat].add(take(at(k + 1)));
    }
  }

  // Sometimes one opponent is in riichi, declared a few cuts ago.
  final riichiAt = [-1, -1, -1, -1];
  var sticks = 0;
  if (riichi && r.nextInt(10) < 3) {
    riichiAt[1 + r.nextInt(3)] = max(2, turns - 1 - r.nextInt(4));
    sticks = 1;
  }

  // Half the tables are level on points; the rest have a spread, which is
  // what makes placement matter in the last hands.
  var points = const [25000, 25000, 25000, 25000];
  if (riichi && r.nextBool()) {
    List<int> spread;
    do {
      final d = [for (var i = 0; i < 3; i++) (r.nextInt(301) - 150) * 100];
      spread = [
        25000 - d.fold(0, (a, b) => a + b),
        for (final x in d) 25000 + x,
      ];
    } while (spread.any((p) => p < 1000) || spread.toSet().length < 4);
    points = spread;
  }

  final dealer = r.nextInt(4);
  return QuizTable(
    roundWind: r.nextInt(5) < 2 ? Wind.south : Wind.east,
    dealer: dealer,
    honba: 0,
    riichiSticks: sticks,
    dora: dora,
    wallRemaining: max(10, 70 - 4 * turns - 1),
    hand: hand,
    ponds: ponds,
    riichiAt: riichiAt,
    offered: offered,
    offeredFrom: offeredFrom,
    points: points,
    ruleset: ruleset,
  );
}
