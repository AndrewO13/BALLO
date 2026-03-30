import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/user_profile.dart';

/// Simple repository for reading and writing the current user's profile.
///
/// Uses the public `players` table, which is populated from `auth.users` via
/// your Supabase trigger. Expected columns:
/// - id (uuid, primary key, references auth.users.id)
/// - username (text, nullable)
/// - player_name (text, nullable)
/// - position (text, nullable)
/// - image_url (text, nullable)
class UserProfileRepository {
  UserProfileRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<UserProfile?> getCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final res = await _client
        .from('players')
        .select('id, username, player_name, position, image_url, country')
        .eq('id', user.id)
        .maybeSingle();

    if (res == null) {
      // No row yet in players; return a minimal profile from auth user.
      return UserProfile(
        id: user.id,
        email: user.email ?? '',
      );
    }

    final map = Map<String, dynamic>.from(res);
    return UserProfile(
      id: user.id,
      email: user.email ?? '',
      username: map['username'] as String?,
      playerName: map['player_name'] as String?,
      position: map['position'] as String?,
      imageUrl: map['image_url'] as String?,
      country: map['country'] as String?,
    );
  }

  Future<UserProfile> upsertCurrentProfile({
    required String username,
    required String playerName,
    String? position,
    String? imageUrl,
    String? country,
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

    final res = await _client
        .from('players')
        .upsert(payload)
        .select('id, username, player_name')
        .maybeSingle();

    if (res == null) {
      return UserProfile(
        id: user.id,
        email: user.email ?? '',
        username: username,
        playerName: playerName,
      );
    }

    final map = Map<String, dynamic>.from(res);
    return UserProfile(
      id: user.id,
      email: user.email ?? '',
      username: map['username'] as String?,
      playerName: map['player_name'] as String?,
    );
  }
}

