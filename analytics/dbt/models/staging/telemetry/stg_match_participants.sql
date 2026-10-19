select
    match_id,
    session_id,
    seat,
    guest_id
from {{ source('telemetry', 'match_participants') }}
