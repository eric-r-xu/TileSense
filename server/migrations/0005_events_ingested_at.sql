-- Server-side arrival time for events. `occurred_at` is the client's own
-- timestamp and a client that was offline delivers old events late, so it
-- cannot be used to find "what is new since last time". Additive only, safe to
-- re-run. Apply with:
--   psql "$DATABASE_URL" -f migrations/0005_events_ingested_at.sql

-- Added without a default first, so existing rows stay null instead of all
-- being stamped with this migration's time (which would be a lie: we do not
-- know when they arrived). Null means "ingested before this column existed".
alter table events add column if not exists ingested_at timestamptz;

-- New inserts, which name no ingested_at, get the arrival time. The ingest
-- code needs no change.
alter table events alter column ingested_at set default now();

-- For incremental readers filtering on arrival time. A plain (non-concurrent)
-- build takes a brief write lock on each partition.
create index if not exists ix_events_ingested on events (ingested_at);
