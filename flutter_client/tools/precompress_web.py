#!/usr/bin/env python3
"""Create deterministic gzip sidecars for Nginx gzip_static after a web build."""
import gzip
from pathlib import Path
import sys


def precompress(root: Path) -> tuple[int, int]:
    original = compressed = 0
    for path in root.rglob('*'):
        if path.suffix not in {'.js', '.wasm', '.json', '.css', '.html', '.svg'}:
            continue
        data = path.read_bytes()
        if len(data) < 1024:
            continue
        packed = gzip.compress(data, compresslevel=9, mtime=0)
        if len(packed) >= len(data):
            continue
        path.with_name(path.name + '.gz').write_bytes(packed)
        original += len(data)
        compressed += len(packed)
    return original, compressed


if __name__ == '__main__':
    root = Path(sys.argv[1] if len(sys.argv) > 1 else 'build/web')
    if not (root / 'main.dart.js').is_file():
        raise SystemExit(f'No Flutter web build at {root}')
    before, after = precompress(root)
    print(f'Web gzip sidecars: {before:,} -> {after:,} bytes')
