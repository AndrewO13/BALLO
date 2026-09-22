-- Reset unread when a scout re-views a profile, and make realtime filters reliable.

alter table public.profile_scout_views replica identity full;

create or replace function public.record_profile_scout_view(p_viewed_player_id uuid)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if p_viewed_player_id is null or p_viewed_player_id = auth.uid() then
    return;
  end if;

  if not exists (
    select 1
    from public.players p
    where p.id = auth.uid()
      and p.account_type = 'technical_staff'
      and p.staff_role = 'scout'
      and p.deleted_at is null
  ) then
    return;
  end if;

  insert into public.profile_scout_views (
    viewed_player_id,
    scout_id,
    last_viewed_at,
    seen_by_player_at
  )
  values (
    p_viewed_player_id,
    auth.uid(),
    now(),
    null
  )
  on conflict (viewed_player_id, scout_id)
  do update set
    last_viewed_at = excluded.last_viewed_at,
    seen_by_player_at = null;
end;
$$;

revoke all on function public.record_profile_scout_view(uuid) from public;
grant execute on function public.record_profile_scout_view(uuid) to authenticated;
