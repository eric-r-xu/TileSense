-- Game-by-game simulation results for reports/stats_report.md. Local only:
-- this is NOT a server migration and must never go in server/migrations/,
-- which deploy.sh applies to production. Idempotent; needs PostgreSQL 16
-- (nulls not distinct, erfc). Applied by reports/sim_run.sh.

-- One row per engine commit x variant x game length x decision maker: 68
-- per commit. Results from different code never share an arm.
create table if not exists sim_arm (
  arm_id         smallint generated always as identity primary key,
  engine_commit  text     not null,
  ruleset        text     not null check (ruleset in ('riichi', 'hongKong', 'taiwanese')),
  minimum        smallint not null,  -- faan (HK) or tai (TW) minimum; 0 for riichi
  game_length    text     not null check (game_length in ('east', 'hanchan')),
  decision_maker text     not null check (decision_maker in ('simple_bot', 'guide')),
  style          text,
  focus          text,
  strategy       text,
  -- Must match the key stats_report_test.dart builds for REPORT_SKIP.
  arm_key text generated always as (
    engine_commit || '|' || ruleset || '|' || minimum::text || '|' || game_length
      || '|' || decision_maker || coalesce('|' || style, '')
      || coalesce('|' || focus, '') || coalesce('|' || strategy, '')) stored,
  check ((decision_maker = 'simple_bot') = (style is null and focus is null and strategy is null)),
  unique nulls not distinct (engine_commit, ruleset, minimum, game_length,
                             decision_maker, style, focus, strategy)
);

-- One row per game. Raw counts only: every rate and statistic is derived in
-- the views below, so nothing is stored twice or can go stale.
create table if not exists sim_game (
  arm_id       smallint     not null references sim_arm,
  seed         int          not null,
  place        numeric(2,1) not null check (place between 1 and 4),
  start_points int          not null check (start_points > 0),
  end_points   int          not null,
  hands        smallint     not null check (hands > 0),
  wins         smallint     not null check (wins between 0 and hands),
  deal_ins     smallint     not null check (deal_ins between 0 and hands),
  primary key (arm_id, seed)
);

-- Lower 20% quantile of chi-square with k degrees of freedom
-- (Wilson-Hilferty; z(0.20) = -0.841621), for the 80% upper limit of an SD.
create or replace function sim_chi2_q20(k numeric) returns float8
  language sql immutable
  return k * power(1 - 2 / (9 * k) - 0.841621 * sqrt(2 / (9 * k)), 3);

create or replace view sim_game_metric as
select g.arm_id, g.seed, m.metric, m.value
from sim_game g
cross join lateral (values
  ('win_rate',     g.wins::float8 / g.hands),
  ('deal_in_rate', g.deal_ins::float8 / g.hands),
  ('points_pct',   100.0 * (g.end_points - g.start_points) / g.start_points),
  ('placement',    g.place::float8)
) as m(metric, value);

create or replace view sim_arm_stats as
select arm_id, metric, n, mean, sd,
       sd / sqrt(n)                                  as se,
       sd / nullif(abs(mean), 0)                     as cv,
       sd * sqrt((n - 1) / sim_chi2_q20(n - 1))      as sd_ucl
from (select arm_id, metric, count(*) as n, avg(value) as mean,
             stddev_samp(value) as sd
      from sim_game_metric group by arm_id, metric) s;

-- Guide games whose seed has no control game in the same family. Must be
-- empty, or the paired join below silently drops those games.
create or replace view sim_unpaired_games as
select a.arm_key, g.seed
from sim_game g
join sim_arm a using (arm_id)
where a.decision_maker = 'guide'
  and not exists (
    select 1 from sim_arm c join sim_game cg on cg.arm_id = c.arm_id
    where c.engine_commit = a.engine_commit and c.ruleset = a.ruleset
      and c.minimum = a.minimum and c.game_length = a.game_length
      and c.decision_maker = 'simple_bot' and cg.seed = g.seed);

-- Each guide arm against its control on the same seeds. delta is the effect
-- to detect: 10 percentage points of stack for points_pct, 10% of the
-- control's mean otherwise. n_* are seeds per arm for a two-sided 5% test
-- at 80% power: 7.849 = (1.960 + 0.842)^2; unpaired uses twice that on the
-- pooled SD. Holm p is adjusted within each (control, metric) family.
create or replace view sim_paired_stats as
with pairs as (
  select a.arm_id, c.arm_id as control_arm_id, gm.metric, gm.value as g, cm.value as c
  from sim_arm a
  join sim_arm c on c.engine_commit = a.engine_commit and c.ruleset = a.ruleset
                and c.minimum = a.minimum and c.game_length = a.game_length
                and c.decision_maker = 'simple_bot'
  join sim_game_metric gm on gm.arm_id = a.arm_id
  join sim_game_metric cm on cm.arm_id = c.arm_id and cm.seed = gm.seed
                         and cm.metric = gm.metric
  where a.decision_maker = 'guide'
), s as (
  select arm_id, control_arm_id, metric, count(*) as n_pairs,
         avg(g) as mean_guide, avg(c) as mean_control,
         stddev_samp(g) as sd_guide, stddev_samp(c) as sd_control,
         avg(g - c) as mean_diff, stddev_samp(g - c) as sd_diff, corr(g, c) as rho
  from pairs group by arm_id, control_arm_id, metric
), d as (
  select s.*,
         case when metric = 'points_pct' then 10.0 else 0.10 * abs(mean_control) end as delta,
         sd_diff * sqrt((n_pairs - 1) / sim_chi2_q20(n_pairs - 1)) as sd_diff_ucl,
         erfc(abs(mean_diff) / nullif(sd_diff / sqrt(n_pairs), 0) / sqrt(2)) as p
  from s
), r as (
  select d.*,
         row_number() over w as k,
         count(*) over (partition by control_arm_id, metric) as m
  from d window w as (partition by control_arm_id, metric order by p)
)
select arm_id, control_arm_id, metric, n_pairs, mean_guide, mean_control,
       mean_diff, sd_diff, sd_diff_ucl, rho, delta, p,
       max(least(1, (m - k + 1) * p)) over (partition by control_arm_id, metric
         order by p rows unbounded preceding) as p_holm,
       ceil(15.697758 * ((sd_guide ^ 2 + sd_control ^ 2) / 2) / nullif(delta, 0) ^ 2) as n_unpaired,
       ceil(7.848879 * (sd_diff / nullif(delta, 0)) ^ 2)     as n_paired,
       ceil(7.848879 * (sd_diff_ucl / nullif(delta, 0)) ^ 2) as n_paired_ucl
from r;

-- Flat, labeled views for Metabase, which cannot join views by itself (views
-- carry no foreign keys). sim_report is also what sim_report.py reads.
create or replace view sim_arm_label as
select a.*,
       case a.ruleset when 'riichi' then 'Japanese Riichi'
                      when 'hongKong' then 'Hong Kong ' || a.minimum || '-faan min'
                      else 'Taiwanese ' || a.minimum || '-tai min' end as variant,
       case a.game_length when 'east' then 'East only' else 'Hanchan' end as game_length_label,
       case a.decision_maker when 'simple_bot' then 'Simple Bot (control)'
                             else 'TileSense Guide' end as decision_maker_label
from sim_arm a;

-- One row per game.
create or replace view sim_game_detail as
select a.engine_commit, a.arm_key, a.variant, a.game_length_label, a.decision_maker_label,
       a.style, a.focus, a.strategy, g.seed, g.place, g.start_points, g.end_points,
       g.hands, g.wins, g.deal_ins,
       g.wins::float8 / g.hands                                  as win_rate,
       g.deal_ins::float8 / g.hands                              as deal_in_rate,
       100.0 * (g.end_points - g.start_points) / g.start_points  as points_pct
from sim_game g
join sim_arm_label a using (arm_id);

-- One row per arm and metric: the rows of reports/stats_report.md.
create or replace view sim_report as
select a.engine_commit, a.arm_key, a.ruleset, a.minimum, a.game_length, a.decision_maker,
       a.style, a.focus, a.strategy, a.variant, a.game_length_label, a.decision_maker_label,
       s.metric,
       case s.metric when 'win_rate' then 'Win Rate' when 'deal_in_rate' then 'Deal-in Rate'
                     when 'points_pct' then 'Ending Points (% vs start)'
                     else 'Ending Placement' end as metric_label,
       s.n, s.mean, s.sd, s.se, s.cv, s.sd_ucl, r.seed_min, r.seed_max,
       p.n_pairs, p.rho, p.mean_diff, p.p_holm, p.delta,
       p.n_unpaired, p.n_paired, p.n_paired_ucl
from sim_arm_label a
join sim_arm_stats s using (arm_id)
join (select arm_id, min(seed) as seed_min, max(seed) as seed_max
      from sim_game group by arm_id) r using (arm_id)
left join sim_paired_stats p on p.arm_id = a.arm_id and p.metric = s.metric;
