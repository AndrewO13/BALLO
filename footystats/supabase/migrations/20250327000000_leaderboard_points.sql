-- Leaderboard: position weights, per-match points view, and get_leaderboard RPC.
-- Weights match app design (goals/assists/tackles/saves/clean sheets + minutes/rating − cards).

alter table public.match_player_stats
  add column if not exists minutes_played integer not null default 0;

create table if not exists public.positions_points_weights (
  position text primary key,
  goal_w double precision not null,
  assist_w double precision not null,
  tackle_w double precision not null,
  save_w double precision not null,
  clean_sheet_w double precision not null,
  minutes_w double precision not null default 0.5,
  rating_w double precision not null default 100,
  -- Positive magnitudes: these are subtracted from match_points (penalties).
  yellow_w double precision not null default 15,
  red_w double precision not null default 50
);

insert into public.positions_points_weights (
  position, goal_w, assist_w, tackle_w, save_w, clean_sheet_w, minutes_w, rating_w, yellow_w, red_w
) values
  ('ATTACKER',   120, 80,  8,  0,  0, 0.5, 100, 15, 50),
  ('DEFENDER',   160, 85, 16,  0, 45, 0.5, 100, 15, 50),
  ('GOALKEEPER', 180, 70,  6, 18, 55, 0.5, 100, 15, 50),
  ('MIDFIELDER', 110, 95, 10,  0, 20, 0.5, 100, 15, 50)
on conflict (position) do update set
  goal_w = excluded.goal_w,
  assist_w = excluded.assist_w,
  tackle_w = excluded.tackle_w,
  save_w = excluded.save_w,
  clean_sheet_w = excluded.clean_sheet_w,
  minutes_w = excluded.minutes_w,
  rating_w = excluded.rating_w,
  yellow_w = excluded.yellow_w,
  red_w = excluded.red_w;

drop view if exists public.v_player_match_points cascade;

create or replace view public.v_player_match_points as
with pos_key as (
  select
    mps.match_id,
    mps.player_id,
    mps.team_id,
    m.league_id,
    m.gameweek as gameweek_id,
    m.match_date,
    case
      when upper(trim(coalesce(p.position, ''))) in ('GOALKEEPER', 'GK') then 'GOALKEEPER'
      when upper(trim(coalesce(p.position, ''))) like '%GOAL%' then 'GOALKEEPER'
      when upper(trim(coalesce(p.position, ''))) in ('DEFENDER', 'DEF', 'CB', 'LB', 'RB') then 'DEFENDER'
      when upper(trim(coalesce(p.position, ''))) like '%DEF%' then 'DEFENDER'
      when upper(trim(coalesce(p.position, ''))) in ('MIDFIELDER', 'MID', 'CM', 'CDM', 'CAM', 'LM', 'RM')
        then 'MIDFIELDER'
      when upper(trim(coalesce(p.position, ''))) like '%MID%' then 'MIDFIELDER'
      when upper(trim(coalesce(p.position, ''))) in ('ATTACKER', 'ATT', 'ST', 'FW', 'FORWARD') then 'ATTACKER'
      when upper(trim(coalesce(p.position, ''))) like '%ATT%' then 'ATTACKER'
      when upper(trim(coalesce(p.position, ''))) like '%FWD%' then 'ATTACKER'
      else 'MIDFIELDER'
    end as position_key,
    coalesce(mps.goals, 0)::double precision as g,
    coalesce(mps.assists, 0)::double precision as a,
    coalesce(mps.tackles, 0)::double precision as t,
    coalesce(mps.saves, 0)::double precision as s,
    case
      when m."teamA" = mps.team_id and coalesce(m."teamB_score", 0) = 0 then 1.0
      when m."teamB" = mps.team_id and coalesce(m."teamA_score", 0) = 0 then 1.0
      else 0.0
    end::double precision as cs,
    coalesce(mps.minutes_played, 0)::double precision as mins,
    coalesce(mps.rating, 0)::double precision as rtg,
    coalesce(mps.yellow_cards, 0)::double precision as yc,
    coalesce(mps.red_cards, 0)::double precision as rc
  from public.match_player_stats mps
  inner join public.matches m on m.id = mps.match_id and m.status = 'fullTime'
  inner join public.players p on p.id = mps.player_id
)
select
  pk.match_id,
  pk.player_id,
  pk.league_id,
  pk.team_id,
  pk.gameweek_id,
  pk.match_date,
  pk.position_key,
  (
    pk.g * w.goal_w
    + pk.a * w.assist_w
    + pk.t * w.tackle_w
    + pk.s * w.save_w
    + pk.cs * w.clean_sheet_w
    + pk.mins * w.minutes_w
    + pk.rtg * w.rating_w
    -- Yellow / red: always penalties (never add to total).
    - (pk.yc * w.yellow_w + pk.rc * w.red_w)
  )::double precision as match_points
from pos_key pk
inner join public.positions_points_weights w on w.position = pk.position_key;

-- Convenience aggregates (optional; app uses get_leaderboard).
create or replace view public.v_player_all_time_points as
select
  player_id,
  sum(match_points)::double precision as total_points
from public.v_player_match_points
group by player_id;

grant select on public.positions_points_weights to authenticated, anon;
grant select on public.v_player_match_points to authenticated, anon;
grant select on public.v_player_all_time_points to authenticated, anon;

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

  -- total_points / gw_points are always from ALL finished matches on the app.
  -- p_mode only decides who is listed: everyone (overall), anyone who played in
  -- this league (league), or current squad members (team).
  return query
  with
  global_totals as (
    select
      v.player_id,
      sum(v.match_points)::double precision as total_points
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
      coalesce(g.total_points, 0)::double precision as total_points,
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

comment on view public.v_player_match_points is
  'Fantasy-style points per player per fullTime match. Yellow/red card weights (yellow_w, red_w) are subtracted from the total.';
comment on function public.get_leaderboard(text, uuid, uuid, int) is
  'p_mode: overall | league | team. previous_rank = standing if latest gameweek points were ignored (vs board_rank after that week).';
