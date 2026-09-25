"""Offline regression tests. No SSH, production DB, or service restarts."""
import contextlib
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch, MagicMock

HERE = Path(__file__).parent

def load(name):
    spec = importlib.util.spec_from_file_location(name, HERE / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

remote = load('remote')
deploy = load('deploy')


def artifact(path, rid='test-release'):
    path.mkdir(parents=True)
    for name in ('index.html', 'flutter_bootstrap.js', 'main.dart.js', 'manifest.json'):
        (path / name).write_text('test')
    (path / 'build_id.json').write_text(json.dumps({'build_id': rid}))
    manifest = {'build_id': rid, 'files': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in path.iterdir()}}
    (path / 'deploy-manifest.json').write_text(json.dumps(manifest))


class RemoteTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name).resolve()
        self.patcher = patch.object(remote, 'ROOT', self.root)
        self.patcher.start()

    def tearDown(self):
        self.patcher.stop()
        self.tmp.cleanup()

    def test_release_id_rejects_paths_and_shell(self):
        for value in ('../x', '/srv/digitalOcean', 'x;rm', '', 'a b'):
            with self.assertRaises(ValueError): remote.release_id(value)

    def test_publish_activate_restore_keeps_old_assets(self):
        artifact(self.root / 'legacy', 'legacy')
        remote.switch(self.root / 'legacy')
        remote.handle({'action': 'stage', 'id': 'test-release'})
        artifact(self.root / '.staging/test-release/web')
        remote.handle({'action': 'publish', 'id': 'test-release'})
        self.assertEqual((self.root / 'current').resolve(), self.root / 'legacy')
        old = remote.handle({'action': 'activate', 'id': 'test-release'})['previous']
        self.assertEqual((self.root / 'current').resolve(), self.root / 'releases/test-release')
        remote.handle({'action': 'restore', 'id': 'test-release', 'previous': old})
        self.assertTrue((self.root / 'releases/test-release/main.dart.js').exists())
        self.assertTrue((self.root / 'legacy/main.dart.js').exists())

    def test_immutable_release_cannot_be_overwritten(self):
        artifact(self.root / '.staging/test-release/web')
        artifact(self.root / 'releases/test-release')
        with self.assertRaises(ValueError): remote.handle({'action': 'publish', 'id': 'test-release'})

    def test_checksum_detects_corruption(self):
        artifact(self.root / 'web')
        (self.root / 'web/main.dart.js').write_text('corruption')
        with self.assertRaises(ValueError): remote.validate_build(self.root / 'web')

    def test_checksum_detects_extra_files(self):
        artifact(self.root / 'web')
        (self.root / 'web/unexpected').touch()
        with self.assertRaises(ValueError): remote.validate_build(self.root / 'web')

    def test_missing_build_file_rejected(self):
        artifact(self.root / 'web')
        (self.root / 'web/index.html').unlink()
        with self.assertRaises(ValueError): remote.validate_build(self.root / 'web')

    def test_stage_collision_rejected(self):
        remote.handle({'action': 'stage', 'id': 'same'})
        with self.assertRaises(FileExistsError): remote.handle({'action': 'stage', 'id': 'same'})

    def test_rollback_path_restricted(self):
        with self.assertRaises(ValueError):
            remote.handle({'action': 'restore', 'id': 'x', 'previous': '/etc'})

    def test_nginx_preserves_other_routes(self):
        original = '''server { server_name app.ericrxu.com;
location /tilesense/ { alias /srv/digitalOcean/static/tilesense/; index index.html; }
location /tilesense/mp/ { proxy_pass http://127.0.0.1:8789/; }
location / { proxy_pass http://unix:/run/myproject/myproject.sock; }
}'''
        result = remote.nginx_config(original)
        self.assertIn('location /tilesense/mp/ { proxy_pass http://127.0.0.1:8789/; }', result)
        self.assertIn('proxy_pass http://unix:/run/myproject/myproject.sock;', result)
        self.assertIn('alias /srv/tilesense/legacy/', result)
        self.assertIn('location = /tilesense/build_id.json', result)
        self.assertEqual(remote.nginx_config(result), result)

    def test_nginx_ambiguous_or_unfamiliar_config_rejected(self):
        block = 'location /tilesense/ { alias /srv/digitalOcean/static/tilesense/; }'
        for value in ('location /tilesense/ { root /srv; }', block + block):
            with self.assertRaises(ValueError): remote.nginx_config(value)

    def test_nginx_validation_failure_restores_config(self):
        legacy = self.root / 'old'
        legacy.mkdir()
        (legacy / 'index.html').write_text('old')
        conf = self.root / 'nginx.conf'
        original = 'location /tilesense/ { alias /srv/digitalOcean/static/tilesense/; }'
        conf.write_text(original)
        fail = subprocess.CalledProcessError(1, ['nginx', '-t'])
        with patch.object(remote, 'NGINX', conf), patch.object(remote, 'LEGACY', legacy), \
                patch.object(remote, 'run', side_effect=[None, fail, None, None]):
            with self.assertRaises(subprocess.CalledProcessError): remote.setup_client()
        self.assertEqual(conf.read_text(), original)
        self.assertTrue(list(self.root.glob('nginx.conf.before-releases-*')))
        self.assertEqual((legacy / 'index.html').read_text(), 'old')

    def test_migration_uses_transaction_error_stop_and_hidden_credentials(self):
        with patch.object(remote, 'run') as run:
            remote.migrate('postgresql://user:secret@db.example:25060/app?sslmode=require',
                           [{'name': '0001_test.sql', 'sql': 'create table example(id int);'}])
        args, kwargs = run.call_args
        self.assertIn('ON_ERROR_STOP=1', args[0])
        self.assertIn('--single-transaction', args[0])
        self.assertNotIn('secret', str(args))
        self.assertEqual(kwargs['env']['PGPASSWORD'], 'secret')
        self.assertIn(b'pg_advisory_xact_lock', kwargs['input'])
        self.assertIn(b'tilesense_schema_migrations', kwargs['input'])

    def test_nontransactional_migration_rejected(self):
        with patch.object(remote, 'run') as run:
            with self.assertRaises(ValueError):
                remote.migrate('postgresql://u:p@db/app', [{'name': '0001_bad.sql', 'sql': 'CREATE INDEX CONCURRENTLY x ON y(z);'}])
        run.assert_not_called()

    def test_worker_disconnect_rolls_back_activation(self):
        artifact(self.root / 'legacy', 'legacy')
        artifact(self.root / 'releases/new', 'new')
        remote.switch(self.root / 'legacy')
        command = json.dumps({'action': 'activate', 'id': 'new'}) + '\n'
        with patch('sys.stdin', io.StringIO(command)), contextlib.redirect_stdout(io.StringIO()):
            remote.main()
        self.assertEqual((self.root / 'current').resolve(), self.root / 'legacy')

    def test_worker_commit_keeps_activation(self):
        artifact(self.root / 'legacy', 'legacy')
        artifact(self.root / 'releases/new', 'new')
        remote.switch(self.root / 'legacy')
        commands = '\n'.join(json.dumps(x) for x in [{'action': 'activate', 'id': 'new'}, {'action': 'commit'}]) + '\n'
        with patch('sys.stdin', io.StringIO(commands)), contextlib.redirect_stdout(io.StringIO()):
            remote.main()
        self.assertEqual((self.root / 'current').resolve(), self.root / 'releases/new')

    def test_service_failure_restores_binary_and_unit(self):
        stage = self.root / 'stage'
        bins = self.root / 'bin'
        units = self.root / 'units'
        for directory in (stage, bins, units): directory.mkdir()
        (bins / 'tilesense-mp').write_bytes(b'old-binary')
        (units / 'tilesense-mp.service').write_text('old-unit')
        (stage / 'tilesense-mp').write_bytes(b'new-binary')
        (stage / 'tilesense-mp.service').write_text('new-unit')
        fail = OSError('health failed')
        with patch.object(remote, 'BIN_DIR', bins), patch.object(remote, 'UNIT_DIR', units), \
             patch.object(remote, 'run'), patch.object(remote.time, 'sleep'), \
             patch.object(remote, 'service_health', side_effect=[fail] * 10 + [None]):
            with self.assertRaises(OSError): remote.install_service(stage, 'tilesense-mp')
        self.assertEqual((bins / 'tilesense-mp').read_bytes(), b'old-binary')
        self.assertEqual((units / 'tilesense-mp.service').read_text(), 'old-unit')
        self.assertEqual((stage / 'backup/tilesense-mp').read_bytes(), b'old-binary')

    def test_invalid_unit_does_not_replace_service(self):
        stage = self.root / 'stage'
        bins = self.root / 'bin'
        units = self.root / 'units'
        for directory in (stage, bins, units): directory.mkdir()
        (bins / 'tilesense-mp').write_bytes(b'old')
        (units / 'tilesense-mp.service').write_text('old')
        (stage / 'tilesense-mp').write_bytes(b'new')
        (stage / 'tilesense-mp.service').write_text('invalid')
        with patch.object(remote, 'BIN_DIR', bins), patch.object(remote, 'UNIT_DIR', units), \
             patch.object(remote, 'run', side_effect=subprocess.CalledProcessError(1, ['verify'])):
            with self.assertRaises(subprocess.CalledProcessError): remote.install_service(stage, 'tilesense-mp')
        self.assertEqual((bins / 'tilesense-mp').read_bytes(), b'old')

    def test_worker_signal_restores_uncommitted_release(self):
        artifact(self.root / 'legacy', 'legacy')
        artifact(self.root / 'releases/new', 'new')
        remote.switch(self.root / 'legacy')
        import sys
        script = "import sys; from pathlib import Path; sys.path.insert(0, sys.argv[1]); import remote; remote.ROOT=Path(sys.argv[2]); remote.main()"
        worker = subprocess.Popen([sys.executable, '-B', '-u', '-c', script, str(HERE), str(self.root)],
                                  stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            self.assertTrue(json.loads(worker.stdout.readline())['ok'])
            worker.stdin.write(json.dumps({'action':'activate', 'id':'new'}) + '\n'); worker.stdin.flush()
            self.assertTrue(json.loads(worker.stdout.readline())['ok'])
            worker.terminate()
            worker.wait(timeout=10)
            self.assertEqual((self.root / 'current').resolve(), self.root / 'legacy')
        finally:
            if worker.poll() is None: worker.kill(); worker.wait()
            worker.stdin.close(); worker.stdout.close(); worker.stderr.close()

    def test_geoip_bad_checksum_cannot_start_database_load(self):
        stage = self.root / 'stage'; stage.mkdir()
        (stage / 'geoip.csv.gz').write_bytes(b'bad')
        with patch.object(remote.subprocess, 'Popen') as process:
            with self.assertRaises(ValueError): remote.load_geoip(stage, 'unused', 'wrong')
        process.assert_not_called()

    def test_geoip_truncated_gzip_cannot_start_database_load(self):
        stage = self.root / 'stage'; stage.mkdir()
        payload = b'not-a-gzip-file'
        (stage / 'geoip.csv.gz').write_bytes(payload)
        with patch.object(remote.subprocess, 'Popen') as process:
            with self.assertRaises(OSError): remote.load_geoip(stage, 'unused', hashlib.sha256(payload).hexdigest())
        process.assert_not_called()


class DriverTests(unittest.TestCase):
    def test_client_config_needs_no_database(self):
        with patch.dict(os.environ, {'HOST': 'app.example.com', 'DROPLET_IP': '192.0.2.1'}, clear=True):
            self.assertEqual(deploy.config('client'), ('app.example.com', '192.0.2.1'))

    def test_unsafe_hostname_rejected(self):
        with patch.dict(os.environ, {'HOST': 'app.example.com', 'DROPLET_IP': 'host; whoami'}, clear=True):
            with self.assertRaises(ValueError): deploy.config('client')

    def test_dirty_source_requires_override(self):
        with patch.dict(os.environ, {}, clear=True), patch.object(deploy, 'output', side_effect=['abc', ' M file']):
            with self.assertRaises(ValueError): deploy.source_state()

    def test_health_check_rejects_wrong_build(self):
        with patch.object(deploy, 'http_get', return_value=b'{"build_id":"old"}'):
            with self.assertRaises(ValueError): deploy.check_release('host', 'new')

    def test_health_check_rejects_old_base(self):
        with patch.object(deploy, 'http_get', side_effect=[b'{"build_id":"new"}', b'<base href="/tilesense/">']):
            with self.assertRaises(ValueError): deploy.check_release('host', 'new')

    def test_build_failure_does_not_connect_to_production(self):
        with patch.object(deploy, 'source_state', return_value=('abc', False)), \
             patch.object(deploy, 'build_client', side_effect=ValueError('build failed')), \
             patch.object(deploy, 'Remote') as remote:
            with self.assertRaises(ValueError): deploy.deploy('client', 'host', 'ip')
        remote.assert_not_called()

    def test_mp_restart_requires_explicit_acknowledgement(self):
        # No terminal to ask at (a script, cron, CI): refuse without the flag.
        with patch.dict(os.environ, {}, clear=True), patch.object(deploy, 'Remote') as remote, \
             patch.object(deploy.sys, 'stdin', MagicMock(**{'isatty.return_value': False})), \
             patch('builtins.input') as prompt:
            with self.assertRaises(ValueError): deploy.deploy('mp', 'host', 'ip')
        prompt.assert_not_called()
        remote.assert_not_called()

    def test_mp_restart_enter_at_a_terminal_acknowledges(self):
        tty = MagicMock(**{'isatty.return_value': True})
        with patch.dict(os.environ, {}, clear=True), patch.object(deploy.sys, 'stdin', tty), \
             patch('builtins.input', return_value='') as prompt:
            deploy.confirm_mp_restart()
        prompt.assert_called_once()

    def test_mp_restart_cancel_at_the_prompt_stops_before_building(self):
        tty = MagicMock(**{'isatty.return_value': True})
        for cancel in (KeyboardInterrupt, EOFError):
            with patch.dict(os.environ, {}, clear=True), patch.object(deploy.sys, 'stdin', tty), \
                 patch('builtins.input', side_effect=cancel), \
                 patch.object(deploy, 'build_service') as build, patch.object(deploy, 'Remote') as remote:
                with self.assertRaises(ValueError): deploy.deploy('mp', 'host', 'ip')
            build.assert_not_called()
            remote.assert_not_called()

    def test_mp_restart_flag_skips_the_prompt(self):
        tty = MagicMock(**{'isatty.return_value': True})
        with patch.dict(os.environ, {'ALLOW_MP_RESTART': '1'}, clear=True), \
             patch.object(deploy.sys, 'stdin', tty), patch('builtins.input') as prompt:
            deploy.confirm_mp_restart()
        prompt.assert_not_called()

    def test_client_failure_does_not_commit_and_closes_worker(self):
        worker = MagicMock()
        worker.call.side_effect = lambda action, **kwargs: {'path': '/srv/tilesense/.staging/test'} if action == 'stage' else {}
        with patch.object(deploy, 'source_state', return_value=('abc', False)), \
             patch.object(deploy, 'build_client'), patch.object(deploy, 'Remote', return_value=worker), \
             patch.object(deploy, 'check_release', side_effect=ValueError('HTTP failed')):
            with self.assertRaises(ValueError): deploy.deploy('client', 'host', 'ip')
        self.assertNotIn('commit', [c.args[0] for c in worker.call.call_args_list])
        worker.close.assert_called_once()

    def test_all_builds_precede_remote_and_client_activates_last(self):
        events = []
        worker = MagicMock()
        def call(action, **kwargs):
            events.append(action)
            return {'path': '/stage', 'previous': '/legacy'}
        worker.call.side_effect = call
        def connect(*args):
            events.append('connect')
            return worker
        with patch.dict(os.environ, {'ALLOW_MP_RESTART': '1', 'DB_ID': 'test'}), \
             patch.object(deploy, 'source_state', return_value=('abc', False)), \
             patch.object(deploy, 'build_client', side_effect=lambda *a: events.append('build-client')), \
             patch.object(deploy, 'build_service', side_effect=lambda *a: events.append('build-service')), \
             patch.object(deploy, 'output', return_value='uri'), \
             patch.object(deploy, 'Remote', side_effect=connect), \
             patch.object(deploy, 'check_release'), \
             patch.object(deploy, 'REPO', Path(__file__).resolve().parents[2]):
            # Test fixture migration required for the staging copy.
            migration_dir = deploy.REPO / 'server/migrations'
            if not migration_dir.exists(): self.skipTest('migration files unavailable')
            deploy.deploy('all', 'host', 'ip')
        self.assertLess(events.index('build-service'), events.index('connect'))
        self.assertLess(events.index('migrate'), events.index('service'))
        self.assertLess(max(i for i, e in enumerate(events) if e == 'service'), events.index('activate'))
        self.assertEqual(events[-1], 'commit')


if __name__ == '__main__':
    unittest.main()
