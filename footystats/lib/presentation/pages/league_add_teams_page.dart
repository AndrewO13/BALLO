import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/teams_provider.dart';
import '../providers/league_teams_provider.dart';

class LeagueAddTeamsPage extends ConsumerStatefulWidget {
  const LeagueAddTeamsPage({super.key, required this.leagueId});

  final String leagueId;

  @override
  ConsumerState<LeagueAddTeamsPage> createState() =>
      _LeagueAddTeamsPageState();
}

class _LeagueAddTeamsPageState extends ConsumerState<LeagueAddTeamsPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addTeam(String teamId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final repo = ref.read(leagueTeamsRepositoryProvider);
      await repo.addTeamToLeague(
        leagueId: widget.leagueId,
        teamId: teamId,
        addedBy: userId,
      );
      ref.invalidate(teamsInLeagueProvider(widget.leagueId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Team added to league')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding team: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncTeams = ref.watch(allTeamsProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Add teams', style: textTheme.headlineMedium),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search teams',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
          ),
          Expanded(
            child: asyncTeams.when(
              data: (teams) {
                final filtered = teams.where((t) {
                  final name = (t.teamName ?? t.shortForm).toLowerCase();
                  return name.contains(_query.toLowerCase());
                }).toList();
                if (filtered.isEmpty) {
                  return const Center(child: Text('No teams found'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final team = filtered[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            Theme.of(context).colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              team.teamName ?? team.shortForm,
                              style: textTheme.bodyMedium,
                            ),
                          ),
                          FilledButton(
                            onPressed: () => _addTeam(team.id),
                            child: const Text('Add'),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }
}
