import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/leagues_repository.dart';
import '../../domain/models/league_model.dart';

/// A league saved from search or the matches list star button.
class FavouritedLeague {
  const FavouritedLeague({
    required this.id,
    required this.name,
    this.country,
    this.logoId,
    this.favouriteCount = 0,
  });

  final String id;
  final String name;
  final String? country;
  final String? logoId;
  final int favouriteCount;

  factory FavouritedLeague.fromLeagueModel(LeagueModel league) {
    return FavouritedLeague(
      id: league.id,
      name: league.leagueName,
      country: league.country,
      logoId: league.logoId,
    );
  }
}

final leaguesRepositoryProvider = Provider<LeaguesRepository>(
  (ref) => LeaguesRepository(),
);

class FavouritedLeaguesNotifier extends Notifier<List<FavouritedLeague>> {
  LeaguesRepository get _repo => ref.read(leaguesRepositoryProvider);

  @override
  List<FavouritedLeague> build() {
    Future.microtask(refresh);
    return [];
  }

  bool isFavourited(String id) => state.any((league) => league.id == id);

  Future<void> refresh() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      state = [];
      return;
    }
    try {
      final leagues = await _repo.getFavouritedLeaguesForUser(userId);
      state = leagues
          .map(
            (league) => FavouritedLeague(
              id: league.id,
              name: league.leagueName,
              country: league.country,
              logoId: league.logoId,
            ),
          )
          .toList();
    } catch (_) {
      // Keep existing local state on failure.
    }
  }

  Future<void> toggle(FavouritedLeague league) async {
    if (league.id.isEmpty) return;
    final wasFavourited = isFavourited(league.id);
    if (wasFavourited) {
      state = [
        for (final entry in state)
          if (entry.id != league.id) entry,
      ];
      try {
        await _repo.removeLeagueFavourite(league.id);
      } catch (_) {
        state = [...state, league];
      }
      return;
    }

    state = [...state, league];
    try {
      await _repo.addLeagueFavourite(league.id);
    } catch (_) {
      state = [
        for (final entry in state)
          if (entry.id != league.id) entry,
      ];
    }
  }

  Future<void> remove(String id) async {
    if (id.isEmpty) return;
    final existing = state.where((league) => league.id == id).toList();
    state = state.where((league) => league.id != id).toList();
    try {
      await _repo.removeLeagueFavourite(id);
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
    _repo.updateLeagueFavouritesOrder(items.map((league) => league.id).toList());
  }
}

final favouritedLeaguesProvider =
    NotifierProvider<FavouritedLeaguesNotifier, List<FavouritedLeague>>(
      FavouritedLeaguesNotifier.new,
    );

final popularLeaguesProvider = FutureProvider<List<LeagueModel>>((ref) {
  return ref.read(leaguesRepositoryProvider).getPopularLeagues();
});

class FavouritesEditModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;

  void set(bool value) => state = value;
}

final favouritesEditModeProvider =
    NotifierProvider<FavouritesEditModeNotifier, bool>(
      FavouritesEditModeNotifier.new,
    );
