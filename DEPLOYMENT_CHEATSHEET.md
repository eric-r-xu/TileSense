# Deployment cheatsheet

Quick reference for shipping a change to `app.ericrxu.com`. Full detail and
one-time setup live in `flutter_client/DEPLOYMENT.md` and
`server/DEPLOYMENT.md` — this is just the copy-paste part.

**`./deploy.sh` (repo root) runs everything below for you** —
`./deploy.sh` for all of it, or `./deploy.sh migrate|client|ingest|mp` for
just one piece. The rest of this file is what that script actually runs,
spelled out, for when something goes wrong and you need to run a piece by
hand.

**Every session, first (`deploy.sh` does this part itself):**

```sh
cd ~/Documents/GitHub/TileSense
source deploy.env                 # DB_ID, DROPLET_ID, DROPLET_IP, HOST, BASE_HREF
export PROD_DB="$(doctl databases connection "$DB_ID" --format URI --no-header)"
open -a Docker && docker ps >/dev/null   # needed for every compile step below
```

## What changed → what to redeploy

| You touched | Redeploy |
| --- | --- |
| `flutter_client/lib/**` (game, UI) | §2 Web client |
| `packages/mahjong_core/**` (shared core) | §2 Web client **and** §4 Multiplayer — the server imports it too |
| A new file in `server/migrations/` | §1 Migration, before §3 |
| `server/bin/server.dart` | §3 Ingest |
| `server/mp/lib/**`, `server/mp/bin/**` | §4 Multiplayer |
| `server/mp/deploy/tilesense-mp.service` (env vars) | §4 Multiplayer (copy the `.service` file too, not just the binary) |

---

## 1. Database migration

Only if a new file exists in `server/migrations/` that prod hasn't seen yet.
**Always before §3** — the ingest binary's SQL references columns/tables
that have to already exist, or every insert referencing them fails.

```sh
MYIP=$(curl -s4 https://api.ipify.org)
doctl databases firewalls replace "$DB_ID" \
  --rule "ip_addr:$MYIP" --rule "droplet:$DROPLET_ID"

docker run --rm -i postgres:16 psql "$PROD_DB" -f - < server/migrations/000X_name.sql
docker run --rm postgres:16 psql "$PROD_DB" -c '\dt'    # confirm the new table/columns

doctl databases firewalls replace "$DB_ID" --rule "droplet:$DROPLET_ID"   # drop laptop access again
```

## 2. Web client

```sh
BUILD_ID=$(date -u +%Y%m%d%H%M%S)

cd flutter_client
flutter build web --release \
  --base-href "$BASE_HREF" \
  --dart-define=BUILD_ID="$BUILD_ID" \
  --dart-define=APP_VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}')
printf '{"build_id":"%s"}' "$BUILD_ID" > build/web/build_id.json
python3 tools/precompress_web.py build/web     # .gz sidecars for gzip_static
cd ..

ssh root@$DROPLET_IP "nginx -T | grep -A6 'location /tilesense/'"   # first time only, to find SERVED_DIR
ssh root@$DROPLET_IP 'python3 -' < server/deploy/install-web-compression.py   # first time only
rsync -avz --delete flutter_client/build/web/ root@$DROPLET_IP:/SERVED_DIR/
curl -sI https://$HOST/tilesense/     # 200, ETag changed from before
curl -sI -H 'Accept-Encoding: gzip' https://$HOST/tilesense/main.dart.js | grep -i content-encoding
```

`BUILD_ID` has to reach the bundle *and* `build_id.json`, or the in-app Update
button can never fire — see
[`flutter_client/DEPLOYMENT.md`](flutter_client/DEPLOYMENT.md). Order matters:
`build_id.json` is written before `precompress_web.py`, which skips anything
under 1 KB, so the id itself is never served from a stale sidecar.

`precompress_web.py` writes a `.gz` next to every `.js`, `.wasm`, `.json`,
`.css`, `.html` and `.svg` over 1 KB; `install-web-compression.py` turns on
`gzip_static` for `location /tilesense/` so Nginx serves them. It is idempotent,
validates with `nginx -t`, and restores its backup if that fails, so re-running
it is safe. `main.dart.js` ships at about 0.8 MB instead of 2.7 MB.

## 3. Ingest service (telemetry)

```sh
docker run --rm --platform linux/amd64 -v "$PWD/server":/src -w /build dart:stable \
  sh -c "cp -r /src/. /build && dart pub get && dart compile exe bin/server.dart -o /src/tilesense-ingest"
file server/tilesense-ingest        # must say: ELF 64-bit ... x86-64

scp server/tilesense-ingest root@$DROPLET_IP:/tmp/tilesense-ingest
ssh root@$DROPLET_IP "mv /tmp/tilesense-ingest /usr/local/bin/tilesense-ingest && \
  systemctl restart tilesense-ingest && systemctl status tilesense-ingest --no-pager && \
  curl -s localhost:8787/healthz"        # -> ok, run on the Droplet (ingest only binds 127.0.0.1)
curl -sI https://$HOST/tilesense/
```

Don't touch `/etc/tilesense-ingest.env` on the Droplet as part of this —
regenerating it (per the *first-deploy* instructions in `server/DEPLOYMENT.md`
§2.5) rotates `IP_HMAC_SECRET` and breaks continuity with past sessions. Only
touch it if you're deliberately rotating the secret or changing `DATABASE_URL`.

## 4. Multiplayer service (mp)

**Restarting this drops every in-progress room** — by design, it has no DB
of its own for live state (see `server/DEPLOYMENT.md` §3). Pick a low-traffic
moment.

```sh
docker run --rm --platform linux/amd64 -v "$PWD":/repo -w /build dart:stable \
  sh -c "mkdir -p /build && cp -r /repo/packages /build/packages && cp -r /repo/server /build/server && \
    cd /build/server/mp && dart pub get && dart compile exe bin/mp_server.dart -o /repo/server/mp/tilesense-mp"
file server/mp/tilesense-mp

scp server/mp/tilesense-mp                root@$DROPLET_IP:/tmp/tilesense-mp
scp server/mp/deploy/tilesense-mp.service root@$DROPLET_IP:/etc/systemd/system/
ssh root@$DROPLET_IP "mv /tmp/tilesense-mp /usr/local/bin/tilesense-mp && systemctl daemon-reload && \
  systemctl restart tilesense-mp && systemctl status tilesense-mp --no-pager"
curl -sI https://$HOST/tilesense/
```

## Verify it actually worked

Play a round (or a full multiplayer game), then:

```sh
docker run --rm postgres:16 psql "$PROD_DB" -c \
  "select match_id, mode, room_code from matches order by started_at desc limit 3;"
docker run --rm postgres:16 psql "$PROD_DB" -c \
  "select kind, actor_seat, tile from events order by occurred_at desc limit 10;"
```
(Needs your laptop's IP on trusted sources again — see §1's firewall commands.)

## Rollback

| To undo | How |
| --- | --- |
| Web client | Redeploy the previous `build/web/`, or `ln -sfn` the previous release dir if using the symlink flow |
| Ingest binary | scp the previous `tilesense-ingest` back the same way, restart |
| Mp binary | Same, or `ssh root@$DROPLET_IP "systemctl disable --now tilesense-mp"` to stop it entirely |
| Mp telemetry only, keep the game running | Remove `Environment=INGEST_URL=...` from `tilesense-mp.service`, then `daemon-reload && restart` |
| A migration | Nothing to do — migrations here are additive-only by design (new columns/tables, never dropped/rewritten) |

## Gotchas hit before

- **`scp: dest open "..." Failure`** — this is `ETXTBSY`: you're overwriting a
  binary that's currently running as a live process, which Linux refuses.
  Always scp to `/tmp` then `ssh ... mv` into place (shown above) — `mv` on
  the same filesystem is a rename, not a write into the busy file, so it
  works even while the old binary is still executing.
- **`Connection refused` connecting to Postgres** — misleading; it almost
  always means your current IP isn't on the database's trusted-sources list
  right now, not that the DB is down. Re-run §1's `doctl databases firewalls
  replace` with your IP added.
- **A new table doesn't show up in Metabase** — Metabase caches its schema.
  Admin settings → Databases → (the telemetry DB) → **Sync database schema
  now**. If it's still missing after that, the `metabase_ro` role likely
  lacks `SELECT` on it specifically — `GRANT SELECT ON <table> TO
  metabase_ro;` connected as the admin role.
