alter table public.players
add column if not exists focus_ring_config jsonb;

update public.players
set focus_ring_config = jsonb_build_object(
  'primary_attribute', 'tackles',
  'targets', jsonb_build_object(
    'tackles', 10,
    'assists', 5,
    'clean_sheets', 3
  )
)
where focus_ring_config is null;

alter table public.players
alter column focus_ring_config set default jsonb_build_object(
  'primary_attribute', 'tackles',
  'targets', jsonb_build_object(
    'tackles', 10,
    'assists', 5,
    'clean_sheets', 3
  )
);

alter table public.players
alter column focus_ring_config set not null;

comment on column public.players.focus_ring_config is
'Authoritative cross-device focus ring preferences: primary metric and weekly targets.';
