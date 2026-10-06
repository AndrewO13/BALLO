-- Only the league creator may update seasons (including ending them).
-- Anonymous/guest sessions cannot.

revoke update on table public.seasons from anon;

drop policy if exists "league_owner_can_update_seasons" on public.seasons;
create policy "league_owner_can_update_seasons"
  on public.seasons
  for update
  to authenticated
  using (
    coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
    and exists (
      select 1
      from public.leagues l
      where l.id = seasons.league_id
        and l.created_by = auth.uid()
    )
  )
  with check (
    coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
    and exists (
      select 1
      from public.leagues l
      where l.id = seasons.league_id
        and l.created_by = auth.uid()
    )
  );
