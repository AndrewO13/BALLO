-- Content safety: reports, blocks, moderation status, guidelines acknowledgment.
-- Supports Apple Guideline 1.2 (UGC filtering, report, block, contact).

-- =============================================================================
-- 1) Videos: moderation columns
-- =============================================================================
alter table public.videos
  add column if not exists moderation_status text not null default 'approved'
    check (moderation_status in ('approved', 'pending_review', 'rejected')),
  add column if not exists moderation_scores jsonb,
  add column if not exists moderated_at timestamptz;

comment on column public.videos.moderation_status is
  'approved = live; pending_review = live but queued for human review; rejected = hidden';

create index if not exists videos_moderation_status_idx
  on public.videos (moderation_status);

-- =============================================================================
-- 2) User blocks (hide blocked users' content from the blocker)
-- =============================================================================
create table if not exists public.user_blocks (
  id uuid primary key default gen_random_uuid(),
  blocker_user_id uuid not null references auth.users(id) on delete cascade,
  blocked_user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint user_blocks_no_self check (blocker_user_id <> blocked_user_id),
  unique (blocker_user_id, blocked_user_id)
);

create index if not exists user_blocks_blocker_idx
  on public.user_blocks (blocker_user_id);
create index if not exists user_blocks_blocked_idx
  on public.user_blocks (blocked_user_id);

alter table public.user_blocks enable row level security;

drop policy if exists "user_blocks_select_own" on public.user_blocks;
create policy "user_blocks_select_own" on public.user_blocks
  for select using (auth.uid() = blocker_user_id);

drop policy if exists "user_blocks_insert_own" on public.user_blocks;
create policy "user_blocks_insert_own" on public.user_blocks
  for insert with check (auth.uid() = blocker_user_id);

drop policy if exists "user_blocks_delete_own" on public.user_blocks;
create policy "user_blocks_delete_own" on public.user_blocks
  for delete using (auth.uid() = blocker_user_id);

-- =============================================================================
-- 3) Content reports
-- =============================================================================
create table if not exists public.content_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_user_id uuid not null references auth.users(id) on delete cascade,
  target_type text not null check (target_type in ('video', 'user')),
  target_id uuid not null,
  reason text not null check (reason in (
    'spam',
    'harassment',
    'hate',
    'sexual',
    'violence',
    'impersonation',
    'other'
  )),
  details text,
  status text not null default 'open'
    check (status in ('open', 'reviewing', 'resolved', 'dismissed')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  unique (reporter_user_id, target_type, target_id)
);

create index if not exists content_reports_status_idx
  on public.content_reports (status, created_at desc);
create index if not exists content_reports_target_idx
  on public.content_reports (target_type, target_id);

alter table public.content_reports enable row level security;

drop policy if exists "content_reports_select_own" on public.content_reports;
create policy "content_reports_select_own" on public.content_reports
  for select using (auth.uid() = reporter_user_id);

drop policy if exists "content_reports_insert_own" on public.content_reports;
create policy "content_reports_insert_own" on public.content_reports
  for insert with check (auth.uid() = reporter_user_id);

-- =============================================================================
-- 4) Moderation queue (borderline / human review)
-- =============================================================================
create table if not exists public.moderation_queue (
  id uuid primary key default gen_random_uuid(),
  content_type text not null check (content_type in ('video', 'image', 'text')),
  content_ref text not null,
  uploader_user_id uuid references auth.users(id) on delete set null,
  decision_hint text not null default 'review'
    check (decision_hint in ('allow', 'review', 'reject')),
  scores jsonb,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewer_note text
);

create index if not exists moderation_queue_pending_idx
  on public.moderation_queue (status, created_at)
  where status = 'pending';

alter table public.moderation_queue enable row level security;

-- Authenticated users can insert their own queue items (via app after edge decision).
drop policy if exists "moderation_queue_insert_own" on public.moderation_queue;
create policy "moderation_queue_insert_own" on public.moderation_queue
  for insert with check (
    auth.uid() is not null
    and (uploader_user_id is null or uploader_user_id = auth.uid())
  );

-- Users can read their own queued items (no cross-user leakage).
drop policy if exists "moderation_queue_select_own" on public.moderation_queue;
create policy "moderation_queue_select_own" on public.moderation_queue
  for select using (uploader_user_id = auth.uid());

-- =============================================================================
-- 5) Community guidelines acknowledgment on players
-- =============================================================================
alter table public.players
  add column if not exists community_guidelines_accepted_at timestamptz;

-- =============================================================================
-- 6) Feed: exclude rejected videos + blocked uploaders
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
  v_blocked_uploaders uuid[];
begin
  if p_user_id is not null then
    select array_agg(following_user_id) into v_followed_uploaders
    from user_follows where follower_user_id = p_user_id;

    select array_agg(blocked_user_id) into v_blocked_uploaders
    from user_blocks where blocker_user_id = p_user_id;
  end if;
  v_followed_uploaders := coalesce(v_followed_uploaders, array[]::uuid[]);
  v_blocked_uploaders := coalesce(v_blocked_uploaders, array[]::uuid[]);

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
      greatest(0, 1 - extract(epoch from (now() - v.created_at)) / (14 * 86400)) as recency_score,
      case when p_user_id is not null and v.uploader_user_id = any(v_followed_uploaders) then 0.15 else 0 end as uploader_follow_boost,
      case when v.uploader_user_id = any(v_recent_skip_uploaders) then -0.2 else 0 end as skip_uploader_penalty,
      case when v.match_id = any(v_recent_skip_matches) then -0.15 else 0 end as skip_match_penalty,
      random() as exploration_rand
    from videos v
    left join matches m on m.id = v.match_id
    left join video_stats vs on vs.video_id = v.id
    where coalesce(v.moderation_status, 'approved') <> 'rejected'
      and (
        v.uploader_user_id is null
        or not (v.uploader_user_id = any(v_blocked_uploaders))
      )
  ),
  scored as (
    select
      c.*,
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
    (s.base_score + case when s.exploration_rand < p_exploration_rate then 0.3 + random() * 0.4 else 0 end) as rank_score
  from scored s
  order by rank_score desc
  limit p_limit
  offset p_offset;
end $$;

-- =============================================================================
-- 7) Account deletion: also clear safety tables (keeps tombstone flow)
-- =============================================================================
-- Patch only the personal-rows section via full replace of the live function.
-- Source of truth: 20260915120000_account_deletion_tombstone.sql + safety tables.

create or replace function private.delete_own_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_team record;
  v_league record;
  v_membership record;
  v_successor uuid;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  for v_team in
    select t.id
    from public.teams t
    where t.created_by = v_uid
  loop
    v_successor := null;

    select ptm.player_id
      into v_successor
    from public.player_team_memberships ptm
    where ptm.team_id = v_team.id
      and ptm.end_date is null
      and ptm.player_id <> v_uid
    order by (ptm.role = 'admin') desc, ptm.start_date asc
    limit 1;

    if v_successor is not null then
      update public.player_team_memberships
      set role = 'player'
      where team_id = v_team.id
        and player_id = v_uid
        and end_date is null
        and role = 'admin';

      update public.player_team_memberships
      set role = 'admin'
      where team_id = v_team.id
        and player_id = v_successor
        and end_date is null;

      update public.teams
      set created_by = v_successor,
          captain_id = case
            when captain_id = v_uid then v_successor
            else captain_id
          end
      where id = v_team.id;
    elsif not exists (
      select 1
      from public.matches m
      where m."teamA" = v_team.id
         or m."teamB" = v_team.id
    ) then
      begin
        delete from public.teams where id = v_team.id;
      exception
        when foreign_key_violation then
          update public.teams
          set created_by = null,
              captain_id = case
                when captain_id = v_uid then null
                else captain_id
              end
          where id = v_team.id;
      end;
    else
      update public.teams
      set created_by = null,
          captain_id = case when captain_id = v_uid then null else captain_id end
      where id = v_team.id;
    end if;
  end loop;

  for v_league in
    select l.id
    from public.leagues l
    where l.created_by = v_uid
  loop
    v_successor := null;

    select ptm.player_id
      into v_successor
    from public.league_team_memberships ltm
    join public.player_team_memberships ptm
      on ptm.team_id = ltm.team_id
     and ptm.end_date is null
     and ptm.role = 'admin'
    where ltm.league_id = v_league.id
      and ltm.end_date is null
      and ptm.player_id <> v_uid
    limit 1;

    if v_successor is null then
      select ptm.player_id
        into v_successor
      from public.league_team_memberships ltm
      join public.player_team_memberships ptm
        on ptm.team_id = ltm.team_id
       and ptm.end_date is null
      where ltm.league_id = v_league.id
        and ltm.end_date is null
        and ptm.player_id <> v_uid
      limit 1;
    end if;

    if v_successor is not null then
      update public.leagues
      set created_by = v_successor
      where id = v_league.id;
    elsif not exists (
      select 1 from public.matches m where m.league_id = v_league.id
    ) and not exists (
      select 1
      from public.league_team_memberships ltm
      where ltm.league_id = v_league.id
        and ltm.end_date is null
    ) then
      begin
        delete from public.leagues where id = v_league.id;
      exception
        when foreign_key_violation then
          update public.leagues
          set created_by = null
          where id = v_league.id;
      end;
    else
      update public.leagues
      set created_by = null
      where id = v_league.id;
    end if;
  end loop;

  for v_membership in
    select ptm.team_id, ptm.role
    from public.player_team_memberships ptm
    where ptm.player_id = v_uid
      and ptm.end_date is null
  loop
    if v_membership.role = 'admin' then
      v_successor := null;
      select ptm.player_id
        into v_successor
      from public.player_team_memberships ptm
      where ptm.team_id = v_membership.team_id
        and ptm.end_date is null
        and ptm.player_id <> v_uid
      order by ptm.start_date asc
      limit 1;

      if v_successor is not null then
        update public.player_team_memberships
        set role = 'player'
        where team_id = v_membership.team_id
          and player_id = v_uid
          and end_date is null;

        update public.player_team_memberships
        set role = 'admin'
        where team_id = v_membership.team_id
          and player_id = v_successor
          and end_date is null;
      end if;
    end if;

    update public.player_team_memberships
    set end_date = now()
    where team_id = v_membership.team_id
      and player_id = v_uid
      and end_date is null;
  end loop;

  update public.teams
  set captain_id = null
  where captain_id = v_uid;

  -- Personal + safety rows
  delete from public.content_reports where reporter_user_id = v_uid;
  delete from public.user_blocks
    where blocker_user_id = v_uid or blocked_user_id = v_uid;
  delete from public.moderation_queue where uploader_user_id = v_uid;
  delete from public.feed_interactions where user_id = v_uid;
  delete from public.video_likes where user_id = v_uid;
  delete from public.user_follows
    where follower_user_id = v_uid or following_user_id = v_uid;
  delete from public.team_player_invites
    where player_id = v_uid or invited_by = v_uid;
  delete from public.team_join_requests where player_id = v_uid;
  delete from public.league_team_join_requests where requested_by = v_uid;
  delete from public.player_favourites
    where user_id = v_uid or player_id = v_uid;
  delete from public.team_favourites where user_id = v_uid;
  delete from public.league_favourites where user_id = v_uid;
  delete from public.match_favourites where user_id = v_uid;

  begin
    update public.players
    set
      deleted_at = now(),
      player_name = 'Deleted player',
      username = 'del_' || substr(replace(id::text, '-', ''), 1, 16),
      image_url = null,
      country = null,
      position = null,
      social_instagram = null,
      social_tiktok = null,
      social_x = null,
      community_guidelines_accepted_at = null,
      focus_ring_config = jsonb_build_object(
        'primary_attribute', 'tackles',
        'targets', jsonb_build_object(
          'tackles', 10,
          'assists', 5,
          'clean_sheets', 3
        )
      ),
      favourite_count = 0
    where id = v_uid;
  exception
    when unique_violation then
      update public.players
      set
        deleted_at = now(),
        player_name = 'Deleted player',
        username = 'd' || replace(id::text, '-', ''),
        image_url = null,
        country = null,
        position = null,
        social_instagram = null,
        social_tiktok = null,
        social_x = null,
        community_guidelines_accepted_at = null,
        focus_ring_config = jsonb_build_object(
          'primary_attribute', 'tackles',
          'targets', jsonb_build_object(
            'tackles', 10,
            'assists', 5,
            'clean_sheets', 3
          )
        ),
        favourite_count = 0
      where id = v_uid;
  end;

  update storage.objects
  set owner = null,
      owner_id = null
  where owner = v_uid
     or owner_id = v_uid::text;

  delete from auth.users where id = v_uid;
end;
$$;
