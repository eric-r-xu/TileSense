-- One row per client with the traits worth keeping history of. Feeds
-- snap_client_traits, so a match can be tied to what the player was like
-- when they played it, not what they are like today.
select
    c.client_id,
    coalesce(bool_or(m.guide_shown_at_start), false) as has_used_guide,
    coalesce(bool_or(m.mode = 'multiplayer'), false) as has_played_multiplayer,
    coalesce(bool_or(m.hanchan), false)              as has_played_hanchan,
    count(m.match_id)                                as matches_played
from {{ ref('stg_clients') }} c
left join {{ ref('stg_sessions') }} s using (client_id)
left join {{ ref('stg_matches') }} m using (session_id)
group by c.client_id
