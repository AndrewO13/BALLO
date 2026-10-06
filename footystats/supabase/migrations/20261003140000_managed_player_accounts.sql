-- Staff-created player profiles (no auth user until a login is attached).
-- handle_new_user must tolerate an existing players row with the same id.

alter table public.players
  add column if not exists created_by uuid references public.players (id) on delete set null;

alter table public.players
  add column if not exists login_enabled_at timestamptz;

comment on column public.players.created_by is
  'Staff account that created this player profile, if it was not self-registered.';

comment on column public.players.login_enabled_at is
  'When the creator attached an email and temporary password so the player can sign in.';

create index if not exists players_created_by_idx
  on public.players (created_by)
  where created_by is not null;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.players (id)
  values (new.id)
  on conflict (id) do nothing;
  return new;
end;
$$;
