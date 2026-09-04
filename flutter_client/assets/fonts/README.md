# Font (build-time input only — not bundled into the app)

## MahjongTiles-Regular.ttf

A subset of **Noto Sans Symbols 2** (SIL Open Font License 1.1, see `OFL.txt`)
containing only the Unicode *Mahjong Tiles* block (`U+1F000`–`U+1F02F`).

This file is **not** listed in `pubspec.yaml` and ships with nothing — it only
exists as the source `tools/render_tiles.py` rasterizes from to produce
`assets/tiles/*.png`, which is what `lib/ui/tile_face.dart` actually draws.

Tile faces used to be drawn directly as these Unicode glyphs via `Text`. That
depended on the browser having — and having already *loaded* — a font
covering the block: stock Android fonts don't have it at all (so Chrome for
Android fell back to a slow/unreliable runtime Noto download), and even after
bundling this font directly, web font loading is asynchronous enough relative
to first paint that tiles could still render blank. Rasterizing once, at build
time, and shipping plain PNGs removes that dependency entirely — see
`tools/render_tiles.py`'s module docstring for the full rationale and the
outline-stripping it does before saving each tile.

### Regenerating this font (only needed if swapping the source font/subset)

```sh
pip install fonttools brotli
curl -fsSL -o NotoSansSymbols2-Regular.ttf \
  https://github.com/googlefonts/noto-fonts/raw/main/unhinted/ttf/NotoSansSymbols2/NotoSansSymbols2-Regular.ttf
pyftsubset NotoSansSymbols2-Regular.ttf \
  --unicodes=U+1F000-1F02F \
  --output-file=MahjongTiles-Regular.ttf \
  --layout-features='' --no-hinting --desubroutinize \
  --name-IDs='' --notdef-outline --drop-tables+=DSIG
```

Then re-run `python3 tools/render_tiles.py` (from `flutter_client/`) to
regenerate `assets/tiles/*.png` from it.
