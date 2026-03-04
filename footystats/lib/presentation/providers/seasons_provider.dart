import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/seasons_repository.dart';
import '../../domain/models/season_model.dart';

final seasonsRepositoryProvider = Provider<SeasonsRepository>((ref) {
  return SeasonsRepository();
});

final currentSeasonProvider =
    FutureProvider.family<SeasonModel?, String>((ref, leagueId) async {
  final repo = ref.watch(seasonsRepositoryProvider);
  return repo.getCurrentSeasonForLeague(leagueId);
});

final ongoingOrUpcomingSeasonProvider =
    FutureProvider.family<SeasonModel?, String>((ref, leagueId) async {
  final repo = ref.watch(seasonsRepositoryProvider);
  return repo.getOngoingOrUpcomingSeasonForLeague(leagueId);
});

final allSeasonsForLeagueProvider =
    FutureProvider.family<List<SeasonModel>, String>((ref, leagueId) async {
  final repo = ref.watch(seasonsRepositoryProvider);
  return repo.getAllSeasonsForLeague(leagueId);
});
