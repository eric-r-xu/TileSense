{{ config(
    materialized='incremental',
    unique_key='event_id',
    incremental_strategy='delete+insert',
    on_schema_change='append_new_columns'
) }}

-- Grain: one row per player action (discard, call, pass, ...). event_id comes
-- from a shared identity sequence, so it is unique across partitions even
-- though Postgres does not enforce that on a partitioned table; the unique
-- test below does. occurred_at is client-supplied, so offline clients deliver
-- old events late; incremental runs therefore key on ingested_at (server arrival
-- time, migration 0005). It is null for rows that predate that column, which a
-- full refresh loads once; after that every new row has it.
select
    e.event_id,
    {{ dbt_utils.generate_surrogate_key(["coalesce(s.client_id::text, '-1')"]) }} as client_key,
    e.occurred_at::date as date_key,
    e.session_id,
    e.match_id,
    e.round_id,
    e.occurred_at,
    e.ingested_at,
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
where e.ingested_at >= coalesce(
    (select max(ingested_at) from {{ this }}) - ({{ var('events_overlap_minutes') }} * interval '1 minute'),
    '-infinity'
)
{% endif %}
