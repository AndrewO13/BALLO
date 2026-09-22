-- Snapshot team squad layouts on matches for the fixture Line-ups tab.
-- Lineups sync from teams.squad_layout while status = 'upcoming' only.

alter table public.matches
  add column if not exists team_a_lineup jsonb,
  add column if not exists team_b_lineup jsonb;

comment on column public.matches.team_a_lineup is
  'Frozen/copy of home team squad_layout for this match. Synced while status is upcoming.';
comment on column public.matches.team_b_lineup is
  'Frozen/copy of away team squad_layout for this match. Synced while status is upcoming.';

create or replace function public.initialize_match_lineups_on_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_team_a_layout jsonb;
  v_team_b_layout jsonb;
begin
  if new."teamA" is not null then
    select t.squad_layout into v_team_a_layout
    from public.teams t
    where t.id = new."teamA";
    new.team_a_lineup := coalesce(v_team_a_layout, '{}'::jsonb);
  end if;

  if new."teamB" is not null then
    select t.squad_layout into v_team_b_layout
    from public.teams t
    where t.id = new."teamB";
    new.team_b_lineup := coalesce(v_team_b_layout, '{}'::jsonb);
  end if;

  return new;
end;
$$;

drop trigger if exists matches_initialize_lineups on public.matches;

create trigger matches_initialize_lineups
before insert on public.matches
for each row
execute function public.initialize_match_lineups_on_insert();

create or replace function public.sync_team_squad_layout_to_matches()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.matches
  set team_a_lineup = new.squad_layout
  where "teamA" = new.id
    and status = 'upcoming';

  update public.matches
  set team_b_lineup = new.squad_layout
  where "teamB" = new.id
    and status = 'upcoming';

  return new;
end;
$$;

drop trigger if exists teams_sync_match_lineups on public.teams;

create trigger teams_sync_match_lineups
after update of squad_layout on public.teams
for each row
when (old.squad_layout is distinct from new.squad_layout)
execute function public.sync_team_squad_layout_to_matches();

-- Backfill upcoming fixtures that pre-date this migration.
update public.matches m
set team_a_lineup = t.squad_layout
from public.teams t
where m."teamA" = t.id
  and m.status = 'upcoming'
  and (m.team_a_lineup is null or m.team_a_lineup = '{}'::jsonb)
  and t.squad_layout is not null
  and t.squad_layout <> '{}'::jsonb;

update public.matches m
set team_b_lineup = t.squad_layout
from public.teams t
where m."teamB" = t.id
  and m.status = 'upcoming'
  and (m.team_b_lineup is null or m.team_b_lineup = '{}'::jsonb)
  and t.squad_layout is not null
  and t.squad_layout <> '{}'::jsonb;
