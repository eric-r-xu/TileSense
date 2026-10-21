-- Grain: one row per daily-quiz answer. A replay of the same puzzle on the
-- same day is a row too; is_first_today picks out the answer the streak
-- counted. The quiz has no match or round, so this reads only the generic
-- event row (kind 'quiz_answered', details in payload; see server/bin/server.dart).
select
    e.event_id,
    e.client_key,
    e.date_key,
    e.session_id,
    e.occurred_at,
    e.payload ->> 'puzzle_id'                                  as puzzle_id,
    e.payload ->> 'puzzle_kind'                                as puzzle_kind,
    e.payload ->> 'choice'                                     as choice,
    e.payload ->> 'answer'                                     as answer,
    coalesce((e.payload ->> 'correct')::boolean, false)        as is_correct,
    coalesce((e.payload ->> 'riichi_option')::boolean, false)  as is_riichi_question,
    (e.payload ->> 'day')::date                                as quiz_day,
    (e.payload ->> 'streak')::int                              as streak,
    coalesce((e.payload ->> 'first_today')::boolean, false)    as is_first_today
from {{ ref('fct_events') }} e
where e.kind = 'quiz_answered'
