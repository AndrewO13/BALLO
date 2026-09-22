-- Remove league-level date windows and derive season date windows from matches.

alter table public.leagues
  drop column if exists start_date,
  drop column if exists end_date;

alter table public.seasons
  alter column start_date drop not null,
  alter column end_date drop not null;

create or replace function public.refresh_season_match_bounds(p_season_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_start date;
  v_end date;
begin
  if p_season_id is null then
    return;
  end if;

  select
    min(m.match_date::date),
    max(m.match_date::date)
  into v_start, v_end
  from public.matches m
  where m.season_id = p_season_id;

  update public.seasons s
  set
    start_date = v_start,
    end_date = v_end
  where s.id = p_season_id;
end;
$$;

create or replace function public.handle_matches_refresh_season_bounds()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    perform public.refresh_season_match_bounds(old.season_id);
    return old;
  end if;

  if tg_op = 'UPDATE' and old.season_id is distinct from new.season_id then
    perform public.refresh_season_match_bounds(old.season_id);
  end if;

  perform public.refresh_season_match_bounds(new.season_id);
  return new;
end;
$$;

drop trigger if exists trg_matches_refresh_season_bounds on public.matches;

create trigger trg_matches_refresh_season_bounds
after insert or update of season_id, match_date or delete
on public.matches
for each row
execute function public.handle_matches_refresh_season_bounds();

-- Backfill existing seasons from already created matches.
do $$
declare
  v_season_id uuid;
begin
  for v_season_id in
    select distinct m.season_id
    from public.matches m
    where m.season_id is not null
  loop
    perform public.refresh_season_match_bounds(v_season_id);
  end loop;
end;
$$;
