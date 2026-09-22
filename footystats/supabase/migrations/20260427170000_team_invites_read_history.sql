alter table public.team_player_invites
  add column if not exists read_at timestamptz;

create index if not exists idx_team_player_invites_player_pending_unread
  on public.team_player_invites(player_id, created_at desc)
  where status = 'pending' and read_at is null;

create or replace function public.mark_all_team_invites_read()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_updated_count integer := 0;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  update public.team_player_invites
  set read_at = now()
  where player_id = auth.uid()
    and status = 'pending'
    and read_at is null;

  get diagnostics v_updated_count = row_count;
  return v_updated_count;
end;
$$;

grant execute on function public.mark_all_team_invites_read() to authenticated;
