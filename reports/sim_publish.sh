#!/usr/bin/env bash
# Copies the local sim results (reports/sim_run.sh) into a `sim` schema in the
# production telemetry database, so the production Metabase's existing
# connection can query them through metabase_ro (e.g. sim.sim_report).
# Nothing outside the sim schema is touched, and server/migrations (which
# only manage public) never touch it. Safe to re-run: rows already published
# are skipped, and nothing is deleted. To remove it all:
# drop schema sim cascade.
#
#   SIM_PGPASSWORD=<local-only> reports/sim_publish.sh
#
# Uses deploy.env (DB_ID, DROPLET_IP) and the same trusted path as deploy.sh:
# doctl for the admin URI, psql on the Droplet (the cluster only admits it).
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SIM_PGPASSWORD:?set SIM_PGPASSWORD, the sim container password}"
source deploy.env
: "${DB_ID:?}" "${DROPLET_IP:?}"
SSH=(ssh -o BatchMode=yes "root@$DROPLET_IP")

# libpq settings for the Droplet, built like remote.py's database_env: the
# password goes through environment variables, never argv.
PGENV=$(doctl databases connection "$DB_ID" --format URI --no-header | python3 -c '
import shlex, sys
from urllib.parse import unquote, urlsplit
u = urlsplit(sys.stdin.read().strip())
env = dict(PGHOST=u.hostname, PGPORT=str(u.port or 5432), PGUSER=unquote(u.username),
           PGPASSWORD=unquote(u.password), PGDATABASE=unquote(u.path.lstrip("/")), PGSSLMODE="require")
print("export " + " ".join(f"{k}={shlex.quote(v)}" for k, v in env.items()))')

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
export PGHOST=127.0.0.1 PGPORT=15439 PGUSER=postgres PGDATABASE=postgres PGPASSWORD=$SIM_PGPASSWORD
psql -X -v ON_ERROR_STOP=1 -c "\copy (select arm_id, engine_commit, ruleset, minimum, game_length, decision_maker, style, focus, strategy from sim_arm) to '$WORK/arms.csv' csv"
psql -X -v ON_ERROR_STOP=1 -c "\copy sim_game to '$WORK/games.csv' csv"
cp reports/sim_schema.sql "$WORK/"

REMOTE=$("${SSH[@]}" mktemp -d)
scp -q -o BatchMode=yes "$WORK"/{arms.csv,games.csv,sim_schema.sql} "root@$DROPLET_IP:$REMOTE/"
# Credentials travel on stdin, never in argv.
"${SSH[@]}" bash -s <<REMOTE_SCRIPT
set -euo pipefail
trap 'rm -rf "$REMOTE"' EXIT
$PGENV PGCONNECT_TIMEOUT=15
export PGOPTIONS='-c client_min_messages=warning'
psql -X -q -v ON_ERROR_STOP=1 -c 'create schema if not exists sim'
# Every sim object is created in, and resolved from, the sim schema.
export PGOPTIONS='-c client_min_messages=warning -c search_path=sim'
psql -X -q -v ON_ERROR_STOP=1 -f "$REMOTE/sim_schema.sql"
psql -X -q -v ON_ERROR_STOP=1 --single-transaction <<'SQL'
create temp table arm_stage (arm_id smallint, engine_commit text, ruleset text, minimum smallint,
  game_length text, decision_maker text, style text, focus text, strategy text);
create temp table game_stage (like sim_game);
\copy arm_stage from '$REMOTE/arms.csv' csv
\copy game_stage from '$REMOTE/games.csv' csv
-- Keep local arm ids so games land on the same arm; stop if an id already
-- means a different arm here.
insert into sim_arm (arm_id, engine_commit, ruleset, minimum, game_length,
                     decision_maker, style, focus, strategy)
overriding system value
select * from arm_stage on conflict do nothing;
do \$\$ begin
  if exists (select 1 from arm_stage s join sim_arm a using (arm_id)
             where (a.engine_commit, a.ruleset, a.minimum, a.game_length, a.decision_maker,
                    a.style, a.focus, a.strategy)
                   is distinct from
                   (s.engine_commit, s.ruleset, s.minimum, s.game_length, s.decision_maker,
                    s.style, s.focus, s.strategy))
  then raise exception 'arm ids differ between local and production; nothing published'; end if;
end \$\$;
insert into sim_game select * from game_stage on conflict do nothing;
grant usage on schema sim to metabase_ro;
grant select on all tables in schema sim to metabase_ro;
alter default privileges in schema sim grant select on tables to metabase_ro;
select format('published: %s games in %s arms', count(*), count(distinct arm_id)) from sim_game;
SQL
REMOTE_SCRIPT
