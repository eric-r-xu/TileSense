import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../logic/round.dart';
import '../logic/tile.dart';
import 'tile_face.dart';

/// The between-round result panel: outcome, winning hand + yaku + han/fu, and
/// the point transfers. Analogue of `ScoringView` / `ScoringPointsView`.
class ScoringView extends StatelessWidget {
  const ScoringView({super.key, required this.game});
  final GameController game;

  @override
  Widget build(BuildContext context) {
    final r = game.round.result!;
    final gameOver = game.phase == GamePhase.gameEnd;

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
                r.label,
                style: const TextStyle(
                    color: Color(0xffffdf76),
                    fontSize: 26,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (r.score != null && r.score!.valid) _handBlock(game.round, r),
              const SizedBox(height: 12),
              _transfers(game.round, r),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xffcaa24e),
                  foregroundColor: Colors.black,
                ),
                onPressed: gameOver ? game.newGame : game.continueFromRoundEnd,
                child: Text(gameOver ? 'New Game' : 'Continue'),
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

  Widget _handBlock(Round round, RoundResult r) {
    final winner = round.seats[r.winners.first];
    final score = r.score!;
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 1,
          children: [
            for (final t in sortByType(winner.hand))
              TileFace(tile: t, size: TileSize.small),
            for (final m in winner.melds) ...[
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
