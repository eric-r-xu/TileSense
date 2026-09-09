import 'dart:async';

import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../game/guide_host.dart';
import '../logic/round.dart';
import 'meld_row.dart';
import 'tile_face.dart';

/// The flat 2D table. Each seat's placard hugs its own edge with the concealed
/// hand just inside it (the freshly drawn tile split out so its position reads);
/// the four discard ponds bracket the centre on a fixed six-column grid whose
/// origin never moves as it fills; the round/wall status sits dead centre and
/// the dead wall in the top-right corner.
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
  // Discard tiles render 25% larger than the authored `TileSize.normal` step.
  static const double _pondScale = 1.25;

  /// Your pond and the one across from you are the only two whose *height*
  /// stacks against the centre status box — the left and right ponds are
  /// turned, so their rows run sideways. Those two render a step smaller so
  /// all four of their rows clear the box, on the short table the scenario
  /// builder lays out as well as the taller one the game does.
  static const double _verticalPondScale = 1.0;

  static double _pondScaleFor(int seat) =>
      (seat == 0 || seat == 2) ? _verticalPondScale : _pondScale;

  /// Half the centre status block, plus the breathing room to leave around it.
  /// Your pond and the one across from you are placed this far from the middle
  /// of the table, measured in pixels rather than as a fraction of its height —
  /// so they sit as close in as they can on a tall table and still clear the
  /// block on a short one. As a fraction they drifted out to a 300px gap on the
  /// game's table while nearly touching on the builder's shorter one.
  static const double _centreBlockHalfHeight = 30;
  static const double _centreBlockClearance = 16;

  /// Where to put the pond above (or below) the centre block so its inner edge
  /// lands exactly that clearance away.
  static double _verticalPondAlign(double tableHeight, {required bool above}) {
    final boxHeight = _pondBoxH(_verticalPondScale);
    final free = tableHeight - boxHeight;
    if (free <= 0) return above ? -1 : 1;
    const offset = _centreBlockHalfHeight + _centreBlockClearance;
    final top =
        above ? tableHeight / 2 - offset - boxHeight : tableHeight / 2 + offset;
    return (2 * top / free - 1).clamp(-1.0, 1.0);
  }

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
      child: LayoutBuilder(builder: (context, constraints) {
        // The two ponds stacked against the centre block are placed off the
        // table's real height, not a fraction of it — see [_verticalPondAlign].
        final height = constraints.maxHeight;
        return Stack(
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
                      const Expanded(child: SizedBox()),
                      _sideOpponent(round, 1, isLeft: false),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _portrait(0, size: 55),
                      const SizedBox(width: 8),
                      _placard(round, 0),
                    ],
                  ),
                ),
              ],
            ),

            // The four discard ponds, bracketing the centre so they form a
            // square. The turned side ponds run out horizontally and keep their
            // fractional placement; the two stacked against the centre block are
            // pinned a fixed distance from it.
            Align(
              alignment: Alignment(0, _verticalPondAlign(height, above: true)),
              child: _pond(round, 2, quarterTurns: 2),
            ),
            Align(
              alignment: const Alignment(-0.52, -0.04),
              child: _pond(round, 3, quarterTurns: 1),
            ),
            Align(
              alignment: const Alignment(0.52, -0.04),
              child: _pond(round, 1, quarterTurns: 3),
            ),
            Align(
              alignment: Alignment(0, _verticalPondAlign(height, above: false)),
              child: _pond(round, 0, quarterTurns: 0),
            ),

            // Round / honba / riichi / wall — dead centre of the pond square.
            Align(alignment: Alignment.center, child: _statusBox(round)),

            // Dead wall — top-right corner.
            Positioned(top: 0, right: 0, child: _deadWall(round)),
          ],
        );
      }),
    );
  }

  /// The central status block: one stat per line, expansive green box. The round
  /// (with kanji) is largest, the wall counter second largest.
  Widget _statusBox(Round round) {
    Widget line(String t, double size, FontWeight weight) => Text(
          t,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xe61f3a1c),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x66e9d58f), width: 1.5),
      ),
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
          line('Honba ${game.honba}  ·  Riichi ${round.riichiSticks}', 10,
              FontWeight.w600),
        ],
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
    final scale = _pondScaleFor(seat);
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
                      : _popIn(
                          ValueKey('pond-$seat-${s.pond.length}'),
                          TileFace(
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
            if (s.riichi) _riichiStick(),
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

  /// A one-shot pop-in used for the freshly discarded tile.
  Widget _popIn(Key key, Widget child) {
    return TweenAnimationBuilder<double>(
      key: key,
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      builder: (_, t, c) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.55 + 0.45 * t, child: c),
      ),
      child: child,
    );
  }

  Widget _meldGroup(SeatState s) {
    final group = Wrap(
      spacing: 4,
      runSpacing: 2,
      children: [
        for (final m in s.melds)
          MeldRow(m, size: TileSize.small, scale: _pondScale)
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
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _portrait(seat, size: 49, tooltip: kSeatNames[seat]),
            const SizedBox(width: 6),
            _placard(round, seat),
          ],
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
        _portrait(seat, size: 44, tooltip: kSeatNames[seat]),
        const SizedBox(height: 4),
        RotatedBox(
          quarterTurns: isLeft ? 3 : 1,
          child: _placard(round, seat),
        ),
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
                  ? [placard, const SizedBox(width: 6), Flexible(child: inside)]
                  : [
                      Flexible(child: inside),
                      const SizedBox(width: 6),
                      placard
                    ],
            ),
          ),
        ],
      ),
    );
  }

  /// Portrait asset per seat: 0 Orderic (you), 1 Grant, 2 Hubert, 3 Astaroth.
  static const List<String> _seatPortrait = [
    'assets/orderic/orderic.png',
    'assets/grant/grant.png',
    'assets/hubert/hubert.png',
    'assets/astaroth/astaroth.png',
  ];

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
        _seatPortrait[seat],
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
    return tooltip == null ? avatar : Tooltip(message: tooltip, child: avatar);
  }

  /// Seat placard (wind + score).
  Widget _placard(Round round, int seat) {
    final s = round.seats[seat];
    final active = round.turn == seat &&
        !round.finished &&
        round.phase != RoundPhase.callOffer;
    final label =
        '${s.wind.kanji}${seat == 0 ? ' Orderic (you)' : ''}  ${s.points}${s.riichi ? '  ◉' : ''}';
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
    // The human seat gets a FURITEN badge beside its placard while tenpai but
    // barred from ron. Only seat 0's placard renders unrotated, so keep it here.
    if (seat == kHumanSeat && game.humanFuriten) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [placard, const SizedBox(width: 6), _furitenBadge()],
      );
    }
    return placard;
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
