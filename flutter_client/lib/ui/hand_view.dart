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
  const HandView({
    super.key,
    required this.game,
    required this.onToggleGuide,
    this.showGuide = true,
  });
  final GameController game;
  final VoidCallback onToggleGuide;

  /// When false the guide is off: no yellow (drawn tile) or green (best discard)
  /// tile highlights.
  final bool showGuide;

  /// Height of the bar's bottom band: the tile row (whose height the TileSense
  /// button beside it sets, at 104px — taller than a `large` face at
  /// [_HandViewState._handScale]) plus the bar's 10px bottom padding. The
  /// efficiency overlay stops above this band so it never covers a tile.
  static const double tileRowBandHeight = 114;

  @override
  State<HandView> createState() => _HandViewState();
}

class _HandViewState extends State<HandView> {
  // Off by default: tiles stay in draw order until the sort button is tapped.
  bool _autoSort = false;

  /// Tile ids in draw order, kept stable so "auto-sort off" leaves tiles put.
  final List<int> _order = [];

  GameController get game => widget.game;

  static const _yellow = Color(0xffffd54f);
  static const _green = Color(0xff43a047);

  /// How much bigger the human hand (and its open melds) render than the
  /// authored `TileSize.large` / `TileSize.normal` steps.
  static const double _handScale = 1.5;

  /// Fixed width for the concealed-tile strip: 13 resting tiles plus the wider
  /// slot the separated drawn tile takes, at [_handScale]. A `large` face is
  /// 46 px wide (→ 46·1.5 ≈ 69) with 4 px of padding, and the drawn tile is
  /// inset a further 14 px. Sizing for the full 14 keeps tiles from shifting on
  /// every draw.
  static const double _handStripWidth =
      13 * (46 * _handScale + 4) + (46 * _handScale + 4 + 14);

  /// Move the tile [id] into the slot [targetId] currently occupies, shifting
  /// the rest along — the ordinary meaning of dropping one thing onto another.
  ///
  /// Indices are read *before* the removal, which is what makes a drag to the
  /// right land after the tile you dropped on and a drag to the left land
  /// before it, without either direction needing a special case.
  void _reorder(int id, int targetId, List<Tile> shown) {
    if (id == targetId) return;
    setState(() {
      if (_autoSort) {
        // Adopt what is on screen and drop out of auto-sort, or the next
        // rebuild would sort the move straight back out again.
        _order
          ..clear()
          ..addAll(shown.map((t) => t.id));
        _autoSort = false;
      }
      final from = _order.indexOf(id);
      final to = _order.indexOf(targetId);
      if (from < 0 || to < 0) return;
      _order.removeAt(from);
      _order.insert(to.clamp(0, _order.length), id);
    });
  }

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

    // Green = the guide's recommended discard — the very row it marks
    // recommended in the panel, so the hand and the panel never disagree.
    // Yellow = the freshly drawn tile. A drawn tile that is also the
    // recommended one gets both: a green tint with a yellow border.
    final showGuide = widget.showGuide;
    final topTypes = <TileType>{
      if (canPlay && showGuide)
        for (final l in game.report.lines)
          if (l.recommended) l.discard,
    };

    Widget tileButton(Tile tile, {bool separated = false}) {
      final isDrawn = drawn != null && tile.id == drawn.id;
      final tappable = canPlay && !game.round.canFlowerWin(kHumanSeat);
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
            scale: _handScale,
            highlightColor: hc,
            borderColorOverride: border,
            dimmed: false,
          ),
        ),
      );
    }

    /// A tile you can pick up and drop somewhere else in the strip.
    ///
    /// Long-press to lift rather than plain drag: the strip sits inside a
    /// horizontal scroll view and the tiles themselves are tap-to-discard, so
    /// a bare horizontal drag is already spoken for twice over. A long press
    /// is unambiguous, and means no gesture here can be started by accident.
    Widget draggableTile(Tile tile, List<Tile> shown,
        {bool separated = false}) {
      final child = tileButton(tile, separated: separated);
      return DragTarget<int>(
        onWillAcceptWithDetails: (details) => details.data != tile.id,
        onAcceptWithDetails: (details) =>
            _reorder(details.data, tile.id, shown),
        builder: (context, candidate, rejected) {
          final marked = candidate.isNotEmpty;
          return LongPressDraggable<int>(
            data: tile.id,
            axis: Axis.horizontal,
            // Feedback rides above the app, outside this subtree's Material,
            // so it brings its own.
            feedback: Material(
              color: Colors.transparent,
              child: Opacity(
                opacity: 0.9,
                child: TileFace(
                  tile: tile,
                  size: TileSize.large,
                  scale: _handScale,
                ),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.25, child: child),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: marked ? const Color(0x3380cbc4) : null,
              ),
              child: child,
            ),
          );
        },
      );
    }

    // Auto-sort on: show all 14 tiles in tile order (drawn marked by its
    // border). Off: resting tiles in the order you have put them in, drawn
    // tile separated on the right. Either way the tiles can be dragged into a
    // different order — doing it while sorted just turns auto-sort off.
    final List<Widget> tiles;
    if (_autoSort) {
      final shown = sortByType(seat.hand);
      tiles = [for (final t in shown) draggableTile(t, shown)];
    } else {
      final resting = [...seat.hand]..remove(drawn);
      final shown = _drawOrdered(resting);
      tiles = [
        for (final t in shown) draggableTile(t, shown),
        // The drawn tile is held apart until you keep it, so it has no slot in
        // the order yet and is not a drop target.
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
              _guideButton(),
              const SizedBox(width: 10),
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
                        MeldRow(m, size: TileSize.normal, scale: _handScale),
                    ],
                  ),
                ),
              // GitHub link then the Flutter credit — centred in this bottom
              // band, never covered by melds.
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'View on GitHub',
                iconSize: 32,
                icon: const FaIcon(FontAwesomeIcons.github, size: 32),
                color: Colors.white70,
                onPressed: () => launchUrl(
                  Uri.parse('https://github.com/eric-r-xu/TileSense'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              const SizedBox(width: 6),
              const _FlutterAttribution(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _guideButton() {
    final action = widget.showGuide ? 'Hide guide' : 'Show guide';
    return Tooltip(
      message: 'TileSense — ${action.toLowerCase()}',
      child: TextButton(
        key: const Key('bottomGuideToggle'),
        onPressed: widget.onToggleGuide,
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xffe9d58f),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: widget.showGuide ? 1.0 : 0.4,
              child: Image.asset(
                'assets/clefairy.png',
                width: 64,
                height: 64,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.school, size: 64),
              ),
            ),
            const SizedBox(height: 4),
            const Text('TileSense',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, height: 1.15)),
            Text(action,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 11, height: 1.2)),
          ],
        ),
      ),
    );
  }

  Widget _sortButton() {
    return Tooltip(
      message: _autoSort
          ? 'Auto-sort: on — tiles kept in tile order.\n'
              'Tap for your own order, or drag a tile to start one.'
          : 'Auto-sort: off — your own order.\n'
              'Long-press a tile and drag it to move it. Tap to auto-sort.',
      child: InkWell(
        key: const Key('sortHand'),
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _autoSort = !_autoSort),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color:
                _autoSort ? const Color(0xff00695c) : const Color(0xff294342),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _autoSort ? Icons.sort : Icons.sort_outlined,
                size: 30,
                color: _autoSort ? Colors.white : Colors.white60,
              ),
              const SizedBox(height: 2),
              Text(
                'Sort Tiles',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                  color: _autoSort ? Colors.white : Colors.white60,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _discard(BuildContext context, Tile tile) => game.humanDiscard(tile);
  Widget _actionBar(BuildContext context) {
    final buttons = <Widget>[];

    if (game.round.canFlowerWin(kHumanSeat)) {
      buttons.add(_btn('FLOWER WIN', const Color(0xff2e7d32), game.humanTsumo));
      buttons.add(_btn('CONTINUE DRAWING', const Color(0xff37474f),
          game.humanPassFlowerWin));
    } else if (game.awaitingHumanCall) {
      final opt = game.humanCallOption!;
      if (opt.types.contains(CallType.ron)) {
        buttons.add(_btn('WIN', const Color(0xffd84315),
            () => game.answerCall(CallType.ron)));
      }
      if (opt.types.contains(CallType.pon)) {
        buttons.add(_btn('PUNG', const Color(0xff00695c),
            () => game.answerCall(CallType.pon)));
      }
      if (opt.types.contains(CallType.kan)) {
        buttons.add(_btn('KONG', const Color(0xff4527a0),
            () => game.answerCall(CallType.kan)));
      }
      if (opt.types.contains(CallType.chi)) {
        buttons.add(_btn('CHOW', const Color(0xff00838f),
            () => game.answerCall(CallType.chi)));
      }
      buttons.add(_btn('PASS', const Color(0xff37474f),
          () => game.answerCall(CallType.none)));
    } else if (game.isHumanTurn) {
      if (game.humanCanTsumo) {
        buttons
            .add(_btn('SELF DRAW', const Color(0xff2e7d32), game.humanTsumo));
      }
      for (final t in game.humanClosedKanTypes) {
        buttons.add(_btn('KONG ${t.code}', const Color(0xff4527a0),
            () => game.humanClosedKan(t)));
      }
      for (final t in game.humanAddedKanTypes) {
        buttons.add(_btn('KONG ${t.code}', const Color(0xff4527a0),
            () => game.humanAddKan(t)));
      }
    }

    // Fixed height so the tile bar below never shifts as buttons come and go.
    // Centred (rather than left-aligned) so it lines up under the seat badge
    // above it instead of hugging the left edge of the bar.
    return SizedBox(
      height: 34,
      width: double.infinity,
      child: Align(
        alignment: Alignment.center,
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

/// "Built with Flutter" credit, bottom-right of the hand bar (so bottom-right
/// of the whole app) — the stock [FlutterLogo] widget rather than a bundled
/// image, tappable through to flutter.dev. The credit is a [Tooltip] popup
/// (hover on desktop, long-press on touch) so it never changes this icon's
/// footprint or nudges its neighbours in the row.
class _FlutterAttribution extends StatelessWidget {
  const _FlutterAttribution();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Built with Flutter',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => launchUrl(
            Uri.parse('https://flutter.dev'),
            mode: LaunchMode.externalApplication,
          ),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: FlutterLogo(size: 20),
          ),
        ),
      ),
    );
  }
}
