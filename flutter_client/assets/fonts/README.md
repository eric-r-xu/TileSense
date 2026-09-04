# Bundled fonts

## MahjongTiles-Regular.ttf

A subset of **Noto Sans Symbols 2** (SIL Open Font License 1.1, see `OFL.txt`)
containing only the Unicode *Mahjong Tiles* block (`U+1F000`–`U+1F02F`).

The tile faces in `lib/ui/tile_face.dart` are drawn as these Unicode glyphs.
iOS/macOS system fonts cover the block, but stock Android fonts do **not**, so on
Chrome for Android CanvasKit was falling back to a runtime Noto download from
`fonts.gstatic.com` — and every tile rendered blank whenever that fetch was
slow, blocked, or offline. Bundling the glyphs removes that dependency and makes
tiles look identical across browsers.

### Regenerating

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
