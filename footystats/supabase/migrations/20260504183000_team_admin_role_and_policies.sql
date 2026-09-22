alter table public.player_team_memberships
  add column if not exists role text not null default 'player';

alter table public.player_team_memberships
  drop constraint if exists player_team_memberships_role_check;

alter table public.player_team_memberships
  add constraint player_team_memberships_role_check
  check (role in ('player', 'admin'));

create unique index if not exists uq_player_team_memberships_one_admin_per_team
  on public.player_team_memberships(team_id)
  where role = 'admin' and end_date is null;

create or replace function public.is_team_admin(p_team_id uuid, p_player_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  return exists (
    select 1
    from public.player_team_memberships ptm
    where ptm.team_id = p_team_id
      and ptm.player_id = p_player_id
      and ptm.role = 'admin'
      and ptm.end_date is null
  );
end;
$$;

grant execute on function public.is_team_admin(uuid, uuid) to authenticated;

create or replace function public.is_team_member(p_team_id uuid, p_player_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  return exists (
    select 1
    from public.player_team_memberships ptm
    where ptm.team_id = p_team_id
      and ptm.player_id = p_player_id
      and ptm.end_date is null
  );
end;
$$;

grant execute on function public.is_team_member(uuid, uuid) to authenticated;

update public.player_team_memberships
  set role = 'player'
  where role = 'admin' and end_date is null;

insert into public.player_team_memberships (player_id, team_id, start_date, role)
select t.created_by, t.id, coalesce(t.created_at, now()), 'admin'
from public.teams t
where t.created_by is not null
  and not exists (
    select 1
    from public.player_team_memberships ptm
    where ptm.team_id = t.id
      and ptm.player_id = t.created_by
  );

update public.player_team_memberships ptm
set role = 'admin'
from public.teams t
where ptm.team_id = t.id
  and ptm.player_id = t.created_by
  and ptm.end_date is null;

create or replace function public.team_memberships_handle_admin_transfer()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_captain_id uuid;
begin
  if old.role = 'admin' and old.end_date is null and new.end_date is not null then
    select captain_id
      into v_captain_id
    from public.teams
    where id = new.team_id;

    update public.player_team_memberships
      set role = 'player'
    where team_id = new.team_id
      and end_date is null
      and role = 'admin';

    if v_captain_id is not null then
      update public.player_team_memberships
        set role = 'admin'
      where team_id = new.team_id
        and player_id = v_captain_id
        and end_date is null;
    end if;

    -- In an AFTER trigger we cannot assign to NEW to change the stored row,
    -- so explicitly update the current row to set its role to 'player'.
    update public.player_team_memberships
      set role = 'player'
    where id = new.id;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_team_memberships_handle_admin_transfer on public.player_team_memberships;
create trigger trg_team_memberships_handle_admin_transfer
after update of end_date, role on public.player_team_memberships
for each row execute function public.team_memberships_handle_admin_transfer();

create or replace function public.teams_seed_admin_membership()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.created_by is not null then
    insert into public.player_team_memberships (player_id, team_id, start_date, role)
    select new.created_by, new.id, coalesce(new.created_at, now()), 'admin'
    where not exists (
      select 1
      from public.player_team_memberships ptm
      where ptm.team_id = new.id
        and ptm.player_id = new.created_by
        and ptm.end_date is null
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_teams_seed_admin_membership on public.teams;
create trigger trg_teams_seed_admin_membership
after insert on public.teams
for each row execute function public.teams_seed_admin_membership();

alter table public.teams enable row level security;
drop policy if exists "teams_select_authenticated" on public.teams;
create policy "teams_select_authenticated"
  on public.teams
  for select
  to authenticated
  using (true);

drop policy if exists "teams_insert_own" on public.teams;
create policy "teams_insert_own"
  on public.teams
  for insert
  to authenticated
  with check (created_by = auth.uid());

drop policy if exists "teams_update_admin" on public.teams;
create policy "teams_update_admin"
  on public.teams
  for update
  to authenticated
  using (public.is_team_admin(id, auth.uid()))
  with check (public.is_team_admin(id, auth.uid()));

drop policy if exists "teams_delete_admin" on public.teams;
create policy "teams_delete_admin"
  on public.teams
  for delete
  to authenticated
  using (public.is_team_admin(id, auth.uid()));

alter table public.player_team_memberships enable row level security;
drop policy if exists "player_team_memberships_select_team_members" on public.player_team_memberships;
create policy "player_team_memberships_select_team_members"
  on public.player_team_memberships
  for select
  to authenticated
  using (
    player_id = auth.uid()
    or public.is_team_member(team_id, auth.uid())
  );

drop policy if exists "player_team_memberships_update_own_or_team_admin" on public.player_team_memberships;
create policy "player_team_memberships_update_own_or_team_admin"
  on public.player_team_memberships
  for update
  to authenticated
  using (
    player_id = auth.uid()
    or public.is_team_admin(team_id, auth.uid())
  )
  with check (
    player_id = auth.uid()
    or public.is_team_admin(team_id, auth.uid())
  );

drop policy if exists "player_team_memberships_delete_own_or_team_admin" on public.player_team_memberships;
create policy "player_team_memberships_delete_own_or_team_admin"
  on public.player_team_memberships
  for delete
  to authenticated
  using (
    player_id = auth.uid()
    or public.is_team_admin(team_id, auth.uid())
  );

drop policy if exists "team_admin_can_create_invites" on public.team_player_invites;
create policy "team_admin_can_create_invites"
  on public.team_player_invites
  for insert
  to authenticated
  with check (
    invited_by = auth.uid()
    and public.is_team_admin(team_id, auth.uid())
  );

drop policy if exists "team_admin_can_view_team_invites" on public.team_player_invites;
create policy "team_admin_can_view_team_invites"
  on public.team_player_invites
  for select
  to authenticated
  using (public.is_team_admin(team_id, auth.uid()));
