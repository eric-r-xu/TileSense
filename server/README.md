# TileSense telemetry ingest

A single Dart service (`bin/server.dart`) that accepts gameplay batches from the
client and writes them to Postgres. It is **entirely additive** infrastructure —
it does not touch how the game is built or served.

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

## Layout

| Path | What |
| --- | --- |
| `bin/server.dart` | the ingest service (shelf + postgres) |
| `migrations/0001_init.sql` | schema — additive, re-runnable |
| `docker-compose.yml` | local Postgres for development |
| `Dockerfile` | build a self-contained binary (App Platform / any container host) |
| `.env.example` | required environment variables |
| `deploy/` | systemd unit, Nginx snippet, retention timer, App Platform spec |

## Endpoints

| Method | Path | Purpose |
| --- | --- | --- |
| `POST` | `/ingest` | accept a JSON batch (`text/plain` from `sendBeacon`); always answers `204` |
| `GET` | `/healthz` | liveness |
| `GET` | `/readyz` | checks the DB connection |

## Deploying

Full local + DigitalOcean runbook (Droplet + Nginx and App Platform), including
the client build flags and rollback: **[`DEPLOYMENT.md`](DEPLOYMENT.md)**.
