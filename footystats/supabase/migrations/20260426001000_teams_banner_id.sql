alter table public.teams
add column if not exists banner_id text;

comment on column public.teams.banner_id is
'Public URL or asset key for the team banner image.';
