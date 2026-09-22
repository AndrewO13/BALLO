-- Restrict matches INSERT/UPDATE/DELETE to the league creator.
-- SELECT policies are unchanged (public read + authenticated select).

alter table public.matches enable row level security;

drop policy if exists "matches_authenticated_insert" on public.matches;
drop policy if exists "matches_authenticated_update" on public.matches;
drop policy if exists "matches_authenticated_delete" on public.matches;

create policy "matches_authenticated_insert"
  on public.matches
  for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.leagues l
      where l.id = league_id
        and l.created_by = auth.uid()
    )
  );

create policy "matches_authenticated_update"
  on public.matches
  for update
  to authenticated
  using (
    exists (
      select 1
      from public.leagues l
      where l.id = matches.league_id
        and l.created_by = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from public.leagues l
      where l.id = league_id
        and l.created_by = auth.uid()
    )
  );

create policy "matches_authenticated_delete"
  on public.matches
  for delete
  to authenticated
  using (
    exists (
      select 1
      from public.leagues l
      where l.id = matches.league_id
        and l.created_by = auth.uid()
    )
  );
