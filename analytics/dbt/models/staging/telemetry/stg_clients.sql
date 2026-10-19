select
    client_id,
    first_seen,
    last_seen,
    first_ua
from {{ source('telemetry', 'clients') }}
