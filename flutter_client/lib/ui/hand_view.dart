import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../game/game_controller.dart' show kHumanSeat;
import '../game/guide_host.dart';
import 'package:mahjong_core/round.dart';
import 'package:mahjong_core/tile.dart';
import 'meld_row.dart';
import 'table_view.dart' show CountdownBadge;
import 'tile_face.dart';

/// The human seat's concealed hand plus turn actions. An auto-sort toggle keeps
/// the hand in tile order; the freshly drawn tile always carries a yellow
/// highlight (guide on or off) so it stays identifiable.
class HandView extends StatefulWidget {
  const HandView({
    super.key,
    required this.game,
    this.onToggleGuide,
    this.showGuide = true,
  });
  final TableGameHost game;

  /// Null hides the TileSense button entirely — multiplayer has no guide, so
  /// nobody gets an assist the other seats lack. Offline always passes one.
  final VoidCallback? onToggleGuide;

  /// When false (or [onToggleGuide] is null) the guide is off: no green
  /// (best discard) tile highlight. The drawn tile's yellow highlight is
  /// unrelated to the guide and always shows.
  final bool showGuide;

  /// Height of the bar's bottom band: the tile row (now set by a `large` face
  /// at [_HandViewState._handScale], which is taller than the 104px TileSense
  /// button beside it) plus the bar's 10px bottom padding. The efficiency
  /// overlay stops above this band so it never covers a tile.
  static const double tileRowBandHeight = 116;

  @override
  State<HandView> createState() => _HandViewState();
}

class _HandViewState extends State<HandView> {
  // On by default: tiles stay in tile order. Unchecking freezes whatever
  // order is on screen at that moment rather than reverting to draw order.
  bool _autoSort = true;

  /// Tile ids in draw order, kept stable so "auto-sort off" leaves tiles put.
  final List<int> _order = [];

  /// The tile currently under the mouse pointer, so it can pick up a slight
  /// hover shading — a no-op on touch devices, which never hover.
  int? _hoveredTileId;

  TableGameHost get game => widget.game;

  static const _yellow = Color(0xffffd54f);
  static const _green = Color(0xff43a047);

  /// How much bigger the human hand (and its open melds) render than the
  /// authored `TileSize.large` / `TileSize.normal` steps. 1.65 = the base
  /// 1.5 scale bumped 10% bigger.
  static const double _handScale = 1.65;

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
      // Adopt what is on screen and drop out of auto-sort, or the next
      // rebuild would sort the move straight back out again.
      if (_autoSort) _freezeOrder(shown);
      final from = _order.indexOf(id);
      final to = _order.indexOf(targetId);
      if (from < 0 || to < 0) return;
      _order.removeAt(from);
      _order.insert(to.clamp(0, _order.length), id);
    });
  }

  /// Snapshots [shown] (whatever order is currently on screen) into [_order]
  /// and turns auto-sort off, so leaving auto-sort never reverts to draw
  /// order.
  void _freezeOrder(List<Tile> shown) {
    _order
      ..clear()
      ..addAll(shown.map((t) => t.id));
    _autoSort = false;
  }

  /// Auto-sort checkbox handler. Turning it off freezes the tile-order view
  /// that's currently on screen; turning it back on just resumes sorting.
  void _toggleAutoSort() {
    setState(() {
      if (_autoSort) {
        _freezeOrder(sortByType(game.round.seats[kHumanSeat].hand));
      } else {
        _autoSort = true;
      }
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
    // After riichi the hand is frozen — only the drawn tile can be discarded.
    final riichiLocked = seat.riichi && drawn != null;

    // Green = the guide's recommended discard — the very row it marks
    // recommended in the panel, so the hand and the panel never disagree.
    // Yellow = the freshly drawn tile, shown whether the guide is on or off.
    // A drawn tile that is also the recommended one gets both: a green tint
    // with a yellow border.
    final showGuide = widget.showGuide && widget.onToggleGuide != null;
    final topTypes = <TileType>{
      if (canPlay && showGuide)
        for (final l in game.report.lines)
          if (l.recommended) l.discard,
    };

    Widget tileButton(Tile tile, {bool separated = false}) {
      final isDrawn = drawn != null && tile.id == drawn.id;
      final tappable = canPlay &&
          (!riichiLocked || isDrawn) &&
          !round.canFlowerWin(kHumanSeat);
      final isTop = tappable && topTypes.contains(tile.type);
      final Color? hc = isTop ? _green : (isDrawn ? _yellow : null);
      final Color? border = (isDrawn && isTop) ? _yellow : null;
      return Padding(
        padding: EdgeInsets.only(left: separated ? 16 : 2, right: 2),
        child: InkWell(
          onTap: tappable ? () => _discard(context, tile) : null,
          onHover: tappable
              ? (h) => setState(() => _hoveredTileId = h ? tile.id : null)
              : null,
          borderRadius: BorderRadius.circular(6),
          child: TileFace(
            tile: tile,
            size: TileSize.large,
            scale: _handScale,
            highlightColor: hc,
            borderColorOverride: border,
            dimmed: riichiLocked && !isDrawn,
            hovered: _hoveredTileId == tile.id,
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
            childWhenDragging: _DragGrabFlash(child: child),
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

    // The resting tiles are in tile order (auto-sort on) or in the order you
    // have put them in (off); either way the drawn tile is held apart on the
    // right, slightly spaced from the rest, until you keep or discard it — so
    // sorting never files it away among the others. Tiles can be dragged into
    // a different order; doing it while sorted just turns auto-sort off.
    final resting = [
      for (final t in seat.hand)
        if (drawn == null || t.id != drawn.id) t,
    ];
    final shown = _autoSort ? sortByType(resting) : _drawOrdered(resting);
    final List<Widget> tiles = [
      for (final t in shown) draggableTile(t, shown),
      // It has no slot in the order yet and is not a drop target.
      if (drawn != null) tileButton(drawn, separated: true),
    ];

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
              if (widget.onToggleGuide != null) ...[
                _guideButton(),
                const SizedBox(width: 10),
              ],
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
                          _sortToggle(),
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
              const SizedBox(width: 6),
              _soundButton(),
            ],
          ),
        ],
      ),
    );
  }

  /// Sound toggle, the rightmost thing in the bar — bottom-right corner of the
  /// whole app. On by default (see [GameController.setSoundOn]); toggling it is
  /// also a fresh gesture a player can reach for to resync audio mid-game if
  /// the browser suspended Web Audio and dropped bot/Auto-Play sfx.
  Widget _soundButton() {
    final on = game.soundOn;
    return IconButton(
      key: const Key('soundToggle'),
      tooltip: on ? 'Sound on — tap to mute' : 'Sound off — tap to unmute',
      iconSize: 28,
      icon: Icon(on ? Icons.volume_up : Icons.volume_off),
      color: on ? const Color(0xffe9d58f) : Colors.white38,
      onPressed: () => game.setSoundOn(!on),
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

  Widget _sortToggle() {
    return Tooltip(
      message: _autoSort
          ? 'Auto-sort: on — tiles kept in tile order.\n'
              'Uncheck to freeze this order, or drag a tile to start your own.'
          : 'Auto-sort: off — your own order.\n'
              'Long-press a tile and drag it to move it. Check to resume auto-sort.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color:
              _autoSort ? const Color(0xff00695c) : const Color(0xff294342),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 30,
              height: 30,
              child: Checkbox(
                key: const Key('sortHand'),
                value: _autoSort,
                onChanged: (_) => _toggleAutoSort(),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                checkColor: const Color(0xff00695c),
                activeColor: Colors.white,
                side: const BorderSide(color: Colors.white60, width: 1.5),
              ),
            ),
            const SizedBox(height: 2),
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: _toggleAutoSort,
              child: Text(
                'Auto-sort',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                  color: _autoSort ? Colors.white : Colors.white60,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _discard(BuildContext context, Tile tile) {
    final canRiichi = game.humanCanRiichi;
    final line =
        game.report.lines.where((l) => l.discard == tile.type).toList();
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
                title:
                    Text('Declare Riichi and discard ${tile.type.displayName}'),
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
    final ruleset = game.round.ruleset;

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

    if (game.round.canFlowerWin(kHumanSeat)) {
      // Hong Kong: a seventh or eighth flower may be claimed as a win.
      buttons.add(_btn('FLOWER WIN', const Color(0xff2e7d32), game.humanTsumo));
      buttons.add(_btn('CONTINUE DRAWING', const Color(0xff37474f),
          game.humanPassFlowerWin));
    } else if (game.awaitingHumanCall) {
      final opt = game.humanCallOption!;
      if (opt.types.contains(CallType.ron)) {
        buttons.add(_btn(ruleset.ronLabel.toUpperCase(),
            const Color(0xffd84315), () => game.answerCall(CallType.ron)));
      }
      if (opt.types.contains(CallType.pon)) {
        buttons.add(_btn(ruleset.ponLabel.toUpperCase(),
            const Color(0xff00695c), () => game.answerCall(CallType.pon)));
      }
      if (opt.types.contains(CallType.kan)) {
        buttons.add(_btn(ruleset.kanLabel.toUpperCase(),
            const Color(0xff4527a0), () => game.answerCall(CallType.kan)));
      }
      if (opt.types.contains(CallType.chi)) {
        buttons.add(_btn(ruleset.chiLabel.toUpperCase(),
            const Color(0xff00838f), () => game.answerCall(CallType.chi)));
      }
      buttons.add(_btn('PASS', const Color(0xff37474f),
          () => game.answerCall(CallType.none)));
      // Time left to answer; the call is passed when it reaches zero.
      final deadline = game.callDeadlineMs;
      if (deadline != null) {
        buttons.add(CountdownBadge(
          key: const Key('callCountdown'),
          deadlineMs: deadline,
        ));
      }
    } else if (game.isHumanTurn) {
      if (game.humanCanTsumo) {
        buttons.add(_btn(ruleset.tsumoLabel.toUpperCase(),
            const Color(0xff2e7d32), game.humanTsumo));
      }
      for (final t in game.humanClosedKanTypes) {
        buttons.add(_btn('${ruleset.kanLabel.toUpperCase()} ${t.code}',
            const Color(0xff4527a0), () => game.humanClosedKan(t)));
      }
      for (final t in game.humanAddedKanTypes) {
        buttons.add(_btn('${ruleset.kanLabel.toUpperCase()} ${t.code}',
            const Color(0xff4527a0), () => game.humanAddKan(t)));
      }
      if (game.report.recommendRiichi) {
        buttons.add(const Chip(
          label: Text('Riichi available', style: TextStyle(fontSize: 11)),
          visualDensity: VisualDensity.compact,
        ));
      }
    }

    // Fixed height so the tile bar below never shifts as buttons come and go.
    // Centred (rather than left-aligned) so it lines up under the seat badge
    // above it instead of hugging the left edge of the bar.
    return SizedBox(
      height: 48,
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
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          minimumSize: const Size(72, 44),
        ),
        onPressed: onTap,
        child: Text(label,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      );
}

/// Shown in a tile's slot the instant a long-press grabs it: a bright flash
/// over the usual dimmed "being dragged" look, fading out on its own. Built
/// fresh exactly when dragging starts (this replaces [child] only then) so
/// the one-shot [TweenAnimationBuilder] animation plays right on grab, with
/// no extra timers or state to track.
class _DragGrabFlash extends StatelessWidget {
  const _DragGrabFlash({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Opacity(opacity: 0.25, child: child),
        Positioned.fill(
          child: IgnorePointer(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 1.0, end: 0.0),
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOut,
              builder: (context, v, _) => v <= 0
                  ? const SizedBox.shrink()
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        color: _HandViewState._yellow.withValues(alpha: 0.55 * v),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
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
