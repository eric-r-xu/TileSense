import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:mahjong_core/tile.dart';

/// How much bigger teaching screens draw their tiles on a phone, where the
/// whole canvas is shrunk to about half size: the same factor the canvas grows
/// its text by (1.0 on a desktop, up to 1.35 on a phone), so tiles and the
/// words about them grow together. Read inside the scaled canvas.
double phoneTileBoost(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.35).toDouble();

/// The scale Learn to Play, Practice and the quiz draw [TileSize.large] at:
/// the in-game hand's size, grown for a phone.
double teachingTileScale(BuildContext context) =>
    1.65 * phoneTileBoost(context);

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
    this.hovered = false,
    this.topViewEdge,
    this.topViewDepth = 1.0,
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

  /// True while the pointer is hovering this tile — darkens the face a touch
  /// so a mouse user can see which tile they're over, on top of whatever
  /// [highlightColor] / [highlight] tint is already showing.
  final bool hovered;

  /// Draws a face-down tile as seen from above, the way an opponent's
  /// concealed hand stands on the table: the half toward [topViewEdge] (the
  /// side nearest its owner) is white, the other half the usual back colour.
  /// The edge is in screen terms, so [rotationQuarterTurns] is already
  /// accounted for: the tile is turned to lie across that axis, not rotated.
  final AxisDirection? topViewEdge;

  /// How much of the tile's long side a [topViewEdge] tile keeps: a tile seen
  /// from above is as wide as it is, but only as deep as the tile is thick.
  final double topViewDepth;

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
  static const Color _backColor = Color(0xff1f7a86);
  static const Color _topViewWhite = Color(0xfff7f5ec);
  static const Color _ink = Colors.black87;
  static const Color _red = Color(0xffc62828);
  static const Color _green = Color(0xff1b7a3a);

  /// Hong Kong flowers and seasons: the picture takes the plant's or season's
  /// own colour, and a `-k` layer inks the character over it.
  static const Map<TileType, Color> _bonusTints = {
    TileType.plum: Color(0xffc8285a),
    TileType.orchid: Color(0xff7b3fa0),
    TileType.chrysanthemum: Color(0xffcd8200),
    TileType.bamboo: _green,
    TileType.spring: _green,
    TileType.summer: Color(0xffd74600),
    TileType.autumn: Color(0xffbe5014),
    TileType.winter: Color(0xff1e64b4),
  };

  Color get _tint {
    if (_aka) return _red;
    final t = _type;
    if (t == null) return _ink;
    if (t.isBonus) return _bonusTints[t]!;
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
    TileType.plum: [('plum-k', _ink)],
    TileType.orchid: [('orchid-k', _ink)],
    TileType.chrysanthemum: [('chrysanthemum-k', _ink)],
    TileType.bamboo: [('bamboo-k', _ink)],
    TileType.spring: [('spring-k', _ink)],
    TileType.summer: [('summer-k', _ink)],
    TileType.autumn: [('autumn-k', _ink)],
    TileType.winter: [('winter-k', _ink)],
  };

  List<(String, Color)> get _tileAccents =>
      _aka ? const [] : (_accents[_type] ?? const []);

  @override
  Widget build(BuildContext context) {
    final dims = _dims(size);
    final Widget face;
    final edge = topViewEdge;
    if ((faceDown || _type == null) && edge != null) {
      // Same footprint as a back, turned on its side when the hand runs
      // vertically; the white half is the one nearest the owner.
      final turned = rotationQuarterTurns.isOdd;
      final depth = dims.$2 * topViewDepth;
      final w = turned ? depth : dims.$1;
      final h = turned ? dims.$1 : depth;
      final horizontalSplit =
          edge == AxisDirection.up || edge == AxisDirection.down;
      final nearFirst = edge == AxisDirection.up || edge == AxisDirection.left;
      const near = Expanded(child: ColoredBox(color: _topViewWhite));
      const far = Expanded(child: ColoredBox(color: _backColor));
      final halves = nearFirst ? const [near, far] : const [far, near];
      Widget result = Container(
        width: w,
        height: h,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xff0b3b41)),
          borderRadius: BorderRadius.circular(dims.$1 * 0.14),
        ),
        // Stretched so each half fills the tile's width (or height): a bare
        // coloured box has no size of its own to centre.
        child: horizontalSplit
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: halves)
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: halves),
      );
      if (dimmed) result = Opacity(opacity: 0.45, child: result);
      return result;
    }
    if (faceDown || _type == null) {
      face = Container(
        width: dims.$1,
        height: dims.$2,
        decoration: BoxDecoration(
          color: _backColor,
          border: Border.all(color: const Color(0xff0b3b41)),
          borderRadius: BorderRadius.circular(dims.$1 * 0.14),
        ),
      );
    } else {
      final t = _type!;
      final hc = highlightColor;
      final baseColor = hc != null
          ? Color.alphaBlend(
              hc.withValues(alpha: 0.22), const Color(0xffeae7d7))
          : highlight
              ? const Color(0xfffff6d8)
              : const Color(0xffeae7d7);
      face = Container(
        width: dims.$1,
        height: dims.$2,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: hovered
              ? Color.alphaBlend(
                  Colors.black.withValues(alpha: 0.14), baseColor)
              : baseColor,
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
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontSize: _indexSize(context, dims.$2),
                    height: 1.0,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xffd90000),
                    // A cream edge keeps the index legible where it crosses
                    // the artwork.
                    shadows: const [
                      Shadow(color: Color(0xfff4f1e6), offset: Offset(1, 0)),
                      Shadow(color: Color(0xfff4f1e6), offset: Offset(-1, 0)),
                      Shadow(color: Color(0xfff4f1e6), offset: Offset(0, 1)),
                      Shadow(color: Color(0xfff4f1e6), offset: Offset(0, -1)),
                    ],
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
          textScaler: TextScaler.noScaling,
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

  /// The red index's size on a tile [height] tall: about a quarter of the
  /// tile, grown with the phone's text boost (it opts out of the text scaler
  /// itself, so it is applied here) but kept within 30% of the tile so it
  /// stays mostly clear of the artwork. Tiny tiles keep a readable floor.
  static double _indexSize(BuildContext context, double height) =>
      (height * 0.27 * phoneTileBoost(context))
          .clamp(6.5, math.max(6.5, height * 0.30))
          .toDouble();

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
