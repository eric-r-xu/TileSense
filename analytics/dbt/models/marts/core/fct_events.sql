{{ config(
    materialized='incremental',
    unique_key='event_id',
    incremental_strategy='delete+insert',
    on_schema_change='append_new_columns'
) }}

-- Grain: one row per player action (discard, call, pass, ...). event_id comes
-- from a shared identity sequence, so it is unique across partitions even
-- though Postgres does not enforce that on a partitioned table; the unique
-- test below does. Append-only source, but occurred_at is client-supplied, so
-- late batches carry old timestamps: the lookback (events_lookback_days) is the
-- only protection, and anything later than that is missed until a full refresh.
select
    e.event_id,
    {{ dbt_utils.generate_surrogate_key(["coalesce(s.client_id::text, '-1')"]) }} as client_key,
    e.occurred_at::date as date_key,
    e.session_id,
    e.match_id,
    e.round_id,
    e.occurred_at,
    e.kind,
    e.actor_seat,
    e.tile,
    coalesce(e.auto, false)           as is_auto,
    e.guide_shown,
    e.guide_reco,
    e.followed_guide,
    e.payload
from {{ ref('stg_events') }} e
left join {{ ref('stg_sessions') }} s on s.session_id = e.session_id
{% if is_incremental() %}
where e.occurred_at >= (select max(occurred_at) from {{ this }}) - ({{ var('events_lookback_days') }} * interval '1 day')
{% endif %}
