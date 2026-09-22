import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/widgets/media_placeholders.dart';
import '../../domain/models/fixture_goal_event.dart';
import '../../domain/models/team_membership_stint.dart';
import '../../domain/models/team_model.dart';

/// Team row for onboarding discovery.
class SuggestedTeamListing {
  const SuggestedTeamListing({
    required this.team,
    required this.memberCount,
  });

  final TeamModel team;
  final int memberCount;
}

class TeamsRepository {
  TeamsRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<TeamModel?> getTeamById(String id) async {
    if (id.isEmpty) return null;
    final res = await _client
        .from('teams')
        .select(
          'id, team_name, short_form, logo_id, banner_id, created_by, created_at',
        )
        .eq('id', id)
        .maybeSingle();
    if (res == null) return null;
    return TeamModel.fromJson(Map<String, dynamic>.from(res));
  }

  Future<List<TeamModel>> getTeamsByCreator(String userId) async {
    final res = await _client
        .from('teams')
        .select(
          'id, team_name, short_form, logo_id, banner_id, created_by, created_at',
        )
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
        .eq('player_id', playerId)
        .isFilter('end_date', null);
    for (final r in ptm as List) {
      final id = (r as Map)['team_id']?.toString();
      if (id != null && id.isNotEmpty) teamIds.add(id);
    }

    if (teamIds.isEmpty) return [];
    final res = await _client
        .from('teams')
        .select(
          'id, team_name, short_form, logo_id, banner_id, created_by, created_at',
        )
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
        .update({'end_date': DateTime.now().toUtc().toIso8601String()})
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
        .select(
          'id, team_name, short_form, logo_id, banner_id, created_by, created_at',
        )
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

  /// Recent teams with active member counts for onboarding discovery.
  Future<List<SuggestedTeamListing>> getSuggestedTeams({
    int limit = 12,
    String? excludePlayerId,
  }) async {
    var query = _client
        .from('teams')
        .select(
          'id, team_name, short_form, logo_id, banner_id, created_by, created_at',
        );
    if (excludePlayerId != null && excludePlayerId.isNotEmpty) {
      query = query.neq('created_by', excludePlayerId);
    }
    final res = await query.order('created_at', ascending: false).limit(limit * 2);
    final teams = List<Map<String, dynamic>>.from(res as List)
        .map(TeamModel.fromJson)
        .where((t) => t.id.isNotEmpty)
        .toList();

    if (teams.isEmpty) return [];

    final teamIds = teams.map((t) => t.id).toList();
    final memberCounts = await _countActiveMembersByTeam(teamIds);
    final activeIds = excludePlayerId == null
        ? <String>{}
        : await getAllActiveTeamIdsForPlayer(excludePlayerId);
    final pendingIds = excludePlayerId == null
        ? <String>{}
        : await getPendingJoinRequestTeamIds(excludePlayerId, teamIds);

    final listings = <SuggestedTeamListing>[];
    for (final team in teams) {
      if (activeIds.contains(team.id) || pendingIds.contains(team.id)) {
        continue;
      }
      listings.add(
        SuggestedTeamListing(
          team: team,
          memberCount: memberCounts[team.id] ?? 0,
        ),
      );
      if (listings.length >= limit) break;
    }

    listings.sort((a, b) => b.memberCount.compareTo(a.memberCount));
    return listings;
  }

  Future<Map<String, int>> _countActiveMembersByTeam(
    List<String> teamIds,
  ) async {
    if (teamIds.isEmpty) return {};
    try {
      final res = await _client
          .from('player_team_memberships')
          .select('team_id')
          .inFilter('team_id', teamIds)
          .isFilter('end_date', null);
      final counts = <String, int>{};
      for (final row in res as List) {
        final id = (row as Map)['team_id']?.toString();
        if (id == null || id.isEmpty) continue;
        counts[id] = (counts[id] ?? 0) + 1;
      }
      return counts;
    } catch (_) {
      return {};
    }
  }

  Future<List<SuggestedTeamListing>> searchTeamsForOnboarding(
    String query, {
    int limit = 20,
    String? excludePlayerId,
  }) async {
    final teams = await searchTeams(query, limit: limit);
    if (teams.isEmpty) return [];

    final teamIds = teams.map((t) => t.id).toList();
    final memberCounts = await _countActiveMembersByTeam(teamIds);

    return teams
        .map(
          (team) => SuggestedTeamListing(
            team: team,
            memberCount: memberCounts[team.id] ?? 0,
          ),
        )
        .toList();
  }

  Future<String> createTeam({
    required String teamName,
    required String shortForm,
    String? logoId,
    required String bannerId,
    required String createdBy,
  }) async {
    final res = await _client
        .from('teams')
        .insert({
          'team_name': teamName,
          'short_form': shortForm,
          'logo_id': logoId,
          'banner_id': bannerId,
          'created_by': createdBy,
        })
        .select('id')
        .single();
    return res['id']?.toString() ?? '';
  }

  Future<void> updateTeam(
    String teamId, {
    String? teamName,
    String? shortForm,
    String? logoId,
    String? bannerId,
  }) async {
    final data = <String, dynamic>{};
    if (teamName != null) data['team_name'] = teamName;
    if (shortForm != null) data['short_form'] = shortForm;
    if (logoId != null) data['logo_id'] = logoId;
    if (bannerId != null) data['banner_id'] = bannerId;
    if (data.isEmpty) return;
    await _client.from('teams').update(data).eq('id', teamId);
  }

  Future<void> deleteTeam(String teamId) async {
    await _client.from('teams').delete().eq('id', teamId);
  }

  Future<List<Map<String, dynamic>>> getTeamPlayerStats(String teamId) async {
    final res = await _client.rpc(
      'get_team_player_stats',
      params: {'p_team_id': teamId},
    );
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<List<Map<String, dynamic>>> getTeamPlayerStatsFiltered(
    String teamId, {
    String? leagueId,
    String? seasonId,
  }) async {
    final res = await _client.rpc(
      'get_team_player_stats_filtered',
      params: {
        'p_team_id': teamId,
        'p_league_id': leagueId,
        'p_season_id': seasonId,
      },
    );
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<Map<String, dynamic>?> getTeamSummaryStats(String teamId) async {
    final res = await _client.rpc(
      'get_team_summary_stats',
      params: {'p_team_id': teamId},
    );
    // RPC returns one row (as a list with a single element).
    final list = res as List?;
    if (list == null || list.isEmpty) return null;
    return Map<String, dynamic>.from(list.first as Map);
  }

  Future<Map<String, dynamic>?> getTeamSummaryStatsFiltered(
    String teamId, {
    String? leagueId,
    String? seasonId,
  }) async {
    final res = await _client.rpc(
      'get_team_summary_stats_filtered',
      params: {
        'p_team_id': teamId,
        'p_league_id': leagueId,
        'p_season_id': seasonId,
      },
    );
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
          assetPath = resolvePlayerImagePath(imageUrl);
        }
        out.add(
          FixturePickerPlayer(
            id: pid,
            name: name,
            position: position,
            imagePath: assetPath,
            imageUrl:
                (imageUrl != null &&
                    (imageUrl.startsWith('http://') ||
                        imageUrl.startsWith('https://')))
                ? imageUrl
                : null,
          ),
        );
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  /// Top teams by favourite count (for search recommendations).
  Future<List<TeamModel>> getPopularTeams({int limit = 10}) async {
    final res = await _client
        .from('teams')
        .select(
          'id, team_name, short_form, logo_id, banner_id, favourite_count',
        )
        .order('favourite_count', ascending: false)
        .limit(limit);
    final list = List<Map<String, dynamic>>.from(res as List);
    return list.map(TeamModel.fromJson).toList();
  }

  /// Favourited teams for the signed-in user (including guests).
  Future<List<TeamModel>> getFavouritedTeamsForUser(String userId) async {
    if (userId.isEmpty) return [];
    final res = await _client
        .from('team_favourites')
        .select(
          'teams(id, team_name, short_form, logo_id, banner_id, favourite_count)',
        )
        .eq('user_id', userId)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: false);
    final out = <TeamModel>[];
    for (final row in res as List) {
      final teams = row['teams'];
      if (teams is Map) {
        out.add(TeamModel.fromJson(Map<String, dynamic>.from(teams)));
      }
    }
    return out;
  }

  Future<bool> isTeamFavourited(String teamId, {String? userId}) async {
    final uid = userId ?? _client.auth.currentUser?.id;
    if (uid == null || teamId.isEmpty) return false;
    final res = await _client
        .from('team_favourites')
        .select('id')
        .eq('user_id', uid)
        .eq('team_id', teamId)
        .maybeSingle();
    return res != null;
  }

  Future<void> addTeamFavourite(String teamId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || teamId.isEmpty) return;
    final nextOrder = await _nextTeamFavouriteSortOrder(uid);
    await _client.from('team_favourites').insert({
      'user_id': uid,
      'team_id': teamId,
      'sort_order': nextOrder,
    });
  }

  Future<int> _nextTeamFavouriteSortOrder(String userId) async {
    final res = await _client
        .from('team_favourites')
        .select('sort_order')
        .eq('user_id', userId)
        .order('sort_order', ascending: false)
        .limit(1)
        .maybeSingle();
    if (res == null) return 0;
    final current = res['sort_order'];
    if (current is int) return current + 1;
    if (current is num) return current.toInt() + 1;
    return 0;
  }

  Future<void> updateTeamFavouritesOrder(List<String> teamIdsInOrder) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || teamIdsInOrder.isEmpty) return;
    for (var i = 0; i < teamIdsInOrder.length; i++) {
      final teamId = teamIdsInOrder[i];
      if (teamId.isEmpty) continue;
      await _client
          .from('team_favourites')
          .update({'sort_order': i})
          .eq('user_id', uid)
          .eq('team_id', teamId);
    }
  }

  Future<void> removeTeamFavourite(String teamId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || teamId.isEmpty) return;
    await _client
        .from('team_favourites')
        .delete()
        .eq('user_id', uid)
        .eq('team_id', teamId);
  }

  /// Videos linked to matches this team played in.
  Future<int> getTeamVideoCount(String teamId) async {
    if (teamId.isEmpty) return 0;
    final matchARes = await _client
        .from('matches')
        .select('id')
        .eq('teamA', teamId);
    final matchBRes = await _client
        .from('matches')
        .select('id')
        .eq('teamB', teamId);
    final matchIds = <String>{};
    for (final r in matchARes as List) {
      final id = (r as Map)['id']?.toString();
      if (id != null && id.isNotEmpty) matchIds.add(id);
    }
    for (final r in matchBRes as List) {
      final id = (r as Map)['id']?.toString();
      if (id != null && id.isNotEmpty) matchIds.add(id);
    }
    if (matchIds.isEmpty) return 0;

    final videosRes = await _client
        .from('videos')
        .select('id')
        .inFilter('match_id', matchIds.toList());
    return (videosRes as List).length;
  }
}
