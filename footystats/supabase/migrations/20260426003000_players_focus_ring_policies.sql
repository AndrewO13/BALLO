-- Policies for focus ring persistence in public.players.
-- Keep select open to authenticated users (existing app screens read other players).

drop policy if exists "players_select_authenticated" on public.players;
create policy "players_select_authenticated"
on public.players
for select
to authenticated
using (true);

drop policy if exists "players_insert_own" on public.players;
create policy "players_insert_own"
on public.players
for insert
to authenticated
with check (auth.uid() = id);

drop policy if exists "players_update_own" on public.players;
create policy "players_update_own"
on public.players
for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);
