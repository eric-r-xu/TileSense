import 'dart:async';

import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../logic/hand_parse.dart';
import '../logic/round.dart';
import '../logic/scoring.dart';
import '../logic/tile.dart';
import 'tile_face.dart';

/// The between-round result panel: outcome, winning hand(s) + yaku + han/fu, and
/// the point transfers. On a multiple ron the winners' hands are paged through
/// with a "Next" button before the final "Continue".
class ScoringView extends StatefulWidget {
  const ScoringView({super.key, required this.game});
  final GameController game;

  @override
  State<ScoringView> createState() => _ScoringViewState();
}

class _ScoringViewState extends State<ScoringView> {
  static const int _autoContinueSeconds = 10;

  int _page = 0;
  bool _autoEnabled = true;
  int _secondsLeft = _autoContinueSeconds;
  Timer? _timer;

  GameController get game => widget.game;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    if (!_autoEnabled || game.phase == GamePhase.gameEnd) return;
    _secondsLeft = _autoContinueSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        _timer?.cancel();
        _advance();
      }
    });
  }

  /// Runs the same step the Continue / Next button performs, then re-arms the
  /// countdown if there are more result pages to page through.
  void _advance() {
    final winners = game.round.result!.winners;
    final page = _page.clamp(0, winners.isEmpty ? 0 : winners.length - 1);
    final hasMore = winners.length > 1 && page < winners.length - 1;
    if (hasMore) {
      setState(() => _page = page + 1);
      _startCountdown();
    } else {
      game.continueFromRoundEnd();
    }
  }

  void _toggleAuto() {
    setState(() => _autoEnabled = !_autoEnabled);
    if (_autoEnabled) {
      _startCountdown();
    } else {
      _timer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final round = game.round;
    final r = round.result!;
    final gameOver = game.phase == GamePhase.gameEnd;
    final winners = r.winners;
    final multi = winners.length > 1;
    final page = _page.clamp(0, winners.isEmpty ? 0 : winners.length - 1);

    HandScore? scoreFor(int idx) {
      if (idx < r.scores.length) return r.scores[idx];
      return r.score;
    }

    final hasMore = multi && page < winners.length - 1;
    final label = gameOver
        ? 'New Game'
        : hasMore
            ? 'Next'
            : 'Continue';

    return Container(
      color: const Color(0xcc021617),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 520),
          decoration: BoxDecoration(
            color: const Color(0xff0b2f2f),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xffcaa24e)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                multi
                    ? '${r.label}  (${page + 1} / ${winners.length})'
                    : r.label,
                style: const TextStyle(
                    color: Color(0xffffdf76),
                    fontSize: 26,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (winners.isNotEmpty &&
                  scoreFor(page) != null &&
                  scoreFor(page)!.valid)
                _handBlock(round, winners[page], scoreFor(page)!,
                    r.winTiles[winners[page]]),
              if (r.kind == RoundEndKind.exhaustiveDraw)
                _tenpaiReveal(round, r),
              const SizedBox(height: 12),
              _transfers(round, r),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xffcaa24e),
                  foregroundColor: Colors.black,
                ),
                onPressed: () {
                  _timer?.cancel();
                  if (hasMore) {
                    setState(() => _page = page + 1);
                    _startCountdown();
                  } else if (gameOver) {
                    game.newGame();
                  } else {
                    game.continueFromRoundEnd();
                  }
                },
                child: Text(label),
              ),
              if (!gameOver)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: TextButton(
                    onPressed: _toggleAuto,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                    ),
                    child: Text(
                      _autoEnabled
                          ? 'Auto Continue in ${_secondsLeft.clamp(0, _autoContinueSeconds)}s  ·  tap to pause'
                          : 'Auto Continue paused  ·  tap to resume',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              if (gameOver)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_standings(game),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _handBlock(Round round, int seat, HandScore score, Tile? winTile) {
    final w = round.seats[seat];
    return Column(
      children: [
        Text(
          '${w.wind.kanji} ${seatDisplayName(seat)}',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 1,
          children: [
            for (final t in sortByType(w.hand))
              TileFace(tile: t, size: TileSize.small),
            if (winTile != null) ...[
              const SizedBox(width: 6),
              TileFace(tile: winTile, size: TileSize.small),
            ],
            for (final m in w.melds) ...[
              const SizedBox(width: 6),
              for (final ty in m.types) TileFace(type: ty, size: TileSize.small),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 2,
          children: [
            for (final y in score.yaku)
              Text('${y.name}  ${y.yakuman > 0 ? 'yakuman' : '${y.han}'}',
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          score.yakuman > 0
              ? '${score.limitName} — ${score.points}'
              : '${score.han} han ${score.fu} fu'
                  '${score.limitName.isNotEmpty ? '  (${score.limitName})' : ''}'
                  ' — ${score.points}',
          style: const TextStyle(
              color: Color(0xffffdf76), fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  /// On an exhaustive draw every tenpai seat opens its hand (as at a real
  /// ryuukyoku), with its waits spelled out beneath.
  Widget _tenpaiReveal(Round round, RoundResult r) {
    final seats = r.tenpaiAtDraw;
    return Column(
      children: [
        Text(
          seats.isEmpty ? 'All players noten' : 'Tenpai hands revealed',
          style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.bold),
        ),
        for (final seat in seats) ...[
          const SizedBox(height: 6),
          _tenpaiHandRow(round, seat),
        ],
      ],
    );
  }

  Widget _tenpaiHandRow(Round round, int seat) {
    final s = round.seats[seat];
    final waits = waitTiles(s.hand, openMelds: s.melds.length);
    return Column(
      children: [
        Text(
          '${s.wind.kanji} ${seatDisplayName(seat)}',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 3),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 1,
          runSpacing: 1,
          children: [
            for (final t in sortByType(s.hand))
              TileFace(tile: t, size: TileSize.small),
            for (final m in s.melds) ...[
              const SizedBox(width: 6),
              for (final ty in m.types) TileFace(type: ty, size: TileSize.small),
            ],
          ],
        ),
        if (waits.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 2,
              runSpacing: 1,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('waits',
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
                const SizedBox(width: 2),
                for (final wt in waits) TileFace(type: wt, size: TileSize.small),
              ],
            ),
          ),
      ],
    );
  }

  Widget _transfers(Round round, RoundResult r) {
    return Column(
      children: [
        for (var i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${round.seats[i].wind.kanji} ${seatDisplayName(i)}',
                  style: const TextStyle(color: Colors.white),
                ),
                Text(
                  '${round.seats[i].points}'
                  '   (${_delta(r.pointDeltas[i] ?? 0)})',
                  style: TextStyle(
                    color: (r.pointDeltas[i] ?? 0) >= 0
                        ? const Color(0xff81c784)
                        : const Color(0xffff8a80),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _delta(int n) => n >= 0 ? '+$n' : '$n';

  String _standings(GameController game) {
    final entries = [
      for (var i = 0; i < 4; i++)
        (seatDisplayName(i), game.tablePoints[i])
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    return entries.map((e) => '${e.$1}: ${e.$2}').join('    ');
  }
}
