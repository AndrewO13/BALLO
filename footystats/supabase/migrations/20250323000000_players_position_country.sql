-- Add position, image_url, and country columns to players table for onboarding.
-- Safe to re-run (uses IF NOT EXISTS).

alter table public.players
  add column if not exists position text,
  add column if not exists image_url text,
  add column if not exists country text;
