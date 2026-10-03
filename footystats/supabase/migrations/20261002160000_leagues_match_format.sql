-- League match format used for Team of the Week (and future lineup defaults).
-- Formation is defenders→attackers and excludes the goalkeeper (e.g. 4-4-2).

alter table public.leagues
  add column if not exists players_per_side integer not null default 11;

alter table public.leagues
  add column if not exists default_formation text not null default '4-4-2';

alter table public.leagues
  drop constraint if exists leagues_players_per_side_check;

alter table public.leagues
  add constraint leagues_players_per_side_check
  check (players_per_side in (5, 6, 7, 8, 9, 11));

comment on column public.leagues.players_per_side is
  'Number of players a side, including the goalkeeper.';

comment on column public.leagues.default_formation is
  'Outfield shape from defenders to attackers, excluding GK. Example: 4-4-2.';
