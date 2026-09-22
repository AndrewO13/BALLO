import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/guest_mode.dart';
import '../../domain/models/scout_profile_viewer.dart';
import '../../domain/models/user_profile.dart';

/// Records and lists scout visits on a profile (TikTok-style viewer history).
class ProfileScoutViewsRepository {
  ProfileScoutViewsRepository({
    SupabaseClient? client,
  }) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<void> recordViewIfScout(String viewedUserId) async {
    if (GuestMode.isGuest) return;
    final scoutId = _client.auth.currentUser?.id;
    if (scoutId == null || scoutId.isEmpty || scoutId == viewedUserId) return;

    try {
      await _client.rpc(
        'record_profile_scout_view',
        params: {'p_viewed_player_id': viewedUserId},
      );
    } catch (_) {
      // Viewing must never fail because analytics could not be written.
    }
  }

  Future<List<ScoutProfileViewer>> listViewersOfCurrentUser() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return const [];

    final rows = await _client
        .from('profile_scout_views')
        .select('scout_id, last_viewed_at')
        .eq('viewed_player_id', userId)
        .order('last_viewed_at', ascending: false);

    final list = List<Map<String, dynamic>>.from(rows as List);
    if (list.isEmpty) return const [];

    final scoutIds = list
        .map((row) => row['scout_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    final profiles = await _client
        .from('players')
        .select(
          'id, player_name, username, image_url, staff_role, staff_role_other, '
          'account_type, deleted_at',
        )
        .inFilter('id', scoutIds);

    final byId = <String, UserProfile>{};
    for (final raw in (profiles as List).whereType<Map>()) {
      final map = Map<String, dynamic>.from(raw);
      final profile = UserProfile.fromJson(map);
      if (profile.isDeleted || !profile.isScout) continue;
      byId[profile.id] = profile;
    }

    final viewers = <ScoutProfileViewer>[];
    for (final row in list) {
      final scoutId = row['scout_id']?.toString() ?? '';
      final profile = byId[scoutId];
      if (profile == null) continue;
      viewers.add(
        ScoutProfileViewer(
          id: profile.id,
          displayName: (profile.playerName?.trim().isNotEmpty ?? false)
              ? profile.playerName!.trim()
              : (profile.username?.trim().isNotEmpty ?? false)
                  ? profile.username!.trim()
                  : 'Scout',
          username: profile.username,
          imageUrl: profile.imageUrl,
          staffRoleOther: profile.staffRoleOther,
          lastViewedAt: DateTime.tryParse(
                row['last_viewed_at']?.toString() ?? '',
              ) ??
              DateTime.now(),
        ),
      );
    }
    return viewers;
  }

  Stream<int> unreadCountForCurrentUser() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      return Stream<int>.value(0);
    }
    return _client
        .from('profile_scout_views')
        .stream(primaryKey: ['id'])
        .eq('viewed_player_id', userId)
        .map((rows) {
          return rows.where((row) => row['seen_by_player_at'] == null).length;
        });
  }

  Future<void> markAllSeenForCurrentUser() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return;
    try {
      await _client.rpc('mark_profile_scout_views_seen');
    } catch (_) {}
  }
}
