-- Video follows and likes
-- Run in Supabase SQL Editor. Safe to re-run (uses IF NOT EXISTS).

-- 1) user_follows: viewer (follower) follows poster (following)
-- uploader_user_id in videos identifies the poster (player/auth user)
create table if not exists public.user_follows (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  follower_user_id uuid not null,
  following_user_id uuid not null,
  constraint user_follows_no_self check (follower_user_id != following_user_id),
  unique (follower_user_id, following_user_id)
);

create index if not exists user_follows_follower_idx on public.user_follows (follower_user_id);
create index if not exists user_follows_following_idx on public.user_follows (following_user_id);

-- 2) video_likes
create table if not exists public.video_likes (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  video_id uuid not null references public.videos(id) on delete cascade,
  user_id uuid not null,
  unique (video_id, user_id)
);

create index if not exists video_likes_video_idx on public.video_likes (video_id);
create index if not exists video_likes_user_idx on public.video_likes (user_id);

-- 3) RLS for user_follows
alter table public.user_follows enable row level security;

drop policy if exists "user_follows_select_own" on public.user_follows;
create policy "user_follows_select_own" on public.user_follows
  for select using (
    auth.uid() = follower_user_id or auth.uid() = following_user_id
  );

drop policy if exists "user_follows_insert_own" on public.user_follows;
create policy "user_follows_insert_own" on public.user_follows
  for insert with check (auth.uid() = follower_user_id);

drop policy if exists "user_follows_delete_own" on public.user_follows;
create policy "user_follows_delete_own" on public.user_follows
  for delete using (auth.uid() = follower_user_id);

-- 4) RLS for video_likes
alter table public.video_likes enable row level security;

drop policy if exists "video_likes_select" on public.video_likes;
create policy "video_likes_select" on public.video_likes
  for select using (true);

drop policy if exists "video_likes_insert_own" on public.video_likes;
create policy "video_likes_insert_own" on public.video_likes
  for insert with check (auth.uid() = user_id);

drop policy if exists "video_likes_delete_own" on public.video_likes;
create policy "video_likes_delete_own" on public.video_likes
  for delete using (auth.uid() = user_id);
