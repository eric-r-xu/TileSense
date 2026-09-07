import 'package:flutter/material.dart';

import '../logic/meld.dart';
import '../logic/tile.dart';
import 'tile_face.dart';

/// One called set, rendered with real riichi notation: the called tile is
/// turned 90° and slotted at the end matching the seat it came from
/// (kamicha = left, toimen = middle, shimocha = right). A concealed kan shows
/// its two outer tiles face down.
class MeldRow extends StatelessWidget {
  const MeldRow(this.meld, {super.key, this.size = TileSize.normal, this.scale = 1.0});
  final Meld meld;
  final TileSize size;
  final double scale;

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
              faceDown: concealedKan && (i == 0 || i == m.types.length - 1),
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
              faceDown: i == 0 || i == m.tiles.length - 1,
            ),
        ],
      );
    }

    // An added kan's 4th tile came from this seat's own hand, not a call —
    // so the *called* tile to rotate is still the pon's original 3rd tile
    // (index 2), matching a plain pon's "need" rather than a kan's.
    final need = m.kind == MeldKind.kan && !m.addedKan ? 3 : 2;
    final Tile? called = m.tiles.length > need ? m.tiles[need] : null;
    final rest = [
      for (final t in m.tiles)
        if (!identical(t, called)) t,
    ];
    final off = m.calledFromSeatOffset ?? 1;
    final slot = off == 3 ? 0 : (off == 2 ? 1 : rest.length);
    final ordered = <Tile?>[...rest];
    if (called != null) ordered.insert(slot.clamp(0, ordered.length), called);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final t in ordered)
          TileFace(
            tile: t,
            size: size,
            scale: scale,
            rotationQuarterTurns: identical(t, called) ? 1 : 0,
          ),
      ],
    );
  }
}
