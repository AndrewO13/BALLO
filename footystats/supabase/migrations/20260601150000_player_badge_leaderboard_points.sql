-- Profile milestone badges: bonus leaderboard points when career targets are met.
-- Keep thresholds in sync with lib/domain/models/player_badge.dart (PlayerBadges).

create or replace function public.player_badge_bonus_points(p_player_id uuid)
returns double precision
language sql
stable
security definer
set search_path = public
as $$
with career as (
  select
    coalesce(sum(mps.goals), 0)::double precision as goals,
    coalesce(sum(mps.tackles), 0)::double precision as tackles
  from public.match_player_stats mps
  inner join public.matches m on m.id = mps.match_id
  where mps.player_id = p_player_id
    and m.status = 'fullTime'
)
select
  coalesce(
    (case when c.goals >= 100 then 10.0 else 0.0 end)
    + (case when c.tackles >= 100 then 10.0 else 0.0 end)
    + (case when c.goals >= 10000 then 100.0 else 0.0 end),
    0.0
  )
from career c;
$$;

grant execute on function public.player_badge_bonus_points(uuid) to authenticated;

comment on function public.player_badge_bonus_points(uuid) is
  'Sum of leaderboard bonus points from earned profile badges (Iron-foot, Lock-down defender, Footy Master).';

drop function if exists public.get_leaderboard(text, uuid, uuid, int);

create or replace function public.get_leaderboard(
  p_mode text,
  p_league_id uuid default null,
  p_team_id uuid default null,
  p_limit int default 200
)
returns table (
  player_id uuid,
  player_name text,
  image_url text,
  total_points double precision,
  gw_points double precision,
  board_rank bigint,
  previous_rank bigint
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if p_mode not in ('overall', 'league', 'team') then
    raise exception 'Invalid p_mode: %', p_mode;
  end if;
  if p_mode = 'league' and p_league_id is null then
    return;
  end if;
  if p_mode = 'team' and p_team_id is null then
    return;
  end if;

  return query
  with
  global_totals as (
    select
      v.player_id,
      sum(v.match_points)::double precision as match_points
    from public.v_player_match_points v
    group by v.player_id
  ),
  latest_gw as (
    select m.gameweek as gw_id
    from public.matches m
    where m.status = 'fullTime'
      and m.gameweek is not null
    order by m.match_date desc nulls last, m.id desc
    limit 1
  ),
  gw_agg as (
    select
      v.player_id,
      sum(v.match_points)::double precision as gw_points
    from public.v_player_match_points v
    cross join latest_gw lg
    where lg.gw_id is not null
      and v.gameweek_id = lg.gw_id
    group by v.player_id
  ),
  eligible_players as (
    select distinct q.pid
    from (
      select v.player_id as pid
      from public.v_player_match_points v
      where p_mode in ('overall', 'league')
        and (p_mode = 'overall' or v.league_id = p_league_id)
      union
      select ptm.player_id as pid
      from public.player_team_memberships ptm
      where p_mode = 'team'
        and ptm.team_id = p_team_id
        and ptm.end_date is null
    ) q
  ),
  leaderboard_core as (
    select
      e.pid as pid,
      coalesce(p.player_name, '')::text as player_name,
      p.image_url::text as image_url,
      (
        coalesce(g.match_points, 0)::double precision
        + public.player_badge_bonus_points(e.pid)
      ) as total_points,
      coalesce(w.gw_points, 0)::double precision as gw_points
    from eligible_players e
    inner join public.players p on p.id = e.pid
    left join global_totals g on g.player_id = e.pid
    left join gw_agg w on w.player_id = e.pid
  ),
  ranked as (
    select
      lc.pid,
      lc.player_name,
      lc.image_url,
      lc.total_points,
      lc.gw_points,
      row_number() over (
        order by lc.total_points desc nulls last, lc.player_name asc
      )::bigint as board_rank,
      row_number() over (
        order by (lc.total_points - lc.gw_points) desc nulls last, lc.player_name asc
      )::bigint as previous_rank
    from leaderboard_core lc
  )
  select
    r.pid as player_id,
    r.player_name,
    r.image_url,
    r.total_points,
    r.gw_points,
    r.board_rank,
    r.previous_rank
  from ranked r
  order by r.board_rank asc, r.player_name asc
  limit greatest(1, least(p_limit, 500));
end;
$$;

grant execute on function public.get_leaderboard(text, uuid, uuid, int) to authenticated;

comment on function public.get_leaderboard(text, uuid, uuid, int) is
  'p_mode: overall | league | team. total_points includes match fantasy points plus earned profile badge bonuses.';
