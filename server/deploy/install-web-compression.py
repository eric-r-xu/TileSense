#!/usr/bin/env python3
"""Enable compression only in the existing TileSense static-file location.

Run on the web host: python3 install-web-compression.py
Validates before reloading Nginx and restores the config if validation fails.
"""
from pathlib import Path
import re
import subprocess

SETTINGS = '''
        # TileSense startup compression (keep within the static location).
        gzip on;
        gzip_static on;
        gzip_vary on;
        gzip_comp_level 6;
        gzip_min_length 1024;
        gzip_types application/javascript application/wasm application/json text/css image/svg+xml;
'''


def configure(text: str) -> str:
    # This host has other applications and an example vhost. Touch only the
    # production TileSense location; never the WebSocket or ingest routes.
    server = text.index('server_name app.ericrxu.com;')
    start = text.index('location /tilesense/ {', server)
    end = text.index('}', start)
    block = text[start:end]
    if 'TileSense startup compression' in block:
        return text
    if re.search(r'\bgzip\w*\s', block):
        raise ValueError('Existing location compression settings need review')
    insert = start + len('location /tilesense/ {')
    return text[:insert] + SETTINGS + text[insert:]


def main() -> None:
    path = Path('/etc/nginx/sites-enabled/myproject').resolve(strict=True)
    original = path.read_text()
    updated = configure(original)
    if updated == original:
        print('TileSense compression is already configured')
        return
    subprocess.run(['nginx', '-t'], check=True)
    backup = path.with_name(path.name + '.before-tilesense-compression')
    if not backup.exists():
        backup.write_text(original)
    try:
        path.write_text(updated)
        subprocess.run(['nginx', '-t'], check=True)
        subprocess.run(['systemctl', 'reload', 'nginx'], check=True)
    except BaseException:
        path.write_text(original)
        subprocess.run(['nginx', '-t'], check=True)
        subprocess.run(['systemctl', 'reload', 'nginx'], check=True)
        raise
    print('TileSense JavaScript/WebAssembly compression enabled')


if __name__ == '__main__':
    main()
