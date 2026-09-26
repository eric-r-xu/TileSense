#!/usr/bin/env bash
# Plays the stats-report games not yet stored and loads them into a local
# PostgreSQL 16 container (tilesense-sim, 127.0.0.1:15439). Games already in
# the database are skipped, so re-running the same seeds plays nothing and a
# larger SEED_COUNT plays only the new seeds.
#
#   SIM_PGPASSWORD=<local-only> SEED_START=500000 SEED_COUNT=200 reports/sim_run.sh
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SIM_PGPASSWORD:?set SIM_PGPASSWORD, a local-only password for the sim container}"
SEED_START=${SEED_START:-500000}
SEED_COUNT=${SEED_COUNT:-200}
export PGHOST=127.0.0.1 PGPORT=15439 PGUSER=postgres PGDATABASE=postgres
export PGPASSWORD=$SIM_PGPASSWORD POSTGRES_PASSWORD=$SIM_PGPASSWORD
psql_() { psql -X -q -v ON_ERROR_STOP=1 "$@"; }

# Results are keyed by the last commit that changed the engine, so a UI-only
# commit reuses stored games; the engine must be exactly that commit.
ENGINE=(flutter_client/lib/game flutter_client/lib/logic flutter_client/lib/net
        flutter_client/lib/telemetry packages/mahjong_core/lib)
if ! git diff --quiet HEAD -- "${ENGINE[@]}"; then
  echo "engine sources differ from HEAD; commit or stash them first" >&2
  exit 1
fi
COMMIT=$(git log -1 --format=%h -- "${ENGINE[@]}")

if ! docker container inspect tilesense-sim >/dev/null 2>&1; then
  # -e with no value reads the password from the environment, not argv.
  docker run -d --name tilesense-sim -p 127.0.0.1:15439:5432 -e POSTGRES_PASSWORD \
    -v tilesense-sim-data:/var/lib/postgresql/data postgres:16 >/dev/null
fi
docker start tilesense-sim >/dev/null
until pg_isready -q; do sleep 1; done
psql_ -f reports/sim_schema.sql

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
psql_ -At -F, -c "select a.arm_key, g.seed from sim_game g join sim_arm a using (arm_id)" \
  > "$WORK/skip.txt"

status=0
(cd flutter_client && REPORT_OUT="$WORK/games.csv" REPORT_SKIP="$WORK/skip.txt" \
  REPORT_COMMIT="$COMMIT" REPORT_SEED="$SEED_START" REPORT_GAMES="$SEED_COUNT" \
  flutter test test/stats_report_test.dart) || status=$?

# Load whatever finished, even after a failure: rows are appended per arm.
psql_ <<SQL
create temp table stage (
  engine_commit text, ruleset text, minimum smallint, game_length text,
  decision_maker text, style text, focus text, strategy text, seed int,
  place numeric(2,1), start_points int, end_points int, hands smallint,
  wins smallint, deal_ins smallint);
\copy stage from '$WORK/games.csv' csv
begin;
insert into sim_arm (engine_commit, ruleset, minimum, game_length,
                     decision_maker, style, focus, strategy)
select distinct engine_commit, ruleset, minimum, game_length,
                decision_maker, style, focus, strategy
from stage
on conflict do nothing;
insert into sim_game
select a.arm_id, s.seed, s.place, s.start_points, s.end_points, s.hands, s.wins, s.deal_ins
from stage s
join sim_arm a
  on (a.engine_commit, a.ruleset, a.minimum, a.game_length, a.decision_maker,
      a.style, a.focus, a.strategy)
     is not distinct from
     (s.engine_commit, s.ruleset, s.minimum, s.game_length, s.decision_maker,
      s.style, s.focus, s.strategy)
on conflict do nothing;
commit;
select format('stored games: %s in %s arms', count(*), count(distinct arm_id)) from sim_game;
SQL

unpaired=$(psql_ -At -c "select count(*) from sim_unpaired_games")
if [ "$unpaired" != 0 ]; then
  echo "$unpaired guide games have no control game on the same seed" >&2
  exit 1
fi
exit "$status"
