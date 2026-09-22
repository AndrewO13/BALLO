import 'package:supabase_flutter/supabase_flutter.dart';

/// Lightweight player row for search and favourites.
class PlayerSearchModel {
  const PlayerSearchModel({
    required this.id,
    required this.displayName,
    this.username,
    this.imageUrl,
    this.position,
    this.favouriteCount = 0,
    this.teamLogoId,
  });

  final String id;
  final String displayName;
  final String? username;
  final String? imageUrl;
  final String? position;
  final int favouriteCount;
  final String? teamLogoId;

  factory PlayerSearchModel.fromJson(Map<String, dynamic> json) {
    final playerName = json['player_name']?.toString().trim();
    final username = json['username']?.toString().trim();
    final displayName = (playerName != null && playerName.isNotEmpty)
        ? playerName
        : ((username != null && username.isNotEmpty) ? username : 'Player');
    return PlayerSearchModel(
      id: json['id']?.toString() ?? '',
      displayName: displayName,
      username: username,
      imageUrl: json['image_url']?.toString(),
      position: json['position']?.toString(),
      favouriteCount: _parseInt(json['favourite_count']),
      teamLogoId: _teamLogoIdFromJson(json),
    );
  }

  String get subtitle {
    final pos = position?.trim();
    if (pos != null && pos.isNotEmpty) return '$pos | Player';
    return 'Player';
  }
}

int _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String? _teamLogoIdFromJson(Map<String, dynamic> json) {
  final memberships = json['player_team_memberships'];
  if (memberships is! List) return null;

  String? pickLogo(Map<dynamic, dynamic> membership) {
    final teams = membership['teams'];
    if (teams is! Map) return null;
    final logoId = teams['logo_id']?.toString().trim();
    return (logoId != null && logoId.isNotEmpty) ? logoId : null;
  }

  for (final entry in memberships) {
    if (entry is! Map) continue;
    if (entry['end_date'] != null) continue;
    final logoId = pickLogo(entry);
    if (logoId != null) return logoId;
  }

  for (final entry in memberships) {
    if (entry is! Map) continue;
    final logoId = pickLogo(entry);
    if (logoId != null) return logoId;
  }

  return null;
}

class PlayersRepository {
  PlayersRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Top players by favourite count (for search recommendations).
  Future<List<PlayerSearchModel>> getPopularPlayers({int limit = 10}) async {
    final res = await _client
        .from('players')
        .select(
          'id, player_name, username, image_url, position, favourite_count, '
          'player_team_memberships(end_date, teams(logo_id))',
        )
        .isFilter('deleted_at', null)
        .order('favourite_count', ascending: false)
        .limit(limit);
    final list = List<Map<String, dynamic>>.from(res as List);
    return list.map(PlayerSearchModel.fromJson).toList();
  }

  /// Favourited players for the signed-in user.
  Future<List<PlayerSearchModel>> getFavouritedPlayersForUser(
    String userId,
  ) async {
    if (userId.isEmpty) return [];
    final res = await _client
        .from('player_favourites')
        .select(
          'players(id, player_name, username, image_url, position, favourite_count)',
        )
        .eq('user_id', userId)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: false);
    final out = <PlayerSearchModel>[];
    for (final row in res as List) {
      final players = row['players'];
      if (players is Map) {
        out.add(PlayerSearchModel.fromJson(Map<String, dynamic>.from(players)));
      }
    }
    return out;
  }

  Future<void> addPlayerFavourite(String playerId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || playerId.isEmpty) return;
    final nextOrder = await _nextPlayerFavouriteSortOrder(uid);
    await _client.from('player_favourites').insert({
      'user_id': uid,
      'player_id': playerId,
      'sort_order': nextOrder,
    });
  }

  Future<int> _nextPlayerFavouriteSortOrder(String userId) async {
    final res = await _client
        .from('player_favourites')
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

  Future<void> updatePlayerFavouritesOrder(List<String> playerIdsInOrder) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || playerIdsInOrder.isEmpty) return;
    for (var i = 0; i < playerIdsInOrder.length; i++) {
      final playerId = playerIdsInOrder[i];
      if (playerId.isEmpty) continue;
      await _client
          .from('player_favourites')
          .update({'sort_order': i})
          .eq('user_id', uid)
          .eq('player_id', playerId);
    }
  }

  Future<void> removePlayerFavourite(String playerId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || playerId.isEmpty) return;
    await _client
        .from('player_favourites')
        .delete()
        .eq('user_id', uid)
        .eq('player_id', playerId);
  }
}
