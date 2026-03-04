import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/league_applications_repository.dart';
import '../../domain/models/league_application_model.dart';

final leagueApplicationsRepositoryProvider =
    Provider<LeagueApplicationsRepository>((ref) {
      return LeagueApplicationsRepository();
    });

final leagueApplicationsProvider =
    FutureProvider.family<List<LeagueApplicationModel>, String>((
      ref,
      leagueId,
    ) async {
      final repo = ref.watch(leagueApplicationsRepositoryProvider);
      return repo.getApplicationsForLeague(leagueId);
    });

final leaguePendingApplicationsWithTeamsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, leagueId) async {
      final repo = ref.watch(leagueApplicationsRepositoryProvider);
      return repo.getPendingApplicationsWithTeams(leagueId);
    });

final leagueRejectedApplicationsWithTeamsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, leagueId) async {
      final repo = ref.watch(leagueApplicationsRepositoryProvider);
      return repo.getRejectedApplicationsWithTeams(leagueId);
    });
