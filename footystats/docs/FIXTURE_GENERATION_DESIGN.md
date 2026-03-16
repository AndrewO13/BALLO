# Fixture Generation Design

## 1. Algorithm: Circle Method (Round-Robin)

**Why circle method:**
- Guarantees each team plays every other team exactly once per leg
- Produces exactly one match per team per gameweek (no team plays twice in same GW)
- Handles odd numbers via BYE (one team sits out each gameweek)
- Simple rotation: fix one team, rotate others in a circle
- O(n) per gameweek, O(n²) total pairs — optimal for fixture generation

**How it works:**
1. Place teams in a circle. Fix team 0.
2. Each round: pair team 0 with last team, then (1,n-2), (2,n-3), etc.
3. Rotate all except team 0 clockwise. Repeat for n-1 rounds (odd n) or n rounds (even n).
4. For even n: n/2 matches per round, (n-1) rounds per leg.
5. For odd n: add BYE; (n-1)/2 matches per round, n rounds per leg.

---

## 2. Step-by-Step Logic

### 2.1 Fetch teams from league_team_memberships
```
1. Get season by season_id
2. Verify season exists and league_id matches
3. Query league_team_memberships WHERE league_id = season.league_id AND end_date IS NULL
4. Select DISTINCT team_id (no duplicates)
5. Validate all team_ids exist in teams table
```

### 2.2 Validation (before generation)
```
- team_count >= 2
- all teams belong to same league (league_id from memberships = season.league_id)
- season exists
- IF allowRegenerate == false: count(matches where season_id = X) == 0
- no duplicate team entries (use Set)
- no pair where teamA == teamB (algorithm prevents this)
- no team plays twice in same gameweek (algorithm guarantees this)
- no duplicate pairings in same leg (algorithm guarantees this)
```

### 2.3 Gameweek formation
```
gameweeks_per_leg = (n even) ? (n-1) : n
total_gameweeks = legs * gameweeks_per_leg  // legs = 1 or 2

For each gameweek 1..total_gameweeks:
  - Create gameweek row: season_id, week = gameweek_number
  - Assign matches to this gameweek
  - Schedule dates: first_gw_date + (gw_num - 1) * interval_days
  - Schedule times: distribute evenly if same-day window
```

### 2.4 Fixture creation (circle method)
```
teams = [t0, t1, ..., tn-1]
if odd: teams = [t0, t1, ..., tn-1, BYE]

for leg in 1..legs:
  for round in 0..(num_rounds - 1):
    matches = []
    for i in 0..(num_matches_per_round - 1):
      home = teams[i]
      away = teams[n - 1 - i]
      if home != BYE and away != BYE:
        if home_away_enabled and leg == 2:
          matches.add((away, home))  // reverse
        else:
          matches.add((home, away))
    append matches to gameweek
    rotate(teams[1..n-1])  // fix teams[0], rotate rest
```

### 2.5 Date/time assignment
```
- Same-day: distribute N matches between start_time and end_time evenly
- Multi-day: spread matches across gw_date..(gw_date + day_span - 1)
- Compressed: all matches in 1-3 days based on window
```

### 2.6 BYE handling
- BYE is in-memory only, never inserted into DB
- Team with BYE simply has no match in that gameweek
- Round still produces (n-1)/2 matches for odd n

### 2.7 Double-leg
- After first leg completes, repeat pairs with home/away reversed
- Gameweek numbers continue (e.g. GW1–GW9 first leg, GW10–GW18 second leg)

---

## 3. Scheduling Modes

| Mode | Interval | Matches per GW | Same-day |
|------|----------|----------------|----------|
| Weekly | 7 days | 1 per team | Optional |
| Biweekly | 14 days | 1 per team | Optional |
| Twice per week | 4 days (e.g. Mon–Tue, Fri–Sun) | 1 per team | Often yes |
| Compressed | 1–3 days total | All in window | Yes |

Same engine, different inputs: `gameweek_interval_days`, `same_day_matches`, `compressed_days`.

---

## 4. Database Execution Strategy

**Recommendation: App-side logic (Flutter + Supabase client)**

**Why:**
- Complex scheduling logic is easier to iterate in Dart
- Validation and error messages can be rich and UI-friendly
- No need to deploy Postgres functions for every change
- Transactional safety: use Supabase batch/transaction if available, or sequential inserts with rollback on failure
- RLS already protects writes; app acts as league admin

**Alternative:** Postgres RPC if you need:
- Very large leagues (100+ teams)
- Server-triggered generation (cron, webhooks)
- Stricter audit trail in DB

For typical league sizes (4–20 teams), app-side is best.

---

## 5. Pseudo-code

```
FUNCTION generateFixtures(options):
  teams = fetchActiveTeams(options.seasonId)
  VALIDATE teams, season, no existing matches
  pairs = circleMethod(teams, options.doubleLeg, options.homeAway)
  gameweeks = groupPairsIntoGameweeks(pairs)
  FOR each gw in gameweeks:
    create gameweek row
    FOR each match in gw.matches:
      assign date, time, venue
      create match row
  RETURN result
```

---

## 6. SQL / Transaction Outline

```sql
BEGIN;
  -- 1. Insert gameweeks
  INSERT INTO gameweeks (season_id, week) VALUES (...), (...);
  -- 2. Insert matches (with gameweek FK from step 1)
  INSERT INTO matches (season_id, league_id, gameweek, match_date, match_time, venue, teamA, teamB, status) VALUES (...);
COMMIT;
```

Supabase Dart: use `_client.rpc()` for a custom function, or sequential inserts. Supabase does not expose multi-statement transactions from the client; use a single RPC that runs in a transaction, or accept sequential inserts (less safe on partial failure).

---

## 7. Regeneration Protection

- Before generating: `SELECT COUNT(*) FROM matches WHERE season_id = ?`
- If count > 0 and `allowRegenerate` is false → abort with error
- If `allowRegenerate` is true: require explicit user confirmation, then:
  - DELETE FROM matches WHERE season_id = ?
  - DELETE FROM gameweeks WHERE season_id = ?
  - Then run generation

---

## 8. Flutter Wiring

1. **Autogenerate dialog** collects all inputs (season, format, dates, times, etc.)
2. **FixtureGenerationOptions** model holds inputs
3. **MatchesRepository.generateFixtures(options)** validates, runs algorithm, inserts
4. **FixtureGenerationResult** returned: teamsCount, gameweeksCreated, matchesCreated, usedBye, success
5. On success: invalidate matchesProvider, show snackbar, optionally pop/navigate
6. On failure: show SnackBar with error message

---

## 9. Edge Cases

| Case | Handling |
|------|----------|
| 2 teams | 1 match per leg, 1 or 2 gameweeks |
| Odd teams | BYE in memory; (n-1)/2 matches per GW |
| Same-day full round | Distribute times between start/end |
| No home/away | Ignore home/away; pairs are unordered |
| Double-leg | Second leg reverses home/away |
| Compressed | All matches in 1–3 days |
| Already generated | Block unless allowRegenerate + confirm |

---

## 10. Output Structure

```dart
class FixtureGenerationResult {
  final int teamsCount;
  final int gameweeksCreated;
  final int matchesCreated;
  final bool usedBye;
  final bool success;
  final String? errorMessage;
}
```
