# Deployment guide

`deploy.sh` is the supported production deployment entrypoint. It delegates to
`server/deploy/deploy.py` and a locked SSH worker, `server/deploy/remote.py`.
It does not upload generated files into the digitalOcean Git checkout.

## Configuration

Keep the ignored `deploy.env` in the repository root. Start from the tracked
template, `cp deploy.env.example deploy.env`, and fill in its placeholders:

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
blindly. A dirty checkout asks whether to continue when run at a terminal;
`ALLOW_DIRTY_DEPLOY=1` allows it up front, and is required without a terminal.
Release metadata records that exception, so a commit ID alone will not
reproduce it.

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
./deploy.sh mp                    # asks you to press Enter first
./deploy.sh all                   # likewise
```

Multiplayer restarts disconnect active rooms, so `mp` and `all` warn and wait
for Enter before building anything (Ctrl-C cancels). `ALLOW_MP_RESTART=1`
acknowledges it up front instead and skips the prompt; without a terminal
(scripts, cron, CI) that flag is required, and the deploy refuses otherwise.
Schedule those releases when disruption is acceptable.

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

## Automatic deploys (GitHub Actions)

`.github/workflows/deploy.yml` runs this same `./deploy.sh` from GitHub:

- **Automatically:** `client`, after the CI workflow passes on a push to
  `ericrxu_dev`. It deploys exactly the commit CI tested, and skips it if
  `ericrxu_dev` has already moved on (the newer push's own CI run deploys that).
  Pull requests never deploy.
- **By hand** (Actions tab → Deploy → Run workflow): `mp`, which drops live
  online rooms (choosing it is the `ALLOW_MP_RESTART=1` acknowledgement), and
  `rollback-client`, `rollback-ingest` and `rollback-mp` with a release ID.
- **Laptop only:** `ingest`, `migrate`, `geoip`, `all` and `setup-client`. The
  first four need doctl and database credentials, which are kept off GitHub.

Deploys queue and are never cancelled midway. The droplet's own lock still
serializes them against a deploy started from the laptop. Each run's release ID
is shown in the run's summary, for a later `rollback-client`.

### One-time setup

1. Make a key used only for deploys, and authorize it on the droplet:

   ```sh
   ssh-keygen -t ed25519 -f tilesense_deploy -N "" -C tilesense-github-deploy
   ssh root@$DROPLET_IP 'cat >> /root/.ssh/authorized_keys' < tilesense_deploy.pub
   ```

2. Pin the droplet's host key. Check the fingerprint of the scan against the
   droplet's own before trusting it:

   ```sh
   ssh-keyscan -t ed25519 $DROPLET_IP > known_hosts_droplet
   ssh-keygen -lf known_hosts_droplet
   ssh root@$DROPLET_IP 'ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub'
   ```

3. In GitHub, Settings → Environments → **New environment** `production`:
   - **Deployment branches:** selected branches, `ericrxu_dev` only.
   - **Secrets:** `DEPLOY_SSH_KEY` (the contents of `tilesense_deploy`, the
     private key), `SSH_KNOWN_HOSTS` (the contents of `known_hosts_droplet`),
     `HOST`, `DROPLET_IP` and `DART_IMAGE` (the same values as `deploy.env`).
   - **Required reviewers** (optional): approve each deploy with one click.

   Then delete the local copies of `tilesense_deploy` and `known_hosts_droplet`.

4. Firewall: GitHub's runners have no fixed IP. If a DigitalOcean firewall
   limits SSH to your own address, runners are blocked. Either allow SSH from
   anywhere (key-only; password login must stay off), or add Tailscale to the
   workflow so the runner joins your private network (more secure).

The workflow runs once it is on `ericrxu_dev`: GitHub only reads
`workflow_run` workflows from the default branch. Try it first with a manual
run of `client`.

**To pause it:** Actions → Deploy → ⋯ → Disable workflow. **To revoke it:**
delete the `tilesense-github-deploy` line from `/root/.ssh/authorized_keys` on
the droplet.

## Recovery and retention

```sh
./deploy.sh rollback-client <previous-release-id>
./deploy.sh rollback-ingest <previous-release-id>
./deploy.sh rollback-mp <previous-release-id>   # drops active rooms, like deploy.sh mp
```

Service rollbacks reinstall the binary (and, for mp, the unit) that an earlier
`ingest`/`mp` deploy left in `/srv/tilesense/.staging/<release-id>/`, so the ID
must be one printed by a deploy that included that service. They do not touch
the database.

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
