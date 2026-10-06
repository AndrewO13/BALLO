-- Guests (anonymous auth) cannot request to join a team or insert memberships.

drop policy if exists "Enable insert for authenticated users only"
  on public.team_join_requests;
drop policy if exists "Players can request to join a team"
  on public.team_join_requests;
create policy "Players can request to join a team"
  on public.team_join_requests
  for insert
  with check (
    player_id = auth.uid()
    and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
  );

drop policy if exists "Enable insert for authenticated users only"
  on public.player_team_memberships;
create policy "Enable insert for authenticated users only"
  on public.player_team_memberships
  for insert
  with check (
    coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
  );
