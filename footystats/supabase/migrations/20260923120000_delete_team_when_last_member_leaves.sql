-- When the last active member (admin) leaves a team, delete the team instead of
-- attempting an authority transfer with no remaining members.

create or replace function public.team_memberships_handle_admin_transfer()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_captain_id uuid;
  v_remaining int;
begin
  if old.role = 'admin' and old.end_date is null and new.end_date is not null then
    select count(*)::int
      into v_remaining
    from public.player_team_memberships
    where team_id = new.team_id
      and end_date is null
      and id <> new.id;

    -- Sole member left: remove the empty team.
    if v_remaining = 0 then
      begin
        delete from public.teams where id = new.team_id;
      exception
        when foreign_key_violation then
          -- Team still referenced (e.g. match history); clear ownership.
          update public.teams
          set created_by = null,
              captain_id = null
          where id = new.team_id;
      end;
      return new;
    end if;

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
