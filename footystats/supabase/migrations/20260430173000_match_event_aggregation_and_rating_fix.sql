-- Fix match stat aggregation and rating impact so event contributions are reflected reliably.

-- Recompute match_player_stats and match_team_stats directly from match_events.
drop function if exists public.recompute_match_stats_from_events(uuid);

create or replace function public.recompute_match_stats_from_events(p_match_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_team_a uuid;
  v_team_b uuid;
begin
  select m."teamA", m."teamB"
  into v_team_a, v_team_b
  from public.matches m
  where m.id = p_match_id;

  if v_team_a is null or v_team_b is null then
    raise exception 'Match not found or missing teams';
  end if;

  perform public._ensure_match_team_stats(p_match_id, v_team_a);
  perform public._ensure_match_team_stats(p_match_id, v_team_b);

  update public.match_player_stats
  set
    goals = 0,
    assists = 0,
    shots = 0,
    shots_on_target = 0,
    tackles = 0,
    saves = 0,
    yellow_cards = 0,
    red_cards = 0
  where match_id = p_match_id;

  update public.match_team_stats
  set
    goals = 0,
    assists = 0,
    shots = 0,
    shots_on_target = 0,
    tackles = 0,
    saves = 0,
    yellow_cards = 0,
    red_cards = 0
  where match_id = p_match_id;

  -- Ensure every player referenced by active events has a stats row.
  insert into public.match_player_stats (match_id, player_id, team_id)
  select distinct
    e.match_id,
    e.player_id,
    e.team_id
  from public.match_events e
  where e.match_id = p_match_id
    and e.is_deleted = false
    and e.player_id is not null
  on conflict (match_id, player_id) do nothing;

  insert into public.match_player_stats (match_id, player_id, team_id)
  select distinct
    e.match_id,
    e.secondary_player_id,
    e.team_id
  from public.match_events e
  where e.match_id = p_match_id
    and e.is_deleted = false
    and e.event_type in ('goal', 'penalty_goal')
    and e.secondary_player_id is not null
  on conflict (match_id, player_id) do nothing;

  -- Player aggregation.
  with shot_events as (
    select
      e.id,
      e.match_id,
      e.team_id,
      e.player_id,
      e.event_minute,
      e.event_second,
      e.created_at
    from public.match_events e
    where e.match_id = p_match_id
      and e.is_deleted = false
      and e.event_type = 'shot'
      and e.player_id is not null
  ),
  resolved_shot_outcomes as (
    select
      s.match_id,
      s.team_id,
      s.player_id,
      (
        s.secondary_player_id is not null
        or exists (
          select 1
          from public.match_events sv
          where sv.match_id = s.match_id
            and sv.is_deleted = false
            and sv.event_type = 'save'
            and sv.secondary_player_id = s.player_id
            and sv.team_id <> s.team_id
            and coalesce(sv.event_minute, -1) = coalesce(s.event_minute, -1)
            and coalesce(sv.event_second, -1) = coalesce(s.event_second, -1)
            and sv.created_at >= s.created_at - interval '10 seconds'
            and sv.created_at <= s.created_at + interval '10 seconds'
        )
      ) as is_on_target
    from public.match_events s
    where s.match_id = p_match_id
      and s.is_deleted = false
      and s.event_type = 'shot'
      and s.player_id is not null
  ),
  player_rollup as (
    select
      x.match_id,
      x.player_id,
      (array_agg(x.team_id))[1] as team_id,
      sum(x.goals)::smallint as goals,
      sum(x.assists)::smallint as assists,
      sum(x.shots)::smallint as shots,
      sum(x.shots_on_target)::smallint as shots_on_target,
      sum(x.tackles)::smallint as tackles,
      sum(x.saves)::smallint as saves,
      sum(x.yellow_cards)::smallint as yellow_cards,
      sum(x.red_cards)::smallint as red_cards
    from (
      -- Goals also count as shots and shots on target.
      select
        e.match_id,
        e.player_id,
        e.team_id,
        1 as goals,
        0 as assists,
        1 as shots,
        1 as shots_on_target,
        0 as tackles,
        0 as saves,
        0 as yellow_cards,
        0 as red_cards
      from public.match_events e
      where e.match_id = p_match_id
        and e.is_deleted = false
        and e.event_type in ('goal', 'penalty_goal')
        and e.player_id is not null

      union all

      -- Goal assists.
      select
        e.match_id,
        e.secondary_player_id as player_id,
        e.team_id,
        0, 1, 0, 0, 0, 0, 0, 0
      from public.match_events e
      where e.match_id = p_match_id
        and e.is_deleted = false
        and e.event_type in ('goal', 'penalty_goal')
        and e.secondary_player_id is not null

      union all

      -- Generic shot events are always shots; saved shots become on-target.
      select
        r.match_id,
        r.player_id,
        r.team_id,
        0,
        0,
        1,
        case when r.is_on_target then 1 else 0 end,
        0,
        0,
        0,
        0
      from resolved_shot_outcomes r

      union all

      select
        e.match_id,
        e.player_id,
        e.team_id,
        0, 0, 0, 0, 1, 0, 0, 0
      from public.match_events e
      where e.match_id = p_match_id
        and e.is_deleted = false
        and e.event_type = 'tackle'
        and e.player_id is not null

      union all

      select
        e.match_id,
        e.player_id,
        e.team_id,
        0, 0, 0, 0, 0, 1, 0, 0
      from public.match_events e
      where e.match_id = p_match_id
        and e.is_deleted = false
        and e.event_type = 'save'
        and e.player_id is not null

      union all

      select
        e.match_id,
        e.player_id,
        e.team_id,
        0, 0, 0, 0, 0, 0, 1, 0
      from public.match_events e
      where e.match_id = p_match_id
        and e.is_deleted = false
        and e.event_type = 'yellow_card'
        and e.player_id is not null

      union all

      select
        e.match_id,
        e.player_id,
        e.team_id,
        0, 0, 0, 0, 0, 0, 0, 1
      from public.match_events e
      where e.match_id = p_match_id
        and e.is_deleted = false
        and e.event_type = 'red_card'
        and e.player_id is not null
    ) x
    group by x.match_id, x.player_id
  )
  update public.match_player_stats mps
  set
    team_id = pr.team_id,
    goals = pr.goals,
    assists = pr.assists,
    shots = pr.shots,
    shots_on_target = pr.shots_on_target,
    tackles = pr.tackles,
    saves = pr.saves,
    yellow_cards = pr.yellow_cards,
    red_cards = pr.red_cards
  from player_rollup pr
  where mps.match_id = pr.match_id
    and mps.player_id = pr.player_id;

  -- Team aggregation from player rows keeps totals coherent.
  with team_rollup as (
    select
      mps.match_id,
      mps.team_id,
      coalesce(sum(mps.goals), 0)::smallint as goals,
      coalesce(sum(mps.assists), 0)::smallint as assists,
      coalesce(sum(mps.shots), 0)::smallint as shots,
      coalesce(sum(mps.shots_on_target), 0)::smallint as shots_on_target,
      coalesce(sum(mps.tackles), 0)::smallint as tackles,
      coalesce(sum(mps.saves), 0)::smallint as saves,
      coalesce(sum(mps.yellow_cards), 0)::smallint as yellow_cards,
      coalesce(sum(mps.red_cards), 0)::smallint as red_cards
    from public.match_player_stats mps
    where mps.match_id = p_match_id
    group by mps.match_id, mps.team_id
  )
  update public.match_team_stats mts
  set
    goals = tr.goals,
    assists = tr.assists,
    shots = tr.shots,
    shots_on_target = tr.shots_on_target,
    tackles = tr.tackles,
    saves = tr.saves,
    yellow_cards = tr.yellow_cards,
    red_cards = tr.red_cards
  from team_rollup tr
  where mts.match_id = tr.match_id
    and mts.team_id = tr.team_id;
end $$;

grant execute on function public.recompute_match_stats_from_events(uuid) to authenticated;


-- Record a generic match event and keep aggregations consistent.
drop function if exists public.record_match_event(uuid, text, uuid, uuid, smallint, smallint);
drop function if exists public.record_match_event(uuid, text, uuid, uuid, smallint, smallint, uuid);

create or replace function public.record_match_event(
  p_match_id uuid,
  p_event_type text,
  p_team_id uuid,
  p_player_id uuid default null,
  p_minute smallint default null,
  p_second smallint default 0,
  p_secondary_player_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status text;
  v_event_id uuid;
  v_linked_shooter_id uuid;
begin
  if p_event_type not in ('shot', 'corner', 'tackle', 'save', 'substitution', 'assist') then
    raise exception 'Invalid event type: %', p_event_type;
  end if;

  if not (
    exists (
      select 1
      from public.matches m
      join public.leagues l on l.id = m.league_id
      where m.id = p_match_id
        and l.created_by = auth.uid()
    )
    or exists (
      select 1
      from public.matches m
      join public.player_team_memberships ptm on ptm.team_id in (m."teamA", m."teamB")
      where m.id = p_match_id
        and ptm.player_id = auth.uid()
        and ptm.end_date is null
    )
  ) then
    raise exception 'Not authorized';
  end if;

  select status into v_status from public.matches where id = p_match_id;
  if v_status is null or v_status not in ('ongoing', 'live', 'halfTime') then
    raise exception 'Match not found or not ongoing';
  end if;

  if p_event_type = 'substitution' then
    if p_player_id is null or p_secondary_player_id is null then
      raise exception 'Substitution requires both players (on and off)';
    end if;
    if p_player_id = p_secondary_player_id then
      raise exception 'Substitution must involve two different players';
    end if;
  end if;

  -- For save events, try to link the save to the shooter (secondary_player_id)
  -- so the shot can be counted as on-target.
  if p_event_type = 'save' then
    v_linked_shooter_id := p_secondary_player_id;

    if v_linked_shooter_id is null then
      select e.player_id
      into v_linked_shooter_id
      from public.match_events e
      where e.match_id = p_match_id
        and e.is_deleted = false
        and e.event_type = 'shot'
        and e.team_id <> p_team_id
        and e.player_id is not null
        and e.secondary_player_id is null
        and coalesce(e.event_minute, -1) = coalesce(p_minute, 0)
        and coalesce(e.event_second, -1) = p_second
      order by e.created_at desc
      limit 1;
    end if;

    if v_linked_shooter_id is not null then
      -- Back-fill the latest unresolved shot to keep relationships explicit.
      update public.match_events e
      set secondary_player_id = v_linked_shooter_id
      where e.id = (
        select s.id
        from public.match_events s
        where s.match_id = p_match_id
          and s.is_deleted = false
          and s.event_type = 'shot'
          and s.team_id <> p_team_id
          and s.player_id = v_linked_shooter_id
          and s.secondary_player_id is null
          and coalesce(s.event_minute, -1) = coalesce(p_minute, 0)
          and coalesce(s.event_second, -1) = p_second
        order by s.created_at desc
        limit 1
      );
    end if;
  end if;

  insert into public.match_events (
    match_id,
    event_type,
    event_minute,
    event_second,
    team_id,
    player_id,
    secondary_player_id
  )
  values (
    p_match_id,
    p_event_type,
    coalesce(p_minute, 0),
    p_second,
    p_team_id,
    p_player_id,
    case
      when p_event_type = 'substitution' then p_secondary_player_id
      when p_event_type = 'save' then v_linked_shooter_id
      else null
    end
  )
  returning id into v_event_id;

  if p_event_type = 'substitution' then
    perform public._ensure_match_player_stats(p_match_id, p_player_id, p_team_id);
    perform public._ensure_match_player_stats(p_match_id, p_secondary_player_id, p_team_id);
  elsif p_player_id is not null then
    perform public._ensure_match_player_stats(p_match_id, p_player_id, p_team_id);
  end if;

  perform public._ensure_match_team_stats(p_match_id, p_team_id);
  perform public.recompute_match_stats_from_events(p_match_id);

  return jsonb_build_object('event_id', v_event_id);
end $$;

grant execute on function public.record_match_event(uuid, text, uuid, uuid, smallint, smallint, uuid) to authenticated;


-- Keep goal recording consistent with shot aggregation and ratings.
create or replace function public.record_match_goal(
  p_match_id uuid,
  p_player_id uuid,
  p_minute smallint,
  p_second smallint default 0,
  p_assist_player_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_team_id uuid;
  v_team_a uuid;
  v_team_b uuid;
  v_status text;
  v_is_team_a boolean;
  v_new_a int;
  v_new_b int;
  v_event_id uuid;
begin
  if not (
    exists (select 1 from public.matches m join public.leagues l on l.id = m.league_id where m.id = p_match_id and l.created_by = auth.uid())
    or exists (select 1 from public.matches m join public.player_team_memberships ptm on ptm.team_id in (m."teamA", m."teamB")
      where m.id = p_match_id and ptm.player_id = auth.uid() and ptm.end_date is null)
  ) then
    raise exception 'Not authorized to record goal for this match';
  end if;

  select status, "teamA", "teamB" into v_status, v_team_a, v_team_b from public.matches where id = p_match_id;
  if v_status is null then
    raise exception 'Match not found';
  end if;
  if v_status not in ('ongoing', 'live', 'halfTime') then
    raise exception 'Match is not ongoing (status: %)', v_status;
  end if;

  v_team_id := public._resolve_player_team_for_match(p_match_id, p_player_id);
  if v_team_id is null then
    raise exception 'Player % is not in either team for this match', p_player_id;
  end if;

  v_is_team_a := (v_team_id = v_team_a);

  perform public._ensure_match_player_stats(p_match_id, p_player_id, v_team_id);
  if p_assist_player_id is not null then
    perform public._ensure_match_player_stats(p_match_id, p_assist_player_id, v_team_id);
  end if;
  perform public._ensure_match_team_stats(p_match_id, v_team_a);
  perform public._ensure_match_team_stats(p_match_id, v_team_b);

  insert into public.match_events (match_id, event_type, event_minute, event_second, team_id, player_id, secondary_player_id)
  values (p_match_id, 'goal', p_minute, p_second, v_team_id, p_player_id, p_assist_player_id)
  returning id into v_event_id;

  if v_is_team_a then
    update public.matches
    set "teamA_score" = coalesce("teamA_score", 0) + 1
    where id = p_match_id;
  else
    update public.matches
    set "teamB_score" = coalesce("teamB_score", 0) + 1
    where id = p_match_id;
  end if;

  select coalesce("teamA_score", 0)::int, coalesce("teamB_score", 0)::int
  into v_new_a, v_new_b
  from public.matches
  where id = p_match_id;

  perform public.recompute_match_stats_from_events(p_match_id);

  return jsonb_build_object(
    'teamA_score', v_new_a,
    'teamB_score', v_new_b,
    'event_id', v_event_id,
    'team_id', v_team_id,
    'is_team_a', v_is_team_a
  );
end $$;


create or replace function public.record_match_card(
  p_match_id uuid,
  p_player_id uuid,
  p_card_type text,
  p_minute smallint,
  p_second smallint default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_team_id uuid;
  v_status text;
  v_event_id uuid;
begin
  if p_card_type not in ('yellow_card', 'red_card') then
    raise exception 'Invalid card type: %', p_card_type;
  end if;

  if not (
    exists (select 1 from public.matches m join public.leagues l on l.id = m.league_id where m.id = p_match_id and l.created_by = auth.uid())
    or exists (select 1 from public.matches m join public.player_team_memberships ptm on ptm.team_id in (m."teamA", m."teamB")
      where m.id = p_match_id and ptm.player_id = auth.uid() and ptm.end_date is null)
  ) then
    raise exception 'Not authorized to record card for this match';
  end if;

  select status into v_status from public.matches where id = p_match_id;
  if v_status is null or v_status not in ('ongoing', 'live', 'halfTime') then
    raise exception 'Match not found or not ongoing';
  end if;

  v_team_id := public._resolve_player_team_for_match(p_match_id, p_player_id);
  if v_team_id is null then
    raise exception 'Player not in either team for this match';
  end if;

  perform public._ensure_match_player_stats(p_match_id, p_player_id, v_team_id);
  perform public._ensure_match_team_stats(p_match_id, (select "teamA" from public.matches where id = p_match_id));
  perform public._ensure_match_team_stats(p_match_id, (select "teamB" from public.matches where id = p_match_id));

  insert into public.match_events (match_id, event_type, event_minute, event_second, team_id, player_id)
  values (p_match_id, p_card_type, p_minute, p_second, v_team_id, p_player_id)
  returning id into v_event_id;

  perform public.recompute_match_stats_from_events(p_match_id);

  return jsonb_build_object('event_id', v_event_id, 'team_id', v_team_id);
end $$;


create or replace function public.void_match_event(p_event_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_evt record;
  v_team_a uuid;
begin
  select match_id, event_type, team_id, is_deleted
  into v_evt
  from public.match_events
  where id = p_event_id;

  if v_evt is null or v_evt.is_deleted then
    raise exception 'Event not found or already voided';
  end if;

  if not (
    exists (select 1 from public.matches m join public.leagues l on l.id = m.league_id where m.id = v_evt.match_id and l.created_by = auth.uid())
    or exists (select 1 from public.matches m join public.player_team_memberships ptm on ptm.team_id in (m."teamA", m."teamB")
      where m.id = v_evt.match_id and ptm.player_id = auth.uid() and ptm.end_date is null)
  ) then
    raise exception 'Not authorized to void this event';
  end if;

  if v_evt.event_type in ('goal', 'penalty_goal') then
    select "teamA" into v_team_a from public.matches where id = v_evt.match_id;
    if v_evt.team_id = v_team_a then
      update public.matches
      set "teamA_score" = greatest(0, coalesce("teamA_score", 0) - 1)
      where id = v_evt.match_id;
    else
      update public.matches
      set "teamB_score" = greatest(0, coalesce("teamB_score", 0) - 1)
      where id = v_evt.match_id;
    end if;
  end if;

  update public.match_events
  set is_deleted = true
  where id = p_event_id;

  perform public.recompute_match_stats_from_events(v_evt.match_id);
end $$;


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
    end as c_clean_sheet,
    case
      when c.minutes_played < 45 then 0.0
      when c.position_key = 'GOALKEEPER' then c.impact_factor * 0.22 * c.conceded::double precision
      when c.position_key = 'DEFENDER' then c.impact_factor * 0.18 * c.conceded::double precision
      when c.position_key = 'MIDFIELDER' then c.impact_factor * 0.08 * c.conceded::double precision
      when c.position_key = 'ATTACKER' then c.impact_factor * 0.04 * c.conceded::double precision
      else c.impact_factor * 0.08 * c.conceded::double precision
    end as p_conceded
  from components c
),
final as (
  select
    6.0 + c_minutes + c_attack + c_tackles + c_saves + c_clean_sheet - (p_yellow + p_red + p_conceded) as rating_raw
  from scored
)
select round(least(10.0, greatest(0.0, rating_raw))::numeric, 1)::double precision
from final;
$$;


create or replace function public.finalize_match(p_match_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1
    from public.matches m
    join public.leagues l on l.id = m.league_id
    where m.id = p_match_id
      and l.created_by = auth.uid()
  ) then
    raise exception 'Only league owner can finalize match';
  end if;

  update public.matches
  set status = 'fullTime'
  where id = p_match_id
    and status in ('ongoing', 'halfTime', 'live');

  -- Ensure all event-derived stats are coherent before rating computation.
  perform public.recompute_match_stats_from_events(p_match_id);
  perform public.apply_match_ratings(p_match_id);

  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'gameweek_player_stats'
  ) then
    null;
  end if;
end $$;
