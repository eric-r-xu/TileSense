import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../game/game_controller.dart';
import '../logic/round.dart';
import '../logic/tile.dart';
import 'meld_row.dart';
import 'tile_face.dart';

/// The human seat's concealed hand plus turn actions. An auto-sort toggle keeps
/// the hand in tile order; while the guide is on the freshly drawn tile carries
/// a yellow border so it stays identifiable.
class HandView extends StatefulWidget {
  const HandView({super.key, required this.game, this.showGuide = true});
  final GameController game;

  /// When false the guide is off: no yellow (drawn tile) or green (best discard)
  /// tile highlights.
  final bool showGuide;

  @override
  State<HandView> createState() => _HandViewState();
}

class _HandViewState extends State<HandView> {
  bool _autoSort = true;

  /// Tile ids in draw order, kept stable so "auto-sort off" leaves tiles put.
  final List<int> _order = [];

  GameController get game => widget.game;

  static const _yellow = Color(0xffffd54f);
  static const _green = Color(0xff43a047);

  /// Fixed width for the concealed-tile strip: 13 resting tiles at 46 px
  /// (42 face + 2 + 2 padding) plus the 60 px slot the separated drawn tile
  /// takes. Sizing for the full 14 keeps tiles from shifting on every draw.
  static const double _handStripWidth = 13 * 46.0 + 60;

  List<Tile> _drawOrdered(List<Tile> resting) {
    final present = {for (final t in resting) t.id: t};
    _order.removeWhere((id) => !present.containsKey(id));
    for (final t in resting) {
      if (!_order.contains(t.id)) _order.add(t.id);
    }
    return [for (final id in _order) present[id]!];
  }

  @override
  Widget build(BuildContext context) {
    final round = game.round;
    final seat = round.seats[kHumanSeat];
    final canPlay = game.isHumanTurn;
    final drawn = seat.drawn;
    // After riichi the hand is frozen — only the drawn tile can be discarded.
    final riichiLocked = seat.riichi && drawn != null;

    // Green = every discard tied for the best choice (all of them, if >1).
    // Yellow = the freshly drawn tile. A drawn tile that is also a top choice
    // gets both: a green tint with a yellow border.
    final showGuide = widget.showGuide;
    final topTypes = <TileType>{};
    if (canPlay && showGuide) {
      final lines = game.report.lines;
      final low = lines.isEmpty
          ? 99
          : lines.map((l) => l.shanten).reduce((a, b) => a < b ? a : b);
      final cands = lines.where((l) => l.shanten == low).toList();
      if (cands.isNotEmpty) {
        final topEv = cands
            .map((l) => l.expectedValue.round())
            .reduce((a, b) => a > b ? a : b);
        for (final l in cands) {
          if (l.recommended || l.expectedValue.round() == topEv) {
            topTypes.add(l.discard);
          }
        }
      }
    }

    Widget tileButton(Tile tile, {bool separated = false}) {
      final isDrawn = drawn != null && tile.id == drawn.id;
      final tappable = canPlay && (!riichiLocked || isDrawn);
      final isTop = tappable && topTypes.contains(tile.type);
      final Color? hc = !showGuide
          ? null
          : isTop
              ? _green
              : (isDrawn ? _yellow : null);
      final Color? border = (showGuide && isDrawn && isTop) ? _yellow : null;
      return Padding(
        padding: EdgeInsets.only(left: separated ? 16 : 2, right: 2),
        child: InkWell(
          onTap: tappable ? () => _discard(context, tile) : null,
          borderRadius: BorderRadius.circular(6),
          child: TileFace(
            tile: tile,
            size: TileSize.large,
            highlightColor: hc,
            borderColorOverride: border,
            dimmed: riichiLocked && !isDrawn,
          ),
        ),
      );
    }

    // Auto-sort on: show all 14 tiles in tile order (drawn marked by its border).
    // Off: resting tiles in draw order, drawn tile separated on the right.
    final List<Widget> tiles;
    if (_autoSort) {
      tiles = [for (final t in sortByType(seat.hand)) tileButton(t)];
    } else {
      final resting = [...seat.hand]..remove(drawn);
      tiles = [
        for (final t in _drawOrdered(resting)) tileButton(t),
        if (drawn != null) tileButton(drawn, separated: true),
      ];
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
              // The tile strip has a fixed width (always sized for 14 tiles), so
              // the resting tiles never drift as the drawn tile comes and goes;
              // that strip is then centred in the band. Scrolls if it overflows.
              Expanded(
                child: LayoutBuilder(
                  builder: (ctx, c) => SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: c.maxWidth),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _sortButton(),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: _handStripWidth,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: tiles,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Your open melds sit on the right, left of the GitHub link.
              if (seat.melds.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Wrap(
                    spacing: 6,
                    children: [
                      for (final m in seat.melds)
                        MeldRow(m, size: TileSize.normal),
                    ],
                  ),
                ),
              // GitHub link — centred in this bottom band, never covered by melds.
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'View on GitHub',
                iconSize: 44,
                icon: const FaIcon(FontAwesomeIcons.github, size: 44),
                color: Colors.white70,
                onPressed: () => launchUrl(
                  Uri.parse('https://github.com/eric-r-xu/TileSense'),
                  mode: LaunchMode.externalApplication,
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
      message: _autoSort ? 'Auto-sort: on' : 'Auto-sort: off (draw order)',
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => setState(() => _autoSort = !_autoSort),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _autoSort ? const Color(0xff00695c) : const Color(0xff294342),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            _autoSort ? Icons.sort : Icons.sort_outlined,
            size: 15,
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
    final buttons = <Widget>[];

    // Furiten marker: shown whenever the human seat is tenpai but barred from
    // ron. It sits first so it stays visible next to (or instead of) the call
    // buttons — a furiten wait never gets a RON prompt.
    if (game.humanFuriten) {
      buttons.add(const Chip(
        label: Text('FURITEN',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5)),
        backgroundColor: Color(0xffc62828),
        visualDensity: VisualDensity.compact,
      ));
    }

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
    }

    // Fixed height so the tile bar below never shifts as buttons come and go.
    return SizedBox(
      height: 34,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: buttons,
        ),
      ),
    );
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
