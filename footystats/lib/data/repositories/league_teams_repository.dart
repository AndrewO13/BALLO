import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/league_team_model.dart';
import '../../domain/models/team_model.dart';

class LeagueTeamsRepository {
  LeagueTeamsRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<LeagueTeamModel>> getLeagueTeams(String leagueId) async {
    final res = await _client
        .from('league_team_memberships')
        .select('league_id, team_id, created_at')
        .eq('league_id', leagueId)
        .order('created_at', ascending: false);
    final list = List<Map<String, dynamic>>.from(res as List);
    return list.map(LeagueTeamModel.fromJson).toList();
  }

  /// Fetches all team IDs in the league (any membership row).
  /// For excluding from "add team" search.
  Future<List<String>> getTeamIdsInLeague(String leagueId) async {
    final res = await _client
        .from('league_team_memberships')
        .select('team_id')
        .eq('league_id', leagueId);
    final list = List<Map<String, dynamic>>.from(res as List);
    final ids = <String>{};
    for (final row in list) {
      final id = row['team_id']?.toString();
      if (id != null && id.isNotEmpty) ids.add(id);
    }
    return ids.toList();
  }

  /// Fetches team IDs that are actively in the league (end_date IS NULL).
  /// No duplicates. For fixture generation.
  Future<List<String>> getActiveTeamIdsForLeague(String leagueId) async {
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

  Future<List<TeamModel>> getTeamsInLeague(String leagueId) async {
    final res = await _client
        .from('league_team_memberships')
        .select('''
      team_id,
      team:teams(id, team_name, short_form, logo_id, created_by, created_at)
    ''')
        .eq('league_id', leagueId);
    final list = List<Map<String, dynamic>>.from(res as List);
    return list.map((row) {
      final teamRaw = row['team'] as Map<String, dynamic>?;
      return teamRaw != null
          ? TeamModel.fromJson(teamRaw)
          : const TeamModel(id: '', shortForm: '—');
    }).toList();
  }

  /// Fetches teams that are in any of the given leagues. Deduplicates by team.
  Future<List<TeamModel>> getTeamsInLeagues(List<String> leagueIds) async {
    if (leagueIds.isEmpty) return [];
    final res = await _client
        .from('league_team_memberships')
        .select('''
      team_id,
      team:teams(id, team_name, short_form, logo_id, created_by, created_at)
    ''')
        .inFilter('league_id', leagueIds);
    final list = List<Map<String, dynamic>>.from(res as List);
    final seen = <String>{};
    final result = <TeamModel>[];
    for (final row in list) {
      final teamRaw = row['team'] as Map<String, dynamic>?;
      if (teamRaw == null) continue;
      final id = teamRaw['id']?.toString();
      if (id == null || id.isEmpty || seen.contains(id)) continue;
      seen.add(id);
      result.add(TeamModel.fromJson(teamRaw));
    }
    result.sort((a, b) => (a.teamName ?? a.shortForm).compareTo(b.teamName ?? b.shortForm));
    return result;
  }

  Future<void> addTeamToLeague({
    required String leagueId,
    required String teamId,
    required String addedBy,
  }) async {
    await _client.from('league_team_memberships').insert({
      'league_id': leagueId,
      'team_id': teamId,
      'added_by': addedBy,
    });
  }

  Future<void> removeTeamFromLeague({
    required String leagueId,
    required String teamId,
  }) async {
    await _client
        .from('league_team_memberships')
        .delete()
        .eq('league_id', leagueId)
        .eq('team_id', teamId);
  }
}
