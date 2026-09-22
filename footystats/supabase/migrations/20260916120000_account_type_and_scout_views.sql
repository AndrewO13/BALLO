-- Player vs technical-staff accounts, plus scout profile-view history.

alter table public.players
  add column if not exists account_type text not null default 'player';

alter table public.players
  drop constraint if exists players_account_type_check;

alter table public.players
  add constraint players_account_type_check
  check (account_type in ('player', 'technical_staff'));

alter table public.players
  add column if not exists staff_role text;

alter table public.players
  drop constraint if exists players_staff_role_check;

alter table public.players
  add constraint players_staff_role_check
  check (
    staff_role is null
    or staff_role in ('coach', 'scout', 'agent', 'other')
  );

alter table public.players
  add column if not exists staff_role_other text;

comment on column public.players.account_type is
  'player or technical_staff. Drives onboarding, navigation, and profile layout.';

comment on column public.players.staff_role is
  'Required when account_type is technical_staff: coach, scout, agent, or other.';

create table if not exists public.profile_scout_views (
  id uuid primary key default gen_random_uuid(),
  viewed_player_id uuid not null references public.players (id) on delete cascade,
  scout_id uuid not null references public.players (id) on delete cascade,
  last_viewed_at timestamptz not null default now(),
  constraint profile_scout_views_no_self check (viewed_player_id <> scout_id),
  unique (viewed_player_id, scout_id)
);

create index if not exists profile_scout_views_viewed_idx
  on public.profile_scout_views (viewed_player_id, last_viewed_at desc);

create index if not exists profile_scout_views_scout_idx
  on public.profile_scout_views (scout_id);

alter table public.profile_scout_views enable row level security;

drop policy if exists "profile_scout_views_select" on public.profile_scout_views;
create policy "profile_scout_views_select"
  on public.profile_scout_views
  for select
  to authenticated
  using (
    auth.uid() = viewed_player_id
    or auth.uid() = scout_id
  );

drop policy if exists "profile_scout_views_insert" on public.profile_scout_views;
create policy "profile_scout_views_insert"
  on public.profile_scout_views
  for insert
  to authenticated
  with check (
    auth.uid() = scout_id
    and exists (
      select 1
      from public.players p
      where p.id = auth.uid()
        and p.account_type = 'technical_staff'
        and p.staff_role = 'scout'
        and p.deleted_at is null
    )
  );

drop policy if exists "profile_scout_views_update" on public.profile_scout_views;
create policy "profile_scout_views_update"
  on public.profile_scout_views
  for update
  to authenticated
  using (auth.uid() = scout_id)
  with check (auth.uid() = scout_id);

grant select, insert, update on public.profile_scout_views to authenticated;

-- Clear staff fields and view history when an account is tombstoned.
create or replace function public.cleanup_staff_data_on_player_tombstone()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.deleted_at is not null and old.deleted_at is null then
    new.account_type := 'player';
    new.staff_role := null;
    new.staff_role_other := null;
    delete from public.profile_scout_views
    where viewed_player_id = new.id
       or scout_id = new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists players_cleanup_staff_data on public.players;
create trigger players_cleanup_staff_data
before update of deleted_at on public.players
for each row
execute function public.cleanup_staff_data_on_player_tombstone();
