import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/match_team_stats_snapshot.dart';
import 'matches_provider.dart';

/// Team aggregates for the Stats tab (two rows keyed by team id in the match).
final matchTeamStatsProvider = FutureProvider.autoDispose
    .family<({MatchTeamStatsSnapshot teamA, MatchTeamStatsSnapshot teamB})?, String>((
      ref,
      matchId,
    ) async {
      if (matchId.isEmpty) return null;
      final match = await ref.watch(fixtureMatchProvider(matchId).future);
      if (match == null) return null;
      final repo = ref.watch(matchesRepositoryProvider);
      return repo.getMatchTeamStatsForMatch(
        matchId,
        match.teamA.id,
        match.teamB.id,
      );
    });
