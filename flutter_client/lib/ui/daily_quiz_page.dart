/// The daily quiz, "What would TileSensor do?": today's posed table, four
/// choices, and once you answer, why TileSense and Mortal pick what they do.
/// The puzzles are `assets/quiz/daily.json`, built by `tools/build_quiz.dart`;
/// the model and the explanation numbers are in `logic/daily_quiz.dart`.
library;

import 'dart:convert';
import 'dart:math' show Random;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:mahjong_core/round.dart' show CallType;
import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/tile.dart';

import '../l10n/l10n.dart';
import '../l10n/mahjong_terms.dart';
import '../logic/daily_quiz.dart';
import '../logic/progress.dart';
import '../telemetry/telemetry.dart';
import '../scenario/scenario_controller.dart';
import 'bar_back_button.dart';
import 'character_select_page.dart' show randomSeatCharacters;
import 'e2e_id.dart';
import 'language_button.dart';
import 'ruleset_badge.dart';
import 'table_view.dart';
import 'tile_face.dart';
import 'tilesensor.dart' show kTileSensorAsset;
import 'theme.dart';

/// Reads the shipped puzzles.
Future<List<QuizPuzzle>> loadQuizPuzzles([AssetBundle? bundle]) async {
  final text =
      await (bundle ?? rootBundle).loadString('assets/quiz/daily.json');
  return [
    for (final p
        in (jsonDecode(text) as Map<String, Object?>)['puzzles']! as List)
      QuizPuzzle.fromJson(p as Map<String, Object?>),
  ];
}

/// Loads the puzzles and opens today's.
class DailyQuizScreen extends StatefulWidget {
  const DailyQuizScreen(
      {super.key,
      required this.onExit,
      this.puzzles,
      this.progress,
      this.onTelemetry});

  final VoidCallback onExit;

  /// Puzzles to use instead of the shipped file, for tests.
  final Future<List<QuizPuzzle>>? puzzles;

  /// Where the streak is kept; the app's own when null.
  final ProgressStore? progress;

  /// Where an answer is reported (see [Telemetry.quizAnsweredPayload]); the
  /// app's telemetry when null, which does nothing unless it is on.
  final void Function(Map<String, Object?> payload)? onTelemetry;

  @override
  State<DailyQuizScreen> createState() => _DailyQuizScreenState();
}

class _DailyQuizScreenState extends State<DailyQuizScreen> {
  late final Future<List<QuizPuzzle>> _puzzles =
      widget.puzzles ?? loadQuizPuzzles();

  /// Counts the answer toward the streak (only a day's first does) and
  /// reports it.
  void _record(QuizPuzzle puzzle, QuizChoice picked, bool correct) {
    final store = widget.progress ?? ProgressStore.instance;
    final now = DateTime.now();
    final first = !store.value.quizAnsweredOn(now);
    store.recordQuiz(now, correct: correct);
    final payload = Telemetry.quizAnsweredPayload(
      puzzleId: puzzle.id,
      puzzleKind: puzzle.kind.name,
      choice: '$picked',
      answer: '${puzzle.answer}',
      correct: correct,
      riichiOption: puzzle.riichiOption,
      day: dayKey(now),
      streak: store.value.quizStreakOn(now),
      firstToday: first,
    );
    (widget.onTelemetry ?? Telemetry.shared()?.quizAnswered)?.call(payload);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<QuizPuzzle>>(
        future: _puzzles,
        builder: (context, snapshot) {
          final puzzles = snapshot.data;
          if (puzzles != null && puzzles.isNotEmpty) {
            return DailyQuizPage(
              puzzle: puzzles[dailyIndex(DateTime.now(), puzzles.length)],
              onExit: widget.onExit,
              onAnswered: (puzzle, picked, correct) =>
                  _record(puzzle, picked, correct),
            );
          }
          return Material(
            color: AppColors.background,
            child: Stack(
              children: [
                Center(
                  child: snapshot.hasError || puzzles != null
                      ? Text(context.l10n.quizLoadFailed,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 18))
                      : const CircularProgressIndicator(),
                ),
                Positioned(
                  left: 4,
                  top: 8,
                  child: BarBackButton(
                    buttonKey: const Key('quizBack'),
                    label: context.l10n.back,
                    tooltip: context.l10n.backToMainMenu,
                    onPressed: widget.onExit,
                    foregroundColor: AppColors.link,
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class DailyQuizPage extends StatefulWidget {
  const DailyQuizPage({
    super.key,
    required this.puzzle,
    required this.onExit,
    this.onAnswered,
    this.random,
  });

  final QuizPuzzle puzzle;

  /// Picks the three opponents; unseeded when null.
  final Random? random;
  final VoidCallback onExit;

  /// Told once, with what was picked and whether it was right.
  final void Function(QuizPuzzle puzzle, QuizChoice picked, bool correct)?
      onAnswered;

  @override
  State<DailyQuizPage> createState() => _DailyQuizPageState();
}

class _DailyQuizPageState extends State<DailyQuizPage> {
  static const double _panelWidth = 520;

  // Three different personas for the right, across and left seats. You have
  // none: the quiz asks what you would do, not who you are.
  late final _characters = randomSeatCharacters(widget.random);
  late final ScenarioController _c =
      widget.puzzle.pose(seatCharacters: _characters);
  QuizChoice? _picked;

  /// A riichi-or-dama puzzle's first answer, the cut, while the second part
  /// (riichi or dama) is still to be asked.
  QuizChoice? _cut;

  QuizPuzzle get _puzzle => widget.puzzle;
  bool get _answered => _picked != null;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _finish(QuizChoice choice) {
    setState(() => _picked = choice);
    widget.onAnswered?.call(_puzzle, choice, choice == _puzzle.answer);
  }

  /// The first (or only) part: a choice, or on a riichi-or-dama puzzle a cut.
  /// A cut that leaves you ready goes on to ask riichi or dama; any other cut
  /// is the whole answer.
  void _pick(QuizChoice choice) {
    if (_answered || _cut != null) return;
    if (_puzzle.riichiOption && quizFacts(_c, choice)?.shanten == 0) {
      setState(() => _cut = choice);
    } else {
      _finish(choice);
    }
  }

  /// The second part: riichi or dama on the cut already chosen.
  void _pickRiichi({required bool riichi}) {
    final cut = _cut;
    if (cut == null || _answered) return;
    _finish(QuizChoice(riichi ? QuizMove.riichi : QuizMove.discard, cut.tile));
  }

  /// The colour a first-part button takes once answered. On a riichi-or-dama
  /// puzzle a cut is right or wrong by its tile, whatever came after.
  Color? _mark(QuizChoice choice) {
    if (!_answered) return null;
    if (_puzzle.riichiOption) {
      if (choice.tile == _puzzle.answer.tile) return AppColors.right;
      return choice.tile == _picked!.tile ? AppColors.wrong : null;
    }
    if (choice == _puzzle.answer) return AppColors.right;
    return choice == _picked ? AppColors.wrong : null;
  }

  /// The colour riichi or dama takes once answered: green on the right call
  /// for the right cut, red on a call made wrongly.
  Color? _markRiichi({required bool riichi}) {
    if (!_answered) return null;
    final move = riichi ? QuizMove.riichi : QuizMove.discard;
    if (_picked!.tile == _puzzle.answer.tile && move == _puzzle.answer.move) {
      return AppColors.right;
    }
    return move == _picked!.move ? AppColors.wrong : null;
  }

  String _seatName(AppLocalizations l10n) =>
      switch (_puzzle.table.offeredFrom) {
        1 => l10n.seatRight,
        2 => l10n.seatAcross,
        _ => l10n.seatLeft,
      };

  String _moveName(AppLocalizations l10n, QuizMove move) => switch (move) {
        QuizMove.discard => l10n.quizDiscard,
        QuizMove.riichi => l10n.quizRiichi,
        QuizMove.pass => l10n.practiceOptionPass,
        QuizMove.chi => l10n.callLabel(CallType.chi, Ruleset.riichi),
        QuizMove.pon => l10n.callLabel(CallType.pon, Ruleset.riichi),
        QuizMove.kan => l10n.callLabel(CallType.kan, Ruleset.riichi),
      };

  /// The tiles a choice puts on its button: the cut, or what the call makes.
  List<TileType> _faces(QuizChoice choice) {
    final offered = _puzzle.table.offered;
    return switch (choice.move) {
      QuizMove.discard || QuizMove.riichi => [choice.tile!],
      QuizMove.chi => [
          for (var i = 0; i < 3; i++) TileType.values[choice.tile!.index + i],
        ],
      QuizMove.pon => [offered!, offered, offered],
      QuizMove.kan => [offered!, offered, offered, offered],
      QuizMove.pass => const [],
    };
  }

  Widget _choiceButton(AppLocalizations l10n, int i, QuizChoice choice) {
    final selected = _cut != null && _cut!.tile == choice.tile;
    final mark = _mark(choice) ?? (selected ? AppColors.gold : null);
    final faces = _faces(choice);
    final id = 'quizChoice_$i';
    return e2eId(
      id,
      OutlinedButton(
        key: Key(id),
        onPressed: _answered || _cut != null ? null : () => _pick(choice),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          backgroundColor: mark?.withValues(alpha: 0.3),
          side: BorderSide(
              color: mark ?? Colors.white38, width: mark == null ? 1 : 3),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          minimumSize: const Size(150, 96),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_moveName(l10n, choice.move),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (faces.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final t in faces)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: TileFace(
                        type: t,
                        size:
                            faces.length == 1 ? TileSize.large : TileSize.small,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _hand() {
    final hand = _puzzle.table.hand;
    final drawn = _puzzle.kind == QuizKind.discard;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, t) in hand.indexed)
            Padding(
              padding: EdgeInsets.only(
                  left: drawn && i == hand.length - 1 ? 14 : 1.5, right: 1.5),
              child: TileFace(type: t, size: TileSize.large),
            ),
        ],
      ),
    );
  }

  // --- the reveal ----------------------------------------------------

  String _points(double v) => v.round().toString();

  TableRow _factsRow(String label, QuizFacts? f, {required Color color}) {
    Widget cell(String s, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
          child: Text(s,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: bold ? color : Colors.white,
                  fontSize: 15,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        );
    return TableRow(children: [
      cell(label, bold: true),
      cell(f == null ? '–' : '${f.shanten}'),
      cell(f?.ukeire == null ? '–' : '${f!.ukeire}'),
      cell(f == null ? '–' : _points(f.expectedValue)),
      cell(f?.risk == null ? '–' : _points(f!.risk!)),
    ]);
  }

  Widget _facts(AppLocalizations l10n, QuizFacts? best, QuizFacts? mine,
      {required bool showMine}) {
    Widget head(String s) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
          child: Text(s,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
        );
    return Table(
      key: const Key('quizFacts'),
      defaultColumnWidth: const IntrinsicColumnWidth(),
      children: [
        TableRow(children: [
          const SizedBox.shrink(),
          head(l10n.quizShanten),
          head(l10n.quizUkeire),
          head(l10n.quizEv),
          head(l10n.quizRisk),
        ]),
        _factsRow(l10n.quizBestMove, best, color: AppColors.right),
        if (showMine)
          _factsRow(l10n.quizYouPicked, mine, color: AppColors.wrong),
      ],
    );
  }

  String _mortalLine(AppLocalizations l10n) {
    final picked = _picked!;
    if (_puzzle.kind == QuizKind.call) return l10n.quizMortalPicked;
    if (picked == _puzzle.answer) return l10n.quizMortalRankFirst;
    // The right cut with the wrong riichi call: Mortal's ranking is by cut, so
    // say what it does about riichi instead.
    if (picked.tile == _puzzle.answer.tile) {
      return _puzzle.answer.move == QuizMove.riichi
          ? l10n.quizMortalRiichi
          : l10n.quizMortalDama;
    }
    final rank = _puzzle.mortalRankOf(picked.tile!);
    return rank == null
        ? l10n.quizMortalPicked
        : l10n.quizMortalRank(rank, _puzzle.mortalRanks.length);
  }

  /// 25000 as "25,000".
  String _n(int v) => v
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  /// How late it is, where you stand, and who is threatening: the context
  /// the cut or call has to be weighed in.
  Widget _situation(AppLocalizations l10n) {
    final t = quizSituation(_puzzle.table);
    final wind =
        l10n.localeName == 'en' ? t.roundWind.label : t.roundWind.kanji;
    final lines = [
      l10n.quizRoundLine(wind, t.hand, t.handsLeft),
      l10n.quizTimingLine(
          switch (t.stage) {
            QuizStage.early => l10n.quizStageEarly,
            QuizStage.middle => l10n.quizStageMiddle,
            QuizStage.late => l10n.quizStageLate,
          },
          t.wallRemaining),
      if (t.evenScores)
        l10n.quizPlaceEven(_n(t.points.first))
      else if (t.rank == 1)
        l10n.quizPlaceLead(t.rank, _n(t.aheadOfNext))
      else
        l10n.quizPlaceBehind(t.rank, _n(t.behindFirst)),
      t.isDealer ? l10n.quizDealerYes : l10n.quizDealerNo,
      if (t.riichiSeat case final seat?)
        l10n.quizThreat(_c.seatLabel(seat), t.riichiTurnsAgo!)
      else
        l10n.quizNoThreat,
      if (t.placementFocus) l10n.quizFocusPlacement else l10n.quizFocusPoints,
    ];
    return Column(
      key: const Key('quizSituation'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2, right: 8),
                  child: Icon(Icons.circle, size: 6, color: Colors.white54),
                ),
                Expanded(
                  child: Text(line,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 15, height: 1.35)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _reveal(AppLocalizations l10n) {
    final picked = _picked!;
    final ok = picked == _puzzle.answer;
    final color = ok ? AppColors.right : const Color(0xffffa000);
    final best = quizFacts(_c, _puzzle.answer);
    final mine = ok ? best : quizFacts(_c, picked);
    final reason = best?.reason ?? '';
    final sameCut = picked.tile == _puzzle.answer.tile;
    Widget heading(String s) => Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(s,
              style: const TextStyle(
                  color: AppColors.goldText,
                  fontSize: 14,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.bold)),
        );
    return Container(
      key: const Key('quizReveal'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          e2eId(
            'quizVerdict',
            Text(ok ? l10n.practiceCorrect : l10n.practiceWrong,
                key: const Key('quizVerdict'),
                style: TextStyle(
                    color:
                        ok ? const Color(0xff9ccc65) : const Color(0xffffca28),
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 6),
          Row(
            key: const Key('quizAgree'),
            children: [
              const Icon(Icons.check_circle, color: AppColors.right, size: 20),
              const SizedBox(width: 6),
              Flexible(
                child: Text(l10n.quizAgree,
                    style: const TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ],
          ),
          heading(l10n.quizSituation),
          _situation(l10n),
          heading(l10n.quizTileSenseSays),
          // Riichi and dama on the same cut have the same numbers here, so
          // there is nothing to set beside the best move.
          _facts(l10n, best, mine, showMine: !ok && !sameCut),
          // The guide writes its reasons in English only, as its panel does.
          if (reason.isNotEmpty && l10n.localeName == 'en') ...[
            const SizedBox(height: 8),
            Text(reason,
                key: const Key('quizReason'),
                style: const TextStyle(
                    color: Colors.white, fontSize: 15, height: 1.4)),
          ],
          heading(l10n.quizMortalSays),
          Text(_mortalLine(l10n),
              key: const Key('quizMortalLine'),
              style: const TextStyle(color: Colors.white, fontSize: 15)),
          const SizedBox(height: 4),
          Text(l10n.quizMortalNote,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 10),
          Text(l10n.quizDone,
              key: const Key('quizDone'),
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _riichiButton(AppLocalizations l10n, {required bool riichi}) {
    final mark = _markRiichi(riichi: riichi);
    final id = riichi ? 'quizRiichi' : 'quizDama';
    return e2eId(
      id,
      OutlinedButton(
        key: Key(id),
        onPressed: _answered ? null : () => _pickRiichi(riichi: riichi),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          backgroundColor: mark?.withValues(alpha: 0.3),
          side: BorderSide(
              color: mark ?? Colors.white38, width: mark == null ? 1 : 3),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          minimumSize: const Size(150, 64),
        ),
        child: Text(riichi ? l10n.quizRiichi : l10n.quizDama,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ),
    );
  }

  /// The second part of a riichi-or-dama puzzle, shown once a cut that leaves
  /// you ready has been chosen.
  Widget _secondPart(AppLocalizations l10n) => Column(
        key: const Key('quizSecondPart'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 18),
          Text(l10n.quizAskRiichi,
              key: const Key('quizAskRiichi'),
              style: const TextStyle(
                  color: Colors.white, fontSize: 18, height: 1.35)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _riichiButton(l10n, riichi: true),
              _riichiButton(l10n, riichi: false),
            ],
          ),
        ],
      );

  Widget _panel(AppLocalizations l10n) {
    final ask = _puzzle.kind == QuizKind.call
        ? l10n.quizAskCall(_seatName(l10n))
        : l10n.quizAskDiscard;
    final questions = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RiichiOnlyBadge(),
          const SizedBox(height: 10),
          Text(ask,
              key: const Key('quizQuestion'),
              style: const TextStyle(
                  color: Colors.white, fontSize: 20, height: 1.35)),
          const SizedBox(height: 14),
          Text(l10n.quizYourHand,
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 4),
          _hand(),
          const SizedBox(height: 16),
          Text(l10n.quizChoose,
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final (i, c) in _puzzle.choices.indexed)
                _choiceButton(l10n, i, c),
            ],
          ),
          if (_cut != null) _secondPart(l10n),
          if (_answered) ...[
            const SizedBox(height: 16),
            _reveal(l10n),
          ],
        ],
      ),
    );
    // The way out stays under the thumb however far the reveal scrolls.
    return Column(
      children: [
        Expanded(child: questions),
        BackFooter(
          buttonKey: const Key('quizBackBottom'),
          label: l10n.backToMenu,
          tooltip: l10n.backToMainMenu,
          onPressed: widget.onExit,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final barHeight = BarBackButton.toolbarHeight(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        toolbarHeight: barHeight,
        titleSpacing: 8,
        leadingWidth: BarBackButton.leadingWidth,
        leading: BarBackButton(
          buttonKey: const Key('quizBack'),
          label: l10n.back,
          tooltip: l10n.backToMainMenu,
          onPressed: widget.onExit,
        ),
        // The across seat's portrait and score live in the bar, centred over
        // the table: the table is only the left part of the screen, so the
        // bar is told it has that much width to centre in.
        title: Builder(builder: (context) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(
                size: Size(mq.size.width - _panelWidth, mq.size.height)),
            child: TableBarTitle(
              game: _c,
              height: barHeight,
              ownPortrait: false,
              titleStart: BarBackButton.leadingWidth + 8,
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(kTileSensorAsset,
                      height: 30,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.school, size: 30)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(l10n.quizTitle,
                        key: const Key('quizTitle'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        }),
        actions: const [LanguageButton(), SizedBox(width: 8)],
      ),
      body: SafeArea(
        child: Row(
          children: [
            Expanded(
                child:
                    TableView(game: _c, acrossInBar: true, ownPortrait: false)),
            SizedBox(width: _panelWidth, child: _panel(l10n)),
          ],
        ),
      ),
    );
  }
}
