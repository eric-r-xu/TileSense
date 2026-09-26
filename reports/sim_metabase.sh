#!/usr/bin/env bash
# Runs a local Metabase at http://localhost:3000 that queries the sim database
# (reports/sim_run.sh) through a read-only role. Safe to re-run.
#
#   SIM_PGPASSWORD=<local-only> SIM_METABASE_PASSWORD=<local-only> reports/sim_metabase.sh
#
# Then in Metabase: Add a database -> PostgreSQL, host tilesense-sim, port 5432,
# database postgres, user metabase_ro, password $SIM_METABASE_PASSWORD, SSL off.
# Query sim_report (one row per report line) or sim_game_detail (one per game).
set -euo pipefail
: "${SIM_PGPASSWORD:?set SIM_PGPASSWORD, the sim container password}"
: "${SIM_METABASE_PASSWORD:?set SIM_METABASE_PASSWORD, a local-only password for metabase_ro}"
export PGHOST=127.0.0.1 PGPORT=15439 PGUSER=postgres PGDATABASE=postgres
export PGPASSWORD=$SIM_PGPASSWORD

# Read-only role, as for the production Metabase (server/DEPLOYMENT.md §6.3).
# \getenv keeps the password out of argv.
psql -X -q -v ON_ERROR_STOP=1 <<'SQL'
\getenv ro_password SIM_METABASE_PASSWORD
select format('create role metabase_ro login password %L', :'ro_password')
where not exists (select from pg_roles where rolname = 'metabase_ro') \gexec
select format('alter role metabase_ro password %L', :'ro_password') \gexec
grant connect on database postgres to metabase_ro;
grant usage on schema public to metabase_ro;
grant select on all tables in schema public to metabase_ro;
alter default privileges in schema public grant select on tables to metabase_ro;
SQL

# A shared network lets Metabase reach the database by container name.
docker network inspect tilesense-sim-net >/dev/null 2>&1 ||
  docker network create tilesense-sim-net >/dev/null
docker inspect -f '{{json .NetworkSettings.Networks}}' tilesense-sim | grep -q tilesense-sim-net ||
  docker network connect tilesense-sim-net tilesense-sim

# Metabase keeps its own questions and dashboards in an H2 file on a named
# volume, which is fine for one local user (production uses Postgres).
if ! docker container inspect tilesense-metabase >/dev/null 2>&1; then
  docker run -d --name tilesense-metabase --network tilesense-sim-net \
    -p 127.0.0.1:3000:3000 -e MB_DB_FILE=/metabase-data/metabase.db \
    -v tilesense-metabase-data:/metabase-data "metabase/metabase:${MB_VERSION:-latest}" >/dev/null
fi
docker start tilesense-metabase >/dev/null
until curl -fsS http://127.0.0.1:3000/api/health >/dev/null 2>&1; do sleep 2; done
echo "Metabase is up at http://localhost:3000"
