-- Guests (anonymous auth) cannot apply a team to a league or insert memberships.

revoke insert on table public.league_team_join_requests from anon;
revoke insert on table public.league_team_memberships from anon;

drop policy if exists "team_owner_can_apply_to_league"
  on public.league_team_join_requests;
create policy "team_owner_can_apply_to_league"
  on public.league_team_join_requests
  for insert
  to authenticated
  with check (
    coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
    and requested_by = auth.uid()
    and exists (
      select 1
      from public.teams t
      where t.id = league_team_join_requests.team_id
        and t.created_by = auth.uid()
    )
  );

drop policy if exists "league_owner_can_insert_memberships"
  on public.league_team_memberships;
create policy "league_owner_can_insert_memberships"
  on public.league_team_memberships
  for insert
  to authenticated
  with check (
    coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
    and exists (
      select 1
      from public.leagues l
      where l.id = league_team_memberships.league_id
        and l.created_by = auth.uid()
    )
  );
