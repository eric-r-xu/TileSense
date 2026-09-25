#!/usr/bin/env python3
"""Read JSON commands over SSH while holding one host-wide deployment lock.

Never logs credentials. All artifacts are staged under a unique release ID.
No runtime dependency beyond Python, flock (via fcntl), psql and systemd.
"""
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import time
from urllib.parse import urlsplit, unquote, parse_qsl

ROOT = Path('/srv/tilesense')
NGINX = Path('/etc/nginx/sites-enabled/myproject')
LEGACY = Path('/srv/digitalOcean/static/tilesense')
BIN_DIR = Path('/usr/local/bin')
UNIT_DIR = Path('/etc/systemd/system')
ID = re.compile(r'[A-Za-z0-9][A-Za-z0-9_-]{0,99}\Z')


def run(args, **kwargs):
    return subprocess.run(args, check=True, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, **kwargs)


def release_id(value):
    if not isinstance(value, str) or not ID.fullmatch(value):
        raise ValueError('Invalid release ID')
    return value


def switch(target):
    current = ROOT / 'current'
    if current.exists() and not current.is_symlink():
        raise ValueError('current must be a symlink')
    temporary = ROOT / '.current-next'
    temporary.unlink(missing_ok=True)
    temporary.symlink_to(target)
    os.replace(temporary, current)


def validate_build(path):
    for name in ('index.html', 'flutter_bootstrap.js', 'main.dart.js', 'build_id.json', 'manifest.json'):
        if not (path / name).is_file() or (path / name).stat().st_size == 0:
            raise ValueError('Incomplete client artifact: ' + name)
    manifest = json.loads((path / 'deploy-manifest.json').read_text())
    for name, digest in manifest['files'].items():
        part = Path(name)
        if part.is_absolute() or '..' in part.parts:
            raise ValueError('Invalid manifest path')
        if hashlib.sha256((path / part).read_bytes()).hexdigest() != digest:
            raise ValueError('Artifact checksum mismatch: ' + name)
    actual = {str(p.relative_to(path)) for p in path.rglob('*') if p.is_file()}
    if actual != set(manifest['files']) | {'deploy-manifest.json'}:
        raise ValueError('Unexpected artifact files')
    if json.loads((path / 'build_id.json').read_text())['build_id'] != manifest['build_id']:
        raise ValueError('Build IDs do not match')
    return manifest


def nginx_config(text):
    # Match only the known live alias, fail closed on an unfamiliar layout.
    marker = '# TileSense versioned releases'
    if marker in text:
        return text
    pattern = r'location /tilesense/\s*\{[^{}]*alias /srv/digitalOcean/static/tilesense/;[^{}]*\}'
    matches = list(re.finditer(pattern, text))
    if len(matches) != 1:
        raise ValueError('Expected exactly one legacy TileSense location in this vhost file')
    block = '''# TileSense versioned releases
    location = /tilesense/ { alias /srv/tilesense/current/; index index.html; add_header Cache-Control "no-store"; }
    location = /tilesense/index.html { alias /srv/tilesense/current/index.html; add_header Cache-Control "no-store"; }
    location = /tilesense/build_id.json { alias /srv/tilesense/current/build_id.json; add_header Cache-Control "no-store"; }
    location ^~ /tilesense/releases/ {
        alias /srv/tilesense/releases/;
        index index.html;
        gzip_static on;
        gzip_vary on;
        add_header Cache-Control "public, max-age=31536000, immutable";
    }
    # Keep pre-migration tabs working; never overwrite or prune this snapshot.
    location /tilesense/ {
        alias /srv/tilesense/legacy/;
        gzip_static on;
        gzip_vary on;
        add_header Cache-Control "no-cache";
    }'''
    m = matches[0]
    return text[:m.start()] + block + text[m.end():]


def setup_client():
    path = NGINX.resolve(strict=True)
    original = path.read_text()
    updated = nginx_config(original)
    if updated == original:
        if not (ROOT / 'current').is_symlink() or not (ROOT / 'legacy/index.html').is_file():
            raise ValueError('Existing release setup is incomplete')
        return {'configured': True, 'index_sha256': hashlib.sha256((ROOT / 'current/index.html').read_bytes()).hexdigest()}
    run(['nginx', '-t'])
    if (ROOT / 'legacy').exists():
        raise ValueError('Legacy snapshot already exists; inspect previous setup before retrying')
    shutil.copytree(LEGACY, ROOT / 'legacy')
    switch(ROOT / 'legacy')
    backup = path.with_name(path.name + '.before-releases-' + str(time.time_ns()))
    shutil.copy2(path, backup)
    try:
        path.write_text(updated)
        run(['nginx', '-t'])
        run(['systemctl', 'reload', 'nginx'])
    except BaseException:
        shutil.copy2(backup, path)
        run(['nginx', '-t'])
        run(['systemctl', 'reload', 'nginx'])
        raise
    return {'configured': True, 'nginx_backup': str(backup),
            'index_sha256': hashlib.sha256((ROOT / 'current/index.html').read_bytes()).hexdigest()}


def database_env(uri):
    # Execute on the already trusted Droplet; no database firewall changes.
    url = urlsplit(uri)
    if url.scheme not in ('postgres', 'postgresql') or not url.hostname:
        raise ValueError('Invalid PostgreSQL URI')
    env = os.environ.copy()
    env.update(PGHOST=url.hostname, PGPORT=str(url.port or 5432),
               PGUSER=unquote(url.username or ''), PGPASSWORD=unquote(url.password or ''),
               PGDATABASE=unquote(url.path.lstrip('/')), PGCONNECT_TIMEOUT='15')
    options = dict(parse_qsl(url.query))
    if set(options) - {'sslmode'}:
        raise ValueError('Unsupported connection options; review before migration')
    env['PGSSLMODE'] = options.get('sslmode', 'require')
    return env


def migrate(uri, migrations):
    env = database_env(uri)
    for item in migrations:
        name = item['name']
        if not re.fullmatch(r'[0-9]+_[a-z0-9_]+\.sql', name):
            raise ValueError('Invalid migration name')
        sql = item['sql']
        digest = hashlib.sha256(sql.encode()).hexdigest()
        # Current migrations are transactional; future exceptions need explicit review.
        if re.search(r'^\s*(BEGIN|COMMIT|ROLLBACK|VACUUM)\b|\bCONCURRENTLY\b|^\s*\\', sql, re.I | re.M):
            raise ValueError('Migration requires manual transaction review: ' + name)
        wrapped = f"""
SET LOCAL lock_timeout = '10s';
SET LOCAL statement_timeout = '120s';
SELECT pg_advisory_xact_lock(731604291);
CREATE TABLE IF NOT EXISTS tilesense_schema_migrations (
 name text PRIMARY KEY, checksum text NOT NULL, applied_at timestamptz NOT NULL DEFAULT now());
DO $$ BEGIN
 IF EXISTS (SELECT 1 FROM tilesense_schema_migrations WHERE name='{name}' AND checksum <> '{digest}')
 THEN RAISE EXCEPTION 'Previously applied migration changed'; END IF;
END $$;
SELECT NOT EXISTS (SELECT 1 FROM tilesense_schema_migrations WHERE name='{name}') AS apply_migration \\gset
\\if :apply_migration
{sql}
INSERT INTO tilesense_schema_migrations(name,checksum) VALUES ('{name}','{digest}');
\\endif
"""
        run(['psql', '-X', '-v', 'ON_ERROR_STOP=1', '--single-transaction', '-f', '-'],
            input=wrapped.encode(), env=env, timeout=150)
    return {'migrations_checked': len(migrations)}


def load_geoip(stage, uri, digest):
    import gzip
    import threading
    archive = stage / 'geoip.csv.gz'
    if hashlib.sha256(archive.read_bytes()).hexdigest() != digest:
        raise ValueError('GeoIP upload checksum mismatch')
    # Validate the whole gzip stream before psql can swap any tables.
    with gzip.open(archive, 'rb') as source:
        rows = sum(1 for _ in source)
    if rows < 1000000:
        raise ValueError('GeoIP file is incomplete')
    env = database_env(uri)
    stop = threading.Event()
    query = """select coalesce(
      (select format('upload: %s rows, %s', tuples_processed, pg_size_pretty(bytes_processed))
       from pg_stat_progress_copy limit 1),
      (select 'index: ' || phase from pg_stat_progress_create_index limit 1),
      (select format('statement running %s', date_trunc('second', now()-query_start))
       from pg_stat_activity where state='active' and usename=current_user
       and pid<>pg_backend_pid() order by query_start limit 1), 'between statements')"""
    def heartbeat():
        while not stop.wait(15):
            try:
                result = run(['psql', '-XAtq', '-c', query], env=env, timeout=10)
                print('[GeoIP heartbeat] ' + result.stdout.decode().strip(), file=sys.stderr, flush=True)
            except Exception:
                print('[GeoIP heartbeat] progress query unavailable', file=sys.stderr, flush=True)
    thread = threading.Thread(target=heartbeat, daemon=True)
    thread.start()
    process = subprocess.Popen(['psql', '-X', '-v', 'ON_ERROR_STOP=1', '-f', str(stage / 'load-geoip.sql')],
                               env=env, stdin=subprocess.PIPE, stdout=sys.stderr, stderr=sys.stderr)
    try:
        with gzip.open(archive, 'rb') as source:
            shutil.copyfileobj(source, process.stdin)
        process.stdin.close()
        if process.wait() != 0:
            raise ValueError('GeoIP load failed; inspect database progress/error output')
    except BaseException:
        process.terminate()
        process.wait(timeout=15)
        raise
    finally:
        stop.set()
        thread.join(timeout=12)
    return {'geoip_rows': rows}


def service_health(name):
    run(['systemctl', 'is-active', '--quiet', name])
    if name == 'tilesense-ingest':
        run(['curl', '--fail', '--silent', '--show-error', '--max-time', '5',
             'http://127.0.0.1:8787/healthz'])
    else:
        # The MP service has no health endpoint. Confirm it accepts loopback connections.
        import socket
        with socket.create_connection(('127.0.0.1', 8789), timeout=5):
            pass


def install_service(stage, name):
    if name not in ('tilesense-ingest', 'tilesense-mp'):
        raise ValueError('Invalid service')
    binary = stage / name
    dest = BIN_DIR / name
    unit = UNIT_DIR / (name + '.service')
    backup = stage / 'backup'
    backup.mkdir(exist_ok=True)
    if not dest.is_file() or not unit.is_file():
        raise ValueError('Existing service required; provision new services separately')
    shutil.copy2(dest, backup / name)
    shutil.copy2(unit, backup / unit.name)
    candidate_unit = stage / unit.name
    if candidate_unit.exists():
        run(['systemd-analyze', 'verify', str(candidate_unit)])
    try:
        temporary = dest.with_name(name + '.next')
        shutil.copy2(binary, temporary)
        temporary.chmod(0o755)
        os.replace(temporary, dest)
        if candidate_unit.exists():
            shutil.copy2(candidate_unit, unit)
            run(['systemctl', 'daemon-reload'])
        run(['systemctl', 'restart', name])
        for attempt in range(10):
            try:
                service_health(name)
                return {'service': name, 'backup': str(backup)}
            except (subprocess.SubprocessError, OSError):
                if attempt == 9:
                    raise
                time.sleep(1)
    except BaseException:
        temporary = dest.with_name(name + '.rollback')
        shutil.copy2(backup / name, temporary)
        os.replace(temporary, dest)
        shutil.copy2(backup / unit.name, unit)
        run(['systemctl', 'daemon-reload'])
        run(['systemctl', 'restart', name])
        service_health(name)
        raise


def rollback_service(stage, name):
    if name not in ('tilesense-ingest', 'tilesense-mp'):
        raise ValueError('Invalid service')
    dest = BIN_DIR / name
    unit = UNIT_DIR / (name + '.service')
    backup = stage / 'backup'
    temporary = dest.with_name(name + '.rollback')
    shutil.copy2(backup / name, temporary)
    os.replace(temporary, dest)
    shutil.copy2(backup / unit.name, unit)
    run(['systemctl', 'daemon-reload'])
    run(['systemctl', 'restart', name])
    service_health(name)
    return {}


def restore_nginx(backup):
    path = NGINX.resolve(strict=True)
    backup = Path(backup)
    if backup.parent != path.parent or not backup.name.startswith(path.name + '.before-releases-'):
        raise ValueError('Invalid Nginx backup')
    shutil.copy2(backup, path)
    run(['nginx', '-t'])
    run(['systemctl', 'reload', 'nginx'])
    return {}


def handle(message):
    action = message['action']
    if action == 'restore-nginx':
        return restore_nginx(message['backup'])
    if action == 'setup-client':
        return setup_client()
    if action == 'migrate':
        return migrate(message['uri'], message['migrations'])
    if action == 'preflight-client':
        if '# TileSense versioned releases' not in NGINX.resolve(strict=True).read_text():
            raise ValueError('Run deploy.sh setup-client once before publishing client releases')
        if not (ROOT / 'current').is_symlink():
            raise ValueError('Missing current release symlink')
        return {}
    rid = release_id(message['id'])
    stage = ROOT / '.staging' / rid
    if action == 'geoip':
        return load_geoip(stage, message['uri'], message['digest'])
    if action == 'stage':
        stage.mkdir(parents=True, exist_ok=False)
        return {'path': str(stage)}
    if action == 'rollback-service':
        return rollback_service(stage, message['name'])
    if action == 'service':
        return install_service(stage, message['name'])
    if action == 'publish':
        manifest = validate_build(stage / 'web')
        if manifest['build_id'] != rid:
            raise ValueError('Release ID mismatch')
        release = ROOT / 'releases' / rid
        if release.exists():
            raise ValueError('Release already exists; immutable releases cannot be overwritten')
        (ROOT / 'releases').mkdir(exist_ok=True)
        os.rename(stage / 'web', release)
        return {}
    if action == 'activate':
        target = ROOT / 'releases' / rid
        validate_build(target)
        previous = os.readlink(ROOT / 'current')
        switch(target)
        return {'previous': previous}
    if action == 'restore':
        target = Path(message['previous'])
        # Only restore a known local release, never an arbitrary client-supplied path.
        if target != ROOT / 'legacy' and target.parent != ROOT / 'releases':
            raise ValueError('Invalid rollback target')
        if not (target / 'index.html').is_file():
            raise ValueError('Rollback target missing')
        switch(target)
        return {}
    raise ValueError('Unknown action')


def main():
    def interrupted(signum, frame):
        signal.signal(signum, signal.SIG_IGN)
        raise SystemExit(128 + signum)
    for signum in (signal.SIGHUP, signal.SIGINT, signal.SIGTERM):
        signal.signal(signum, interrupted)
    ROOT.mkdir(parents=True, exist_ok=True)
    with (ROOT / '.deploy.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        print(json.dumps({'ok': True}), flush=True)
        undo = []
        try:
            for line in sys.stdin:
                try:
                    message = json.loads(line)
                    if message['action'] == 'commit':
                        undo.clear()
                        result = {}
                    else:
                        result = handle(message)
                        if message['action'] == 'activate':
                            undo.append({'action': 'restore', 'id': message['id'], 'previous': result['previous']})
                        elif message['action'] == 'service':
                            undo.append({'action': 'rollback-service', 'id': message['id'], 'name': message['name']})
                        elif message['action'] == 'setup-client' and 'nginx_backup' in result:
                            undo.append({'action': 'restore-nginx', 'backup': result['nginx_backup']})
                    print(json.dumps({'ok': True, 'result': result}), flush=True)
                except Exception as error:
                    detail = str(error) if isinstance(error, ValueError) else type(error).__name__
                    print(json.dumps({'ok': False, 'error': detail}), flush=True)
        finally:
            # EOF/SSH disconnect rolls back any activation not explicitly committed.
            for message in reversed(undo):
                try:
                    handle(message)
                except Exception:
                    print('ROLLBACK FAILED: ' + message['action'], file=sys.stderr)
                    raise


if __name__ == '__main__':
    main()
