-- Per-match player ratings (0.0–10.0) computed from match_player_stats + match score.
-- Called automatically from finalize_match().

-- 1) Compute a single player's rating for a match.
drop function if exists public.compute_match_player_rating(uuid, uuid);

create or replace function public.compute_match_player_rating(
  p_match_id uuid,
  p_player_id uuid
) returns double precision
language sql
stable
security definer
set search_path = public
as $$
with
raw as (
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
    coalesce(mps."xG", 0)::double precision as xg,
    coalesce(mps."xA", 0)::double precision as xa,
    coalesce(mps.yellow_cards, 0) as yellow_cards,
    coalesce(mps.red_cards, 0) as red_cards,
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
    -- Derived from match score (team context).
    case
      when m."teamA" = mps.team_id then coalesce(m."teamB_score", 0)
      when m."teamB" = mps.team_id then coalesce(m."teamA_score", 0)
      else 0
    end as conceded
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
    case when r.conceded = 0 then 1 else 0 end as clean_sheet,
    -- Participation share and minutes factor (dampens low minutes).
    least(1.0, greatest(0.0, r.minutes_played::double precision / 90.0)) as p_share,
    sqrt(least(1.0, greatest(0.0, r.minutes_played::double precision / 90.0))) as mf,
    -- Per-90 (avoid divide-by-zero).
    (90.0 * r.shots::double precision / greatest(1.0, r.minutes_played::double precision)) as shots90,
    (90.0 * r.shots_on_target::double precision / greatest(1.0, r.minutes_played::double precision)) as sot90,
    (90.0 * r.tackles::double precision / greatest(1.0, r.minutes_played::double precision)) as tackles90,
    (90.0 * r.saves::double precision / greatest(1.0, r.minutes_played::double precision)) as saves90
  from raw r
),
components as (
  select
    d.*,
    -- Minutes / involvement: most credit by ~60 mins.
    (0.8 * d.mf * least(1.0, greatest(0.0, d.minutes_played::double precision / 60.0))) as c_minutes,

    -- Discipline penalties (not dampened by minutes).
    (0.6 * d.yellow_cards::double precision) as p_yellow,
    (2.0 * d.red_cards::double precision) as p_red,

    -- Shot pressure component (capped).
    (
      0.10 * least(5.0, greatest(0.0, d.sot90))
      + 0.05 * least(6.0, greatest(0.0, d.shots90 - d.sot90))
    ) as c_pressure,

    -- Attacking (position-aware weights).
    case d.position_key
      when 'ATTACKER' then d.mf * (1.35*d.goals + 0.75*d.assists + 0.35*d.xg + 0.25*d.xa + (
        0.10 * least(5.0, greatest(0.0, d.sot90))
        + 0.05 * least(6.0, greatest(0.0, d.shots90 - d.sot90))
      ))
      when 'MIDFIELDER' then d.mf * (1.10*d.goals + 0.90*d.assists + 0.35*d.xg + 0.35*d.xa + 0.8*(
        0.10 * least(5.0, greatest(0.0, d.sot90))
        + 0.05 * least(6.0, greatest(0.0, d.shots90 - d.sot90))
      ))
      when 'DEFENDER' then d.mf * (1.25*d.goals + 0.65*d.assists + 0.20*d.xg + 0.20*d.xa + 0.5*(
        0.10 * least(5.0, greatest(0.0, d.sot90))
        + 0.05 * least(6.0, greatest(0.0, d.shots90 - d.sot90))
      ))
      when 'GOALKEEPER' then d.mf * (0.30*d.assists + 0.15*d.xa)
      else d.mf * (1.10*d.goals + 0.90*d.assists + 0.35*d.xg + 0.35*d.xa + 0.8*(
        0.10 * least(5.0, greatest(0.0, d.sot90))
        + 0.05 * least(6.0, greatest(0.0, d.shots90 - d.sot90))
      ))
    end as c_attack,

    -- Defensive actions (tackles) for non-GK (capped per-90).
    case d.position_key
      when 'DEFENDER' then d.mf * 0.18 * least(10.0, greatest(0.0, d.tackles90))
      when 'MIDFIELDER' then d.mf * 0.14 * least(10.0, greatest(0.0, d.tackles90))
      when 'ATTACKER' then d.mf * 0.08 * least(8.0, greatest(0.0, d.tackles90))
      else 0.0
    end as c_tackles,

    -- Goalkeeping (saves) (capped per-90).
    case d.position_key
      when 'GOALKEEPER' then d.mf * 0.22 * least(10.0, greatest(0.0, d.saves90))
      else 0.0
    end as c_saves,

    -- Team defensive result (clean sheet bonus gated by minutes).
    case
      when d.minutes_played < 60 then 0.0
      when d.position_key = 'GOALKEEPER' then 0.70 * d.clean_sheet::double precision
      when d.position_key = 'DEFENDER' then 0.55 * d.clean_sheet::double precision
      when d.position_key = 'MIDFIELDER' then 0.20 * d.clean_sheet::double precision
      when d.position_key = 'ATTACKER' then 0.05 * d.clean_sheet::double precision
      else 0.20 * d.clean_sheet::double precision
    end as c_clean_sheet,

    -- Conceded penalty gated by minutes; scaled by mf to soften low minutes.
    case
      when d.minutes_played < 45 then 0.0
      when d.position_key = 'GOALKEEPER' then d.mf * 0.22 * d.conceded::double precision
      when d.position_key = 'DEFENDER' then d.mf * 0.18 * d.conceded::double precision
      when d.position_key = 'MIDFIELDER' then d.mf * 0.08 * d.conceded::double precision
      when d.position_key = 'ATTACKER' then d.mf * 0.04 * d.conceded::double precision
      else d.mf * 0.08 * d.conceded::double precision
    end as p_conceded
  from derived d
),
final as (
  select
    -- Baseline 6.0
    6.0
    + c_minutes
    + c_attack
    + c_tackles
    + c_saves
    + c_clean_sheet
    - (p_yellow + p_red + p_conceded)
    as rating_raw
  from components
)
select
  -- Clamp to [0,10] and round to 1 decimal.
  round(
    least(10.0, greatest(0.0, rating_raw))::numeric,
    1
  )::double precision
from final;
$$;

-- 2) Apply ratings to all players in a match.
drop function if exists public.apply_match_ratings(uuid);

create or replace function public.apply_match_ratings(p_match_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.match_player_stats mps
  set rating = public.compute_match_player_rating(mps.match_id, mps.player_id)
  where mps.match_id = p_match_id;
end $$;

-- 3) Hook into finalize_match so ratings are computed on fullTime.
create or replace function public.finalize_match(p_match_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not exists (
    select 1
    from matches m
    join leagues l on l.id = m.league_id
    where m.id = p_match_id
      and l.created_by = auth.uid()
  ) then
    raise exception 'Only league owner can finalize match';
  end if;

  update matches
  set status = 'fullTime'
  where id = p_match_id
    and status in ('ongoing', 'halfTime');

  -- Compute 0–10 ratings for all players in this match.
  perform public.apply_match_ratings(p_match_id);

  -- gameweek_player_stats: create/update if table exists
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'gameweek_player_stats'
  ) then
    -- Placeholder: aggregate from match_player_stats for the match's gameweek
    null;
  end if;
end $$;

grant execute on function public.compute_match_player_rating(uuid, uuid) to authenticated;
grant execute on function public.apply_match_ratings(uuid) to authenticated;
