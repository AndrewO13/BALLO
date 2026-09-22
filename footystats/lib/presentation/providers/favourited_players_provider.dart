import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/players_repository.dart';

/// A player saved from the search star button.
class FavouritedPlayer {
  const FavouritedPlayer({
    required this.id,
    required this.name,
    this.username,
    this.imageUrl,
    this.position,
    this.favouriteCount = 0,
  });

  final String id;
  final String name;
  final String? username;
  final String? imageUrl;
  final String? position;
  final int favouriteCount;

  factory FavouritedPlayer.fromSearchModel(PlayerSearchModel player) {
    return FavouritedPlayer(
      id: player.id,
      name: player.displayName,
      username: player.username,
      imageUrl: player.imageUrl,
      position: player.position,
      favouriteCount: player.favouriteCount,
    );
  }

  String get displayName {
    final trimmedName = name.trim();
    if (trimmedName.isNotEmpty) return trimmedName;
    final trimmedUsername = username?.trim();
    if (trimmedUsername != null && trimmedUsername.isNotEmpty) {
      return trimmedUsername;
    }
    return 'Player';
  }

  String get subtitle {
    final pos = position?.trim();
    if (pos != null && pos.isNotEmpty) return '$pos | Player';
    return 'Player';
  }
}

final playersRepositoryProvider = Provider<PlayersRepository>(
  (ref) => PlayersRepository(),
);

class FavouritedPlayersNotifier extends Notifier<List<FavouritedPlayer>> {
  PlayersRepository get _repo => ref.read(playersRepositoryProvider);

  @override
  List<FavouritedPlayer> build() {
    Future.microtask(refresh);
    return [];
  }

  bool isFavourited(String id) => state.any((player) => player.id == id);

  Future<void> refresh() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      state = [];
      return;
    }
    try {
      final players = await _repo.getFavouritedPlayersForUser(userId);
      state = players.map(FavouritedPlayer.fromSearchModel).toList();
    } catch (_) {
      // Keep existing local state on failure.
    }
  }

  Future<void> toggle(FavouritedPlayer player) async {
    if (player.id.isEmpty) return;
    final wasFavourited = isFavourited(player.id);
    if (wasFavourited) {
      state = [
        for (final entry in state)
          if (entry.id != player.id) entry,
      ];
      try {
        await _repo.removePlayerFavourite(player.id);
      } catch (_) {
        state = [...state, player];
      }
      return;
    }

    state = [...state, player];
    try {
      await _repo.addPlayerFavourite(player.id);
    } catch (_) {
      state = [
        for (final entry in state)
          if (entry.id != player.id) entry,
      ];
    }
  }

  Future<void> remove(String id) async {
    if (id.isEmpty) return;
    final existing = state.where((player) => player.id == id).toList();
    state = state.where((player) => player.id != id).toList();
    try {
      await _repo.removePlayerFavourite(id);
    } catch (_) {
      if (existing.isNotEmpty) {
        state = [...state, ...existing];
      }
    }
  }

  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        newIndex < 0 ||
        oldIndex >= state.length ||
        newIndex >= state.length ||
        oldIndex == newIndex) {
      return;
    }
    final items = [...state];
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    state = items;
    _repo.updatePlayerFavouritesOrder(items.map((player) => player.id).toList());
  }
}

final favouritedPlayersProvider =
    NotifierProvider<FavouritedPlayersNotifier, List<FavouritedPlayer>>(
      FavouritedPlayersNotifier.new,
    );

final popularPlayersProvider = FutureProvider<List<PlayerSearchModel>>((ref) {
  return ref.read(playersRepositoryProvider).getPopularPlayers();
});
