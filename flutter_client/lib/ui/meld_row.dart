import 'package:flutter/material.dart';

import 'package:mahjong_core/meld.dart';
import 'package:mahjong_core/tile.dart';
import 'tile_face.dart';

/// One called set, rendered with real riichi notation: the called tile is
/// turned 90° and slotted at the end matching the seat it came from
/// (kamicha = left, toimen = middle, shimocha = right). An added kan's 4th
/// tile lies sideways on top of the called one. A concealed kan shows
/// its two outer tiles face down — or all four when [faceDown], as another
/// seat sees one under Taiwanese rules.
class MeldRow extends StatelessWidget {
  const MeldRow(this.meld,
      {super.key,
      this.size = TileSize.normal,
      this.scale = 1.0,
      this.faceDown = false,
      this.mirrored = false});
  final Meld meld;
  final TileSize size;
  final double scale;
  final bool faceDown;

  /// The row is drawn upright for a seat that faces the viewer (the across
  /// seat), where the owner's left is the viewer's right. Side seats get this
  /// for free by being turned a quarter, so only the across seat sets it.
  final bool mirrored;

  @override
  Widget build(BuildContext context) {
    final m = meld;
    final concealedKan = m.kind == MeldKind.kan && m.concealed;

    if (m.tiles.length < 3) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < m.types.length; i++)
            TileFace(
              type: m.types[i],
              size: size,
              scale: scale,
              faceDown: faceDown ||
                  concealedKan && (i == 0 || i == m.types.length - 1),
            ),
        ],
      );
    }
    if (concealedKan) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < m.tiles.length; i++)
            TileFace(
              tile: m.tiles[i],
              size: size,
              scale: scale,
              faceDown: faceDown || i == 0 || i == m.tiles.length - 1,
            ),
        ],
      );
    }

    // An added kan's 4th tile came from this seat's own hand, not a call —
    // so the *called* tile to rotate is still the pon's original 3rd tile
    // (index 2), matching a plain pon's "need" rather than a kan's.
    final need = m.kind == MeldKind.kan && !m.addedKan ? 3 : 2;
    final Tile? called = m.tiles.length > need ? m.tiles[need] : null;
    // An added kan's 4th tile (last) lies sideways on top of the called one.
    final Tile? added = m.kind == MeldKind.kan && m.addedKan && called != null
        ? m.tiles.last
        : null;
    final rest = [
      for (final t in m.tiles)
        if (!identical(t, called) && !identical(t, added)) t,
    ];
    final off = m.calledFromSeatOffset ?? 1;
    final fromLeft = mirrored ? off == 1 : off == 3;
    final fromRight = mirrored ? off == 3 : off == 1;
    final slot = fromLeft ? 0 : (fromRight ? rest.length : 1);
    final ordered = <Tile?>[...rest];
    if (called != null) ordered.insert(slot.clamp(0, ordered.length), called);
    Widget face(Tile? t) => TileFace(
          tile: t,
          size: size,
          scale: scale,
          rotationQuarterTurns: identical(t, called) ? 1 : 0,
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final t in ordered)
          if (identical(t, called) && added != null)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TileFace(
                  tile: added,
                  size: size,
                  scale: scale,
                  rotationQuarterTurns: 1,
                ),
                face(t),
              ],
            )
          else
            face(t),
      ],
    );
  }
}
