import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/player_year_team_stats.dart';

/// Profile stats, career totals, and comparison data.
///
/// Primary path: SQL RPCs / views that sum [match_player_stats.minutes_played]
/// (computed from frozen line-ups + substitutions). Fallback queries the same
/// table directly for completed matches.
class PlayerStatsRepository {
  PlayerStatsRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  int get currentCalendarYear => DateTime.now().year;

  Future<PlayerYearOverallStats?> getPlayerYearOverall(
    String playerId, {
    int? year,
  }) async {
    if (playerId.isEmpty) return null;
    final targetYear = year ?? currentCalendarYear;

    try {
      final res = await _client.rpc(
        'get_player_year_stats',
        params: {'p_player_id': playerId, 'p_year': targetYear},
      );
      final rows = _normalizeRows(res);
      if (rows.isEmpty) return null;
      return PlayerYearOverallStats.fromJson(rows.first, year: targetYear);
    } catch (_) {
      return _loadPlayerYearOverallFallback(playerId, targetYear);
    }
  }

  Future<List<PlayerYearTeamStats>> getPlayerYearTeamStats(
    String playerId, {
    int? year,
  }) async {
    if (playerId.isEmpty) return const [];
    final targetYear = year ?? currentCalendarYear;

    try {
      final res = await _client.rpc(
        'get_player_year_team_stats',
        params: {'p_player_id': playerId, 'p_year': targetYear},
      );
      final rows = _normalizeRows(res);
      return rows
          .map((row) => PlayerYearTeamStats.fromJson(row, year: targetYear))
          .toList();
    } catch (_) {
      return _loadPlayerYearTeamStatsFallback(playerId, targetYear);
    }
  }

  Future<PlayerAllTimeStats?> getPlayerAllTimeStats(String playerId) async {
    if (playerId.isEmpty) return null;

    try {
      final res = await _client.rpc(
        'get_player_all_time_stats',
        params: {'p_player_id': playerId},
      );
      final rows = _normalizeRows(res);
      if (rows.isEmpty) return null;
      return PlayerAllTimeStats.fromJson(rows.first);
    } catch (_) {
      return _loadPlayerAllTimeFallback(playerId);
    }
  }

  Future<List<PlayerYearTeamStats>> getPlayerCareerTeamStats(
    String playerId,
  ) async {
    if (playerId.isEmpty) return const [];

    try {
      final res = await _client.rpc(
        'get_player_career_team_stats',
        params: {'p_player_id': playerId},
      );
      final rows = _normalizeRows(res);
      return rows.map((row) {
        final yearValue = row['year'];
        final year = yearValue is num
            ? yearValue.round()
            : int.tryParse(yearValue?.toString() ?? '') ??
                  currentCalendarYear;
        return PlayerYearTeamStats.fromJson(row, year: year);
      }).toList();
    } catch (_) {
      return _loadPlayerCareerTeamStatsFallback(playerId);
    }
  }

  List<Map<String, dynamic>> _normalizeRows(dynamic res) {
    if (res is! List) return const [];
    return res
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  String _yearStart(int year) => '$year-01-01';
  String _yearEnd(int year) => '${year + 1}-01-01';

  Future<PlayerYearOverallStats?> _loadPlayerYearOverallFallback(
    String playerId,
    int year,
  ) async {
    final rows = await _fetchYearMatchStatRows(playerId, year);
    if (rows.isEmpty) return null;
    return PlayerYearOverallStats.fromMatchRows(rows, year: year);
  }

  Future<List<PlayerYearTeamStats>> _loadPlayerYearTeamStatsFallback(
    String playerId,
    int year,
  ) async {
    final rows = await _fetchYearMatchStatRows(playerId, year);
    if (rows.isEmpty) return const [];

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final teamId = row['team_id']?.toString() ?? '';
      if (teamId.isEmpty) continue;
      grouped.putIfAbsent(teamId, () => []).add(row);
    }

    final out = <PlayerYearTeamStats>[];
    for (final entry in grouped.entries) {
      final sample = entry.value.first;
      final team = sample['teams'];
      final teamMap = team is Map ? Map<String, dynamic>.from(team) : null;
      final teamName =
          teamMap?['team_name']?.toString().trim().isNotEmpty == true
          ? teamMap!['team_name'].toString()
          : (teamMap?['short_form']?.toString().trim().isNotEmpty == true
                ? teamMap!['short_form'].toString()
                : 'Team');
      final logoId = teamMap?['logo_id']?.toString();
      out.add(
        PlayerYearTeamStats.fromMatchRows(
          teamId: entry.key,
          teamName: teamName,
          logoId: logoId,
          rows: entry.value,
          year: year,
        ),
      );
    }
    out.sort((a, b) => a.teamName.toLowerCase().compareTo(b.teamName.toLowerCase()));
    return out;
  }

  Future<PlayerAllTimeStats?> _loadPlayerAllTimeFallback(String playerId) async {
    final rows = await _fetchMatchStatRows(playerId);
    if (rows.isEmpty) return null;
    return PlayerAllTimeStats.fromMatchRows(rows);
  }

  Future<List<PlayerYearTeamStats>> _loadPlayerCareerTeamStatsFallback(
    String playerId,
  ) async {
    final rows = await _fetchMatchStatRows(playerId);
    if (rows.isEmpty) return const [];

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final teamId = row['team_id']?.toString() ?? '';
      if (teamId.isEmpty) continue;
      final year = _yearFromRow(row);
      if (year == null) continue;
      grouped.putIfAbsent('$teamId|$year', () => []).add(row);
    }

    final out = <PlayerYearTeamStats>[];
    for (final entry in grouped.entries) {
      final sample = entry.value.first;
      final team = sample['teams'];
      final teamMap = team is Map ? Map<String, dynamic>.from(team) : null;
      final teamName =
          teamMap?['team_name']?.toString().trim().isNotEmpty == true
          ? teamMap!['team_name'].toString()
          : (teamMap?['short_form']?.toString().trim().isNotEmpty == true
                ? teamMap!['short_form'].toString()
                : 'Team');
      final logoId = teamMap?['logo_id']?.toString();
      final year = _yearFromRow(sample) ?? currentCalendarYear;
      out.add(
        PlayerYearTeamStats.fromMatchRows(
          teamId: sample['team_id']?.toString() ?? '',
          teamName: teamName,
          logoId: logoId,
          rows: entry.value,
          year: year,
        ),
      );
    }
    out.sort((a, b) {
      final yearCompare = b.year.compareTo(a.year);
      if (yearCompare != 0) return yearCompare;
      return a.teamName.toLowerCase().compareTo(b.teamName.toLowerCase());
    });
    return out;
  }

  int? _yearFromRow(Map<String, dynamic> row) {
    final match = row['match'];
    if (match is! Map) return null;
    final matchDate = match['match_date']?.toString();
    if (matchDate == null || matchDate.length < 4) return null;
    return int.tryParse(matchDate.substring(0, 4));
  }

  Future<List<Map<String, dynamic>>> _fetchYearMatchStatRows(
    String playerId,
    int year,
  ) async {
    return _fetchMatchStatRows(
      playerId,
      startDate: _yearStart(year),
      endDate: _yearEnd(year),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchMatchStatRows(
    String playerId, {
    String? startDate,
    String? endDate,
  }) async {
    var query = _client
        .from('match_player_stats')
        .select(
          'team_id, match_id, minutes_played, goals, assists, shots, '
          'shots_on_target, tackles, saves, yellow_cards, red_cards, rating, '
          'teams(team_name, short_form, logo_id), '
          'match:matches!inner(status, match_date)',
        )
        .eq('player_id', playerId)
        .eq('match.status', 'fullTime');
    if (startDate != null) {
      query = query.gte('match.match_date', startDate);
    }
    if (endDate != null) {
      query = query.lt('match.match_date', endDate);
    }
    final res = await query;
    return _normalizeRows(res);
  }
}
