-- Self-service account deletion.
-- Clients cannot delete from auth.users directly; this security definer RPC runs
-- with elevated privileges after verifying auth.uid().

create schema if not exists private;

create or replace function private.delete_own_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  if exists (
    select 1
    from public.leagues
    where created_by = v_uid
  ) then
    raise exception
      'You created one or more leagues. Delete or transfer them before deleting your account.';
  end if;

  if exists (
    select 1
    from public.teams
    where created_by = v_uid
  ) then
    raise exception
      'You created one or more teams. Delete or transfer them before deleting your account.';
  end if;

  delete from public.feed_interactions where user_id = v_uid;
  delete from public.video_likes where user_id = v_uid;
  delete from public.user_follows
    where follower_user_id = v_uid or following_user_id = v_uid;

  -- invited_by uses ON DELETE RESTRICT in team_player_invites.
  delete from public.team_player_invites
    where player_id = v_uid or invited_by = v_uid;

  delete from public.player_team_memberships where player_id = v_uid;

  delete from public.videos where uploader_user_id = v_uid;

  update public.teams
  set captain_id = null
  where captain_id = v_uid;

  -- Storage files must be removed via the Storage API before this RPC runs.
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
