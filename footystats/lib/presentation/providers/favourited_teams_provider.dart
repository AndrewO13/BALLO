import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/teams_repository.dart';
import '../../domain/models/team_model.dart';

/// A team saved from the team detail or search star button.
class FavouritedTeam {
  const FavouritedTeam({
    required this.id,
    required this.name,
    this.shortForm,
    this.logoId,
    this.favouriteCount = 0,
  });

  final String id;
  final String name;
  final String? shortForm;
  final String? logoId;
  final int favouriteCount;

  factory FavouritedTeam.fromTeamModel(TeamModel team) {
    return FavouritedTeam(
      id: team.id,
      name: team.displayName,
      shortForm: team.shortForm,
      logoId: team.logoId,
      favouriteCount: team.favouriteCount,
    );
  }

  String get displayName {
    final trimmedName = name.trim();
    if (trimmedName.isNotEmpty) return trimmedName;
    final trimmedShort = shortForm?.trim();
    if (trimmedShort != null && trimmedShort.isNotEmpty) return trimmedShort;
    return '—';
  }

  String get subtitle {
    final trimmedShort = shortForm?.trim();
    if (trimmedShort != null && trimmedShort.isNotEmpty) {
      return '$trimmedShort | Football';
    }
    return 'Team | Football';
  }
}

final teamsRepositoryProvider = Provider<TeamsRepository>(
  (ref) => TeamsRepository(),
);

class FavouritedTeamsNotifier extends Notifier<List<FavouritedTeam>> {
  TeamsRepository get _repo => ref.read(teamsRepositoryProvider);

  @override
  List<FavouritedTeam> build() {
    Future.microtask(refresh);
    return [];
  }

  bool isFavourited(String id) => state.any((team) => team.id == id);

  Future<void> refresh() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      state = [];
      return;
    }
    try {
      final teams = await _repo.getFavouritedTeamsForUser(userId);
      state = teams.map(FavouritedTeam.fromTeamModel).toList();
    } catch (_) {
      // Keep existing local state on failure.
    }
  }

  Future<void> toggle(FavouritedTeam team) async {
    if (team.id.isEmpty) return;
    final wasFavourited = isFavourited(team.id);
    if (wasFavourited) {
      state = [
        for (final entry in state)
          if (entry.id != team.id) entry,
      ];
      try {
        await _repo.removeTeamFavourite(team.id);
      } catch (_) {
        state = [...state, team];
      }
      return;
    }

    state = [...state, team];
    try {
      await _repo.addTeamFavourite(team.id);
    } catch (_) {
      state = [
        for (final entry in state)
          if (entry.id != team.id) entry,
      ];
    }
  }

  Future<void> remove(String id) async {
    if (id.isEmpty) return;
    final existing = state.where((team) => team.id == id).toList();
    state = state.where((team) => team.id != id).toList();
    try {
      await _repo.removeTeamFavourite(id);
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
    _repo.updateTeamFavouritesOrder(items.map((team) => team.id).toList());
  }
}

final favouritedTeamsProvider =
    NotifierProvider<FavouritedTeamsNotifier, List<FavouritedTeam>>(
      FavouritedTeamsNotifier.new,
    );

final popularTeamsProvider = FutureProvider<List<TeamModel>>((ref) {
  return ref.read(teamsRepositoryProvider).getPopularTeams();
});
