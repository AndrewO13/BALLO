alter table public.profile_scout_views
  add column if not exists seen_by_player_at timestamptz;

comment on column public.profile_scout_views.seen_by_player_at is
  'Set when the profile owner opens Scout views. Null means unread.';

create index if not exists profile_scout_views_unread_idx
  on public.profile_scout_views (viewed_player_id)
  where seen_by_player_at is null;

create or replace function public.mark_profile_scout_views_seen()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  update public.profile_scout_views
  set seen_by_player_at = now()
  where viewed_player_id = auth.uid()
    and seen_by_player_at is null;
end;
$$;

revoke all on function public.mark_profile_scout_views_seen() from public;
grant execute on function public.mark_profile_scout_views_seen() to authenticated;

do $$
begin
  alter publication supabase_realtime add table public.profile_scout_views;
exception
  when duplicate_object then null;
end $$;
