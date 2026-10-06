-- Guests (anonymous auth) cannot follow or unfollow players.

drop policy if exists "user_follows_insert_own" on public.user_follows;
create policy "user_follows_insert_own"
  on public.user_follows
  for insert
  with check (
    auth.uid() = follower_user_id
    and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
    and exists (
      select 1
      from public.players p
      where p.id = following_user_id
        and p.deleted_at is null
    )
  );

drop policy if exists "user_follows_delete_own" on public.user_follows;
create policy "user_follows_delete_own"
  on public.user_follows
  for delete
  using (
    auth.uid() = follower_user_id
    and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
  );
