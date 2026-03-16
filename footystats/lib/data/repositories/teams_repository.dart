import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/fixture_goal_event.dart';
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

  /// Teams the user participates in: created by user OR member via player_team_memberships.
  Future<List<TeamModel>> getTeamsForUser(String userId) async {
    final teamIds = <String>{};

    for (final t in await getTeamsByCreator(userId)) {
      teamIds.add(t.id);
    }

    final ptm = await _client
        .from('player_team_memberships')
        .select('team_id')
        .eq('player_id', userId);
    for (final r in ptm as List) {
      final id = (r as Map)['team_id']?.toString();
      if (id != null && id.isNotEmpty) teamIds.add(id);
    }

    if (teamIds.isEmpty) return [];
    final res = await _client
        .from('teams')
        .select('id, team_name, short_form, logo_id, created_by, created_at')
        .inFilter('id', teamIds.toList())
        .order('team_name', ascending: true);
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

  /// Searches teams by team_name or short_form (case-insensitive).
  /// Returns up to [limit] results.
  Future<List<TeamModel>> searchTeams(String query, {int limit = 50}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final pattern = '%$q%';
    final res = await _client
        .from('teams')
        .select('id, team_name, short_form, logo_id, created_by, created_at')
        .or('team_name.ilike.$pattern,short_form.ilike.$pattern')
        .limit(limit)
        .order('team_name', ascending: true);
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

  /// Active squad: player_team_memberships for [teamId] where end_date IS NULL.
  /// Joins players for name, position, image_url (for goal/assist picker).
  Future<List<FixturePickerPlayer>> getActiveSquadForTeam(String teamId) async {
    if (teamId.isEmpty) return [];
    try {
      final res = await _client
          .from('player_team_memberships')
          .select(
            'player_id, players!player_team_memberships_player_id_fkey(player_name, position, image_url)',
          )
          .eq('team_id', teamId)
          .isFilter('end_date', null);
      final list = List<Map<String, dynamic>>.from(res as List);
      final out = <FixturePickerPlayer>[];
      for (final row in list) {
        final pid = row['player_id']?.toString();
        if (pid == null || pid.isEmpty) continue;
        final players = row['players'];
        String name = 'Player';
        String position = '';
        String? imageUrl;
        if (players is Map) {
          name = players['player_name']?.toString().trim().isNotEmpty == true
              ? players['player_name'].toString()
              : name;
          position = players['position']?.toString() ?? '';
          imageUrl = players['image_url']?.toString();
        }
        if (position.isEmpty) position = '—';
        // image_url may be filename only; treat as asset key if not http
        String? assetPath;
        if (imageUrl != null &&
            !imageUrl.startsWith('http://') &&
            !imageUrl.startsWith('https://')) {
          assetPath = imageUrl.contains('/')
              ? imageUrl
              : 'lib/assets/images/team logos/$imageUrl';
        }
        out.add(FixturePickerPlayer(
          id: pid,
          name: name,
          position: position,
          imagePath: assetPath,
          imageUrl: (imageUrl != null &&
                  (imageUrl.startsWith('http://') ||
                      imageUrl.startsWith('https://')))
              ? imageUrl
              : null,
        ));
      }
      return out;
    } catch (_) {
      return [];
    }
  }
}
