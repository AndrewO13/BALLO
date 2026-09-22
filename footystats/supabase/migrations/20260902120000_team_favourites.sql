-- Team favourites: per-user stars with denormalized count on teams.

alter table public.teams
  add column if not exists favourite_count integer not null default 0;

comment on column public.teams.favourite_count is
  'Denormalized count of rows in team_favourites; maintained by trigger.';

create index if not exists teams_favourite_count_idx
  on public.teams (favourite_count desc);

create table if not exists public.team_favourites (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  user_id uuid not null references auth.users (id) on delete cascade,
  team_id uuid not null references public.teams (id) on delete cascade,
  constraint team_favourites_unique unique (user_id, team_id)
);

create index if not exists team_favourites_user_idx
  on public.team_favourites (user_id);

create index if not exists team_favourites_team_idx
  on public.team_favourites (team_id);

alter table public.team_favourites enable row level security;

drop policy if exists "team_favourites_select_own" on public.team_favourites;
create policy "team_favourites_select_own"
  on public.team_favourites
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "team_favourites_insert_own" on public.team_favourites;
create policy "team_favourites_insert_own"
  on public.team_favourites
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "team_favourites_delete_own" on public.team_favourites;
create policy "team_favourites_delete_own"
  on public.team_favourites
  for delete
  to authenticated
  using (auth.uid() = user_id);

create or replace function public.sync_team_favourite_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.teams
    set favourite_count = favourite_count + 1
    where id = new.team_id;
    return new;
  elsif tg_op = 'DELETE' then
    update public.teams
    set favourite_count = greatest(favourite_count - 1, 0)
    where id = old.team_id;
    return old;
  end if;
  return null;
end;
$$;

drop trigger if exists team_favourites_count_trigger on public.team_favourites;
create trigger team_favourites_count_trigger
after insert or delete on public.team_favourites
for each row
execute function public.sync_team_favourite_count();
