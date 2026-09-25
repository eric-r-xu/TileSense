"""Opt-in tests against a disposable localhost PostgreSQL server.

Set TILESENSE_TEST_DB_URI to an admin connection URI. Each test uses a new,
randomly named database and drops it afterward; never use production credentials.
The ordinary offline suite skips these tests.
"""
import gzip
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import uuid
from urllib.parse import urlsplit, urlunsplit

from test_deploy import remote

URI = os.environ.get('TILESENSE_TEST_DB_URI', '')
REPO = Path(__file__).resolve().parents[2]


@unittest.skipUnless(URI, 'Set TILESENSE_TEST_DB_URI to a disposable localhost PostgreSQL server')
class DatabaseIntegrationTests(unittest.TestCase):
    def setUp(self):
        parts = urlsplit(URI)
        if parts.hostname not in ('127.0.0.1', 'localhost', '::1'):
            self.fail('Integration tests require a localhost database')
        self.name = 'tilesense_deploy_test_' + uuid.uuid4().hex
        self.admin_env = remote.database_env(URI)
        subprocess.run(['psql', '-X', '-v', 'ON_ERROR_STOP=1', '-c', 'CREATE DATABASE ' + self.name],
                       env=self.admin_env, check=True, capture_output=True)
        self.addCleanup(self.drop_database)
        self.uri = urlunsplit(parts._replace(path='/' + self.name))
        self.env = remote.database_env(self.uri)
        self.migrations = [{'name': p.name, 'sql': p.read_text()}
                           for p in sorted((REPO / 'server/migrations').glob('*.sql'))]
        remote.migrate(self.uri, self.migrations)

    def drop_database(self):
        subprocess.run(['psql', '-X', '-v', 'ON_ERROR_STOP=1', '-c', 'DROP DATABASE ' + self.name + ' WITH (FORCE)'],
                       env=self.admin_env, check=True, capture_output=True)

    def query(self, sql):
        return subprocess.check_output(['psql', '-XAt', '-v', 'ON_ERROR_STOP=1', '-c', sql],
                                       env=self.env, text=True).strip()

    def test_repeatability_atomic_failure_and_checksum_enforcement(self):
        remote.migrate(self.uri, self.migrations)
        self.assertEqual(self.query('SELECT count(*) FROM tilesense_schema_migrations'), str(len(self.migrations)))
        with self.assertRaises(subprocess.CalledProcessError):
            remote.migrate(self.uri, [{'name': '9999_failure.sql', 'sql':
                                      'CREATE TABLE should_rollback(id int); SELECT nonexistent_column FROM sessions;'}])
        self.assertEqual(self.query("SELECT to_regclass('should_rollback') IS NULL"), 't')
        self.assertEqual(self.query("SELECT count(*) FROM tilesense_schema_migrations WHERE name='9999_failure.sql'"), '0')
        with self.assertRaises(subprocess.CalledProcessError):
            remote.migrate(self.uri, [{**self.migrations[0], 'sql': self.migrations[0]['sql'] + '\n-- changed'}])

    def test_geoip_upload_swap_and_backfill(self):
        self.query("INSERT INTO clients(client_id) VALUES ('00000000-0000-0000-0000-000000000001'); "
                   "INSERT INTO sessions(session_id,client_id,ip_prefix) VALUES "
                   "('00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','1.0.0.0/24')")
        with tempfile.TemporaryDirectory() as directory:
            stage = Path(directory)
            shutil.copy2(REPO / 'server/deploy/load-geoip.sql', stage / 'load-geoip.sql')
            archive = stage / 'geoip.csv.gz'
            with gzip.open(archive, 'wb') as stream:
                for _ in range(1000):
                    stream.write(b'1.0.0.0,1.0.0.255,NA,US,TestRegion,TestCity,0,0\n' * 1000)
            result = remote.load_geoip(stage, self.uri, hashlib.sha256(archive.read_bytes()).hexdigest())
            self.assertEqual(result['geoip_rows'], 1000000)
        self.assertEqual(self.query("SELECT geo_country||'/'||geo_region||'/'||geo_city FROM sessions"),
                         'US/TestRegion/TestCity')


if __name__ == '__main__':
    unittest.main()
