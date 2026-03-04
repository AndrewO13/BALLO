import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/league_application_model.dart';

class LeagueApplicationsRepository {
  LeagueApplicationsRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<LeagueApplicationModel>> getApplicationsForLeague(
    String leagueId, {
    String? status,
  }) async {
    var query = _client
        .from('league_team_join_requests')
        .select(
          'id, league_id, team_id, status, requested_by, created_at',
        )
        .eq('league_id', leagueId);
    if (status != null) {
      query = query.eq('status', status);
    }
    final res = await query.order('created_at', ascending: false);
    final list = List<Map<String, dynamic>>.from(res as List);
    return list.map(LeagueApplicationModel.fromJson).toList();
  }

  /// Fetches pending applications with embedded team data for the manage UI.
  Future<List<Map<String, dynamic>>> getPendingApplicationsWithTeams(
    String leagueId,
  ) async {
    final res = await _client
        .from('league_team_join_requests')
        .select(
          'id, league_id, team_id, status, requested_by, created_at, '
          'team:teams(id, team_name, short_form, logo_id)',
        )
        .eq('league_id', leagueId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res as List);
  }

  /// Fetches rejected applications with embedded team data.
  Future<List<Map<String, dynamic>>> getRejectedApplicationsWithTeams(
    String leagueId,
  ) async {
    final res = await _client
        .from('league_team_join_requests')
        .select(
          'id, league_id, team_id, status, requested_by, created_at, '
          'team:teams(id, team_name, short_form, logo_id)',
        )
        .eq('league_id', leagueId)
        .eq('status', 'rejected')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<String> applyToLeague({
    required String leagueId,
    required String teamId,
    required String createdBy,
  }) async {
    final res = await _client
        .from('league_team_join_requests')
        .insert({
          'league_id': leagueId,
          'team_id': teamId,
          'requested_by': createdBy,
          'status': 'pending',
        })
        .select('id')
        .single();
    return res['id']?.toString() ?? '';
  }

  Future<void> reviewApplication({
    required String applicationId,
    required String status, // accepted | rejected
    required String reviewedBy,
  }) async {
    await _client
        .from('league_team_join_requests')
        .update({'status': status})
        .eq('id', applicationId);
  }
}
