# Deployment cheatsheet

`deploy.sh` is the supported production deployment entrypoint. It delegates to
`server/deploy/deploy.py` and a locked SSH worker, `server/deploy/remote.py`.
It does not upload generated files into the digitalOcean Git checkout.

## Configuration

Keep the ignored `deploy.env` in the repository root:

```sh
HOST=app.ericrxu.com
DROPLET_IP=<your-droplet-address>
BASE_HREF=/tilesense/
DB_ID=<managed-postgres-id>       # only migrate / ingest / all
DART_IMAGE=dart:3.13.3            # only ingest / mp / all; exact SDK tag required
```

Pin `DART_IMAGE` to the SDK validated for the release (a digest can also be
appended). Docker must already be running for backend builds. Client-only
deployments require Flutter, Python 3.9+, Git, SSH and rsync; they do not need
Docker, doctl, or database credentials. Database deployment requires doctl on
the laptop and psql on the already trusted Droplet. PostgreSQL credentials go
through encrypted SSH stdin and subprocess environment, not command arguments.
No firewall rules are replaced. `DROPLET_ID` and `SERVED_DIR` are no longer used.

Commit the source before deploying. The existing checkout may include locally
modified compiled backend binaries: review those separately, never discard them
blindly. `ALLOW_DIRTY_DEPLOY=1` explicitly allows a dirty checkout; release
metadata records that exception, so a commit ID alone will not reproduce it.

## One-time client hosting transition

```sh
./deploy.sh setup-client
```

This copies the currently served assets from
`/srv/digitalOcean/static/tilesense/` into `/srv/tilesense/legacy/`, backs up
`/etc/nginx/sites-enabled/myproject`'s resolved file, and modifies only the known
TileSense static location. Other Flask, ingest, TLS and WebSocket routes are
preserved. It runs `nginx -t` before reloading and restores the previous config
on validation, reload, or the driver's public HTTP check failure. The old Git
checkout and its assets remain untouched.

The setup fails on an unfamiliar/ambiguous Nginx layout. Review it rather than
loosening the checks. A failed setup can leave a private backup and legacy
snapshot; inspect them before retrying. Do not delete the old assets as part of
this transition. Reconcile digitalOcean's existing Git differences separately.

## Routine releases

```sh
./deploy.sh client
./deploy.sh migrate
./deploy.sh ingest
./deploy.sh geoip                 # monthly DB-IP city refresh; not part of all
ALLOW_MP_RESTART=1 ./deploy.sh mp
ALLOW_MP_RESTART=1 ./deploy.sh all
```

Multiplayer restarts disconnect active rooms; the explicit environment flag
acknowledges this. Schedule those releases when disruption is acceptable.

The script builds all requested artifacts before making production changes.
Backend builds use read-only source mounts and lockfiles and put outputs in a
temporary directory, leaving tracked binaries untouched. Full releases apply
migrations, install/verify ingest and multiplayer, then activate the client.

Client releases are uploaded to unique staging directories and checked against
a SHA-256 manifest. They are published under `/srv/tilesense/releases/<id>/`.
The stable `/tilesense/` URL serves the current release's index; its HTML base
points at `/tilesense/releases/<id>/`. Deferred JavaScript, fonts and other
assets therefore continue to work in tabs opened before a later deployment.
The manifest's PWA start URL and the in-app build-ID check remain `/tilesense/`.
Font fingerprinting, compressed sidecars and the initial loading page remain.
No Flutter service worker is generated for new releases.

An atomic symlink switch activates the client. Public checks verify the build
ID, HTML base and core assets before and after activation. Local and remote
locks prevent overlapping deployments using this script. Legacy deploy aliases
and manual rsync commands bypass these locks and must no longer be used.

## Recovery and retention

```sh
./deploy.sh rollback-client <previous-release-id>
```

Releases are immutable. The script never prunes the legacy snapshot, old
releases, or backend backups. Monitor disk usage and retain versions needed by
open tabs; deleting their assets can break deferred loading. A rollback to a
versioned release runs the same health checks as a deployment. The initial
legacy snapshot is reserved for automatic first-deployment rollback.

Until the worker receives an explicit commit, SSH EOF/disconnection restores
activated clients and successfully replaced services in reverse order. Each
service also restores its binary/unit immediately if its own restart or health
check fails. Backups are in `/srv/tilesense/.staging/<id>/backup/`. An OS crash,
forced kill, or network outage can prevent automatic recovery or verification;
inspect the reported backup and `current` paths before retrying. Ingest uses
its HTTP health endpoint; multiplayer checks service state and its listening
socket (this is not a full game-protocol smoke test).

Migrations run with `ON_ERROR_STOP`, transaction boundaries, an advisory lock,
timeouts, and a checksum ledger. Current idempotent migrations run once when
adopting the ledger on an existing database. Failed migrations roll back their
own changes. Successful migrations remain applied if a later deployment step
fails: automatic schema rollback could discard newly collected telemetry.
Confirm database backups/PITR before releases; this script does not create a
managed database backup. Nontransactional migrations require a separate review.

## Regression checks (no production access)

```sh
python3 -B -m unittest discover -s server/deploy -p 'test_*.py' -v
bash -n deploy.sh
```

The legacy manual commands in the longer platform documents describe initial
provisioning and historical deployment. For routine production releases use
this script, not direct rsync into `/srv/digitalOcean` or firewall replacement.

## GeoIP compatibility

`geoip` retains the current DB-IP city download, prior-month fallback, existing
`load-geoip.sql` table swap/backfill, and a 15-second database progress heartbeat.
It validates the complete gzip stream and uploaded checksum before loading.
The load now runs through SSH on the trusted Droplet, with no firewall changes
or local Docker requirement. Its existing SQL transaction boundaries are kept;
a completed table swap is not automatically undone if subsequent backfill fails.
The compressed download stays in the unique staging directory for diagnosis.

The optional database integration suite creates and drops randomly named test
databases on an explicitly supplied **disposable localhost** PostgreSQL server.
It exercises current migrations, SQL-error rollback, changed migration rejection,
and the GeoIP loader with one million synthetic rows. Example after starting an
isolated PostgreSQL instance and ensuring `psql` is on PATH:

```sh
TILESENSE_TEST_DB_URI='postgresql://postgres:local-test-only@127.0.0.1:15439/postgres?sslmode=disable' \
  python3 -B -m unittest discover -s server/deploy -p 'test_*.py' -v
```
