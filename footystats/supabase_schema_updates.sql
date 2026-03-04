-- FootyStats schema updates (run manually in Supabase SQL Editor)
-- Safe to re-run: uses IF NOT EXISTS / ON CONFLICT where possible.

-- 1) New tables for league workflows
create table if not exists public.league_teams (
  league_id uuid not null,
  team_id uuid not null,
  status text not null default 'active',
  created_at timestamp with time zone not null default now(),
  added_by uuid,
  primary key (league_id, team_id),
  constraint league_teams_league_id_fkey foreign key (league_id)
    references public.leagues(id) on delete cascade,
  constraint league_teams_team_id_fkey foreign key (team_id)
    references public.teams(id) on delete cascade,
  constraint league_teams_added_by_fkey foreign key (added_by)
    references public.players(id) on delete set null
);

create table if not exists public.league_applications (
  id uuid not null default gen_random_uuid(),
  league_id uuid not null,
  team_id uuid not null,
  status text not null default 'pending',
  created_by uuid not null,
  created_at timestamp with time zone not null default now(),
  reviewed_by uuid,
  reviewed_at timestamp with time zone,
  primary key (id),
  constraint league_applications_league_id_fkey foreign key (league_id)
    references public.leagues(id) on delete cascade,
  constraint league_applications_team_id_fkey foreign key (team_id)
    references public.teams(id) on delete cascade,
  constraint league_applications_created_by_fkey foreign key (created_by)
    references public.players(id) on delete cascade,
  constraint league_applications_reviewed_by_fkey foreign key (reviewed_by)
    references public.players(id) on delete set null,
  constraint league_applications_unique unique (league_id, team_id)
);

-- 2) Optional odds columns for matches (if not already present)
alter table public.matches
  add column if not exists home_odds numeric,
  add column if not exists draw_odds numeric,
  add column if not exists away_odds numeric;

-- 3) View for current season per league (status = 'ongoing')
create or replace view public.league_current_season as
select s.*
from public.seasons s
where s.status = 'ongoing';

-- 4) Helpful indexes
create index if not exists matches_match_date_idx on public.matches (match_date);
create index if not exists matches_league_id_idx on public.matches (league_id);
create index if not exists league_applications_status_idx on public.league_applications (status);
create index if not exists league_teams_status_idx on public.league_teams (status);

-- 5) Storage buckets
insert into storage.buckets (id, name, public)
values ('Profile images', 'Profile images', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('match_videos', 'match_videos', false)
on conflict (id) do nothing;

-- 6) RLS enablement
alter table public.league_teams enable row level security;
alter table public.league_applications enable row level security;
alter table public.matches enable row level security;
alter table public.teams enable row level security;
alter table public.leagues enable row level security;

-- 7) RLS policies (basic, adjust as needed)
-- Teams: creator can manage; authenticated can read
drop policy if exists "teams_read" on public.teams;
create policy "teams_read" on public.teams
for select to authenticated
using (true);

drop policy if exists "teams_write" on public.teams;
create policy "teams_write" on public.teams
for all to authenticated
using (created_by = auth.uid())
with check (created_by = auth.uid());

-- Leagues: creator can manage; authenticated can read
drop policy if exists "leagues_read" on public.leagues;
create policy "leagues_read" on public.leagues
for select to authenticated
using (true);

drop policy if exists "leagues_write" on public.leagues;
create policy "leagues_write" on public.leagues
for all to authenticated
using (created_by = auth.uid())
with check (created_by = auth.uid());

-- League teams: league owner can manage; authenticated can read
drop policy if exists "league_teams_read" on public.league_teams;
create policy "league_teams_read" on public.league_teams
for select to authenticated
using (true);

drop policy if exists "league_teams_write" on public.league_teams;
create policy "league_teams_write" on public.league_teams
for all to authenticated
using (
  exists (
    select 1 from public.leagues l
    where l.id = league_teams.league_id and l.created_by = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.leagues l
    where l.id = league_teams.league_id and l.created_by = auth.uid()
  )
);

-- League applications: team creator can apply, league owner can review
drop policy if exists "league_applications_read" on public.league_applications;
create policy "league_applications_read" on public.league_applications
for select to authenticated
using (
  created_by = auth.uid()
  or exists (
    select 1 from public.leagues l
    where l.id = league_applications.league_id and l.created_by = auth.uid()
  )
);

drop policy if exists "league_applications_write" on public.league_applications;
create policy "league_applications_write" on public.league_applications
for insert to authenticated
with check (created_by = auth.uid());

drop policy if exists "league_applications_review" on public.league_applications;
create policy "league_applications_review" on public.league_applications
for update to authenticated
using (
  exists (
    select 1 from public.leagues l
    where l.id = league_applications.league_id and l.created_by = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.leagues l
    where l.id = league_applications.league_id and l.created_by = auth.uid()
  )
);

-- Matches: authenticated can read; league owner can create/update/delete
drop policy if exists "matches_read" on public.matches;
create policy "matches_read" on public.matches
for select to authenticated
using (true);

drop policy if exists "matches_write" on public.matches;
create policy "matches_write" on public.matches
for all to authenticated
using (
  exists (
    select 1 from public.leagues l
    where l.id = matches.league_id and l.created_by = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.leagues l
    where l.id = matches.league_id and l.created_by = auth.uid()
  )
);

-- 8) Storage RLS for folders
alter table storage.objects enable row level security;

drop policy if exists "storage_read_profile_images" on storage.objects;
create policy "storage_read_profile_images" on storage.objects
for select to authenticated
using (bucket_id = 'Profile images');

drop policy if exists "storage_write_team_logos" on storage.objects;
create policy "storage_write_team_logos" on storage.objects
for insert to authenticated
with check (
  bucket_id = 'Profile images'
  and (storage.foldername(name))[1] = 'team logos'
);

drop policy if exists "storage_write_league_logos" on storage.objects;
create policy "storage_write_league_logos" on storage.objects
for insert to authenticated
with check (
  bucket_id = 'Profile images'
  and (storage.foldername(name))[1] = 'league logos'
);

drop policy if exists "storage_write_avatars" on storage.objects;
create policy "storage_write_avatars" on storage.objects
for insert to authenticated
with check (
  bucket_id = 'Profile images'
  and (storage.foldername(name))[1] = 'avatars'
);

drop policy if exists "storage_write_videos" on storage.objects;
create policy "storage_write_videos" on storage.objects
for insert to authenticated
with check (
  bucket_id = 'match_videos'
  and (storage.foldername(name))[1] = 'videos'
);
