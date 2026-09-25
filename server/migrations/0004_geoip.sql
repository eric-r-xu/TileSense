-- GeoIP ranges, for the ingest's per-session location lookup, and the
-- session columns it fills. Additive only, safe to re-run. Apply with:
--   psql "$DATABASE_URL" -f migrations/0004_geoip.sql
--
-- Filled, and refreshed each month, by `./deploy.sh geoip`
-- (server/deploy/load-geoip.sql) from DB-IP's free "IP to City Lite"
-- database, licensed CC BY 4.0 — credit "IP Geolocation by DB-IP"
-- (https://db-ip.com) on anything built from it. Until it is filled the
-- lookup simply finds nothing and new sessions get null geo_* columns, same
-- as before.
create table if not exists geoip_city (
  ip_start inet not null,
  ip_end   inet not null,
  country  text not null,  -- ISO 3166-1 alpha-2
  region   text,           -- state / province, as DB-IP names it
  city     text
);
create index if not exists ix_geoip_city_start on geoip_city (ip_start);

-- sessions.geo_country has been there since 0001.
alter table sessions add column if not exists geo_region text;
alter table sessions add column if not exists geo_city   text;
