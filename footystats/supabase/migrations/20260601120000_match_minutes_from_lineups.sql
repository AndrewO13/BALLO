-- Minutes played from frozen match_lineups + substitution events, scaled to a 90-minute match.
-- Pitch players at kickoff count from minute 0; bench players count only after being subbed on.

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function public._match_half_duration_minutes(p_match_id uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    nullif(
      (select m.half_duration_minutes from public.matches m where m.id = p_match_id),
      0
    ),
    45
  );
$$;

-- Cumulative real match minute (0 .. 2*half_duration) for an event timestamp.
create or replace function public._event_cumulative_real_minute(
  p_match_id uuid,
  p_event_minute smallint,
  p_event_second smallint,
  p_created_at timestamptz
)
returns numeric
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_hdm integer;
  v_halftime timestamptz;
  v_resumed timestamptz;
  v_minute numeric;
  v_second numeric;
begin
  v_hdm := public._match_half_duration_minutes(p_match_id);

  select m.halftime_paused_at, m.resumed_from_halftime_at
  into v_halftime, v_resumed
  from public.matches m
  where m.id = p_match_id;

  v_minute := coalesce(p_event_minute, 0)::numeric;
  v_second := coalesce(p_event_second, 0)::numeric / 60.0;

  if v_halftime is not null
    and (
      (p_created_at is not null and p_created_at >= v_halftime)
      or (p_created_at is null and v_resumed is not null)
    )
  then
    return v_hdm::numeric + v_minute + v_second;
  end if;

  return v_minute + v_second;
end;
$$;

-- Current cumulative real minute for open stints (live or at full time).
create or replace function public._match_current_cumulative_minute(p_match_id uuid)
returns numeric
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_status text;
  v_hdm integer;
  v_started timestamptz;
  v_halftime timestamptz;
  v_resumed timestamptz;
  v_paused_seconds integer;
  v_now timestamptz := now();
begin
  select
    m.status,
    m.started_at,
    m.halftime_paused_at,
    m.resumed_from_halftime_at,
    coalesce(m.total_paused_duration_seconds, 0)
  into v_status, v_started, v_halftime, v_resumed, v_paused_seconds
  from public.matches m
  where m.id = p_match_id;

  v_hdm := public._match_half_duration_minutes(p_match_id);

  if v_started is null or v_status = 'upcoming' then
    return 0;
  end if;

  if v_status = 'fullTime' then
    return (2 * v_hdm)::numeric;
  end if;

  if v_status = 'halfTime' and v_halftime is not null then
    return greatest(
      0,
      extract(epoch from (v_halftime - v_started))::numeric / 60.0
        - (v_paused_seconds::numeric / 60.0)
    );
  end if;

  if v_resumed is not null and v_status in ('ongoing', 'live') then
    return v_hdm::numeric
      + greatest(0, extract(epoch from (v_now - v_resumed))::numeric / 60.0);
  end if;

  return greatest(
    0,
    extract(epoch from (v_now - v_started))::numeric / 60.0
      - (v_paused_seconds::numeric / 60.0)
  );
end;
$$;

-- Scale real minutes on pitch to equivalent 90-minute football minutes.
create or replace function public._scale_real_minutes_to_football(
  p_real_minutes numeric,
  p_match_id uuid
)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select case
    when coalesce(p_real_minutes, 0) <= 0 then 0
    else round(
      p_real_minutes
      * 90.0
      / greatest(1.0, (2 * public._match_half_duration_minutes(p_match_id))::numeric)
    )::integer
  end;
$$;

-- ---------------------------------------------------------------------------
-- Freeze squads into match_lineups when the match starts
-- ---------------------------------------------------------------------------

create or replace function public.freeze_match_lineups(p_match_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_team_a uuid;
  v_team_b uuid;
  v_layout_a jsonb;
  v_layout_b jsonb;
begin
  select m."teamA", m."teamB", m.team_a_lineup, m.team_b_lineup
  into v_team_a, v_team_b, v_layout_a, v_layout_b
  from public.matches m
  where m.id = p_match_id;

  if v_team_a is null or v_team_b is null then
    raise exception 'Match not found or missing teams';
  end if;

  delete from public.match_lineups where match_id = p_match_id;

  insert into public.match_lineups (match_id, player_id, team_id, is_starting, is_bench)
  select
    p_match_id,
    kv.key::uuid,
    v_team_a,
    coalesce((kv.value ->> 'bench')::boolean, false) = false,
    coalesce((kv.value ->> 'bench')::boolean, false)
  from jsonb_each(coalesce(v_layout_a -> 'players', '{}'::jsonb)) kv
  where kv.key ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';

  insert into public.match_lineups (match_id, player_id, team_id, is_starting, is_bench)
  select
    p_match_id,
    kv.key::uuid,
    v_team_b,
    coalesce((kv.value ->> 'bench')::boolean, false) = false,
    coalesce((kv.value ->> 'bench')::boolean, false)
  from jsonb_each(coalesce(v_layout_b -> 'players', '{}'::jsonb)) kv
  where kv.key ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  on conflict (match_id, player_id) do nothing;
end;
$$;

-- ---------------------------------------------------------------------------
-- Recompute minutes_played for every squad player in the match
-- ---------------------------------------------------------------------------

create or replace function public.recompute_match_minutes_played(p_match_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from public.match_lineups ml where ml.match_id = p_match_id) then
    perform public.freeze_match_lineups(p_match_id);
  end if;

  with subs as (
    select
      e.player_id as player_on,
      e.secondary_player_id as player_off,
      public._event_cumulative_real_minute(
        e.match_id,
        e.event_minute,
        e.event_second,
        e.created_at
      ) as sub_at
    from public.match_events e
    where e.match_id = p_match_id
      and e.is_deleted = false
      and e.event_type = 'substitution'
      and e.player_id is not null
      and e.secondary_player_id is not null
    order by sub_at, e.created_at
  ),
  lineup as (
    select ml.player_id, ml.is_bench
    from public.match_lineups ml
    where ml.match_id = p_match_id
  ),
  sub_events as (
    select s.sub_at, s.player_on, s.player_off from subs s
  ),
  -- Build on/off timeline per player from kickoff + substitutions.
  player_ticks as (
    select
      l.player_id,
      0::numeric as tick_at,
      case when l.is_bench then 0 else 1 end as on_pitch
    from lineup l

    union all

    select se.player_on, se.sub_at, 1 from sub_events se

    union all

    select se.player_off, se.sub_at, 0 from sub_events se
  ),
  ordered_ticks as (
    select
      pt.player_id,
      pt.tick_at,
      pt.on_pitch,
      row_number() over (
        partition by pt.player_id, pt.tick_at
        order by pt.on_pitch desc
      ) as tie_rank
    from player_ticks pt
  ),
  deduped_ticks as (
    select ot.player_id, ot.tick_at, ot.on_pitch
    from ordered_ticks ot
    where ot.tie_rank = 1
  ),
  tick_with_next as (
    select
      dt.player_id,
      dt.tick_at,
      dt.on_pitch,
      lead(dt.tick_at) over (
        partition by dt.player_id
        order by dt.tick_at
      ) as next_tick_at
    from deduped_ticks dt
  ),
  stints as (
    select
      t.player_id,
      t.tick_at as stint_start,
      coalesce(t.next_tick_at, public._match_current_cumulative_minute(p_match_id)) as stint_end
    from tick_with_next t
    where t.on_pitch = 1
      and coalesce(t.next_tick_at, public._match_current_cumulative_minute(p_match_id)) > t.tick_at
  ),
  minutes_by_player as (
    select
      s.player_id,
      public._scale_real_minutes_to_football(
        coalesce(sum(greatest(0, s.stint_end - s.stint_start)), 0),
        p_match_id
      ) as minutes_played
    from stints s
    group by s.player_id
  )
  update public.match_player_stats mps
  set minutes_played = coalesce(mbp.minutes_played, 0)
  from lineup l
  left join minutes_by_player mbp on mbp.player_id = l.player_id
  where mps.match_id = p_match_id
    and mps.player_id = l.player_id;

  update public.match_player_stats mps
  set minutes_played = 0
  where mps.match_id = p_match_id
    and not exists (
      select 1 from public.match_lineups ml
      where ml.match_id = p_match_id
        and ml.player_id = mps.player_id
    );
end;
$$;

grant execute on function public.freeze_match_lineups(uuid) to authenticated;
grant execute on function public.recompute_match_minutes_played(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Hook into match lifecycle + events
-- ---------------------------------------------------------------------------

create or replace function public.initialize_match_stats(p_match_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_team_a uuid;
  v_team_b uuid;
  r record;
begin
  select "teamA", "teamB" into v_team_a, v_team_b
  from public.matches
  where id = p_match_id;

  if v_team_a is null or v_team_b is null then
    raise exception 'Match not found or missing teams';
  end if;

  perform public._ensure_match_team_stats(p_match_id, v_team_a);
  perform public._ensure_match_team_stats(p_match_id, v_team_b);

  perform public.freeze_match_lineups(p_match_id);

  for r in
    select ml.player_id, ml.team_id
    from public.match_lineups ml
    where ml.match_id = p_match_id
  loop
    perform public._ensure_match_player_stats(p_match_id, r.player_id, r.team_id);
  end loop;

  for r in
    select ptm.player_id, ptm.team_id
    from public.player_team_memberships ptm
    where ptm.team_id in (v_team_a, v_team_b)
      and ptm.end_date is null
  loop
    perform public._ensure_match_player_stats(p_match_id, r.player_id, r.team_id);
  end loop;

  update public.match_player_stats
  set minutes_played = 0
  where match_id = p_match_id;

  perform public.recompute_match_minutes_played(p_match_id);
end;
$$;

-- Status transitions (half-time / full-time) refresh open stints.
create or replace function public.trg_matches_recompute_minutes_on_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status is distinct from old.status
    and new.status in ('halfTime', 'fullTime', 'ongoing', 'live')
    and old.status in ('upcoming', 'ongoing', 'live', 'halfTime')
    and exists (select 1 from public.match_lineups ml where ml.match_id = new.id)
  then
    perform public.recompute_match_minutes_played(new.id);
  end if;
  return new;
end;
$$;

drop trigger if exists matches_recompute_minutes_on_status on public.matches;

create trigger matches_recompute_minutes_on_status
after update of status on public.matches
for each row
execute function public.trg_matches_recompute_minutes_on_status();

-- Patch record_match_event to refresh minutes after every event.
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
  perform public.recompute_match_minutes_played(p_match_id);

  return jsonb_build_object('event_id', v_event_id);
end;
$$;

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
    exists (
      select 1
      from public.matches m
      join public.leagues l on l.id = m.league_id
      where m.id = v_evt.match_id
        and l.created_by = auth.uid()
    )
    or exists (
      select 1
      from public.matches m
      join public.player_team_memberships ptm on ptm.team_id in (m."teamA", m."teamB")
      where m.id = v_evt.match_id
        and ptm.player_id = auth.uid()
        and ptm.end_date is null
    )
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
  perform public.recompute_match_minutes_played(v_evt.match_id);
end;
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

  perform public.recompute_match_stats_from_events(p_match_id);
  perform public.recompute_match_minutes_played(p_match_id);
  perform public.apply_match_ratings(p_match_id);

  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'gameweek_player_stats'
  ) then
    null;
  end if;
end;
$$;

-- Backfill frozen lineups + minutes for matches already in progress or completed.
do $$
declare
  r record;
begin
  for r in
    select m.id
    from public.matches m
    where m.status in ('ongoing', 'halfTime', 'live', 'fullTime')
      and not exists (
        select 1 from public.match_lineups ml where ml.match_id = m.id
      )
  loop
    begin
      perform public.freeze_match_lineups(r.id);
      perform public.recompute_match_minutes_played(r.id);
    exception
      when others then
        null;
    end;
  end loop;
end;
$$;
