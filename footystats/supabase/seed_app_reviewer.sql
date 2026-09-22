-- App Store reviewer demo account + content.
-- Idempotent: safe to re-run. Login verified via Auth password grant.
--
-- Email:    reviewer@ballonetwork.com
-- Password: BalloReview2026!

create extension if not exists pgcrypto with schema extensions;

do $$
declare
  v_user_id uuid := 'a1111111-1111-4111-8111-111111111111';
  v_identity_id uuid := 'a1212121-1212-4121-8121-121212121212';
  v_team_a uuid := 'a2222222-2222-4222-8222-222222222222';
  v_team_b uuid := 'a3333333-3333-4333-8333-333333333333';
  v_league uuid := 'a4444444-4444-4444-8444-444444444444';
  v_season uuid := 'a5555555-5555-4555-8555-555555555555';
  v_gameweek uuid := 'a6666666-6666-4666-8666-666666666666';
  v_match1 uuid := 'a7777777-7777-4777-8777-777777777777';
  v_match2 uuid := 'a8888888-8888-4888-8888-888888888888';
  v_video1 uuid := 'a9999999-9999-4999-8999-999999999999';
  v_video2 uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  v_sample_video text := 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4';
  v_sample_thumb text := 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerBlazes.jpg';
  v_sample_video2 text := 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4';
  v_sample_thumb2 text := 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerEscapes.jpg';
begin
  if not exists (select 1 from auth.users where id = v_user_id) then
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, recovery_token, email_change_token_new, email_change,
      is_anonymous, is_sso_user
    ) values (
      '00000000-0000-0000-0000-000000000000',
      v_user_id, 'authenticated', 'authenticated',
      'reviewer@ballonetwork.com',
      extensions.crypt('BalloReview2026!', extensions.gen_salt('bf')),
      now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{"onboarding_complete":true,"player_name":"App Reviewer","username":"appreviewer"}'::jsonb,
      now(), now(), '', '', '', '', false, false
    );

    insert into auth.identities (
      id, provider_id, user_id, identity_data, provider,
      last_sign_in_at, created_at, updated_at
    ) values (
      v_identity_id, v_user_id::text, v_user_id,
      jsonb_build_object(
        'sub', v_user_id::text,
        'email', 'reviewer@ballonetwork.com',
        'email_verified', true,
        'phone_verified', false
      ),
      'email', now(), now(), now()
    );
  else
    update auth.users
    set
      encrypted_password = extensions.crypt('BalloReview2026!', extensions.gen_salt('bf')),
      email_confirmed_at = coalesce(email_confirmed_at, now()),
      raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb) ||
        '{"onboarding_complete":true,"player_name":"App Reviewer","username":"appreviewer"}'::jsonb,
      updated_at = now()
    where id = v_user_id;
  end if;

  insert into public.players (
    id, username, player_name, position, country, account_type,
    community_guidelines_accepted_at
  ) values (
    v_user_id, 'appreviewer', 'App Reviewer', 'MID', 'UG', 'player', now()
  )
  on conflict (id) do update set
    username = excluded.username,
    player_name = excluded.player_name,
    community_guidelines_accepted_at =
      coalesce(public.players.community_guidelines_accepted_at, now());

  insert into public.teams (id, team_name, short_form, created_by)
  values
    (v_team_a, 'Review United', 'REV', v_user_id),
    (v_team_b, 'Demo FC', 'DEM', v_user_id)
  on conflict (id) do nothing;

  insert into public.leagues (id, league_name, created_by, country, default_venue)
  values (v_league, 'App Review League', v_user_id, 'UG', 'Review Arena')
  on conflict (id) do nothing;

  insert into public.seasons (id, league_id, season_name, status, start_date)
  values (v_season, v_league, 'Review Season 2026', 'ongoing', current_date)
  on conflict (id) do nothing;

  insert into public.gameweeks (id, season_id, week)
  values (v_gameweek, v_season, 1)
  on conflict (id) do nothing;

  insert into public.league_team_memberships (league_id, team_id, added_by, start_date)
  values
    (v_league, v_team_a, v_user_id, current_date),
    (v_league, v_team_b, v_user_id, current_date)
  on conflict do nothing;

  insert into public.player_team_memberships (player_id, team_id, role, start_date)
  values (v_user_id, v_team_a, 'player', current_date)
  on conflict do nothing;

  update public.teams set captain_id = v_user_id where id = v_team_a;

  insert into public.matches (
    id, match_date, match_time, status,
    "teamA", "teamB", "teamA_score", "teamB_score",
    venue, gameweek, season_id, league_id, started_at
  ) values
    (
      v_match1, current_date - 2, '15:00', 'fullTime',
      v_team_a, v_team_b, 3, 1,
      'Review Arena', v_gameweek, v_season, v_league,
      now() - interval '2 days'
    ),
    (
      v_match2, current_date + 3, '17:30', 'upcoming',
      v_team_b, v_team_a, 0, 0,
      'Review Arena', v_gameweek, v_season, v_league, null
    )
  on conflict (id) do nothing;

  insert into public.videos (
    id, match_id, uploader_user_id, duration_seconds,
    video_url, thumbnail_url, moderation_status, moderated_at
  ) values
    (v_video1, v_match1, v_user_id, 15, v_sample_video, v_sample_thumb, 'approved', now()),
    (v_video2, v_match1, v_user_id, 15, v_sample_video2, v_sample_thumb2, 'approved', now())
  on conflict (id) do nothing;
end $$;
