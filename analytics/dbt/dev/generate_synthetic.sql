-- Dev-only synthetic telemetry for a LOCAL Postgres. Truncates the telemetry
-- tables first, so never run it against anything you care about:
--   psql -v confirm_local=1 [-v n_clients=5000] [-v events_per_round=6] -f dev/generate_synthetic.sql
-- Deliberately messy: abandoned/open matches, multiplayer rows with null
-- human_place, rounds that never ended, and events whose session is unknown.
\if :{?confirm_local}
\else
  \echo 'refusing to run: pass -v confirm_local=1 (this truncates telemetry tables)'
  \quit
\endif
\if :{?n_clients} \else \set n_clients 5000 \endif
\if :{?events_per_round} \else \set events_per_round 6 \endif

select setseed(0.42);
truncate clients, events restart identity cascade;

insert into clients (client_id, first_seen, last_seen, first_ua)
select gen_random_uuid(), t, t, 'synthetic/' || (g % 5)
from generate_series(1, :n_clients) g,
     lateral (select now() - random() * interval '120 days' as t) x;

insert into sessions (session_id, client_id, started_at, app_version, geo_country)
select gen_random_uuid(), c.client_id,
       c.first_seen + random() * (now() - c.first_seen),
       (array['1.0.0','1.1.0','1.2.0'])[1 + floor(random() * 3)::int],
       (array['US','JP','HK','TW','GB','DE'])[1 + floor(random() * 6)::int]
from clients c, generate_series(1, 4) g
where random() < 0.75;

insert into matches (match_id, session_id, mode, room_code, timer_seconds, hanchan,
                     fast_mode, autoplay_at_start, guide_shown_at_start, started_at,
                     ended_at, ended_reason, human_seat, human_place, final_points,
                     seat_places)
select gen_random_uuid(), s.session_id, x.mode,
       case when x.mode = 'multiplayer' then upper(substr(md5(random()::text), 1, 4)) end,
       case when x.mode = 'multiplayer' then 30 end,
       random() < 0.6, random() < 0.3, random() < 0.1, random() < 0.5,
       x.started,
       case when x.r < 0.95 then x.started + interval '15 minutes' + random() * interval '45 minutes' end,
       case when x.r < 0.75 then 'game_end' when x.r < 0.90 then 'abandoned'
            when x.r < 0.95 then 'new_game' end,
       floor(random() * 4)::int,
       case when x.mode = 'single' and x.r < 0.75 then 1 + floor(random() * 4)::int end,
       case when x.r < 0.75 then array[25000 + 1000*floor(random()*10)::int, 25000, 25000, 25000 - 1000*floor(random()*10)::int] end,
       case when x.mode = 'multiplayer' and x.r < 0.75 then array[1,2,3,4] end
from sessions s, generate_series(1, 3) g,
     lateral (select random() as r,
                     case when random() < 0.15 then 'multiplayer' else 'single' end as mode,
                     least(now(), s.started_at + random() * interval '2 hours') as started) x
where random() < 0.7;

insert into match_participants (match_id, session_id, seat, guest_id)
select m.match_id, m.session_id, h.seat, 'g' || h.seat
from matches m, lateral (select generate_series(0, 1) as seat) h
where m.mode = 'multiplayer';

insert into rounds (round_id, match_id, round_index, round_wind, hand_number, dealer_seat,
                    honba, riichi_sticks, started_at, ended_at, end_kind, winners,
                    loser_seat, han, fu, points, point_deltas, dealer_kept)
select gen_random_uuid(), m.match_id, g - 1,
       case when g <= 4 then 'east' else 'south' end, ((g - 1) % 4) + 1, (g - 1) % 4,
       floor(random() * 3)::int, floor(random() * 2)::int, x.started,
       case when x.r < 0.98 then x.started + interval '2 minutes' end,
       case when x.r >= 0.98 then null
            when x.r < 0.40 then 'tsumo' when x.r < 0.75 then 'ron'
            when x.r < 0.95 then 'exhaustiveDraw' else 'abortiveDraw' end,
       case when x.r < 0.75 then array[floor(random() * 4)::int] end,
       case when x.r >= 0.40 and x.r < 0.75 then floor(random() * 4)::int end,
       case when x.r < 0.75 then 1 + floor(random() * 8)::int end,
       case when x.r < 0.75 then 20 + 10 * floor(random() * 10)::int end,
       case when x.r < 0.75 then 1000 * (1 + floor(random() * 8)::int) end,
       case when x.r < 0.98 then array[-1000, 1000, 0, 0] end,
       random() < 0.3
from matches m, generate_series(1, 8) g,
     lateral (select random() as r,
                     least(now(), m.started_at + (g - 1) * interval '3 minutes') as started) x
where g <= case when m.hanchan then 8 else 4 end;

insert into events (session_id, match_id, round_id, occurred_at, kind, actor_seat, tile,
                    auto, guide_shown, guide_reco, followed_guide)
select case when x.r < 0.02 then gen_random_uuid() else m.session_id end,
       case when x.kind = 'setting_change' then null else r.match_id end,
       case when x.kind = 'setting_change' then null else r.round_id end,
       least(now(), r.started_at + g * interval '10 seconds'),
       x.kind, floor(random() * 4)::int,
       case when x.kind = 'discard' then (array['1m','5m','9p','3s','7z','5z'])[1 + floor(random() * 6)::int] end,
       random() < 0.1, m.guide_shown_at_start,
       case when m.guide_shown_at_start and x.kind = 'discard' then '5m' end,
       case when m.guide_shown_at_start and x.kind = 'discard' then random() < 0.6 end
from rounds r
join matches m using (match_id),
     generate_series(1, :events_per_round) g,
     lateral (select random() as r,
                     case when random() < 0.70 then 'discard' when random() < 0.5 then 'pass'
                          when random() < 0.9 then 'call' else 'setting_change' end as kind) x;

analyze;
select 'clients' t, count(*) from clients union all select 'sessions', count(*) from sessions
union all select 'matches', count(*) from matches union all select 'rounds', count(*) from rounds
union all select 'events', count(*) from events;
