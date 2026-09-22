import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/user_profile.dart';

const _playerProfileColumns =
    'id, username, player_name, position, image_url, country, '
    'social_instagram, social_tiktok, social_x, deleted_at, '
    'account_type, staff_role, staff_role_other, about';

/// Simple repository for reading and writing the current user's profile.
///
/// Uses the public `players` table, which is populated from `auth.users` via
/// your Supabase trigger. After account deletion the row remains as a tombstone
/// (`deleted_at` set); `id` is the stable participant key, not a live auth user.
class UserProfileRepository {
  UserProfileRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static String? _trimOrNull(String? value) {
    if (value == null) return null;
    final t = value.trim();
    return t.isEmpty ? null : t;
  }

  UserProfile _mapRow(Map<String, dynamic> map, {required String id, required String email}) {
    return UserProfile(
      id: id,
      email: email,
      username: map['username'] as String?,
      playerName: map['player_name'] as String?,
      position: map['position'] as String?,
      imageUrl: map['image_url'] as String?,
      country: map['country'] as String?,
      socialInstagram: map['social_instagram']?.toString(),
      socialTiktok: map['social_tiktok']?.toString(),
      socialX: map['social_x']?.toString(),
      deletedAt: map['deleted_at'] != null
          ? DateTime.tryParse(map['deleted_at'].toString())
          : null,
      accountType: map['account_type'] as String?,
      staffRole: map['staff_role'] as String?,
      staffRoleOther: map['staff_role_other'] as String?,
      about: map['about'] as String?,
    );
  }

  Future<UserProfile?> getCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final res = await _client
        .from('players')
        .select(_playerProfileColumns)
        .eq('id', user.id)
        .maybeSingle();

    if (res == null) {
      // No row yet in players; return a minimal profile from auth user.
      return UserProfile(
        id: user.id,
        email: user.email ?? '',
      );
    }

    return _mapRow(
      Map<String, dynamic>.from(res),
      id: user.id,
      email: user.email ?? '',
    );
  }

  /// Public `players` row for any user (e.g. leaderboard → profile). Email is empty.
  Future<UserProfile?> getProfileByPlayerId(String playerId) async {
    if (playerId.isEmpty) return null;
    final res = await _client
        .from('players')
        .select(_playerProfileColumns)
        .eq('id', playerId)
        .maybeSingle();
    if (res == null) return null;
    final map = Map<String, dynamic>.from(res);
    return _mapRow(
      map,
      id: map['id']?.toString() ?? playerId,
      email: '',
    );
  }

  Future<UserProfile> upsertCurrentProfile({
    required String username,
    required String playerName,
    String? position,
    String? imageUrl,
    String? country,
    String? socialInstagram,
    String? socialTiktok,
    String? socialX,
    bool updateSocialLinks = false,
    String? accountType,
    String? staffRole,
    String? staffRoleOther,
    bool updateStaffRole = false,
    String? about,
    bool updateAbout = false,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw AuthException('No authenticated user for profile upsert');
    }

    final payload = <String, dynamic>{
      'id': user.id,
      'username': username,
      'player_name': playerName,
    };
    if (position != null) payload['position'] = position;
    if (imageUrl != null) payload['image_url'] = imageUrl;
    if (country != null) payload['country'] = country;
    if (accountType != null) payload['account_type'] = accountType;
    if (updateStaffRole || staffRole != null) {
      payload['staff_role'] = _trimOrNull(staffRole);
      payload['staff_role_other'] = staffRole == 'other'
          ? _trimOrNull(staffRoleOther)
          : null;
    }
    if (updateSocialLinks) {
      payload['social_instagram'] = _trimOrNull(socialInstagram);
      payload['social_tiktok'] = _trimOrNull(socialTiktok);
      payload['social_x'] = _trimOrNull(socialX);
    }
    if (updateAbout || about != null) {
      payload['about'] = _trimOrNull(about);
    }

    final res = await _client
        .from('players')
        .upsert(payload)
        .select(_playerProfileColumns)
        .maybeSingle();

    if (res == null) {
      return UserProfile(
        id: user.id,
        email: user.email ?? '',
        username: username,
        playerName: playerName,
        position: position,
        imageUrl: imageUrl,
        country: country,
        socialInstagram: socialInstagram,
        socialTiktok: socialTiktok,
        socialX: socialX,
        accountType: accountType,
        staffRole: staffRole,
        staffRoleOther: staffRoleOther,
        about: about,
      );
    }

    return _mapRow(
      Map<String, dynamic>.from(res),
      id: user.id,
      email: user.email ?? '',
    );
  }
}
