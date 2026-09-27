#!/usr/bin/env bash
# Removes git-ignored build output and caches; all of it is regenerated on the next run, test, or deploy.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
echo "Before: $(du -sh . | cut -f1)"
(cd flutter_client && flutter clean)
rm -rf server/.dart_tool server/mp/.dart_tool packages/mahjong_core/.dart_tool
rm -f server/tilesense-ingest
find . -name .DS_Store -not -path './.git/*' -delete
echo "After: $(du -sh . | cut -f1)"
