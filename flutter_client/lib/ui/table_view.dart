import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../logic/meld.dart';
import '../logic/round.dart';
import 'tile_face.dart';

/// The flat 2D table: three concealed opponents around a central discard area,
/// a dead-wall strip with revealed dora, seat placards, riichi markers and the
/// wall counter. Mirrors the arrangement of the Vala `GameRenderView2D`.
class TableView extends StatelessWidget {
  const TableView({super.key, required this.game});
  final GameController game;

  @override
  Widget build(BuildContext context) {
    final round = game.round;
    // Seat mapping from the human's perspective: 0 self, 1 right, 2 across, 3 left.
    return Container(
      color: const Color(0xff063a3a),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          _opponentRow(round, 2),
          const SizedBox(height: 4),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sideOpponent(round, 3, isLeft: true),
                Expanded(child: _center(context, round)),
                _sideOpponent(round, 1, isLeft: false),
              ],
            ),
          ),
          const SizedBox(height: 4),
          _selfPondAndInfo(round),
        ],
      ),
    );
  }

  Widget _center(BuildContext context, Round round) {
    return Column(
      children: [
        _statusLine(round),
        const SizedBox(height: 4),
        _deadWall(round),
        const SizedBox(height: 8),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final seat in const [2, 1, 3, 0])
                    _pond(round, seat),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusLine(Round round) {
    return Text(
      '${round.roundWind.label} ${game.roundNumber + 1}   ·   '
      'Honba ${game.honba}   ·   Riichi ${round.riichiSticks}   ·   '
      'Wall ${round.wall.remaining}',
      style: const TextStyle(
          color: Color(0xffe9d58f), fontSize: 12, fontWeight: FontWeight.w600),
    );
  }

  Widget _deadWall(Round round) {
    final tiles = round.wall.deadWallDisplay();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('DORA ',
            style: TextStyle(color: Colors.white54, fontSize: 10)),
        for (final t in tiles.take(10))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: TileFace(tile: t, faceDown: t == null, size: TileSize.small),
          ),
      ],
    );
  }

  Widget _pond(Round round, int seat) {
    final s = round.seats[seat];
    final quarter = switch (seat) {
      1 => 1,
      2 => 2,
      3 => 3,
      _ => 0,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 58,
            child: _placard(round, seat, compact: true),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Wrap(
              spacing: 1,
              runSpacing: 1,
              children: [
                for (var i = 0; i < s.pond.length; i++)
                  TileFace(
                    tile: s.pond[i],
                    size: TileSize.small,
                    rotationQuarterTurns:
                        i == s.riichiPondIndex ? (quarter + 1) : quarter,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _opponentRow(Round round, int seat) {
    final s = round.seats[seat];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _placard(round, seat),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < s.hand.length; i++)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 0.5),
                  child: TileFace(faceDown: true, size: TileSize.small),
                ),
            ],
          ),
        ),
        if (s.melds.isNotEmpty)
          FittedBox(fit: BoxFit.scaleDown, child: _melds(s)),
      ],
    );
  }

  Widget _sideOpponent(Round round, int seat, {required bool isLeft}) {
    final s = round.seats[seat];
    return SizedBox(
      width: 68,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          RotatedBox(
            quarterTurns: isLeft ? 1 : 3,
            child: _placard(round, seat),
          ),
          const SizedBox(height: 4),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < s.hand.length.clamp(0, 13); i++)
                    const Padding(
                      padding: EdgeInsets.all(0.5),
                      child: TileFace(faceDown: true, size: TileSize.tiny),
                    ),
                ],
              ),
            ),
          ),
          if (s.melds.isNotEmpty)
            RotatedBox(quarterTurns: isLeft ? 1 : 3, child: _melds(s)),
        ],
      ),
    );
  }

  Widget _selfPondAndInfo(Round round) {
    final s = round.seats[0];
    return Column(
      children: [
        if (s.melds.isNotEmpty) _melds(s),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 1,
          runSpacing: 1,
          children: [
            for (var i = 0; i < s.pond.length; i++)
              TileFace(
                tile: s.pond[i],
                size: TileSize.small,
                rotationQuarterTurns: i == s.riichiPondIndex ? 1 : 0,
              ),
          ],
        ),
      ],
    );
  }

  Widget _melds(SeatState s) {
    return Wrap(
      spacing: 4,
      children: [
        for (final m in s.melds)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final t in m.types)
                TileFace(
                  type: t,
                  faceDown: m.kind == MeldKind.kan && m.concealed,
                  size: TileSize.tiny,
                ),
            ],
          ),
      ],
    );
  }

  Widget _placard(Round round, int seat, {bool compact = false}) {
    final s = round.seats[seat];
    final active =
        round.turn == seat && !round.finished && round.phase != RoundPhase.callOffer;
    final label =
        '${s.wind.kanji}${seat == 0 ? ' You' : ''}  ${s.points}${s.riichi ? '  ◉' : ''}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: active ? const Color(0xffcaa24e) : const Color(0xff0c4747),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: active ? Colors.black : Colors.white,
          fontSize: compact ? 9 : 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
