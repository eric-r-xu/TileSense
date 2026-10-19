select
    event_id,
    session_id,
    match_id,
    round_id,
    occurred_at,
    ingested_at,
    kind,
    actor_seat,
    tile,
    auto,
    guide_shown,
    guide_reco,
    followed_guide,
    payload
from {{ source('telemetry', 'events') }}
