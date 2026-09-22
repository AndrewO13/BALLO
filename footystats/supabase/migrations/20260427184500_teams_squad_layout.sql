alter table public.teams
add column if not exists squad_layout jsonb not null default '{}'::jsonb;

comment on column public.teams.squad_layout is
  'Persisted team squad pitch layout. JSON: {version, players:{player_id:{x,y,bench}}} with normalized coordinates.';
