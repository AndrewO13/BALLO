-- Tackles, saves, and cards in get_team_summary_stats_filtered must count only
-- events credited to p_team_id (not the opponent's events in the same matches).

drop function if exists public.get_team_summary_stats_filtered(uuid, uuid, uuid);

create or replace function public.get_team_summary_stats_filtered(
  p_team_id uuid,
  p_league_id uuid default null,
  p_season_id uuid default null
)
returns table (
  matches_played      bigint,
  goals_scored        bigint,
  goals_conceded      bigint,
  goal_difference     bigint,
  assists             bigint,
  clean_sheets        bigint,
  shots_on_target     bigint,
  tackles             bigint,
  saves               bigint,
  yellow_cards        bigint,
  red_cards           bigint,
  total_xg            double precision,
  total_xa            double precision
)
language sql
security definer
set search_path = public
as $$
  with team_matches as (
    select
      m.id as match_id,
      m."teamA_score" as gf,
      m."teamB_score" as ga
    from matches m
    where m."teamA" = p_team_id
      and m.status = 'fullTime'
      and m."teamA_score" is not null
      and m."teamB_score" is not null
      and (p_league_id is null or m.league_id = p_league_id)
      and (p_season_id is null or m.season_id = p_season_id)

    union all

    select
      m.id as match_id,
      m."teamB_score" as gf,
      m."teamA_score" as ga
    from matches m
    where m."teamB" = p_team_id
      and m.status = 'fullTime'
      and m."teamA_score" is not null
      and m."teamB_score" is not null
      and (p_league_id is null or m.league_id = p_league_id)
      and (p_season_id is null or m.season_id = p_season_id)
  ),
  match_agg as (
    select
      count(*) as matches_played,
      coalesce(sum(gf), 0) as goals_scored,
      coalesce(sum(ga), 0) as goals_conceded,
      coalesce(sum(gf - ga), 0) as goal_difference,
      count(*) filter (where ga = 0) as clean_sheets
    from team_matches
  ),
  finished_match_ids as (
    select match_id from team_matches
  ),
  player_agg as (
    select
      coalesce(sum(mps.assists), 0) as assists,
      coalesce(sum(mps."xG"), 0.0) as total_xg,
      coalesce(sum(mps."xA"), 0.0) as total_xa
    from match_player_stats mps
    where mps.match_id in (select match_id from finished_match_ids)
      and mps.team_id = p_team_id
  ),
  event_agg as (
    select
      count(*) filter (
        where me.event_type = 'tackle'
          and not me.is_deleted
          and me.team_id = p_team_id
      ) as tackles,
      count(*) filter (
        where me.event_type = 'save'
          and not me.is_deleted
          and me.team_id = p_team_id
      ) as saves,
      count(*) filter (
        where me.event_type = 'yellow_card'
          and not me.is_deleted
          and me.team_id = p_team_id
      ) as yellow_cards,
      count(*) filter (
        where me.event_type = 'red_card'
          and not me.is_deleted
          and me.team_id = p_team_id
      ) as red_cards,
      count(distinct me.id) filter (
        where not me.is_deleted and (
          (me.event_type in ('goal', 'penalty_goal') and me.team_id = p_team_id)
          or (me.event_type = 'save' and me.team_id != p_team_id)
        )
      ) as shots_on_target
    from match_events me
    where me.match_id in (select match_id from finished_match_ids)
  )
  select
    ma.matches_played,
    ma.goals_scored,
    ma.goals_conceded,
    ma.goal_difference,
    coalesce(pa.assists, 0) as assists,
    ma.clean_sheets,
    coalesce(ea.shots_on_target, 0) as shots_on_target,
    coalesce(ea.tackles, 0) as tackles,
    coalesce(ea.saves, 0) as saves,
    coalesce(ea.yellow_cards, 0) as yellow_cards,
    coalesce(ea.red_cards, 0) as red_cards,
    coalesce(pa.total_xg, 0.0) as total_xg,
    coalesce(pa.total_xa, 0.0) as total_xa
  from match_agg ma
  left join player_agg pa on true
  left join event_agg ea on true;
$$;

-- Same team scoping for unfiltered team summary (team detail all-time stats).
drop function if exists public.get_team_summary_stats(uuid);

create or replace function public.get_team_summary_stats(p_team_id uuid)
returns table (
  matches_played      bigint,
  goals_scored        bigint,
  goals_conceded      bigint,
  goal_difference     bigint,
  assists             bigint,
  clean_sheets        bigint,
  shots_on_target     bigint,
  tackles             bigint,
  saves               bigint,
  yellow_cards        bigint,
  red_cards           bigint,
  total_xg            double precision,
  total_xa            double precision
)
language sql
security definer
set search_path = public
as $$
  with team_matches as (
    select
      m.id as match_id,
      m."teamA_score" as gf,
      m."teamB_score" as ga
    from matches m
    where m."teamA" = p_team_id
      and m.status = 'fullTime'
      and m."teamA_score" is not null
      and m."teamB_score" is not null

    union all

    select
      m.id as match_id,
      m."teamB_score" as gf,
      m."teamA_score" as ga
    from matches m
    where m."teamB" = p_team_id
      and m.status = 'fullTime'
      and m."teamA_score" is not null
      and m."teamB_score" is not null
  ),
  match_agg as (
    select
      count(*) as matches_played,
      coalesce(sum(gf), 0) as goals_scored,
      coalesce(sum(ga), 0) as goals_conceded,
      coalesce(sum(gf - ga), 0) as goal_difference,
      count(*) filter (where ga = 0) as clean_sheets
    from team_matches
  ),
  finished_match_ids as (
    select match_id from team_matches
  ),
  player_agg as (
    select
      coalesce(sum(mps.assists), 0) as assists,
      coalesce(sum(mps."xG"), 0.0) as total_xg,
      coalesce(sum(mps."xA"), 0.0) as total_xa
    from match_player_stats mps
    where mps.match_id in (select match_id from finished_match_ids)
      and mps.team_id = p_team_id
  ),
  event_agg as (
    select
      count(*) filter (
        where me.event_type = 'tackle'
          and not me.is_deleted
          and me.team_id = p_team_id
      ) as tackles,
      count(*) filter (
        where me.event_type = 'save'
          and not me.is_deleted
          and me.team_id = p_team_id
      ) as saves,
      count(*) filter (
        where me.event_type = 'yellow_card'
          and not me.is_deleted
          and me.team_id = p_team_id
      ) as yellow_cards,
      count(*) filter (
        where me.event_type = 'red_card'
          and not me.is_deleted
          and me.team_id = p_team_id
      ) as red_cards,
      count(distinct me.id) filter (
        where not me.is_deleted and (
          (me.event_type in ('goal', 'penalty_goal') and me.team_id = p_team_id)
          or (me.event_type = 'save' and me.team_id != p_team_id)
        )
      ) as shots_on_target
    from match_events me
    where me.match_id in (select match_id from finished_match_ids)
  )
  select
    ma.matches_played,
    ma.goals_scored,
    ma.goals_conceded,
    ma.goal_difference,
    coalesce(pa.assists, 0) as assists,
    ma.clean_sheets,
    coalesce(ea.shots_on_target, 0) as shots_on_target,
    coalesce(ea.tackles, 0) as tackles,
    coalesce(ea.saves, 0) as saves,
    coalesce(ea.yellow_cards, 0) as yellow_cards,
    coalesce(ea.red_cards, 0) as red_cards,
    coalesce(pa.total_xg, 0.0) as total_xg,
    coalesce(pa.total_xa, 0.0) as total_xa
  from match_agg ma
  left join player_agg pa on true
  left join event_agg ea on true;
$$;
