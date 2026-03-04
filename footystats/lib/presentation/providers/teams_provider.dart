import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/teams_repository.dart';
import '../../domain/models/team_model.dart';

final teamsRepositoryProvider = Provider<TeamsRepository>((ref) {
  return TeamsRepository();
});

final teamByIdProvider =
    FutureProvider.family<TeamModel?, String>((ref, teamId) async {
  final repo = ref.watch(teamsRepositoryProvider);
  return repo.getTeamById(teamId);
});

final teamsByCreatorProvider =
    FutureProvider.family<List<TeamModel>, String>((ref, userId) async {
  final repo = ref.watch(teamsRepositoryProvider);
  return repo.getTeamsByCreator(userId);
});

final allTeamsProvider = FutureProvider<List<TeamModel>>((ref) async {
  final repo = ref.watch(teamsRepositoryProvider);
  return repo.getAllTeams();
});
