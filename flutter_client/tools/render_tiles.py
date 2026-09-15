"""Rasterize each mahjong tile-face into a transparent PNG under assets/tiles/.

`TileFace` (lib/ui/tile_face.dart) draws tile artwork from these images rather
than a Unicode Mahjong Tiles glyph via Text. Rendering the glyph as text made
tiles depend on the browser having - and having already *loaded* - a font
covering that Unicode block: missing entirely on stock Android fonts, and
still a race against web font loading even once one was bundled, so tiles
could render blank (seen in practice on Chrome for Android, never on Safari).
A raster image sidesteps that class of bug outright.

Source: assets/fonts/MahjongTiles-Regular.ttf, a Noto Sans Symbols 2 subset
covering the Mahjong Tiles block (see assets/fonts/README.md) - kept only as
input to this script, not bundled into the app itself. The Noto glyphs are
complete standalone tile pictograms, each with its own rounded-rect outline;
TileFace already draws its own tile background and (colour-coded) border, so
this strips that outline - detected as the largest connected ink component -
and keeps only the inner numeral/kanji/pip artwork.

Run once (`python3 tools/render_tiles.py`) after regenerating the font, or if
these need to change; commit the resulting PNGs like any other asset.

Requires: pillow, numpy, scipy (`pip install pillow numpy scipy`) - dev-time
only, not a project dependency.
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT_PATH = os.path.join(ROOT, "assets", "fonts", "MahjongTiles-Regular.ttf")
OUT_DIR = os.path.join(ROOT, "assets", "tiles")

# TileType order (index 1..34), matching lib/logic/tile.dart's TileType enum.
NAMES = (
    "man1 man2 man3 man4 man5 man6 man7 man8 man9 "
    "pin1 pin2 pin3 pin4 pin5 pin6 pin7 pin8 pin9 "
    "sou1 sou2 sou3 sou4 sou5 sou6 sou7 sou8 sou9 "
    "ton nan shaa pei "
    "haku hatsu chun"
).split()

GLYPHS = (
    "\U0001F007 \U0001F008 \U0001F009 \U0001F00A \U0001F00B \U0001F00C \U0001F00D \U0001F00E \U0001F00F "
    "\U0001F019 \U0001F01A \U0001F01B \U0001F01C \U0001F01D \U0001F01E \U0001F01F \U0001F020 \U0001F021 "
    "\U0001F010 \U0001F011 \U0001F012 \U0001F013 \U0001F014 \U0001F015 \U0001F016 \U0001F017 \U0001F018 "
    "\U0001F000 \U0001F001 \U0001F002 \U0001F003 "
    "\U0001F006 \U0001F005 \U0001F004"
).split()

assert len(NAMES) == 34 == len(GLYPHS)

# Hong Kong flowers and seasons, in TileType order (plum..winter). Unicode puts
# bamboo (U+1F024) before chrysanthemum (U+1F025); the app numbers them the
# other way round, as the tiles themselves do: plum 1, orchid 2, chrysanthemum
# 3, bamboo 4. Each also gets a `-k` cut-out holding just its Chinese
# character, so TileFace can ink the character apart from the picture.
BONUS_NAMES = "plum orchid chrysanthemum bamboo spring summer autumn winter".split()
BONUS_GLYPHS = (
    "\U0001F022 \U0001F023 \U0001F025 \U0001F024 "
    "\U0001F026 \U0001F027 \U0001F028 \U0001F029"
).split()

assert len(BONUS_NAMES) == 8 == len(BONUS_GLYPHS)

CANVAS = (480, 640)  # portrait, roughly the tile face's aspect ratio
FONT_SIZE = 560
PAD = 14  # ink-bbox margin kept around each cropped tile


def render_one(name: str, glyph: str, font: ImageFont.FreeTypeFont,
               character_layer: bool = False) -> None:
    img = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.text((CANVAS[0] / 2, CANVAS[1] / 2), glyph, font=font,
               fill=(0, 0, 0, 255), anchor="mm")

    alpha = np.array(img.getchannel("A"))
    mask = alpha > 40

    # Bridge any 1px anti-aliasing gaps so the whole rounded-rect outline is
    # one connected component before labelling.
    dilated = ndimage.binary_dilation(mask, iterations=2)
    labelled, n = ndimage.label(dilated, structure=np.ones((3, 3)))
    if n == 0:
        raise RuntimeError(f"{name}: glyph rendered empty - missing from font?")

    # The outline is the component with the largest bounding-box footprint;
    # the numeral/kanji/pip strokes sit well inside it. (haku/white-dragon's
    # tile is legitimately just a nested double frame with no inner mark -
    # stripping only the outermost one is correct there too.)
    best_label, best_area = None, -1
    for lbl in range(1, n + 1):
        ys, xs = np.where(labelled == lbl)
        area = (ys.max() - ys.min() + 1) * (xs.max() - xs.min() + 1)
        if area > best_area:
            best_label, best_area = lbl, area

    keep = mask & (labelled != best_label)

    # The character sits in the face's top-left corner, clear of the picture:
    # every kept component whose centre lies there belongs to it.
    character = np.zeros_like(keep)
    if character_layer:
        ys0, xs0 = np.where(labelled == best_label)
        top0, left0 = ys0.min(), xs0.min()
        height0, width0 = ys0.max() - top0, xs0.max() - left0
        for lbl in range(1, n + 1):
            if lbl == best_label:
                continue
            ys, xs = np.where(labelled == lbl)
            cy = (ys.mean() - top0) / height0
            cx = (xs.mean() - left0) / width0
            if cy < 0.32 and cx < 0.48:
                character |= labelled == lbl
        character &= mask
    out = np.zeros((*CANVAS[::-1], 4), dtype=np.uint8)
    # Keep the original (anti-aliased) alpha on the pixels we keep, rather
    # than flattening to solid black, so stroke edges stay smooth.
    out[keep, 3] = alpha[keep]

    result = Image.fromarray(out, "RGBA")
    bbox = result.getbbox()
    if bbox is None:
        raise RuntimeError(
            f"{name}: nothing left after stripping the outline - the "
            f"largest-bbox heuristic picked the wrong component"
        )
    left, top, right, bottom = bbox
    left = max(0, left - PAD)
    top = max(0, top - PAD)
    right = min(CANVAS[0], right + PAD)
    bottom = min(CANVAS[1], bottom + PAD)
    result.crop((left, top, right, bottom)).save(
        os.path.join(OUT_DIR, f"{name}.png")
    )
    if character_layer:
        layer = np.zeros_like(out)
        layer[character, 3] = alpha[character]
        # Same canvas, same crop box, so it registers with the base face.
        Image.fromarray(layer, "RGBA").crop((left, top, right, bottom)).save(
            os.path.join(OUT_DIR, f"{name}-k.png")
        )


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    font = ImageFont.truetype(FONT_PATH, FONT_SIZE)
    for name, glyph in zip(NAMES, GLYPHS):
        render_one(name, glyph, font)
    for name, glyph in zip(BONUS_NAMES, BONUS_GLYPHS):
        render_one(name, glyph, font, character_layer=True)
    print(f"Wrote {len(NAMES) + len(BONUS_NAMES)} tile images to {OUT_DIR}")


if __name__ == "__main__":
    main()
