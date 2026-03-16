-- Match events and RPC-driven stat recording
-- Run in Supabase SQL Editor. Safe to re-run (uses IF NOT EXISTS / DROP IF EXISTS).

-- 1) match_events table
create table if not exists public.match_events (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  match_id uuid not null references public.matches(id) on delete cascade,
  event_type text not null check (
    event_type in (
      'goal', 'own_goal', 'penalty_goal', 'missed_penalty',
      'yellow_card', 'red_card', 'assist', 'save', 'tackle',
      'substitution', 'shot', 'corner', 'match_start', 'match_end'
    )
  ),
  event_minute smallint check (event_minute between 0 and 130),
  event_second smallint not null default 0 check (event_second between 0 and 59),
  team_id uuid not null references public.teams(id),
  player_id uuid references public.players(id),
  secondary_player_id uuid references public.players(id),
  is_deleted boolean not null default false
);

create index if not exists match_events_match_id_idx on public.match_events (match_id);
create index if not exists match_events_event_type_idx on public.match_events (event_type);

-- 2) match_lineups table (for future lineup selection)
create table if not exists public.match_lineups (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  match_id uuid not null references public.matches(id) on delete cascade,
  player_id uuid not null references public.players(id),
  team_id uuid not null references public.teams(id),
  is_starting boolean not null default true,
  is_bench boolean not null default false,
  unique (match_id, player_id)
);

create index if not exists match_lineups_match_id_idx on public.match_lineups (match_id);


-- 3) Helper: resolve player's team for a match (from player_team_memberships + match teams)
create or replace function public._resolve_player_team_for_match(
  p_match_id uuid,
  p_player_id uuid
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_team_a uuid;
  v_team_b uuid;
  v_player_team uuid;
begin
  select m."teamA", m."teamB" into v_team_a, v_team_b
  from matches m where m.id = p_match_id;
  if v_team_a is null or v_team_b is null then
    return null;
  end if;
  select ptm.team_id into v_player_team
  from player_team_memberships ptm
  where ptm.player_id = p_player_id
    and ptm.team_id in (v_team_a, v_team_b)
    and ptm.end_date is null
  limit 1;
  return v_player_team;
end $$;

-- 4) Ensure match_player_stats row exists (upsert)
create or replace function public._ensure_match_player_stats(
  p_match_id uuid,
  p_player_id uuid,
  p_team_id uuid
) returns void language plpgsql security definer set search_path = public as $$
begin
  insert into match_player_stats (match_id, player_id, team_id)
  values (p_match_id, p_player_id, p_team_id)
  on conflict (match_id, player_id) do nothing;
end $$;

-- 5) Ensure match_team_stats row exists
create or replace function public._ensure_match_team_stats(
  p_match_id uuid,
  p_team_id uuid
) returns void language plpgsql security definer set search_path = public as $$
begin
  insert into match_team_stats (match_id, team_id)
  values (p_match_id, p_team_id)
  on conflict (match_id, team_id) do nothing;
end $$;

-- 6) record_match_goal RPC
create or replace function public.record_match_goal(
  p_match_id uuid,
  p_player_id uuid,
  p_minute smallint,
  p_second smallint default 0,
  p_assist_player_id uuid default null
)
returns jsonb language plpgsql security definer set search_path = public as $$
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
  -- 1. Verify permission: league owner or player in match
  if not (
    exists (select 1 from matches m join leagues l on l.id = m.league_id where m.id = p_match_id and l.created_by = auth.uid())
    or exists (select 1 from matches m join player_team_memberships ptm on ptm.team_id in (m."teamA", m."teamB")
      where m.id = p_match_id and ptm.player_id = auth.uid() and ptm.end_date is null)
  ) then
    raise exception 'Not authorized to record goal for this match';
  end if;

  -- 2. Match must be ongoing
  select status, "teamA", "teamB" into v_status, v_team_a, v_team_b from matches where id = p_match_id;
  if v_status is null then
    raise exception 'Match not found';
  end if;
  if v_status not in ('ongoing', 'live') then
    raise exception 'Match is not ongoing (status: %)', v_status;
  end if;

  -- 3. Resolve player's team
  v_team_id := public._resolve_player_team_for_match(p_match_id, p_player_id);
  if v_team_id is null then
    raise exception 'Player % is not in either team for this match', p_player_id;
  end if;

  v_is_team_a := (v_team_id = v_team_a);

  -- 4. Ensure stats rows exist
  perform _ensure_match_player_stats(p_match_id, p_player_id, v_team_id);
  if p_assist_player_id is not null then
    perform _ensure_match_player_stats(p_match_id, p_assist_player_id, v_team_id);
  end if;
  perform _ensure_match_team_stats(p_match_id, v_team_a);
  perform _ensure_match_team_stats(p_match_id, v_team_b);

  -- 5. Insert match_events
  insert into match_events (match_id, event_type, event_minute, event_second, team_id, player_id, secondary_player_id)
  values (p_match_id, 'goal', p_minute, p_second, v_team_id, p_player_id, p_assist_player_id)
  returning id into v_event_id;

  -- 6. Increment match_player_stats (scorer)
  update match_player_stats set goals = goals + 1 where match_id = p_match_id and player_id = p_player_id;

  -- 7. Increment assists if present
  if p_assist_player_id is not null then
    update match_player_stats set assists = assists + 1 where match_id = p_match_id and player_id = p_assist_player_id;
  end if;

  -- 8. Increment match_team_stats
  update match_team_stats set goals = goals + 1, assists = assists + case when p_assist_player_id is not null then 1 else 0 end
  where match_id = p_match_id and team_id = v_team_id;

  -- 9. Increment match score (use quoted identifiers for camelCase columns)
  if v_is_team_a then
    update matches set "teamA_score" = coalesce("teamA_score", 0) + 1 where id = p_match_id;
    select coalesce("teamA_score", 0), coalesce("teamB_score", 0) into v_new_a, v_new_b from matches where id = p_match_id;
  else
    update matches set "teamB_score" = coalesce("teamB_score", 0) + 1 where id = p_match_id;
    select coalesce("teamA_score", 0), coalesce("teamB_score", 0) into v_new_a, v_new_b from matches where id = p_match_id;
  end if;

  return jsonb_build_object(
    'teamA_score', v_new_a,
    'teamB_score', v_new_b,
    'event_id', v_event_id,
    'team_id', v_team_id,
    'is_team_a', v_is_team_a
  );
end $$;

-- 8) record_match_card RPC (yellow_card or red_card)
create or replace function public.record_match_card(
  p_match_id uuid,
  p_player_id uuid,
  p_card_type text,
  p_minute smallint,
  p_second smallint default 0
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_team_id uuid;
  v_status text;
  v_event_id uuid;
begin
  if p_card_type not in ('yellow_card', 'red_card') then
    raise exception 'Invalid card type: %', p_card_type;
  end if;

  -- Permission check (same as goal)
  if not (
    exists (select 1 from matches m join leagues l on l.id = m.league_id where m.id = p_match_id and l.created_by = auth.uid())
    or exists (select 1 from matches m join player_team_memberships ptm on ptm.team_id in (m."teamA", m."teamB")
      where m.id = p_match_id and ptm.player_id = auth.uid() and ptm.end_date is null)
  ) then
    raise exception 'Not authorized to record card for this match';
  end if;

  select status into v_status from matches where id = p_match_id;
  if v_status is null or v_status not in ('ongoing', 'live') then
    raise exception 'Match not found or not ongoing';
  end if;

  v_team_id := public._resolve_player_team_for_match(p_match_id, p_player_id);
  if v_team_id is null then
    raise exception 'Player not in either team for this match';
  end if;

  perform _ensure_match_player_stats(p_match_id, p_player_id, v_team_id);
  perform _ensure_match_team_stats(p_match_id, (select "teamA" from matches where id = p_match_id));
  perform _ensure_match_team_stats(p_match_id, (select "teamB" from matches where id = p_match_id));

  insert into match_events (match_id, event_type, event_minute, event_second, team_id, player_id)
  values (p_match_id, p_card_type, p_minute, p_second, v_team_id, p_player_id)
  returning id into v_event_id;

  if p_card_type = 'yellow_card' then
    update match_player_stats set yellow_cards = yellow_cards + 1 where match_id = p_match_id and player_id = p_player_id;
    update match_team_stats set yellow_cards = yellow_cards + 1 where match_id = p_match_id and team_id = v_team_id;
  else
    update match_player_stats set red_cards = red_cards + 1 where match_id = p_match_id and player_id = p_player_id;
    update match_team_stats set red_cards = red_cards + 1 where match_id = p_match_id and team_id = v_team_id;
  end if;

  return jsonb_build_object('event_id', v_event_id, 'team_id', v_team_id);
end $$;

-- 9) record_match_event RPC (generic: shot, corner, tackle, save, substitution)
create or replace function public.record_match_event(
  p_match_id uuid,
  p_event_type text,
  p_team_id uuid,
  p_player_id uuid default null,
  p_minute smallint default null,
  p_second smallint default 0
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_status text;
  v_event_id uuid;
begin
  if p_event_type not in ('shot', 'corner', 'tackle', 'save', 'substitution', 'assist') then
    raise exception 'Invalid event type: %', p_event_type;
  end if;

  if not (
    exists (select 1 from matches m join leagues l on l.id = m.league_id where m.id = p_match_id and l.created_by = auth.uid())
    or exists (select 1 from matches m join player_team_memberships ptm on ptm.team_id in (m."teamA", m."teamB")
      where m.id = p_match_id and ptm.player_id = auth.uid() and ptm.end_date is null)
  ) then
    raise exception 'Not authorized';
  end if;

  select status into v_status from matches where id = p_match_id;
  if v_status is null or v_status not in ('ongoing', 'live') then
    raise exception 'Match not found or not ongoing';
  end if;

  insert into match_events (match_id, event_type, event_minute, event_second, team_id, player_id)
  values (p_match_id, p_event_type, p_minute, p_second, p_team_id, p_player_id)
  returning id into v_event_id;

  -- Increment relevant stat if player provided
  if p_player_id is not null then
    perform _ensure_match_player_stats(p_match_id, p_player_id, p_team_id);
    perform _ensure_match_team_stats(p_match_id, p_team_id);
    if p_event_type = 'shot' then
      update match_player_stats set shots = coalesce(shots, 0) + 1 where match_id = p_match_id and player_id = p_player_id;
      update match_team_stats set shots = coalesce(shots, 0) + 1 where match_id = p_match_id and team_id = p_team_id;
    elsif p_event_type = 'tackle' then
      update match_player_stats set tackles = coalesce(tackles, 0) + 1 where match_id = p_match_id and player_id = p_player_id;
      update match_team_stats set tackles = coalesce(tackles, 0) + 1 where match_id = p_match_id and team_id = p_team_id;
    elsif p_event_type = 'save' then
      update match_player_stats set saves = coalesce(saves, 0) + 1 where match_id = p_match_id and player_id = p_player_id;
      update match_team_stats set saves = coalesce(saves, 0) + 1 where match_id = p_match_id and team_id = p_team_id;
    end if;
  end if;

  return jsonb_build_object('event_id', v_event_id);
end $$;

-- 10) void_match_event RPC (undo)
create or replace function public.void_match_event(p_event_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_evt record;
  v_team_a uuid;
  v_team_b uuid;
begin
  select match_id, event_type, team_id, player_id, secondary_player_id, is_deleted
  into v_evt from match_events where id = p_event_id;
  if v_evt is null or v_evt.is_deleted then
    raise exception 'Event not found or already voided';
  end if;

  if not (
    exists (select 1 from matches m join leagues l on l.id = m.league_id where m.id = v_evt.match_id and l.created_by = auth.uid())
    or exists (select 1 from matches m join player_team_memberships ptm on ptm.team_id in (m."teamA", m."teamB")
      where m.id = v_evt.match_id and ptm.player_id = auth.uid() and ptm.end_date is null)
  ) then
    raise exception 'Not authorized to void this event';
  end if;

  if v_evt.event_type = 'goal' then
    update match_player_stats set goals = greatest(0, goals - 1) where match_id = v_evt.match_id and player_id = v_evt.player_id;
    if v_evt.secondary_player_id is not null then
      update match_player_stats set assists = greatest(0, assists - 1) where match_id = v_evt.match_id and player_id = v_evt.secondary_player_id;
    end if;
    update match_team_stats set goals = greatest(0, goals - 1), assists = greatest(0, assists - case when v_evt.secondary_player_id is not null then 1 else 0 end)
    where match_id = v_evt.match_id and team_id = v_evt.team_id;

    select "teamA", "teamB" into v_team_a, v_team_b from matches where id = v_evt.match_id;
    if v_evt.team_id = v_team_a then
      update matches set "teamA_score" = greatest(0, coalesce("teamA_score", 0) - 1) where id = v_evt.match_id;
    else
      update matches set "teamB_score" = greatest(0, coalesce("teamB_score", 0) - 1) where id = v_evt.match_id;
    end if;
  elsif v_evt.event_type in ('yellow_card', 'red_card') then
    if v_evt.event_type = 'yellow_card' then
      update match_player_stats set yellow_cards = greatest(0, yellow_cards - 1) where match_id = v_evt.match_id and player_id = v_evt.player_id;
      update match_team_stats set yellow_cards = greatest(0, yellow_cards - 1) where match_id = v_evt.match_id and team_id = v_evt.team_id;
    else
      update match_player_stats set red_cards = greatest(0, red_cards - 1) where match_id = v_evt.match_id and player_id = v_evt.player_id;
      update match_team_stats set red_cards = greatest(0, red_cards - 1) where match_id = v_evt.match_id and team_id = v_evt.team_id;
    end if;
  elsif v_evt.event_type in ('shot', 'tackle', 'save') and v_evt.player_id is not null then
    if v_evt.event_type = 'shot' then
      update match_player_stats set shots = greatest(0, coalesce(shots, 0) - 1) where match_id = v_evt.match_id and player_id = v_evt.player_id;
      update match_team_stats set shots = greatest(0, coalesce(shots, 0) - 1) where match_id = v_evt.match_id and team_id = v_evt.team_id;
    elsif v_evt.event_type = 'tackle' then
      update match_player_stats set tackles = greatest(0, coalesce(tackles, 0) - 1) where match_id = v_evt.match_id and player_id = v_evt.player_id;
      update match_team_stats set tackles = greatest(0, coalesce(tackles, 0) - 1) where match_id = v_evt.match_id and team_id = v_evt.team_id;
    elsif v_evt.event_type = 'save' then
      update match_player_stats set saves = greatest(0, coalesce(saves, 0) - 1) where match_id = v_evt.match_id and player_id = v_evt.player_id;
      update match_team_stats set saves = greatest(0, coalesce(saves, 0) - 1) where match_id = v_evt.match_id and team_id = v_evt.team_id;
    end if;
  end if;

  update match_events set is_deleted = true where id = p_event_id;
end $$;

-- 11) initialize_match_stats RPC (call when match starts)
create or replace function public.initialize_match_stats(p_match_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_team_a uuid;
  v_team_b uuid;
  r record;
begin
  select "teamA", "teamB" into v_team_a, v_team_b from matches where id = p_match_id;
  if v_team_a is null or v_team_b is null then
    raise exception 'Match not found or missing teams';
  end if;

  perform _ensure_match_team_stats(p_match_id, v_team_a);
  perform _ensure_match_team_stats(p_match_id, v_team_b);

  for r in select ptm.player_id, ptm.team_id from player_team_memberships ptm
    where ptm.team_id in (v_team_a, v_team_b) and ptm.end_date is null
  loop
    perform _ensure_match_player_stats(p_match_id, r.player_id, r.team_id);
  end loop;
end $$;

-- 12) finalize_match RPC (when match ends)
create or replace function public.finalize_match(p_match_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_exists boolean;
begin
  if not exists (select 1 from matches m join leagues l on l.id = m.league_id where m.id = p_match_id and l.created_by = auth.uid()) then
    raise exception 'Only league owner can finalize match';
  end if;

  update matches set status = 'fullTime' where id = p_match_id and status in ('ongoing', 'halfTime');

  -- gameweek_player_stats: create/update if table exists
  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'gameweek_player_stats') then
    -- Placeholder: aggregate from match_player_stats for the match's gameweek
    -- Implement aggregation logic as needed
    null;
  end if;
end $$;

-- 13) RLS on match_events
alter table public.match_events enable row level security;

drop policy if exists "match_events_select" on public.match_events;
create policy "match_events_select" on public.match_events for select to authenticated
using (
  exists (select 1 from matches m where m.id = match_events.match_id and (
    exists (select 1 from player_team_memberships ptm where ptm.team_id in (m."teamA", m."teamB") and ptm.player_id = auth.uid())
    or exists (select 1 from leagues l where l.id = m.league_id and l.created_by = auth.uid())
  ))
);

drop policy if exists "match_events_insert" on public.match_events;
create policy "match_events_insert" on public.match_events for insert to authenticated
with check (false); -- inserts only via RPC
