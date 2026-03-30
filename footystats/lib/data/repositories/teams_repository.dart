import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/fixture_goal_event.dart';
import '../../domain/models/team_membership_stint.dart';
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

  /// Teams the player is linked to: created by them OR any `player_team_memberships` row.
  Future<List<TeamModel>> getTeamsForPlayer(String playerId) async {
    if (playerId.isEmpty) return [];
    final teamIds = <String>{};

    for (final t in await getTeamsByCreator(playerId)) {
      teamIds.add(t.id);
    }

    final ptm = await _client
        .from('player_team_memberships')
        .select('team_id')
        .eq('player_id', playerId);
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

  /// Teams the user participates in: created by user OR member via player_team_memberships.
  Future<List<TeamModel>> getTeamsForUser(String userId) =>
      getTeamsForPlayer(userId);

  /// All team memberships for [playerId] (current and past), newest activity first.
  Future<List<TeamMembershipStint>> getMembershipHistoryForPlayer(
    String playerId,
  ) async {
    if (playerId.isEmpty) return [];
    try {
      final res = await _client
          .from('player_team_memberships')
          .select(
            'created_at, end_date, '
            'teams(id, team_name, short_form, logo_id)',
          )
          .eq('player_id', playerId)
          .order('created_at', ascending: false);
      final list = List<Map<String, dynamic>>.from(res as List);
      final out = <TeamMembershipStint>[];
      for (final row in list) {
        final teams = row['teams'];
        if (teams is! Map) continue;
        final tid = teams['id']?.toString();
        if (tid == null || tid.isEmpty) continue;
        out.add(
          TeamMembershipStint(
            teamId: tid,
            teamName: teams['team_name']?.toString(),
            shortForm: teams['short_form']?.toString(),
            logoId: teams['logo_id']?.toString(),
            createdAt: _parseDate(row['created_at']),
            endDate: _parseDate(row['end_date']),
          ),
        );
      }
      out.sort((a, b) {
        if (a.isCurrent != b.isCurrent) return a.isCurrent ? -1 : 1;
        final ac = a.createdAt;
        final bc = b.createdAt;
        if (ac == null && bc == null) return 0;
        if (ac == null) return 1;
        if (bc == null) return -1;
        return bc.compareTo(ac);
      });
      return out;
    } catch (_) {
      return [];
    }
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  /// Sets [endDate] on an active membership (leave team).
  Future<void> leaveTeam({
    required String playerId,
    required String teamId,
  }) async {
    await _client
        .from('player_team_memberships')
        .update({
          'end_date': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('player_id', playerId)
        .eq('team_id', teamId)
        .isFilter('end_date', null);
  }

  /// Inserts a pending join request (same flow as team detail).
  Future<void> sendTeamJoinRequest({
    required String playerId,
    required String teamId,
  }) async {
    await _client.from('team_join_requests').insert({
      'team_id': teamId,
      'player_id': playerId,
    });
  }

  /// Team IDs where [playerId] has an active membership (`end_date` IS NULL).
  Future<Set<String>> getActiveTeamIdsForPlayer(
    String playerId,
    List<String> teamIds,
  ) async {
    if (playerId.isEmpty || teamIds.isEmpty) return {};
    try {
      final res = await _client
          .from('player_team_memberships')
          .select('team_id')
          .eq('player_id', playerId)
          .inFilter('team_id', teamIds)
          .isFilter('end_date', null);
      final out = <String>{};
      for (final r in res as List) {
        final id = (r as Map)['team_id']?.toString();
        if (id != null && id.isNotEmpty) out.add(id);
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  /// All active team IDs for [playerId] (`end_date` IS NULL).
  Future<Set<String>> getAllActiveTeamIdsForPlayer(String playerId) async {
    if (playerId.isEmpty) return {};
    try {
      final res = await _client
          .from('player_team_memberships')
          .select('team_id')
          .eq('player_id', playerId)
          .isFilter('end_date', null);
      final out = <String>{};
      for (final r in res as List) {
        final id = (r as Map)['team_id']?.toString();
        if (id != null && id.isNotEmpty) out.add(id);
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  /// Team IDs with a **pending** join request for [playerId].
  Future<Set<String>> getPendingJoinRequestTeamIds(
    String playerId,
    List<String> teamIds,
  ) async {
    if (playerId.isEmpty || teamIds.isEmpty) return {};
    try {
      final res = await _client
          .from('team_join_requests')
          .select('team_id')
          .eq('player_id', playerId)
          .eq('status', 'pending')
          .inFilter('team_id', teamIds);
      final out = <String>{};
      for (final r in res as List) {
        final id = (r as Map)['team_id']?.toString();
        if (id != null && id.isNotEmpty) out.add(id);
      }
      return out;
    } catch (_) {
      return {};
    }
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

  Future<List<Map<String, dynamic>>> getTeamPlayerStats(String teamId) async {
    final res = await _client.rpc('get_team_player_stats', params: {
      'p_team_id': teamId,
    });
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<Map<String, dynamic>?> getTeamSummaryStats(String teamId) async {
    final res = await _client.rpc('get_team_summary_stats', params: {
      'p_team_id': teamId,
    });
    // RPC returns one row (as a list with a single element).
    final list = res as List?;
    if (list == null || list.isEmpty) return null;
    return Map<String, dynamic>.from(list.first as Map);
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
