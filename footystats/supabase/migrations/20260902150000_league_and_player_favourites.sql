-- League and player favourites: per-user stars with denormalized counts.

alter table public.leagues
  add column if not exists favourite_count integer not null default 0;

comment on column public.leagues.favourite_count is
  'Denormalized count of rows in league_favourites; maintained by trigger.';

create index if not exists leagues_favourite_count_idx
  on public.leagues (favourite_count desc);

create table if not exists public.league_favourites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  league_id uuid not null references public.leagues (id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint league_favourites_unique unique (user_id, league_id)
);

create index if not exists league_favourites_user_idx
  on public.league_favourites (user_id);

create index if not exists league_favourites_league_idx
  on public.league_favourites (league_id);

alter table public.league_favourites enable row level security;

drop policy if exists "league_favourites_select_own" on public.league_favourites;
create policy "league_favourites_select_own"
  on public.league_favourites
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "league_favourites_insert_own" on public.league_favourites;
create policy "league_favourites_insert_own"
  on public.league_favourites
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "league_favourites_delete_own" on public.league_favourites;
create policy "league_favourites_delete_own"
  on public.league_favourites
  for delete
  to authenticated
  using (auth.uid() = user_id);

create or replace function public.sync_league_favourite_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.leagues
    set favourite_count = favourite_count + 1
    where id = new.league_id;
    return new;
  elsif tg_op = 'DELETE' then
    update public.leagues
    set favourite_count = greatest(favourite_count - 1, 0)
    where id = old.league_id;
    return old;
  end if;
  return null;
end;
$$;

drop trigger if exists league_favourites_count_trigger on public.league_favourites;
create trigger league_favourites_count_trigger
after insert or delete on public.league_favourites
for each row
execute function public.sync_league_favourite_count();

alter table public.players
  add column if not exists favourite_count integer not null default 0;

comment on column public.players.favourite_count is
  'Denormalized count of rows in player_favourites; maintained by trigger.';

create index if not exists players_favourite_count_idx
  on public.players (favourite_count desc);

create table if not exists public.player_favourites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  player_id uuid not null references public.players (id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint player_favourites_unique unique (user_id, player_id)
);

create index if not exists player_favourites_user_idx
  on public.player_favourites (user_id);

create index if not exists player_favourites_player_idx
  on public.player_favourites (player_id);

alter table public.player_favourites enable row level security;

drop policy if exists "player_favourites_select_own" on public.player_favourites;
create policy "player_favourites_select_own"
  on public.player_favourites
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "player_favourites_insert_own" on public.player_favourites;
create policy "player_favourites_insert_own"
  on public.player_favourites
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "player_favourites_delete_own" on public.player_favourites;
create policy "player_favourites_delete_own"
  on public.player_favourites
  for delete
  to authenticated
  using (auth.uid() = user_id);

create or replace function public.sync_player_favourite_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.players
    set favourite_count = favourite_count + 1
    where id = new.player_id;
    return new;
  elsif tg_op = 'DELETE' then
    update public.players
    set favourite_count = greatest(favourite_count - 1, 0)
    where id = old.player_id;
    return old;
  end if;
  return null;
end;
$$;

drop trigger if exists player_favourites_count_trigger on public.player_favourites;
create trigger player_favourites_count_trigger
after insert or delete on public.player_favourites
for each row
execute function public.sync_player_favourite_count();
