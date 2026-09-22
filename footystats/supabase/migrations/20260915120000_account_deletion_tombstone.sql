-- Account deletion: keep shared football history, remove the person.
-- players.id used to CASCADE from auth.users, and leagues/teams.created_by
-- CASCADE from players — that would wipe other users' competitions.

-- Tombstone column. The players row is kept so match FKs stay valid.
alter table public.players
  add column if not exists deleted_at timestamptz;

comment on column public.players.deleted_at is
  'Set when the auth account is deleted. Row remains as an anonymous participant.';

create index if not exists players_deleted_at_idx
  on public.players (deleted_at)
  where deleted_at is null;

-- Player records must outlive auth.users.
alter table public.players
  drop constraint if exists profiles_id_fkey;

-- Ownership can be vacant or transferred; never cascade-delete the entity.
alter table public.leagues
  alter column created_by drop not null;

alter table public.leagues
  drop constraint if exists leagues_created_by_fkey;

alter table public.leagues
  add constraint leagues_created_by_fkey
  foreign key (created_by) references public.players (id) on delete set null;

alter table public.teams
  alter column created_by drop not null;

alter table public.teams
  drop constraint if exists teams_created_by_fkey;

alter table public.teams
  add constraint teams_created_by_fkey
  foreign key (created_by) references public.players (id) on delete set null;

-- Cannot follow a tombstoned player.
drop policy if exists "user_follows_insert_own" on public.user_follows;
create policy "user_follows_insert_own"
  on public.user_follows
  for insert
  with check (
    auth.uid() = follower_user_id
    and exists (
      select 1
      from public.players p
      where p.id = following_user_id
        and p.deleted_at is null
    )
  );

-- A lingering JWT must not rewrite or remove the tombstone row.
drop policy if exists "Enable delete for users based on user_id" on public.players;
drop policy if exists "Enable all actions for authenticated users" on public.players;

drop policy if exists "players_update_own" on public.players;
create policy "players_update_own"
  on public.players
  for update
  to authenticated
  using (auth.uid() = id and deleted_at is null)
  with check (auth.uid() = id and deleted_at is null);

create or replace function private.delete_own_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_team record;
  v_league record;
  v_membership record;
  v_successor uuid;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  -- 1. Teams this user created: transfer, delete if empty, or orphan.
  for v_team in
    select t.id
    from public.teams t
    where t.created_by = v_uid
  loop
    v_successor := null;

    select ptm.player_id
      into v_successor
    from public.player_team_memberships ptm
    where ptm.team_id = v_team.id
      and ptm.end_date is null
      and ptm.player_id <> v_uid
    order by (ptm.role = 'admin') desc, ptm.start_date asc
    limit 1;

    if v_successor is not null then
      update public.player_team_memberships
      set role = 'player'
      where team_id = v_team.id
        and player_id = v_uid
        and end_date is null
        and role = 'admin';

      update public.player_team_memberships
      set role = 'admin'
      where team_id = v_team.id
        and player_id = v_successor
        and end_date is null;

      update public.teams
      set created_by = v_successor,
          captain_id = case
            when captain_id = v_uid then v_successor
            else captain_id
          end
      where id = v_team.id;
    elsif not exists (
      select 1
      from public.matches m
      where m."teamA" = v_team.id
         or m."teamB" = v_team.id
    ) then
      begin
        delete from public.teams where id = v_team.id;
      exception
        when foreign_key_violation then
          update public.teams
          set created_by = null,
              captain_id = case
                when captain_id = v_uid then null
                else captain_id
              end
          where id = v_team.id;
      end;
    else
      update public.teams
      set created_by = null,
          captain_id = case when captain_id = v_uid then null else captain_id end
      where id = v_team.id;
    end if;
  end loop;

  -- 2. Leagues this user created.
  for v_league in
    select l.id
    from public.leagues l
    where l.created_by = v_uid
  loop
    v_successor := null;

    select ptm.player_id
      into v_successor
    from public.league_team_memberships ltm
    join public.player_team_memberships ptm
      on ptm.team_id = ltm.team_id
     and ptm.end_date is null
     and ptm.role = 'admin'
    where ltm.league_id = v_league.id
      and ltm.end_date is null
      and ptm.player_id <> v_uid
    limit 1;

    if v_successor is null then
      select ptm.player_id
        into v_successor
      from public.league_team_memberships ltm
      join public.player_team_memberships ptm
        on ptm.team_id = ltm.team_id
       and ptm.end_date is null
      where ltm.league_id = v_league.id
        and ltm.end_date is null
        and ptm.player_id <> v_uid
      limit 1;
    end if;

    if v_successor is not null then
      update public.leagues
      set created_by = v_successor
      where id = v_league.id;
    elsif not exists (
      select 1 from public.matches m where m.league_id = v_league.id
    ) and not exists (
      select 1
      from public.league_team_memberships ltm
      where ltm.league_id = v_league.id
        and ltm.end_date is null
    ) then
      begin
        delete from public.leagues where id = v_league.id;
      exception
        when foreign_key_violation then
          update public.leagues
          set created_by = null
          where id = v_league.id;
      end;
    else
      update public.leagues
      set created_by = null
      where id = v_league.id;
    end if;
  end loop;

  -- 3. Leave remaining squads; hand off admin if this user is the last admin.
  for v_membership in
    select ptm.team_id, ptm.role
    from public.player_team_memberships ptm
    where ptm.player_id = v_uid
      and ptm.end_date is null
  loop
    if v_membership.role = 'admin' then
      v_successor := null;
      select ptm.player_id
        into v_successor
      from public.player_team_memberships ptm
      where ptm.team_id = v_membership.team_id
        and ptm.end_date is null
        and ptm.player_id <> v_uid
      order by ptm.start_date asc
      limit 1;

      if v_successor is not null then
        update public.player_team_memberships
        set role = 'player'
        where team_id = v_membership.team_id
          and player_id = v_uid
          and end_date is null;

        update public.player_team_memberships
        set role = 'admin'
        where team_id = v_membership.team_id
          and player_id = v_successor
          and end_date is null;
      end if;
    end if;

    update public.player_team_memberships
    set end_date = now()
    where team_id = v_membership.team_id
      and player_id = v_uid
      and end_date is null;
  end loop;

  update public.teams
  set captain_id = null
  where captain_id = v_uid;

  -- 4. Personal rows (match videos stay; uploader remains the tombstone).
  delete from public.feed_interactions where user_id = v_uid;
  delete from public.video_likes where user_id = v_uid;
  delete from public.user_follows
    where follower_user_id = v_uid or following_user_id = v_uid;
  delete from public.team_player_invites
    where player_id = v_uid or invited_by = v_uid;
  delete from public.team_join_requests where player_id = v_uid;
  delete from public.league_team_join_requests where requested_by = v_uid;
  delete from public.player_favourites
    where user_id = v_uid or player_id = v_uid;
  delete from public.team_favourites where user_id = v_uid;
  delete from public.league_favourites where user_id = v_uid;
  delete from public.match_favourites where user_id = v_uid;

  -- 5. Tombstone the player so stats/lineups/events keep a stable id.
  begin
    update public.players
    set
      deleted_at = now(),
      player_name = 'Deleted player',
      username = 'del_' || substr(replace(id::text, '-', ''), 1, 16),
      image_url = null,
      country = null,
      position = null,
      social_instagram = null,
      social_tiktok = null,
      social_x = null,
      focus_ring_config = jsonb_build_object(
        'primary_attribute', 'tackles',
        'targets', jsonb_build_object(
          'tackles', 10,
          'assists', 5,
          'clean_sheets', 3
        )
      ),
      favourite_count = 0
    where id = v_uid;
  exception
    when unique_violation then
      update public.players
      set
        deleted_at = now(),
        player_name = 'Deleted player',
        username = 'd' || replace(id::text, '-', ''),
        image_url = null,
        country = null,
        position = null,
        social_instagram = null,
        social_tiktok = null,
        social_x = null,
        focus_ring_config = jsonb_build_object(
          'primary_attribute', 'tackles',
          'targets', jsonb_build_object(
            'tackles', 10,
            'assists', 5,
            'clean_sheets', 3
          )
        ),
        favourite_count = 0
      where id = v_uid;
  end;

  -- 6. Remaining storage files (team logos, match clips) must not block
  --    auth.users deletion. Avatars are removed by the client first.
  update storage.objects
  set owner = null,
      owner_id = null
  where owner = v_uid
     or owner_id = v_uid::text;

  delete from auth.users where id = v_uid;
end;
$$;

revoke all on function private.delete_own_account() from public;
grant execute on function private.delete_own_account() to authenticated;

create or replace function public.delete_own_account()
returns void
language sql
security definer
set search_path = ''
as $$
  select private.delete_own_account();
$$;

revoke all on function public.delete_own_account() from public;
grant execute on function public.delete_own_account() to authenticated;
