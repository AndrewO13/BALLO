import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/managed_player.dart';

class ManagedPlayersException implements Exception {
  const ManagedPlayersException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ManagedPlayersRepository {
  ManagedPlayersRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _columns =
      'id, player_name, username, position, image_url, login_enabled_at, created_at';

  Future<List<ManagedPlayer>> listCreatedByCurrentUser() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];

    final rows = await _client
        .from('players')
        .select(_columns)
        .eq('created_by', uid)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);

    return (rows as List)
        .whereType<Map>()
        .map((row) => ManagedPlayer.fromJson(Map<String, dynamic>.from(row)))
        .where((player) => player.id.isNotEmpty)
        .toList();
  }

  Future<List<ManagedPlayer>> createPlayers(
    List<ManagedPlayerDraftInput> players,
  ) async {
    final data = await _invoke({
      'action': 'create',
      'players': players.map((p) => p.toJson()).toList(),
    });
    final raw = data['players'];
    if (raw is! List) {
      throw const ManagedPlayersException('Could not create players');
    }
    return raw
        .whereType<Map>()
        .map((row) => ManagedPlayer.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<ManagedPlayer> updatePlayer({
    required String playerId,
    required ManagedPlayerDraftInput details,
  }) async {
    final data = await _invoke({
      'action': 'update',
      'player_id': playerId,
      ...details.toJson(),
    });
    final raw = data['player'];
    if (raw is! Map) {
      throw const ManagedPlayersException('Could not update this player');
    }
    return ManagedPlayer.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<void> enableLogin({
    required String playerId,
    required String email,
    required String password,
  }) async {
    await _invoke({
      'action': 'enable_login',
      'player_id': playerId,
      'email': email,
      'password': password,
    });
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    final token = _client.auth.currentSession?.accessToken;
    try {
      final response = await _client.functions.invoke(
        'manage-created-players',
        body: body,
        headers: {
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        if (data['error'] != null) {
          throw ManagedPlayersException(data['error'].toString());
        }
        return data;
      }
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        if (map['error'] != null) {
          throw ManagedPlayersException(map['error'].toString());
        }
        return map;
      }
      throw const ManagedPlayersException('Unexpected response');
    } on FunctionException catch (e) {
      throw ManagedPlayersException(_messageFromDetails(e.details));
    }
  }

  static String _messageFromDetails(Object? details) {
    if (details is Map && details['error'] != null) {
      return details['error'].toString();
    }
    return 'Could not update player accounts. Please try again.';
  }
}
