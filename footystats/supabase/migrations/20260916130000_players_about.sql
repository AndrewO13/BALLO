alter table public.players
  add column if not exists about text;

comment on column public.players.about is
  'Optional profile bio shown on the account Overview.';

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
    new.about := null;
    delete from public.profile_scout_views
    where viewed_player_id = new.id
       or scout_id = new.id;
  end if;
  return new;
end;
$$;
