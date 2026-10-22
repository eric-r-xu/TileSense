/// The daily quiz, "What would TileSensor do?": a posed table, four choices,
/// and one right answer. A riichi puzzle's answer is one that TileSense and
/// Mortal both give; a Hong Kong puzzle has no Mortal to ask, so its answer is
/// TileSense's, kept only where the guide leads by a clear margin.
///
/// A puzzle is stored as its table, its choices and the answer. TileSense's
/// side is never trusted from the file: [tileSenseChoice] works it out again
/// from the table with the same guide the game uses, and a test fails if that
/// ever stops matching [QuizPuzzle.answer]. Mortal's side is stored (it needs
/// the sidecar, which the app may not have), so the file is built offline by
/// `tools/build_quiz.dart`, which keeps only the tables both agree on.
library;

import 'package:mahjong_core/hong_kong/hong_kong_rules.dart';
import 'package:mahjong_core/mjai.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/tile.dart';

import '../game/mortal_advisor.dart' show MortalAdvice, MortalStatus;
import '../game/sfx.dart' show Character;
import '../scenario/scenario.dart';
import 'auto_dials.dart' show kPlacementHands;
import '../scenario/scenario_controller.dart';
import 'efficiency_engine.dart' show GuidedAction;

/// What a choice does.
enum QuizMove {
  /// Cut [QuizChoice.tile] and stay quiet (a closed hand stays closed).
  discard,

  /// Declare riichi, cutting [QuizChoice.tile].
  riichi,

  /// Let the offered tile go by.
  pass,

  /// Chi the offered tile, with the run whose lowest tile is
  /// [QuizChoice.tile].
  chi,
  pon,
  kan,
}

/// What the table asks.
enum QuizKind {
  /// You hold 14 tiles: what do you cut?
  discard,

  /// You hold 13 and an opponent has cut: what do you do with that tile?
  call,
}

/// One answer on offer, and what either engine can answer with.
class QuizChoice {
  const QuizChoice(this.move, [this.tile]);

  final QuizMove move;

  /// The tile cut by [QuizMove.discard] and [QuizMove.riichi]; the run's
  /// lowest tile for [QuizMove.chi]; null otherwise.
  final TileType? tile;

  @override
  bool operator ==(Object other) =>
      other is QuizChoice && other.move == move && other.tile == tile;

  @override
  int get hashCode => Object.hash(move, tile);

  @override
  String toString() => '${move.name}${tile == null ? '' : ' ${tile!.code}'}';

  Map<String, Object?> toJson() =>
      {'move': move.name, if (tile != null) 'tile': tile!.code};

  factory QuizChoice.fromJson(Map<String, Object?> json) => QuizChoice(
        QuizMove.values.byName(json['move']! as String),
        json['tile'] == null ? null : tileOfCode(json['tile']! as String),
      );
}

final Map<String, TileType> _byCode = {
  for (final t in TileType.values)
    if (t.isPlayingTile) t.code: t,
};

/// The playing tile whose [TileType.code] is [code] (`5m`, `E`, `B`).
TileType tileOfCode(String code) =>
    _byCode[code] ?? (throw FormatException('unknown tile "$code"'));

/// The playing tile named in mjai notation (`5m`, `E`, `P`), red marker or not.
TileType tileOfMjai(String name) => switch (name.replaceFirst('r', '')) {
      'P' => TileType.haku,
      'F' => TileType.hatsu,
      'C' => TileType.chun,
      final other => tileOfCode(other),
    };

/// A posed table in a form that goes to JSON and back: what the guide reads
/// and nothing else. No calls are held by anyone, and no tile is red, which
/// keeps puzzles simple to read.
class QuizTable {
  const QuizTable({
    required this.roundWind,
    required this.dealer,
    required this.honba,
    required this.riichiSticks,
    required this.dora,
    required this.wallRemaining,
    required this.hand,
    required this.ponds,
    required this.riichiAt,
    this.offered,
    this.offeredFrom = 1,
    this.points = const [25000, 25000, 25000, 25000],
    this.ruleset = Ruleset.riichi,
    this.minimumFaan = HongKongRules.defaultMinimumFaan,
  });

  /// The rules the table is played under; the quiz offers riichi and Hong
  /// Kong (see [kQuizRulesets]).
  final Ruleset ruleset;

  /// A Hong Kong table's minimum faan; unused under any other rules.
  final int minimumFaan;

  final Wind roundWind;

  /// The seat holding the deal; you are seat 0.
  final int dealer;
  final int honba;
  final int riichiSticks;
  final List<TileType> dora;
  final int wallRemaining;

  /// Your concealed tiles; for a discard puzzle the last is the one just drawn.
  final List<TileType> hand;

  /// Each seat's discards in order, you first.
  final List<List<TileType>> ponds;

  /// Per seat, the pond index of the riichi declaration, or -1.
  final List<int> riichiAt;

  /// Every seat's score, you first. Uneven scores are what make placement
  /// matter in the last hands.
  final List<int> points;

  /// The tile on offer, for a call puzzle.
  final TileType? offered;
  final int offeredFrom;

  QuizKind get kind => offered == null ? QuizKind.discard : QuizKind.call;

  factory QuizTable.fromScenario(Scenario s) => QuizTable(
        roundWind: s.roundWind,
        dealer: s.dealer,
        honba: s.honba,
        riichiSticks: s.riichiSticks,
        dora: List.of(s.dora),
        wallRemaining: s.wallRemaining,
        hand: [for (final t in s.hand) t.type],
        ponds: [
          for (final seat in s.seats) [for (final t in seat.pond) t.type],
        ],
        riichiAt: [for (final seat in s.seats) seat.riichiPondIndex],
        offered: s.offered?.type,
        offeredFrom: s.offeredFrom,
        points: List.of(s.points),
        ruleset: s.ruleset,
        minimumFaan: s.minimumFaan,
      );

  /// Poses this table on [s], replacing whatever it held.
  void applyTo(Scenario s) {
    s.ruleset = ruleset;
    s.minimumFaan = minimumFaan;
    s.clear();
    s.roundWind = roundWind;
    s.dealer = dealer;
    s.honba = honba;
    s.riichiSticks = riichiSticks;
    s.dora
      ..clear()
      ..addAll(dora);
    s.wallRemaining = wallRemaining;
    s.points = List.of(points);
    for (final t in hand) {
      s.hand.add(s.mint(t));
    }
    for (var i = 0; i < 4; i++) {
      for (final t in ponds[i]) {
        s.seats[i].pond.add(s.mint(t));
      }
      s.seats[i].riichiPondIndex = riichiAt[i];
      s.seats[i].riichi = riichiAt[i] >= 0;
    }
    s.offered = offered == null ? null : s.mint(offered!);
    s.offeredFrom = offeredFrom;
  }

  /// A guide posed on this table, with Mortal switched off: the app reads
  /// Mortal's side from the puzzle file and never calls the sidecar here.
  ///
  /// [seatCharacters] puts a persona in each seat of the table drawn from it.
  ScenarioController pose({List<Character>? seatCharacters}) =>
      ScenarioController(askMortal: false, seatCharacters: seatCharacters)
        ..edit(applyTo);

  Map<String, Object?> toJson() => {
        if (ruleset != Ruleset.riichi) 'ruleset': ruleset.name,
        if (ruleset.isHongKong) 'minimumFaan': minimumFaan,
        'roundWind': roundWind.name,
        'dealer': dealer,
        if (honba != 0) 'honba': honba,
        if (riichiSticks != 0) 'riichiSticks': riichiSticks,
        'dora': [for (final t in dora) t.code],
        'wall': wallRemaining,
        'hand': [for (final t in hand) t.code],
        'ponds': [
          for (final p in ponds) [for (final t in p) t.code],
        ],
        if (riichiAt.any((i) => i >= 0)) 'riichiAt': riichiAt,
        if (offered != null) 'offered': offered!.code,
        if (offered != null) 'offeredFrom': offeredFrom,
        if (points.toSet().length > 1) 'points': points,
      };

  factory QuizTable.fromJson(Map<String, Object?> json) {
    List<TileType> tiles(Object? codes) =>
        [for (final c in codes! as List) tileOfCode(c as String)];
    return QuizTable(
      ruleset: json['ruleset'] == null
          ? Ruleset.riichi
          : Ruleset.values.byName(json['ruleset']! as String),
      minimumFaan:
          json['minimumFaan'] as int? ?? HongKongRules.defaultMinimumFaan,
      roundWind: Wind.values.byName(json['roundWind']! as String),
      dealer: json['dealer']! as int,
      honba: json['honba'] as int? ?? 0,
      riichiSticks: json['riichiSticks'] as int? ?? 0,
      dora: tiles(json['dora']),
      wallRemaining: json['wall']! as int,
      hand: tiles(json['hand']),
      ponds: [for (final p in json['ponds']! as List) tiles(p)],
      riichiAt: (json['riichiAt'] as List?)?.cast<int>() ?? [-1, -1, -1, -1],
      offered: json['offered'] == null
          ? null
          : tileOfCode(json['offered']! as String),
      offeredFrom: json['offeredFrom'] as int? ?? 1,
      points: (json['points'] as List?)?.cast<int>() ??
          const [25000, 25000, 25000, 25000],
    );
  }
}

/// How far into the hand it is, by the wall left.
enum QuizStage { early, middle, late }

/// What the table says about timing and standing, for the reveal: how late
/// in the hand and the game it is, where you stand, and who is threatening.
class QuizSituation {
  const QuizSituation({
    required this.roundWind,
    required this.hand,
    required this.handsLeft,
    required this.stage,
    required this.wallRemaining,
    required this.isDealer,
    required this.points,
    required this.rank,
    required this.behindFirst,
    required this.aheadOfNext,
    required this.placementFocus,
    this.riichiSeat,
    this.riichiTurnsAgo,
  });

  final Wind roundWind;

  /// The hand number within the round wind, 1 to 4.
  final int hand;
  final int handsLeft;
  final QuizStage stage;
  final int wallRemaining;
  final bool isDealer;
  final List<int> points;

  /// Your place, 1 to 4; seats level on points share the better place.
  final int rank;

  /// Points to the leader; 0 when you lead.
  final int behindFirst;

  /// Your lead over the seat just below you; 0 when you are last or level.
  final int aheadOfNext;

  /// The last hands, with scores to weigh: the guide plays for placement.
  final bool placementFocus;

  /// The first opponent in riichi, and how many turns ago it declared.
  final int? riichiSeat;
  final int? riichiTurnsAgo;

  bool get evenScores => points.toSet().length == 1;
}

/// The wall left at which a hand turns from early to middle, and to late.
const int kMiddleWall = 44;
const int kLateWall = 26;

QuizSituation quizSituation(QuizTable t) {
  final scores = t.points;
  final mine = scores[0];
  final rank = 1 + scores.where((p) => p > mine).length;
  final lead = scores.reduce((a, b) => a > b ? a : b);
  final below = [
    for (final p in scores.skip(1))
      if (p < mine) p
  ];
  final scenarioHands = Scenario.handsLeftIn(t.roundWind, t.dealer);
  int? riichiSeat;
  for (var seat = 1; seat < 4 && riichiSeat == null; seat++) {
    if (t.riichiAt[seat] >= 0) riichiSeat = seat;
  }
  return QuizSituation(
    roundWind: t.roundWind,
    hand: t.dealer + 1,
    handsLeft: scenarioHands,
    stage: t.wallRemaining > kMiddleWall
        ? QuizStage.early
        : t.wallRemaining >= kLateWall
            ? QuizStage.middle
            : QuizStage.late,
    wallRemaining: t.wallRemaining,
    isDealer: t.dealer == 0,
    points: scores,
    rank: rank,
    behindFirst: lead - mine,
    aheadOfNext:
        below.isEmpty ? 0 : mine - below.reduce((a, b) => a > b ? a : b),
    placementFocus: t.ruleset.isRiichi &&
        scores.toSet().length > 1 &&
        scenarioHands <= kPlacementHands,
    riichiSeat: riichiSeat,
    riichiTurnsAgo: riichiSeat == null
        ? null
        : t.ponds[riichiSeat].length - t.riichiAt[riichiSeat],
  );
}

/// One daily question.
class QuizPuzzle {
  const QuizPuzzle({
    required this.id,
    required this.table,
    required this.choices,
    required this.answer,
    this.mortalRanks = const {},
    this.margin = 0,
    this.riichiOption = false,
  });

  /// Stable name, `q0001`; telemetry keys on it.
  final String id;
  final QuizTable table;

  /// The options as shown, in order; [answer] is one of them.
  final List<QuizChoice> choices;

  /// What TileSense says, and under riichi Mortal too.
  final QuizChoice answer;

  /// Mortal's order of preference over the legal discards, 1 = its pick, keyed
  /// by mjai tile name (`5p`, `E`, `P`). Empty for a call puzzle, where Mortal
  /// names only its move.
  final Map<String, int> mortalRanks;

  /// How far ahead of the next-best line TileSense's pick was, as a fraction
  /// of its expected value; kept so weak puzzles can be told apart later.
  final double margin;

  /// True when the best cut leaves a ready hand, so the question is also
  /// whether to declare riichi or stay quiet (dama): the same cut is offered
  /// both ways, and a plain [QuizMove.discard] choice means dama.
  final bool riichiOption;

  QuizKind get kind => table.kind;

  /// The rules the puzzle is posed under.
  Ruleset get ruleset => table.ruleset;

  /// Mortal's rank for [tile], 1 = its pick.
  int? mortalRankOf(TileType tile) => mortalRanks[mjaiTile(Tile(-1, tile))];

  Map<String, Object?> toJson() => {
        'id': id,
        'table': table.toJson(),
        'choices': [for (final c in choices) c.toJson()],
        'answer': answer.toJson(),
        if (mortalRanks.isNotEmpty) 'mortalRanks': mortalRanks,
        'margin': double.parse(margin.toStringAsFixed(3)),
        if (riichiOption) 'riichiOption': true,
      };

  factory QuizPuzzle.fromJson(Map<String, Object?> json) => QuizPuzzle(
        id: json['id']! as String,
        table: QuizTable.fromJson(json['table']! as Map<String, Object?>),
        choices: [
          for (final c in json['choices']! as List)
            QuizChoice.fromJson(c as Map<String, Object?>),
        ],
        answer: QuizChoice.fromJson(json['answer']! as Map<String, Object?>),
        mortalRanks:
            (json['mortalRanks'] as Map?)?.cast<String, int>() ?? const {},
        margin: (json['margin'] as num?)?.toDouble() ?? 0,
        riichiOption: json['riichiOption'] == true,
      );

  /// A guide posed on this puzzle's table; see [QuizTable.pose].
  ScenarioController pose({List<Character>? seatCharacters}) =>
      table.pose(seatCharacters: seatCharacters);
}

/// TileSense's one clear answer on the posed table, or null when there is
/// none: no table to read, a win on offer, or several lines tied for first.
QuizChoice? tileSenseChoice(ScenarioController c) {
  if (c.blockedReason != null) return null;
  if (c.scenario.isDiscardRead) {
    final best = [
      for (final l in c.report.lines)
        if (l.recommended) l
    ];
    if (best.length != 1) return null;
    return QuizChoice(
        c.report.recommendRiichi ? QuizMove.riichi : QuizMove.discard,
        best.single.discard);
  }
  final advice = c.callAdvice;
  if (advice == null) return null;
  return _callChoice(advice.best.action, advice.best.meldLow);
}

QuizChoice? _callChoice(GuidedAction action, TileType? meldLow) =>
    switch (action) {
      GuidedAction.pass => const QuizChoice(QuizMove.pass),
      GuidedAction.pon => const QuizChoice(QuizMove.pon),
      GuidedAction.kan => const QuizChoice(QuizMove.kan),
      GuidedAction.chi =>
        meldLow == null ? null : QuizChoice(QuizMove.chi, meldLow),
      _ => null,
    };

/// The choice for each evaluated call option, best first.
List<QuizChoice> callChoices(ScenarioController c) => [
      for (final o in c.callAdvice?.options ?? const [])
        if (_callChoice(o.action, o.meldLow) case final choice?) choice,
    ];

/// Mortal's answer as a choice, or null when it gave no usable move (a win,
/// nine terminals, or the sidecar failing).
QuizChoice? mortalChoice(MortalAdvice advice, {required QuizKind kind}) {
  if (advice.status != MortalStatus.ready) return null;
  final action = advice.action;
  if (kind == QuizKind.discard) {
    if (action != null || advice.discard == null) return null;
    return QuizChoice(advice.riichi ? QuizMove.riichi : QuizMove.discard,
        tileOfMjai(advice.discard!));
  }
  if (action == null) return null;
  if (action == 'PASS') return const QuizChoice(QuizMove.pass);
  if (action == 'PON') return const QuizChoice(QuizMove.pon);
  if (action == 'KAN') return const QuizChoice(QuizMove.kan);
  if (action.startsWith('CHI ')) {
    // "CHI 345m": the run's lowest tile is its first digit.
    final run = action.substring(4);
    return QuizChoice(
        QuizMove.chi, tileOfCode('${run[0]}${run[run.length - 1]}'));
  }
  return null;
}

/// The puzzle for [day], one a day for ever: the local calendar date counted
/// in days, taken round the [count] puzzles. Needs no clock but the device's,
/// and two players on the same date get the same puzzle.
int dailyIndex(DateTime day, int count) {
  final days = DateTime.utc(day.year, day.month, day.day)
      .difference(DateTime.utc(2024))
      .inDays;
  return days % count;
}

/// The numbers the guide has behind one choice, for the answer's explanation.
class QuizFacts {
  const QuizFacts({
    required this.shanten,
    required this.expectedValue,
    required this.reason,
    this.ukeire,
    this.risk,
  });

  /// Tiles from a ready hand after this choice; 0 is ready.
  final int shanten;

  /// Live tiles that would improve the hand; null for a call.
  final int? ukeire;

  /// The guide's expected value, in points.
  final double expectedValue;

  /// What the choice is charged for the chance of dealing in; null for a call
  /// and when nobody is in riichi.
  final double? risk;

  /// The guide's own sentence about the choice; English only.
  final String reason;
}

/// What the guide has to say about [choice] on the table posed by [c], or null
/// when it did not weigh that choice.
QuizFacts? quizFacts(ScenarioController c, QuizChoice choice) {
  switch (choice.move) {
    case QuizMove.discard || QuizMove.riichi:
      for (final l in c.report.lines) {
        if (l.discard != choice.tile) continue;
        return QuizFacts(
          shanten: l.shanten,
          ukeire: l.ukeire,
          expectedValue: l.expectedValue,
          risk: l.dealInCost > 0 ? l.dealInCost : null,
          reason: l.reason,
        );
      }
    case QuizMove.pass || QuizMove.chi || QuizMove.pon || QuizMove.kan:
      final action = switch (choice.move) {
        QuizMove.pass => GuidedAction.pass,
        QuizMove.chi => GuidedAction.chi,
        QuizMove.pon => GuidedAction.pon,
        _ => GuidedAction.kan,
      };
      final o = c.callAdvice?.forAction(action);
      if (o != null) {
        return QuizFacts(
            shanten: o.shantenAfter,
            expectedValue: o.expectedValue,
            reason: o.reason);
      }
  }
  return null;
}
