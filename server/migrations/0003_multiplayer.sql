-- Multiplayer session data. Additive only, safe to re-run. Apply with:
--   psql "$DATABASE_URL" -f migrations/0003_multiplayer.sql
--
-- Single-player writes come from the browser (one client, one session, one
-- human seat per match) via the ingest service, same as before. Multiplayer
-- writes come from the mp game server instead (`server/mp`) — it is the
-- authoritative source for a shared match, so it is the one writer, not each
-- of up to four browsers independently reporting the same match. See
-- `server/mp/lib/telemetry.dart` and DEPLOYMENT.md section 3.

-- 'single' (default, existing behaviour unchanged) or 'multiplayer'.
alter table matches add column if not exists mode text not null default 'single';
alter table matches add column if not exists room_code text;
alter table matches add column if not exists timer_seconds int;

-- One entry per seat, null for a bot-filled seat — the multiplayer analogue
-- of `human_seat`, which only fits a match with exactly one human.
alter table matches add column if not exists seat_guest_ids text[];

-- 1..4 final standing per seat (ties share the higher place), the
-- multiplayer analogue of `human_place`.
alter table matches add column if not exists seat_places int[];

create index if not exists ix_matches_room_code on matches (room_code)
  where room_code is not null;
create index if not exists ix_matches_mode on matches (mode);

-- Which sessions played in which match, one row per human seat. `matches`
-- keeps its single `session_id` (the host's, for multiplayer) so that
-- existing FK and every single-player query against it are untouched;
-- this table carries the complete multi-session truth a shared match needs.
create table if not exists match_participants (
  match_id   uuid not null references matches,
  session_id uuid not null references sessions,
  seat       int not null,
  guest_id   text not null,
  primary key (match_id, seat)
);
create index if not exists ix_match_participants_session
  on match_participants (session_id);
