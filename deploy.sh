#!/usr/bin/env bash
# TileSense production deploy — the runnable form of DEPLOYMENT_CHEATSHEET.md.
# Read that file if you want the manual, explained version of any step here.
#
# Usage (run from anywhere; the script cd's to the repo root itself):
#   ./deploy.sh              # everything: migrations + client + ingest + mp
#   ./deploy.sh migrate      # just the DB migrations
#   ./deploy.sh client       # just the web client (the game itself)
#   ./deploy.sh ingest       # migrations, then the telemetry ingest service
#   ./deploy.sh mp           # just the multiplayer service
#
# Requires: deploy.env in the repo root (DB_ID, DROPLET_ID, DROPLET_IP, HOST,
# BASE_HREF — see server/DEPLOYMENT.md section 2.0 to generate one), doctl
# authenticated, Docker Desktop installed, ssh access to the Droplet.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

TARGET="${1:-all}"

# --- setup ---------------------------------------------------------------

if [[ ! -f deploy.env ]]; then
  echo "deploy.env not found in the repo root — see server/DEPLOYMENT.md" \
       "section 2.0 to create one." >&2
  exit 1
fi
# shellcheck source=/dev/null
source deploy.env
: "${DB_ID:?deploy.env is missing DB_ID}"
: "${DROPLET_ID:?deploy.env is missing DROPLET_ID}"
: "${DROPLET_IP:?deploy.env is missing DROPLET_IP}"
: "${HOST:?deploy.env is missing HOST}"
: "${BASE_HREF:?deploy.env is missing BASE_HREF}"

echo "==> Checking Docker..."
open -a Docker >/dev/null 2>&1 || true
for _ in $(seq 1 30); do
  docker info >/dev/null 2>&1 && break
  sleep 2
done
if ! docker info >/dev/null 2>&1; then
  echo "Docker did not come up in time — start it manually and re-run." >&2
  exit 1
fi

PROD_DB="$(doctl databases connection "$DB_ID" --format URI --no-header)"
export PROD_DB

check_site() {
  echo "    site check: $(curl -sI "https://$HOST/tilesense/" | head -1 | tr -d '\r')"
}

# --- steps -----------------------------------------------------------------

run_migrations() {
  echo "==> Applying database migrations (additive-only — safe to re-run all of them every time)..."
  local myip
  myip="$(curl -s4 https://api.ipify.org || true)"
  if [[ -z "$myip" ]]; then
    echo "    could not determine this machine's IP — skipping the firewall" \
         "update; migrations will fail if this IP isn't already trusted." >&2
  else
    doctl databases firewalls replace "$DB_ID" \
      --rule "ip_addr:$myip" --rule "droplet:$DROPLET_ID"
  fi

  for f in server/migrations/*.sql; do
    echo "    - $f"
    docker run --rm -i postgres:16 psql "$PROD_DB" -f - < "$f"
  done

  if [[ -n "$myip" ]]; then
    doctl databases firewalls replace "$DB_ID" --rule "droplet:$DROPLET_ID"
  fi
  echo "==> Migrations applied."
}

deploy_client() {
  echo "==> Building the web client..."
  # The in-app Update button compares this id with the one it was compiled
  # with, so the build must stamp it in two places: into the bundle, and into
  # build_id.json next to index.html. Without both the check can never fire.
  local build_id
  build_id="$(date -u +%Y%m%d%H%M%S)"
  (
    cd flutter_client
    flutter build web --release \
      --base-href "$BASE_HREF" \
      --dart-define=BUILD_ID="$build_id" \
      --dart-define=APP_VERSION="$(grep '^version:' pubspec.yaml | awk '{print $2}')"
    printf '{"build_id":"%s"}' "$build_id" > build/web/build_id.json
    # After the build, before the sidecars: precompress skips files under 1KB,
    # so this one stays uncompressed and always freshly readable.
    python3 tools/precompress_web.py build/web
  )
  echo "    build id: $build_id"

  local served="${SERVED_DIR:-}"
  if [[ -z "$served" ]]; then
    echo "==> SERVED_DIR not set in deploy.env — looking it up from Nginx..."
    served="$(ssh "root@$DROPLET_IP" \
      "nginx -T 2>/dev/null | awk '/location \\/tilesense\\// {f=1} f && (/root /||/alias /) {print \$2; exit}'" \
      | tr -d ';')"
    if [[ -z "$served" ]]; then
      echo "    could not auto-detect it. Run:" >&2
      echo "      ssh root@$DROPLET_IP \"nginx -T | grep -A6 'location /tilesense/'\"" >&2
      echo "    then add 'export SERVED_DIR=<that path>' to deploy.env." >&2
      exit 1
    fi
    echo "    found: $served"
    echo "    add 'export SERVED_DIR=$served' to deploy.env to skip this lookup next time."
  fi

  ssh "root@$DROPLET_IP" 'python3 -' < server/deploy/install-web-compression.py
  rsync -avz --delete flutter_client/build/web/ "root@$DROPLET_IP:$served/"
  echo "==> Web client deployed."
  check_site
}

deploy_ingest() {
  run_migrations
  echo "==> Building the ingest service..."
  docker run --rm --platform linux/amd64 -v "$PWD/server":/src -w /build dart:stable \
    sh -c "cp -r /src/. /build && dart pub get && dart compile exe bin/server.dart -o /src/tilesense-ingest"
  file server/tilesense-ingest | grep -q 'x86-64' || {
    echo "Unexpected binary architecture — aborting." >&2
    exit 1
  }

  echo "==> Deploying it (scp to /tmp then mv — a direct scp fails with" \
       "ETXTBSY while the old binary is still running)..."
  scp server/tilesense-ingest "root@$DROPLET_IP:/tmp/tilesense-ingest"
  ssh "root@$DROPLET_IP" '
    mv /tmp/tilesense-ingest /usr/local/bin/tilesense-ingest &&
    systemctl restart tilesense-ingest &&
    systemctl status tilesense-ingest --no-pager &&
    curl -s localhost:8787/healthz
  '
  echo "==> Ingest service deployed."
  check_site
}

deploy_mp() {
  echo "==> Building the multiplayer service..."
  docker run --rm --platform linux/amd64 -v "$PWD":/repo -w /build dart:stable sh -c '
    mkdir -p /build &&
    cp -r /repo/packages /build/packages &&
    cp -r /repo/server /build/server &&
    cd /build/server/mp &&
    dart pub get &&
    dart compile exe bin/mp_server.dart -o /repo/server/mp/tilesense-mp
  '
  file server/mp/tilesense-mp | grep -q 'x86-64' || {
    echo "Unexpected binary architecture — aborting." >&2
    exit 1
  }

  echo "    NOTE: restarting the multiplayer service drops every room" \
       "currently in progress — no DB-backed room state, by design."
  echo "==> Deploying it (binary + the .service file, which carries INGEST_URL)..."
  scp server/mp/tilesense-mp "root@$DROPLET_IP:/tmp/tilesense-mp"
  scp server/mp/deploy/tilesense-mp.service "root@$DROPLET_IP:/etc/systemd/system/"
  ssh "root@$DROPLET_IP" '
    mv /tmp/tilesense-mp /usr/local/bin/tilesense-mp &&
    systemctl daemon-reload &&
    systemctl restart tilesense-mp &&
    systemctl status tilesense-mp --no-pager
  '
  echo "==> Multiplayer service deployed."
  check_site
}

# --- dispatch ----------------------------------------------------------

case "$TARGET" in
  all)
    # deploy_ingest runs the migrations itself (see below) — no need to
    # duplicate that call here.
    deploy_client
    deploy_ingest
    deploy_mp
    ;;
  migrate) run_migrations ;;
  client) deploy_client ;;
  ingest) deploy_ingest ;;
  mp) deploy_mp ;;
  *)
    echo "Usage: $0 [all|migrate|client|ingest|mp]" >&2
    exit 1
    ;;
esac

echo "==> Done."
