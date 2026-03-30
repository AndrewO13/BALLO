-- Optional social profile links (full https URLs) for teams, leagues, and players.

alter table public.teams
  add column if not exists social_instagram text,
  add column if not exists social_tiktok text,
  add column if not exists social_x text;

alter table public.leagues
  add column if not exists social_instagram text,
  add column if not exists social_tiktok text,
  add column if not exists social_x text;

alter table public.players
  add column if not exists social_instagram text,
  add column if not exists social_tiktok text,
  add column if not exists social_x text;

comment on column public.teams.social_instagram is 'Full URL to team Instagram profile.';
comment on column public.teams.social_tiktok is 'Full URL to team TikTok profile.';
comment on column public.teams.social_x is 'Full URL to team X (Twitter) profile.';
comment on column public.leagues.social_instagram is 'Full URL to league Instagram profile.';
comment on column public.leagues.social_tiktok is 'Full URL to league TikTok profile.';
comment on column public.leagues.social_x is 'Full URL to league X (Twitter) profile.';
comment on column public.players.social_instagram is 'Full URL to player Instagram profile.';
comment on column public.players.social_tiktok is 'Full URL to player TikTok profile.';
comment on column public.players.social_x is 'Full URL to player X (Twitter) profile.';
