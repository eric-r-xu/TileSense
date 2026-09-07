import 'package:flutter/material.dart';

import '../logic/tile.dart';

/// A single mahjong tile face: the tile artwork on a cream tile, with a small
/// red index in the top-right corner (number for suits, letter for honours).
/// `null` [tile] with [faceDown] renders a back.
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
    this.scale = 1.0,
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

  /// Linear multiplier on the tile's footprint (and its artwork / index), on top
  /// of [size]. 1.0 is the authored size; callers bump this to enlarge tiles in
  /// one region without disturbing the shared [TileSize] steps used elsewhere.
  final double scale;

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

  // Traditional face colours, approximating color.png. The artwork is a
  // single-colour PNG tinted via BlendMode.srcIn, so each tile can only be one
  // colour — genuinely two-tone faces (a red 萬 under a black numeral, the
  // green/red/black pin suit) can't be reproduced without new artwork, so those
  // stay near-black. What we *can* match cleanly:
  //   • red fives (aka) and the red dragon  → aka-red
  //   • the green dragon, the whole bamboo (sou) suit, and 1-pin → bamboo-green
  //   • everything else → near-black (unchanged from before)
  static const Color _ink = Colors.black87;
  static const Color _red = Color(0xffc62828);
  static const Color _green = Color(0xff1b7a3a);

  Color get _tint {
    if (_aka) return _red;
    final t = _type;
    if (t == null) return _ink;
    if (t == TileType.chun) return _red;
    if (t == TileType.hatsu || t.isSou || t == TileType.pin1) return _green;
    return _ink;
  }

  /// Extra artwork layers drawn over the base face and tinted (srcIn) with an
  /// accent colour: `(asset-name-without-extension, colour)`. Each accent PNG is
  /// a cut-out of the base PNG covering just the pips / strokes that colour
  /// applies to (generated to match color.png). This is how the genuinely
  /// two-/three-tone faces get made — a single srcIn tint can't split a face.
  /// Suppressed on red fives, which stay uniformly aka-red.
  static const Map<TileType, List<(String, Color)>> _accents = {
    TileType.man1: [('man1-r', _red)],
    TileType.man2: [('man2-r', _red)],
    TileType.man3: [('man3-r', _red)],
    TileType.man4: [('man4-r', _red)],
    TileType.man5: [('man5-r', _red)],
    TileType.man6: [('man6-r', _red)],
    TileType.man7: [('man7-r', _red)],
    TileType.man8: [('man8-r', _red)],
    TileType.man9: [('man9-r', _red)],
    TileType.pin2: [('pin2-g', _green)],
    TileType.pin3: [('pin3-g', _green), ('pin3-r', _red)],
    TileType.pin4: [('pin4-g', _green)],
    TileType.pin6: [('pin6-g', _green), ('pin6-r', _red)],
    TileType.pin7: [('pin7-g', _green), ('pin7-r', _red)],
    TileType.pin9: [('pin9-g', _green), ('pin9-r', _red)],
    TileType.sou1: [('sou1-r', _red)],
    TileType.sou5: [('sou5-r', _red)],
    TileType.sou7: [('sou7-r', _red)],
    TileType.sou9: [('sou9-r', _red)],
  };

  List<(String, Color)> get _tileAccents =>
      _aka ? const [] : (_accents[_type] ?? const []);

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
                (highlight ? const Color(0xffd39e2e) : const Color(0xff403d35)),
            width: (borderColorOverride != null || hc != null)
                ? 3
                : (highlight ? 2 : 1),
          ),
          borderRadius: BorderRadius.circular(dims.$1 * 0.14),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // The base face, then each accent cut-out, every one wrapped in the
            // *same* Center + Padding so it lays out identically — the artwork
            // rect is byte-for-byte what a single un-accented image would get,
            // so recolouring never shifts or resizes a tile.
            //
            // The margin keeps the artwork off the tile's own border;
            // BoxFit.contain fills the rest, matching the ~85-90%-of-the-face
            // sizing the old oversized-glyph text had.
            for (final (name, color, fallback) in _artworkLayers(t, dims))
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: dims.$1 * 0.08,
                    vertical: dims.$2 * 0.05,
                  ),
                  child: Image.asset(
                    'assets/tiles/$name.png',
                    fit: BoxFit.contain,
                    color: color,
                    colorBlendMode: BlendMode.srcIn,
                    filterQuality: FilterQuality.high,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) =>
                        fallback ?? const SizedBox.shrink(),
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
                    fontSize: (dims.$2 * 0.30).clamp(6.5, 15.0 * scale),
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

  /// The artwork layers to stack, in paint order: the base PNG tinted [_tint]
  /// first, then any [_tileAccents] cut-outs in their own colours. Each accent
  /// PNG shares its base PNG's dimensions and is drawn with the identical
  /// [BoxFit.contain] box, so the layers register pixel-for-pixel.
  List<(String, Color, Widget?)> _artworkLayers(
      TileType t, (double, double, double) dims) {
    return [
      (
        t.name,
        _tint,
        // Should never trigger — a last-resort fallback so a missing/corrupt
        // asset still shows something readable rather than a blank tile.
        Text(
          t.code,
          style: TextStyle(
            fontSize: dims.$2 * 0.42,
            fontWeight: FontWeight.bold,
            color: _tint,
          ),
        ),
      ),
      for (final (name, c) in _tileAccents) (name, c, null),
    ];
  }

  (double, double, double) _dims(TileSize s) {
    final (double w, double h, double f) = switch (s) {
      TileSize.tiny => (15, 21, 15),
      TileSize.small => (22, 30, 21),
      TileSize.normal => (32, 44, 30),
      TileSize.large => (46, 64, 44),
    };
    return (w * scale, h * scale, f * scale);
  }
}

enum TileSize { tiny, small, normal, large }
