-- Junk dimension: the per-match option flags that would otherwise repeat as
-- booleans on every match row. One row per combination seen in the data.
-- Null flags are kept distinct from false (older clients may not report them).
with combos as (
    select distinct
        mode,
        hanchan,
        fast_mode,
        autoplay_at_start,
        guide_shown_at_start
    from {{ ref('stg_matches') }}
),

known as (
    select
        {{ dbt_utils.generate_surrogate_key([
            'mode', 'hanchan', 'fast_mode', 'autoplay_at_start', 'guide_shown_at_start'
        ]) }} as match_settings_key,
        *
    from combos
),

unknown as (
    select
        {{ dbt_utils.generate_surrogate_key(["'-1'"]) }} as match_settings_key,
        null::text as mode,
        null::boolean as hanchan,
        null::boolean as fast_mode,
        null::boolean as autoplay_at_start,
        null::boolean as guide_shown_at_start
)

select * from known
union all
select * from unknown
