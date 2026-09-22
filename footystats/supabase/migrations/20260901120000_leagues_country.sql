-- Add country to leagues so creators can set a league location.
-- Safe to re-run (uses IF NOT EXISTS).

alter table public.leagues
  add column if not exists country text;

comment on column public.leagues.country is 'ISO 3166-1 alpha-2 country code for the league location.';
