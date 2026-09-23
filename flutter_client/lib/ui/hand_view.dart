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
  /// button beside it) plus the bar's 10px bottom padding, plus the headroom
  /// every tile reserves above itself to raise into on a first tap. The
  /// efficiency overlay stops above this band so it never covers a tile.
  static const double tileRowBandHeight = 116 + _HandViewState._liftHeight;

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

  /// The tile a first tap raised, staged for discard. A second tap on it — or
  /// [_discard] itself — discards it; a tap on any other tile just moves the
  /// raise there instead. Cleared whenever a new tile is drawn (see [build]),
  /// so it never survives past the turn it was raised on.
  int? _selectedTileId;

  /// [Tile.drawn]'s id as of the last build, so [build] can tell a fresh draw
  /// apart from a rebuild mid-turn and drop a stale raise exactly once, at
  /// the turn boundary.
  int? _lastDrawnId;

  TableGameHost get game => widget.game;

  static const _yellow = Color(0xffffd54f);
  static const _green = Color(0xff43a047);

  /// How far a raised tile lifts off the row, in logical pixels.
  static const double _liftHeight = 12;

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
                          // Auto-discard only matters once you're locked
                          // into riichi, so it only appears then.
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _sortToggle(),
                              const SizedBox(height: 4),
                              _autoWinToggle(),
                              if (seat.riichi) ...[
                                const SizedBox(height: 4),
                                _autoDiscardToggle(),
                              ],
                            ],
                          ),
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
    return _miniToggle(
      key: const Key('sortHand'),
      label: 'Auto-sort',
      value: _autoSort,
      onTap: _toggleAutoSort,
      activeColor: const Color(0xff00695c),
      tooltip: _autoSort
          ? 'Auto-sort: on — tiles kept in tile order.\n'
              'Uncheck to freeze this order, or drag a tile to start your own.'
          : 'Auto-sort: off — your own order.\n'
              'Long-press a tile and drag it to move it. Check to resume auto-sort.',
    );
  }

  /// Auto-win: declares ron/tsumo the moment one is legal.
  Widget _autoWinToggle() {
    final game = widget.game;
    final on = game.autoWin;
    return _miniToggle(
      key: const Key('autoWin'),
      label: 'Auto-win',
      value: on,
      onTap: () => game.setAutoWin(!on),
      activeColor: const Color(0xff2e7d32),
      tooltip: on
          ? 'Auto-win: on — ron and tsumo are declared for you '
              'as soon as you can win.\nUncheck to decide yourself.'
          : 'Auto-win: off — press the win button yourself.\n'
              'Check to declare ron/tsumo automatically.',
    );
  }

  /// Riichi auto-discard: every discard after declaring is already forced to
  /// be the drawn tile, so this just skips confirming it. Never auto-kans —
  /// a self-kan (or a win) still waits for you.
  Widget _autoDiscardToggle() {
    final game = widget.game;
    final on = game.autoDiscardInRiichi;
    return _miniToggle(
      key: const Key('autoDiscardInRiichi'),
      label: 'Auto-discard',
      value: on,
      onTap: () => game.setAutoDiscardInRiichi(!on),
      activeColor: const Color(0xff8a6d1f),
      tooltip: on
          ? 'Auto-discard: on — your drawn tile is cut right away.\n'
              'Still pauses for a self-kan or a win. Uncheck to turn off.'
          : 'Auto-discard: off — confirm each drawn tile yourself.\n'
              'Check to cut it automatically (kans are never automatic).',
    );
  }

  /// A compact one-line checkbox chip, shared by the toggles stacked left
  /// of the hand so they line up at the same width — up to three of them fit
  /// within the tile row's height.
  Widget _miniToggle({
    required Key key,
    required String label,
    required bool value,
    required VoidCallback onTap,
    required Color activeColor,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: value ? activeColor : const Color(0xff294342),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Container(
            width: 86,
            padding: const EdgeInsets.fromLTRB(3, 2, 6, 2),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: Checkbox(
                    key: key,
                    value: value,
                    onChanged: (_) => onTap(),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    checkColor: activeColor,
                    activeColor: Colors.white,
                    side: const BorderSide(color: Colors.white60, width: 1.5),
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: value ? Colors.white : Colors.white60,
                    ),
                  ),
                ),
              ],
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
