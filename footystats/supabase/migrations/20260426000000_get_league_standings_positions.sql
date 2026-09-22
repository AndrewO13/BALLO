-- Extend get_league_standings with table position, previous position, and movement.
-- previous_position: rank after all fullTime matches strictly before the latest
--   match_date in the league; null if the team had no results in that "prior" set.
-- position_change: previous_position - position (positive = moved up the table).

drop function if exists public.get_league_standings(uuid);

create or replace function public.get_league_standings(p_league_id uuid)
returns table (
  team_id             uuid,
  team_short_form     text,
  team_logo           text,
  played              bigint,
  wins                bigint,
  draws               bigint,
  losses              bigint,
  goals_for           bigint,
  goals_against       bigint,
  goal_difference     bigint,
  points              bigint,
  "position"          int,
  previous_position   int,
  position_change     int
)
language sql
security definer
set search_path = public
as $$
  with latest_match_time as (
    select max(m.match_date) as t
    from matches m
    where m.league_id = p_league_id
      and m.status = 'fullTime'
      and m."teamA_score" is not null
      and m."teamB_score" is not null
  ),
  team_matches_all as (
    select
      m."teamA" as tid,
      m."teamA_score" as gf,
      m."teamB_score" as ga
    from matches m
    where m.league_id = p_league_id
      and m.status = 'fullTime'
      and m."teamA_score" is not null
      and m."teamB_score" is not null

    union all

    select
      m."teamB" as tid,
      m."teamB_score" as gf,
      m."teamA_score" as ga
    from matches m
    where m.league_id = p_league_id
      and m.status = 'fullTime'
      and m."teamA_score" is not null
      and m."teamB_score" is not null
  ),
  team_matches_prev as (
    select
      m."teamA" as tid,
      m."teamA_score" as gf,
      m."teamB_score" as ga
    from matches m
    where m.league_id = p_league_id
      and m.status = 'fullTime'
      and m."teamA_score" is not null
      and m."teamB_score" is not null
      and m.match_date < (select t from latest_match_time)
      and (select t from latest_match_time) is not null

    union all

    select
      m."teamB" as tid,
      m."teamB_score" as gf,
      m."teamA_score" as ga
    from matches m
    where m.league_id = p_league_id
      and m.status = 'fullTime'
      and m."teamA_score" is not null
      and m."teamB_score" is not null
      and m.match_date < (select t from latest_match_time)
      and (select t from latest_match_time) is not null
  ),
  aggregated as (
    select
      tm.tid,
      count(*)                                   as played,
      count(*) filter (where tm.gf > tm.ga)      as wins,
      count(*) filter (where tm.gf = tm.ga)      as draws,
      count(*) filter (where tm.gf < tm.ga)     as losses,
      coalesce(sum(tm.gf), 0)                    as goals_for,
      coalesce(sum(tm.ga), 0)                    as goals_against,
      coalesce(sum(tm.gf - tm.ga), 0)            as goal_difference,
      count(*) filter (where tm.gf > tm.ga) * 3
        + count(*) filter (where tm.gf = tm.ga)  as points
    from team_matches_all tm
    group by tm.tid
  ),
  aggregated_prev as (
    select
      tm.tid,
      count(*)                                   as played,
      count(*) filter (where tm.gf > tm.ga)      as wins,
      count(*) filter (where tm.gf = tm.ga)      as draws,
      count(*) filter (where tm.gf < tm.ga)     as losses,
      coalesce(sum(tm.gf), 0)                    as goals_for,
      coalesce(sum(tm.ga), 0)                    as goals_against,
      coalesce(sum(tm.gf - tm.ga), 0)            as goal_difference,
      count(*) filter (where tm.gf > tm.ga) * 3
        + count(*) filter (where tm.gf = tm.ga)  as points
    from team_matches_prev tm
    group by tm.tid
  ),
  current_ranked as (
    select
      a.tid,
      t.short_form    as team_short_form,
      t.logo_id       as team_logo,
      a.played,
      a.wins,
      a.draws,
      a.losses,
      a.goals_for,
      a.goals_against,
      a.goal_difference,
      a.points,
      row_number() over (
        order by
          a.points desc,
          a.goal_difference desc,
          a.goals_for desc,
          t.short_form
      )::int as pos
    from aggregated a
    join teams t on t.id = a.tid
  ),
  prev_ranked as (
    select
      a.tid,
      row_number() over (
        order by
          a.points desc,
          a.goal_difference desc,
          a.goals_for desc,
          t.short_form
      )::int as pos
    from aggregated_prev a
    join teams t on t.id = a.tid
  )
  select
    c.tid as team_id,
    c.team_short_form,
    c.team_logo,
    c.played,
    c.wins,
    c.draws,
    c.losses,
    c.goals_for,
    c.goals_against,
    c.goal_difference,
    c.points,
    c.pos as "position",
    p.pos as previous_position,
    case
      when p.pos is null then 0
      else p.pos - c.pos
    end as position_change
  from current_ranked c
  left join prev_ranked p on p.tid = c.tid
  order by c.pos;
$$;
