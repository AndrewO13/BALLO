alter table public.teams
add column if not exists captain_id uuid references public.players(id) on delete set null;

create index if not exists idx_teams_captain_id on public.teams(captain_id);

comment on column public.teams.captain_id is
  'Captain of the team (players.id). Used for UI badge and team management.';

