import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/league_model.dart';

class LeaguesRepository {
  LeaguesRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<LeagueModel?> getLeagueById(String id) async {
    if (id.isEmpty) return null;
    final res = await _client
        .from('leagues')
        .select('id, league_name, logo_id, created_by, created_at')
        .eq('id', id)
        .maybeSingle();
    if (res == null) return null;
    return LeagueModel.fromJson(Map<String, dynamic>.from(res));
  }

  Future<List<LeagueModel>> getLeaguesByCreator(String userId) async {
    final res = await _client
        .from('leagues')
        .select('id, league_name, logo_id, created_by, created_at')
        .eq('created_by', userId)
        .order('created_at', ascending: false);
    final list = List<Map<String, dynamic>>.from(res as List);
    return list.map(LeagueModel.fromJson).toList();
  }

  Future<String> createLeague({
    required String leagueName,
    String? logoId,
    required String createdBy,
  }) async {
    final res = await _client.from('leagues').insert({
      'league_name': leagueName,
      'logo_id': logoId,
      'created_by': createdBy,
    }).select('id').single();
    return res['id']?.toString() ?? '';
  }

  Future<void> updateLeague(
    String leagueId, {
    String? leagueName,
    String? logoId,
  }) async {
    final data = <String, dynamic>{};
    if (leagueName != null) data['league_name'] = leagueName;
    if (logoId != null) data['logo_id'] = logoId;
    if (data.isEmpty) return;
    await _client.from('leagues').update(data).eq('id', leagueId);
  }

  Future<void> deleteLeague(String leagueId) async {
    await _client.from('leagues').delete().eq('id', leagueId);
  }
}
