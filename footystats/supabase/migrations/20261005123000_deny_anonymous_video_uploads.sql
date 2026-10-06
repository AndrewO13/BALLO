-- Guests use anonymous auth (authenticated role + is_anonymous JWT claim).
-- They must not insert/update/delete match clips or Match videos storage objects.

drop policy if exists "Authenticated users can insert their own videos"
  on public.videos;
create policy "Authenticated users can insert their own videos"
  on public.videos
  for insert
  with check (
    uploader_user_id = auth.uid()
    and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
  );

drop policy if exists "Uploaders can update their own videos"
  on public.videos;
create policy "Uploaders can update their own videos"
  on public.videos
  for update
  using (
    uploader_user_id = auth.uid()
    and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
  )
  with check (
    uploader_user_id = auth.uid()
    and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
  );

drop policy if exists "Uploaders can delete their own videos"
  on public.videos;
create policy "Uploaders can delete their own videos"
  on public.videos
  for delete
  using (
    uploader_user_id = auth.uid()
    and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
  );

drop policy if exists "Authenticated users can upload to Match videos"
  on storage.objects;
create policy "Authenticated users can upload to Match videos"
  on storage.objects
  for insert
  with check (
    bucket_id = 'Match videos'
    and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
  );

drop policy if exists "Authenticated users can upload to match-videos"
  on storage.objects;
create policy "Authenticated users can upload to match-videos"
  on storage.objects
  for insert
  with check (
    bucket_id = 'match-videos'
    and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
  );

drop policy if exists "Users can update their own files in Match videos"
  on storage.objects;
create policy "Users can update their own files in Match videos"
  on storage.objects
  for update
  using (
    bucket_id = 'Match videos'
    and owner = auth.uid()
    and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
  )
  with check (
    bucket_id = 'Match videos'
    and owner = auth.uid()
    and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
  );

drop policy if exists "Users can update their own files in match-videos"
  on storage.objects;
create policy "Users can update their own files in match-videos"
  on storage.objects
  for update
  using (
    bucket_id = 'match-videos'
    and owner = auth.uid()
    and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
  )
  with check (
    bucket_id = 'match-videos'
    and owner = auth.uid()
    and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
  );

drop policy if exists "Users can delete their own files in Match videos"
  on storage.objects;
create policy "Users can delete their own files in Match videos"
  on storage.objects
  for delete
  using (
    bucket_id = 'Match videos'
    and owner = auth.uid()
    and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
  );

drop policy if exists "Users can delete their own files in match-videos"
  on storage.objects;
create policy "Users can delete their own files in match-videos"
  on storage.objects
  for delete
  using (
    bucket_id = 'match-videos'
    and owner = auth.uid()
    and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
  );
