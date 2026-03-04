import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/team_model.dart';

class TeamsRepository {
  TeamsRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<TeamModel?> getTeamById(String id) async {
    if (id.isEmpty) return null;
    final res = await _client
        .from('teams')
        .select('id, team_name, short_form, logo_id, created_by, created_at')
        .eq('id', id)
        .maybeSingle();
    if (res == null) return null;
    return TeamModel.fromJson(Map<String, dynamic>.from(res));
  }

  Future<List<TeamModel>> getTeamsByCreator(String userId) async {
    final res = await _client
        .from('teams')
        .select('id, team_name, short_form, logo_id, created_by, created_at')
        .eq('created_by', userId)
        .order('created_at', ascending: false);
    final list = List<Map<String, dynamic>>.from(res as List);
    return list.map(TeamModel.fromJson).toList();
  }

  Future<List<TeamModel>> getAllTeams() async {
    final res = await _client
        .from('teams')
        .select('id, team_name, short_form, logo_id, created_by, created_at')
        .order('created_at', ascending: false);
    final list = List<Map<String, dynamic>>.from(res as List);
    return list.map(TeamModel.fromJson).toList();
  }

  Future<String> createTeam({
    required String teamName,
    required String shortForm,
    String? logoId,
    required String createdBy,
  }) async {
    final res = await _client.from('teams').insert({
      'team_name': teamName,
      'short_form': shortForm,
      'logo_id': logoId,
      'created_by': createdBy,
    }).select('id').single();
    return res['id']?.toString() ?? '';
  }

  Future<void> updateTeam(
    String teamId, {
    String? teamName,
    String? shortForm,
    String? logoId,
  }) async {
    final data = <String, dynamic>{};
    if (teamName != null) data['team_name'] = teamName;
    if (shortForm != null) data['short_form'] = shortForm;
    if (logoId != null) data['logo_id'] = logoId;
    if (data.isEmpty) return;
    await _client.from('teams').update(data).eq('id', teamId);
  }

  Future<void> deleteTeam(String teamId) async {
    await _client.from('teams').delete().eq('id', teamId);
  }
}
