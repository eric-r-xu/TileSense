import 'dart:async';

import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../logic/round.dart';
import 'meld_row.dart';
import 'tile_face.dart';

/// The flat 2D table. Each seat's placard hugs its own edge with the concealed
/// hand just inside it (the freshly drawn tile split out so its position reads);
/// the four discard ponds bracket the centre on a fixed six-column grid whose
/// origin never moves as it fills; the round/wall status sits dead centre and
/// the dead wall in the top-right corner — the Vala `GameRenderView2D` layout.
class TableView extends StatelessWidget {
  const TableView({super.key, required this.game});
  final GameController game;

  static const int _pondCols = 6;
  // normal tile (32w / 44h) + EdgeInsets.all(0.5) on both sides.
  static const double _pondTileW = 33;
  static const double _pondTileH = 45;
  // Fixed footprint: one riichi stick + four full rows. Anchored top-left so
  // earlier tiles stay put as later rows come in.
  static const double _pondBoxW = _pondCols * _pondTileW + 16; // room for a turned tile
  static const double _pondBoxH = 16 + 4 * _pondTileH;

  @override
  Widget build(BuildContext context) {
    final round = game.round;
    // Seat mapping from the human's perspective: 0 self, 1 right, 2 across, 3 left.
    return Container(
      color: const Color(0xff063a3a),
      padding: const EdgeInsets.all(8),
      child: Stack(
        children: [
          Column(
            children: [
              _opponentRow(round, 2),
              const SizedBox(height: 4),
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
              const SizedBox(height: 4),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ordericAvatar(),
                    const SizedBox(width: 8),
                    _placard(round, 0),
                  ],
                ),
              ),
            ],
          ),

          // The four discard ponds, bracketing the centre so they form a square.
          Align(
            alignment: const Alignment(0, -0.76),
            child: _pond(round, 2, quarterTurns: 2),
          ),
          Align(
            alignment: const Alignment(-0.48, -0.04),
            child: _pond(round, 3, quarterTurns: 1),
          ),
          Align(
            alignment: const Alignment(0.48, -0.04),
            child: _pond(round, 1, quarterTurns: 3),
          ),
          Align(
            alignment: const Alignment(0, 0.76),
            child: _pond(round, 0, quarterTurns: 0),
          ),

          // Round / honba / riichi / wall — dead centre of the pond square.
          Align(alignment: Alignment.center, child: _statusBox(round)),

          // Dead wall — top-right corner.
          Positioned(top: 0, right: 0, child: _deadWall(round)),
        ],
      ),
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
            height: 1.25,
          ),
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xe61f3a1c),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x66e9d58f), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          line('${round.roundWind.kanji}  ${round.roundWind.label} ${game.handInWind}',
              17, FontWeight.w800),
          const SizedBox(height: 3),
          line('Wall ${round.wall.remaining}', 13, FontWeight.w700),
          const SizedBox(height: 2),
          line('Honba ${game.honba}  ·  Riichi ${round.riichiSticks}', 11,
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
  /// revealed dora indicators; the rest stay face down.
  Widget _deadWall(Round round) {
    final tiles = round.wall.deadWallDisplay();
    List<Widget> row(bool top) => [
          for (var col = 0; col < 7; col++)
            Padding(
              padding: const EdgeInsets.all(0.5),
              child: TileFace(
                tile: tiles[col * 2 + (top ? 0 : 1)],
                faceDown: tiles[col * 2 + (top ? 0 : 1)] == null,
                size: TileSize.normal,
              ),
            ),
        ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Padding(
          padding: EdgeInsets.only(right: 4),
          child: Text('DORA',
              style: TextStyle(color: Colors.white54, fontSize: 11)),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: row(true)),
            Row(mainAxisSize: MainAxisSize.min, children: row(false)),
          ],
        ),
      ],
    );
  }

  /// One player's discard pond in a fixed-size box (six columns, four rows),
  /// content anchored top-left so every tile keeps its slot as the pond fills.
  /// The newest tile pops in so you can see it land.
  Widget _pond(Round round, int seat, {required int quarterTurns}) {
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
                            rotationQuarterTurns:
                                i == s.riichiPondIndex ? 1 : 0,
                          ),
                        )
                      : _popIn(
                          ValueKey('pond-$seat-${s.pond.length}'),
                          TileFace(
                            tile: s.pond[i],
                            size: TileSize.normal,
                            rotationQuarterTurns:
                                i == s.riichiPondIndex ? 1 : 0,
                          ),
                        ))
                  : TileFace(
                      tile: s.pond[i],
                      size: TileSize.normal,
                      rotationQuarterTurns: i == s.riichiPondIndex ? 1 : 0,
                    ),
            ),
        ],
      ));
    }
    final boxed = SizedBox(
      width: _pondBoxW,
      height: _pondBoxH,
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
    return quarterTurns == 0
        ? boxed
        : RotatedBox(quarterTurns: quarterTurns, child: boxed);
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
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: [for (final m in s.melds) MeldRow(m, size: TileSize.small)],
    );
  }

  /// Across player: placard on top, open melds to the left of the concealed hand.
  Widget _opponentRow(Round round, int seat) {
    final s = round.seats[seat];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _placard(round, seat),
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
    final placard = RotatedBox(
      quarterTurns: isLeft ? 3 : 1,
      child: _placard(round, seat),
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
                  : [Flexible(child: inside), const SizedBox(width: 6), placard],
            ),
          ),
        ],
      ),
    );
  }

  /// The human player's Orderic portrait, tucked beside the self placard and
  /// sized to sit level with it.
  Widget _ordericAvatar() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xff0c4747),
        border: Border.all(color: const Color(0xffcaa24e), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/orderic/orderic.png',
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      ),
    );
  }

  /// Seat placard (wind + score).
  Widget _placard(Round round, int seat) {
    final s = round.seats[seat];
    final active = round.turn == seat &&
        !round.finished &&
        round.phase != RoundPhase.callOffer;
    final label =
        '${s.wind.kanji}${seat == 0 ? ' Orderic' : ''}  ${s.points}${s.riichi ? '  ◉' : ''}';
    return Container(
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
class _OpponentHand extends StatefulWidget {
  const _OpponentHand({
    required this.game,
    required this.seat,
    required this.vertical,
    this.rotate = 0,
  });

  final GameController game;
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
              faceDown: true, size: TileSize.small, rotationQuarterTurns: rotate),
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

    return widget.vertical
        ? Column(mainAxisSize: MainAxisSize.min, children: tiles)
        : Row(mainAxisSize: MainAxisSize.min, children: tiles);
  }
}
