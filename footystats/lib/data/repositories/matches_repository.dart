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
        id, match_date, match_time, status, teamA_score, teamB_score, gameweek,
        teamA:teams!teamA(id, logo_id, short_form),
        teamB:teams!teamB(id, logo_id, short_form)
      ''').eq('id', id).maybeSingle();
      if (res == null) return null;
      return MatchModel.fromJson(Map<String, dynamic>.from(res));
    } catch (_) {
      final fallback = await _client.from('matches').select(
        'id, match_date, match_time, status, teamA, teamB, '
        'teamA_score, teamB_score, gameweek',
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
        id, match_date, match_time, status, teamA_score, teamB_score, gameweek,
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
        'teamA_score, teamB_score, gameweek, league_id',
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
    for (final r in rows) {
      for (final k in ['teamA', 'teamB']) {
        final v = r[k]?.toString();
        if (v != null && v.isNotEmpty) teamIds.add(v);
      }
      final lid = r['league_id']?.toString();
      if (lid != null && lid.isNotEmpty) leagueIds.add(lid);
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

    return rows.map((row) {
      final json = Map<String, dynamic>.from(row);
      json['teamA'] = teamsMap[row['teamA']?.toString() ?? ''];
      json['teamB'] = teamsMap[row['teamB']?.toString() ?? ''];
      final lid = row['league_id']?.toString();
      if (lid != null) json['league'] = {'league_name': leaguesMap[lid] ?? '—'};
      return MatchModel.fromJson(json);
    }).toList();
  }

  /// Fetches all matches ordered by date and time.
  Future<List<MatchModel>> getMatches({String? gameweek}) async {
    List<Map<String, dynamic>> list;
    try {
      var query = _client.from('matches').select('''
        id, match_date, match_time, status, teamA_score, teamB_score, gameweek,
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
        'teamA_score, teamB_score, gameweek',
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
    for (final r in rows) {
      final a = r['teamA']?.toString();
      final b = r['teamB']?.toString();
      if (a != null) teamIds.add(a);
      if (b != null) teamIds.add(b);
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

    return rows.map((row) {
      final aId = row['teamA']?.toString();
      final bId = row['teamB']?.toString();
      final json = Map<String, dynamic>.from(row)
        ..['teamA'] = teamsMap[aId]
        ..['teamB'] = teamsMap[bId];
      return MatchModel.fromJson(json);
    }).toList();
  }
}
