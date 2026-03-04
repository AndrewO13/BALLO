import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/league_teams_repository.dart';
import '../../domain/models/league_team_model.dart';
import '../../domain/models/team_model.dart';

final leagueTeamsRepositoryProvider = Provider<LeagueTeamsRepository>((ref) {
  return LeagueTeamsRepository();
});

final leagueTeamsProvider =
    FutureProvider.family<List<LeagueTeamModel>, String>((ref, leagueId) async {
  final repo = ref.watch(leagueTeamsRepositoryProvider);
  return repo.getLeagueTeams(leagueId);
});

final teamsInLeagueProvider =
    FutureProvider.family<List<TeamModel>, String>((ref, leagueId) async {
  final repo = ref.watch(leagueTeamsRepositoryProvider);
  return repo.getTeamsInLeague(leagueId);
});
