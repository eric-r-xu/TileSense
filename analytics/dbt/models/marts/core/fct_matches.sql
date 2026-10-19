-- Grain: one row per match. Matches are written open and closed later, so
-- this is an accumulating-snapshot fact rebuilt in full (matches is small).
-- Abandoned and still-open matches are kept and flagged, not dropped.
with round_counts as (
    select match_id, count(*) as rounds_played
    from {{ ref('stg_rounds') }}
    group by match_id
),

human_seats as (
    select match_id, count(*) as human_seat_count
    from {{ ref('stg_match_participants') }}
    group by match_id
)

select
    m.match_id,
    {{ dbt_utils.generate_surrogate_key(["coalesce(s.client_id::text, '-1')"]) }} as client_key,
    {{ dbt_utils.generate_surrogate_key([
        'm.mode', 'm.hanchan', 'm.fast_mode', 'm.autoplay_at_start', 'm.guide_shown_at_start'
    ]) }} as match_settings_key,
    m.started_at::date as date_key,
    m.session_id,
    m.room_code,
    m.timer_seconds,
    m.started_at,
    m.ended_at,
    m.ended_reason,
    m.ended_at is not null                              as is_ended,
    coalesce(m.ended_reason = 'game_end', false)    as is_completed,
    coalesce(m.ended_reason = 'abandoned', false)   as is_abandoned,
    extract(epoch from (m.ended_at - m.started_at))::int as duration_seconds,
    coalesce(rc.rounds_played, 0)                       as rounds_played,
    -- Single-player has exactly one human; multiplayer is counted from participants.
    case when m.mode = 'single' then 1
         else coalesce(hs.human_seat_count, 0) end      as human_seat_count,
    m.human_seat,
    m.human_place,
    -- Postgres arrays are 1-based; seats are 0-based.
    m.final_points[m.human_seat + 1]                    as human_final_points
from {{ ref('stg_matches') }} m
left join {{ ref('stg_sessions') }} s on s.session_id = m.session_id
left join round_counts rc on rc.match_id = m.match_id
left join human_seats hs on hs.match_id = m.match_id
