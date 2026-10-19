{{ config(
    materialized='incremental',
    unique_key='round_id',
    incremental_strategy='delete+insert',
    on_schema_change='append_new_columns'
) }}

-- Grain: one row per round (hand). Rounds are written open and closed later,
-- so the incremental window re-reads recent starts to pick up ended_at/end_kind.
select
    r.round_id,
    r.match_id,
    {{ dbt_utils.generate_surrogate_key(['s.client_id']) }} as client_key,
    r.started_at::date as date_key,
    r.round_index,
    r.round_wind,
    r.hand_number,
    r.dealer_seat,
    r.honba,
    r.riichi_sticks,
    r.started_at,
    r.ended_at,
    r.end_kind,
    r.loser_seat,
    r.han,
    r.fu,
    r.points,
    r.dealer_kept,
    r.yaku
from {{ ref('stg_rounds') }} r
join {{ ref('stg_matches') }} m using (match_id)
join {{ ref('stg_sessions') }} s on s.session_id = m.session_id
{% if is_incremental() %}
where r.started_at >= (select max(started_at) from {{ this }}) - interval '3 days'
{% endif %}
