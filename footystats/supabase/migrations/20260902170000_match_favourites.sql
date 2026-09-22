-- Match favourites: per-user stars for guest (and signed-in) users.

create table if not exists public.match_favourites (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  sort_order integer not null default 0,
  user_id uuid not null references auth.users (id) on delete cascade,
  match_id uuid not null references public.matches (id) on delete cascade,
  constraint match_favourites_unique unique (user_id, match_id)
);

create index if not exists match_favourites_user_idx
  on public.match_favourites (user_id);

create index if not exists match_favourites_match_idx
  on public.match_favourites (match_id);

create index if not exists match_favourites_user_sort_idx
  on public.match_favourites (user_id, sort_order);

alter table public.match_favourites enable row level security;

drop policy if exists "match_favourites_select_own" on public.match_favourites;
create policy "match_favourites_select_own"
  on public.match_favourites
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "match_favourites_insert_own" on public.match_favourites;
create policy "match_favourites_insert_own"
  on public.match_favourites
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "match_favourites_delete_own" on public.match_favourites;
create policy "match_favourites_delete_own"
  on public.match_favourites
  for delete
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "match_favourites_update_own" on public.match_favourites;
create policy "match_favourites_update_own"
  on public.match_favourites
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
