-- Per-seat character (persona) and bot-vs-human info on a match, so Metabase
-- can break down play by who/what was in each seat rather than just which
-- single seat was human. Additive only, safe to re-run. Apply with:
--   psql "$DATABASE_URL" -f migrations/0002_seat_characters.sql

-- One entry per seat (index 0-3 = seat 0-3), e.g. {orderic,grant,hubert,astaroth}.
alter table matches add column if not exists seat_characters text[];

-- One entry per seat (index 0-3 = seat 0-3); true where that seat is bot-
-- controlled. Offline today this is always exactly one `false`, but it's
-- recorded per seat — not assumed from human_seat — so it still holds once
-- a match can have more than one human seat.
alter table matches add column if not exists seat_is_bot boolean[];
