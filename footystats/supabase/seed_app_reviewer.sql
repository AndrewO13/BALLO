-- App Store reviewer demo account + rich superstar content.
-- Idempotent: safe to re-run. Login verified via Auth password grant.
--
-- Email:    reviewer@ballonetwork.com
-- Password: BalloReview2026!
--
-- Fills Home (focus rings, performance chart, this-week matches, standings)
-- and Profile (year/career stats, badges progress, matches, scout views,
-- radar chart year slider with 2021–2025 historical match_player_stats).

create extension if not exists pgcrypto with schema extensions;

do $$
declare
  v_user_id uuid := 'a1111111-1111-4111-8111-111111111111';
  v_identity_id uuid := 'a1212121-1212-4121-8121-121212121212';
  v_team_a uuid := 'a2222222-2222-4222-8222-222222222222'; -- Review United
  v_team_b uuid := 'a3333333-3333-4333-8333-333333333333'; -- Demo FC
  v_team_c uuid := 'a3434343-3434-4343-8343-343434343434'; -- Apex Athletic
  v_team_d uuid := 'a3535353-3535-4353-8353-353535353535'; -- City Rovers
  v_ex_team1 uuid := 'a3636363-3636-4363-8363-363636363636'; -- Nile Academy (2014–2019)
  v_ex_team2 uuid := 'a3737373-3737-4373-8373-373737373737'; -- Kampala United (2019–2022)
  v_ex_team3 uuid := 'a3838383-3838-4383-8383-383838383838'; -- Villa Stars (2022–2025)
  v_league uuid := 'a4444444-4444-4444-8444-444444444444';
  v_season uuid := 'a5555555-5555-4555-8555-555555555555';
  v_gw1 uuid := 'a6666666-6666-4666-8666-666666666666';
  v_gw2 uuid := 'a6677777-6677-4677-8677-667777777777';
  v_gw3 uuid := 'a6688888-6688-4688-8688-668888888888';
  v_gw4 uuid := 'a6699999-6699-4699-8699-669999999999';
  v_gw5 uuid := 'a66aaaaa-66aa-46aa-86aa-66aaaaaaaaaa';
  v_gw6 uuid := 'a66bbbbb-66bb-46bb-86bb-66bbbbbbbbbb';
  v_gw7 uuid := 'a66ccccc-66cc-46cc-86cc-66cccccccccc';
  v_gw8 uuid := 'a66ddddd-66dd-46dd-86dd-66dddddddddd'; -- current / this week
  v_match1 uuid := 'a7777777-7777-4777-8777-777777777777';
  v_match2 uuid := 'a8888888-8888-4888-8888-888888888888';
  v_match3 uuid := 'a8787878-8787-4787-8787-878787878787';
  v_match4 uuid := 'a8797979-8797-4797-8797-879797979797';
  v_match5 uuid := 'a87a7a7a-87a7-47a7-87a7-87a7a7a7a7a7';
  v_match6 uuid := 'a87b7b7b-87b7-47b7-87b7-87b7b7b7b7b7';
  v_match7 uuid := 'a87c7c7c-87c7-47c7-87c7-87c7c7c7c7c7';
  v_match8 uuid := 'a87d7d7d-87d7-47d7-87d7-87d7d7d7d7d7'; -- this-week upcoming
  v_match_b1 uuid := 'a8808080-8808-4808-8808-880808080808'; -- filler standings matches
  v_match_b2 uuid := 'a8818181-8818-4818-8818-881818181818';
  v_match_b3 uuid := 'a8828282-8828-4828-8828-882828282828';
  v_match_b4 uuid := 'a8838383-8838-4838-8838-883838383838';
  v_match_b5 uuid := 'a8848484-8848-4848-8848-884848484848';
  v_match_b6 uuid := 'a8858585-8858-4858-8858-885858585858';
  v_match_b7 uuid := 'a8868686-8868-4868-8868-886868686868';
  -- Historical radar fixtures (calendar years on the Profile year slider)
  v_hist_season uuid := 'a55bbbbb-55bb-45bb-85bb-55bbbbbbbbbb';
  v_hist_gw uuid := 'a66eeeee-66ee-46ee-86ee-66eeeeeeeeee';
  v_h_m21a uuid := 'a8900001-8900-4900-8900-890000000001';
  v_h_m21b uuid := 'a8900002-8900-4900-8900-890000000002';
  v_h_m22a uuid := 'a8900003-8900-4900-8900-890000000003';
  v_h_m22b uuid := 'a8900004-8900-4900-8900-890000000004';
  v_h_m23a uuid := 'a8900005-8900-4900-8900-890000000005';
  v_h_m23b uuid := 'a8900006-8900-4900-8900-890000000006';
  v_h_m24a uuid := 'a8900007-8900-4900-8900-890000000007';
  v_h_m24b uuid := 'a8900008-8900-4900-8900-890000000008';
  v_h_m25a uuid := 'a8900009-8900-4900-8900-890000000009';
  v_h_m25b uuid := 'a890000a-8900-4900-8900-89000000000a';
  v_teammate1 uuid := 'ab111111-b111-4111-8111-b11111111111';
  v_teammate2 uuid := 'ab222222-b222-4222-8222-b22222222222';
  v_opp_scorer uuid := 'ab333333-b333-4333-8333-b33333333333';
  v_scout1 uuid := 'ab444444-b444-4444-8444-b44444444444';
  v_scout2 uuid := 'ab555555-b555-4555-8555-b55555555555';
  v_fan1 uuid := 'ab666666-b666-4666-8666-b66666666666';
  v_fan2 uuid := 'ab777777-b777-4777-8777-b77777777777';
  v_fan3 uuid := 'ab888888-b888-4888-8888-b88888888888';
  -- Demo crests are re-hosted in Supabase Storage ("Profile images/team logos/demo/").
  -- crests.football-data.org sends no CORS headers, so Flutter web (CanvasKit)
  -- cannot decode those images and logos render as placeholders in the browser.
  v_crest_base text := 'https://dcpltazuzyyhxtkpbuiu.supabase.co/storage/v1/object/public/Profile%20images/team%20logos/demo/';
  -- Anchor calendar so "this week" carousel always has a match near seed time.
  v_today date := current_date;
  v_this_week_match date := v_today + ((3 - extract(isodow from v_today)::int + 7) % 7);
  v_gw7_date date := v_today - extract(isodow from v_today)::int; -- last Sunday
  v_gw6_date date := v_gw7_date - 7;
  v_gw5_date date := v_gw7_date - 14;
  v_gw4_date date := v_gw7_date - 21;
  v_gw3_date date := v_gw7_date - 28;
  v_gw2_date date := v_gw7_date - 35;
  v_gw1_date date := v_gw7_date - 42;
begin
  if v_this_week_match < v_today then
    v_this_week_match := v_today; -- if Wednesday already passed, use today
  end if;

  --------------------------------------------------------------------
  -- Auth user
  --------------------------------------------------------------------
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

  --------------------------------------------------------------------
  -- Superstar player profile (Home focus rings + Profile header)
  --------------------------------------------------------------------
  insert into public.players (
    id, username, player_name, position, country, account_type,
    community_guidelines_accepted_at, about, favourite_count,
    social_instagram, social_tiktok, social_x, focus_ring_config, image_url
  ) values (
    v_user_id, 'appreviewer', 'App Reviewer', 'Attacker', 'UG', 'player',
    now(),
    'Ballon d’Or hopeful. Clinical finisher for Review United — live stats, highlights, and scouting heat every gameweek.',
    128,
    'appreviewer', 'appreviewer', 'appreviewer',
    jsonb_build_object(
      'primary_attribute', 'goals',
      'targets', jsonb_build_object('goals', 3, 'assists', 2, 'shots_on_target', 5)
    ),
    'lib/assets/images/avatars/3d_avatar_13.png'
  )
  on conflict (id) do update set
    username = excluded.username,
    player_name = excluded.player_name,
    position = excluded.position,
    country = excluded.country,
    about = excluded.about,
    favourite_count = excluded.favourite_count,
    social_instagram = excluded.social_instagram,
    social_tiktok = excluded.social_tiktok,
    social_x = excluded.social_x,
    focus_ring_config = excluded.focus_ring_config,
    community_guidelines_accepted_at =
      coalesce(public.players.community_guidelines_accepted_at, now());

  -- Seed-only supporting players (no auth rows required)
  insert into public.players (id, username, player_name, position, country, account_type, staff_role)
  values
    (v_teammate1, 'rev_kai', 'Kai Mensah', 'Midfielder', 'UG', 'player', null),
    (v_teammate2, 'rev_oko', 'Oko Bemba', 'Defender', 'UG', 'player', null),
    (v_opp_scorer, 'demo_striker', 'Leo Nambi', 'Attacker', 'UG', 'player', null),
    (v_scout1, 'scout_mira', 'Mira Okello', null, 'UG', 'technical_staff', 'scout'),
    (v_scout2, 'scout_jon', 'Jon Adeyemi', null, 'KE', 'technical_staff', 'scout'),
    (v_fan1, 'fan_ella', 'Ella K', 'Midfielder', 'UG', 'player', null),
    (v_fan2, 'fan_tito', 'Tito M', 'Attacker', 'UG', 'player', null),
    (v_fan3, 'fan_zara', 'Zara N', 'Defender', 'TZ', 'player', null)
  on conflict (id) do update set
    username = excluded.username,
    player_name = excluded.player_name,
    position = excluded.position,
    account_type = excluded.account_type,
    staff_role = excluded.staff_role;

  --------------------------------------------------------------------
  -- League / teams / season / gameweeks
  --------------------------------------------------------------------
  -- Crests/competition badges hosted in Supabase Storage (CORS-safe; HTTPS URLs work as logo_id).
  -- Only Review United is created_by the reviewer so Home defaults to the team with stats.
  insert into public.teams (id, team_name, short_form, created_by, logo_id, banner_id)
  values
    (
      v_team_a, 'Review United', 'REV', v_user_id,
      v_crest_base || 'crest-57.png',
      'https://images.unsplash.com/photo-1431324155629-1a6deb1dec8d?auto=format&fit=crop&w=1600&q=80'
    ),
    (
      v_team_b, 'Demo FC', 'DEM', v_teammate1,
      v_crest_base || 'crest-61.png',
      'https://images.unsplash.com/photo-1529900748604-07564a03e7a6?auto=format&fit=crop&w=1600&q=80'
    ),
    (
      v_team_c, 'Apex Athletic', 'APX', v_teammate1,
      v_crest_base || 'crest-65.png',
      'https://images.unsplash.com/photo-1574629810360-7efbbe195018?auto=format&fit=crop&w=1600&q=80'
    ),
    (
      v_team_d, 'City Rovers', 'CTY', v_teammate1,
      v_crest_base || 'crest-64.png',
      'https://images.unsplash.com/photo-1551958219-acbc608c6377?auto=format&fit=crop&w=1600&q=80'
    ),
    (
      v_ex_team1, 'Nile Academy', 'NIL', v_teammate1,
      v_crest_base || 'crest-5.png',
      'https://images.unsplash.com/photo-1529900748604-07564a03e7a6?auto=format&fit=crop&w=1600&q=80'
    ),
    (
      v_ex_team2, 'Kampala United', 'KLA', v_teammate1,
      v_crest_base || 'crest-81.png',
      'https://images.unsplash.com/photo-1574629810360-7efbbe195018?auto=format&fit=crop&w=1600&q=80'
    ),
    (
      v_ex_team3, 'Villa Stars', 'VIL', v_teammate1,
      v_crest_base || 'crest-73.png',
      'https://images.unsplash.com/photo-1551958219-acbc608c6377?auto=format&fit=crop&w=1600&q=80'
    )
  on conflict (id) do update set
    team_name = excluded.team_name,
    short_form = excluded.short_form,
    created_by = excluded.created_by,
    logo_id = excluded.logo_id,
    banner_id = excluded.banner_id;

  insert into public.leagues (id, league_name, created_by, country, default_venue, logo_id)
  values (
    v_league, 'App Review League', v_user_id, 'UG', 'Review Arena',
    v_crest_base || 'crest-PL.png'
  )
  on conflict (id) do update set
    league_name = excluded.league_name,
    default_venue = excluded.default_venue,
    logo_id = excluded.logo_id;

  insert into public.seasons (id, league_id, season_name, status, start_date)
  values (v_season, v_league, 'Review Season 2026', 'ongoing', v_gw1_date)
  on conflict (id) do update set
    season_name = excluded.season_name,
    status = 'ongoing',
    start_date = excluded.start_date;

  insert into public.gameweeks (id, season_id, week)
  values
    (v_gw1, v_season, 1),
    (v_gw2, v_season, 2),
    (v_gw3, v_season, 3),
    (v_gw4, v_season, 4),
    (v_gw5, v_season, 5),
    (v_gw6, v_season, 6),
    (v_gw7, v_season, 7),
    (v_gw8, v_season, 8)
  on conflict (id) do update set week = excluded.week, season_id = excluded.season_id;

  insert into public.league_team_memberships (league_id, team_id, added_by, start_date)
  select v_league, t.team_id, v_user_id, v_gw1_date
  from (values (v_team_a), (v_team_b), (v_team_c), (v_team_d)) as t(team_id)
  where not exists (
    select 1 from public.league_team_memberships ltm
    where ltm.league_id = v_league and ltm.team_id = t.team_id and ltm.end_date is null
  );

  insert into public.player_team_memberships (player_id, team_id, role, start_date)
  select p.player_id, p.team_id, 'player', v_gw1_date
  from (values
    (v_user_id, v_team_a),
    (v_teammate1, v_team_a),
    (v_teammate2, v_team_a),
    (v_opp_scorer, v_team_b)
  ) as p(player_id, team_id)
  where not exists (
    select 1 from public.player_team_memberships ptm
    where ptm.player_id = p.player_id and ptm.team_id = p.team_id and ptm.end_date is null
  );

  update public.teams set captain_id = v_user_id where id = v_team_a;

  -- Home lists teams by created_by OR membership. Keep reviewer only on Review United
  -- so focus rings / GW stats resolve against the team with match_player_stats.
  delete from public.player_team_memberships
  where player_id = v_user_id
    and team_id in (v_team_b, v_team_c, v_team_d);

  insert into public.player_team_memberships (player_id, team_id, role, start_date)
  select v_user_id, v_team_a, 'admin', v_gw1_date
  where not exists (
    select 1 from public.player_team_memberships
    where player_id = v_user_id and team_id = v_team_a and role = 'admin' and end_date is null
  );

  insert into public.player_team_memberships (player_id, team_id, role, start_date)
  select v_teammate1, t.team_id, 'admin', v_gw1_date
  from (values (v_team_b), (v_team_c), (v_team_d)) as t(team_id)
  where not exists (
    select 1 from public.player_team_memberships ptm
    where ptm.player_id = v_teammate1 and ptm.team_id = t.team_id
      and ptm.role = 'admin' and ptm.end_date is null
  );

  -- Club history: Profile uses membership created_at → end_date for year labels.
  delete from public.player_team_memberships
  where player_id = v_user_id
    and team_id in (v_ex_team1, v_ex_team2, v_ex_team3);

  insert into public.player_team_memberships (
    player_id, team_id, role, start_date, end_date, created_at
  ) values
    (v_user_id, v_ex_team1, 'player', '2014-01-15', '2019-06-30', '2014-01-15 10:00:00+00'),
    (v_user_id, v_ex_team2, 'player', '2019-07-01', '2022-05-31', '2019-07-01 10:00:00+00'),
    (v_user_id, v_ex_team3, 'player', '2022-06-15', '2025-08-31', '2022-06-15 10:00:00+00');

  update public.player_team_memberships
  set
    start_date = '2025-09-01',
    created_at = '2025-09-01 10:00:00+00',
    end_date = null
  where player_id = v_user_id
    and team_id = v_team_a
    and end_date is null;

  --------------------------------------------------------------------
  -- Matches: GW1–7 finished (Review United dominant) + GW8 this week
  --------------------------------------------------------------------
  insert into public.matches (
    id, match_date, match_time, status,
    "teamA", "teamB", "teamA_score", "teamB_score",
    venue, gameweek, season_id, league_id, started_at
  ) values
    -- Review United fixtures (home unless noted)
    (v_match1, v_gw1_date, '15:00', 'fullTime', v_team_a, v_team_b, 5, 1, 'Review Arena', v_gw1, v_season, v_league, v_gw1_date + time '15:00'),
    (v_match2, v_gw2_date, '15:00', 'fullTime', v_team_c, v_team_a, 0, 4, 'Apex Park', v_gw2, v_season, v_league, v_gw2_date + time '15:00'),
    (v_match3, v_gw3_date, '16:00', 'fullTime', v_team_a, v_team_d, 6, 2, 'Review Arena', v_gw3, v_season, v_league, v_gw3_date + time '16:00'),
    (v_match4, v_gw4_date, '15:00', 'fullTime', v_team_b, v_team_a, 1, 3, 'Demo Ground', v_gw4, v_season, v_league, v_gw4_date + time '15:00'),
    (v_match5, v_gw5_date, '17:00', 'fullTime', v_team_a, v_team_c, 4, 0, 'Review Arena', v_gw5, v_season, v_league, v_gw5_date + time '17:00'),
    (v_match6, v_gw6_date, '15:00', 'fullTime', v_team_d, v_team_a, 2, 5, 'City Stadium', v_gw6, v_season, v_league, v_gw6_date + time '15:00'),
    (v_match7, v_gw7_date, '16:30', 'fullTime', v_team_a, v_team_b, 4, 1, 'Review Arena', v_gw7, v_season, v_league, v_gw7_date + time '16:30'),
    (v_match8, v_this_week_match, '18:00', 'upcoming', v_team_c, v_team_a, 0, 0, 'Apex Park', v_gw8, v_season, v_league, null),
    -- Other fixtures so standings look like a real table
    (v_match_b1, v_gw1_date, '17:30', 'fullTime', v_team_c, v_team_d, 2, 2, 'Apex Park', v_gw1, v_season, v_league, v_gw1_date + time '17:30'),
    (v_match_b2, v_gw2_date, '17:30', 'fullTime', v_team_b, v_team_d, 1, 0, 'Demo Ground', v_gw2, v_season, v_league, v_gw2_date + time '17:30'),
    (v_match_b3, v_gw3_date, '18:00', 'fullTime', v_team_b, v_team_c, 0, 1, 'Demo Ground', v_gw3, v_season, v_league, v_gw3_date + time '18:00'),
    (v_match_b4, v_gw4_date, '17:00', 'fullTime', v_team_d, v_team_c, 3, 1, 'City Stadium', v_gw4, v_season, v_league, v_gw4_date + time '17:00'),
    (v_match_b5, v_gw5_date, '15:00', 'fullTime', v_team_d, v_team_b, 2, 2, 'City Stadium', v_gw5, v_season, v_league, v_gw5_date + time '15:00'),
    (v_match_b6, v_gw6_date, '17:00', 'fullTime', v_team_c, v_team_b, 1, 1, 'Apex Park', v_gw6, v_season, v_league, v_gw6_date + time '17:00'),
    (v_match_b7, v_gw7_date, '14:00', 'fullTime', v_team_d, v_team_c, 0, 2, 'City Stadium', v_gw7, v_season, v_league, v_gw7_date + time '14:00')
  on conflict (id) do update set
    match_date = excluded.match_date,
    match_time = excluded.match_time,
    status = excluded.status,
    "teamA" = excluded."teamA",
    "teamB" = excluded."teamB",
    "teamA_score" = excluded."teamA_score",
    "teamB_score" = excluded."teamB_score",
    venue = excluded.venue,
    gameweek = excluded.gameweek,
    season_id = excluded.season_id,
    league_id = excluded.league_id,
    started_at = excluded.started_at;

  --------------------------------------------------------------------
  -- Line-ups + superstar match_player_stats (minutes_played required)
  -- Career totals ~105 goals / ~42 assists / ~112 tackles → Iron-foot + Lockdown
  --------------------------------------------------------------------
  insert into public.match_lineups (match_id, player_id, team_id, is_starting, is_bench)
  values
    (v_match1, v_user_id, v_team_a, true, false),
    (v_match1, v_teammate1, v_team_a, true, false),
    (v_match1, v_teammate2, v_team_a, true, false),
    (v_match2, v_user_id, v_team_a, true, false),
    (v_match3, v_user_id, v_team_a, true, false),
    (v_match4, v_user_id, v_team_a, true, false),
    (v_match5, v_user_id, v_team_a, true, false),
    (v_match6, v_user_id, v_team_a, true, false),
    (v_match7, v_user_id, v_team_a, true, false)
  on conflict (match_id, player_id) do update set
    team_id = excluded.team_id,
    is_starting = true,
    is_bench = false;

  insert into public.match_player_stats (
    match_id, player_id, team_id, minutes_played,
    goals, assists, shots, shots_on_target, tackles, saves,
    rating, yellow_cards, red_cards, clean_sheets
  ) values
    (v_match1, v_user_id, v_team_a, 90, 15, 6, 22, 18, 16, 0, 4.6, 0, 0, 0),
    (v_match2, v_user_id, v_team_a, 90, 14, 5, 20, 16, 15, 0, 8.9, 0, 0, 1),
    (v_match3, v_user_id, v_team_a, 90, 16, 7, 24, 19, 14, 0, 7.9, 0, 0, 0),
    (v_match4, v_user_id, v_team_a, 88, 12, 4, 18, 14, 18, 0, 10.0, 1, 0, 0),
    (v_match5, v_user_id, v_team_a, 90, 15, 6, 21, 17, 17, 0, 5.3, 0, 0, 1),
    (v_match6, v_user_id, v_team_a, 90, 17, 8, 25, 20, 15, 0, 9.4, 0, 0, 0),
    -- Current finished gameweek (Home rings default here)
    (v_match7, v_user_id, v_team_a, 90, 16, 6, 23, 18, 17, 0, 6.7, 0, 0, 0),
    (v_match1, v_teammate1, v_team_a, 90, 1, 2, 4, 2, 8, 0, 7.4, 0, 0, 0),
    (v_match7, v_teammate1, v_team_a, 85, 0, 2, 3, 1, 6, 0, 7.1, 0, 0, 0)
  on conflict (match_id, player_id) do update set
    team_id = excluded.team_id,
    minutes_played = excluded.minutes_played,
    goals = excluded.goals,
    assists = excluded.assists,
    shots = excluded.shots,
    shots_on_target = excluded.shots_on_target,
    tackles = excluded.tackles,
    saves = excluded.saves,
    rating = excluded.rating,
    yellow_cards = excluded.yellow_cards,
    red_cards = excluded.red_cards,
    clean_sheets = excluded.clean_sheets;

  -- Highlight goals on latest finished match (fixture timeline)
  delete from public.match_events
  where match_id in (v_match7, v_match1);

  insert into public.match_events (
    match_id, event_type, event_minute, team_id, player_id, secondary_player_id
  ) values
    (v_match7, 'goal', 8, v_team_a, v_user_id, v_teammate1),
    (v_match7, 'goal', 22, v_team_a, v_user_id, null),
    (v_match7, 'goal', 51, v_team_a, v_user_id, v_teammate1),
    (v_match7, 'goal', 77, v_team_a, v_user_id, null),
    (v_match7, 'goal', 64, v_team_b, v_opp_scorer, null),
    (v_match1, 'goal', 12, v_team_a, v_user_id, v_teammate1),
    (v_match1, 'goal', 33, v_team_a, v_user_id, null),
    (v_match1, 'goal', 58, v_team_a, v_user_id, v_teammate2);

  --------------------------------------------------------------------
  -- Social proof: scout views + followers
  --------------------------------------------------------------------
  insert into public.profile_scout_views (viewed_player_id, scout_id, last_viewed_at, seen_by_player_at)
  values
    (v_user_id, v_scout1, now() - interval '2 hours', null),
    (v_user_id, v_scout2, now() - interval '1 day', null)
  on conflict (viewed_player_id, scout_id) do update set
    last_viewed_at = excluded.last_viewed_at,
    seen_by_player_at = null;

  insert into public.user_follows (follower_user_id, following_user_id)
  values
    (v_fan1, v_user_id),
    (v_fan2, v_user_id),
    (v_fan3, v_user_id),
    (v_teammate1, v_user_id)
  on conflict (follower_user_id, following_user_id) do nothing;

  --------------------------------------------------------------------
  -- Historical matches for Profile radar (year slider: current−5 … current)
  -- Varying attribute shapes so each year reads differently on the chart.
  -- Teams follow club history: Kampala United → Villa Stars → Review United.
  --------------------------------------------------------------------
  insert into public.seasons (id, league_id, season_name, status, start_date)
  values (v_hist_season, v_league, 'Archive (radar history)', 'completed', '2021-01-01')
  on conflict (id) do update set
    season_name = excluded.season_name,
    status = 'completed',
    start_date = excluded.start_date;

  insert into public.gameweeks (id, season_id, week)
  values (v_hist_gw, v_hist_season, 1)
  on conflict (id) do update set week = 1, season_id = excluded.season_id;

  insert into public.matches (
    id, match_date, match_time, status,
    "teamA", "teamB", "teamA_score", "teamB_score",
    venue, gameweek, season_id, league_id, started_at
  ) values
    -- 2021 · Kampala United (developing attacker — lower ATT/SHT, solid DIS)
    (v_h_m21a, '2021-03-14', '15:00', 'fullTime', v_ex_team2, v_team_b, 2, 1, 'Kampala Ground', v_hist_gw, v_hist_season, v_league, '2021-03-14 15:00:00+00'),
    (v_h_m21b, '2021-09-18', '16:00', 'fullTime', v_team_c, v_ex_team2, 1, 1, 'Apex Park', v_hist_gw, v_hist_season, v_league, '2021-09-18 16:00:00+00'),
    -- 2022 · late Kampala → early Villa (rising ATT, more tackles)
    (v_h_m22a, '2022-02-20', '15:00', 'fullTime', v_ex_team2, v_team_d, 3, 2, 'Kampala Ground', v_hist_gw, v_hist_season, v_league, '2022-02-20 15:00:00+00'),
    (v_h_m22b, '2022-10-08', '15:00', 'fullTime', v_ex_team3, v_team_b, 2, 0, 'Villa Park', v_hist_gw, v_hist_season, v_league, '2022-10-08 15:00:00+00'),
    -- 2023 · Villa Stars (balanced mid-career)
    (v_h_m23a, '2023-04-02', '16:30', 'fullTime', v_ex_team3, v_team_c, 4, 1, 'Villa Park', v_hist_gw, v_hist_season, v_league, '2023-04-02 16:30:00+00'),
    (v_h_m23b, '2023-11-11', '15:00', 'fullTime', v_team_d, v_ex_team3, 2, 3, 'City Stadium', v_hist_gw, v_hist_season, v_league, '2023-11-11 15:00:00+00'),
    -- 2024 · Villa Stars (peak shooting / goals)
    (v_h_m24a, '2024-05-19', '17:00', 'fullTime', v_ex_team3, v_team_b, 5, 2, 'Villa Park', v_hist_gw, v_hist_season, v_league, '2024-05-19 17:00:00+00'),
    (v_h_m24b, '2024-12-07', '15:00', 'fullTime', v_team_c, v_ex_team3, 1, 4, 'Apex Park', v_hist_gw, v_hist_season, v_league, '2024-12-07 15:00:00+00'),
    -- 2025 · late Villa + early Review United (high DEF press + ATT)
    (v_h_m25a, '2025-03-22', '16:00', 'fullTime', v_ex_team3, v_team_d, 3, 1, 'Villa Park', v_hist_gw, v_hist_season, v_league, '2025-03-22 16:00:00+00'),
    (v_h_m25b, '2025-11-09', '15:00', 'fullTime', v_team_a, v_team_b, 4, 0, 'Review Arena', v_hist_gw, v_hist_season, v_league, '2025-11-09 15:00:00+00')
  on conflict (id) do update set
    match_date = excluded.match_date,
    match_time = excluded.match_time,
    status = excluded.status,
    "teamA" = excluded."teamA",
    "teamB" = excluded."teamB",
    "teamA_score" = excluded."teamA_score",
    "teamB_score" = excluded."teamB_score",
    venue = excluded.venue,
    gameweek = excluded.gameweek,
    season_id = excluded.season_id,
    league_id = excluded.league_id,
    started_at = excluded.started_at;

  insert into public.match_lineups (match_id, player_id, team_id, is_starting, is_bench)
  values
    (v_h_m21a, v_user_id, v_ex_team2, true, false),
    (v_h_m21b, v_user_id, v_ex_team2, true, false),
    (v_h_m22a, v_user_id, v_ex_team2, true, false),
    (v_h_m22b, v_user_id, v_ex_team3, true, false),
    (v_h_m23a, v_user_id, v_ex_team3, true, false),
    (v_h_m23b, v_user_id, v_ex_team3, true, false),
    (v_h_m24a, v_user_id, v_ex_team3, true, false),
    (v_h_m24b, v_user_id, v_ex_team3, true, false),
    (v_h_m25a, v_user_id, v_ex_team3, true, false),
    (v_h_m25b, v_user_id, v_team_a, true, false)
  on conflict (match_id, player_id) do update set
    team_id = excluded.team_id,
    is_starting = true,
    is_bench = false;

  -- Stats tuned so averaged radar axes differ by year
  -- (ATT/SHT rise over time; 2025 adds tackle volume; cards stay low).
  insert into public.match_player_stats (
    match_id, player_id, team_id, minutes_played,
    goals, assists, shots, shots_on_target, tackles, saves,
    rating, yellow_cards, red_cards, clean_sheets
  ) values
    (v_h_m21a, v_user_id, v_ex_team2, 78, 1, 0, 3, 1, 4, 0, 6.8, 0, 0, 0),
    (v_h_m21b, v_user_id, v_ex_team2, 85, 0, 1, 2, 1, 5, 0, 6.5, 1, 0, 0),
    (v_h_m22a, v_user_id, v_ex_team2, 90, 2, 1, 5, 3, 6, 0, 7.4, 0, 0, 0),
    (v_h_m22b, v_user_id, v_ex_team3, 88, 1, 1, 4, 2, 7, 0, 7.2, 0, 0, 1),
    (v_h_m23a, v_user_id, v_ex_team3, 90, 3, 2, 8, 5, 8, 0, 8.1, 0, 0, 0),
    (v_h_m23b, v_user_id, v_ex_team3, 90, 2, 1, 7, 4, 9, 0, 7.8, 0, 0, 0),
    (v_h_m24a, v_user_id, v_ex_team3, 90, 4, 2, 11, 8, 10, 0, 8.6, 0, 0, 0),
    (v_h_m24b, v_user_id, v_ex_team3, 90, 3, 2, 10, 7, 11, 0, 8.4, 0, 0, 0),
    (v_h_m25a, v_user_id, v_ex_team3, 90, 3, 3, 9, 6, 14, 0, 8.8, 0, 0, 0),
    (v_h_m25b, v_user_id, v_team_a, 90, 4, 2, 12, 9, 13, 0, 9.0, 0, 0, 1)
  on conflict (match_id, player_id) do update set
    team_id = excluded.team_id,
    minutes_played = excluded.minutes_played,
    goals = excluded.goals,
    assists = excluded.assists,
    shots = excluded.shots,
    shots_on_target = excluded.shots_on_target,
    tackles = excluded.tackles,
    saves = excluded.saves,
    rating = excluded.rating,
    yellow_cards = excluded.yellow_cards,
    red_cards = excluded.red_cards,
    clean_sheets = excluded.clean_sheets;
end $$;
