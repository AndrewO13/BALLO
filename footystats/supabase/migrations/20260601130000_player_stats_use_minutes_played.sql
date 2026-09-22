-- Align appearances (matches played) with lineup-derived minutes_played:
-- only count a match when the player has minutes_played > 0.

-- Year overall + per-team (profile Stats tab)
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
  count(distinct mps.match_id) filter (
    where coalesce(mps.minutes_played, 0) > 0
  )::bigint as matches,
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
    when count(*) filter (
      where coalesce(mps.rating, 0) > 0
        and coalesce(mps.minutes_played, 0) > 0
    ) > 0
      then (
        sum(mps.rating) filter (
          where coalesce(mps.rating, 0) > 0
            and coalesce(mps.minutes_played, 0) > 0
        )
        / count(*) filter (
          where coalesce(mps.rating, 0) > 0
            and coalesce(mps.minutes_played, 0) > 0
        )
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
  count(distinct mps.match_id) filter (
    where coalesce(mps.minutes_played, 0) > 0
  )::bigint as matches,
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
    when count(*) filter (
      where coalesce(mps.rating, 0) > 0
        and coalesce(mps.minutes_played, 0) > 0
    ) > 0
      then (
        sum(mps.rating) filter (
          where coalesce(mps.rating, 0) > 0
            and coalesce(mps.minutes_played, 0) > 0
        )
        / count(*) filter (
          where coalesce(mps.rating, 0) > 0
            and coalesce(mps.minutes_played, 0) > 0
        )
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

-- Career / all-time (profile Career tab)
create or replace function public.get_player_all_time_stats(
  p_player_id uuid
)
returns table (
  matches bigint,
  minutes_played double precision,
  goals double precision,
  assists double precision,
  tackles double precision,
  saves double precision,
  yellow_cards double precision,
  red_cards double precision,
  avg_rating double precision
)
language sql
stable
security definer
set search_path = public
as $$
select
  count(distinct mps.match_id) filter (
    where coalesce(mps.minutes_played, 0) > 0
  )::bigint as matches,
  coalesce(sum(mps.minutes_played), 0)::double precision as minutes_played,
  coalesce(sum(mps.goals), 0)::double precision as goals,
  coalesce(sum(mps.assists), 0)::double precision as assists,
  coalesce(sum(mps.tackles), 0)::double precision as tackles,
  coalesce(sum(mps.saves), 0)::double precision as saves,
  coalesce(sum(mps.yellow_cards), 0)::double precision as yellow_cards,
  coalesce(sum(mps.red_cards), 0)::double precision as red_cards,
  case
    when count(*) filter (
      where coalesce(mps.rating, 0) > 0
        and coalesce(mps.minutes_played, 0) > 0
    ) > 0
      then (
        sum(mps.rating) filter (
          where coalesce(mps.rating, 0) > 0
            and coalesce(mps.minutes_played, 0) > 0
        )
        / count(*) filter (
          where coalesce(mps.rating, 0) > 0
            and coalesce(mps.minutes_played, 0) > 0
        )
      )::double precision
    else 0.0
  end as avg_rating
from public.match_player_stats mps
inner join public.matches m on m.id = mps.match_id
where mps.player_id = p_player_id
  and m.status = 'fullTime';
$$;

create or replace function public.get_player_career_team_stats(
  p_player_id uuid
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
select
  mps.team_id,
  coalesce(nullif(trim(t.team_name), ''), nullif(trim(t.short_form), ''), 'Team') as team_name,
  t.logo_id,
  extract(year from m.match_date)::int as year,
  count(distinct mps.match_id) filter (
    where coalesce(mps.minutes_played, 0) > 0
  )::bigint as matches,
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
    when count(*) filter (
      where coalesce(mps.rating, 0) > 0
        and coalesce(mps.minutes_played, 0) > 0
    ) > 0
      then (
        sum(mps.rating) filter (
          where coalesce(mps.rating, 0) > 0
            and coalesce(mps.minutes_played, 0) > 0
        )
        / count(*) filter (
          where coalesce(mps.rating, 0) > 0
            and coalesce(mps.minutes_played, 0) > 0
        )
      )::double precision
    else 0.0
  end as avg_rating
from public.match_player_stats mps
inner join public.matches m on m.id = mps.match_id
inner join public.teams t on t.id = mps.team_id
where mps.player_id = p_player_id
  and m.status = 'fullTime'
group by
  mps.team_id,
  t.team_name,
  t.short_form,
  t.logo_id,
  extract(year from m.match_date)::int
order by year desc, team_name asc;
$$;

-- Player comparison (league / season filters)
drop view if exists public.v_player_league_season_totals;

create view public.v_player_league_season_totals as
with valid_rows as (
  select
    mps.match_id,
    mps.player_id,
    mps.team_id,
    m.league_id,
    m.season_id,
    m.match_date::date as match_day,
    mps.minutes_played,
    mps.goals,
    mps.assists,
    mps.tackles,
    mps.saves,
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
  count(distinct vr.match_id) filter (
    where coalesce(vr.minutes_played, 0) > 0
  )::bigint as matches,
  coalesce(sum(vr.minutes_played), 0)::bigint as minutes_played,
  coalesce(sum(vr.goals), 0)::bigint as goals,
  coalesce(sum(vr.assists), 0)::bigint as assists,
  coalesce(sum(vr.tackles), 0)::bigint as tackles,
  coalesce(sum(vr.saves), 0)::bigint as saves,
  coalesce(sum(vr.yellow_cards), 0)::bigint as yellow_cards,
  coalesce(sum(vr.red_cards), 0)::bigint as red_cards,
  0::bigint as chances_created,
  coalesce(sum(vr.xg), 0.0)::double precision as expected_goals,
  coalesce(sum(vr.xa), 0.0)::double precision as expected_assists,
  case
    when count(*) filter (
      where coalesce(vr.rating, 0) > 0
        and coalesce(vr.minutes_played, 0) > 0
    ) > 0
      then (
        sum(vr.rating) filter (
          where coalesce(vr.rating, 0) > 0
            and coalesce(vr.minutes_played, 0) > 0
        )
        / count(*) filter (
          where coalesce(vr.rating, 0) > 0
            and coalesce(vr.minutes_played, 0) > 0
        )
      )::double precision
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
