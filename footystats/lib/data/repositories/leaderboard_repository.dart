import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/leaderboard_entry.dart';

/// Loads ranked players via `get_leaderboard`.
///
/// `total_points` and `gw_points` always reflect all finished matches on the app.
/// [getForLeague] / [getForTeam] only change which players are included in the list.
/// See `20250327000000_leaderboard_points.sql`.
class LeaderboardRepository {
  LeaderboardRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<LeaderboardEntry>> getOverall({int limit = 200}) async {
    return _call(mode: 'overall', leagueId: null, teamId: null, limit: limit);
  }

  Future<List<LeaderboardEntry>> getForLeague(String leagueId,
      {int limit = 200}) async {
    if (leagueId.isEmpty) return [];
    return _call(mode: 'league', leagueId: leagueId, teamId: null, limit: limit);
  }

  Future<List<LeaderboardEntry>> getForTeam(String teamId,
      {int limit = 200}) async {
    if (teamId.isEmpty) return [];
    return _call(mode: 'team', leagueId: null, teamId: teamId, limit: limit);
  }

  Future<List<LeaderboardEntry>> _call({
    required String mode,
    required String? leagueId,
    required String? teamId,
    required int limit,
  }) async {
    try {
      final res = await _client.rpc(
        'get_leaderboard',
        params: {
          'p_mode': mode,
          'p_league_id': leagueId,
          'p_team_id': teamId,
          'p_limit': limit,
        },
      );
      if (res == null) return [];
      final list = res is List ? res : (res as List<dynamic>? ?? []);
      final out = <LeaderboardEntry>[];
      for (final e in list) {
        if (e == null) continue;
        try {
          final map = e is Map<String, dynamic>
              ? e
              : Map<String, dynamic>.from(e as Map);
          out.add(LeaderboardEntry.fromRpcRow(map));
        } catch (_) {
          continue;
        }
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  /// First team id for the user (active membership), if any.
  Future<String?> getPrimaryTeamId(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final res = await _client
          .from('player_team_memberships')
          .select('team_id')
          .eq('player_id', userId)
          .isFilter('end_date', null)
          .limit(1)
          .maybeSingle();
      return res?['team_id']?.toString();
    } catch (_) {
      return null;
    }
  }
}
