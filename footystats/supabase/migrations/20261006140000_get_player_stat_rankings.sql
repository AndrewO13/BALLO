-- App-wide player statistical rankings (not fantasy/leaderboard points).
-- Period: year | all_time. Ranked by a single outstanding stat.

create or replace function public.get_player_stat_rankings(
  p_period text,
  p_stat text,
  p_year integer default null,
  p_limit integer default 25
)
returns table (
  player_id uuid,
  player_name text,
  image_url text,
  player_position text,
  team_name text,
  matches bigint,
  stat_value double precision,
  board_rank bigint
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_year int;
  v_limit int;
  v_min_shots int;
  v_min_matches int;
begin
  if p_period not in ('year', 'all_time') then
    raise exception 'Invalid p_period: %', p_period;
  end if;
  if p_stat not in (
    'goals',
    'assists',
    'goal_contributions',
    'shooting_pct',
    'avg_rating',
    'tackles',
    'saves',
    'shots_on_target',
    'goals_per_match'
  ) then
    raise exception 'Invalid p_stat: %', p_stat;
  end if;

  v_year := coalesce(
    p_year,
    extract(year from (current_timestamp at time zone 'utc'))::int
  );
  v_limit := greatest(1, least(coalesce(p_limit, 25), 50));
  v_min_shots := case when p_period = 'year' then 8 else 15 end;
  v_min_matches := case when p_period = 'year' then 3 else 5 end;

  return query
  with totals as (
    select
      mps.player_id,
      count(distinct mps.match_id) filter (
        where coalesce(mps.minutes_played, 0) > 0
      )::bigint as matches,
      coalesce(sum(mps.goals), 0)::double precision as goals,
      coalesce(sum(mps.assists), 0)::double precision as assists,
      coalesce(sum(mps.shots), 0)::double precision as shots,
      coalesce(sum(mps.shots_on_target), 0)::double precision as shots_on_target,
      coalesce(sum(mps.tackles), 0)::double precision as tackles,
      coalesce(sum(mps.saves), 0)::double precision as saves,
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
        else 0::double precision
      end as avg_rating
    from public.match_player_stats mps
    inner join public.matches m on m.id = mps.match_id
    inner join public.players p on p.id = mps.player_id
    where m.status = 'fullTime'
      and p.deleted_at is null
      and p.account_type = 'player'
      and (
        p_period = 'all_time'
        or extract(year from m.match_date)::int = v_year
      )
    group by mps.player_id
  ),
  scored as (
    select
      t.player_id,
      t.matches,
      case p_stat
        when 'goals' then t.goals
        when 'assists' then t.assists
        when 'goal_contributions' then t.goals + t.assists
        when 'shooting_pct' then
          case
            when t.shots >= v_min_shots
              then (100.0 * t.shots_on_target / nullif(t.shots, 0))
            else null
          end
        when 'avg_rating' then
          case
            when t.matches >= v_min_matches then t.avg_rating
            else null
          end
        when 'tackles' then t.tackles
        when 'saves' then t.saves
        when 'shots_on_target' then t.shots_on_target
        when 'goals_per_match' then
          case
            when t.matches >= v_min_matches
              then t.goals / t.matches::double precision
            else null
          end
      end as stat_value
    from totals t
  ),
  eligible as (
    select
      s.player_id,
      s.matches,
      s.stat_value
    from scored s
    where s.stat_value is not null
      and (
        p_stat in ('shooting_pct', 'avg_rating', 'goals_per_match')
        or s.stat_value > 0
      )
  ),
  ranked as (
    select
      e.player_id,
      coalesce(p.player_name, '')::text as player_name,
      p.image_url::text as image_url,
      coalesce(p.position, '')::text as player_position,
      e.matches,
      e.stat_value,
      row_number() over (
        order by e.stat_value desc nulls last, coalesce(p.player_name, '') asc
      )::bigint as board_rank
    from eligible e
    inner join public.players p on p.id = e.player_id
  ),
  top as (
    select *
    from ranked r
    where r.board_rank <= v_limit
  )
  select
    t.player_id,
    t.player_name,
    t.image_url,
    t.player_position,
    coalesce(
      nullif(trim(lt.team_name), ''),
      nullif(trim(lt.short_form), ''),
      ''
    )::text as team_name,
    t.matches,
    t.stat_value,
    t.board_rank
  from top t
  left join lateral (
    select tm.team_name, tm.short_form
    from public.match_player_stats mps
    inner join public.matches m on m.id = mps.match_id
    inner join public.teams tm on tm.id = mps.team_id
    where mps.player_id = t.player_id
      and m.status = 'fullTime'
    order by m.match_date desc nulls last, m.id desc
    limit 1
  ) lt on true
  order by t.board_rank asc;
end;
$$;

grant execute on function public.get_player_stat_rankings(text, text, integer, integer)
  to authenticated;

comment on function public.get_player_stat_rankings(text, text, integer, integer) is
  'App-wide player rankings by one stat. p_period: year | all_time. Rate stats require min samples (year: 8 shots / 3 matches; all-time: 15 shots / 5 matches).';
