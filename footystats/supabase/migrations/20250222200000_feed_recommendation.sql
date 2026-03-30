-- Content recommendation system: event logging + candidate generation + heuristic ranking
-- Run in Supabase SQL Editor. Safe to re-run.

-- =============================================================================
-- 1) FEED INTERACTIONS - Event logging (Layer 1)
-- =============================================================================
create table if not exists public.feed_interactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  video_id uuid not null references public.videos(id) on delete cascade,
  session_id uuid not null,
  shown_at timestamptz not null default now(),
  watch_seconds numeric not null default 0,
  video_seconds numeric not null default 0,
  completion_rate numeric generated always as (
    case when video_seconds > 0 then least(1, watch_seconds / video_seconds) else 0 end
  ) stored,
  swiped_fast boolean not null default false,
  rewatched boolean not null default false,
  paused boolean not null default false,
  liked boolean not null default false,
  shared boolean not null default false,
  followed_uploader boolean not null default false,
  clicked_match boolean not null default false,
  clicked_team boolean not null default false,
  clicked_uploader boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, video_id, session_id)
);

create index if not exists feed_interactions_user_idx on public.feed_interactions (user_id);
create index if not exists feed_interactions_video_idx on public.feed_interactions (video_id);
create index if not exists feed_interactions_session_idx on public.feed_interactions (session_id);
create index if not exists feed_interactions_shown_at_idx on public.feed_interactions (shown_at desc);

alter table public.feed_interactions enable row level security;

drop policy if exists "feed_interactions_select_own" on public.feed_interactions;
create policy "feed_interactions_select_own" on public.feed_interactions
  for select using (auth.uid() = user_id);

drop policy if exists "feed_interactions_insert_own" on public.feed_interactions;
create policy "feed_interactions_insert_own" on public.feed_interactions
  for insert with check (auth.uid() = user_id);

drop policy if exists "feed_interactions_update_own" on public.feed_interactions;
create policy "feed_interactions_update_own" on public.feed_interactions
  for update using (auth.uid() = user_id);

-- =============================================================================
-- 2) RPC: Log impression (call when video is shown)
-- =============================================================================
create or replace function public.log_feed_impression(
  p_user_id uuid,
  p_video_id uuid,
  p_session_id uuid,
  p_video_seconds numeric default 0
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
begin
  insert into public.feed_interactions (
    user_id, video_id, session_id, video_seconds, watch_seconds, shown_at, updated_at
  ) values (
    p_user_id, p_video_id, p_session_id, p_video_seconds, 0, now(), now()
  )
  on conflict (user_id, video_id, session_id) do update set
    shown_at = now(),
    video_seconds = excluded.video_seconds,
    updated_at = now()
  returning id into v_id;
  return v_id;
end $$;

-- =============================================================================
-- 3) RPC: Update interaction (call when we have watch time or engagements)
-- =============================================================================
create or replace function public.update_feed_interaction(
  p_id uuid,
  p_watch_seconds numeric default null,
  p_swiped_fast boolean default null,
  p_rewatched boolean default null,
  p_paused boolean default null,
  p_liked boolean default null,
  p_shared boolean default null,
  p_followed_uploader boolean default null
) returns void language plpgsql security definer set search_path = public as $$
begin
  update public.feed_interactions
  set
    watch_seconds = coalesce(p_watch_seconds, watch_seconds),
    swiped_fast = coalesce(p_swiped_fast, swiped_fast),
    rewatched = coalesce(p_rewatched, rewatched),
    paused = coalesce(p_paused, paused),
    liked = coalesce(p_liked, liked),
    shared = coalesce(p_shared, shared),
    followed_uploader = coalesce(p_followed_uploader, followed_uploader),
    updated_at = now()
  where id = p_id and user_id = auth.uid();
end $$;

-- =============================================================================
-- 4) RPC: Get recommended videos (Layer 2 + 3: candidates + heuristic ranking)
-- =============================================================================
create or replace function public.get_recommended_videos(
  p_user_id uuid default null,
  p_session_id uuid default null,
  p_limit int default 500,
  p_offset int default 0,
  p_exploration_rate numeric default 0.12
) returns table (
  video_id uuid,
  match_id uuid,
  uploader_user_id uuid,
  duration_seconds int,
  video_url text,
  thumbnail_url text,
  rank_score numeric
) language plpgsql security definer set search_path = public as $$
declare
  v_followed_uploaders uuid[];
  v_recent_skip_uploaders uuid[];
  v_recent_skip_matches uuid[];
  v_rand numeric;
begin
  -- Get followed uploaders for this user
  if p_user_id is not null then
    select array_agg(following_user_id) into v_followed_uploaders
    from user_follows where follower_user_id = p_user_id;
  end if;
  v_followed_uploaders := coalesce(v_followed_uploaders, array[]::uuid[]);

  -- Get uploaders/matches user skipped fast recently (negative signal)
  if p_user_id is not null and p_session_id is not null then
    select array_agg(distinct v.uploader_user_id) into v_recent_skip_uploaders
    from feed_interactions fi
    join videos v on v.id = fi.video_id
    where fi.user_id = p_user_id and fi.session_id = p_session_id
      and fi.swiped_fast = true and fi.watch_seconds < 2
      and v.uploader_user_id is not null;
    select array_agg(distinct v.match_id) into v_recent_skip_matches
    from feed_interactions fi
    join videos v on v.id = fi.video_id
    where fi.user_id = p_user_id and fi.session_id = p_session_id
      and fi.swiped_fast = true and fi.watch_seconds < 2
      and v.match_id is not null;
  end if;
  v_recent_skip_uploaders := coalesce(v_recent_skip_uploaders, array[]::uuid[]);
  v_recent_skip_matches := coalesce(v_recent_skip_matches, array[]::uuid[]);

  return query
  with
  -- Video popularity (completion, rewatch) from all interactions
  video_stats as (
    select
      fi.video_id,
      coalesce(avg(case when fi.watch_seconds >= 3 then 1.0 else 0.0 end), 0) as watch_3s_rate,
      coalesce(avg(case when fi.watch_seconds >= 10 or (v.duration_seconds > 0 and fi.watch_seconds >= 0.75 * v.duration_seconds) then 1.0 else 0.0 end), 0) as quality_watch_rate,
      coalesce(avg(case when fi.rewatched then 1.0 else 0.0 end), 0) as rewatch_rate,
      coalesce(avg(fi.liked::int), 0) as like_rate,
      count(*)::int as impression_count
    from feed_interactions fi
    join videos v on v.id = fi.video_id
    where fi.shown_at > now() - interval '30 days'
    group by fi.video_id
  ),
  -- Candidate pool: all videos with match/uploader context
  candidates as (
    select
      v.id as video_id,
      v.match_id,
      v.uploader_user_id,
      v.duration_seconds,
      v.video_url,
      v.thumbnail_url,
      v.created_at as video_created_at,
      m.league_id,
      m."teamA" as team_a_id,
      m."teamB" as team_b_id,
      coalesce(vs.watch_3s_rate, 0.5) as watch_3s_rate,
      coalesce(vs.quality_watch_rate, 0.4) as quality_watch_rate,
      coalesce(vs.rewatch_rate, 0) as rewatch_rate,
      coalesce(vs.like_rate, 0) as like_rate,
      coalesce(vs.impression_count, 0) as impression_count,
      -- Recency: newer = better (decay over 14 days)
      greatest(0, 1 - extract(epoch from (now() - v.created_at)) / (14 * 86400)) as recency_score,
      -- Uploader followed boost
      case when p_user_id is not null and v.uploader_user_id = any(v_followed_uploaders) then 0.15 else 0 end as uploader_follow_boost,
      -- Skip penalties
      case when v.uploader_user_id = any(v_recent_skip_uploaders) then -0.2 else 0 end as skip_uploader_penalty,
      case when v.match_id = any(v_recent_skip_matches) then -0.15 else 0 end as skip_match_penalty,
      -- Epsilon-greedy: random for exploration
      random() as exploration_rand
    from videos v
    left join matches m on m.id = v.match_id
    left join video_stats vs on vs.video_id = v.id
  ),
  scored as (
    select
      c.*,
      -- Heuristic rank score
      (
        0.25 * c.recency_score
        + 0.20 * c.watch_3s_rate
        + 0.25 * c.quality_watch_rate
        + 0.10 * c.rewatch_rate
        + 0.05 * c.like_rate
        + c.uploader_follow_boost
        + c.skip_uploader_penalty
        + c.skip_match_penalty
      ) as base_score
    from candidates c
  )
  select
    s.video_id,
    s.match_id,
    s.uploader_user_id,
    s.duration_seconds,
    s.video_url,
    s.thumbnail_url,
    -- Apply exploration: 12% of the time, boost by random to surface variety
    (s.base_score + case when s.exploration_rand < p_exploration_rate then 0.3 + random() * 0.4 else 0 end) as rank_score
  from scored s
  order by rank_score desc
  limit p_limit
  offset p_offset;
end $$;
