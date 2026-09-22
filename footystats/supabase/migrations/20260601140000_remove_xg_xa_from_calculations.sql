-- Stop xG/xA from affecting match ratings and aggregate stats RPCs/views.

create or replace function public.compute_match_player_rating(
  p_match_id uuid,
  p_player_id uuid
) returns double precision
language sql
stable
security definer
set search_path = public
as $$
with raw as (
  select
    mps.match_id,
    mps.player_id,
    mps.team_id,
    coalesce(mps.minutes_played, 0) as minutes_played,
    coalesce(mps.goals, 0) as goals,
    coalesce(mps.assists, 0) as assists,
    coalesce(mps.shots, 0) as shots,
    coalesce(mps.shots_on_target, 0) as shots_on_target,
    coalesce(mps.tackles, 0) as tackles,
    coalesce(mps.saves, 0) as saves,
    coalesce(mps.yellow_cards, 0) as yellow_cards,
    coalesce(mps.red_cards, 0) as red_cards,
    case
      when upper(trim(coalesce(p.position, ''))) in ('GOALKEEPER', 'GK') then 'GOALKEEPER'
      when upper(trim(coalesce(p.position, ''))) like '%GOAL%' then 'GOALKEEPER'
      when upper(trim(coalesce(p.position, ''))) in ('DEFENDER', 'DEF', 'CB', 'LB', 'RB') then 'DEFENDER'
      when upper(trim(coalesce(p.position, ''))) like '%DEF%' then 'DEFENDER'
      when upper(trim(coalesce(p.position, ''))) in ('MIDFIELDER', 'MID', 'CM', 'CDM', 'CAM', 'LM', 'RM') then 'MIDFIELDER'
      when upper(trim(coalesce(p.position, ''))) like '%MID%' then 'MIDFIELDER'
      when upper(trim(coalesce(p.position, ''))) in ('ATTACKER', 'ATT', 'ST', 'FW', 'FORWARD') then 'ATTACKER'
      when upper(trim(coalesce(p.position, ''))) like '%ATT%' then 'ATTACKER'
      when upper(trim(coalesce(p.position, ''))) like '%FWD%' then 'ATTACKER'
      else 'MIDFIELDER'
    end as position_key,
    case
      when m."teamA" = mps.team_id then coalesce(m."teamB_score", 0)
      when m."teamB" = mps.team_id then coalesce(m."teamA_score", 0)
      else 0
    end as goals_conceded
  from public.match_player_stats mps
  inner join public.matches m on m.id = mps.match_id
  inner join public.players p on p.id = mps.player_id
  where mps.match_id = p_match_id
    and mps.player_id = p_player_id
  limit 1
),
derived as (
  select
    r.*,
    (coalesce(r.goals, 0) + coalesce(r.assists, 0) + coalesce(r.shots, 0) + coalesce(r.shots_on_target, 0) + coalesce(r.tackles, 0) + coalesce(r.saves, 0) + coalesce(r.yellow_cards, 0) + coalesce(r.red_cards, 0)) as activity_events,
    case when r.goals_conceded = 0 then 1 else 0 end as clean_sheet,
    least(1.0, greatest(0.0, r.minutes_played::double precision / 90.0)) as p_share,
    sqrt(least(1.0, greatest(0.0, r.minutes_played::double precision / 90.0))) as mf_minutes,
    (90.0 * r.shots::double precision / greatest(1.0, r.minutes_played::double precision)) as shots90,
    (90.0 * r.shots_on_target::double precision / greatest(1.0, r.minutes_played::double precision)) as sot90,
    (90.0 * r.tackles::double precision / greatest(1.0, r.minutes_played::double precision)) as tackles90,
    (90.0 * r.saves::double precision / greatest(1.0, r.minutes_played::double precision)) as saves90
  from raw r
),
components as (
  select
    d.*,
    case
      when d.minutes_played > 0 then d.mf_minutes
      when d.activity_events > 0 then least(0.9, 0.55 + 0.08 * d.activity_events::double precision)
      else 0.0
    end as impact_factor,
    (0.8 * d.mf_minutes * least(1.0, greatest(0.0, d.minutes_played::double precision / 60.0))) as c_minutes,
    (0.6 * d.yellow_cards::double precision) as p_yellow,
    (2.0 * d.red_cards::double precision) as p_red,
    (
      0.14 * least(5.0, greatest(0.0, d.sot90))
      + 0.05 * least(6.0, greatest(0.0, d.shots90 - d.sot90))
    ) as c_pressure
  from derived d
),
scored as (
  select
    c.*,
    case c.position_key
      when 'ATTACKER' then c.impact_factor * (1.35*c.goals + 0.75*c.assists + c.c_pressure)
      when 'MIDFIELDER' then c.impact_factor * (1.10*c.goals + 0.90*c.assists + 0.8*c.c_pressure)
      when 'DEFENDER' then c.impact_factor * (1.25*c.goals + 0.65*c.assists + 0.5*c.c_pressure)
      when 'GOALKEEPER' then c.impact_factor * (0.30*c.assists + 0.30*c.saves)
      else c.impact_factor * (1.10*c.goals + 0.90*c.assists + 0.8*c.c_pressure)
    end as c_attack,
    case c.position_key
      when 'DEFENDER' then c.impact_factor * 0.18 * least(10.0, greatest(0.0, c.tackles90))
      when 'MIDFIELDER' then c.impact_factor * 0.14 * least(10.0, greatest(0.0, c.tackles90))
      when 'ATTACKER' then c.impact_factor * 0.08 * least(8.0, greatest(0.0, c.tackles90))
      else 0.0
    end as c_tackles,
    case c.position_key
      when 'GOALKEEPER' then c.impact_factor * 0.22 * least(10.0, greatest(0.0, c.saves90))
      else 0.0
    end as c_saves,
    case
      when c.minutes_played < 60 then 0.0
      when c.position_key = 'GOALKEEPER' then 0.70 * c.clean_sheet::double precision
      when c.position_key = 'DEFENDER' then 0.55 * c.clean_sheet::double precision
      when c.position_key = 'MIDFIELDER' then 0.20 * c.clean_sheet::double precision
      when c.position_key = 'ATTACKER' then 0.05 * c.clean_sheet::double precision
      else 0.20 * c.clean_sheet::double precision
    end as c_clean_sheet
  from components c
),
final as (
  select
    6.0
    + c_minutes
    + c_attack
    + c_tackles
    + c_saves
    + c_clean_sheet
    - (p_yellow + p_red)
    - case
        when minutes_played <= 0 then 0.0
        else
          p_share
          * goals_conceded::double precision
          * (
            case position_key
              when 'GOALKEEPER' then 0.58 + 0.28 * impact_factor
              when 'DEFENDER' then 0.42 + 0.22 * impact_factor
              when 'MIDFIELDER' then 0.13 + 0.07 * impact_factor
              when 'ATTACKER' then 0.05 + 0.03 * impact_factor
              else 0.13 + 0.07 * impact_factor
            end
          )
      end
    as rating_raw
  from scored
)
select round(least(10.0, greatest(0.0, rating_raw))::numeric, 1)::double precision
from final;
$$;

-- Profile year stats: keep xg/xa columns for API compatibility but always return zero.
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
  0.0::double precision as xg,
  0.0::double precision as xa,
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
  0.0::double precision as xg,
  0.0::double precision as xa,
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
  0.0::double precision as xg,
  0.0::double precision as xa,
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

drop function if exists public.get_team_summary_stats_filtered(uuid, uuid, uuid);

create or replace function public.get_team_summary_stats_filtered(
  p_team_id uuid,
  p_league_id uuid default null,
  p_season_id uuid default null
)
returns table (
  matches_played      bigint,
  goals_scored        bigint,
  goals_conceded      bigint,
  goal_difference     bigint,
  assists             bigint,
  clean_sheets        bigint,
  shots_on_target     bigint,
  tackles             bigint,
  saves               bigint,
  yellow_cards        bigint,
  red_cards           bigint,
  total_xg            double precision,
  total_xa            double precision
)
language sql
security definer
set search_path = public
as $$
  with team_matches as (
    select
      m.id as match_id,
      m."teamA_score" as gf,
      m."teamB_score" as ga
    from matches m
    where m."teamA" = p_team_id
      and m.status = 'fullTime'
      and m."teamA_score" is not null
      and m."teamB_score" is not null
      and (p_league_id is null or m.league_id = p_league_id)
      and (p_season_id is null or m.season_id = p_season_id)

    union all

    select
      m.id as match_id,
      m."teamB_score" as gf,
      m."teamA_score" as ga
    from matches m
    where m."teamB" = p_team_id
      and m.status = 'fullTime'
      and m."teamA_score" is not null
      and m."teamB_score" is not null
      and (p_league_id is null or m.league_id = p_league_id)
      and (p_season_id is null or m.season_id = p_season_id)
  ),
  match_agg as (
    select
      count(*) as matches_played,
      coalesce(sum(gf), 0) as goals_scored,
      coalesce(sum(ga), 0) as goals_conceded,
      coalesce(sum(gf - ga), 0) as goal_difference,
      count(*) filter (where ga = 0) as clean_sheets
    from team_matches
  ),
  finished_match_ids as (
    select match_id from team_matches
  ),
  player_agg as (
    select
      coalesce(sum(mps.assists), 0) as assists
    from match_player_stats mps
    where mps.match_id in (select match_id from finished_match_ids)
      and mps.team_id = p_team_id
  ),
  event_agg as (
    select
      count(*) filter (where me.event_type = 'tackle' and not me.is_deleted) as tackles,
      count(*) filter (where me.event_type = 'save' and not me.is_deleted) as saves,
      count(*) filter (where me.event_type = 'yellow_card' and not me.is_deleted) as yellow_cards,
      count(*) filter (where me.event_type = 'red_card' and not me.is_deleted) as red_cards,
      count(distinct me.id) filter (
        where not me.is_deleted and (
          (me.event_type in ('goal', 'penalty_goal') and me.team_id = p_team_id)
          or (me.event_type = 'save' and me.team_id != p_team_id)
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
    0.0::double precision as total_xg,
    0.0::double precision as total_xa
  from match_agg ma
  left join player_agg pa on true
  left join event_agg ea on true;
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
      0.0::double precision                                     as total_xg,
      0.0::double precision                                     as total_xa,
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
    mps.rating
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
  0.0::double precision as expected_goals,
  0.0::double precision as expected_assists,
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

-- Recompute stored ratings without xG/xA contribution.
do $reco$
declare
  r record;
begin
  for r in
    select id from public.matches where status = 'fullTime'
  loop
    perform public.apply_match_ratings(r.id);
  end loop;
end
$reco$;
