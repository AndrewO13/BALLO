create table if not exists public.team_player_invites (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete cascade,
  invited_by uuid not null references public.players(id) on delete restrict,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'rejected')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  updated_at timestamptz not null default now()
);

create unique index if not exists uq_team_player_invites_pending
  on public.team_player_invites(team_id, player_id)
  where status = 'pending';

create index if not exists idx_team_player_invites_player_status_created
  on public.team_player_invites(player_id, status, created_at desc);

create index if not exists idx_team_player_invites_team_status_created
  on public.team_player_invites(team_id, status, created_at desc);

alter table public.team_player_invites enable row level security;

drop policy if exists "player_can_view_own_invites" on public.team_player_invites;
create policy "player_can_view_own_invites"
  on public.team_player_invites
  for select
  to authenticated
  using (player_id = auth.uid());

drop policy if exists "team_owner_can_create_invites" on public.team_player_invites;
create policy "team_owner_can_create_invites"
  on public.team_player_invites
  for insert
  to authenticated
  with check (
    invited_by = auth.uid()
    and exists (
      select 1
      from public.teams t
      where t.id = team_id
        and t.created_by = auth.uid()
    )
  );

drop policy if exists "player_can_respond_to_own_pending_invites" on public.team_player_invites;
create policy "player_can_respond_to_own_pending_invites"
  on public.team_player_invites
  for update
  to authenticated
  using (player_id = auth.uid() and status = 'pending')
  with check (player_id = auth.uid() and status in ('accepted', 'rejected'));

drop policy if exists "team_owner_can_view_team_invites" on public.team_player_invites;
create policy "team_owner_can_view_team_invites"
  on public.team_player_invites
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.teams t
      where t.id = team_id
        and t.created_by = auth.uid()
    )
  );

create or replace function public.tpi_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_tpi_set_updated_at on public.team_player_invites;
create trigger trg_tpi_set_updated_at
before update on public.team_player_invites
for each row execute function public.tpi_set_updated_at();

create or replace function public.accept_team_player_invite(p_invite_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invite public.team_player_invites%rowtype;
begin
  select *
  into v_invite
  from public.team_player_invites
  where id = p_invite_id
  for update;

  if not found then
    raise exception 'Invite not found';
  end if;

  if v_invite.player_id <> auth.uid() then
    raise exception 'Not allowed to accept this invite';
  end if;

  if v_invite.status <> 'pending' then
    raise exception 'Invite is no longer pending';
  end if;

  if not exists (
    select 1
    from public.player_team_memberships ptm
    where ptm.player_id = v_invite.player_id
      and ptm.team_id = v_invite.team_id
      and ptm.end_date is null
  ) then
    insert into public.player_team_memberships (player_id, team_id, start_date)
    values (v_invite.player_id, v_invite.team_id, now());
  end if;

  update public.team_player_invites
  set status = 'accepted',
      responded_at = now()
  where id = p_invite_id;
end;
$$;

grant execute on function public.accept_team_player_invite(uuid) to authenticated;

create or replace function public.reject_team_player_invite(p_invite_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invite public.team_player_invites%rowtype;
begin
  select *
  into v_invite
  from public.team_player_invites
  where id = p_invite_id
  for update;

  if not found then
    raise exception 'Invite not found';
  end if;

  if v_invite.player_id <> auth.uid() then
    raise exception 'Not allowed to reject this invite';
  end if;

  if v_invite.status <> 'pending' then
    raise exception 'Invite is no longer pending';
  end if;

  update public.team_player_invites
  set status = 'rejected',
      responded_at = now()
  where id = p_invite_id;
end;
$$;

grant execute on function public.reject_team_player_invite(uuid) to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'team_player_invites'
  ) then
    alter publication supabase_realtime add table public.team_player_invites;
  end if;
end
$$;
