# Deploying TileSense telemetry

The ingest service + database for the optional gameplay telemetry. This is
**additive** infrastructure — it does not change how the game is built or
served (see `README.md` for the design and safety properties).

Contents: `bin/server.dart`, `migrations/*.sql`, `docker-compose.yml`,
`Dockerfile`, `deploy/` (systemd unit, Nginx snippet, retention timer, App
Platform spec, and `deploy/metabase/` for the analytics dashboard — §5).

---

## 1. Local

`psql` is not required — the `db` container has it. The `dc` alias below is just
`docker compose exec -T db psql -U tilesense -d tilesense`.

### 1.1 Database

```sh
cd server
docker compose up -d                     # Postgres on :5432
alias dc='docker compose exec -T db psql -U tilesense -d tilesense'
dc -f - < migrations/0001_init.sql
dc -f - < migrations/0002_seat_characters.sql
dc -f - < migrations/0003_multiplayer.sql
dc -c '\dt'                              # -> clients, sessions, matches, rounds, events, events_default
```

### 1.2 Ingest service

Run natively (the client machine reaches the container on `localhost:5432`):

```sh
cd server
rm -rf .dart_tool && dart pub get        # rm only needed if a container ever ran `dart pub get` here
DATABASE_URL='postgres://tilesense:devpassword@localhost:5432/tilesense?sslmode=disable' \
IP_HMAC_SECRET=dev-only-not-secret \
ALLOW_ORIGIN='*' PORT=8787 \
  dart run bin/server.dart
# -> [ingest] listening on :8787
curl -s localhost:8787/healthz           # -> ok
```

### 1.3 Point the app at it

In a second terminal:

```sh
cd flutter_client
flutter run -d chrome \
  --dart-define=TELEMETRY=true \
  --dart-define=TELEMETRY_ENDPOINT=http://localhost:8787/ingest \
  --dart-define=APP_VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}')
```

Play a round or two, then (reusing the `dc` alias from 1.1):

```sh
dc -c "select match_id, seed, hanchan, autoplay_at_start from matches;"
dc -c "select kind, tile, auto, followed_guide from events order by occurred_at desc limit 20;"
dc -c "select round_index, end_kind, points, dealer_kept from rounds order by started_at;"
```

In Chrome DevTools -> Network, filter `ingest`: requests appear as type **`ping`**
(that is `sendBeacon`), fired at round/match boundaries and every ~15 s — never
one per discard.

### 1.4 Local no-regression gate

Telemetry is **on** in release builds now, so the checks are about isolation,
not absence:

```sh
cd flutter_client
flutter analyze                                  # clean
flutter test                                     # all pass (telemetry is inert on the VM)

# opt-out still fully removes it:
flutter build web --release --dart-define=TELEMETRY=false
grep -rl "sendBeacon\|ts_client_id\|human_decision" build/web/ ; echo "^ must be EMPTY"

# a dead endpoint must not affect gameplay (default endpoint, nothing serving it):
flutter run -d chrome --dart-define=TELEMETRY=true \
  --dart-define=TELEMETRY_ENDPOINT=http://127.0.0.1:59999/ingest
# play several rounds — no jank, no errors surfaced to the UI
```

### 1.5 Tear down

```sh
cd server && docker compose down          # add -v to also wipe the data volume
```

---

## 2. DigitalOcean — Droplet + Nginx (matches `DEPLOYMENT_CHEATSHEET.md` §2, which `deploy.sh` runs)

The site is served at `https://app.ericrxu.com/tilesense/` by nginx on the one
Droplet. This adds a sidecar ingest service on that Droplet and a managed
database. Nothing about the game build or its deploy changes — telemetry is
already on by default in release builds and points at
`https://app.ericrxu.com/ingest`; this section just makes that endpoint exist.

**No local `psql` needed** — every database command below runs through a
throwaway `postgres:16` container. Requires Docker Desktop running and `doctl`
authenticated. Run everything from the repo root unless noted.

### 2.0 Variables (re-do in every new terminal tab)

`export` does not survive across tabs, so keep the stable values in a file:

```sh
cd ~/Documents/GitHub/TileSense
cat > deploy.env <<'EOF'
export DB_ID=0e6e08c1-ed4d-4c6d-8a8f-b281c4de6b0a      # tilesense-db (doctl databases list)
export DROPLET_ID=353749640                            # doctl compute droplet list
export DROPLET_IP=143.198.98.204                       # SSH target (the droplet's own IP)
export HOST=app.ericrxu.com                            # hostname only, no /tilesense
export BASE_HREF=/tilesense/                           # existing sub-path deploy
EOF
grep -qxF deploy.env .gitignore || echo deploy.env >> .gitignore
```

> The live site (`https://app.ericrxu.com/tilesense/`) is served by this one
> droplet — DNS points at a DigitalOcean **reserved IP** (`143.198.245.111`)
> that routes to it, while `143.198.98.204` is the droplet's own address you
> `ssh` to. Both serve identical content; no DNS change is needed. There is no
> App Platform app or load balancer.

Then, in each tab:

```sh
cd ~/Documents/GitHub/TileSense
source deploy.env
export PROD_DB="$(doctl databases connection "$DB_ID" --format URI --no-header)"
echo "$PROD_DB"   # sanity: postgres://...@...ondigitalocean.com:25060/... ?sslmode=require
```

### 2.1 Managed Postgres (skip if `tilesense-db` already exists)

```sh
doctl databases create tilesense-db --engine pg --version 16 \
  --region nyc3 --size db-s-1vcpu-1gb --num-nodes 1
doctl databases list                                  # copy the ID into deploy.env
doctl databases get "$DB_ID" --format Name,Status     # wait for: online
```

### 2.2 Trusted sources

The DB refuses connections from IPs not on its allow-list. Add two — your
laptop (temporary, for the migration) and the Droplet (permanent):

```sh
MYIP=$(curl -s4 https://api.ipify.org)
echo "MYIP=[$MYIP]  DROPLET_ID=[$DROPLET_ID]"         # BOTH must be non-empty
doctl databases firewalls replace "$DB_ID" \
  --rule "ip_addr:$MYIP" \
  --rule "droplet:$DROPLET_ID"
doctl databases firewalls list "$DB_ID"               # confirm both rules
```

`replace` rejects the whole call if either `--rule` value is blank. If `$MYIP`
comes back empty, `curl` is being blocked — get the IP another way and set it
by hand. (Or do it in the control panel: **tilesense-db → Settings → Trusted
Sources → Add my current IP**, plus the droplet.)

### 2.3 Migrate (through a container)

```sh
docker run --rm -i postgres:16 psql "$PROD_DB" -f - < server/migrations/0001_init.sql
docker run --rm -i postgres:16 psql "$PROD_DB" -f - < server/migrations/0002_seat_characters.sql
docker run --rm -i postgres:16 psql "$PROD_DB" -f - < server/migrations/0003_multiplayer.sql
docker run --rm    postgres:16 psql "$PROD_DB" -c '\dt'
#   -> clients, sessions, matches, rounds, events, events_default
```

Then drop the laptop rule, keeping only the Droplet:

```sh
doctl databases firewalls replace "$DB_ID" --rule "droplet:$DROPLET_ID"
```

### 2.4 Build the Linux binary

Build inside a throwaway dir in the container (so it never writes
`server/.dart_tool` with container paths) and force x86-64 to match the Droplet:

```sh
docker run --rm --platform linux/amd64 -v "$PWD/server":/src -w /build dart:stable \
  sh -c "cp -r /src/. /build && dart pub get && dart compile exe bin/server.dart -o /src/tilesense-ingest"
file server/tilesense-ingest        # must say: ELF 64-bit ... x86-64
```

### 2.5 Copy everything to the Droplet

Build the env file locally (so `$PROD_DB` and `openssl` resolve here, not on the
Droplet where they aren't set), then scp:

```sh
cat > /tmp/ts-ingest.env <<EOF
DATABASE_URL=$PROD_DB
IP_HMAC_SECRET=$(openssl rand -hex 32)
ALLOW_ORIGIN=https://$HOST
PORT=8787
EOF

scp server/tilesense-ingest                root@$DROPLET_IP:/usr/local/bin/
scp server/deploy/tilesense-ingest.service root@$DROPLET_IP:/etc/systemd/system/
scp server/deploy/retention.sh             root@$DROPLET_IP:/usr/local/bin/tilesense-retention.sh
scp server/deploy/tilesense-retention.service server/deploy/tilesense-retention.timer \
                                           root@$DROPLET_IP:/etc/systemd/system/
scp /tmp/ts-ingest.env                     root@$DROPLET_IP:/etc/tilesense-ingest.env
rm /tmp/ts-ingest.env
```

### 2.6 Start the service (on the Droplet)

```sh
ssh root@$DROPLET_IP
```
```sh
chmod 600 /etc/tilesense-ingest.env
chmod +x /usr/local/bin/tilesense-retention.sh
systemctl daemon-reload
systemctl enable --now tilesense-ingest
systemctl enable --now tilesense-retention.timer
curl -s localhost:8787/healthz             # -> ok
systemctl status tilesense-ingest --no-pager
```

### 2.7 Wire Nginx (only change to the running site — still on the Droplet)

The site config is **`/etc/nginx/sites-enabled/myproject`** (confirm with
`nginx -T | grep -n 'configuration file\|server_name app.ericrxu'`). Inside the
`server { listen 443 ssl; server_name app.ericrxu.com; ... }` block, add the
`location = /ingest { ... }` block from `server/deploy/nginx-ingest.conf`. It's
an **exact-match** location, so position within the block doesn't matter — put
it near the top for readability, alongside the other `location = ...` lines.

```sh
nano /etc/nginx/sites-enabled/myproject
nginx -t                                        # MUST pass
systemctl reload nginx

curl -sI https://app.ericrxu.com/tilesense/     # game still 200, unchanged ETag
curl -s -X POST https://app.ericrxu.com/ingest \
  -d '{"client_id":"00000000-0000-4000-8000-000000000000","session_id":"00000000-0000-4000-8000-000000000001","events":[]}' \
  -w '%{http_code}\n'                            # -> 204
curl -s localhost:8787/healthz                   # -> ok (service is bound to 127.0.0.1)
exit
```

### 2.8 Redeploy the client

Telemetry is already on by default for `--release` builds and already points at
`https://app.ericrxu.com/ingest`, so a normal rebuild + your usual deploy is all
that's needed. `APP_VERSION` is optional but stamps events with a real version
instead of `dev`.

```sh
cd ~/Documents/GitHub/TileSense/flutter_client
flutter build web --release \
  --base-href "$BASE_HREF" \
  --dart-define=APP_VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}')
```

Find where nginx serves `/tilesense/` from and copy the new `build/web/` there:

```sh
ssh root@$DROPLET_IP "nginx -T | grep -A6 'location /tilesense/'"
#   look for `root <dir>;` or `alias <dir>;` — the game files live at
#   <dir>/tilesense/index.html (root) or <dir>/index.html (alias)
```

Then `rsync build/web/` into that directory (adjust the path to what you found):

```sh
rsync -avz --delete build/web/ root@$DROPLET_IP:/SERVED_DIR/
```

> Your `flutter_client/DEPLOYMENT.md` describes a `/var/www/tilesense/releases/<ts>`
> + `current` symlink flow. If this box uses that, deploy that way; if it serves
> a plain directory, just rsync into it. Either way nothing about telemetry
> requires changing the deploy mechanism.

### 2.9 Smoke test

```sh
# play a full match at https://app.ericrxu.com/tilesense/ , then:
docker run --rm postgres:16 psql "$PROD_DB" -c \
  "select date_trunc('minute',started_at) m, count(*) from matches group by 1 order by 1 desc limit 5;"
docker run --rm postgres:16 psql "$PROD_DB" -c \
  "select kind, tile, auto, followed_guide from events order by occurred_at desc limit 20;"
docker run --rm postgres:16 psql "$PROD_DB" -c \
  "select ip_prefix, geo_country, geo_region, geo_city, encode(ip_hmac,'hex') from sessions order by started_at desc limit 3;"
```

### 2.10 Rollback (any one, independent)

| To undo | How |
| --- | --- |
| the client change | redeploy the previous `build/web/` the same way you shipped this one (or `ln -sfn` the previous release dir if you use the symlink flow) |
| the Nginx route | remove the `location = /ingest` block from `/etc/nginx/sites-enabled/myproject`, `nginx -t && systemctl reload nginx` |
| the service | `ssh root@$DROPLET_IP "systemctl disable --now tilesense-ingest"` |
| everything | all three above; the DB is inert, or `doctl databases delete $DB_ID` |

---

### 2.11 GeoIP location (`sessions.geo_country`, `geo_region`, `geo_city`)

The ingest looks each new session's network up in `geoip_city` (migration
`0004_geoip.sql`) and stores its country code, region and city on the
session. The data is DB-IP's free "IP to City Lite" database, licensed **CC BY 4.0 — credit "IP Geolocation by DB-IP"
(https://db-ip.com)** on any chart, dashboard or report built from it (see
`server/README.md`, Data attribution).

```sh
./deploy.sh geoip   # download this month's file, swap it in, backfill
```

That downloads the CSV here (~85 MB, ~7.7M ranges), loads it through
`server/deploy/load-geoip.sql` into a side table, and swaps it in with a quick
rename, so the ingest never waits on the load. A short or failed download stops
before the swap and leaves the current table in place, and its staging data is
a temporary table, so nothing is left behind. It then fills in the location of
every session missing a country or city, including every session recorded
before this existed. Re-run it monthly to pick up DB-IP's new file; it is safe
to run any time.

The database side is quiet for minutes at a time (the upload, the table copy,
the index build), so `deploy.sh` prints a heartbeat line every 15 seconds
from a separate read-only connection: the upload's percentage, the index
build's phase, or which statement is running and for how long, plus the
database's size. For example:

```
    [heartbeat 14:32:15] uploading: 63.1% (4893140 of 7748998 rows, 379 MB) · db 463 MB
    [heartbeat 14:32:23] create table geoip_city_new as select ip_start, ip_end, coun (running 00:00:05) · db 1339 MB
    [heartbeat 14:32:31] index: building index: loading tuples in tree · db 850 MB
```

Disk: the table is ~860 MB with its index. A reload briefly holds the old
table, the new one and the staging data at once, peaking at ~2.3 GB, so keep
~3 GB free (the `db-s-1vcpu-1gb` plan has 10 GiB).

- Only the network address (the `/24` or `/48`) is ever looked up, never a
  caller's own address.
- The lookup runs outside the batch's transaction and swallows its own errors:
  an empty or missing table just leaves the `geo_*` columns null, and the
  batch is still stored. Failures log as `[ingest] geoip lookup failed: …`.
- Country is reliable, region usually right. City is approximate: mobile
  carriers, VPNs and corporate networks often resolve to their ISP's hub city
  rather than the player's.
- The caller's address is the **last** `X-Forwarded-For` entry — the one nginx
  appends (`$proxy_add_x_forwarded_for`). Earlier entries are whatever the
  client sent and are ignored. `CF-IPCountry`/`CF-Connecting-IP` are ignored
  too: the site isn't behind Cloudflare, so only a client could set them.

Check it:

```sh
docker run --rm postgres:16 psql "$PROD_DB" -c \
  "select geo_country, geo_region, geo_city, count(distinct client_id) as clients
   from sessions group by 1, 2, 3 order by 4 desc limit 20;"
```

## 3. Multiplayer game server

A second, independent sidecar — `server/mp/` — alongside the ingest service
from §2. It has **no database of its own**: rooms live in memory only, so
restarting this service drops every in-progress room. That's the accepted
tradeoff for the MVP (private room codes, guest identity, bot fill-in — see
`server/mp/README` if present, or the multiplayer plan this section shipped
with).

That tradeoff is about live room state only. Session *data* — matches,
rounds, discards/calls, who joined/left/went-bot — is recorded into the same
Postgres §1 set up, the same way single-player's is: `server/mp` is the
authoritative source for a shared match (it computed every round for all
four seats, so it is the one writer, not up to four browsers each reporting
their own view), and forwards batched events to the ingest service's
`/ingest` endpoint over loopback — see `server/mp/lib/telemetry.dart` and
`server/migrations/0003_multiplayer.sql`. Controlled by one env var,
`INGEST_URL`: unset (the default for `dart run bin/mp_server.dart` with no
env set) means entirely off, exactly like the client's own telemetry when
`TELEMETRY_ENDPOINT` has nothing to talk to. A dead or slow ingest service
never affects a live game — every send is fire-and-forget with errors
swallowed.

### 3.1 Local

```sh
cd server/mp
dart pub get
dart run bin/mp_server.dart
# -> [mp] listening on 127.0.0.1:8789
```

Point a locally-built client at it:

```sh
cd flutter_client
flutter run -d chrome --dart-define=MP_ENDPOINT=ws://localhost:8789
```

To also exercise multiplayer session recording locally, run it with
`INGEST_URL` pointing at the ingest service from §1.2 (both need to be up —
§1.1's Postgres included):

```sh
cd server/mp
INGEST_URL=http://127.0.0.1:8787/ingest dart run bin/mp_server.dart
```

Play a room through, then (reusing the `dc` alias from §1.1):

```sh
dc -c "select match_id, mode, room_code, timer_seconds, seat_places from matches where mode = 'multiplayer' order by started_at desc limit 5;"
dc -c "select seat, guest_id from match_participants where match_id = '<a match_id from above>' order by seat;"
```

### 3.2 Build the Linux binary

Different entrypoint and package from §2.4, and — unlike the ingest
service — this one has a `path:` dependency on `packages/mahjong_core`
(`../../packages/mahjong_core` from `server/mp/pubspec.yaml`), so mounting
`server/mp` alone leaves `dart pub get` unable to see it at all
("`mahjong_core from path` doesn't exist"). Mount the repo root instead and
copy just `server/` and `packages/`, preserving their relative layout, so
that relative path still resolves inside the container:

```sh
docker run --rm --platform linux/amd64 -v "$PWD":/repo -w /build dart:stable \
  sh -c "mkdir -p /build/server /build/packages && \
    cp -r /repo/server/. /build/server/ && cp -r /repo/packages/. /build/packages/ && \
    cd /build/server/mp && dart pub get && \
    dart compile exe bin/mp_server.dart -o /repo/server/mp/tilesense-mp"
file server/mp/tilesense-mp        # must say: ELF 64-bit ... x86-64
```

Run from the repo root, not `server/mp` — `$PWD` here has to be the whole
checkout.

### 3.3 Copy to the Droplet and start the service

```sh
scp server/mp/tilesense-mp                root@$DROPLET_IP:/usr/local/bin/
scp server/mp/deploy/tilesense-mp.service root@$DROPLET_IP:/etc/systemd/system/

ssh root@$DROPLET_IP
```
```sh
systemctl daemon-reload
systemctl enable --now tilesense-mp
curl -s localhost:8789/                     # -> 404 (expected — only WebSocket upgrades are served)
systemctl status tilesense-mp --no-pager
```

### 3.4 Wire Nginx

Same site config as §2.7 (`/etc/nginx/sites-enabled/myproject`). Add the
`location /tilesense/mp/ { ... }` block from `server/mp/deploy/nginx-mp.conf`
inside the same `server { server_name app.ericrxu.com; }` block, near the
`/ingest` block.

```sh
nano /etc/nginx/sites-enabled/myproject
nginx -t                                        # MUST pass
systemctl reload nginx

curl -sI https://app.ericrxu.com/tilesense/     # game still 200, unchanged ETag
exit
```

### 3.5 Point the client at it and redeploy

```sh
cd ~/Documents/GitHub/TileSense/flutter_client
flutter build web --release \
  --base-href "$BASE_HREF" \
  --dart-define=MP_ENDPOINT=wss://app.ericrxu.com/tilesense/mp/
```

Then ship `build/web/` the same way §2.8 does.

### 3.6 Smoke test

Open the deployed site in two separate browser profiles/tabs, create a room
in one, join with the code in the other, start with bots filling the other
two seats, and play a full hand end to end. Then close one tab and confirm
the other receives a bot-takeover notice after ~30s and keeps playing.

Then confirm that hand was actually recorded:

```sh
docker run --rm postgres:16 psql "$PROD_DB" -c \
  "select match_id, room_code, seat_characters, seat_is_bot from matches where mode = 'multiplayer' order by started_at desc limit 1;"
docker run --rm postgres:16 psql "$PROD_DB" -c \
  "select kind, actor_seat, tile from events where match_id = '<the match_id above>' order by occurred_at;"
```

### 3.7 Rollback (independent of ingest)

| To undo | How |
| --- | --- |
| the client change | redeploy the previous `build/web/` |
| the Nginx route | remove the `location /tilesense/mp/` block, `nginx -t && systemctl reload nginx` |
| the service | `ssh root@$DROPLET_IP "systemctl disable --now tilesense-mp"` |
| just multiplayer session recording, keeping the game running | `ssh root@$DROPLET_IP` and remove the `Environment=INGEST_URL=...` line from `/etc/systemd/system/tilesense-mp.service`, then `systemctl daemon-reload && systemctl restart tilesense-mp` |

---

## 4. DigitalOcean — App Platform (Option B, containers)

If the site already runs as an App Platform Docker service:

```sh
# edit server/deploy/app-platform.yaml: set IP_HMAC_SECRET, repo/branch, region
doctl apps list                                    # note the <app-id>
doctl apps update <app-id> --spec server/deploy/app-platform.yaml
```

App Platform provisions the managed DB, injects `${db.DATABASE_URL}`, terminates
TLS, and routes `/ingest` to the `ingest` component on the same origin. Run the
migration once against the attached DB:

```sh
PROD_DB="$(doctl databases connection <db-id-from-app> --format URI --no-header)"
docker run --rm -i postgres:16 psql "$PROD_DB" -f - < server/migrations/0001_init.sql
docker run --rm -i postgres:16 psql "$PROD_DB" -f - < server/migrations/0002_seat_characters.sql
docker run --rm -i postgres:16 psql "$PROD_DB" -f - < server/migrations/0003_multiplayer.sql
docker run --rm -i postgres:16 psql "$PROD_DB" -f - < server/migrations/0004_geoip.sql
```

The ingest takes the caller's address from the **last** `X-Forwarded-For`
entry (see 2.11), so check that App Platform's router appends the caller's
address there before trusting `ip_prefix`/`geo_*` on this setup. Load
the GeoIP data by running `server/deploy/load-geoip.sql` against `$PROD_DB`,
as `load_geoip` in `deploy.sh` does.

Then deploy the client exactly as in 2.8 with
`TELEMETRY_ENDPOINT=https://<your-app>.ondigitalocean.app/ingest`.

Rollback: `doctl apps update <app-id> --spec <previous-spec>` (remove the
`ingest` service + `databases` entry), then redeploy the client without the
defines.

---

## 5. Analytics starters

Run these against prod with
`docker run --rm postgres:16 psql "$PROD_DB" -c "<query>"` (or install `psql`
via `brew install libpq`).

```sql
-- matches started / finished per IP-group per day
select date_trunc('day', m.started_at) d,
       encode(s.ip_hmac,'hex') ip_key,
       count(*) started,
       count(*) filter (where m.ended_reason = 'game_end') finished
from matches m join sessions s using (session_id)
group by 1,2 order by 1 desc, 3 desc;

-- guide follow-rate, manual play only, guide on screen
select s.ip_prefix,
       count(*) filter (where e.guide_reco is not null) decisions,
       avg((e.followed_guide)::int) filter (where e.guide_reco is not null) follow_rate
from events e join sessions s using (session_id)
where e.kind in ('discard','call','pass')
  and e.auto = false and e.guide_shown = true
group by 1 having count(*) >= 20
order by decisions desc;

-- human placement distribution
select human_place, count(*) from matches
where ended_reason = 'game_end' group by 1 order by 1;
```

---

## 6. Metabase (analytics dashboard)

Run Metabase on the Droplet (already a trusted source for the managed DB,
always-on, behind the existing nginx + Certbot). Config lives in
`server/deploy/metabase/`. All commands are on the Droplet as `root` unless
noted.

### 6.1 Docker (skip if `docker compose version` already works)

```sh
apt-get update && apt-get install -y ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
docker compose version
```

### 6.2 Memory — add swap if under 2 GB

```sh
free -m                                   # look at "Mem: total"
# if total < ~2000:
fallocate -l 2G /swapfile && chmod 600 /swapfile
mkswap /swapfile && swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab
printf 'vm.swappiness=10\n' > /etc/sysctl.d/99-swap.conf && sysctl --system
```

### 6.3 Read-only DB user (for querying telemetry)

As `doadmin` (`psql "$DATABASE_URL"` — the value from
`/etc/tilesense-ingest.env`):

```sql
CREATE ROLE metabase_ro WITH LOGIN PASSWORD 'GENERATE_A_STRONG_ONE';
GRANT CONNECT ON DATABASE defaultdb TO metabase_ro;
GRANT USAGE ON SCHEMA public TO metabase_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO metabase_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO metabase_ro;
```

### 6.4 DNS

Add an `A` record: `analytics.app.ericrxu.com` -> the same IP the apex uses
(`143.198.245.111`). Confirm before continuing:

```sh
dig +short analytics.app.ericrxu.com      # must return that IP
```

### 6.5 Bring up Metabase

```sh
mkdir -p /opt/metabase
# copy the two files from the repo (scp from your Mac, or paste):
#   server/deploy/metabase/docker-compose.yml -> /opt/metabase/docker-compose.yml
#   server/deploy/metabase/.env.example       -> /opt/metabase/.env
cd /opt/metabase

# fill in .env
MB_VERSION=$(curl -s https://api.github.com/repos/metabase/metabase/releases/latest \
  | grep -oE '"tag_name": *"[^"]+"' | grep -oE 'v[0-9.]+')
sed -i "s|^MB_VERSION=.*|MB_VERSION=$MB_VERSION|" .env
sed -i "s|^MB_DB_PASSWORD=.*|MB_DB_PASSWORD=$(openssl rand -hex 24)|" .env
chmod 600 .env
cat .env                                  # sanity check

docker compose up -d
docker compose logs -f metabase           # wait for "Metabase Initialization COMPLETE"  (~1-2 min)
curl -fsS http://127.0.0.1:3000/api/health   # {"status":"ok"}
```

### 6.6 nginx + TLS

```sh
cp server/deploy/metabase/nginx-analytics.conf \
   /etc/nginx/sites-available/analytics.app.ericrxu.com          # scp/paste
ln -s /etc/nginx/sites-available/analytics.app.ericrxu.com /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx
certbot --nginx -d analytics.app.ericrxu.com                     # pick "redirect"
curl -sI https://analytics.app.ericrxu.com/                      # 200 or 302 to /setup
```

### 6.7 First-run + connect the telemetry DB

Open `https://analytics.app.ericrxu.com`:

1. Create the admin account (name / email / password).
2. Add data -> **PostgreSQL**:
   - Host: run `psql "$DATABASE_URL" -c 'select inet_server_addr()'` on the
     droplet, or take the host from `/etc/tilesense-ingest.env`'s `DATABASE_URL`
   - Port `25060`, Database `defaultdb`, Username `metabase_ro`, the password
     from 5.3
   - **Use a secure connection (SSL): ON**, SSL Mode `require`
3. Finish. Metabase syncs the schema in ~30 s.

### 6.8 Build the dashboard

**+ New -> SQL query -> (the telemetry DB) ->** paste e.g. the queries in §4 ->
Run -> Visualization -> Save -> add to a new dashboard. Add a date filter bound
to `matches.started_at`; set the dashboard to auto-refresh from its menu.

### 6.9 Backups + updates

```sh
cp server/deploy/metabase/backup.sh /usr/local/bin/metabase-backup.sh
chmod +x /usr/local/bin/metabase-backup.sh
echo '0 4 * * * root /usr/local/bin/metabase-backup.sh' > /etc/cron.d/metabase-backup

# update to a newer Metabase:
cd /opt/metabase
sed -i "s|^MB_VERSION=.*|MB_VERSION=vX.Y.Z|" .env      # a released tag
docker compose pull && docker compose up -d            # app DB (and dashboards) persist
```

### 6.10 Rollback

```sh
cd /opt/metabase && docker compose down                # stop; volume + data kept
rm /etc/nginx/sites-enabled/analytics.app.ericrxu.com  # drop the vhost
nginx -t && systemctl reload nginx
# full wipe (loses dashboards): docker compose down -v
```
