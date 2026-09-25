# TileSense server

Two Dart services live here:

- **Telemetry ingest** (`bin/server.dart`) — accepts gameplay batches from the
  client and writes them to Postgres. Described below.
- **Multiplayer game server** (`mp/`) — runs the online tables. It imports the
  shared core (`packages/mahjong_core/`), so a change there needs it
  redeployed too. Its runbook is
  [`DEPLOYMENT.md`](DEPLOYMENT.md) §3.

## Telemetry ingest

The ingest service is **entirely additive** infrastructure — it does not touch
how the game is built or served.

- **On by default in release web builds** — `flutter build web --release`
  ships it, pointed at `https://app.ericrxu.com/ingest`. Debug builds,
  `flutter run`, and every VM test are inert. Opt out with
  `--dart-define=TELEMETRY=false`; repoint with
  `--dart-define=TELEMETRY_ENDPOINT=<url>`.
- The client sends with `navigator.sendBeacon` — fire-and-forget, batched, no
  `await`. A dead or slow endpoint is invisible to gameplay, so shipping the
  client before the ingest endpoint is live just means those events are lost.
- The only change to a running web server is one Nginx `location = /ingest`
  block. Removing it + `nginx -s reload` is a full rollback.
- No raw IP is stored — only `HMAC-SHA256(ip, secret)` and a `/24`–`/48` prefix.
- Each session's approximate location (`sessions.geo_country`,
  `geo_region`, `geo_city`) comes from looking that prefix up in
  `geoip_city`, which `./deploy.sh geoip` loads from DB-IP's free database —
  see [Data attribution](#data-attribution) and
  [`DEPLOYMENT.md`](DEPLOYMENT.md) §2.11.

## Layout

| Path | What |
| --- | --- |
| `bin/server.dart` | the ingest service (shelf + postgres) |
| `lib/client_network.dart` | the caller's address and network prefix, from the proxy headers |
| `test/` | unit tests for `lib/` (`dart test`) |
| `migrations/*.sql` | schema — additive, re-runnable, applied in filename order |
| `docker-compose.yml` | local Postgres for development |
| `Dockerfile` | build a self-contained binary (App Platform / any container host) |
| `.env.example` | required environment variables |
| `deploy/` | systemd unit, Nginx snippet, retention timer, App Platform spec, GeoIP loader (`load-geoip.sql`) |
| `mp/` | the multiplayer game server — `bin/mp_server.dart`, `lib/table_loop.dart`, its own `deploy/` unit and Nginx snippet |

## Endpoints

| Method | Path | Purpose |
| --- | --- | --- |
| `POST` | `/ingest` | accept a JSON batch (`text/plain` from `sendBeacon`); always answers `204` |
| `GET` | `/healthz` | liveness |
| `GET` | `/readyz` | checks the DB connection |

## Data attribution

Location data: [IP Geolocation by DB-IP](https://db-ip.com). The "IP to
City Lite" database is licensed under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), which requires that
credit wherever it is used. So any chart, dashboard or report built from
`sessions.geo_country`, `geo_region` or `geo_city` (or `geoip_city`) must
carry "IP Geolocation by DB-IP" with a link to https://db-ip.com.

## Deploying

Full local + DigitalOcean runbook (Droplet + Nginx and App Platform), including
the client build flags and rollback: **[`DEPLOYMENT.md`](DEPLOYMENT.md)**.
