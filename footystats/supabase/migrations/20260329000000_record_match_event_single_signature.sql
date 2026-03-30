-- PostgREST could not resolve record_match_event when both the original 6-arg
-- and the newer 7-arg overloads existed (CREATE OR REPLACE only updates an
-- existing function if the signature matches; adding p_secondary_player_id
-- created a second overload). Drop the old signature so only one RPC remains.

drop function if exists public.record_match_event(uuid, text, uuid, uuid, smallint, smallint);

create or replace function public.record_match_event(
  p_match_id uuid,
  p_event_type text,
  p_team_id uuid,
  p_player_id uuid default null,
  p_minute smallint default null,
  p_second smallint default 0,
  p_secondary_player_id uuid default null
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
    perform _ensure_match_player_stats(p_match_id, p_player_id, p_team_id);
    perform _ensure_match_player_stats(p_match_id, p_secondary_player_id, p_team_id);
  end if;

  insert into match_events (match_id, event_type, event_minute, event_second, team_id, player_id, secondary_player_id)
  values (
    p_match_id,
    p_event_type,
    coalesce(p_minute, 0),
    p_second,
    p_team_id,
    p_player_id,
    case when p_event_type = 'substitution' then p_secondary_player_id else null end
  )
  returning id into v_event_id;

  if p_player_id is not null and p_event_type <> 'substitution' then
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

grant execute on function public.record_match_event(uuid, text, uuid, uuid, smallint, smallint, uuid) to authenticated;
