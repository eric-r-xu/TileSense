import 'package:flutter/material.dart';

import '../logic/tile.dart';

/// A single mahjong tile face. Uses the Unicode mahjong glyph on a cream tile;
/// a red index for aka fives. `null` [tile] with [faceDown] renders a back.
class TileFace extends StatelessWidget {
  const TileFace({
    super.key,
    this.tile,
    this.type,
    this.faceDown = false,
    this.size = TileSize.normal,
    this.highlight = false,
    this.dimmed = false,
    this.rotationQuarterTurns = 0,
  });

  final Tile? tile;
  final TileType? type;
  final bool faceDown;
  final TileSize size;
  final bool highlight;
  final bool dimmed;
  final int rotationQuarterTurns;

  TileType? get _type => tile?.type ?? type;
  bool get _aka => tile?.aka ?? false;

  @override
  Widget build(BuildContext context) {
    final dims = _dims(size);
    final Widget face;
    if (faceDown || _type == null) {
      face = Container(
        width: dims.$1,
        height: dims.$2,
        decoration: BoxDecoration(
          color: const Color(0xff1f7a86),
          border: Border.all(color: const Color(0xff0b3b41)),
          borderRadius: BorderRadius.circular(dims.$1 * 0.14),
        ),
      );
    } else {
      final t = _type!;
      face = Container(
        width: dims.$1,
        height: dims.$2,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: highlight ? const Color(0xfffff6d8) : const Color(0xffeae7d7),
          border: Border.all(
            color: highlight ? const Color(0xffd39e2e) : const Color(0xff403d35),
            width: highlight ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(dims.$1 * 0.14),
        ),
        child: Text(
          t.glyph,
          style: TextStyle(
            fontSize: dims.$3,
            height: 1.0,
            color: _aka ? const Color(0xffc62828) : Colors.black87,
          ),
        ),
      );
    }

    Widget result = face;
    if (rotationQuarterTurns != 0) {
      result = RotatedBox(quarterTurns: rotationQuarterTurns, child: result);
    }
    if (dimmed) {
      result = Opacity(opacity: 0.45, child: result);
    }
    return result;
  }

  (double, double, double) _dims(TileSize s) {
    switch (s) {
      case TileSize.tiny:
        return (15, 21, 15);
      case TileSize.small:
        return (22, 30, 21);
      case TileSize.normal:
        return (32, 44, 30);
      case TileSize.large:
        return (42, 58, 40);
    }
  }
}

enum TileSize { tiny, small, normal, large }
