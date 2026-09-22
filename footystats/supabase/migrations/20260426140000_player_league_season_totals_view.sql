-- Aggregated player stats by league and season from completed matches.
-- This powers player comparison filters (League -> Season).
-- It counts only rows where:
-- 1) player has stats in the match (match_player_stats),
-- 2) player's team is one of the match teams,
-- 3) player belongs to that team around the match date (player_team_memberships),
-- 4) team belongs to the league around the match date (league_team_memberships).

drop view if exists public.v_player_league_season_totals;

create view public.v_player_league_season_totals as
with valid_rows as (
  select
    mps.player_id,
    mps.team_id,
    m.league_id,
    m.season_id,
    m.match_date::date as match_day,
    mps.minutes_played,
    mps.goals,
    mps.assists,
    mps.yellow_cards,
    mps.red_cards,
    mps.rating,
    mps."xG" as xg,
    mps."xA" as xa
  from public.match_player_stats mps
  join public.matches m on m.id = mps.match_id
  where m.status = 'fullTime'
    and mps.team_id in (m."teamA", m."teamB")
    and exists (
      select 1
      from public.player_team_memberships ptm
      where ptm.player_id = mps.player_id
        and ptm.team_id = mps.team_id
        and (ptm.created_at is null or ptm.created_at::date <= m.match_date::date)
        and (ptm.end_date is null or ptm.end_date >= m.match_date::date)
    )
    and exists (
      select 1
      from public.league_team_memberships ltm
      where ltm.league_id = m.league_id
        and ltm.team_id = mps.team_id
        and (ltm.created_at is null or ltm.created_at::date <= m.match_date::date)
        and (ltm.end_date is null or ltm.end_date >= m.match_date::date)
    )
)
select
  vr.player_id,
  vr.league_id,
  l.league_name,
  vr.season_id,
  s.season_name,
  count(*)::bigint as matches,
  coalesce(sum(vr.minutes_played), 0)::bigint as minutes_played,
  coalesce(sum(vr.goals), 0)::bigint as goals,
  coalesce(sum(vr.assists), 0)::bigint as assists,
  coalesce(sum(vr.yellow_cards), 0)::bigint as yellow_cards,
  coalesce(sum(vr.red_cards), 0)::bigint as red_cards,
  0::bigint as chances_created,
  coalesce(sum(vr.xg), 0.0)::double precision as expected_goals,
  coalesce(sum(vr.xa), 0.0)::double precision as expected_assists,
  case
    when count(*) filter (where coalesce(vr.rating, 0) > 0) > 0
      then (sum(vr.rating) filter (where coalesce(vr.rating, 0) > 0)
            / count(*) filter (where coalesce(vr.rating, 0) > 0))::double precision
    else 0.0
  end as avg_rating
from valid_rows vr
left join public.leagues l on l.id = vr.league_id
left join public.seasons s on s.id = vr.season_id
group by
  vr.player_id,
  vr.league_id,
  l.league_name,
  vr.season_id,
  s.season_name;

grant select on public.v_player_league_season_totals to authenticated;
grant select on public.v_player_league_season_totals to anon;
