-- Dev-only fixture for a LOCAL Postgres. Never run against production.
insert into clients (client_id, first_ua) values
  ('00000000-0000-0000-0000-0000000000a1', 'Mozilla/5.0 test'),
  ('00000000-0000-0000-0000-0000000000a2', 'Mozilla/5.0 other');
insert into sessions (session_id, client_id, app_version, geo_country) values
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1', '1.0.0', 'US'),
  ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000a2', '1.0.0', 'JP');
insert into matches (match_id, session_id, hanchan, guide_shown_at_start, ended_at, ended_reason, human_seat, human_place, mode) values
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000b1', true,  true,  now(), 'game_end', 0, 2, 'single'),
  ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-0000000000b2', false, false, null,  null,       1, null, 'multiplayer');
insert into rounds (round_id, match_id, round_index, round_wind, hand_number, dealer_seat, honba, end_kind, winners, loser_seat, han, fu, points, point_deltas, dealer_kept) values
  ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1', 0, 'east', 1, 0, 0, 'ron',  '{1}', 0, 3, 30, 3900, '{-3900,3900,0,0}', false),
  ('00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-0000000000c1', 1, 'east', 2, 1, 0, 'tsumo','{1}', null, 2, 30, 2000, '{-500,1000,-250,-250}', true),
  ('00000000-0000-0000-0000-0000000000d3', '00000000-0000-0000-0000-0000000000c2', 0, 'east', 1, 0, 0, null, null, null, null, null, null, null, null);

insert into match_participants (match_id, session_id, seat, guest_id) values
  ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-0000000000b2', 1, 'g1'),
  ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-0000000000b1', 2, 'g2');
update matches set final_points = '{21000,32000,25000,22000}' where match_id = '00000000-0000-0000-0000-0000000000c1';
insert into events (session_id, match_id, round_id, occurred_at, kind, actor_seat, tile, auto, guide_shown, guide_reco, followed_guide) values
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000d1', now(), 'discard', 0, '3m', false, true, '3m', true),
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000d1', now(), 'discard', 0, '9p', false, true, '1s', false),
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000d1', now(), 'pass',    0, null, true,  false, null, null),
  ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-0000000000d3', now(), 'discard', 1, '5z', null,  false, null, null),
  ('00000000-0000-0000-0000-0000000000ff', null, null, now(), 'setting_change', null, null, false, null, null, null);
