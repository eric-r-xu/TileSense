import 'package:flutter/material.dart';

import '../logic/tile.dart';

/// A single mahjong tile face: the tile artwork on a cream tile, with a small
/// red index in the top-right corner (number for suits, letter for honours), as
/// in the Vala 2D renderer. `null` [tile] with [faceDown] renders a back.
///
/// The artwork is a bundled PNG per [TileType] (`assets/tiles/<name>.png`, tinted
/// black or aka-red via [Image.color]/`BlendMode.srcIn`), not a Unicode glyph
/// drawn with [Text]. Rendering mahjong tiles as text depends on the browser
/// having (and having already *loaded*) a font covering the Unicode Mahjong
/// Tiles block — unreliable enough on mobile browsers (missing on stock
/// Android fonts; a race against web font loading even once bundled) that
/// tiles could render blank. A raster image has no such dependency.
class TileFace extends StatelessWidget {
  const TileFace({
    super.key,
    this.tile,
    this.type,
    this.faceDown = false,
    this.size = TileSize.normal,
    this.highlight = false,
    this.highlightColor,
    this.borderColorOverride,
    this.dimmed = false,
    this.rotationQuarterTurns = 0,
    this.showIndex = true,
  });

  final Tile? tile;
  final TileType? type;
  final bool faceDown;
  final TileSize size;
  final bool highlight;

  /// When set, tints the face and draws a thick border in this colour — used to
  /// mark a top discard choice (green).
  final Color? highlightColor;

  /// Overrides just the border colour (e.g. a yellow border on a green-tinted
  /// tile that is both the drawn tile and a top choice).
  final Color? borderColorOverride;
  final bool dimmed;
  final int rotationQuarterTurns;
  final bool showIndex;

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
      final hc = highlightColor;
      face = Container(
        width: dims.$1,
        height: dims.$2,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: hc != null
              ? Color.alphaBlend(
                  hc.withValues(alpha: 0.22), const Color(0xffeae7d7))
              : highlight
                  ? const Color(0xfffff6d8)
                  : const Color(0xffeae7d7),
          border: Border.all(
            color: borderColorOverride ??
                hc ??
                (highlight
                    ? const Color(0xffd39e2e)
                    : const Color(0xff403d35)),
            width: (borderColorOverride != null || hc != null)
                ? 3
                : (highlight ? 2 : 1),
          ),
          borderRadius: BorderRadius.circular(dims.$1 * 0.14),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Padding(
                // Leaves a small margin so the artwork doesn't touch the tile's
                // own border; BoxFit.contain fills the rest, matching the
                // ~85-90%-of-the-face sizing the old oversized-glyph text had.
                padding: EdgeInsets.symmetric(
                  horizontal: dims.$1 * 0.08,
                  vertical: dims.$2 * 0.05,
                ),
                child: Image.asset(
                  'assets/tiles/${t.name}.png',
                  fit: BoxFit.contain,
                  color: _aka ? const Color(0xffc62828) : Colors.black87,
                  colorBlendMode: BlendMode.srcIn,
                  filterQuality: FilterQuality.high,
                  // Should never trigger — kept as a last-resort fallback so a
                  // missing/corrupt asset still shows *something* readable
                  // rather than a blank tile.
                  errorBuilder: (_, __, ___) => Text(
                    t.code,
                    style: TextStyle(
                      fontSize: dims.$2 * 0.42,
                      fontWeight: FontWeight.bold,
                      color: _aka ? const Color(0xffc62828) : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
            if (showIndex)
              Positioned(
                top: dims.$2 * 0.03,
                right: dims.$1 * 0.08,
                child: Text(
                  t.redIndex,
                  style: TextStyle(
                    fontSize: (dims.$2 * 0.30).clamp(6.5, 15.0),
                    height: 1.0,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xffd90000),
                  ),
                ),
              ),
          ],
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
