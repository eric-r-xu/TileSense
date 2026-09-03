import 'package:flutter/material.dart';

import '../game/game_controller.dart';
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
  int _page = 0;

  GameController get game => widget.game;

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
              const SizedBox(height: 12),
              _transfers(round, r),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xffcaa24e),
                  foregroundColor: Colors.black,
                ),
                onPressed: () {
                  if (hasMore) {
                    setState(() => _page = page + 1);
                  } else if (gameOver) {
                    game.newGame();
                  } else {
                    game.continueFromRoundEnd();
                  }
                },
                child: Text(label),
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
          '${w.wind.kanji} ${seat == kHumanSeat ? 'You' : 'CPU $seat'}',
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
                  '${round.seats[i].wind.kanji} ${i == kHumanSeat ? 'You' : 'CPU $i'}',
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
        (i == kHumanSeat ? 'You' : 'CPU $i', game.tablePoints[i])
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    return entries.map((e) => '${e.$1}: ${e.$2}').join('    ');
  }
}
