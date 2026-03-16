-- FootyStats schema updates (run manually in Supabase SQL Editor)
-- Safe to re-run: uses IF NOT EXISTS / ON CONFLICT where possible.

-- 1) New tables for league workflows




-- 2) League default venue columns (used when creating matches)
alter table public.leagues
  add column if not exists default_venue text,
  add column if not exists default_venue_image_url text;

-- 3) Optional odds columns for matches (if not already present)
alter table public.matches
  add column if not exists home_odds numeric,
  add column if not exists draw_odds numeric,
  add column if not exists away_odds numeric,
  add column if not exists venue_image_url text;



-- 5) Helpful indexes
create index if not exists matches_match_date_idx on public.matches (match_date);
create index if not exists matches_league_id_idx on public.matches (league_id);
create index if not exists league_applications_status_idx on public.league_applications (status);
create index if not exists league_teams_status_idx on public.league_teams (status);
 
-- 6) Storage buckets
insert into storage.buckets (id, name, public)
values ('Profile images', 'Profile images', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('match_videos', 'match_videos', false)
on conflict (id) do nothing;



-- 8) RLS policies (basic, adjust as needed)
-- Matches: show if user is a player on teamA/teamB OR league creator
alter table public.matches enable row level security;

drop policy if exists "matches_read" on public.matches;
create policy "matches_read" on public.matches
for select to authenticated
using (
  -- User is a player on teamA or teamB
  exists (
    select 1 from public.player_team_memberships ptm
    where (ptm.team_id = matches."teamA" or ptm.team_id = matches."teamB")
    and ptm.player_id = auth.uid()
  )
  or
  -- User created the league
  exists (
    select 1 from public.leagues l
    where l.id = matches.league_id and l.created_by = auth.uid()
  )
);

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

-- 9) Storage RLS for folders
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

drop policy if exists "storage_write_venue_images" on storage.objects;
create policy "storage_write_venue_images" on storage.objects
for insert to authenticated
with check (
  bucket_id = 'Profile images'
  and (storage.foldername(name))[1] = 'venue images'
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
