-- players.image_url had a legacy column default of 'Lefters.png'. That string is
-- not a URL, a bundled asset path, or an avatar name, so every player who never
-- picked an avatar ended up with an image the app tried to load via
-- Image.asset('Lefters.png') -> 404 ("Unable to load asset: Lefters.png").
--
-- Drop the default and clear the bogus value so the app falls back to its
-- placeholder avatar instead.

alter table public.players
  alter column image_url drop default;

update public.players
set image_url = null
where image_url = 'Lefters.png';
