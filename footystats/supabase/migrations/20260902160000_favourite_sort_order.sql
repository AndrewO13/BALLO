-- User-defined ordering for favourites lists.

alter table public.team_favourites
  add column if not exists sort_order integer not null default 0;

alter table public.league_favourites
  add column if not exists sort_order integer not null default 0;

alter table public.player_favourites
  add column if not exists sort_order integer not null default 0;

create index if not exists team_favourites_user_sort_idx
  on public.team_favourites (user_id, sort_order);

create index if not exists league_favourites_user_sort_idx
  on public.league_favourites (user_id, sort_order);

create index if not exists player_favourites_user_sort_idx
  on public.player_favourites (user_id, sort_order);

drop policy if exists "team_favourites_update_own" on public.team_favourites;
create policy "team_favourites_update_own"
  on public.team_favourites
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "league_favourites_update_own" on public.league_favourites;
create policy "league_favourites_update_own"
  on public.league_favourites
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "player_favourites_update_own" on public.player_favourites;
create policy "player_favourites_update_own"
  on public.player_favourites
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
