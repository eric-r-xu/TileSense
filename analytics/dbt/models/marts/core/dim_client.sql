with current_state as (
    select
        c.client_id,
        c.first_seen,
        c.last_seen,
        t.has_used_guide,
        t.has_played_multiplayer,
        t.has_played_hanchan,
        t.matches_played
    from {{ ref('stg_clients') }} c
    join {{ ref('int_client_traits') }} t using (client_id)
),

known as (
    select
        {{ dbt_utils.generate_surrogate_key(['client_id']) }} as client_key,
        *
    from current_state
),

unknown as (
    select
        {{ dbt_utils.generate_surrogate_key(["'-1'"]) }} as client_key,
        null::uuid as client_id,
        null::timestamptz as first_seen,
        null::timestamptz as last_seen,
        null::boolean as has_used_guide,
        null::boolean as has_played_multiplayer,
        null::boolean as has_played_hanchan,
        null::bigint as matches_played
)

select * from known
union all
select * from unknown
