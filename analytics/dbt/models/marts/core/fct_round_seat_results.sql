-- Grain: one row per round x seat. Unpacks rounds.point_deltas (int[], index =
-- seat) so no array columns reach the mart. Ordinality is 1-based; seat is 0-based.
select
    r.round_id,
    d.seat0 - 1                           as seat,
    d.delta                               as point_delta,
    (d.seat0 - 1) = any(r.winners)        as is_winner,
    (d.seat0 - 1) = r.loser_seat          as is_loser,
    (d.seat0 - 1) = r.dealer_seat         as is_dealer
from {{ ref('stg_rounds') }} r
cross join lateral unnest(r.point_deltas) with ordinality as d(delta, seat0)
where r.point_deltas is not null
