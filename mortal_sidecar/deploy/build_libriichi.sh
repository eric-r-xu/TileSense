#!/usr/bin/env bash
# Builds libriichi.so for the droplet (Linux x86-64, Python 3.12, glibc <= 2.39)
# from the Mortal commit pinned in ../model.json, in Docker, so it works the
# same from a Mac or a GitHub runner.
#
#   mortal_sidecar/deploy/build_libriichi.sh OUT_DIR [MANIFEST]
#
# MANIFEST defaults to ../model.json; pass ../model_sanma.json for the sanma
# build. A manifest's optional "cargo_features" (e.g. "sanma") is passed to
# cargo, and the sanma build needs its own OUT_DIR.
#
# Writes OUT_DIR/libriichi.so and OUT_DIR/libriichi.commit. Skips the build
# when OUT_DIR already holds a build of the pinned commit (CI caches OUT_DIR).
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
out="$(mkdir -p "$1" && cd "$1" && pwd)"
manifest="${2:-$here/../model.json}"
read -r repo commit features < <(python3 -c '
import json, sys
m = json.load(open(sys.argv[1]))
print(m["mortal_repo"], m["mortal_commit"], m.get("cargo_features", ""))' "$manifest")
build="$commit${features:+ $features}"

if [[ -f "$out/libriichi.so" && "$(cat "$out/libriichi.commit" 2>/dev/null)" == "$build" ]]; then
  echo "libriichi.so for $build already built"
  exit 0
fi

# python:3.12 matches the droplet's Python (the .so links libpython3.12);
# bookworm's glibc 2.36 is older than the droplet's 2.39, so it loads there.
# Mortal uses Rust edition 2024: 1.85 or newer.
docker run --rm --platform linux/amd64 -v "$out:/out" python:3.12-bookworm bash -euc "
  curl -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain 1.89.0 >/dev/null
  . \$HOME/.cargo/env
  git clone --quiet --filter=blob:none '$repo' /mortal
  cd /mortal && git checkout --quiet '$commit'
  PYO3_PYTHON=python3.12 cargo build --quiet -p libriichi --lib --release ${features:+--features '$features'}
  cp target/release/libriichi.so /out/libriichi.so
"
header="$(head -c 20 "$out/libriichi.so" | od -An -tx1 | tr -d ' \n')"
[[ "${header:0:12}" == 7f454c460201 && "${header:36:4}" == 3e00 ]] ||
  { echo 'Expected a Linux x86-64 ELF library' >&2; exit 1; }
echo "$build" > "$out/libriichi.commit"
echo "Built libriichi.so for $build"
