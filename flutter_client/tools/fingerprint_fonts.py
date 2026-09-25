#!/usr/bin/env python3
"""Give every font in a Flutter web build a content-hashed filename.

`flutter build web` tree-shakes the icon fonts (MaterialIcons, CupertinoIcons,
Font Awesome) down to the glyphs the app uses, so each build ships a different
font under the same URL. The host caches fonts for a day, so a browser that
already has yesterday's subset keeps it, and an icon added since draws as
nothing. Renaming each font to include its hash, and pointing
FontManifest.json (served no-cache) at the new name, gives a changed font a
new URL while an unchanged one keeps its cache hit.
"""
import hashlib
import json
from pathlib import Path
import sys


def fingerprint(root: Path) -> int:
    assets = root / 'assets'
    manifest_path = assets / 'FontManifest.json'
    manifest = json.loads(manifest_path.read_text())
    renamed = 0
    for family in manifest:
        for font in family['fonts']:
            src = assets / font['asset']
            digest = hashlib.sha256(src.read_bytes()).hexdigest()[:10]
            if src.stem.endswith('.' + digest):
                continue  # already fingerprinted by an earlier run
            dst = src.with_name(f'{src.stem}.{digest}{src.suffix}')
            src.rename(dst)
            font['asset'] = str(Path(font['asset']).with_name(dst.name))
            renamed += 1
    manifest_path.write_text(json.dumps(manifest, separators=(',', ':')))
    return renamed


if __name__ == '__main__':
    root = Path(sys.argv[1] if len(sys.argv) > 1 else 'build/web')
    if not (root / 'assets' / 'FontManifest.json').is_file():
        raise SystemExit(f'No Flutter web build at {root}')
    print(f'Fingerprinted {fingerprint(root)} font(s)')
