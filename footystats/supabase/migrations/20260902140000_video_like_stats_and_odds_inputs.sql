-- Aggregated like counts for a page of videos (avoids downloading every like row).
create or replace function public.get_video_like_stats(
  p_video_ids uuid[],
  p_user_id uuid default null
)
returns table (
  video_id uuid,
  like_count integer,
  is_liked boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    v.vid as video_id,
    coalesce(c.cnt, 0)::integer as like_count,
    coalesce(l.liked, false) as is_liked
  from unnest(coalesce(p_video_ids, array[]::uuid[])) as v(vid)
  left join (
    select vl.video_id, count(*)::integer as cnt
    from public.video_likes vl
    where vl.video_id = any(p_video_ids)
    group by vl.video_id
  ) c on c.video_id = v.vid
  left join (
    select vl.video_id, true as liked
    from public.video_likes vl
    where p_user_id is not null
      and vl.user_id = p_user_id
      and vl.video_id = any(p_video_ids)
  ) l on l.video_id = v.vid;
$$;

grant execute on function public.get_video_like_stats(uuid[], uuid) to anon, authenticated;

comment on function public.get_video_like_stats(uuid[], uuid) is
  'Per-video like totals and whether p_user_id liked each clip. One row per requested id.';

-- Batch match-odds inputs for many fixtures in one round trip.
-- Mirrors the client MatchOddsCalculator factor set (form, H2H, squad, GD, PPG).
create or replace function public.get_match_odds_inputs(p_match_ids uuid[])
returns table (
  match_id uuid,
  team_a_form jsonb,
  team_b_form jsonb,
  h2h_a_wins integer,
  h2h_draws integer,
  h2h_b_wins integer,
  team_a_squad_rating double precision,
  team_b_squad_rating double precision,
  team_a_gd_per_game double precision,
  team_b_gd_per_game double precision,
  team_a_ppg double precision,
  team_b_ppg double precision
)
language sql
stable
security definer
set search_path = public
as $$
with requested as (
  select
    m.id as match_id,
    m."teamA" as team_a,
    m."teamB" as team_b,
    m.league_id,
    m.season_id,
    m.match_date,
    coalesce(m.match_time, '23:59:59'::time) as match_time
  from public.matches m
  where m.id = any(coalesce(p_match_ids, array[]::uuid[]))
),
finished as (
  select
    m.id,
    m."teamA" as team_a,
    m."teamB" as team_b,
    m."teamA_score"::int as score_a,
    m."teamB_score"::int as score_b,
    m.match_date,
    coalesce(m.match_time, '23:59:59'::time) as match_time,
    m.league_id,
    m.season_id
  from public.matches m
  where m.status = 'fullTime'
    and m."teamA_score" is not null
    and m."teamB_score" is not null
),
form_rows as (
  select
    r.match_id,
    side.which,
    jsonb_build_object(
      'is_win', case
        when f.team_a = side.team_id then f.score_a > f.score_b
        else f.score_b > f.score_a
      end,
      'is_draw', f.score_a = f.score_b,
      'goals_for', case
        when f.team_a = side.team_id then f.score_a
        else f.score_b
      end,
      'goals_against', case
        when f.team_a = side.team_id then f.score_b
        else f.score_a
      end
    ) as snap,
    row_number() over (
      partition by r.match_id, side.which
      order by f.match_date desc, f.match_time desc
    ) as rn
  from requested r
  cross join lateral (
    values
      ('a', r.team_a),
      ('b', r.team_b)
  ) as side(which, team_id)
  join finished f
    on (f.team_a = side.team_id or f.team_b = side.team_id)
   and f.id <> r.match_id
   and (
     f.match_date < r.match_date
     or (f.match_date = r.match_date and f.match_time < r.match_time)
   )
),
form as (
  select
    match_id,
    jsonb_agg(snap order by rn) filter (where which = 'a' and rn <= 5) as team_a_form,
    jsonb_agg(snap order by rn) filter (where which = 'b' and rn <= 5) as team_b_form
  from form_rows
  group by match_id
),
h2h as (
  select
    r.match_id,
    count(*) filter (
      where (f.team_a = r.team_a and f.score_a > f.score_b)
         or (f.team_b = r.team_a and f.score_b > f.score_a)
    )::integer as h2h_a_wins,
    count(*) filter (where f.score_a = f.score_b)::integer as h2h_draws,
    count(*) filter (
      where (f.team_a = r.team_b and f.score_a > f.score_b)
         or (f.team_b = r.team_b and f.score_b > f.score_a)
    )::integer as h2h_b_wins
  from requested r
  join finished f
    on (
      (f.team_a = r.team_a and f.team_b = r.team_b)
      or (f.team_a = r.team_b and f.team_b = r.team_a)
    )
   and f.id <> r.match_id
   and f.match_date <= r.match_date
  group by r.match_id
),
recent_ids as (
  select match_id, which, team_id, id as recent_match_id
  from (
    select
      r.match_id,
      side.which,
      side.team_id,
      f.id,
      row_number() over (
        partition by r.match_id, side.which
        order by f.match_date desc, f.match_time desc
      ) as rn
    from requested r
    cross join lateral (
      values
        ('a', r.team_a),
        ('b', r.team_b)
    ) as side(which, team_id)
    join finished f
      on (f.team_a = side.team_id or f.team_b = side.team_id)
     and f.id <> r.match_id
  ) x
  where rn <= 5
),
squad as (
  select
    r.match_id,
    avg(mps.rating) filter (where ri.which = 'a' and mps.rating > 0) as team_a_squad_rating,
    avg(mps.rating) filter (where ri.which = 'b' and mps.rating > 0) as team_b_squad_rating
  from requested r
  left join recent_ids ri on ri.match_id = r.match_id
  left join public.match_player_stats mps
    on mps.match_id = ri.recent_match_id
   and mps.team_id = ri.team_id
  group by r.match_id
),
season_gd as (
  select
    r.match_id,
    case
      when count(*) filter (where f.team_a = r.team_a or f.team_b = r.team_a) > 0
      then (
        sum(
          case
            when f.team_a = r.team_a then f.score_a - f.score_b
            when f.team_b = r.team_a then f.score_b - f.score_a
            else 0
          end
        )::double precision
        / count(*) filter (where f.team_a = r.team_a or f.team_b = r.team_a)
      )
      else 0
    end as team_a_gd_per_game,
    case
      when count(*) filter (where f.team_a = r.team_b or f.team_b = r.team_b) > 0
      then (
        sum(
          case
            when f.team_a = r.team_b then f.score_a - f.score_b
            when f.team_b = r.team_b then f.score_b - f.score_a
            else 0
          end
        )::double precision
        / count(*) filter (where f.team_a = r.team_b or f.team_b = r.team_b)
      )
      else 0
    end as team_b_gd_per_game
  from requested r
  left join finished f
    on f.league_id is not distinct from r.league_id
   and f.season_id is not distinct from r.season_id
   and f.id <> r.match_id
  group by r.match_id
),
season_ppg as (
  select
    r.match_id,
    case
      when count(*) filter (where f.team_a = r.team_a or f.team_b = r.team_a) > 0
      then (
        sum(
          case
            when f.team_a = r.team_a and f.score_a > f.score_b then 3
            when f.team_b = r.team_a and f.score_b > f.score_a then 3
            when (f.team_a = r.team_a or f.team_b = r.team_a) and f.score_a = f.score_b then 1
            else 0
          end
        )::double precision
        / count(*) filter (where f.team_a = r.team_a or f.team_b = r.team_a)
      )
      else null
    end as team_a_ppg,
    case
      when count(*) filter (where f.team_a = r.team_b or f.team_b = r.team_b) > 0
      then (
        sum(
          case
            when f.team_a = r.team_b and f.score_a > f.score_b then 3
            when f.team_b = r.team_b and f.score_b > f.score_a then 3
            when (f.team_a = r.team_b or f.team_b = r.team_b) and f.score_a = f.score_b then 1
            else 0
          end
        )::double precision
        / count(*) filter (where f.team_a = r.team_b or f.team_b = r.team_b)
      )
      else null
    end as team_b_ppg
  from requested r
  left join finished f
    on f.league_id is not distinct from r.league_id
   and f.season_id is not distinct from r.season_id
   and f.id <> r.match_id
  group by r.match_id
)
select
  r.match_id,
  coalesce(f.team_a_form, '[]'::jsonb) as team_a_form,
  coalesce(f.team_b_form, '[]'::jsonb) as team_b_form,
  coalesce(h.h2h_a_wins, 0) as h2h_a_wins,
  coalesce(h.h2h_draws, 0) as h2h_draws,
  coalesce(h.h2h_b_wins, 0) as h2h_b_wins,
  coalesce(s.team_a_squad_rating, 0) as team_a_squad_rating,
  coalesce(s.team_b_squad_rating, 0) as team_b_squad_rating,
  coalesce(g.team_a_gd_per_game, 0) as team_a_gd_per_game,
  coalesce(g.team_b_gd_per_game, 0) as team_b_gd_per_game,
  p.team_a_ppg,
  p.team_b_ppg
from requested r
left join form f on f.match_id = r.match_id
left join h2h h on h.match_id = r.match_id
left join squad s on s.match_id = r.match_id
left join season_gd g on g.match_id = r.match_id
left join season_ppg p on p.match_id = r.match_id;
$$;

grant execute on function public.get_match_odds_inputs(uuid[]) to anon, authenticated;

comment on function public.get_match_odds_inputs(uuid[]) is
  'Batch form / H2H / squad / season signals used to compute pre-match odds for many fixtures.';
