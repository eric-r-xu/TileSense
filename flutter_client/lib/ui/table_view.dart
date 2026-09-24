import 'dart:async';

import 'package:flutter/material.dart';

import '../game/call_callout.dart';
import '../game/game_controller.dart';
import '../game/guide_host.dart';
import '../game/sfx.dart' show kCharacterPortrait;
import 'package:mahjong_core/round.dart';
import 'meld_row.dart';
import 'tile_face.dart';

/// The flat 2D table. Each seat's placard hugs its own edge with the concealed
/// hand just inside it (the freshly drawn tile split out so its position reads);
/// the four discard ponds bracket the centre on a fixed six-column grid whose
/// origin never moves as it fills; the round/wall status sits in the top-left
/// corner and the dead wall in the top-right one.
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
  const TableView({super.key, required this.game, this.edits});
  final GuideHost game;

  /// Non-null only in the scenario builder; see [TableEdits].
  final TableEdits? edits;

  static const int _pondCols = 6;
  // Discard tiles render 25% larger than the authored `TileSize.normal` step —
  // all four ponds alike.
  static const double _pondScale = 1.25;

  /// The gap between your pond and the one across from you. With the status
  /// panel up in the corner, nothing sits between them any more, so they meet
  /// in the middle of the table with just this much felt showing.
  static const double _centrePondGap = 10;

  /// The status panel's fixed height and its inset from the table's top edge.
  static const double _statusPanelHeight = 60;
  static const double _statusPanelTop = 6;

  /// How far down from the top of the table the top-left status panel
  /// reaches, plus a little clearance — where anything else pinned to that
  /// corner (the guide panel) should start so the two never overlap.
  static const double statusPanelClearance =
      _statusPanelTop + _statusPanelHeight + 8;

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
              _opponentRow(round, 2),
              const SizedBox(height: 2),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sideOpponent(round, 3, isLeft: true),
                    // The band between the across seat's hand and your own
                    // placard — exactly the room your pond and the one
                    // across from you have — so they are placed off it.
                    Expanded(child: _centrePonds(round)),
                    _sideOpponent(round, 1, isLeft: false),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Center(
                // A full eight-flower Taiwanese tray is wider than a
                // typical Hong Kong hand's, and this Row has no width of
                // its own to wrap within — scale the whole thing down
                // instead of letting it overflow the table, same as
                // FittedBox already does for hands and melds below.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _portrait(0, size: 55),
                      const SizedBox(width: 8),
                      _placard(round, 0),
                      if (round.ruleset.isChineseStyle) ...[
                        const SizedBox(width: 8),
                        _seatFlowers(round, 0),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          // The turned side ponds run out horizontally beside the centre
          // pair (see [_centrePonds]), so the four form a square.
          Align(
            alignment: const Alignment(-0.52, -0.04),
            child: _pond(round, 3, quarterTurns: 1),
          ),
          Align(
            alignment: const Alignment(0.52, -0.04),
            child: _pond(round, 1, quarterTurns: 3),
          ),

          // Round / honba / riichi / wall — the top-left corner, above the
          // left seat and clear of the across seat's row, which is centred.
          Positioned(
            top: _statusPanelTop,
            left: 0,
            child: _statusBox(round),
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

  /// Your pond and the one across from you, meeting in the middle of the
  /// band between the across seat's hand and your own placard. Each grows
  /// away from the middle as it fills; a long game's fourth row can run past
  /// the band's edge, which paints over rather than pushing anything aside.
  Widget _centrePonds(Round round) {
    return LayoutBuilder(builder: (context, c) {
      final mid = c.maxHeight / 2;
      return Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: mid + _centrePondGap / 2,
            child: Center(child: _pond(round, 2, quarterTurns: 2)),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: mid + _centrePondGap / 2,
            child: Center(child: _pond(round, 0, quarterTurns: 0)),
          ),
        ],
      );
    });
  }

  /// The top-left status panel: one stat per line, expansive green box. The
  /// round (with kanji) is largest, the wall counter second largest.
  Widget _statusBox(Round round) {
    Widget line(String t, double size, FontWeight weight) => Text(
          t,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            color: const Color(0xffe9d58f),
            fontSize: size,
            fontWeight: weight,
            height: 1.15,
          ),
        );
    return Container(
      // Fixed width so the panel reads as a panel, not a tight label — ~30%
      // wider than the widest line ("Honba 0 · Riichi 0") needs.
      width: 250,
      // Fixed height (content centred in it) so [statusPanelClearance] can
      // say exactly where the panel ends.
      height: _statusPanelHeight,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xe61f3a1c),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x66e9d58f), width: 1.5),
      ),
      // Shrinks to fit rather than overflowing if a line runs long (a wide
      // font, a long ruleset label), since the height above is fixed.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            line(
                '${round.roundWind.kanji}  ${round.roundWind.label} ${game.handInWind}',
                15,
                FontWeight.w800),
            const SizedBox(height: 2),
            line('Wall ${round.wall.remaining}', 12, FontWeight.w700),
            const SizedBox(height: 1),
            line(
                round.ruleset.isChineseStyle
                    ? '${round.ruleset.label}  ·  Dealer repeat ${game.dealerRepeat}'
                    : 'Honba ${game.honba}  ·  Riichi ${round.riichiSticks}',
                10,
                FontWeight.w600),
          ],
        ),
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
  Widget _pond(Round round, int seat, {required int quarterTurns}) {
    final s = round.seats[seat];
    const scale = _pondScale;
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
    return quarterTurns == 0
        ? selectable
        : RotatedBox(quarterTurns: quarterTurns, child: selectable);
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
  static const Offset _pondArrivalFrom = Offset(0, 40);

  /// A one-shot "it just landed here" transition for a freshly discarded
  /// tile: it glides in from [_pondArrivalFrom] while fading and growing
  /// slightly, so it reads as having travelled from the hand rather than
  /// having appeared. The slide, fade and scale run on their own curves —
  /// a long, soft deceleration for the slide, a quick fade so the tile is
  /// solid before it lands, and a gentle scale that settles with it — so no
  /// single property snaps into place. Kept under a single turn's step delay
  /// (see `GameController._stepDelay`, 552ms in fast mode) to within a whisker,
  /// so it never really laps the next action.
  Widget _travelIn(Key key, {required Widget child}) {
    return TweenAnimationBuilder<double>(
      key: key,
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 576),
      curve: Curves.linear,
      builder: (_, t, c) {
        // Three keyframes rather than two: glide in, ride a hair past the
        // slot, then settle back into it.
        final slide = _pondSlide.transform(t);
        final fade = Curves.easeOut.transform((t / 0.45).clamp(0.0, 1.0));
        final scale = _pondScale3.transform(t);
        return Opacity(
          opacity: fade,
          child: Transform.translate(
            offset: _pondArrivalFrom * (1 - slide),
            child: Transform.scale(scale: scale, child: c),
          ),
        );
      },
      child: child,
    );
  }

  /// 1 = at rest in the slot; the middle keyframe overshoots to 1.06 (a few
  /// pixels past it) before the last one settles back. Applied as
  /// `_pondArrivalFrom * (1 - slide)`, so an overshoot slides the tile briefly
  /// *past* its slot, away from where it came from.
  static final TweenSequence<double> _pondSlide = TweenSequence<double>([
    TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.06)
            .chain(CurveTween(curve: Curves.easeOutQuart)),
        weight: 70),
    TweenSequenceItem(
        tween: Tween(begin: 1.06, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 30),
  ]);

  static final TweenSequence<double> _pondScale3 = TweenSequence<double>([
    TweenSequenceItem(
        tween: Tween(begin: 0.85, end: 1.04)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 65),
    TweenSequenceItem(
        tween: Tween(begin: 1.04, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 35),
  ]);

  /// A one-shot pop-in for a newly formed meld (chi/pon/kan) or a riichi
  /// stick, so a call reads as the set assembling rather than appearing whole.
  /// Three keyframes: rise and grow in, swell just past full size, settle.
  Widget _popIn(Key key, Widget child) {
    return TweenAnimationBuilder<double>(
      key: key,
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 312),
      curve: Curves.linear,
      builder: (_, t, c) => Opacity(
        opacity: Curves.easeOut.transform((t / 0.5).clamp(0.0, 1.0)),
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - Curves.easeOutCubic.transform(t))),
          child: Transform.scale(scale: _popScale.transform(t), child: c),
        ),
      ),
      child: child,
    );
  }

  static final TweenSequence<double> _popScale = TweenSequence<double>([
    TweenSequenceItem(
        tween: Tween(begin: 0.55, end: 1.07)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 55),
    TweenSequenceItem(
        tween: Tween(begin: 1.07, end: 0.98)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 25),
    TweenSequenceItem(
        tween: Tween(begin: 0.98, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutSine)),
        weight: 20),
  ]);

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
                      style: TextStyle(color: Colors.white38, fontSize: 9))))
          : group,
    );
  }

  /// Across player: placard on top, open melds to the left of the concealed hand.
  Widget _opponentRow(Round round, int seat) {
    final s = round.seats[seat];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // See the human seat's own row in build() for why this is scaled
        // down rather than left to overflow: a full flower tray has no
        // bounded width to wrap within inside a plain Row.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _portrait(seat, size: 49, tooltip: game.seatLabel(seat)),
              const SizedBox(width: 6),
              _placard(round, seat),
              if (round.ruleset.isChineseStyle) ...[
                const SizedBox(width: 6),
                _seatFlowers(round, seat),
              ],
            ],
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (s.melds.isNotEmpty) ...[
              FittedBox(fit: BoxFit.scaleDown, child: _meldGroup(s)),
              const SizedBox(width: 10),
            ],
            FittedBox(
              fit: BoxFit.scaleDown,
              child: _OpponentHand(game: game, seat: seat, vertical: false),
            ),
          ],
        ),
      ],
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
    final inside = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: _OpponentHand(
                game: game, seat: seat, vertical: true, rotate: isLeft ? 1 : 3),
          ),
        ),
        if (s.melds.isNotEmpty) ...[
          const SizedBox(height: 6),
          RotatedBox(
            quarterTurns: isLeft ? 1 : 3,
            child: FittedBox(fit: BoxFit.scaleDown, child: _meldGroup(s)),
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
      width: 118,
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
  /// same mechanism as the AppBar's clefairy guide toggle.
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
/// The strip is a fixed footprint (room for 13 resting backs, the gap, and the
/// separated drawn tile) so drawing or discarding never changes how much space
/// this seat's hand occupies — only the tiles inside it move. Without this the
/// hand (and everything centred around it: portrait, placard, melds) visibly
/// shifted every time an opponent drew, then shifted back on discard.
class _OpponentHand extends StatefulWidget {
  const _OpponentHand({
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

  // The largest this strip ever needs to be: 13 resting backs plus one more
  // for the ~450 ms discard-cut flash (which briefly inserts an extra blank
  // slot), plus the gap and the separated drawn tile. Those two extras don't
  // actually overlap in practice, but sizing for both together costs nothing
  // and keeps this safe even if a future timing tweak ever let them touch.
  static const double _fixedMain = 14 * _tileMain + _drawGap + _tileMain;

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
    final rest = (hasDrawn ? s.hand.length - 1 : s.hand.length).clamp(0, 13);

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
      width: widget.vertical ? _tileCross : _fixedMain,
      height: widget.vertical ? _fixedMain : _tileCross,
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
