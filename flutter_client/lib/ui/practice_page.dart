/// Guided practice hands: short questions with one right answer, each
/// explained once answered. Reached from the welcome screen; the questions
/// and their answers live in `logic/practice_drills.dart`.
library;

import 'package:flutter/material.dart';
import 'package:mahjong_core/round.dart' show CallType;
import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/tile.dart';

import '../l10n/l10n.dart';
import '../l10n/mahjong_terms.dart';
import '../logic/practice_drills.dart';
import 'bar_back_button.dart';
import 'e2e_id.dart';
import 'screen_scaffold.dart';
import 'tile_face.dart';
import 'theme.dart';

class PracticePage extends StatefulWidget {
  const PracticePage({super.key, required this.ruleset, required this.onExit});

  final Ruleset ruleset;
  final VoidCallback onExit;

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  late final List<PracticeDrill> _drills = practiceDrillsFor(widget.ruleset);
  int _index = 0;
  int _score = 0;
  bool _finished = false;

  /// What was answered on this question, once it has been: the tile for a
  /// winning-tile or discard drill, the choice for a claim drill.
  Object? _answer;

  PracticeDrill get _drill => _drills[_index];
  bool get _answered => _answer != null;

  bool _isCorrect(Object answer) => switch (_drill.kind) {
        DrillKind.winningTile => _drill.isWinningTile(answer as TileType),
        DrillKind.discard => _drill.discardLeavesReady(answer as TileType),
        DrillKind.claim => answer == _drill.correctClaim,
      };

  void _answerWith(Object answer) {
    if (_answered) return;
    setState(() {
      _answer = answer;
      if (_isCorrect(answer)) _score++;
    });
  }

  void _next() {
    setState(() {
      _answer = null;
      if (_index == _drills.length - 1) {
        _finished = true;
      } else {
        _index++;
      }
    });
  }

  void _again() => setState(() {
        _index = 0;
        _score = 0;
        _answer = null;
        _finished = false;
      });

  String _why(AppLocalizations l10n) {
    final call = l10n.callLabel(
        _drill.id == 'c2' ? CallType.chi : CallType.pon, widget.ruleset);
    return switch (_drill.id) {
      'w1' => l10n.practiceWhyW1,
      'w2' => l10n.practiceWhyW2,
      'w3' => l10n.practiceWhyW3,
      'd1' => l10n.practiceWhyD1,
      'd2' => l10n.practiceWhyD2,
      'd3' => l10n.practiceWhyD3,
      'c1' => l10n.practiceWhyC1(call),
      'c2' => l10n.practiceWhyC2(call),
      'c3' => l10n.practiceWhyC3,
      _ => l10n.practiceWhyC4,
    };
  }

  /// A tile in the colour its answer gives it: green once it is the right
  /// answer, red when it was the wrong one picked.
  Color? _mark(Object tileOrChoice, {required bool isRight}) {
    if (!_answered) return null;
    if (isRight) return AppColors.right;
    return _answer == tileOrChoice ? AppColors.wrong : null;
  }

  Widget _handRow(List<TileType> hand, {bool tappable = false}) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, t) in hand.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: tappable
                  ? e2eId(
                      'practiceTile_$i',
                      InkWell(
                        key: Key('practiceTile_$i'),
                        borderRadius: BorderRadius.circular(6),
                        onTap: _answered ? null : () => _answerWith(t),
                        child: TileFace(
                          type: t,
                          size: TileSize.large,
                          highlightColor:
                              _mark(t, isRight: _drill.discardLeavesReady(t)),
                        ),
                      ),
                    )
                  : TileFace(type: t, size: TileSize.large),
            ),
        ],
      ),
    );
  }

  Widget _optionTiles() => Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        children: [
          for (final t in _drill.optionTiles)
            e2eId(
              'practiceOption_${t.code}',
              InkWell(
                key: Key('practiceOption_${t.code}'),
                borderRadius: BorderRadius.circular(6),
                onTap: _answered ? null : () => _answerWith(t),
                child: TileFace(
                  type: t,
                  size: TileSize.large,
                  highlightColor: _mark(t, isRight: _drill.isWinningTile(t)),
                ),
              ),
            ),
        ],
      );

  String _seatName(AppLocalizations l10n) => switch (_drill.from!) {
        DiscardFrom.left => l10n.seatLeft,
        DiscardFrom.across => l10n.seatAcross,
        DiscardFrom.right => l10n.seatRight,
      };

  Widget _claimChoices(AppLocalizations l10n) {
    final labels = {
      if (!widget.ruleset.isSichuan)
        ClaimChoice.chow: l10n.callLabel(CallType.chi, widget.ruleset),
      ClaimChoice.pung: l10n.callLabel(CallType.pon, widget.ruleset),
      ClaimChoice.pass: l10n.practiceOptionPass,
    };
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      children: [
        for (final MapEntry(key: choice, value: label) in labels.entries)
          e2eId(
            'practiceClaim_${choice.name}',
            OutlinedButton(
              key: Key('practiceClaim_${choice.name}'),
              onPressed: _answered ? null : () => _answerWith(choice),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: switch (
                    _mark(choice, isRight: choice == _drill.correctClaim)) {
                  final c? => c.withValues(alpha: 0.35),
                  null => null,
                },
                side: BorderSide(
                    color:
                        _mark(choice, isRight: choice == _drill.correctClaim) ??
                            Colors.white38),
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              ),
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
      ],
    );
  }

  Widget _feedback(AppLocalizations l10n) {
    final ok = _isCorrect(_answer!);
    final color = ok ? AppColors.right : const Color(0xffffa000);
    return Container(
      key: const Key('practiceFeedback'),
      width: 640,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          e2eId(
            'practiceVerdict',
            Text(ok ? l10n.practiceCorrect : l10n.practiceWrong,
                key: const Key('practiceVerdict'),
                style: TextStyle(
                    color:
                        ok ? const Color(0xff9ccc65) : const Color(0xffffca28),
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 4),
          Text(_why(l10n),
              key: const Key('practiceWhy'),
              style: const TextStyle(
                  color: Colors.white, fontSize: 16, height: 1.45)),
          const SizedBox(height: 6),
          // What the p and s in the explanation's tile names stand for.
          Text(l10n.practiceLegend,
              key: const Key('practiceLegend'),
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _question(AppLocalizations l10n) {
    final d = _drill;
    final ask = switch (d.kind) {
      DrillKind.winningTile => l10n.practiceAskWin,
      DrillKind.discard => l10n.practiceAskDiscard,
      DrillKind.claim => l10n.practiceAskClaim,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 760,
          child: Text(ask,
              key: const Key('practiceQuestion'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontSize: 22, height: 1.4)),
        ),
        const SizedBox(height: 18),
        Text(l10n.practiceYourHand,
            style: const TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 6),
        _handRow(d.hand, tappable: d.kind == DrillKind.discard),
        const SizedBox(height: 22),
        switch (d.kind) {
          DrillKind.winningTile => Column(
              children: [
                Text(l10n.practiceChoices,
                    key: const Key('practiceChoices'),
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 6),
                _optionTiles(),
              ],
            ),
          DrillKind.discard => const SizedBox.shrink(),
          DrillKind.claim => Column(
              children: [
                Text(l10n.practiceDiscardedBy(_seatName(l10n)),
                    key: const Key('practiceDiscardedBy'),
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 15)),
                const SizedBox(height: 8),
                TileFace(type: d.claimedTile, size: TileSize.large),
                const SizedBox(height: 18),
                _claimChoices(l10n),
              ],
            ),
        },
        if (_answered) ...[
          const SizedBox(height: 22),
          _feedback(l10n),
          const SizedBox(height: 14),
          e2eId(
            'practiceNext',
            ElevatedButton(
              key: const Key('practiceNext'),
              onPressed: _next,
              style: AppButtons.primary(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              ),
              child: Text(
                  _index == _drills.length - 1
                      ? l10n.practiceSeeResults
                      : l10n.practiceNext,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _results(AppLocalizations l10n) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.practiceResult(_score, _drills.length),
              key: const Key('practiceResult'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.goldText,
                  fontSize: 34,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 26),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                key: const Key('practiceAgain'),
                onPressed: _again,
                style: AppButtons.secondary(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                ),
                child: Text(l10n.practiceAgain,
                    style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                key: const Key('practiceDone'),
                onPressed: widget.onExit,
                style: AppButtons.primary(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                ),
                child: Text(l10n.back,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ScreenScaffold(
      backKey: const Key('practiceBack'),
      onBack: widget.onExit,
      // The results screen has its own Back; mid-drill the way out is also
      // here, under the thumb rather than in the far corner.
      footer: _finished
          ? null
          : BackFooter(
              buttonKey: const Key('practiceBackBottom'),
              label: l10n.backToMenu,
              tooltip: l10n.backToMainMenu,
              onPressed: widget.onExit,
            ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.practiceTitle,
              style: const TextStyle(
                  color: Colors.white54, fontSize: 18, letterSpacing: 1.2)),
          if (!_finished) ...[
            const SizedBox(height: 4),
            Text(l10n.practiceProgress(_index + 1, _drills.length),
                key: const Key('practiceProgress'),
                style: const TextStyle(color: Colors.white38, fontSize: 14)),
          ],
          const SizedBox(height: 22),
          _finished ? _results(l10n) : _question(l10n),
        ],
      ),
    );
  }
}
