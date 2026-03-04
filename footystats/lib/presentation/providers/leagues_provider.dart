import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/leagues_repository.dart';
import '../../domain/models/league_model.dart';

final leaguesRepositoryProvider = Provider<LeaguesRepository>((ref) {
  return LeaguesRepository();
});

final leagueByIdProvider =
    FutureProvider.family<LeagueModel?, String>((ref, leagueId) async {
  final repo = ref.watch(leaguesRepositoryProvider);
  return repo.getLeagueById(leagueId);
});

final leaguesByCreatorProvider =
    FutureProvider.family<List<LeagueModel>, String>((ref, userId) async {
  final repo = ref.watch(leaguesRepositoryProvider);
  return repo.getLeaguesByCreator(userId);
});
