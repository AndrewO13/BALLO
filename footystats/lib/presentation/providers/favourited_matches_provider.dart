import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/matches_repository.dart';
import '../../domain/models/match_model.dart';
import 'matches_provider.dart';

/// A match saved from the fixture page star button (guest accounts).
class FavouritedMatch {
  const FavouritedMatch({required this.match});

  final MatchModel match;

  String get id => match.id;

  String get title {
    final home = match.teamA.shortForm.trim();
    final away = match.teamB.shortForm.trim();
    if (home.isNotEmpty && away.isNotEmpty) return '$home vs $away';
    if (home.isNotEmpty) return home;
    if (away.isNotEmpty) return away;
    return 'Match';
  }

  String get subtitle {
    final league = match.leagueName?.trim();
    final date = match.matchDate;
    final dateKey =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final dateLabel = formatMatchDateKey(dateKey);
    if (league != null && league.isNotEmpty) {
      return '$league · $dateLabel';
    }
    return dateLabel;
  }

  String? get leagueLogoId => match.leagueLogoId;

  factory FavouritedMatch.fromMatchModel(MatchModel match) {
    return FavouritedMatch(match: match);
  }
}

class FavouritedMatchesNotifier extends Notifier<List<FavouritedMatch>> {
  MatchesRepository get _repo => ref.read(matchesRepositoryProvider);

  @override
  List<FavouritedMatch> build() {
    Future.microtask(refresh);
    return [];
  }

  bool isFavourited(String id) => state.any((match) => match.id == id);

  Future<void> refresh() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      state = [];
      return;
    }
    try {
      final matches = await _repo.getFavouritedMatchesForUser(userId);
      state = matches.map(FavouritedMatch.fromMatchModel).toList();
    } catch (_) {
      // Keep existing local state on failure.
    }
  }

  Future<void> toggle(FavouritedMatch favourite) async {
    if (favourite.id.isEmpty) return;
    final wasFavourited = isFavourited(favourite.id);
    if (wasFavourited) {
      state = [
        for (final entry in state)
          if (entry.id != favourite.id) entry,
      ];
      try {
        await _repo.removeMatchFavourite(favourite.id);
      } catch (_) {
        state = [...state, favourite];
      }
      return;
    }

    state = [...state, favourite];
    try {
      await _repo.addMatchFavourite(favourite.id);
    } catch (_) {
      state = [
        for (final entry in state)
          if (entry.id != favourite.id) entry,
      ];
    }
  }

  Future<void> remove(String id) async {
    if (id.isEmpty) return;
    final existing = state.where((match) => match.id == id).toList();
    state = state.where((match) => match.id != id).toList();
    try {
      await _repo.removeMatchFavourite(id);
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
    _repo.updateMatchFavouritesOrder(items.map((match) => match.id).toList());
  }
}

final favouritedMatchesProvider =
    NotifierProvider<FavouritedMatchesNotifier, List<FavouritedMatch>>(
      FavouritedMatchesNotifier.new,
    );
