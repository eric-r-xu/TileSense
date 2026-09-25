-- Replaces geoip_city with a fresh DB-IP "IP to City Lite" CSV read from
-- stdin, then fills in the location of sessions that have none. Run by
-- `./deploy.sh geoip`:
--   gunzip -c dbip-city-lite-YYYY-MM.csv.gz |
--     psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f server/deploy/load-geoip.sql
--
-- The new data loads into side tables and is swapped in with a quick rename,
-- so the ingest's lookups never wait on the load. A short or failed download
-- stops before the swap and leaves the current table in place.
\set ON_ERROR_STOP on

-- The CSV exactly as DB-IP ships it. Temporary: never written to the WAL,
-- and gone with this session even if a step below fails, so a bad download
-- can't leave ~1 GB of it behind.
create temp table geoip_city_load (
  ip_start  inet,
  ip_end    inet,
  continent text,
  country   text,
  region    text,
  city      text,
  lat       float8,
  lon       float8
);
\copy geoip_city_load from pstdin with (format csv)

do $$
declare n bigint := (select count(*) from geoip_city_load);
begin
  -- A full file is ~7.7M ranges; anything far short is a broken download.
  if n < 1000000 then
    raise exception 'only % GeoIP ranges loaded; keeping the current table', n;
  end if;
end $$;

-- Just what the lookup needs. 'ZZ' marks reserved and unassigned space:
-- better no location than that one.
drop table if exists geoip_city_new;
create table geoip_city_new as
  select ip_start, ip_end, country,
         nullif(region, '') as region,
         nullif(city, '') as city
  from geoip_city_load
  where country is not null and country <> 'ZZ';
drop table geoip_city_load;
alter table geoip_city_new
  alter column ip_start set not null,
  alter column ip_end set not null,
  alter column country set not null;
create index geoip_city_new_start on geoip_city_new (ip_start);
analyze geoip_city_new;

begin;
drop table geoip_city;
alter table geoip_city_new rename to geoip_city;
alter index geoip_city_new_start rename to ix_geoip_city_start;
commit;

-- Backfill: every session missing a country or a city, looked up by its
-- network. One prefix at a time, skipping any that isn't valid CIDR — the
-- ingest wrote malformed IPv6 prefixes (e.g. '2601:647:::/48') before it
-- parsed addresses properly, and one bad cast must not stop the rest.
do $$
declare
  p      text;
  a      inet;
  place  record;
  filled bigint := 0;
begin
  for p in
    select distinct ip_prefix from sessions
    where ip_prefix is not null
      and (geo_country is null or geo_city is null)
  loop
    begin
      a := host(p::cidr)::inet;
    exception when others then
      continue;
    end;
    select g.country, g.region, g.city into place from (
      select country, region, city, ip_end from geoip_city
      where ip_start <= a
      order by ip_start desc
      limit 1
    ) g
    where g.ip_end >= a;
    if place.country is not null then
      update sessions
      set geo_country = place.country,
          geo_region  = place.region,
          geo_city    = place.city
      where ip_prefix = p
        and (geo_country is null or geo_city is null);
      filled := filled + 1;
    end if;
  end loop;
  raise notice 'location filled in for % network prefixes', filled;
end $$;
