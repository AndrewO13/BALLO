-- Case-insensitive unique usernames on public.players.

create unique index if not exists players_username_unique_ci
  on public.players (lower(trim(username)))
  where username is not null and trim(username) <> '';

-- Callable before sign-up (anon) and when editing profile (authenticated).
create or replace function public.is_username_available(
  p_username text,
  p_exclude_player_id uuid default null
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select not exists (
    select 1
    from public.players p
    where lower(trim(p.username)) = lower(trim(p_username))
      and trim(coalesce(p_username, '')) <> ''
      and (p_exclude_player_id is null or p.id <> p_exclude_player_id)
  );
$$;

revoke all on function public.is_username_available(text, uuid) from public;
grant execute on function public.is_username_available(text, uuid) to anon, authenticated;
