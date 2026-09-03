import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../logic/efficiency_engine.dart';
import '../logic/round.dart';
import '../logic/tile.dart';
import 'tile_face.dart';

/// The human seat's concealed hand plus turn actions. The freshly drawn tile is
/// shown slightly separated on the right, as in the desktop 2D renderer.
class HandView extends StatelessWidget {
  const HandView({super.key, required this.game});
  final GameController game;

  @override
  Widget build(BuildContext context) {
    final round = game.round;
    final seat = round.seats[kHumanSeat];
    final canPlay = game.isHumanTurn;
    final drawn = seat.drawn;
    final report = game.report;

    final resting = [...seat.hand]..remove(drawn);
    final ordered = sortByType(resting);

    DiscardLine? lineFor(TileType t) {
      for (final l in report.lines) {
        if (l.discard == t) return l;
      }
      return null;
    }

    Widget tileButton(Tile tile, {bool separated = false}) {
      final line = canPlay ? lineFor(tile.type) : null;
      return Padding(
        padding: EdgeInsets.only(left: separated ? 14 : 2, right: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (line != null)
              Text(
                line.shanten == -1 ? 'win' : 'u${line.ukeire}',
                style: TextStyle(
                  fontSize: 9,
                  color: line.recommended
                      ? const Color(0xff81c784)
                      : line.bestUkeire
                          ? const Color(0xffffdf76)
                          : Colors.white54,
                  fontWeight: line.bestUkeire ? FontWeight.bold : FontWeight.normal,
                ),
              )
            else
              const SizedBox(height: 12),
            InkWell(
              onTap: canPlay ? () => _discard(context, tile) : null,
              borderRadius: BorderRadius.circular(6),
              child: TileFace(
                tile: tile,
                size: TileSize.large,
                highlight: canPlay && (line?.recommended ?? false),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      color: const Color(0xff052726),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _actionBar(context),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final t in ordered) tileButton(t),
                if (drawn != null) tileButton(drawn, separated: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _discard(BuildContext context, Tile tile) {
    final canRiichi = game.humanCanRiichi;
    final line = game.report.lines.where((l) => l.discard == tile.type).toList();
    final keepsTenpai = line.isNotEmpty && line.first.shanten == 0;
    if (canRiichi && keepsTenpai) {
      showModalBottomSheet<void>(
        context: context,
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.campaign),
                title: Text('Declare Riichi and discard ${tile.type.displayName}'),
                onTap: () {
                  Navigator.pop(context);
                  game.humanDiscard(tile, declareRiichi: true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_forward),
                title: Text('Just discard ${tile.type.displayName}'),
                onTap: () {
                  Navigator.pop(context);
                  game.humanDiscard(tile);
                },
              ),
            ],
          ),
        ),
      );
    } else {
      game.humanDiscard(tile);
    }
  }

  Widget _actionBar(BuildContext context) {
    final round = game.round;
    final buttons = <Widget>[];

    if (game.awaitingHumanCall) {
      final opt = game.humanCallOption!;
      if (opt.types.contains(CallType.ron)) {
        buttons.add(_btn('RON', const Color(0xffd84315),
            () => game.answerCall(CallType.ron)));
      }
      if (opt.types.contains(CallType.pon)) {
        buttons.add(_btn('PON', const Color(0xff00695c),
            () => game.answerCall(CallType.pon)));
      }
      if (opt.types.contains(CallType.kan)) {
        buttons.add(_btn('KAN', const Color(0xff4527a0),
            () => game.answerCall(CallType.kan)));
      }
      buttons.add(_btn('PASS', const Color(0xff37474f),
          () => game.answerCall(CallType.none)));
    } else if (game.isHumanTurn) {
      if (game.humanCanTsumo) {
        buttons.add(_btn('TSUMO', const Color(0xff2e7d32), game.humanTsumo));
      }
      for (final t in game.humanClosedKanTypes) {
        buttons.add(_btn('KAN ${t.code}', const Color(0xff4527a0),
            () => game.humanClosedKan(t)));
      }
      if (game.report.recommendRiichi) {
        buttons.add(const Chip(
          label: Text('Riichi available', style: TextStyle(fontSize: 11)),
          visualDensity: VisualDensity.compact,
        ));
      }
    } else if (!round.finished) {
      buttons.add(Text(
        '${round.seats[round.turn].wind.label} is thinking…',
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ));
    }

    return Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: buttons);
  }

  Widget _btn(String label, Color color, VoidCallback onTap) => ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        ),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      );
}
