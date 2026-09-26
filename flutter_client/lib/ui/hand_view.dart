import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../game/game_controller.dart' show kHumanSeat;
import '../game/guide_host.dart';
import 'package:mahjong_core/round.dart';
import 'package:mahjong_core/tile.dart';
import 'meld_row.dart';
import 'table_view.dart' show CountdownBadge;
import 'tile_face.dart';
import 'tilesensor.dart';

/// How the concealed hand is ordered — the three settings of the Sort chip.
enum HandSort {
  /// Your own order: tiles stay where you put them.
  off,

  /// Resting tiles in tile order; the drawn tile held apart on the right.
  hand,

  /// Every tile in tile order, the drawn tile filed in among the rest.
  handAndDraw,
}

/// The human seat's concealed hand plus turn actions. A three-way Sort chip
/// keeps the hand in tile order, with or without the drawn tile; the freshly
/// drawn tile always carries a yellow highlight (guide on or off) so it stays
/// identifiable wherever it sits.
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
  /// button beside it) plus the bar's 10px bottom padding, plus the headroom
  /// every tile reserves above itself to raise into on a first tap. The
  /// efficiency overlay stops above this band so it never covers a tile.
  static const double tileRowBandHeight = 116 + _HandViewState._liftHeight;

  @override
  State<HandView> createState() => _HandViewState();
}

class _HandViewState extends State<HandView> {
  // Hand by default: resting tiles stay in tile order, the drawn tile apart.
  // Turning sorting off freezes whatever order is on screen at that moment
  // rather than reverting to draw order.
  HandSort _sort = HandSort.hand;

  /// Tile ids in draw order, kept stable so "sort off" leaves tiles put. It
  /// only holds the drawn tile once you have dragged it somewhere in the
  /// strip; otherwise the drawn tile keeps its own slot on the right.
  final List<int> _order = [];

  /// The tile currently under the mouse pointer, so it can pick up a slight
  /// hover shading — a no-op on touch devices, which never hover.
  int? _hoveredTileId;

  /// The tile a first tap raised, staged for discard. A second tap on it — or
  /// [_discard] itself — discards it; a tap on any other tile just moves the
  /// raise there instead. Cleared whenever a new tile is drawn (see [build]),
  /// so it never survives past the turn it was raised on.
  int? _selectedTileId;

  /// [Tile.drawn]'s id as of the last build, so [build] can tell a fresh draw
  /// apart from a rebuild mid-turn and drop a stale raise exactly once, at
  /// the turn boundary.
  int? _lastDrawnId;

  /// The tile strip's row: where each tile's slot is measured from, so a
  /// scroll or a pinch-zoom never reads as the tiles moving.
  final GlobalKey _stripKey = GlobalKey();

  TableGameHost get game => widget.game;

  static const _yellow = Color(0xffffd54f);
  static const _green = Color(0xff43a047);

  /// How far a raised tile lifts off the row, in logical pixels.
  static const double _liftHeight = 12;

  /// How much bigger the human hand (and its open melds) render than the
  /// authored `TileSize.large` / `TileSize.normal` steps. 1.65 = the base
  /// 1.5 scale bumped 10% bigger — sized for riichi and Hong Kong's 13
  /// resting tiles. Taiwanese holds 16, three more, so it scales down
  /// instead, enough that all of them (17 with the drawn tile) still fit the
  /// same band without needing the strip's horizontal scroll to see the
  /// last one.
  double get _handScale =>
      game.round.ruleset.isTaiwanese ? _taiwaneseHandScale : _defaultHandScale;
  static const double _defaultHandScale = 1.65;
  static const double _taiwaneseHandScale = 1.4;

  /// Minimum width for the concealed-tile strip: every resting tile plus the
  /// wider slot the separated drawn tile takes, at [_handScale] — 13 (14 with
  /// the draw) for riichi and Hong Kong, 16 (17 with the draw) for Taiwanese.
  /// A `large` face is 46 px wide (→ 46·1.5 ≈ 69) with 4 px of padding, and
  /// the drawn tile is inset a further 14 px. Sizing for the full hand keeps
  /// tiles from shifting on every draw; the strip's own horizontal scroll (see
  /// `build`) takes over for anything still wider than the available band —
  /// several open melds, say — rather than this ever overflowing it.
  double get _handStripWidth {
    final resting = game.round.ruleset.isTaiwanese ? 16 : 13;
    final slot = 46 * _handScale + 4;
    return resting * slot + (slot + 14);
  }

  /// Move the tile [id] into the slot [targetId] currently occupies, shifting
  /// the rest along — the ordinary meaning of dropping one thing onto another.
  ///
  /// Indices are read *before* the removal, which is what makes a drag to the
  /// right land after the tile you dropped on and a drag to the left land
  /// before it, without either direction needing a special case.
  void _reorder(int id, int targetId, List<Tile> shown) {
    if (id == targetId) return;
    setState(() {
      // Adopt what is on screen and drop out of sorting, or the next
      // rebuild would sort the move straight back out again.
      if (_sort != HandSort.off) _freezeOrder(shown);
      final from = _order.indexOf(id);
      final to = _order.indexOf(targetId);
      if (from < 0 || to < 0) return;
      _order.removeAt(from);
      _order.insert(to.clamp(0, _order.length), id);
    });
  }

  /// Snapshots [shown] (whatever order is currently on screen) into [_order]
  /// and turns sorting off, so leaving a sort never reverts to draw order.
  void _freezeOrder(List<Tile> shown) {
    _order
      ..clear()
      ..addAll(shown.map((t) => t.id));
    _sort = HandSort.off;
  }

  /// Sort chip handler: cycles Off → Hand → Hand+draw → Off. Arriving at Off
  /// freezes the resting tiles in the tile order just on screen, and sends
  /// the drawn tile back to its own slot on the right, as Off always keeps
  /// it until you place it yourself.
  void _cycleSort() {
    setState(() {
      switch (_sort) {
        case HandSort.off:
          _sort = HandSort.hand;
        case HandSort.hand:
          _sort = HandSort.handAndDraw;
        case HandSort.handAndDraw:
          final seat = game.round.seats[kHumanSeat];
          final drawnId = seat.drawn?.id;
          _freezeOrder(sortByType([
            for (final t in seat.hand)
              if (t.id != drawnId) t
          ]));
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

    // A fresh draw means a new turn started, so any raise from the last one
    // is stale — drop it. Mutating the field directly (rather than through
    // setState) is safe here: it only needs to take effect in this build,
    // which is already underway.
    if (drawn?.id != _lastDrawnId) {
      _lastDrawnId = drawn?.id;
      _selectedTileId = null;
    }

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
      final raised = tappable && tile.id == _selectedTileId;
      return Padding(
        // The top inset is reserved on every tile, raised or not, so a raise
        // is just the tile moving up into space that was already there —
        // nothing else in the row has to shift to make room for it.
        padding: EdgeInsets.only(
            top: _liftHeight, left: separated ? 16 : 2, right: 2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, raised ? -_liftHeight : 0, 0),
          child: InkWell(
            onTap: tappable ? () => _tapTile(context, tile) : null,
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

    // Sort Hand: the resting tiles are in tile order and the drawn tile is
    // held apart on the right, slightly spaced from the rest, until you keep
    // or discard it. Sort Hand+draw: it is filed in among them instead.
    // Sort Off: the order you have put them in, the drawn tile apart on the
    // right unless you have dragged it into place. Tiles can be dragged into
    // a different order; doing it while sorted just turns sorting off.
    final drawnInline = drawn != null &&
        (_sort == HandSort.handAndDraw ||
            (_sort == HandSort.off && _order.contains(drawn.id)));
    final inStrip = [
      for (final t in seat.hand)
        if (drawnInline || drawn == null || t.id != drawn.id) t,
    ];
    final shown =
        _sort == HandSort.off ? _drawOrdered(inStrip) : sortByType(inStrip);
    // Each tile keyed by its id, so a tile that moves — the gap a discard
    // leaves closing up, the drawn tile filed into place, a re-sort — keeps
    // its own element and can glide from its old slot to its new one. A fresh
    // draw fades in as it drops into its slot.
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    Widget glide(Tile tile, Widget child) => KeyedSubtree(
          key: ValueKey(tile.id),
          child: _SlideFromPrevious(
            anchor: () =>
                _stripKey.currentContext?.findRenderObject() as RenderBox?,
            enabled: !still,
            child: TweenAnimationBuilder<double>(
              tween: Tween(
                  begin: drawn?.id == tile.id && !still ? 0.0 : 1.0, end: 1.0),
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              builder: (_, t, c) => Opacity(
                opacity: t,
                child: Transform.translate(
                    offset: Offset(0, -14 * (1 - t)), child: c),
              ),
              child: child,
            ),
          ),
        );
    final List<Widget> tiles = [
      for (final t in shown) glide(t, draggableTile(t, shown)),
      // Held apart, it has no slot in the order yet and is not a drop target.
      if (drawn != null && !drawnInline)
        glide(drawn, tileButton(drawn, separated: true)),
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
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _sortToggle(),
                              // Apart, so a thumb on a phone lands on the one
                              // it meant.
                              const SizedBox(height: 10),
                              _autoWinToggle(),
                            ],
                          ),
                          const SizedBox(width: 14),
                          // A *minimum*, not a fixed width: short hands still
                          // hold the no-jitter width this was sized for, but
                          // a hand this can't fit — Taiwanese's 16/17 tiles,
                          // or an ordinary hand with several open melds —
                          // grows the Row past it instead of overflowing;
                          // the SingleChildScrollView above already scrolls
                          // for exactly that case.
                          ConstrainedBox(
                            constraints:
                                BoxConstraints(minWidth: _handStripWidth),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              key: _stripKey,
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
              // The credits, small and muted in the corner: they are links
              // out of the game, not controls of it, so they stay out of a
              // thumb's way. Sound, which is a control, lives with pause and
              // new game in the top bar.
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'View on GitHub',
                iconSize: 22,
                visualDensity: VisualDensity.compact,
                icon: const FaIcon(FontAwesomeIcons.github, size: 22),
                color: Colors.white38,
                onPressed: () => launchUrl(
                  Uri.parse('https://github.com/eric-r-xu/TileSense'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              const _FlutterAttribution(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _guideButton() {
    final action = widget.showGuide ? 'Hide guide' : 'Show guide';
    return TileSensorTooltip(
      footer:
          widget.showGuide ? 'Tap to hide my guide.' : 'Tap to show my guide.',
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
                kTileSensorAsset,
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

  /// The three-way Sort toggle: tap to cycle Off → Hand → Hand+draw.
  Widget _sortToggle() {
    final (value, icon, tooltip) = switch (_sort) {
      HandSort.off => (
          'Off',
          Icons.drag_indicator,
          'Sort: Off — your own order.\n'
              'Long-press a tile and drag it to move it. '
              'Tap for Hand (tile order).'
        ),
      HandSort.hand => (
          'Hand',
          Icons.sort,
          'Sort: Hand — tiles kept in tile order, your drawn tile apart '
              'on the right.\n'
              'Tap for Hand+draw, or drag a tile to start your own order.'
        ),
      HandSort.handAndDraw => (
          'Hand+draw',
          Icons.low_priority,
          'Sort: Hand+draw — your drawn tile is sorted straight into your '
              'hand.\n'
              'Tap to freeze this order (Off), or drag a tile to start your own.'
        ),
    };
    return _handToggle(
      key: const Key('sortHand'),
      caption: 'SORT',
      value: value,
      icon: icon,
      on: _sort != HandSort.off,
      activeColor: const Color(0xff00695c),
      tooltip: tooltip,
      onTap: _cycleSort,
    );
  }

  /// Auto-win: declares ron/tsumo the moment one is legal.
  Widget _autoWinToggle() {
    final on = game.autoWin;
    return _handToggle(
      key: const Key('autoWin'),
      caption: 'AUTO-WIN',
      value: on ? 'On' : 'Off',
      icon: Icons.emoji_events,
      on: on,
      activeColor: const Color(0xff2e7d32),
      tooltip: on
          ? 'Auto-win: on — ron and tsumo are declared for you '
              'as soon as you can win.\nTap to decide yourself.'
          : 'Auto-win: off — press the win button yourself.\n'
              'Tap to declare ron/tsumo automatically.',
      onTap: () => game.setAutoWin(!on),
    );
  }

  /// One of the two toggles stacked left of the hand, in the same
  /// caption-over-value grammar as the top bar's tiles. 120×46 each (wide
  /// enough for "Hand+draw" and "AUTO-WIN" without fading out) with a
  /// 10px gap: the pair still fits inside the tile row's height, so it
  /// covers nothing, while each is big enough to hit on a phone — where the
  /// whole canvas is drawn at about half size. Filled in its colour when on,
  /// an outline when off, so the state reads without the label.
  Widget _handToggle({
    required Key key,
    required String caption,
    required String value,
    required IconData icon,
    required bool on,
    required Color activeColor,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final ink = on ? Colors.white : Colors.white60;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: on ? activeColor : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: on ? activeColor : Colors.white24),
        ),
        child: InkWell(
          key: key,
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: SizedBox(
            width: 120,
            height: 46,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: ink),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(caption,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.fade,
                            style: TextStyle(
                                color: ink.withValues(alpha: 0.7),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6)),
                        const SizedBox(height: 2),
                        Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          softWrap: false,
                          style: TextStyle(
                              color: ink,
                              fontSize: 12,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A tile tap: the first one just raises it (staging it for discard), and
  /// a second tap on that same raised tile discards it. Tapping a different
  /// tile moves the raise there instead, without discarding anything.
  void _tapTile(BuildContext context, Tile tile) {
    if (_selectedTileId == tile.id) {
      setState(() => _selectedTileId = null);
      _discard(context, tile);
    } else {
      setState(() => _selectedTileId = tile.id);
    }
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
    // Same rule as the green tile: the guide's opinions show only while it is
    // on, and multiplayer (no toggle) never has one.
    final showGuide = widget.showGuide && widget.onToggleGuide != null;

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
        final runs = game.humanChiRuns;
        if (runs.length > 1) {
          // Several runs could be made with this tile, so you choose which.
          // The guide's pick, when it has one, carries a star.
          final picked = showGuide ? game.recommendedChiRun : null;
          for (final low in runs) {
            buttons.add(KeyedSubtree(
              key: Key('chiRun_${low.name}'),
              child: _btn(
                  '${ruleset.chiLabel.toUpperCase()} ${_runLabel(low)}'
                  '${low == picked ? ' ★' : ''}',
                  const Color(0xff00838f),
                  () => game.answerCall(CallType.chi, chiLow: low)),
            ));
          }
        } else {
          buttons.add(_btn(ruleset.chiLabel.toUpperCase(),
              const Color(0xff00838f), () => game.answerCall(CallType.chi)));
        }
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
      // Nine kinds of terminals/honors — only ever on your own first
      // uninterrupted draw, so this never overlaps a real turn's usual
      // choices; it just sits alongside them when it's on offer at all.
      if (game.humanCanDeclareKyuushu) {
        buttons.add(_btn('KYUUSHU KYUUHAI', const Color(0xff8d6e63),
            game.humanDeclareKyuushu));
      }
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
      // Whenever riichi is legal — closed, and some discard leaves the hand
      // tenpai — not only when the guide would declare it. Discarding one of
      // those tiles offers the declaration. The guide's own preference is
      // added only while it is on.
      if (game.humanCanRiichi) {
        final recommended = showGuide && game.report.recommendRiichi;
        buttons.add(Chip(
          key: const Key('riichiAvailable'),
          avatar: const Icon(Icons.campaign, size: 16, color: Colors.white),
          label: Text(
              recommended
                  ? 'Riichi available — recommended'
                  : 'Riichi available',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          backgroundColor:
              recommended ? const Color(0xff2e7d32) : const Color(0xff37474f),
          side: const BorderSide(color: Color(0xffcaa24e)),
          visualDensity: VisualDensity.compact,
        ));
      }
    }

    // What the bar is offering, as one value: when it changes, the old set of
    // buttons fades out as the new one fades in, rather than swapping in a
    // single frame.
    final offer = [
      game.humanFuriten,
      game.round.canFlowerWin(kHumanSeat),
      game.humanCallOption?.types,
      game.humanChiRuns,
      game.isHumanTurn,
      game.humanCanDeclareKyuushu,
      game.humanCanTsumo,
      game.humanClosedKanTypes,
      game.humanAddedKanTypes,
      game.humanCanRiichi,
      showGuide && game.report.recommendRiichi,
      showGuide ? game.recommendedChiRun : null,
    ].join('|');
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    // Fixed height so the tile bar below never shifts as buttons come and go.
    // Centred (rather than left-aligned) so it lines up under the seat badge
    // above it instead of hugging the left edge of the bar.
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedSwitcher(
            duration: still ? Duration.zero : const Duration(milliseconds: 150),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween(begin: 0.96, end: 1.0).animate(animation),
                child: child,
              ),
            ),
            child: Wrap(
              key: ValueKey(offer),
              // Wide gaps so a thumb on a small screen lands on the action
              // it meant — the bar is the full canvas width, so even a
              // crowded turn (every chi option plus pon, kan, win and pass)
              // stays one row.
              spacing: 17,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: buttons,
            ),
          ),
          // Take back sits apart at the left end, outside the centred row,
          // so the call buttons never shift when it comes and goes.
          if (game.canUndo)
            Positioned(left: 0, child: _undoButton()),
        ],
      ),
    );
  }

  /// Takes back your last decision this hand — see [TableGameHost.undo].
  /// Named for what it undoes, so a press is never a guess.
  Widget _undoButton() => Tooltip(
        message: 'Take back your last move this hand, and everything after '
            'it.\nPress again to keep stepping back. (Ctrl/Cmd+Z)',
        child: OutlinedButton.icon(
          key: const Key('undo'),
          onPressed: () {
            setState(() => _selectedTileId = null);
            game.undo();
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xffe9d58f),
            side: const BorderSide(color: Color(0xffcaa24e)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            minimumSize: const Size(120, 44),
          ),
          icon: const Icon(Icons.undo, size: 22),
          label: Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'Take back  '),
              TextSpan(
                  text: game.undoLabel ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ),
      );

  /// "345m" for the run whose lowest tile is [low].
  static String _runLabel(TileType low) {
    final n = low.number;
    final code = low.code;
    return '$n${n + 1}${n + 2}${code.substring(code.length - 1)}';
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
                        color:
                            _HandViewState._yellow.withValues(alpha: 0.55 * v),
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

/// Slides its child from wherever it was last painted to wherever layout puts
/// it now — so a tile that changes slot glides there instead of jumping.
///
/// The move is noticed while painting, not after the frame: by then the new
/// slot would already have been shown for one frame, and the slide would
/// start with a flicker back to the old one. Positions are measured against
/// [anchor] (the strip itself), so scrolling or zooming the table moves
/// nothing.
class _SlideFromPrevious extends StatefulWidget {
  const _SlideFromPrevious({
    required this.anchor,
    required this.enabled,
    required this.child,
  });

  final RenderBox? Function() anchor;
  final bool enabled;
  final Widget child;

  @override
  State<_SlideFromPrevious> createState() => _SlideFromPreviousState();
}

class _SlideFromPreviousState extends State<_SlideFromPrevious>
    with SingleTickerProviderStateMixin {
  /// Quick enough to be done well inside a bot's turn, long enough to read
  /// as the row closing up rather than snapping shut.
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    value: 1,
  );

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Slide(
        anchor: widget.anchor,
        enabled: widget.enabled,
        progress: _progress,
        child: widget.child,
      );
}

class _Slide extends SingleChildRenderObjectWidget {
  const _Slide({
    required this.anchor,
    required this.enabled,
    required this.progress,
    super.child,
  });

  final RenderBox? Function() anchor;
  final bool enabled;
  final AnimationController progress;

  @override
  _RenderSlide createRenderObject(BuildContext context) =>
      _RenderSlide(anchor, enabled, progress);

  @override
  void updateRenderObject(BuildContext context, _RenderSlide renderObject) {
    renderObject
      ..anchor = anchor
      ..enabled = enabled;
  }
}

class _RenderSlide extends RenderProxyBox {
  _RenderSlide(this.anchor, this.enabled, this._progress);

  RenderBox? Function() anchor;
  bool enabled;
  final AnimationController _progress;

  /// Where layout put this last time it was painted, in the anchor's space.
  Offset? _lastSlot;

  /// How far from its slot the slide starts. Eased towards zero by
  /// [_progress].
  Offset _from = Offset.zero;

  /// A move was spotted mid-paint; [_progress] is restarted just after the
  /// frame, and until then the tile holds at [_from].
  bool _restartPending = false;

  Offset get _shift => _restartPending
      ? _from
      : _from * (1 - Curves.easeOutCubic.transform(_progress.value));

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _progress.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _progress.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final base = anchor();
    if (base != null && base.attached && enabled) {
      final slot = localToGlobal(Offset.zero, ancestor: base);
      final last = _lastSlot;
      if (last != null && (slot - last).distance > 0.5) {
        // Start from where it is on screen right now — mid-slide included —
        // so a second move during the first just bends the path.
        _from = _shift + (last - slot);
        _restartPending = true;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (!attached) return;
          _restartPending = false;
          _progress.forward(from: 0);
        });
      }
      _lastSlot = slot;
    }
    if (child != null) context.paintChild(child!, offset + _shift);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      result.addWithPaintOffset(
        offset: _shift,
        position: position,
        hitTest: (result, transformed) =>
            child?.hitTest(result, position: transformed) ?? false,
      );

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final s = _shift;
    transform.translateByDouble(s.dx, s.dy, 0, 1);
  }
}
