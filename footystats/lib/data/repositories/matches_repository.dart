import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/match_model.dart';

/// Fetches matches from Supabase matches table with teamA/teamB embedded.
/// Table columns: id, created_at, match_date, match_time, status, teamA_score,
/// teamB_score, teamA, teamB, gameweek. Teams: id, logo_id, short_form.
class MatchesRepository {
  MatchesRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Fetches a single match by id with teamA/teamB embedded.
  Future<MatchModel?> getMatchById(String id) async {
    if (id.isEmpty) return null;
    try {
      final res = await _client.from('matches').select('''
        id, match_date, match_time, status, teamA_score, teamB_score,
        gameweek:gameweeks(week),
        league:leagues(league_name),
        teamA:teams!teamA(id, logo_id, short_form),
        teamB:teams!teamB(id, logo_id, short_form)
      ''').eq('id', id).maybeSingle();
      if (res == null) return null;
      return MatchModel.fromJson(Map<String, dynamic>.from(res));
    } catch (_) {
      final fallback = await _client.from('matches').select(
        'id, match_date, match_time, status, teamA, teamB, '
        'teamA_score, teamB_score, gameweek_id, league_id',
      ).eq('id', id).maybeSingle();
      if (fallback == null) return null;
      final list = await _matchesWithTeamsFetched([Map<String, dynamic>.from(fallback)]);
      return list.isNotEmpty ? list.single : null;
    }
  }

  /// Returns Monday 00:00:00 and Sunday 23:59:59 of the current week.
  static (DateTime, DateTime) _thisWeekRange() {
    final now = DateTime.now();
    final weekday = now.weekday; // 1=Mon, 7=Sun
    final monday = DateTime(now.year, now.month, now.day - (weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    final sundayEnd = DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59);
    return (monday, sundayEnd);
  }

  /// Fetches matches whose match_date falls within this week (Mon–Sun).
  /// Includes league name from leagues table. Matches table must have league_id.
  Future<List<MatchModel>> getMatchesThisWeek() async {
    final (monday, sundayEnd) = _thisWeekRange();
    final mondayStr = monday.toIso8601String().split('T').first;
    final sundayStr = sundayEnd.toIso8601String().split('T').first;

    try {
      final res = await _client.from('matches').select('''
        id, match_date, match_time, status, teamA_score, teamB_score,
        gameweek:gameweeks(week),
        league:leagues(league_name),
        teamA:teams!teamA(id, logo_id, short_form),
        teamB:teams!teamB(id, logo_id, short_form)
      ''').gte('match_date', mondayStr).lte('match_date', sundayStr)
          .order('match_date', ascending: true)
          .order('match_time', ascending: true);
      final list = List<Map<String, dynamic>>.from(res as List);
      return list.map((e) => MatchModel.fromJson(e)).toList();
    } catch (_) {
      final fallback = await _client.from('matches').select(
        'id, match_date, match_time, status, teamA, teamB, '
        'teamA_score, teamB_score, gameweek_id, league_id',
      ).gte('match_date', mondayStr).lte('match_date', sundayStr)
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
      final gwid = r['gameweek_id']?.toString();
      if (gwid != null && gwid.isNotEmpty) gameweekIds.add(gwid);
    }

    final teamsMap = <String, Map<String, dynamic>>{};
    if (teamIds.isNotEmpty) {
      final teamsRes = await _client.from('teams').select('id, logo_id, short_form')
          .inFilter('id', teamIds.toList());
      for (final t in List<Map<String, dynamic>>.from(teamsRes as List)) {
        final id = t['id']?.toString();
        if (id != null) teamsMap[id] = t;
      }
    }

    final leaguesMap = <String, String>{};
    if (leagueIds.isNotEmpty) {
      final leaguesRes = await _client.from('leagues').select('id, league_name')
          .inFilter('id', leagueIds.toList());
      for (final l in List<Map<String, dynamic>>.from(leaguesRes as List)) {
        final id = l['id']?.toString();
        if (id != null) leaguesMap[id] = l['league_name']?.toString() ?? '—';
      }
    }

    final gameweeksMap = <String, int>{};
    if (gameweekIds.isNotEmpty) {
      final gwsRes = await _client.from('gameweeks').select('id, week')
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
      if (lid != null) json['league'] = {'league_name': leaguesMap[lid] ?? '—'};
      final gwid = row['gameweek_id']?.toString();
      if (gwid != null) json['gameweek'] = {'week': gameweeksMap[gwid]};
      return MatchModel.fromJson(json);
    }).toList();
  }

  /// Fetches all matches ordered by date and time.
  Future<List<MatchModel>> getMatches({String? gameweek}) async {
    List<Map<String, dynamic>> list;
    try {
      var query = _client.from('matches').select('''
        id, match_date, match_time, status, teamA_score, teamB_score,
        gameweek:gameweeks(week),
        league:leagues(league_name),
        teamA:teams!teamA(id, logo_id, short_form),
        teamB:teams!teamB(id, logo_id, short_form)
      ''');
      if (gameweek != null && gameweek.isNotEmpty) {
        query = query.eq('gameweek', gameweek);
      }
      final res = await query
          .order('match_date', ascending: true)
          .order('match_time', ascending: true);
      list = List<Map<String, dynamic>>.from(res as List);
    } catch (_) {
      // Fallback: select without nested relation, then fetch teams by teamA / teamB
      var fallback = _client.from('matches').select(
        'id, match_date, match_time, status, teamA, teamB, '
        'teamA_score, teamB_score, gameweek_id, league_id',
      );
      if (gameweek != null && gameweek.isNotEmpty) {
        fallback = fallback.eq('gameweek', gameweek);
      }
      final res = await fallback
          .order('match_date', ascending: true)
          .order('match_time', ascending: true);
      list = List<Map<String, dynamic>>.from(res as List);
      return _matchesWithTeamsFetched(list);
    }

    return list.map((e) => MatchModel.fromJson(e)).toList();
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
    String? gameweekId,
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
    };
    if (gameweekId != null && gameweekId.isNotEmpty) {
      data['gameweek'] = gameweekId;
    }
    final res = await _client
        .from('matches')
        .insert(data)
        .select('id')
        .single();
    return res['id']?.toString() ?? '';
  }

  /// Auto-generates fixtures: round-robin between all league teams in date range.
  /// [matchTime] e.g. '15:00'. Creates one match per day (or spreads across dates).
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
  Future<void> updateMatchStatus(String id, MatchStatus status) async {
    if (id.isEmpty) return;
    await _client
        .from('matches')
        .update({'status': status.dbValue}).eq('id', id);
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
      final gwid = r['gameweek_id']?.toString();
      if (gwid != null && gwid.isNotEmpty) gameweekIds.add(gwid);
    }
    if (teamIds.isEmpty) {
      return rows.map((e) => MatchModel.fromJson(e)).toList();
    }

    final teamsRes = await _client
        .from('teams')
        .select('id, logo_id, short_form')
        .inFilter('id', teamIds.toList());
    final teamsList = List<Map<String, dynamic>>.from(teamsRes as List);
    final teamsMap = {for (final t in teamsList) t['id']?.toString(): t};

    final leaguesMap = <String, String>{};
    if (leagueIds.isNotEmpty) {
      final leaguesRes = await _client.from('leagues').select('id, league_name')
          .inFilter('id', leagueIds.toList());
      for (final l in List<Map<String, dynamic>>.from(leaguesRes as List)) {
        final id = l['id']?.toString();
        if (id != null) leaguesMap[id] = l['league_name']?.toString() ?? '—';
      }
    }

    final gameweeksMap = <String, int>{};
    if (gameweekIds.isNotEmpty) {
      final gwsRes = await _client.from('gameweeks').select('id, week')
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
      if (lid != null) json['league'] = {'league_name': leaguesMap[lid] ?? '—'};
      final gwid = row['gameweek_id']?.toString();
      if (gwid != null) json['gameweek'] = {'week': gameweeksMap[gwid]};
      return MatchModel.fromJson(json);
    }).toList();
  }
}
