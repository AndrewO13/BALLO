-- League standings and team stats calculated from completed matches.
-- Call via: select * from get_league_standings('your-league-uuid');
-- Call via: select * from get_league_team_stats('your-league-uuid');

create or replace function public.get_league_standings(p_league_id uuid)
returns table (
  team_id       uuid,
  team_short_form text,
  team_logo     text,
  played        bigint,
  wins          bigint,
  draws         bigint,
  losses        bigint,
  goals_for     bigint,
  goals_against bigint,
  goal_difference bigint,
  points        bigint
)
language sql
security definer
set search_path = public
as $$
  with team_matches as (
    -- One row per team per finished match (unpivot home/away)
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
  aggregated as (
    select
      tm.tid,
      count(*)                                   as played,
      count(*) filter (where tm.gf > tm.ga)      as wins,
      count(*) filter (where tm.gf = tm.ga)      as draws,
      count(*) filter (where tm.gf < tm.ga)      as losses,
      coalesce(sum(tm.gf), 0)                    as goals_for,
      coalesce(sum(tm.ga), 0)                    as goals_against,
      coalesce(sum(tm.gf - tm.ga), 0)            as goal_difference,
      count(*) filter (where tm.gf > tm.ga) * 3
        + count(*) filter (where tm.gf = tm.ga)  as points
    from team_matches tm
    group by tm.tid
  )
  select
    a.tid           as team_id,
    t.short_form    as team_short_form,
    t.logo_id       as team_logo,
    a.played,
    a.wins,
    a.draws,
    a.losses,
    a.goals_for,
    a.goals_against,
    a.goal_difference,
    a.points
  from aggregated a
  join teams t on t.id = a.tid
  order by a.points desc, a.goal_difference desc, a.goals_for desc, t.short_form;
$$;

-- Team stats aggregated from completed matches + match_events.
-- Returns one row per team with totals; divide by matches_played in the client
-- for "per match" averages.
--
-- Shots on target = goals scored by the team (goal, penalty_goal events)
--                 + saves made by the opponent (save events where team_id != tid).
-- A missed_goal that is NOT a save is off-target and excluded.

drop function if exists public.get_league_team_stats(uuid);

create or replace function public.get_league_team_stats(p_league_id uuid)
returns table (
  team_id            uuid,
  team_short_form    text,
  team_logo          text,
  matches_played     bigint,
  total_goals        bigint,
  total_conceded     bigint,
  clean_sheets       bigint,
  shots_on_target    bigint,
  total_tackles      bigint,
  total_saves        bigint,
  total_yellow_cards bigint,
  total_red_cards    bigint
)
language sql
security definer
set search_path = public
as $$
  with match_team as (
    select m.id as match_id, m."teamA" as tid,
           m."teamA_score" as gf, m."teamB_score" as ga
    from matches m
    where m.league_id = p_league_id
      and m.status = 'fullTime'
      and m."teamA_score" is not null
      and m."teamB_score" is not null

    union all

    select m.id, m."teamB",
           m."teamB_score", m."teamA_score"
    from matches m
    where m.league_id = p_league_id
      and m.status = 'fullTime'
      and m."teamA_score" is not null
      and m."teamB_score" is not null
  ),
  match_agg as (
    select
      mt.tid,
      count(distinct mt.match_id)                   as matches_played,
      coalesce(sum(mt.gf), 0)                       as total_goals,
      coalesce(sum(mt.ga), 0)                       as total_conceded,
      count(*) filter (where mt.ga = 0)             as clean_sheets
    from match_team mt
    group by mt.tid
  ),
  finished_match_ids as (
    select id from matches
    where league_id = p_league_id and status = 'fullTime'
  ),
  -- Shots on target per team: goals by the team + saves by the opponent.
  sot_agg as (
    select
      mt.tid,
      count(distinct me.id) filter (
        where not me.is_deleted
          and (
            (me.event_type in ('goal', 'penalty_goal') and me.team_id = mt.tid)
            or
            (me.event_type = 'save' and me.team_id != mt.tid)
          )
      ) as shots_on_target
    from match_team mt
    left join match_events me on me.match_id = mt.match_id
    group by mt.tid
  ),
  event_agg as (
    select
      me.team_id as tid,
      count(*) filter (where me.event_type = 'tackle'      and not me.is_deleted) as total_tackles,
      count(*) filter (where me.event_type = 'save'        and not me.is_deleted) as total_saves,
      count(*) filter (where me.event_type = 'yellow_card' and not me.is_deleted) as total_yellow_cards,
      count(*) filter (where me.event_type = 'red_card'    and not me.is_deleted) as total_red_cards
    from match_events me
    where me.match_id in (select id from finished_match_ids)
    group by me.team_id
  )
  select
    ma.tid              as team_id,
    t.short_form        as team_short_form,
    t.logo_id           as team_logo,
    ma.matches_played,
    ma.total_goals,
    ma.total_conceded,
    ma.clean_sheets,
    coalesce(sa.shots_on_target, 0)    as shots_on_target,
    coalesce(ea.total_tackles, 0)      as total_tackles,
    coalesce(ea.total_saves, 0)        as total_saves,
    coalesce(ea.total_yellow_cards, 0) as total_yellow_cards,
    coalesce(ea.total_red_cards, 0)    as total_red_cards
  from match_agg ma
  join teams t on t.id = ma.tid
  left join sot_agg sa on sa.tid = ma.tid
  left join event_agg ea on ea.tid = ma.tid
  order by t.short_form;
$$;

-- Player stats aggregated from match_player_stats for a league.
-- Returns one row per player with totals; divide by matches_played in the
-- client for "per match" averages.

drop function if exists public.get_league_player_stats(uuid);

create or replace function public.get_league_player_stats(p_league_id uuid)
returns table (
  player_id             uuid,
  player_name           text,
  image_url             text,
  team_id               uuid,
  team_short_form       text,
  team_logo             text,
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
  with league_matches as (
    select id from matches
    where league_id = p_league_id and status = 'fullTime'
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
      coalesce(sum(mps.yellow_cards), 0)                        as total_yellow_cards,
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
    where mps.match_id in (select id from league_matches)
    group by mps.player_id
  ),
  player_team as (
    select distinct on (mps.player_id)
      mps.player_id,
      mps.team_id
    from match_player_stats mps
    where mps.match_id in (select id from league_matches)
    group by mps.player_id, mps.team_id
    order by mps.player_id, count(*) desc
  )
  select
    pa.player_id,
    p.player_name,
    p.image_url,
    pt.team_id,
    t.short_form       as team_short_form,
    t.logo_id          as team_logo,
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
  join player_team pt on pt.player_id = pa.player_id
  join players p on p.id = pa.player_id
  join teams t on t.id = pt.team_id
  order by pa.total_goals desc, p.player_name;
$$;

-- Team summary stats for the team detail "Stats" tab.
-- Aggregates completed matches only.
drop function if exists public.get_team_summary_stats(uuid);

create or replace function public.get_team_summary_stats(p_team_id uuid)
returns table (
  matches_played      bigint,
  goals_scored       bigint,
  goals_conceded     bigint,
  goal_difference    bigint,
  assists            bigint,
  clean_sheets       bigint,
  shots_on_target    bigint,
  tackles            bigint,
  saves              bigint,
  yellow_cards       bigint,
  red_cards          bigint,
  total_xg           double precision,
  total_xa           double precision
)
language sql
security definer
set search_path = public
as $$
  with team_matches as (
    -- Team as home side
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

    -- Team as away side
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
      count(*)                  as matches_played,
      coalesce(sum(gf), 0)      as goals_scored,
      coalesce(sum(ga), 0)      as goals_conceded,
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
      coalesce(sum(mps."xG"), 0.0)  as total_xg,
      coalesce(sum(mps."xA"), 0.0)  as total_xa
    from match_player_stats mps
    where mps.match_id in (select match_id from finished_match_ids)
      and mps.team_id = p_team_id
  ),
  event_agg as (
    select
      count(*) filter (
        where me.event_type = 'tackle'
          and not me.is_deleted
      ) as tackles,
      count(*) filter (
        where me.event_type = 'save'
          and not me.is_deleted
      ) as saves,
      count(*) filter (
        where me.event_type = 'yellow_card'
          and not me.is_deleted
      ) as yellow_cards,
      count(*) filter (
        where me.event_type = 'red_card'
          and not me.is_deleted
      ) as red_cards,
      -- Shots on target = team goals (goal/penalty_goal) + opponent saves against the team.
      count(distinct me.id) filter (
        where not me.is_deleted and (
          (me.event_type in ('goal', 'penalty_goal') and me.team_id = p_team_id)
          or
          (me.event_type = 'save' and me.team_id != p_team_id)
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

-- Player stats aggregated from match_player_stats for a single team.

drop function if exists public.get_team_player_stats(uuid);

create or replace function public.get_team_player_stats(p_team_id uuid)
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
      coalesce(sum(mps.yellow_cards), 0)                        as total_yellow_cards,
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
