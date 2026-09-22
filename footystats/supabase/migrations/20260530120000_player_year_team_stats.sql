-- Calendar-year player stats overall and grouped by team (for profile Stats tab).

drop function if exists public.get_player_year_stats(uuid, int);
drop function if exists public.get_player_year_team_stats(uuid, int);

create or replace function public.get_player_year_stats(
  p_player_id uuid,
  p_year int default extract(year from now())::int
)
returns table (
  year int,
  matches bigint,
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
  red_cards double precision,
  avg_rating double precision
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
  count(distinct mps.match_id)::bigint as matches,
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
  coalesce(sum(mps.red_cards), 0)::double precision as red_cards,
  case
    when count(*) filter (where coalesce(mps.rating, 0) > 0) > 0
      then (
        sum(mps.rating) filter (where coalesce(mps.rating, 0) > 0)
        / count(*) filter (where coalesce(mps.rating, 0) > 0)
      )::double precision
    else 0.0
  end as avg_rating
from public.match_player_stats mps
inner join public.matches m on m.id = mps.match_id
cross join bounds b
where mps.player_id = p_player_id
  and m.status = 'fullTime'
  and (m.match_date::date >= b.start_date and m.match_date::date < b.end_date);
$$;

create or replace function public.get_player_year_team_stats(
  p_player_id uuid,
  p_year int default extract(year from now())::int
)
returns table (
  team_id uuid,
  team_name text,
  logo_id text,
  year int,
  matches bigint,
  minutes_played double precision,
  goals double precision,
  assists double precision,
  shots double precision,
  shots_on_target double precision,
  shots_off_target double precision,
  tackles double precision,
  saves double precision,
  xg double precision,
  xa double precision,
  yellow_cards double precision,
  red_cards double precision,
  avg_rating double precision
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
  mps.team_id,
  coalesce(nullif(trim(t.team_name), ''), nullif(trim(t.short_form), ''), 'Team') as team_name,
  t.logo_id,
  p_year as year,
  count(distinct mps.match_id)::bigint as matches,
  coalesce(sum(mps.minutes_played), 0)::double precision as minutes_played,
  coalesce(sum(mps.goals), 0)::double precision as goals,
  coalesce(sum(mps.assists), 0)::double precision as assists,
  coalesce(sum(mps.shots), 0)::double precision as shots,
  coalesce(sum(mps.shots_on_target), 0)::double precision as shots_on_target,
  greatest(
    0,
    coalesce(sum(mps.shots), 0) - coalesce(sum(mps.shots_on_target), 0)
  )::double precision as shots_off_target,
  coalesce(sum(mps.tackles), 0)::double precision as tackles,
  coalesce(sum(mps.saves), 0)::double precision as saves,
  coalesce(sum(mps."xG"), 0.0)::double precision as xg,
  coalesce(sum(mps."xA"), 0.0)::double precision as xa,
  coalesce(sum(mps.yellow_cards), 0)::double precision as yellow_cards,
  coalesce(sum(mps.red_cards), 0)::double precision as red_cards,
  case
    when count(*) filter (where coalesce(mps.rating, 0) > 0) > 0
      then (
        sum(mps.rating) filter (where coalesce(mps.rating, 0) > 0)
        / count(*) filter (where coalesce(mps.rating, 0) > 0)
      )::double precision
    else 0.0
  end as avg_rating
from public.match_player_stats mps
inner join public.matches m on m.id = mps.match_id
inner join public.teams t on t.id = mps.team_id
cross join bounds b
where mps.player_id = p_player_id
  and m.status = 'fullTime'
  and (m.match_date::date >= b.start_date and m.match_date::date < b.end_date)
group by mps.team_id, t.team_name, t.short_form, t.logo_id
order by team_name asc;
$$;

grant execute on function public.get_player_year_stats(uuid, int) to authenticated;
grant execute on function public.get_player_year_team_stats(uuid, int) to authenticated;
