-- Optional season scope for league team and player aggregate RPCs (same shape as
-- get_league_team_stats / get_league_player_stats; p_season_id null = all seasons).

drop function if exists public.get_league_team_stats_filtered(uuid, uuid);

create or replace function public.get_league_team_stats_filtered(
  p_league_id uuid,
  p_season_id uuid default null
)
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
      and (p_season_id is null or m.season_id = p_season_id)

    union all

    select m.id, m."teamB",
           m."teamB_score", m."teamA_score"
    from matches m
    where m.league_id = p_league_id
      and m.status = 'fullTime'
      and m."teamA_score" is not null
      and m."teamB_score" is not null
      and (p_season_id is null or m.season_id = p_season_id)
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
    where league_id = p_league_id
      and status = 'fullTime'
      and (p_season_id is null or season_id = p_season_id)
  ),
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

drop function if exists public.get_league_player_stats_filtered(uuid, uuid);

create or replace function public.get_league_player_stats_filtered(
  p_league_id uuid,
  p_season_id uuid default null
)
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
    where league_id = p_league_id
      and status = 'fullTime'
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
