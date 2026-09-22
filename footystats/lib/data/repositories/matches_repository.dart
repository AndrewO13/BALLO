import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/fixture_generation_options.dart';
import '../../domain/models/fixture_generation_result.dart';
import '../../domain/models/match_model.dart';
import '../../domain/models/fixture_match_rated_player.dart';
import '../../domain/models/match_team_stats_snapshot.dart';
import '../../domain/services/fixture_generator.dart';

/// Fetches matches from Supabase matches table with teamA/teamB embedded.
/// Table columns: id, created_at, match_date, match_time, status, teamA_score,
/// teamB_score, teamA, teamB, gameweek. Teams: id, logo_id, short_form, team_name.
class MatchesRepository {
  MatchesRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Fetches a single match by id with teamA/teamB embedded.
  Future<MatchModel?> getMatchById(String id) async {
    if (id.isEmpty) return null;
    try {
      final res = await _client
          .from('matches')
          .select('''
        id, match_date, match_time, status, teamA_score, teamB_score, venue_image_url, league_id,
        half_duration_minutes,
        gameweek:gameweeks(week),
        league:leagues(league_name, country, logo_id),
        teamA:teams!teamA(id, logo_id, short_form, team_name),
        teamB:teams!teamB(id, logo_id, short_form, team_name)
      ''')
          .eq('id', id)
          .maybeSingle();
      if (res == null) return null;
      return MatchModel.fromJson(Map<String, dynamic>.from(res));
    } catch (_) {
      final fallback = await _client
          .from('matches')
          .select(
            'id, match_date, match_time, status, teamA, teamB, '
            'teamA_score, teamB_score, gameweek, league_id, venue_image_url, '
            'half_duration_minutes',
          )
          .eq('id', id)
          .maybeSingle();
      if (fallback == null) return null;
      final list = await _matchesWithTeamsFetched([
        Map<String, dynamic>.from(fallback),
      ]);
      return list.isNotEmpty ? list.single : null;
    }
  }

  /// Returns Monday 00:00:00 and Sunday 23:59:59 of the current week.
  static (DateTime, DateTime) _thisWeekRange() {
    final now = DateTime.now();
    final weekday = now.weekday; // 1=Mon, 7=Sun
    final monday = DateTime(now.year, now.month, now.day - (weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    final sundayEnd = DateTime(
      sunday.year,
      sunday.month,
      sunday.day,
      23,
      59,
      59,
    );
    return (monday, sundayEnd);
  }

  /// Fetches matches whose match_date falls within this week (Mon–Sun).
  /// Includes league name from leagues table. Matches table must have league_id.
  Future<List<MatchModel>> getMatchesThisWeek() async {
    final (monday, sundayEnd) = _thisWeekRange();
    final mondayStr = monday.toIso8601String().split('T').first;
    final sundayStr = sundayEnd.toIso8601String().split('T').first;

    try {
      final res = await _client
          .from('matches')
          .select('''
        id, match_date, match_time, status, teamA_score, teamB_score, venue_image_url, league_id,
        gameweek:gameweeks(week),
        league:leagues(league_name, country, logo_id),
        teamA:teams!teamA(id, logo_id, short_form, team_name),
        teamB:teams!teamB(id, logo_id, short_form, team_name)
      ''')
          .gte('match_date', mondayStr)
          .lte('match_date', sundayStr)
          .order('match_date', ascending: true)
          .order('match_time', ascending: true);
      final list = List<Map<String, dynamic>>.from(res as List);
      return list.map((e) => MatchModel.fromJson(e)).toList();
    } catch (_) {
      final fallback = await _client
          .from('matches')
          .select(
            'id, match_date, match_time, status, teamA, teamB, '
            'teamA_score, teamB_score, gameweek, league_id, venue_image_url',
          )
          .gte('match_date', mondayStr)
          .lte('match_date', sundayStr)
          .order('match_date', ascending: true)
          .order('match_time', ascending: true);
      final list = List<Map<String, dynamic>>.from(fallback as List);
      return _matchesThisWeekWithRelations(list);
    }
  }

  Future<List<MatchModel>> _matchesThisWeekWithRelations(
    List<Map<String, dynamic>> rows,
  ) async {
    final teamIds = <String>{};
    final leagueIds = <String>{};
    final gameweekIds = <String>{};
    for (final r in rows) {
      for (final k in ['teamA', 'teamB']) {
        final v = r[k]?.toString();
        if (v != null && v.isNotEmpty) teamIds.add(v);
      }
      final lid = r['league_id']?.toString();
      if (lid != null && lid.isNotEmpty) leagueIds.add(lid);
      final gwid = r['gameweek']?.toString();
      if (gwid != null && gwid.isNotEmpty) gameweekIds.add(gwid);
    }

    final teamsMap = <String, Map<String, dynamic>>{};
    if (teamIds.isNotEmpty) {
      final teamsRes = await _client
          .from('teams')
          .select('id, logo_id, short_form, team_name')
          .inFilter('id', teamIds.toList());
      for (final t in List<Map<String, dynamic>>.from(teamsRes as List)) {
        final id = t['id']?.toString();
        if (id != null) teamsMap[id] = t;
      }
    }

    final leaguesMap = <String, Map<String, String>>{};
    if (leagueIds.isNotEmpty) {
      final leaguesRes = await _client
          .from('leagues')
          .select('id, league_name, country, logo_id')
          .inFilter('id', leagueIds.toList());
      for (final l in List<Map<String, dynamic>>.from(leaguesRes as List)) {
        final id = l['id']?.toString();
        if (id != null) {
          leaguesMap[id] = {
            'league_name': l['league_name']?.toString() ?? '—',
            'country': l['country']?.toString() ?? '',
            'logo_id': l['logo_id']?.toString() ?? '',
          };
        }
      }
    }

    final gameweeksMap = <String, int>{};
    if (gameweekIds.isNotEmpty) {
      final gwsRes = await _client
          .from('gameweeks')
          .select('id, week')
          .inFilter('id', gameweekIds.toList());
      for (final g in List<Map<String, dynamic>>.from(gwsRes as List)) {
        final id = g['id']?.toString();
        final week = int.tryParse(g['week']?.toString() ?? '');
        if (id != null && week != null) gameweeksMap[id] = week;
      }
    }

    return rows.map((row) {
      final json = Map<String, dynamic>.from(row);
      json['teamA'] = teamsMap[row['teamA']?.toString() ?? ''];
      json['teamB'] = teamsMap[row['teamB']?.toString() ?? ''];
      final lid = row['league_id']?.toString();
      if (lid != null) {
        json['league'] = leaguesMap[lid] ??
            {'league_name': '—', 'country': '', 'logo_id': ''};
      }
      final gwid = row['gameweek']?.toString();
      if (gwid != null) json['gameweek'] = {'week': gameweeksMap[gwid]};
      return MatchModel.fromJson(json);
    }).toList();
  }

  /// Fetches matches ordered by date and time.
  /// Filters by participation: leagueIds, seasonIds, gameweekId, teamIds (matches
  /// where teamA or teamB is in teamIds). RLS already restricts to user's matches.
  ///
  /// [fromDate]/[toDate] bound the fetch to a date window and [limit] caps the
  /// row count, so callers avoid downloading a full multi-season history.
  Future<List<MatchModel>> getMatches({
    String? gameweek,
    List<String>? leagueIds,
    List<String>? seasonIds,
    List<String>? teamIds,
    DateTime? fromDate,
    DateTime? toDate,
    int? limit,
    bool ascending = true,
  }) async {
    final fromDateStr = fromDate?.toIso8601String().split('T').first;
    final toDateStr = toDate?.toIso8601String().split('T').first;
    List<Map<String, dynamic>> list;
    try {
      var query = _client.from('matches').select('''
        id, match_date, match_time, status, teamA_score, teamB_score, venue_image_url, league_id,
        gameweek:gameweeks(week),
        league:leagues(league_name, country, logo_id),
        teamA:teams!teamA(id, logo_id, short_form, team_name),
        teamB:teams!teamB(id, logo_id, short_form, team_name)
      ''');
      if (gameweek != null && gameweek.isNotEmpty) {
        query = query.eq('gameweek', gameweek);
      }
      if (leagueIds != null && leagueIds.isNotEmpty) {
        query = query.inFilter('league_id', leagueIds);
      }
      if (seasonIds != null && seasonIds.isNotEmpty) {
        query = query.inFilter('season_id', seasonIds);
      }
      if (fromDateStr != null) {
        query = query.gte('match_date', fromDateStr);
      }
      if (toDateStr != null) {
        query = query.lte('match_date', toDateStr);
      }
      if (teamIds != null && teamIds.isNotEmpty) {
        query = query.or(
          'teamA.in.(${teamIds.join(',')}),teamB.in.(${teamIds.join(',')})',
        );
      }
      var ordered = query
          .order('match_date', ascending: ascending)
          .order('match_time', ascending: ascending);
      if (limit != null && limit > 0) {
        ordered = ordered.limit(limit);
      }
      final res = await ordered;
      list = List<Map<String, dynamic>>.from(res as List);
      if (teamIds != null && teamIds.isNotEmpty) {
        final teamSet = teamIds.toSet();
        list = list.where((r) {
          final a = r['teamA'];
          final b = r['teamB'];
          final aId = a is Map ? a['id']?.toString() : a?.toString();
          final bId = b is Map ? b['id']?.toString() : b?.toString();
          return teamSet.contains(aId) || teamSet.contains(bId);
        }).toList();
      }
    } catch (_) {
      var fallback = _client
          .from('matches')
          .select(
            'id, match_date, match_time, status, teamA, teamB, '
            'teamA_score, teamB_score, gameweek, league_id, season_id, venue_image_url',
          );
      if (gameweek != null && gameweek.isNotEmpty) {
        fallback = fallback.eq('gameweek', gameweek);
      }
      if (leagueIds != null && leagueIds.isNotEmpty) {
        fallback = fallback.inFilter('league_id', leagueIds);
      }
      if (seasonIds != null && seasonIds.isNotEmpty) {
        fallback = fallback.inFilter('season_id', seasonIds);
      }
      if (fromDateStr != null) {
        fallback = fallback.gte('match_date', fromDateStr);
      }
      if (toDateStr != null) {
        fallback = fallback.lte('match_date', toDateStr);
      }
      if (teamIds != null && teamIds.isNotEmpty) {
        fallback = fallback.or(
          'teamA.in.(${teamIds.join(',')}),teamB.in.(${teamIds.join(',')})',
        );
      }
      var orderedFallback = fallback
          .order('match_date', ascending: ascending)
          .order('match_time', ascending: ascending);
      if (limit != null && limit > 0) {
        orderedFallback = orderedFallback.limit(limit);
      }
      final res = await orderedFallback;
      list = List<Map<String, dynamic>>.from(res as List);
      if (teamIds != null && teamIds.isNotEmpty) {
        final teamSet = teamIds.toSet();
        list = list.where((r) {
          final aId = r['teamA']?.toString();
          final bId = r['teamB']?.toString();
          return teamSet.contains(aId) || teamSet.contains(bId);
        }).toList();
      }
      return _matchesWithTeamsFetched(list);
    }

    return list.map((e) => MatchModel.fromJson(e)).toList();
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Next upcoming / live fixture without downloading full history.
  Future<MatchModel?> getNextUpcomingMatch({
    List<String>? teamIds,
    List<String>? leagueIds,
  }) async {
    final matches = await getMatches(
      teamIds: teamIds,
      leagueIds: leagueIds,
      fromDate: _today(),
      limit: 20,
    );
    final live = matches.where(
      (m) =>
          m.status == MatchStatus.ongoing || m.status == MatchStatus.halfTime,
    );
    if (live.isNotEmpty) return live.first;
    final upcoming = matches.where((m) => m.status == MatchStatus.upcoming);
    if (upcoming.isNotEmpty) return upcoming.first;
    return matches.isEmpty ? null : matches.first;
  }

  /// Most recent completed results, newest first.
  Future<List<MatchModel>> getRecentCompletedMatches({
    List<String>? teamIds,
    List<String>? leagueIds,
    int limit = 6,
  }) async {
    final matches = await getMatches(
      teamIds: teamIds,
      leagueIds: leagueIds,
      toDate: _today(),
      limit: limit * 4,
      ascending: false,
    );
    return matches
        .where(
          (m) =>
              m.status == MatchStatus.fullTime &&
              m.teamAScore != null &&
              m.teamBScore != null,
        )
        .take(limit)
        .toList();
  }

  /// [playedCount]: `fullTime` matches. [totalCount]: all fixtures for league + season.
  Future<SeasonFixtureProgress> getSeasonFixtureProgress({
    required String leagueId,
    required String seasonId,
  }) async {
    if (leagueId.isEmpty || seasonId.isEmpty) {
      return const SeasonFixtureProgress(playedCount: 0, totalCount: 0);
    }
    final res = await _client
        .from('matches')
        .select('status')
        .eq('league_id', leagueId)
        .eq('season_id', seasonId);
    final rows = List<Map<String, dynamic>>.from(res as List);
    var played = 0;
    for (final r in rows) {
      if (r['status']?.toString() == 'fullTime') {
        played++;
      }
    }
    return SeasonFixtureProgress(playedCount: played, totalCount: rows.length);
  }

  /// Gets or creates a gameweek for the given season and week number.
  /// Returns the gameweek id.
  Future<String> getOrCreateGameweek({
    required String seasonId,
    required int week,
  }) async {
    final existing = await _client
        .from('gameweeks')
        .select('id')
        .eq('season_id', seasonId)
        .eq('week', week)
        .maybeSingle();
    if (existing != null) {
      return existing['id']?.toString() ?? '';
    }
    final res = await _client
        .from('gameweeks')
        .insert({'season_id': seasonId, 'week': week})
        .select('id')
        .single();
    return res['id']?.toString() ?? '';
  }

  /// Creates a single match. Returns the new match id.
  Future<String> createMatch({
    required String leagueId,
    required String seasonId,
    required String teamAId,
    required String teamBId,
    required DateTime matchDate,
    required String matchTime,
    required String venue,
    String? venueImageUrl,
    required String gameweekId,
  }) async {
    final dateStr = matchDate.toIso8601String().split('T').first;
    final data = <String, dynamic>{
      'league_id': leagueId,
      'season_id': seasonId,
      'teamA': teamAId,
      'teamB': teamBId,
      'match_date': dateStr,
      'match_time': matchTime,
      'venue': venue,
      'gameweek': gameweekId,
    };
    if (venueImageUrl != null && venueImageUrl.isNotEmpty) {
      data['venue_image_url'] = venueImageUrl;
    }
    final res = await _client
        .from('matches')
        .insert(data)
        .select('id')
        .single();
    return res['id']?.toString() ?? '';
  }

  /// Fetches active team IDs from league_team_memberships (end_date IS NULL).
  Future<List<String>> _getActiveTeamIdsForLeague(String leagueId) async {
    final res = await _client
        .from('league_team_memberships')
        .select('team_id, end_date')
        .eq('league_id', leagueId);
    final list = List<Map<String, dynamic>>.from(res as List);
    final ids = <String>{};
    for (final row in list) {
      if (row['end_date'] == null) {
        final id = row['team_id']?.toString();
        if (id != null && id.isNotEmpty) ids.add(id);
      }
    }
    return ids.toList();
  }

  /// Generates fixtures using round-robin algorithm. Creates gameweeks and matches.
  Future<FixtureGenerationResult> generateFixtures(
    FixtureGenerationOptions options,
  ) async {
    final seasonRes = await _client
        .from('seasons')
        .select('id, league_id')
        .eq('id', options.seasonId)
        .maybeSingle();
    if (seasonRes == null) {
      return FixtureGenerationResult.failure('Season not found');
    }
    final seasonLeagueId = seasonRes['league_id']?.toString() ?? '';
    if (seasonLeagueId.isEmpty || seasonLeagueId != options.leagueId) {
      return FixtureGenerationResult.failure(
        'Season does not belong to this league',
      );
    }

    final teamIds = await _getActiveTeamIdsForLeague(options.leagueId);
    if (teamIds.length < 2) {
      return FixtureGenerationResult.failure(
        'Need at least 2 active teams (end_date IS NULL) in the league',
      );
    }

    final existing = await _client
        .from('matches')
        .select('id')
        .eq('season_id', options.seasonId)
        .limit(1);
    final hasExisting = (existing as List).isNotEmpty;
    if (hasExisting && !options.allowRegeneration) {
      return FixtureGenerationResult.failure(
        'Season already has fixtures. Enable "Allow regeneration" to replace.',
      );
    }

    if (options.allowRegeneration && hasExisting) {
      await _client.from('matches').delete().eq('season_id', options.seasonId);
      await _client
          .from('gameweeks')
          .delete()
          .eq('season_id', options.seasonId);
    }

    final gameweeks = FixtureGenerator.generate(
      teamIds: teamIds,
      options: options,
    );
    if (gameweeks.isEmpty) {
      return FixtureGenerationResult.failure('No fixtures generated');
    }

    final gameweekIds = <int, String>{};
    for (final gw in gameweeks) {
      final res = await _client
          .from('gameweeks')
          .insert({'season_id': options.seasonId, 'week': gw.weekNumber})
          .select('id')
          .single();
      gameweekIds[gw.weekNumber] = res['id']?.toString() ?? '';
    }

    var matchesCreated = 0;
    final venue = options.defaultVenue ?? 'TBD';
    for (final gw in gameweeks) {
      final gwId = gameweekIds[gw.weekNumber];
      if (gwId == null || gwId.isEmpty) continue;
      for (final m in gw.matches) {
        final dateStr = m.matchDate.toIso8601String().split('T').first;
        await _client.from('matches').insert({
          'season_id': options.seasonId,
          'league_id': options.leagueId,
          'gameweek': gwId,
          'match_date': dateStr,
          'match_time': m.matchTime,
          'venue': venue,
          'venue_image_url': options.defaultVenueImageUrl,
          'teamA': m.teamA,
          'teamB': m.teamB,
          'status': options.defaultStatus,
        });
        matchesCreated++;
      }
    }

    final usedBye = teamIds.length.isOdd;
    return FixtureGenerationResult.success(
      teamsCount: teamIds.length,
      gameweeksCreated: gameweeks.length,
      matchesCreated: matchesCreated,
      usedBye: usedBye,
    );
  }

  /// Auto-generates fixtures: round-robin between all league teams in date range.
  /// [matchTime] e.g. '15:00'. Creates one match per day (or spreads across dates).
  /// @deprecated Use generateFixtures with FixtureGenerationOptions instead.
  Future<int> autoGenerateFixtures({
    required String leagueId,
    required String seasonId,
    required DateTime startDate,
    required DateTime endDate,
    required String matchTime,
  }) async {
    final teamsRes = await _client
        .from('league_team_memberships')
        .select('team_id')
        .eq('league_id', leagueId);
    final teamIds = (teamsRes as List)
        .map((r) => (r as Map)['team_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();

    if (teamIds.length < 2) return 0;

    // Generate all unique pairs (round-robin)
    final pairs = <(String, String)>[];
    for (var i = 0; i < teamIds.length; i++) {
      for (var j = i + 1; j < teamIds.length; j++) {
        pairs.add((teamIds[i], teamIds[j]));
      }
    }

    if (pairs.isEmpty) return 0;

    // Spread matches across date range
    final days = endDate.difference(startDate).inDays + 1;
    final matchesPerDay = (pairs.length / days).ceil().clamp(1, pairs.length);
    var created = 0;
    var dayOffset = 0;
    var pairIdx = 0;

    while (pairIdx < pairs.length) {
      final pair = pairs[pairIdx];
      final matchDate = startDate.add(Duration(days: dayOffset));
      if (matchDate.isAfter(endDate)) break;

      final dateStr = matchDate.toIso8601String().split('T').first;
      await _client.from('matches').insert({
        'league_id': leagueId,
        'season_id': seasonId,
        'teamA': pair.$1,
        'teamB': pair.$2,
        'match_date': dateStr,
        'match_time': matchTime,
        'venue': 'TBD',
      });
      created++;
      pairIdx++;
      if (pairIdx % matchesPerDay == 0) dayOffset++;
    }

    return created;
  }

  /// Updates the status of a match in the database.
  /// Also handles timestamp tracking for timer synchronization:
  /// - When status changes to "ongoing": sets started_at to now
  /// - When status changes to "halfTime": sets halftime_paused_at to now
  /// - When status changes back to "ongoing": updates resumed_from_halftime_at and increments total_paused_duration_seconds
  Future<void> updateMatchStatus(String id, MatchStatus status) async {
    if (id.isEmpty) return;

    final now = DateTime.now().toUtc().toIso8601String();
    final updateData = <String, dynamic>{'status': status.dbValue};

    // Handle timestamp tracking based on status transition
    if (status == MatchStatus.ongoing) {
      // Check if this is initial start or resumption from halftime
      final existingMatch = await _client
          .from('matches')
          .select(
            'started_at, halftime_paused_at, total_paused_duration_seconds',
          )
          .eq('id', id)
          .maybeSingle();

      if (existingMatch != null) {
        if (existingMatch['started_at'] == null) {
          // First time starting the match
          updateData['started_at'] = now;
        } else if (existingMatch['halftime_paused_at'] != null) {
          // Resuming from halftime - calculate pause duration
          final haltimePausedAt = DateTime.parse(
            existingMatch['halftime_paused_at'] as String,
          );
          final pausedSeconds = DateTime.now()
              .toUtc()
              .difference(haltimePausedAt)
              .inSeconds;
          final previousTotal =
              (existingMatch['total_paused_duration_seconds'] as int?) ?? 0;

          updateData['resumed_from_halftime_at'] = now;
          updateData['total_paused_duration_seconds'] =
              previousTotal + pausedSeconds;
        }
      }
    } else if (status == MatchStatus.halfTime) {
      // Match entering halftime
      updateData['halftime_paused_at'] = now;
    }

    await _client.from('matches').update(updateData).eq('id', id);

    if (status == MatchStatus.fullTime) {
      await _syncSeasonStatusForEndedMatch(id);
    }
  }

  /// Returns the configured half duration for a match, or null if unset.
  Future<int?> getMatchHalfDurationMinutes(String matchId) async {
    if (matchId.isEmpty) return null;
    try {
      final row = await _client
          .from('matches')
          .select('half_duration_minutes')
          .eq('id', matchId)
          .maybeSingle();
      final raw = row?['half_duration_minutes'];
      if (raw == null) return null;
      return int.tryParse(raw.toString());
    } catch (_) {
      return null;
    }
  }

  /// Persists the configured half duration for a match (1–120 minutes per half).
  Future<void> setMatchHalfDurationMinutes(String matchId, int minutes) async {
    if (matchId.isEmpty) return;
    final clamped = minutes.clamp(1, 120);
    await _client
        .from('matches')
        .update({'half_duration_minutes': clamped})
        .eq('id', matchId);
  }

  /// Records a goal via RPC (inserts match_events, updates stats, match score).
  /// Returns updated teamA_score, teamB_score or null on error.
  /// On error, throws with the backend message for debugging.
  Future<Map<String, dynamic>?> recordGoalViaRpc({
    required String matchId,
    required String scorerPlayerId,
    required int minute,
    int second = 0,
    String? assistPlayerId,
  }) async {
    if (matchId.isEmpty || scorerPlayerId.isEmpty) return null;
    try {
      final res = await _client.rpc(
        'record_match_goal',
        params: {
          'p_match_id': matchId,
          'p_player_id': scorerPlayerId,
          'p_minute': minute,
          'p_second': second,
          if (assistPlayerId != null && assistPlayerId.isNotEmpty)
            'p_assist_player_id': assistPlayerId,
        },
      );
      return res as Map<String, dynamic>?;
    } catch (e) {
      rethrow;
    }
  }

  /// Records a card via RPC. cardType: 'yellow_card' or 'red_card'.
  Future<Map<String, dynamic>?> recordCardViaRpc({
    required String matchId,
    required String playerId,
    required String cardType,
    required int minute,
    int second = 0,
  }) async {
    if (matchId.isEmpty || playerId.isEmpty) return null;
    try {
      final res = await _client.rpc(
        'record_match_card',
        params: {
          'p_match_id': matchId,
          'p_player_id': playerId,
          'p_card_type': cardType,
          'p_minute': minute,
          'p_second': second,
        },
      );
      return res as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  /// Initializes match_player_stats and match_team_stats for all squad players.
  /// Call when match starts (before first event).
  Future<void> initializeMatchStatsViaRpc(String matchId) async {
    if (matchId.isEmpty) return;
    try {
      await _client.rpc(
        'initialize_match_stats',
        params: {'p_match_id': matchId},
      );
    } catch (_) {}
  }

  /// Finalizes match (sets fullTime, optionally refreshes gameweek_player_stats).
  Future<void> finalizeMatchViaRpc(String matchId) async {
    if (matchId.isEmpty) return;
    try {
      await _client.rpc('finalize_match', params: {'p_match_id': matchId});
      await _syncSeasonStatusForEndedMatch(matchId);
    } catch (_) {}
  }

  /// When a match in a new season is ended, move season status from
  /// `upcoming` to `ongoing`.
  Future<void> _syncSeasonStatusForEndedMatch(String matchId) async {
    if (matchId.isEmpty) return;
    try {
      final matchRow = await _client
          .from('matches')
          .select('season_id, status')
          .eq('id', matchId)
          .maybeSingle();
      if (matchRow == null) return;
      final matchStatus = matchRow['status']?.toString();
      final seasonId = matchRow['season_id']?.toString();
      if (seasonId == null || seasonId.isEmpty || matchStatus != 'fullTime') {
        return;
      }

      final seasonRow = await _client
          .from('seasons')
          .select('status')
          .eq('id', seasonId)
          .maybeSingle();
      if (seasonRow == null) return;
      final seasonStatus = seasonRow['status']?.toString() ?? '';
      if (seasonStatus == 'upcoming') {
        await _client
            .from('seasons')
            .update({'status': 'ongoing'})
            .eq('id', seasonId);
      }
    } catch (_) {
      // Keep match finalization/status change resilient even if season sync fails.
    }
  }

  /// Records a generic match event (shot, corner, tackle, save, substitution).
  /// Pass [playerId] for player-specific stats; omit for team-only events.
  Future<void> recordMatchEventViaRpc({
    required String matchId,
    required String eventType,
    required String teamId,
    required int minute,
    int second = 0,
    String? playerId,
    String? secondaryPlayerId,
  }) async {
    if (matchId.isEmpty || teamId.isEmpty) return;
    await _client.rpc(
      'record_match_event',
      params: {
        'p_match_id': matchId,
        'p_event_type': eventType,
        'p_team_id': teamId,
        'p_minute': minute,
        'p_second': second,
        if (playerId != null && playerId.isNotEmpty) 'p_player_id': playerId,
        if (secondaryPlayerId != null && secondaryPlayerId.isNotEmpty)
          'p_secondary_player_id': secondaryPlayerId,
      },
    );
  }

  /// Voids (undoes) a match event. Reverses stat updates and marks event deleted.
  Future<void> voidMatchEventViaRpc(String eventId) async {
    if (eventId.isEmpty) return;
    await _client.rpc('void_match_event', params: {'p_event_id': eventId});
  }

  /// Players with non-null [rating] for this match, highest first (PotM + top rated).
  Future<List<FixtureMatchRatedPlayer>> getMatchPlayerRatingsRanked(
    String matchId,
  ) async {
    if (matchId.isEmpty) return <FixtureMatchRatedPlayer>[];
    try {
      final res = await _client
          .from('match_player_stats')
          .select('''
            player_id, team_id, rating,
            player:players!match_player_stats_player_id_fkey(player_name, image_url, position),
            team:teams!match_player_stats_team_id_fkey(short_form, team_name)
          ''')
          .eq('match_id', matchId)
          .not('rating', 'is', null)
          .order('rating', ascending: false);
      final list = List<Map<String, dynamic>>.from(res as List);
      final out = <FixtureMatchRatedPlayer>[];
      for (final row in list) {
        final rating = double.tryParse(row['rating']?.toString() ?? '');
        final playerId = row['player_id']?.toString() ?? '';
        final teamId = row['team_id']?.toString() ?? '';
        if (rating == null || playerId.isEmpty || teamId.isEmpty) continue;
        final player = row['player'];
        final playerMap = player is Map<String, dynamic>
            ? player
            : (player is Map
                  ? Map<String, dynamic>.from(player)
                  : <String, dynamic>{});
        final team = row['team'];
        final teamMap = team is Map<String, dynamic>
            ? team
            : (team is Map
                  ? Map<String, dynamic>.from(team)
                  : <String, dynamic>{});
        out.add(
          FixtureMatchRatedPlayer(
            playerId: playerId,
            teamId: teamId,
            name: playerMap['player_name']?.toString() ?? '—',
            rating: rating,
            imageUrl: playerMap['image_url']?.toString(),
            position: playerMap['position']?.toString(),
            teamShortForm: teamMap['short_form']?.toString(),
            teamTeamName: teamMap['team_name']?.toString(),
          ),
        );
      }
      return out;
    } catch (_) {
      try {
        final res = await _client
            .from('match_player_stats')
            .select('player_id, team_id, rating')
            .eq('match_id', matchId)
            .not('rating', 'is', null)
            .order('rating', ascending: false);
        final list = List<Map<String, dynamic>>.from(res as List);
        return list
            .map(
              (row) => FixtureMatchRatedPlayer(
                playerId: row['player_id']?.toString() ?? '',
                teamId: row['team_id']?.toString() ?? '',
                name: 'Player',
                rating: double.tryParse(row['rating']?.toString() ?? '') ?? 0,
              ),
            )
            .where((p) => p.playerId.isNotEmpty && p.teamId.isNotEmpty)
            .toList();
      } catch (__) {
        return [];
      }
    }
  }

  /// Aggregated team stats for the Stats tab (`match_team_stats` per team).
  Future<({MatchTeamStatsSnapshot teamA, MatchTeamStatsSnapshot teamB})>
  getMatchTeamStatsForMatch(
    String matchId,
    String teamAId,
    String teamBId,
  ) async {
    if (matchId.isEmpty) {
      return (
        teamA: const MatchTeamStatsSnapshot(),
        teamB: const MatchTeamStatsSnapshot(),
      );
    }
    try {
      final res = await _client
          .from('match_team_stats')
          .select()
          .eq('match_id', matchId)
          .inFilter('team_id', [teamAId, teamBId]);
      final list = List<Map<String, dynamic>>.from(res as List);
      final byTeam = <String, Map<String, dynamic>>{};
      for (final r in list) {
        final tid = r['team_id']?.toString();
        if (tid != null) byTeam[tid] = r;
      }
      return (
        teamA: MatchTeamStatsSnapshot.fromRow(byTeam[teamAId]),
        teamB: MatchTeamStatsSnapshot.fromRow(byTeam[teamBId]),
      );
    } catch (_) {
      return (
        teamA: const MatchTeamStatsSnapshot(),
        teamB: const MatchTeamStatsSnapshot(),
      );
    }
  }

  /// Fetches match_events for a match (excluding voided), with scorer/assister names.
  Future<List<Map<String, dynamic>>> getMatchEvents(String matchId) async {
    if (matchId.isEmpty) return [];
    try {
      final res = await _client
          .from('match_events')
          .select('''
        id, created_at, event_type, event_minute, event_second, team_id, player_id, secondary_player_id,
        scorer:players!match_events_player_id_fkey(player_name),
        assister:players!match_events_secondary_player_id_fkey(player_name)
      ''')
          .eq('match_id', matchId)
          .eq('is_deleted', false)
          .order('event_minute', ascending: true)
          .order('event_second', ascending: true);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (_) {
      try {
        final fallback = await _client
            .from('match_events')
            .select(
              'id, created_at, event_type, event_minute, event_second, team_id, player_id, secondary_player_id',
            )
            .eq('match_id', matchId)
            .eq('is_deleted', false)
            .order('event_minute', ascending: true)
            .order('event_second', ascending: true);
        return List<Map<String, dynamic>>.from(fallback as List);
      } catch (__) {
        return [];
      }
    }
  }

  /// Sets both team scores directly (e.g. league-owner correction).
  Future<void> updateMatchScores(
    String id, {
    required int teamAScore,
    required int teamBScore,
  }) async {
    if (id.isEmpty) return;
    await _client
        .from('matches')
        .update({
          'teamA_score': teamAScore.clamp(0, 99),
          'teamB_score': teamBScore.clamp(0, 99),
        })
        .eq('id', id);
  }

  /// Updates match date and kick-off time.
  Future<void> updateMatchSchedule(
    String id, {
    required DateTime matchDate,
    required String matchTime,
  }) async {
    if (id.isEmpty) return;
    final date =
        '${matchDate.year}-${matchDate.month.toString().padLeft(2, '0')}-${matchDate.day.toString().padLeft(2, '0')}';
    await _client
        .from('matches')
        .update({'match_date': date, 'match_time': matchTime})
        .eq('id', id);
  }

  /// Permanently removes a match row.
  Future<void> deleteMatch(String id) async {
    if (id.isEmpty) return;
    await _client.from('matches').delete().eq('id', id);
  }

  /// Increments team A or team B score by 1 (uses current row; null scores treated as 0).
  Future<void> incrementMatchScore(String id, {required bool forTeamA}) async {
    if (id.isEmpty) return;
    final match = await getMatchById(id);
    if (match == null) return;
    final a = (match.teamAScore ?? 0) + (forTeamA ? 1 : 0);
    final b = (match.teamBScore ?? 0) + (forTeamA ? 0 : 1);
    await _client
        .from('matches')
        .update({'teamA_score': a, 'teamB_score': b})
        .eq('id', id);
  }

  /// Records a goal: match score +1, match_player_stats (scorer goals, assister assists),
  /// match_team_stats (team goals/assists). Uses upsert-like read-then-write for NOT NULL columns.
  Future<void> recordGoalWithStats({
    required String matchId,
    required bool forTeamA,
    required String scorerPlayerId,
    required String scoringTeamId,
    String? assistPlayerId,
  }) async {
    if (matchId.isEmpty || scorerPlayerId.isEmpty || scoringTeamId.isEmpty) {
      return;
    }
    await incrementMatchScore(matchId, forTeamA: forTeamA);

    await _incrementMatchPlayerGoals(
      matchId: matchId,
      playerId: scorerPlayerId,
      teamId: scoringTeamId,
    );
    if (assistPlayerId != null &&
        assistPlayerId.isNotEmpty &&
        assistPlayerId != scorerPlayerId) {
      await _incrementMatchPlayerAssists(
        matchId: matchId,
        playerId: assistPlayerId,
        teamId: scoringTeamId,
      );
    }
    await _incrementMatchTeamGoalAndMaybeAssist(
      matchId: matchId,
      teamId: scoringTeamId,
      hasAssist: assistPlayerId != null && assistPlayerId.isNotEmpty,
    );
  }

  static const Map<String, dynamic> _matchPlayerStatsDefaults = {
    'minutes_played': 0,
    'goals': 0,
    'assists': 0,
    'shots': 0,
    'shots_on_target': 0,
    'tackles': 0,
    'saves': 0,
    'rating': 0.0,
    'xG': 0.0,
    'xA': 0.0,
    'yellow_cards': 0,
    'red_cards': 0,
  };

  static const Map<String, dynamic> _matchTeamStatsDefaults = {
    'goals': 0,
    'shots': 0,
    'shots_on_target': 0,
    'yellow_cards': 0,
    'red_cards': 0,
    'tackles': 0,
    'assists': 0,
    'saves': 0,
    'XG': 0.0,
  };

  Future<void> _incrementMatchPlayerGoals({
    required String matchId,
    required String playerId,
    required String teamId,
  }) async {
    final row = await _client
        .from('match_player_stats')
        .select('goals')
        .eq('match_id', matchId)
        .eq('player_id', playerId)
        .maybeSingle();
    if (row != null) {
      final g = (row['goals'] is int)
          ? row['goals'] as int
          : int.tryParse(row['goals']?.toString() ?? '0') ?? 0;
      await _client
          .from('match_player_stats')
          .update({'goals': g + 1})
          .eq('match_id', matchId)
          .eq('player_id', playerId);
    } else {
      final insert = Map<String, dynamic>.from(_matchPlayerStatsDefaults)
        ..['match_id'] = matchId
        ..['player_id'] = playerId
        ..['team_id'] = teamId
        ..['goals'] = 1;
      await _client.from('match_player_stats').insert(insert);
    }
  }

  Future<void> _incrementMatchPlayerAssists({
    required String matchId,
    required String playerId,
    required String teamId,
  }) async {
    final row = await _client
        .from('match_player_stats')
        .select('assists')
        .eq('match_id', matchId)
        .eq('player_id', playerId)
        .maybeSingle();
    if (row != null) {
      final a = (row['assists'] is int)
          ? row['assists'] as int
          : int.tryParse(row['assists']?.toString() ?? '0') ?? 0;
      await _client
          .from('match_player_stats')
          .update({'assists': a + 1})
          .eq('match_id', matchId)
          .eq('player_id', playerId);
    } else {
      final insert = Map<String, dynamic>.from(_matchPlayerStatsDefaults)
        ..['match_id'] = matchId
        ..['player_id'] = playerId
        ..['team_id'] = teamId
        ..['assists'] = 1;
      await _client.from('match_player_stats').insert(insert);
    }
  }

  Future<void> _incrementMatchTeamGoalAndMaybeAssist({
    required String matchId,
    required String teamId,
    required bool hasAssist,
  }) async {
    final row = await _client
        .from('match_team_stats')
        .select('goals, assists')
        .eq('match_id', matchId)
        .eq('team_id', teamId)
        .maybeSingle();
    if (row != null) {
      final g = (row['goals'] is int)
          ? row['goals'] as int
          : int.tryParse(row['goals']?.toString() ?? '0') ?? 0;
      final a = (row['assists'] is int)
          ? row['assists'] as int
          : int.tryParse(row['assists']?.toString() ?? '0') ?? 0;
      final update = <String, dynamic>{'goals': g + 1};
      if (hasAssist) update['assists'] = a + 1;
      await _client
          .from('match_team_stats')
          .update(update)
          .eq('match_id', matchId)
          .eq('team_id', teamId);
    } else {
      final insert = Map<String, dynamic>.from(_matchTeamStatsDefaults)
        ..['match_id'] = matchId
        ..['team_id'] = teamId
        ..['goals'] = 1;
      if (hasAssist) insert['assists'] = 1;
      await _client.from('match_team_stats').insert(insert);
    }
  }

  /// Fallback when nested select fails: fetch teams separately and merge.
  Future<List<MatchModel>> _matchesWithTeamsFetched(
    List<Map<String, dynamic>> rows,
  ) async {
    final teamIds = <String>{};
    final leagueIds = <String>{};
    final gameweekIds = <String>{};
    for (final r in rows) {
      final a = r['teamA']?.toString();
      final b = r['teamB']?.toString();
      if (a != null) teamIds.add(a);
      if (b != null) teamIds.add(b);
      final lid = r['league_id']?.toString();
      if (lid != null && lid.isNotEmpty) leagueIds.add(lid);
      final gwid = r['gameweek']?.toString();
      if (gwid != null && gwid.isNotEmpty) gameweekIds.add(gwid);
    }
    if (teamIds.isEmpty) {
      return rows.map((e) => MatchModel.fromJson(e)).toList();
    }

    final teamsRes = await _client
        .from('teams')
        .select('id, logo_id, short_form, team_name')
        .inFilter('id', teamIds.toList());
    final teamsList = List<Map<String, dynamic>>.from(teamsRes as List);
    final teamsMap = {for (final t in teamsList) t['id']?.toString(): t};

    final leaguesMap = <String, Map<String, String>>{};
    if (leagueIds.isNotEmpty) {
      final leaguesRes = await _client
          .from('leagues')
          .select('id, league_name, country, logo_id')
          .inFilter('id', leagueIds.toList());
      for (final l in List<Map<String, dynamic>>.from(leaguesRes as List)) {
        final id = l['id']?.toString();
        if (id != null) {
          leaguesMap[id] = {
            'league_name': l['league_name']?.toString() ?? '—',
            'country': l['country']?.toString() ?? '',
            'logo_id': l['logo_id']?.toString() ?? '',
          };
        }
      }
    }

    final gameweeksMap = <String, int>{};
    if (gameweekIds.isNotEmpty) {
      final gwsRes = await _client
          .from('gameweeks')
          .select('id, week')
          .inFilter('id', gameweekIds.toList());
      for (final g in List<Map<String, dynamic>>.from(gwsRes as List)) {
        final id = g['id']?.toString();
        final week = int.tryParse(g['week']?.toString() ?? '');
        if (id != null && week != null) gameweeksMap[id] = week;
      }
    }

    return rows.map((row) {
      final aId = row['teamA']?.toString();
      final bId = row['teamB']?.toString();
      final json = Map<String, dynamic>.from(row)
        ..['teamA'] = teamsMap[aId]
        ..['teamB'] = teamsMap[bId];
      final lid = row['league_id']?.toString();
      if (lid != null) {
        json['league'] = leaguesMap[lid] ??
            {'league_name': '—', 'country': '', 'logo_id': ''};
      }
      final gwid = row['gameweek']?.toString();
      if (gwid != null) json['gameweek'] = {'week': gameweeksMap[gwid]};
      return MatchModel.fromJson(json);
    }).toList();
  }

  /// Fetch match timing data needed for server-synced clock and timeline.
  /// Returns timing fields or null if match not found.
  Future<Map<String, dynamic>?> getMatchTimingData(String matchId) async {
    if (matchId.isEmpty) return null;
    try {
      final response = await _client
          .from('matches')
          .select(
            'started_at, halftime_paused_at, resumed_from_halftime_at, '
            'half_duration_minutes, total_paused_duration_seconds, status',
          )
          .eq('id', matchId)
          .maybeSingle();
      return response;
    } catch (_) {
      return null;
    }
  }

  /// Record that a match was started (sets started_at if not already set)
  Future<void> recordMatchStart(String matchId) async {
    if (matchId.isEmpty) return;
    try {
      // Check if started_at is already set
      final existing = await _client
          .from('matches')
          .select('started_at')
          .eq('id', matchId)
          .maybeSingle();

      if (existing != null && existing['started_at'] == null) {
        // Only update if not already set
        await _client
            .from('matches')
            .update({'started_at': DateTime.now().toUtc().toIso8601String()})
            .eq('id', matchId);
      }
    } catch (_) {}
  }

  /// Record pause duration when transitioning between halves
  Future<void> recordPauseDuration(String matchId, int pausedSeconds) async {
    if (matchId.isEmpty || pausedSeconds <= 0) return;
    try {
      final row = await _client
          .from('matches')
          .select('total_paused_duration_seconds')
          .eq('id', matchId)
          .maybeSingle();

      if (row != null) {
        final current = (row['total_paused_duration_seconds'] as int?) ?? 0;
        await _client
            .from('matches')
            .update({'total_paused_duration_seconds': current + pausedSeconds})
            .eq('id', matchId);
      }
    } catch (_) {}
  }

  static const _matchFavouriteSelect = '''
        id, match_date, match_time, status, teamA_score, teamB_score, venue_image_url, league_id,
        half_duration_minutes,
        gameweek:gameweeks(week),
        league:leagues(league_name, country, logo_id),
        teamA:teams!teamA(id, logo_id, short_form, team_name),
        teamB:teams!teamB(id, logo_id, short_form, team_name)
      ''';

  /// Favourited matches for the signed-in user (including guests).
  Future<List<MatchModel>> getFavouritedMatchesForUser(String userId) async {
    if (userId.isEmpty) return [];
    final res = await _client
        .from('match_favourites')
        .select('matches($_matchFavouriteSelect)')
        .eq('user_id', userId)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: false);
    final out = <MatchModel>[];
    for (final row in res as List) {
      final matchRaw = row['matches'];
      if (matchRaw is Map) {
        out.add(MatchModel.fromJson(Map<String, dynamic>.from(matchRaw)));
      }
    }
    return out;
  }

  Future<void> addMatchFavourite(String matchId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || matchId.isEmpty) return;
    final nextOrder = await _nextMatchFavouriteSortOrder(uid);
    await _client.from('match_favourites').insert({
      'user_id': uid,
      'match_id': matchId,
      'sort_order': nextOrder,
    });
  }

  Future<int> _nextMatchFavouriteSortOrder(String userId) async {
    final res = await _client
        .from('match_favourites')
        .select('sort_order')
        .eq('user_id', userId)
        .order('sort_order', ascending: false)
        .limit(1)
        .maybeSingle();
    if (res == null) return 0;
    final current = res['sort_order'];
    if (current is int) return current + 1;
    if (current is num) return current.toInt() + 1;
    return 0;
  }

  Future<void> updateMatchFavouritesOrder(List<String> matchIdsInOrder) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || matchIdsInOrder.isEmpty) return;
    for (var i = 0; i < matchIdsInOrder.length; i++) {
      final matchId = matchIdsInOrder[i];
      if (matchId.isEmpty) continue;
      await _client
          .from('match_favourites')
          .update({'sort_order': i})
          .eq('user_id', uid)
          .eq('match_id', matchId);
    }
  }

  Future<void> removeMatchFavourite(String matchId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || matchId.isEmpty) return;
    await _client
        .from('match_favourites')
        .delete()
        .eq('user_id', uid)
        .eq('match_id', matchId);
  }
}

/// Fixture completion counts for season progress UI.
class SeasonFixtureProgress {
  const SeasonFixtureProgress({
    required this.playedCount,
    required this.totalCount,
  });

  final int playedCount;
  final int totalCount;

  /// 0..1 when [totalCount] > 0; otherwise 0.
  double get progress01 =>
      totalCount > 0 ? (playedCount / totalCount).clamp(0.0, 1.0) : 0.0;
}
