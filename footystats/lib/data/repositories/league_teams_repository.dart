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
