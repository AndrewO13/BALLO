-- Aggregated player stats for a given calendar year (for radar attributes).
-- Uses match_player_stats joined to matches by match_id.

drop function if exists public.get_player_year_stats(uuid, int);

create or replace function public.get_player_year_stats(
  p_player_id uuid,
  p_year int default extract(year from now())::int
)
returns table (
  year int,
  minutes_played double precision,
  goals double precision,
  assists double precision,
  shots double precision,
  shots_on_target double precision,
  tackles double precision,
  saves double precision,
  xg double precision,
  xa double precision,
  yellow_cards double precision,
  red_cards double precision
)
language sql
stable
security definer
set search_path = public
as $$
with bounds as (
  select
    make_date(p_year, 1, 1) as start_date,
    make_date(p_year + 1, 1, 1) as end_date
)
select
  p_year as year,
  coalesce(sum(mps.minutes_played), 0)::double precision as minutes_played,
  coalesce(sum(mps.goals), 0)::double precision as goals,
  coalesce(sum(mps.assists), 0)::double precision as assists,
  coalesce(sum(mps.shots), 0)::double precision as shots,
  coalesce(sum(mps.shots_on_target), 0)::double precision as shots_on_target,
  coalesce(sum(mps.tackles), 0)::double precision as tackles,
  coalesce(sum(mps.saves), 0)::double precision as saves,
  coalesce(sum(mps."xG"), 0.0)::double precision as xg,
  coalesce(sum(mps."xA"), 0.0)::double precision as xa,
  coalesce(sum(mps.yellow_cards), 0)::double precision as yellow_cards,
  coalesce(sum(mps.red_cards), 0)::double precision as red_cards
from public.match_player_stats mps
inner join public.matches m on m.id = mps.match_id
cross join bounds b
where mps.player_id = p_player_id
  and m.status = 'fullTime'
  and (m.match_date::date >= b.start_date and m.match_date::date < b.end_date);
$$;

grant execute on function public.get_player_year_stats(uuid, int) to authenticated;

