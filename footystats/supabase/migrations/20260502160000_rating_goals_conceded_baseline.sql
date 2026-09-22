-- Stronger goals-conceded impact on per-match ratings (especially GK/DEF).
-- On-pitch players (minutes_played > 0): penalty scales with minutes share (p_share),
-- so the effective baseline (neutral 6.0) is pulled down when the team concedes.
-- Bench (0 minutes, no proportional share): no conceded penalty.
-- Recomputes match_player_stats.rating for all fullTime matches (aggregates/views read this column).

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
    coalesce(mps."xG", 0)::double precision as xg,
    coalesce(mps."xA", 0)::double precision as xa,
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
    (coalesce(r.goals, 0) + coalesce(r.assists, 0) + coalesce(r.shots, 0) + coalesce(r.shots_on_target, 0) + coalesce(r.tackles, 0) + coalesce(r.saves, 0) + coalesce(r.yellow_cards, 0) + coalesce(r.red_cards, 0)) as activity_events,
    case when r.conceded = 0 then 1 else 0 end as clean_sheet,
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
      when 'ATTACKER' then c.impact_factor * (1.35*c.goals + 0.75*c.assists + 0.35*c.xg + 0.25*c.xa + c.c_pressure)
      when 'MIDFIELDER' then c.impact_factor * (1.10*c.goals + 0.90*c.assists + 0.35*c.xg + 0.35*c.xa + 0.8*c.c_pressure)
      when 'DEFENDER' then c.impact_factor * (1.25*c.goals + 0.65*c.assists + 0.20*c.xg + 0.20*c.xa + 0.5*c.c_pressure)
      when 'GOALKEEPER' then c.impact_factor * (0.30*c.assists + 0.15*c.xa + 0.30*c.saves)
      else c.impact_factor * (1.10*c.goals + 0.90*c.assists + 0.35*c.xg + 0.35*c.xa + 0.8*c.c_pressure)
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
    -- Goals conceded: hurts everyone on the pitch proportional to time played; GK/DEF most.
    -- Pulls down the neutral baseline before stat bonuses (bench: p_share = 0 → no hit).
    - case
        when minutes_played <= 0 then 0.0
        else
          p_share
          * conceded::double precision
          * (
            case position_key
              when 'GOALKEEPER' then 0.58
              when 'DEFENDER' then 0.42
              when 'MIDFIELDER' then 0.13
              when 'ATTACKER' then 0.05
              else 0.13
            end
          )
      end
    -- Extra defensive responsibility: scales with involvement so quiet games still pay for goals.
    - case
        when minutes_played <= 0 then 0.0
        else
          impact_factor
          * p_share
          * conceded::double precision
          * (
            case position_key
              when 'GOALKEEPER' then 0.28
              when 'DEFENDER' then 0.22
              when 'MIDFIELDER' then 0.07
              when 'ATTACKER' then 0.03
              else 0.07
            end
          )
      end
    as rating_raw
  from scored
)
select round(least(10.0, greatest(0.0, rating_raw))::numeric, 1)::double precision
from final;
$$;

-- Batch recompute of match_player_stats.rating: see 20260502170000_rating_conceded_per_goal_explicit.sql
