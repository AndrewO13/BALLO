import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/matches_repository.dart';
import '../../domain/models/fixture_match_rated_player.dart';
import 'matches_provider.dart';

/// Per-match player ratings from `match_player_stats` (after `apply_match_ratings` / finalize).
final fixtureMatchRatingsProvider = FutureProvider.autoDispose
    .family<List<FixtureMatchRatedPlayer>, String>((ref, matchId) async {
      if (matchId.isEmpty) return [];
      final repo = ref.watch(matchesRepositoryProvider);
      return repo.getMatchPlayerRatingsRanked(matchId);
    });
