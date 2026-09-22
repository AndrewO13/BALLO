-- Add timestamp columns to matches table for server-synced timer
-- This ensures all clients see the same match time regardless of local device clocks

-- Migration: Add match timing columns
-- Purpose: Enable server-side match time synchronization across all clients

alter table matches
  add column if not exists started_at timestamptz,
  add column if not exists halftime_paused_at timestamptz,
  add column if not exists resumed_from_halftime_at timestamptz,
  add column if not exists half_duration_minutes int,
  add column if not exists total_paused_duration_seconds int not null default 0;

-- Add comments for clarity
comment on column matches.started_at is 
  'Timestamp when match status changed to "ongoing". Used to calculate elapsed match time.';
comment on column matches.halftime_paused_at is 
  'Timestamp when match entered halftime (status = "halfTime"). Used to track pause start.';
comment on column matches.resumed_from_halftime_at is 
  'Timestamp when match resumed from halftime. Used to calculate pause duration.';
comment on column matches.half_duration_minutes is 
  'Configured minutes per half for the synced match timer pill and stoppage-time threshold.';
comment on column matches.total_paused_duration_seconds is 
  'Cumulative seconds paused during match (e.g., halftime pause). Added to started_at to calculate real elapsed time.';

-- Index on started_at for faster queries when calculating clock times
create index if not exists idx_matches_started_at on matches(started_at);
create index if not exists idx_matches_status on matches(status);
