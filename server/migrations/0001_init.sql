-- TileSense telemetry schema. Additive only: safe to re-run (IF NOT EXISTS
-- everywhere), never drops or rewrites. Apply with:
--   psql "$DATABASE_URL" -f migrations/0001_init.sql

create table if not exists clients (
  client_id  uuid primary key,
  first_seen timestamptz not null default now(),
  last_seen  timestamptz not null default now(),
  first_ua   text
);

create table if not exists sessions (
  session_id  uuid primary key,
  client_id   uuid not null references clients,
  started_at  timestamptz not null default now(),
  app_version text,
  user_agent  text,
  ip_prefix   text,   -- /24 (v4) or /48 (v6), never the full address
  ip_hmac     bytea,  -- HMAC-SHA256(ip, server secret) — grouping without the IP
  geo_country text
);
create index if not exists ix_sessions_client on sessions (client_id);
create index if not exists ix_sessions_ip_hmac on sessions (ip_hmac);

create table if not exists matches (
  match_id             uuid primary key,
  session_id           uuid not null references sessions,
  seed                 bigint,
  hanchan              boolean,
  fast_mode            boolean,
  autoplay_at_start    boolean,
  guide_shown_at_start boolean,
  started_at           timestamptz not null default now(),
  ended_at             timestamptz,
  ended_reason         text,  -- 'game_end' | 'new_game' | 'abandoned'
  final_points         int[],
  human_seat           int,
  human_place          int
);
create index if not exists ix_matches_session on matches (session_id);
create index if not exists ix_matches_started on matches (started_at);

create table if not exists rounds (
  round_id      uuid primary key,
  match_id      uuid not null references matches,
  round_index   int,
  round_wind    text,
  hand_number   int,
  dealer_seat   int,
  honba         int,
  riichi_sticks int,
  started_at    timestamptz not null default now(),
  ended_at      timestamptz,
  end_kind      text,   -- tsumo | ron | exhaustiveDraw | abortiveDraw
  winners       int[],
  loser_seat    int,
  han int, fu int, points int,
  yaku          jsonb,
  point_deltas  int[],
  dealer_kept   boolean
);
create index if not exists ix_rounds_match on rounds (match_id);

-- Per-action stream. Partitioned by month so retention is a partition drop.
create table if not exists events (
  event_id      bigint generated always as identity,
  session_id    uuid not null,
  match_id      uuid,
  round_id      uuid,
  occurred_at   timestamptz not null default now(),
  kind          text not null,   -- discard | call | pass | setting_change | ...
  actor_seat    int,
  tile          text,
  auto          boolean,
  guide_shown   boolean,
  guide_reco    text,
  followed_guide boolean,
  payload       jsonb
) partition by range (occurred_at);

-- A catch-all partition so inserts never fail for want of a month partition.
-- Create dated partitions later (pg_partman or a monthly cron) if volume grows.
create table if not exists events_default partition of events default;
create index if not exists ix_events_match on events (match_id, occurred_at);
create index if not exists ix_events_kind on events (kind, occurred_at);
