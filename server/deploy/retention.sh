#!/usr/bin/env bash
# Nightly data-minimisation. Drops rows older than the window; the schema keeps
# no raw IPs so this is the whole retention story.
#   /usr/local/bin/tilesense-retention.sh
set -euo pipefail
: "${DATABASE_URL:?}"
WINDOW="${RETENTION_INTERVAL:-90 days}"

psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
delete from events   where occurred_at < now() - interval '$WINDOW';
delete from rounds   where coalesce(ended_at, started_at) < now() - interval '$WINDOW';
delete from matches  where coalesce(ended_at, started_at) < now() - interval '$WINDOW';
delete from sessions where started_at < now() - interval '$WINDOW'
  and session_id not in (select session_id from matches);
delete from clients  where last_seen < now() - interval '$WINDOW';
SQL
