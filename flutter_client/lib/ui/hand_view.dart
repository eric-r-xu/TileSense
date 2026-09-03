import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../logic/efficiency_engine.dart';
import '../logic/round.dart';
import '../logic/tile.dart';
import 'tile_face.dart';

/// The human seat's concealed hand plus turn actions. The freshly drawn tile is
/// always shown slightly separated on the far right; an auto-sort toggle keeps
/// the resting 13 in tile order (or leaves them in draw order).
class HandView extends StatefulWidget {
  const HandView({super.key, required this.game});
  final GameController game;

  @override
  State<HandView> createState() => _HandViewState();
}

class _HandViewState extends State<HandView> {
  bool _autoSort = true;

  /// Tile ids of the resting hand in draw order, kept stable across rebuilds so
  /// "auto-sort off" leaves tiles where they were.
  final List<int> _drawOrder = [];

  GameController get game => widget.game;

  List<Tile> _orderedResting(List<Tile> resting) {
    if (_autoSort) return sortByType(resting);
    final present = {for (final t in resting) t.id: t};
    _drawOrder.removeWhere((id) => !present.containsKey(id));
    for (final t in resting) {
      if (!_drawOrder.contains(t.id)) _drawOrder.add(t.id);
    }
    return [for (final id in _drawOrder) present[id]!];
  }

  @override
  Widget build(BuildContext context) {
    final round = game.round;
    final seat = round.seats[kHumanSeat];
    final canPlay = game.isHumanTurn;
    final drawn = seat.drawn;
    final report = game.report;

    final resting = [...seat.hand]..remove(drawn);
    final ordered = _orderedResting(resting);

    DiscardLine? lineFor(TileType t) {
      for (final l in report.lines) {
        if (l.discard == t) return l;
      }
      return null;
    }

    // Blue = the autoplay pick; green = any best-EV / safest tie. Mirrors the
    // highlighting in the efficiency guide.
    final topEv = report.lines.isEmpty
        ? 0
        : report.lines
            .map((l) => l.expectedValue.round())
            .reduce((a, b) => a > b ? a : b);
    final topSafety = report.defending
        ? report.lines
            .map((l) => l.safety?.rating ?? -1)
            .fold<int>(-1, (a, b) => a > b ? a : b)
        : -1;
    Color? highlightFor(DiscardLine? line) {
      if (!canPlay || line == null) return null;
      if (line.recommended) return const Color(0xff3d7bff);
      final evTie = topEv > 0 && line.expectedValue.round() == topEv;
      final safeTie =
          topSafety >= 0 && (line.safety?.rating ?? -1) == topSafety;
      return (evTie || safeTie) ? const Color(0xff43a047) : null;
    }

    Widget tileButton(Tile tile, {bool separated = false}) {
      final line = canPlay ? lineFor(tile.type) : null;
      return Padding(
        padding: EdgeInsets.only(left: separated ? 16 : 2, right: 2),
        child: InkWell(
          onTap: canPlay ? () => _discard(context, tile) : null,
          borderRadius: BorderRadius.circular(6),
          child: TileFace(
            tile: tile,
            size: TileSize.large,
            highlightColor: highlightFor(line),
          ),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _sortButton(),
              const SizedBox(width: 6),
              Expanded(
                child: LayoutBuilder(
                  builder: (ctx, c) => SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: c.maxWidth),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final t in ordered) tileButton(t),
                          // The latest draw is always kept at the far right.
                          if (drawn != null) tileButton(drawn, separated: true),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sortButton() {
    return Tooltip(
      message: _autoSort ? 'Auto-sort on' : 'Auto-sort off (draw order)',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _autoSort = !_autoSort),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: _autoSort ? const Color(0xff00695c) : const Color(0xff26403f),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _autoSort ? Icons.sort : Icons.sort_outlined,
            size: 20,
            color: _autoSort ? Colors.white : Colors.white60,
          ),
        ),
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

    return Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: buttons);
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
