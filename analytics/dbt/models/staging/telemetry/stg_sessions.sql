-- ip_prefix and ip_hmac are deliberately not selected: nothing downstream
-- needs them, and leaving them out keeps the marts free of IP-derived data.
select
    session_id,
    client_id,
    started_at,
    app_version,
    user_agent,
    geo_country,
    geo_region,
    geo_city
from {{ source('telemetry', 'sessions') }}
