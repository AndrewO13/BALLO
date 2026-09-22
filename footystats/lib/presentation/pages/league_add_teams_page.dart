import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_assets.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/media_placeholders.dart';
import '../../domain/models/team_model.dart';
import '../providers/league_teams_provider.dart';
import '../providers/teams_provider.dart';

class LeagueAddTeamsPage extends ConsumerStatefulWidget {
  const LeagueAddTeamsPage({super.key, required this.leagueId});

  final String leagueId;

  @override
  ConsumerState<LeagueAddTeamsPage> createState() =>
      _LeagueAddTeamsPageState();
}

class _LeagueAddTeamsPageState extends ConsumerState<LeagueAddTeamsPage> {
  final _searchController = TextEditingController();
  List<TeamModel> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  final Set<String> _processingIds = {};
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final q = _searchController.text.trim();
      if (q.isEmpty) {
        setState(() {
          _searchResults = [];
          _hasSearched = false;
        });
        return;
      }
      _performSearch(q);
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });
    try {
      final teamsRepo = ref.read(teamsRepositoryProvider);
      final results = await teamsRepo.searchTeams(query);
      final leagueTeamIds = await ref
          .read(leagueTeamsRepositoryProvider)
          .getTeamIdsInLeague(widget.leagueId);
      final excludeSet = leagueTeamIds.toSet();
      final filtered = results.where((t) => !excludeSet.contains(t.id)).toList();
      if (!mounted) return;
      setState(() {
        _searchResults = filtered;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addTeam(TeamModel team) async {
    if (_processingIds.contains(team.id)) return;
    setState(() => _processingIds.add(team.id));
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _processingIds.remove(team.id));
      return;
    }
    try {
      final repo = ref.read(leagueTeamsRepositoryProvider);
      await repo.addTeamToLeague(
        leagueId: widget.leagueId,
        teamId: team.id,
        addedBy: userId,
      );
      if (!mounted) return;
      ref.invalidate(teamsInLeagueProvider(widget.leagueId));
      ref.invalidate(activeTeamIdsForLeagueProvider(widget.leagueId));
      setState(() {
        _processingIds.remove(team.id);
        _searchResults = _searchResults.where((t) => t.id != team.id).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${team.displayName} added to league')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _processingIds.remove(team.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding team: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Add teams', style: textTheme.headlineMedium),
        centerTitle: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by team name',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              autofocus: true,
            ),
          ),
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : !_hasSearched
                    ? const ScrollableAppEmptyState(
                        imageAsset: AppAssets.addTeamsEmpty,
                        title: 'Add teams to your league',
                        subtitle:
                            'Search by team name to find teams and add them to this league.',
                      )
                    : _searchResults.isEmpty
                        ? const ScrollableAppEmptyState(
                            imageAsset: AppAssets.addTeamsEmpty,
                            title: 'No teams found',
                            subtitle:
                                'Try a different team name, or check the spelling.',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _searchResults.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final team = _searchResults[index];
                              final isProcessing = _processingIds.contains(team.id);
                              return _TeamSearchListItem(
                                team: team,
                                onAdd: () => _addTeam(team),
                                isProcessing: isProcessing,
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _TeamSearchListItem extends StatelessWidget {
  const _TeamSearchListItem({
    required this.team,
    required this.onAdd,
    required this.isProcessing,
  });

  final TeamModel team;
  final VoidCallback onAdd;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          _TeamLogo(logoId: team.logoId),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  team.displayName,
                  style: textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (team.teamName != null &&
                    team.shortForm.isNotEmpty &&
                    team.shortForm != team.teamName) ...[
                  const SizedBox(height: 2),
                  Text(
                    team.shortForm,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: isProcessing ? null : onAdd,
            icon: isProcessing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add, size: 20),
            label: Text(isProcessing ? 'Adding' : 'Add'),
          ),
        ],
      ),
    );
  }
}

class _TeamLogo extends StatelessWidget {
  const _TeamLogo({this.logoId});

  final String? logoId;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ClipOval(
      child: SizedBox(
        width: 48,
        height: 48,
        child: buildTeamLogo(
          _resolvePath(logoId),
          size: 48,
          placeholderIconColor: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  String? _resolvePath(String? logoId) => resolveTeamLogoPath(logoId);
}
