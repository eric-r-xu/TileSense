import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/call_callout.dart';
import '../game/game_controller.dart';
import '../game/guide_host.dart';
import '../game/sfx.dart' show kCharacterPortrait;
import 'package:mahjong_core/round.dart';
import 'meld_row.dart';
import 'tile_face.dart';
import 'tilesensor.dart';

/// The flat 2D table. Each seat's placard hugs its own edge with the concealed
/// hand just inside it (the freshly drawn tile split out so its position reads);
/// the four discard ponds bracket the centre on a fixed six-column grid whose
/// origin never moves as it fills; the dead wall sits in the top-right corner.
/// The round/wall status sits on one line dead centre, between the ponds —
/// see [TableStatusLine].
/// Which part of the table the scenario builder is currently pointing at.
enum TableArea { pond, melds, dora }

/// In-place editing hooks. Null in the live game — the table there is a
/// read-out, never an editor — and supplied only by the scenario builder, which
/// uses them to select a slot to fill and to pull tiles back out of it.
class TableEdits {
  const TableEdits({
    required this.onSelect,
    required this.onRemovePondTile,
    required this.onRemoveDora,
    this.area,
    this.seat,
  });

  /// Tapping a pond, a seat's melds, or the dead wall points the tile palette
  /// at it.
  final void Function(TableArea area, int seat) onSelect;

  /// Tapping a placed tile takes it back off the table.
  final void Function(int seat, int index) onRemovePondTile;
  final void Function(int index) onRemoveDora;

  /// The slot currently selected, drawn with a highlight ring.
  final TableArea? area;
  final int? seat;

  bool isSelected(TableArea a, int s) =>
      area == a && (a == TableArea.dora || seat == s);
}

class TableView extends StatelessWidget {
  const TableView({
    super.key,
    required this.game,
    this.edits,
    this.autoplaying = false,
    this.showRulesetInStatus = false,
    this.acrossInBar = false,
  });
  final GuideHost game;

  /// Auto-Play is playing your seat: your placard carries a small TileSensor,
  /// the same mascot as the Auto-Play switch, while it does.
  final bool autoplaying;

  /// Non-null only in the scenario builder; see [TableEdits].
  final TableEdits? edits;

  static const int _pondCols = 6;
  // Discard tiles render up to 25% larger than the authored `TileSize.normal`
  // step — all four ponds alike. Melds on the felt stay at this size.
  static const double _pondScale = 1.25;

  /// The smallest pond tiles ever get, on a table too short for the full
  /// [_pondScale] — see [_pondScaleFor].
  static const double _minPondScale = 1.0;

  /// Felt kept between a full pond and whatever sits beyond it.
  static const double _pondMargin = 5;

  /// The pond scale at which the across pond, the pill and your pond — each
  /// pond at its fullest, four rows behind a riichi stick — exactly fill a
  /// band [height] tall, capped at [_pondScale]. A tall table (a tablet)
  /// gets the full size; the phone-shaped one gives up a few percent rather
  /// than let a long game's fourth row run into the seats.
  static double _pondScaleFor(double height) {
    // 2 · _pondBoxH(s) + pill + gaps + margins = height, with
    // _pondBoxH(s) = 20 + 176·s.
    const fixed =
        2 * 20 + _statusPillHeight + 2 * _statusPillGap + 2 * _pondMargin;
    return ((height - fixed) / (2 * 176))
        .clamp(_minPondScale, _pondScale)
        .toDouble();
  }

  /// Height of the across seat's face-down hand, on its own row along the
  /// top of the felt, under their portrait up in the app bar: full size, the
  /// same backs as the side seats' hands.
  static const double _acrossHandRowHeight = _OpponentHandState._tileCross;

  /// How wide the across seat's hand comes out at [_acrossHandRowHeight].
  static double _acrossHandWidth(Round round) =>
      _OpponentHandState.mainExtent(_OpponentHandState.restFor(round, 2)) *
      _acrossHandRowHeight /
      _OpponentHandState._tileCross;

  /// The round/wall status pill in the middle of the table: one line, wide
  /// and short, so the ponds above and below it lose as little height to it
  /// as possible. It grows past [_statusPillMinWidth] for a longer line (the
  /// online table names the ruleset too) up to the gap between the side ponds.
  static const double _statusPillHeight = 28;
  static const double _statusPillMinWidth = 340;
  static const double _statusPillMaxWidth = 2 * _sidePondInset - 20;

  /// Felt left between the pill and the pond above and below it.
  static const double _statusPillGap = 6;

  /// From the middle of the table to the inner edge of each side pond: clear
  /// of the widest pill, and of the centre ponds' corners.
  static const double _sidePondInset = 230;

  /// Width of each side seat's column (placard, hand and melds).
  static const double _sideSeatWidth = 118;

  /// Portrait size for your seat and for the across seat up in the app bar:
  /// the side seats' size, and short enough to sit inside the 50px bar.
  static const double _barPortraitSize = 44;

  /// Room the across seat's row leaves at each end for Riichi's dead wall:
  /// seven tiles and its DORA/URA labels, plus a little felt.
  static const double _deadWallClearance = 7 * 33 + 50 + 8;

  /// How far down from the top of the table anything pinned to its top-left
  /// corner (the guide panel) starts. The corner is otherwise empty — the
  /// round/wall status sits in the middle of the table ([TableStatusLine]).
  static const double guidePanelTop = 8;

  /// Name the ruleset in the centre status too — for a table whose bar
  /// doesn't already show it (online play).
  final bool showRulesetInStatus;

  /// The across seat's portrait, placard and hand are up in the app bar
  /// ([TableBarTitle]) rather than along the top of the felt, which gives
  /// the ponds that row's height. Only their open melds stay on the felt.
  /// Off in the builder, whose bar is full of its own controls.
  final bool acrossInBar;

  // normal tile (32w / 44h) · scale + EdgeInsets.all(0.5) on both sides.
  static double _pondTileW(double scale) => 32 * scale + 1;
  static double _pondTileH(double scale) => 44 * scale + 1;
  // Fixed footprint: one riichi stick + four full rows. Anchored top-left so
  // earlier tiles stay put as later rows come in.
  static double _pondBoxW(double scale) =>
      _pondCols * _pondTileW(scale) + 16; // room for a turned tile
  static double _pondBoxH(double scale) => 16 + 4 * _pondTileH(scale);

  @override
  Widget build(BuildContext context) {
    final round = game.round;
    // Seat mapping from the human's perspective: 0 self, 1 right, 2 across, 3 left.
    return Container(
      color: const Color(0xff063a3a),
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 2),
      child: Stack(
        children: [
          Column(
            children: [
              if (acrossInBar)
                // The across seat's face-down hand, straight under their
                // portrait in the app bar.
                SizedBox(
                  height: _acrossHandRowHeight,
                  child: Center(
                    child: FittedBox(
                      key: const Key('acrossHand'),
                      child:
                          _OpponentHand(game: game, seat: 2, vertical: false),
                    ),
                  ),
                )
              else
                _opponentRow(round, 2),
              const SizedBox(height: 2),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sideOpponent(round, 3, isLeft: true),
                    Expanded(child: _centre(round)),
                    _sideOpponent(round, 1, isLeft: false),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              // A full eight-flower Taiwanese tray is wider than a typical
              // Hong Kong hand's, and this Row has no width of its own to
              // wrap within — scale the whole thing down instead of letting
              // it overflow the table.
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _ownSeat(round),
                ),
              ),
            ],
          ),

          // The across seat's open melds, on the line of their hand and just
          // left of it: out over empty felt, since they stand taller than the
          // hand's row and the pond below starts at the middle.
          if (acrossInBar && round.seats[2].melds.isNotEmpty)
            Positioned(
              top: 0,
              // Clear of the side seats' columns below, whose tops they
              // would otherwise reach with four kans.
              left: _sideSeatWidth + 8,
              right: _sideSeatWidth + 8,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.topRight,
                      child: FittedBox(
                        key: const Key('acrossMelds'),
                        fit: BoxFit.scaleDown,
                        child: _meldGroup(round.seats[2]),
                      ),
                    ),
                  ),
                  SizedBox(width: _acrossHandWidth(round) + 2 * 12),
                  const Spacer(),
                ],
              ),
            ),

          // Dead wall — top-right. Hong Kong and Taiwanese have no dora to
          // show here; their flowers sit beside each seat's own placard
          // instead.
          if (!round.ruleset.isChineseStyle)
            Positioned(
              top: 0,
              right: 0,
              child: _deadWall(round),
            ),
        ],
      ),
    );
  }

  /// Your portrait and placard, centred under your pond, with Hong Kong's
  /// and Taiwanese flowers beside them. The portrait is the side seats'
  /// size rather than bigger, so the row costs the ponds as little height
  /// as it can.
  Widget _ownSeat(Round round) {
    return Row(
      key: const Key('ownSeat'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _portrait(kHumanSeat, size: _barPortraitSize),
        const SizedBox(width: 8),
        _placard(round, kHumanSeat),
        if (round.ruleset.isChineseStyle) ...[
          const SizedBox(width: 8),
          _seatFlowers(round, kHumanSeat),
        ],
      ],
    );
  }

  /// The band between the across seat's hand and the hand bar: the status
  /// pill dead centre, your pond below it and the across pond above, the
  /// side ponds turned beside them, so the four form a square around the
  /// pill. Everything is placed off the band's middle, so a taller table
  /// just leaves more felt above and below. Each pond grows away from the
  /// middle as it fills.
  Widget _centre(Round round) {
    return LayoutBuilder(builder: (context, c) {
      final mid = c.maxHeight / 2;
      final centreX = c.maxWidth / 2;
      const clear = _statusPillHeight / 2 + _statusPillGap;
      final scale = _pondScaleFor(c.maxHeight);
      // A turned side pond is the upright box on its side.
      final sideW = _pondBoxH(scale);
      final sideH = _pondBoxW(scale);
      return Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: mid + clear,
            child:
                Center(child: _pond(round, 2, quarterTurns: 2, scale: scale)),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: mid + clear,
            child:
                Center(child: _pond(round, 0, quarterTurns: 0, scale: scale)),
          ),
          Positioned(
            left: centreX - _sidePondInset - sideW,
            top: mid - sideH / 2,
            child: _pond(round, 3, quarterTurns: 1, scale: scale),
          ),
          Positioned(
            left: centreX + _sidePondInset,
            top: mid - sideH / 2,
            child: _pond(round, 1, quarterTurns: 3, scale: scale),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: mid - _statusPillHeight / 2,
            child: Center(child: _statusPill()),
          ),
        ],
      );
    });
  }

  /// Round, wall and honba/riichi (or dealer repeat) on one line, in the
  /// middle of the table.
  Widget _statusPill() {
    return Container(
      key: const Key('statusPill'),
      height: _statusPillHeight,
      constraints: const BoxConstraints(
          minWidth: _statusPillMinWidth, maxWidth: _statusPillMaxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xe61f3a1c),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x66e9d58f), width: 1.5),
      ),
      // Sized to the line itself, not stretched to the widest the pill may
      // be: the line's FittedBox would otherwise grow to keep its aspect
      // ratio against the pill's fixed height.
      child: Center(
        widthFactor: 1,
        child: TableStatusLine(game: game, showRuleset: showRulesetInStatus),
      ),
    );
  }

  /// The 1000-point riichi declaration stick shown at the head of a pond.
  Widget _riichiStick() {
    return Container(
      margin: const EdgeInsets.only(bottom: 3, left: 1),
      width: 76,
      height: 12,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xfff4f1e6),
        border: Border.all(color: Colors.black54, width: 0.5),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
            color: Color(0xffcc1111), shape: BoxShape.circle),
      ),
    );
  }

  /// 40% bigger than the plain `TileSize.tiny` step — flowers were still
  /// hard to make out at that size, and this is the only place they render.
  static const double _flowerScale = 1.4;

  /// Hong Kong's and Taiwanese's exposed flowers and seasons for [seat],
  /// shown as a compact tray beside that seat's own placard rather than
  /// bundled in one corner — so they read as belonging to that player
  /// without covering any other tile on the table. Empty seats show nothing
  /// in the live game; the builder keeps a small tappable placeholder so
  /// there's always something on the table to select into flower-editing
  /// mode.
  Widget _seatFlowers(Round round, int seat) {
    if (!round.ruleset.isChineseStyle) return const SizedBox.shrink();
    final flowers = round.seats[seat].flowers;
    if (edits == null && flowers.isEmpty) return const SizedBox.shrink();
    final tray = flowers.isEmpty
        ? const SizedBox(width: 21, height: 29)
        : Wrap(
            spacing: 1,
            children: [
              for (final tile in flowers)
                TileFace(
                  tile: tile,
                  size: TileSize.tiny,
                  scale: _flowerScale,
                ),
            ],
          );
    return _selectable(TableArea.dora, seat, tray);
  }

  /// The 14-tile dead wall: seven columns, two rows. The upper row shows the
  /// revealed dora indicators; the lower row is ura-dora and stays face down
  /// until a riichi hand wins the round (real ryuukyoku doesn't reveal it, and
  /// neither does a non-riichi win — the indicators don't count for it).
  Widget _deadWall(Round round) {
    final result = round.result;
    final revealUra = result != null &&
        (result.kind == RoundEndKind.tsumo ||
            result.kind == RoundEndKind.ron) &&
        result.winners.any((w) => round.seats[w].riichi);
    final tiles = round.wall.deadWallDisplay(revealUra: revealUra);
    // Dead-wall slots 4,6,8,10,12 are the dora indicators; in the builder each
    // revealed one can be tapped off again.
    int? doraIndexAt(int slot) =>
        (slot >= 4 && slot.isEven && tiles[slot] != null)
            ? (slot - 4) ~/ 2
            : null;
    List<Widget> row(bool top) => [
          for (var col = 0; col < 7; col++)
            Padding(
              padding: const EdgeInsets.all(0.5),
              child: switch ((edits, doraIndexAt(col * 2 + (top ? 0 : 1)))) {
                (final e?, final d?) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => e.onRemoveDora(d),
                    child: TileFace(
                      tile: tiles[col * 2 + (top ? 0 : 1)],
                      size: TileSize.normal,
                    ),
                  ),
                _ => TileFace(
                    tile: tiles[col * 2 + (top ? 0 : 1)],
                    faceDown: tiles[col * 2 + (top ? 0 : 1)] == null,
                    size: TileSize.normal,
                  ),
              },
            ),
        ];
    // 44-high normal tile + 0.5 padding on both sides, so each label lines up
    // with its row regardless of whether the URA label is present.
    Widget rowLabel(String t) => SizedBox(
          height: 45,
          child: Center(
            child: Text(t,
                style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ),
        );
    return Row(
      key: const Key('deadWall'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              rowLabel('DORA'),
              rowLabel(revealUra ? 'URA' : ''),
            ],
          ),
        ),
        _selectable(
          TableArea.dora,
          -1,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: row(true)),
              Row(mainAxisSize: MainAxisSize.min, children: row(false)),
            ],
          ),
        ),
      ],
    );
  }

  /// One player's discard pond in a fixed-size box (six columns, four rows),
  /// content anchored top-left so every tile keeps its slot as the pond fills.
  /// The newest tile pops in so you can see it land.
  Widget _pond(Round round, int seat,
      {required int quarterTurns, required double scale}) {
    final s = round.seats[seat];
    if (s.pond.isEmpty && !s.riichi) return const SizedBox.shrink();
    final last = s.pond.length - 1;
    // Pulse the just-cut tile while the human is being offered a call on it.
    final flashLast =
        game.awaitingHumanCall && round.pendingDiscardSeat == seat;
    final rows = <Widget>[];
    for (var start = 0; start < s.pond.length; start += _pondCols) {
      final end = (start + _pondCols).clamp(0, s.pond.length);
      rows.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = start; i < end; i++)
            Padding(
              padding: const EdgeInsets.all(0.5),
              child: i == last
                  ? (flashLast
                      ? _FlashTile(
                          child: TileFace(
                            tile: s.pond[i],
                            size: TileSize.normal,
                            scale: scale,
                            rotationQuarterTurns:
                                i == s.riichiPondIndex ? 1 : 0,
                          ),
                        )
                      : _travelIn(
                          ValueKey('pond-$seat-${s.pond.length}'),
                          child: TileFace(
                            tile: s.pond[i],
                            size: TileSize.normal,
                            scale: scale,
                            rotationQuarterTurns:
                                i == s.riichiPondIndex ? 1 : 0,
                          ),
                        ))
                  : TileFace(
                      tile: s.pond[i],
                      size: TileSize.normal,
                      scale: scale,
                      rotationQuarterTurns: i == s.riichiPondIndex ? 1 : 0,
                    ),
            ),
        ],
      ));
    }
    if (edits case final e?) {
      for (var row = 0; row < rows.length; row++) {
        final base = row * _pondCols;
        rows[row] = _RemovableRow(
          row: rows[row],
          count: (s.pond.length - base).clamp(0, _pondCols),
          onTap: (i) => e.onRemovePondTile(seat, base + i),
          tileWidth: _pondTileW(scale),
        );
      }
    }
    final boxed = SizedBox(
      width: _pondBoxW(scale),
      height: _pondBoxH(scale),
      child: Align(
        alignment: Alignment.topLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (s.riichi) _popIn(ValueKey('riichi-$seat'), _riichiStick()),
            ...rows,
          ],
        ),
      ),
    );
    final selectable = _selectable(TableArea.pond, seat, boxed);
    return KeyedSubtree(
      key: ValueKey('pond-$seat'),
      child: quarterTurns == 0
          ? selectable
          : RotatedBox(quarterTurns: quarterTurns, child: selectable),
    );
  }

  /// Wraps a slot so the builder can point the palette at it. In the live game
  /// [edits] is null and this returns [child] untouched.
  Widget _selectable(TableArea area, int seat, Widget child) {
    final e = edits;
    if (e == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => e.onSelect(area, seat),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: e.isSelected(area, seat)
                ? const Color(0xffe9d58f)
                : const Color(0x22ffffff),
            width: e.isSelected(area, seat) ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: child,
      ),
    );
  }

  /// Pre-rotation local displacement a freshly discarded tile eases in from.
  /// Every pond is built "top-left, growing down" and *then* turned by its
  /// own `quarterTurns` in [_pond] (0/1/2/3 for the bottom/left/top/right
  /// seats), with each rotation chosen so that a tile displaced this way
  /// before that turn lands, after it, displaced outward along that seat's
  /// own edge of the table — down for you, up for across, sideways for the
  /// two turned seats — without this animation needing to know which seat it
  /// is. (Verified by hand for all four `quarterTurns` values: a positive
  /// local y always rotates to point away from the centre status block.)
  static const Offset _pondArrivalFrom = Offset(0, 56);

  /// A one-shot "it just landed here" transition for a freshly discarded
  /// tile: it glides in from [_pondArrivalFrom], fading in over the first
  /// part of the trip and growing very slightly, so it reads as having
  /// travelled from the hand rather than having appeared.
  ///
  /// One long, soft deceleration and no overshoot: an earlier version rode
  /// past the slot and bounced back, which read as jumpy at the table's pace.
  /// 480ms keeps it inside a single fast-mode turn (see
  /// `GameController._stepDelay`, 552ms), so it never laps the next action.
  Widget _travelIn(Key key, {required Widget child}) => Builder(
      key: key, builder: (context) => _still(context) ? child : _travel(child));

  Widget _travel(Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 480),
      curve: Curves.linear,
      builder: (_, t, c) {
        final slide = Curves.easeOutCubic.transform(t);
        final fade = Curves.easeOut.transform((t / 0.35).clamp(0.0, 1.0));
        return Opacity(
          opacity: fade,
          child: Transform.translate(
            offset: _pondArrivalFrom * (1 - slide),
            child: Transform.scale(scale: 0.94 + 0.06 * slide, child: c),
          ),
        );
      },
      child: child,
    );
  }

  /// A one-shot pop-in for a newly formed meld (chi/pon/kan) or a riichi
  /// stick, so a call reads as the set assembling rather than appearing
  /// whole: it rises a little and grows into place, settling without a
  /// bounce.
  Widget _popIn(Key key, Widget child) => Builder(
      key: key, builder: (context) => _still(context) ? child : _pop(child));

  /// The system's reduce-motion setting: tiles and melds just appear.
  static bool _still(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  Widget _pop(Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.linear,
      builder: (_, t, c) {
        final settle = Curves.easeOutCubic.transform(t);
        return Opacity(
          opacity: Curves.easeOut.transform((t / 0.5).clamp(0.0, 1.0)),
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - settle)),
            child: Transform.scale(scale: 0.85 + 0.15 * settle, child: c),
          ),
        );
      },
      child: child,
    );
  }

  Widget _meldGroup(SeatState s) {
    final group = Wrap(
      spacing: 4,
      runSpacing: 2,
      children: [
        for (final m in s.melds)
          _popIn(
            // The tile-id list is a meld's identity: stable across rebuilds
            // (so an already-shown meld doesn't replay its pop), but fresh
            // whenever a kan upgrades an existing pon's tiles, which is
            // itself a call worth animating in again.
            ValueKey('meld-${s.seat}-${m.tiles.map((t) => t.id).join(',')}'),
            MeldRow(m,
                size: TileSize.small,
                scale: _pondScale,
                // The builder poses the whole table, so it shows everything.
                faceDown: edits == null &&
                    s.seat != kHumanSeat &&
                    game.round.isHiddenKong(m)),
          ),
      ],
    );
    if (edits == null) return group;
    // The builder needs somewhere to tap even before a seat has any calls.
    return _selectable(
      TableArea.melds,
      s.seat,
      s.melds.isEmpty
          ? const SizedBox(
              width: 54,
              height: 30,
              child: Center(
                  child: Text('calls',
                      style: TextStyle(color: Colors.white54, fontSize: 10))))
          : group,
    );
  }

  /// Across player along the top of the felt — only where they aren't up in
  /// the app bar ([acrossInBar]), i.e. the builder. On one line so the ponds
  /// get the height a second row would take: portrait and placard dead centre, over the across pond,
  /// with open melds (and Hong Kong's / Taiwanese flowers) to their left and
  /// the concealed hand to their right. The hand takes the right because the
  /// melds can run long, and the right has the dead wall's corner to keep
  /// clear of while the left only has the guide panel, which is an overlay.
  Widget _opponentRow(Round round, int seat) {
    final s = round.seats[seat];
    final chinese = round.ruleset.isChineseStyle;
    // Each side scales down rather than overflowing into the middle: four
    // melds and a full flower tray have no bounded width to wrap within.
    // Riichi's dead wall holds the top-right corner, so both outer edges
    // keep that far in — both, so the middle stays the middle.
    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: chinese ? 0 : _deadWallClearance),
      child: LayoutBuilder(builder: (context, c) {
        final maxWidth = c.maxWidth;
        return Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  key: const Key('acrossLeft'),
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (s.melds.isNotEmpty) _meldGroup(s),
                      if (s.melds.isNotEmpty && chinese)
                        const SizedBox(width: 10),
                      if (chinese) _seatFlowers(round, seat),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Scales down too, if a long name ever leaves the sides no room.
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth - 20),
              child: FittedBox(
                key: const Key('acrossSeat'),
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _portrait(seat, size: 49, tooltip: game.seatLabel(seat)),
                    const SizedBox(width: 6),
                    _placard(round, seat),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  key: const Key('acrossHand'),
                  fit: BoxFit.scaleDown,
                  child: _OpponentHand(game: game, seat: seat, vertical: false),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  /// A side seat: placard on the outer edge, concealed hand (turned 90° to the
  /// player) and open melds shifted just inside it.
  Widget _sideOpponent(Round round, int seat, {required bool isLeft}) {
    final s = round.seats[seat];
    // Portrait stays upright above the sideways placard on the outer edge.
    final placard = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _portrait(seat, size: 44, tooltip: game.seatLabel(seat)),
        const SizedBox(height: 4),
        RotatedBox(
          quarterTurns: isLeft ? 3 : 1,
          child: _placard(round, seat),
        ),
        if (round.ruleset.isChineseStyle) ...[
          const SizedBox(height: 4),
          _seatFlowers(round, seat),
        ],
      ],
    );
    // The hand keeps its full size — the same backs as the across seat's —
    // and the melds below it are what give way if a column of calls ever
    // runs longer than the table is tall. Each call takes three backs out of
    // the hand, so that only happens with four kans on a short table.
    final inside = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _OpponentHand(
          key: ValueKey('sideHand-$seat'),
          game: game,
          seat: seat,
          vertical: true,
          rotate: isLeft ? 1 : 3,
        ),
        if (s.melds.isNotEmpty) ...[
          const SizedBox(height: 6),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: RotatedBox(
                quarterTurns: isLeft ? 1 : 3,
                child: _meldGroup(s),
              ),
            ),
          ),
        ],
      ],
    );
    // Scales the placard column down to fit rather than overflowing — the
    // rotated placard alone already runs tall, and Hong Kong's added flower
    // tray beneath it needs the same headroom [inside] gets.
    final flexPlacard =
        Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: placard));
    return SizedBox(
      key: ValueKey('sideSeat-$seat'),
      width: _sideSeatWidth,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: isLeft
                  ? [
                      flexPlacard,
                      const SizedBox(width: 6),
                      Flexible(child: inside)
                    ]
                  : [
                      Flexible(child: inside),
                      const SizedBox(width: 6),
                      flexPlacard
                    ],
            ),
          ),
        ],
      ),
    );
  }

  /// A seat's character portrait, tucked beside its placard and sized to sit
  /// level with it. [tooltip], when given, names the player on hover — the
  /// same mechanism as the TileSensor guide toggle.
  Widget _portrait(int seat, {double size = 42, String? tooltip}) {
    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xff0c4747),
        border: Border.all(color: const Color(0xffcaa24e), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        kCharacterPortrait[game.characterForSeat(seat)]!,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
    final portrait =
        tooltip == null ? avatar : Tooltip(message: tooltip, child: avatar);
    return _CallBubbleAnchor(seat: seat, child: portrait);
  }

  /// Seat placard (wind + score), with Hong Kong's matching bonus-tile number.
  Widget _placard(Round round, int seat) {
    final s = round.seats[seat];
    final active = round.turn == seat &&
        !round.finished &&
        round.phase != RoundPhase.callOffer;
    // `seatLabel` already carries "(you)"/"(bot)" where relevant — the real
    // guest nickname online, the fixed persona name offline.
    // The number follows the current wind, not the fixed character position.
    final seatNumber =
        round.ruleset.isChineseStyle ? '${s.wind.index + 1} ' : '';
    // The Custom Hand & Context Builder (`edits` set) shows just the wind: who
    // sits where is not part of a posed table.
    final name = edits == null ? '${game.seatLabel(seat)}  ' : ' ';
    final label = '$seatNumber${s.wind.kanji}(${s.wind.initial}) '
        '$name${s.points}${s.riichi ? '  ◉' : ''}';
    final placard = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? const Color(0xffcaa24e) : const Color(0xff0c4747),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: active ? Colors.black : Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    final deadline = game.turnDeadlineMs;
    final badges = <Widget>[
      // The human seat gets a FURITEN badge beside its placard while tenpai
      // but barred from ron. Only seat 0's placard renders unrotated, so
      // keep it here.
      if (seat == kHumanSeat && game.humanFuriten) _furitenBadge(),
      if (seat == kHumanSeat && autoplaying) _autoplayBadge(),
      // Online play only — see [GuideHost.turnDeadlineMs] — a per-turn
      // countdown next to whoever's actually on the clock.
      if (active && deadline != null) CountdownBadge(deadlineMs: deadline),
    ];
    if (badges.isEmpty) return placard;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        placard,
        for (final b in badges) ...[const SizedBox(width: 6), b],
      ],
    );
  }

  Widget _autoplayBadge() => Tooltip(
        message: 'Auto-Play — TileSensor is playing your seat',
        child: Container(
          key: const Key('autoplaySeatBadge'),
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: const Color(0xff0c4747),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xffcaa24e), width: 1.5),
          ),
          child: Image.asset(
            kTileSensorAsset,
            width: 18,
            height: 18,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => const Icon(Icons.play_arrow,
                size: 18, color: Color(0xffcaa24e)),
          ),
        ),
      );

  Widget _furitenBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xffc62828),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'FURITEN',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      );
}

/// Seconds remaining until [deadlineMs], ticking down once a second on its
/// own timer — the server's `turnDeadlineMs` only changes when a fresh turn
/// starts, so nothing else would rebuild this between broadcasts.
class CountdownBadge extends StatefulWidget {
  const CountdownBadge({super.key, required this.deadlineMs});
  final int deadlineMs;

  @override
  State<CountdownBadge> createState() => _CountdownBadgeState();
}

class _CountdownBadgeState extends State<CountdownBadge> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(CountdownBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deadlineMs != widget.deadlineMs) _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remainingMs =
        widget.deadlineMs - DateTime.now().millisecondsSinceEpoch;
    final seconds = (remainingMs / 1000).ceil().clamp(0, 999);
    final urgent = seconds <= 10;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: urgent ? const Color(0xffc62828) : const Color(0xff0c4747),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '${seconds}s',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// A tile that pulses (glow + gentle scale) to point at the tile a pending
/// call would act on.
class _FlashTile extends StatefulWidget {
  const _FlashTile({required this.child});
  final Widget child;

  @override
  State<_FlashTile> createState() => _FlashTileState();
}

class _FlashTileState extends State<_FlashTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Transform.scale(
          scale: 1.0 + 0.10 * t,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              boxShadow: [
                BoxShadow(
                  color: Color.lerp(
                      const Color(0x00ffd54f), const Color(0xffffd54f), t)!,
                  blurRadius: 6 + 10 * t,
                  spreadRadius: 1 + 2 * t,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// An opponent's concealed hand: backs with the freshly drawn tile split off on
/// the right. When that seat cuts a tile from its hand (not tsumogiri), a blank
/// slot flashes at the cut position for ~450 ms so you can see which tile left,
/// then the backs close up.
///
/// The strip is a fixed footprint (room for the resting backs, the gap, and the
/// separated drawn tile) so drawing or discarding never changes how much space
/// this seat's hand occupies — only the tiles inside it move; it shortens only
/// when a call takes tiles out of the hand. Without this the
/// hand (and everything centred around it: portrait, placard, melds) visibly
/// shifted every time an opponent drew, then shifted back on discard.
class _OpponentHand extends StatefulWidget {
  const _OpponentHand({
    super.key,
    required this.game,
    required this.seat,
    required this.vertical,
    this.rotate = 0,
  });

  final GuideHost game;
  final int seat;
  final bool vertical;
  final int rotate;

  @override
  State<_OpponentHand> createState() => _OpponentHandState();
}

class _OpponentHandState extends State<_OpponentHand> {
  int _seenSerial = -1;
  int? _gapIndex;
  Timer? _timer;

  // Small-tile back footprint: 22×30 face + 0.5 padding on every side = 23×31.
  // A rotated back (side seats) reports the same numbers swapped, so the
  // extent along the strip's main axis is always 23 and its depth always 31
  // regardless of orientation.
  static const double _tileMain = 23;
  static const double _tileCross = 31;
  static const double _drawGap = 6;

  /// The backs [seat] has resting in hand, not counting a freshly drawn tile:
  /// at most a closed hand's 13, or Taiwanese's 16.
  static int restFor(Round round, int seat) {
    final s = round.seats[seat];
    return (s.drawn != null ? s.hand.length - 1 : s.hand.length)
        .clamp(0, round.ruleset.concealedHandSize);
  }

  /// The largest this strip needs to be for [rest] resting backs: one more
  /// for the ~450 ms discard-cut flash (which briefly inserts an extra blank
  /// slot), plus the gap and the separated drawn tile. Those two extras don't
  /// actually overlap in practice, but sizing for both together costs nothing
  /// and keeps this safe even if a future timing tweak ever let them touch.
  /// It only changes when a call takes tiles out of the hand, so the strip
  /// holds still through every draw and discard, yet stays centred on the
  /// tiles actually there.
  static double mainExtent(int rest) =>
      (rest + 1) * _tileMain + _drawGap + _tileMain;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _sync() {
    final g = widget.game;
    if (g.discardSerial == _seenSerial) return;
    _seenSerial = g.discardSerial;
    _timer?.cancel();
    if (g.lastDiscardSeat == widget.seat && !g.lastDiscardTsumogiri) {
      final n = g.round.seats[widget.seat].hand.length; // 13 after a hand cut
      _gapIndex = (n ~/ 2).clamp(0, n);
      _timer = Timer(const Duration(milliseconds: 450), () {
        if (mounted) setState(() => _gapIndex = null);
      });
    } else {
      _gapIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    _sync();
    final s = widget.game.round.seats[widget.seat];
    final rotate = widget.rotate;
    final hasDrawn = s.drawn != null;
    final rest = restFor(widget.game.round, widget.seat);

    Widget back() => Padding(
          padding: const EdgeInsets.all(0.5),
          child: TileFace(
              faceDown: true,
              size: TileSize.small,
              rotationQuarterTurns: rotate),
        );

    final tiles = <Widget>[];
    for (var i = 0; i < rest; i++) {
      if (_gapIndex == i) {
        tiles.add(Opacity(opacity: 0, child: back())); // the flashed blank slot
      }
      tiles.add(back());
    }
    if (_gapIndex != null && _gapIndex! >= rest) {
      tiles.add(Opacity(opacity: 0, child: back()));
    }
    if (hasDrawn) {
      tiles.add(SizedBox(
          width: widget.vertical ? 0 : 6, height: widget.vertical ? 6 : 0));
      tiles.add(back());
    }

    final content = widget.vertical
        ? Column(mainAxisSize: MainAxisSize.min, children: tiles)
        : Row(mainAxisSize: MainAxisSize.min, children: tiles);

    // Fixed-size box, content anchored to its start edge: the strip's
    // footprint never changes, so nothing around it needs to recentre while
    // the discard-cut animation above decides (and shows) whether this was
    // the drawn tile or one from the existing hand.
    return SizedBox(
      width: widget.vertical ? _tileCross : mainExtent(rest),
      height: widget.vertical ? mainExtent(rest) : _tileCross,
      child: Align(
        alignment: widget.vertical ? Alignment.topCenter : Alignment.centerLeft,
        child: content,
      ),
    );
  }
}

/// Overlays tap targets on one already-laid-out pond row so the scenario
/// builder can pull a discard back off the table. Sized from the row's own
/// fixed tile pitch, so the hit boxes line up with what is drawn.
class _RemovableRow extends StatelessWidget {
  const _RemovableRow({
    required this.row,
    required this.count,
    required this.onTap,
    required this.tileWidth,
  });

  final Widget row;
  final int count;
  final void Function(int indexInRow) onTap;
  final double tileWidth;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        row,
        Positioned.fill(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < count; i++)
                SizedBox(
                  width: tileWidth,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Wraps a seat's portrait and flashes its call bubble (see [CallCallout]):
/// white text on black, "PON" / "CHI" / "KAN" / "RON" / "TSUMO" / "RIICHI".
///
/// The bubble lives in the app's root [Overlay], not in the table's own widget
/// tree, so it paints above everything — the hand, the ponds, the scoring
/// panel — and can never be covered. A [CompositedTransformFollower] pins it
/// beside the portrait (following any scaling of the table). This owns the
/// flash timer; [CallCallout] only says when a call happened.
class _CallBubbleAnchor extends StatefulWidget {
  const _CallBubbleAnchor({required this.seat, required this.child});
  final int seat;
  final Widget child;

  @override
  State<_CallBubbleAnchor> createState() => _CallBubbleAnchorState();
}

class _CallBubbleAnchorState extends State<_CallBubbleAnchor> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;
  Timer? _timer;
  // Calls made before this widget existed are history, not something to flash.
  int _seenId = 0;

  @override
  void initState() {
    super.initState();
    _seenId = CallCallout.i.latest(widget.seat)?.id ?? 0;
    CallCallout.i.addListener(_onCall);
  }

  void _onCall() {
    final call = CallCallout.i.latest(widget.seat);
    if (call == null || call.id == _seenId || !mounted) return;
    _seenId = call.id;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _hide();
    // Left seat: bubble to the right of the portrait. Every other seat: to its
    // left (the bottom and top portraits have their placard on the right).
    final onRight = widget.seat == 3;
    _entry = OverlayEntry(
      builder: (_) => Positioned(
        left: 0,
        top: 0,
        child: CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: onRight ? Alignment.centerRight : Alignment.centerLeft,
          followerAnchor:
              onRight ? Alignment.centerLeft : Alignment.centerRight,
          offset: Offset(onRight ? 6 : -6, 0),
          child: _bubble(call.text),
        ),
      ),
    );
    overlay.insert(_entry!);
    _timer = Timer(CallCallout.flash, _hide);
  }

  void _hide() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
  }

  Widget _bubble(String text) => IgnorePointer(
        child: Container(
          key: ValueKey('call-bubble-${widget.seat}'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Text(
            text,
            maxLines: 1,
            softWrap: false,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      );

  @override
  void dispose() {
    CallCallout.i.removeListener(_onCall);
    _hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      CompositedTransformTarget(link: _link, child: widget.child);
}

/// The round, wall and stick/repeat counts on one line, for the status pill
/// in the middle of the table — the same read-out for Riichi, Hong Kong and
/// Taiwanese tables, solo or online. Scales down rather than wrapping when
/// the pill is tight, so it never grows into the ponds around it.
class TableStatusLine extends StatelessWidget {
  const TableStatusLine(
      {super.key, required this.game, this.showRuleset = false});
  final GuideHost game;

  /// Name the ruleset too (Hong Kong/Taiwanese only, where the dealer-repeat
  /// count takes the honba/riichi slot) — for a table whose app bar doesn't
  /// already show it.
  final bool showRuleset;

  static const _colour = Color(0xffe9d58f);

  @override
  Widget build(BuildContext context) {
    final round = game.round;
    final rules = round.ruleset;
    final rest = [
      'Wall ${round.wall.remaining}',
      if (rules.isChineseStyle) ...[
        if (showRuleset) rules.label,
        'Dealer repeat ${game.dealerRepeat}',
      ] else ...[
        'Honba ${game.honba}',
        'Riichi ${round.riichiSticks}',
      ],
    ];
    return FittedBox(
      key: const Key('tableStatus'),
      fit: BoxFit.scaleDown,
      child: Text.rich(
        TextSpan(
          style: const TextStyle(
              color: _colour, fontSize: 13, fontWeight: FontWeight.w600),
          children: [
            TextSpan(
              text: '${round.roundWind.kanji} ${round.roundWind.label} '
                  '${game.handInWind}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            for (final r in rest) TextSpan(text: '  ·  $r'),
          ],
        ),
        maxLines: 1,
        softWrap: false,
      ),
    );
  }
}

/// An app bar title that carries the across seat: the bar's own controls
/// ([leading]) on the left, then the across seat's portrait and placard
/// centred over the table — over their hand, which runs along the top of the
/// felt just below — and Hong Kong's / Taiwanese flowers just right of the
/// placard. Pair it with a `TableView(acrossInBar: true)`.
///
/// [titleStart] is where the bar starts this title: its leading width plus
/// its title spacing. The layout needs it to find the middle of the table,
/// since the title itself starts well right of the table's edge.
class TableBarTitle extends StatelessWidget {
  const TableBarTitle({
    super.key,
    required this.game,
    required this.titleStart,
    required this.leading,
    this.height = 50,
  });
  final GuideHost game;
  final double titleStart;
  final Widget leading;

  /// The bar's toolbar height. A bar's title slot leaves height unbounded,
  /// so this title sizes itself to it.
  final double height;

  @override
  Widget build(BuildContext context) {
    final round = game.round;
    final table = TableView(game: game, acrossInBar: true);
    const seat = 2;
    return SizedBox(
      height: height,
      child: CustomMultiChildLayout(
        delegate: _BarTitleLayout(
          centreX: MediaQuery.sizeOf(context).width / 2 - titleStart,
        ),
        children: [
          LayoutId(id: _BarPart.leading, child: leading),
          LayoutId(
            id: _BarPart.seat,
            child: FittedBox(
              key: const Key('acrossSeat'),
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  table._portrait(seat,
                      size: TableView._barPortraitSize,
                      tooltip: game.seatLabel(seat)),
                  const SizedBox(width: 6),
                  table._placard(round, seat),
                ],
              ),
            ),
          ),
          if (round.ruleset.isChineseStyle)
            LayoutId(
              id: _BarPart.flowers,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: table._seatFlowers(round, seat),
              ),
            ),
        ],
      ),
    );
  }
}

enum _BarPart { leading, seat, flowers }

class _BarTitleLayout extends MultiChildLayoutDelegate {
  _BarTitleLayout({required this.centreX});

  /// The middle of the table, in this title's own coordinates.
  final double centreX;

  static const double _gap = 10;

  @override
  void performLayout(Size size) {
    Offset middle(Size child, double x) =>
        Offset(x, (size.height - child.height) / 2);

    final lead = layoutChild(_BarPart.leading, BoxConstraints.loose(size));
    positionChild(_BarPart.leading, middle(lead, 0));

    // Scales down rather than overflowing if the bar is ever that crowded.
    final start = lead.width + _gap;
    final seat = layoutChild(
        _BarPart.seat,
        BoxConstraints(
            maxWidth: math.max(0.0, size.width - start),
            maxHeight: size.height));
    // Centred over the table, unless the bar's own controls reach that far.
    final seatX = (centreX - seat.width / 2)
        .clamp(start, math.max(start, size.width - seat.width))
        .toDouble();
    positionChild(_BarPart.seat, middle(seat, seatX));

    if (hasChild(_BarPart.flowers)) {
      final x = seatX + seat.width + _gap;
      final flowers = layoutChild(
          _BarPart.flowers,
          BoxConstraints(
              maxWidth: (size.width - x).clamp(0, size.width).toDouble(),
              maxHeight: size.height));
      positionChild(_BarPart.flowers, middle(flowers, x));
    }
  }

  @override
  bool shouldRelayout(_BarTitleLayout oldDelegate) =>
      oldDelegate.centreX != centreX;
}
