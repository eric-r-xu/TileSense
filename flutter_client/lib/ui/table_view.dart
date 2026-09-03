import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../logic/meld.dart';
import '../logic/round.dart';
import '../logic/tile.dart';
import 'tile_face.dart';

/// The flat 2D table, laid out with absolute [Align] placement to follow the
/// Vala `GameRenderView2D` arrangement: a small dead wall in the top-right, the
/// across player's hand and (180°-flipped) pond up top, the two side players
/// turned ±90° with their placards pulled down toward the middle of the edge,
/// the round / honba / riichi line and wall counter dead centre, and the
/// human's own pond just below it.
class TableView extends StatelessWidget {
  const TableView({super.key, required this.game});
  final GameController game;

  @override
  Widget build(BuildContext context) {
    final round = game.round;
    // Seat mapping from the human's perspective: 0 self, 1 right, 2 across, 3 left.
    return Container(
      color: const Color(0xff063a3a),
      child: Stack(
        children: [
          // Dead wall: top-right corner, tiles at ~75% size.
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 6, 8, 0),
              child: _deadWall(round),
            ),
          ),

          // Across player (seat 2): placard + concealed hand along the top.
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _placard(round, 2),
                  const SizedBox(height: 3),
                  _backsRow(round.seats[2].hand.length),
                ],
              ),
            ),
          ),
          // Across pond, flipped 180° so its tiles face that player.
          Align(
            alignment: const Alignment(0, -0.34),
            child: _pondBlock(round, 2, quarterTurns: 2),
          ),

          // Left player (seat 3): concealed hand up the left edge, placard
          // pulled down toward the middle, pond turned -90°.
          Align(
            alignment: const Alignment(-1, -0.30),
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _backsColumn(round.seats[3].hand.length),
            ),
          ),
          Align(
            alignment: const Alignment(-1, 0.42),
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: RotatedBox(quarterTurns: 3, child: _placard(round, 3)),
            ),
          ),
          Align(
            alignment: const Alignment(-0.86, 0.05),
            child: _pondBlock(round, 3, quarterTurns: 3),
          ),

          // Right player (seat 1): mirror of the left.
          Align(
            alignment: const Alignment(1, -0.30),
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _backsColumn(round.seats[1].hand.length),
            ),
          ),
          Align(
            alignment: const Alignment(1, 0.42),
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: RotatedBox(quarterTurns: 1, child: _placard(round, 1)),
            ),
          ),
          Align(
            alignment: const Alignment(0.86, 0.05),
            child: _pondBlock(round, 1, quarterTurns: 1),
          ),

          // Round / honba / riichi and the wall counter, dead centre.
          Align(alignment: const Alignment(0, -0.02), child: _centerInfo(round)),

          // The human's own pond, just below the centre.
          Align(
            alignment: const Alignment(0, 0.42),
            child: _pondBlock(round, 0, quarterTurns: 0),
          ),
        ],
      ),
    );
  }

  Widget _centerInfo(Round round) {
    Widget pill(String text, double size, FontWeight weight) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0x7a01201f),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0x33e9d58f)),
          ),
          child: Text(text,
              style: TextStyle(
                  color: const Color(0xffe9d58f),
                  fontSize: size,
                  fontWeight: weight)),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        pill(
          '${round.roundWind.label} ${game.roundNumber + 1}   ·   '
          'Honba ${game.honba}   ·   Riichi ${round.riichiSticks}',
          13,
          FontWeight.w600,
        ),
        const SizedBox(height: 4),
        pill('Wall ${round.wall.remaining}', 16, FontWeight.w700),
      ],
    );
  }

  /// The 14-tile dead wall: seven columns, two rows, at ~75% tile size. The
  /// upper row carries the revealed dora indicators; the rest stay face down.
  Widget _deadWall(Round round) {
    final tiles = round.wall.deadWallDisplay();
    List<Widget> row(bool top) => [
          for (var col = 0; col < 7; col++)
            Padding(
              padding: const EdgeInsets.all(0.5),
              child: TileFace(
                tile: tiles[col * 2 + (top ? 0 : 1)],
                faceDown: tiles[col * 2 + (top ? 0 : 1)] == null,
                size: TileSize.tiny,
              ),
            ),
        ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Padding(
          padding: EdgeInsets.only(right: 3),
          child: Text('DORA',
              style: TextStyle(color: Colors.white54, fontSize: 9)),
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

  Widget _backsRow(int n) => FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < n; i++)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 0.5),
                child: TileFace(faceDown: true, size: TileSize.small),
              ),
          ],
        ),
      );

  Widget _backsColumn(int n) => FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < n.clamp(0, 13); i++)
              const Padding(
                padding: EdgeInsets.all(0.5),
                child: TileFace(faceDown: true, size: TileSize.tiny),
              ),
          ],
        ),
      );

  /// A player's pond plus, on their relative-right, their open melds.
  Widget _pondBlock(Round round, int seat, {required int quarterTurns}) {
    final s = round.seats[seat];
    final pond = _pondGrid(round, seat, quarterTurns: quarterTurns);
    if (s.melds.isEmpty) return pond;
    final melds = RotatedBox(
      quarterTurns: quarterTurns,
      child: FittedBox(fit: BoxFit.scaleDown, child: _melds(s)),
    );
    // Lay the melds after the pond along the pond's own axis.
    final children = quarterTurns == 0 || quarterTurns == 2
        ? <Widget>[pond, const SizedBox(width: 8), melds]
        : <Widget>[pond, const SizedBox(height: 8), melds];
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: (quarterTurns == 0 || quarterTurns == 2)
          ? Row(mainAxisSize: MainAxisSize.min, children: children)
          : Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  /// One player's discard pond: six tiles on rows one and two, then the rest on
  /// row three. The riichi declaration tile gets one quarter-turn; a riichi
  /// stick shows on the centre-facing edge. [quarterTurns] rotates the pond.
  Widget _pondGrid(Round round, int seat, {int quarterTurns = 0}) {
    final s = round.seats[seat];
    if (s.pond.isEmpty && !s.riichi) return const SizedBox.shrink();

    final n = s.pond.length;
    final bounds = <List<int>>[];
    if (n > 0) {
      bounds.add([0, n < 6 ? n : 6]);
      if (n > 6) bounds.add([6, n < 12 ? n : 12]);
      if (n > 12) bounds.add([12, n]);
    }

    Widget tileAt(int i) => Padding(
          padding: const EdgeInsets.all(0.5),
          child: TileFace(
            tile: s.pond[i],
            size: TileSize.small,
            rotationQuarterTurns: i == s.riichiPondIndex ? 1 : 0,
          ),
        );

    final grid = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (s.riichi) _riichiStick(),
        for (final b in bounds)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [for (var i = b[0]; i < b[1]; i++) tileAt(i)],
          ),
      ],
    );
    return quarterTurns == 0
        ? grid
        : RotatedBox(quarterTurns: quarterTurns, child: grid);
  }

  /// The 1000-point riichi declaration stick: a pale bar with a single red pip.
  Widget _riichiStick() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      width: 66,
      height: 10,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xfff4f1e6),
        border: Border.all(color: Colors.black87, width: 0.5),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
            color: Color(0xffcc1111), shape: BoxShape.circle),
      ),
    );
  }

  Widget _melds(SeatState s) {
    return Wrap(
      spacing: 6,
      runSpacing: 2,
      children: [for (final m in s.melds) _meld(m)],
    );
  }

  /// A single called set. A concealed kan shows only its two end tiles face
  /// down; an open set turns the called tile sideways and slots it toward the
  /// seat it came from.
  Widget _meld(Meld m) {
    final concealedKan = m.kind == MeldKind.kan && m.concealed;
    if (m.tiles.length < 3) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < m.types.length; i++)
            TileFace(
              type: m.types[i],
              faceDown: concealedKan && (i == 0 || i == m.types.length - 1),
              size: TileSize.tiny,
            ),
        ],
      );
    }

    final need = m.kind == MeldKind.kan ? 3 : 2;
    final Tile? called =
        (!m.concealed && m.tiles.length > need) ? m.tiles.last : null;
    final ordered = <Tile>[
      for (final t in m.tiles)
        if (!identical(t, called)) t,
    ];
    if (called != null) {
      final offset = m.calledFromSeatOffset ?? 1;
      final slot = offset == 3 ? 0 : (offset == 2 ? 1 : ordered.length);
      ordered.insert(slot.clamp(0, ordered.length), called);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < ordered.length; i++)
          TileFace(
            tile: ordered[i],
            faceDown: concealedKan && (i == 0 || i == ordered.length - 1),
            size: TileSize.tiny,
            rotationQuarterTurns: identical(ordered[i], called) ? 1 : 0,
          ),
      ],
    );
  }

  Widget _placard(Round round, int seat) {
    final s = round.seats[seat];
    final active = round.turn == seat &&
        !round.finished &&
        round.phase != RoundPhase.callOffer;
    final label =
        '${s.wind.kanji}${seat == 0 ? ' You' : ''}  ${s.points}${s.riichi ? '  ◉' : ''}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: active ? const Color(0xffcaa24e) : const Color(0xff0c4747),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: active ? Colors.black : Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
