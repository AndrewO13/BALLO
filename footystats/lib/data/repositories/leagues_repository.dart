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
        .select(
            'id, league_name, logo_id, created_by, created_at, '
            'default_venue, default_venue_image_url')
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

  /// Leagues the user participates in: created by user OR has a team in the league
  /// (user is a player on a team that is in the league via league_team_memberships).
  Future<List<LeagueModel>> getLeaguesForUser(String userId) async {
    final leagueIds = <String>{};

    // Leagues created by user
    final created = await getLeaguesByCreator(userId);
    for (final l in created) {
      leagueIds.add(l.id);
    }

    // Leagues where user's team is a member (user -> player_team_memberships -> team -> league_team_memberships)
    final ptm = await _client
        .from('player_team_memberships')
        .select('team_id')
        .eq('player_id', userId);
    final teamIds = (ptm as List)
        .map((r) => (r as Map)['team_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (teamIds.isNotEmpty) {
      final ltm = await _client
          .from('league_team_memberships')
          .select('league_id')
          .inFilter('team_id', teamIds);
      for (final r in ltm as List) {
        final id = (r as Map)['league_id']?.toString();
        if (id != null && id.isNotEmpty) leagueIds.add(id);
      }
    }

    if (leagueIds.isEmpty) return [];
    final res = await _client
        .from('leagues')
        .select('id, league_name, logo_id, created_by, created_at')
        .inFilter('id', leagueIds.toList())
        .order('league_name', ascending: true);
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
    String? defaultVenue,
    String? defaultVenueImageUrl,
  }) async {
    final data = <String, dynamic>{};
    if (leagueName != null) data['league_name'] = leagueName;
    if (logoId != null) data['logo_id'] = logoId;
    if (defaultVenue != null) data['default_venue'] = defaultVenue;
    if (defaultVenueImageUrl != null) {
      data['default_venue_image_url'] = defaultVenueImageUrl;
    }
    if (data.isEmpty) return;
    await _client.from('leagues').update(data).eq('id', leagueId);
  }

  Future<void> deleteLeague(String leagueId) async {
    await _client.from('leagues').delete().eq('id', leagueId);
  }
}
