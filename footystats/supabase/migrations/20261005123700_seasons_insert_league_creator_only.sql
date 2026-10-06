-- Only the league creator may insert seasons. Anonymous/guest sessions cannot.

revoke insert on table public.seasons from anon;

drop policy if exists "league_owner_can_insert_seasons" on public.seasons;
create policy "league_owner_can_insert_seasons"
  on public.seasons
  for insert
  to authenticated
  with check (
    coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
    and exists (
      select 1
      from public.leagues l
      where l.id = seasons.league_id
        and l.created_by = auth.uid()
    )
  );
