-- Single-row overall leaderboard rank lookup for a player.
-- Replaces the client downloading the whole leaderboard (up to 500 rows via
-- get_leaderboard) just to find one player's position.
-- Ranking logic must stay in sync with public.get_leaderboard (overall mode):
-- total_points = match fantasy points + earned profile badge bonuses,
-- ordered by total_points desc, player_name asc.

create or replace function public.get_player_rank(p_player_id uuid)
returns bigint
language sql
stable
security definer
set search_path = public
as $$
with global_totals as (
  select
    v.player_id,
    sum(v.match_points)::double precision as match_points
  from public.v_player_match_points v
  group by v.player_id
),
leaderboard_core as (
  select
    g.player_id,
    coalesce(p.player_name, '')::text as player_name,
    (
      g.match_points + public.player_badge_bonus_points(g.player_id)
    ) as total_points
  from global_totals g
  inner join public.players p on p.id = g.player_id
),
ranked as (
  select
    lc.player_id,
    row_number() over (
      order by lc.total_points desc nulls last, lc.player_name asc
    )::bigint as board_rank
  from leaderboard_core lc
)
select r.board_rank
from ranked r
where r.player_id = p_player_id;
$$;

grant execute on function public.get_player_rank(uuid) to authenticated;

comment on function public.get_player_rank(uuid) is
  'Overall leaderboard rank (1-based) for one player, or null if the player has no scored matches. Mirrors get_leaderboard overall ordering.';
