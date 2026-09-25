#!/usr/bin/env python3
"""TileSense deployment orchestration. No production action at import time."""
import argparse
import datetime
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.request
import uuid

REPO = Path(__file__).resolve().parents[2]
BASE = '/tilesense/'


def run(args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)


def output(args, **kwargs):
    return subprocess.check_output(args, text=True, **kwargs).strip()


def required(name):
    value = os.environ.get(name, '')
    if not value:
        raise ValueError('deploy.env is missing ' + name)
    return value


def config(target):
    host = required('HOST')
    droplet = required('DROPLET_IP')
    for value in (host, droplet):
        if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9.-]*', value):
            raise ValueError('HOST and DROPLET_IP must be plain hostnames or IPv4 addresses')
    if os.environ.get('BASE_HREF', BASE) != BASE:
        raise ValueError('This release layout currently supports BASE_HREF=/tilesense/ only')
    # Never silently honor the former destructive rsync destination.
    if target in ('client', 'all', 'setup-client') and os.environ.get('SERVED_DIR'):
        print('SERVED_DIR is obsolete; release uploads always go to /srv/tilesense.', file=sys.stderr)
    return host, droplet


class Remote:
    def __init__(self, droplet):
        self.destination = 'root@' + droplet
        self.options = ['-o', 'BatchMode=yes', '-o', 'ConnectTimeout=15',
                        '-o', 'ServerAliveInterval=15', '-o', 'ServerAliveCountMax=3']
        script = (REPO / 'server/deploy/remote.py').read_text()
        self.process = subprocess.Popen(
            ['ssh', *self.options, self.destination, 'python3 -u -c ' + shlex.quote(script)],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
        self.receive()  # remote process acquires flock before accepting requests

    def receive(self):
        line = self.process.stdout.readline()
        if not line:
            raise RuntimeError('SSH worker stopped (another deployment may hold the lock)')
        result = json.loads(line)
        if not result['ok']:
            raise RuntimeError(result['error'])
        return result.get('result', {})

    def call(self, action, **values):
        self.process.stdin.write(json.dumps({'action': action, **values}) + '\n')
        self.process.stdin.flush()
        return self.receive()

    def upload(self, source, destination):
        # Upload only to a freshly-created stage, never delete anything on the server.
        run(['rsync', '-rlptz', '--chmod=D755,F644', '-e',
             shlex.join(['ssh', *self.options]), str(source),
             self.destination + ':' + destination])

    def close(self):
        if self.process.stdin:
            self.process.stdin.close()
        try:
            status = self.process.wait(timeout=45)
            if status != 0:
                raise RuntimeError('SSH worker failed; inspect server rollback diagnostics')
        except subprocess.TimeoutExpired:
            self.process.terminate()
            self.process.wait(timeout=10)


def http_get(url):
    request = urllib.request.Request(url, headers={'Cache-Control': 'no-cache'})
    for attempt in range(5):
        try:
            with urllib.request.urlopen(request, timeout=10) as response:
                if response.status != 200:
                    raise ValueError('Expected HTTP 200')
                return response.read()
        except Exception:
            if attempt == 4:
                raise
            time.sleep(1)


def check_release(host, rid, staged=False):
    prefix = BASE + 'releases/' + rid + '/' if staged else BASE
    body = http_get('https://' + host + prefix + 'build_id.json?t=' + uuid.uuid4().hex)
    if json.loads(body).get('build_id') != rid:
        raise ValueError('Served build ID does not match the candidate release')
    html = http_get('https://' + host + prefix).decode()
    if f'<base href="{BASE}releases/{rid}/">' not in html:
        raise ValueError('Served HTML does not reference the candidate release')
    for name in ('flutter_bootstrap.js', 'main.dart.js', 'assets/FontManifest.json'):
        http_get('https://' + host + BASE + 'releases/' + rid + '/' + name)


def stamp_client(web, rid, revision, dirty, toolchain):
    (web / 'build_id.json').write_text(json.dumps({'build_id': rid}))
    manifest_path = web / 'manifest.json'
    manifest = json.loads(manifest_path.read_text())
    # Installed PWAs continue to open the stable URL; icons remain relative to this release.
    manifest.update(start_url=BASE, scope=BASE, id=BASE)
    manifest_path.write_text(json.dumps(manifest))
    run(['python3', str(REPO / 'flutter_client/tools/fingerprint_fonts.py'), str(web)])
    run(['python3', str(REPO / 'flutter_client/tools/precompress_web.py'), str(web)])
    manifest = {'build_id': rid, 'git_commit': revision, 'dirty': dirty,
                'toolchain': toolchain, 'files': {}}
    for p in sorted(web.rglob('*')):
        if p.is_symlink():
            raise ValueError('Symlinks are not allowed in a web artifact')
        if p.is_file() and p.name != 'deploy-manifest.json':
            manifest['files'][str(p.relative_to(web))] = hashlib.sha256(p.read_bytes()).hexdigest()
    (web / 'deploy-manifest.json').write_text(json.dumps(manifest, indent=2))


def build_client(work, rid, revision, dirty):
    client = REPO / 'flutter_client'
    toolchain = json.loads(output(['flutter', '--version', '--machine']))
    version = next(line.split(':', 1)[1].strip() for line in
                   (client / 'pubspec.yaml').read_text().splitlines() if line.startswith('version:'))
    run(['flutter', 'build', 'web', '--release', '--pwa-strategy=none',
         '--base-href', BASE + 'releases/' + rid + '/',
         '--dart-define=BUILD_ID=' + rid, '--dart-define=APP_VERSION=' + version,
         '--dart-define=UPDATE_BASE_HREF=' + BASE], cwd=client)
    web = work / 'web'
    shutil.copytree(client / 'build/web', web)
    stamp_client(web, rid, revision, dirty, toolchain)
    return web


def build_service(work, name):
    # Exact SDK tag is required; mutable dart:stable is deliberately not a default.
    image = required('DART_IMAGE')
    if not re.fullmatch(r'dart:[0-9]+\.[0-9]+\.[0-9]+(?:@sha256:[a-f0-9]{64})?', image):
        raise ValueError('Set DART_IMAGE to an exact SDK tag, optionally with a digest')
    run(['docker', 'info'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    directory, source = ('server', 'server.dart') if name == 'tilesense-ingest' else ('server/mp', 'mp_server.dart')
    # Repository is read-only. Generated binaries never modify tracked source files.
    command = (f'cp -r /repo/server /build/server && cp -r /repo/packages /build/packages && '
               f'cd /build/{directory} && dart pub get --enforce-lockfile && '
               f'dart compile exe bin/{source} -o /out/{name}')
    run(['docker', 'run', '--rm', '--platform', 'linux/amd64',
         '-v', str(REPO) + ':/repo:ro', '-v', str(work) + ':/out', '-w', '/build',
         image, 'sh', '-c', command])
    binary = work / name
    header = binary.read_bytes()[:20]
    if header[:4] != b'\x7fELF' or header[4:6] != b'\x02\x01' or header[18:20] != b'\x3e\x00':
        raise ValueError('Expected a Linux x86-64 ELF binary')
    if name == 'tilesense-mp':
        shutil.copy2(REPO / 'server/mp/deploy/tilesense-mp.service', work / (name + '.service'))


def download_geoip(work):
    import gzip
    today = datetime.datetime.now(datetime.timezone.utc).date()
    previous = today.replace(day=1) - datetime.timedelta(days=1)
    archive = work / 'geoip.csv.gz'
    for month in (today.strftime('%Y-%m'), previous.strftime('%Y-%m')):
        try:
            with urllib.request.urlopen('https://download.db-ip.com/free/dbip-city-lite-' + month + '.csv.gz', timeout=60) as response, archive.open('wb') as target:
                shutil.copyfileobj(response, target)
            with gzip.open(archive, 'rb') as source:
                rows = sum(1 for _ in source)
            if rows < 1000000:
                raise ValueError('GeoIP download is incomplete')
            shutil.copy2(REPO / 'server/deploy/load-geoip.sql', work / 'load-geoip.sql')
            return hashlib.sha256(archive.read_bytes()).hexdigest()
        except Exception:
            archive.unlink(missing_ok=True)
    raise ValueError('Unable to download a complete current or previous month GeoIP city database')


def source_state():
    revision = output(['git', 'rev-parse', 'HEAD'], cwd=REPO)
    dirty = bool(output(['git', 'status', '--porcelain'], cwd=REPO))
    if dirty and os.environ.get('ALLOW_DIRTY_DEPLOY') != '1':
        raise ValueError('Source checkout has changes. Commit them, or explicitly set ALLOW_DIRTY_DEPLOY=1; releases record this exception.')
    return revision, dirty


def deploy(target, host, droplet, rollback=None):
    needs_client = target in ('all', 'client')
    needs_ingest = target in ('all', 'ingest')
    needs_mp = target in ('all', 'mp')
    needs_geoip = target == 'geoip'
    if needs_mp and os.environ.get('ALLOW_MP_RESTART') != '1':
        raise ValueError('Multiplayer restart disconnects active rooms. Set ALLOW_MP_RESTART=1 to acknowledge it.')
    rid = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ-') + uuid.uuid4().hex[:8]
    with tempfile.TemporaryDirectory(prefix='tilesense-deploy-') as directory:
        work = Path(directory)
        # Finish all requested builds before connecting to the production deploy worker.
        if needs_client or needs_ingest or needs_mp:
            revision, dirty = source_state()
            if needs_client:
                build_client(work, rid, revision, dirty)
            if needs_ingest:
                build_service(work, 'tilesense-ingest')
            if needs_mp:
                build_service(work, 'tilesense-mp')
            (work / 'release.json').write_text(json.dumps({'build_id': rid, 'git_commit': revision,
                'dirty': dirty, 'dart_image': os.environ.get('DART_IMAGE')}))
        geoip_digest = download_geoip(work) if needs_geoip else None
        uri = None
        migrations = None
        if target == 'migrate' or needs_ingest or needs_geoip:
            uri = output(['doctl', 'databases', 'connection', required('DB_ID'), '--format', 'URI', '--no-header'])
            migrations = [{'name': p.name, 'sql': p.read_text()} for p in sorted((REPO / 'server/migrations').glob('*.sql'))]
            if not migrations:
                raise ValueError('No migrations found')
        remote = Remote(droplet)
        previous = None
        try:
            if target == 'setup-client':
                result = remote.call('setup-client')
                body = http_get('https://' + host + BASE)
                if hashlib.sha256(body).hexdigest() != result['index_sha256']:
                    raise ValueError('Hosting transition did not preserve the served index')
                print(result)
                remote.call('commit')
                return
            if target == 'rollback-client':
                if not rollback:
                    raise ValueError('rollback-client requires a release ID')
                previous = remote.call('activate', id=rollback)['previous']
                check_release(host, rollback)
                remote.call('commit')
                return
            if needs_client:
                remote.call('preflight-client')
            if needs_client or needs_ingest or needs_mp or needs_geoip:
                stage = remote.call('stage', id=rid)['path']
                remote.upload(str(work) + '/', stage + '/')
            if needs_client:
                remote.call('publish', id=rid)
                check_release(host, rid, staged=True)
            if migrations is not None:
                remote.call('migrate', uri=uri, migrations=migrations)
            if needs_geoip:
                print(remote.call('geoip', id=rid, uri=uri, digest=geoip_digest))
            for name, enabled in [('tilesense-ingest', needs_ingest), ('tilesense-mp', needs_mp)]:
                if enabled:
                    remote.call('service', id=rid, name=name)
            if needs_client:
                previous = remote.call('activate', id=rid)['previous']
                check_release(host, rid)
            remote.call('commit')
            print('Deployment verified: ' + rid)
        except BaseException:
            print('Deployment failed; closing SSH triggers restoration of uncommitted client/service changes. '
                  'Successful additive migrations remain applied.', file=sys.stderr)
            raise
        finally:
            remote.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('target', nargs='?', default='all', choices=[
        'all', 'client', 'ingest', 'mp', 'migrate', 'geoip', 'setup-client', 'rollback-client'])
    parser.add_argument('release', nargs='?')
    args = parser.parse_args()
    if (args.target == 'rollback-client') != (args.release is not None):
        parser.error('Only rollback-client accepts and requires a release ID')
    host, droplet = config(args.target)
    # Serialize local builds as well as remote activation; kernel releases locks after crashes.
    lock_path = Path(tempfile.gettempdir()) / ('tilesense-' + hashlib.sha256(str(REPO).encode()).hexdigest()[:16] + '.lock')
    with lock_path.open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        deploy(args.target, host, droplet, args.release)


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        # Avoid printing subprocess arguments: connection commands may contain credentials.
        print('Deployment failed: ' + (str(error) if isinstance(error, (ValueError, RuntimeError)) else type(error).__name__), file=sys.stderr)
        sys.exit(1)
