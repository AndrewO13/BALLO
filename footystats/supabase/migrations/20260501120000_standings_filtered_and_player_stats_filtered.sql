-- Season-filtered standings (same semantics as get_league_standings) and
-- league/season-filtered team player aggregates for team detail tabs.

drop function if exists public.get_league_standings_filtered(uuid, uuid);

create or replace function public.get_league_standings_filtered(
  p_league_id uuid,
  p_season_id uuid default null
)
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
      and (p_season_id is null or m.season_id = p_season_id)
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
      and (p_season_id is null or m.season_id = p_season_id)

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
      and (p_season_id is null or m.season_id = p_season_id)
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
      and (p_season_id is null or m.season_id = p_season_id)

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
      and (p_season_id is null or m.season_id = p_season_id)
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

drop function if exists public.get_team_player_stats_filtered(uuid, uuid, uuid);

create or replace function public.get_team_player_stats_filtered(
  p_team_id uuid,
  p_league_id uuid default null,
  p_season_id uuid default null
)
returns table (
  player_id             uuid,
  player_name           text,
  image_url             text,
  "position"            text,
  matches_played        bigint,
  total_goals           bigint,
  total_assists         bigint,
  goals_assists         bigint,
  total_saves           bigint,
  total_yellow_cards    bigint,
  total_red_cards       bigint,
  total_tackles         bigint,
  total_shots           bigint,
  total_shots_on_target bigint,
  total_xg              double precision,
  total_xa              double precision,
  avg_rating            double precision,
  missed_opportunities  bigint
)
language sql
security definer
set search_path = public
as $$
  with team_matches as (
    select id from matches
    where ("teamA" = p_team_id or "teamB" = p_team_id)
      and status = 'fullTime'
      and (p_league_id is null or league_id = p_league_id)
      and (p_season_id is null or season_id = p_season_id)
  ),
  player_agg as (
    select
      mps.player_id,
      count(*)                                                  as matches_played,
      coalesce(sum(mps.goals), 0)                               as total_goals,
      coalesce(sum(mps.assists), 0)                             as total_assists,
      coalesce(sum(mps.goals), 0) + coalesce(sum(mps.assists), 0)
                                                                as goals_assists,
      coalesce(sum(mps.saves), 0)                               as total_saves,
      coalesce(sum(mps.yellow_cards), 0)                       as total_yellow_cards,
      coalesce(sum(mps.red_cards), 0)                           as total_red_cards,
      coalesce(sum(mps.tackles), 0)                             as total_tackles,
      coalesce(sum(mps.shots), 0)                               as total_shots,
      coalesce(sum(mps.shots_on_target), 0)                     as total_shots_on_target,
      coalesce(sum(mps."xG"), 0.0)                              as total_xg,
      coalesce(sum(mps."xA"), 0.0)                              as total_xa,
      case
        when count(*) filter (where mps.rating > 0) > 0
        then sum(mps.rating) filter (where mps.rating > 0)
             / count(*) filter (where mps.rating > 0)
        else 0.0
      end                                                       as avg_rating,
      greatest(coalesce(sum(mps.shots), 0) - coalesce(sum(mps.goals), 0), 0)
                                                                as missed_opportunities
    from match_player_stats mps
    where mps.match_id in (select id from team_matches)
      and mps.team_id = p_team_id
    group by mps.player_id
  )
  select
    pa.player_id,
    p.player_name,
    p.image_url,
    p."position",
    pa.matches_played,
    pa.total_goals,
    pa.total_assists,
    pa.goals_assists,
    pa.total_saves,
    pa.total_yellow_cards,
    pa.total_red_cards,
    pa.total_tackles,
    pa.total_shots,
    pa.total_shots_on_target,
    pa.total_xg,
    pa.total_xa,
    pa.avg_rating,
    pa.missed_opportunities
  from player_agg pa
  join players p on p.id = pa.player_id
  order by pa.total_goals desc, p.player_name;
$$;
