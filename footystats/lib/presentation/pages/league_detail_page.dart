import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_assets.dart';
import '../../data/repositories/league_applications_repository.dart';
import '../../data/repositories/leagues_repository.dart';
import '../../domain/models/season_model.dart';
import '../../data/repositories/teams_repository.dart';
import '../../domain/models/team_model.dart';
import 'create_team_league_page.dart';
import '../providers/league_teams_provider.dart';
import '../providers/seasons_provider.dart';
import 'league_add_teams_page.dart';
import 'league_applications_page.dart';
import 'league_create_matches_page.dart';
import 'league_rejected_applications_page.dart';
import 'team_detail_page.dart';

class LeagueDetailPage extends ConsumerStatefulWidget {
  const LeagueDetailPage({super.key, required this.leagueId});

  final String leagueId;

  @override
  ConsumerState<LeagueDetailPage> createState() => _LeagueDetailPageState();
}

class _LeagueDetailPageState extends ConsumerState<LeagueDetailPage> {
  Map<String, dynamic>? _league;
  bool _isLoading = true;
  bool _isDeleting = false;
  bool _hasJoined = false;

  @override
  void initState() {
    super.initState();
    _loadLeague();
  }

  Future<void> _loadLeague() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('leagues')
          .select()
          .eq('id', widget.leagueId)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _league = response;
          _isLoading = false;
        });
        final currentUserId = Supabase.instance.client.auth.currentUser?.id;
        final createdBy = response['created_by']?.toString();
        if (currentUserId != null && createdBy != currentUserId) {
          await _refreshJoinState();
        }
      } else if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('League not found')));
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading league: $error')));
    }
  }

  List<PopupMenuItem<String>> _buildSeasonMenuItems(
    ColorScheme colorScheme,
  ) {
    final seasonsAsync =
        ref.watch(allSeasonsForLeagueProvider(widget.leagueId));
    return seasonsAsync.when(
      data: (seasons) {
        final ongoing =
            seasons.where((s) => s.status == 'ongoing').firstOrNull;
        final upcoming =
            seasons.where((s) => s.status == 'upcoming').firstOrNull;
        if (ongoing != null) {
          return [
            PopupMenuItem<String>(
              value: 'end_season',
              child: Row(
                children: [
                  Icon(Icons.stop_circle, color: colorScheme.error),
                  const SizedBox(width: 16),
                  const Text('End season'),
                ],
              ),
            ),
          ];
        }
        if (upcoming != null) {
          return [
            PopupMenuItem<String>(
              value: 'start_season',
              child: const Row(
                children: [
                  Icon(Icons.play_circle),
                  SizedBox(width: 16),
                  Text('Start season'),
                ],
              ),
            ),
          ];
        }
        return [];
      },
      loading: () => [],
      error: (_, __) => [],
    );
  }

  Future<void> _handleStartSeason() async {
    final seasonsAsync =
        ref.read(allSeasonsForLeagueProvider(widget.leagueId));
    final seasons = seasonsAsync.value ?? [];
    final upcoming =
        seasons.where((s) => s.status == 'upcoming').firstOrNull;
    if (upcoming == null) return;
    try {
      await ref.read(seasonsRepositoryProvider).startSeason(upcoming.id);
      if (!mounted) return;
      ref.invalidate(allSeasonsForLeagueProvider(widget.leagueId));
      ref.invalidate(ongoingOrUpcomingSeasonProvider(widget.leagueId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Season started')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _handleEndSeason() async {
    final seasonsAsync =
        ref.read(allSeasonsForLeagueProvider(widget.leagueId));
    final seasons = seasonsAsync.value ?? [];
    final ongoing =
        seasons.where((s) => s.status == 'ongoing').firstOrNull;
    if (ongoing == null) return;
    try {
      await ref.read(seasonsRepositoryProvider).endSeason(ongoing.id);
      if (!mounted) return;
      ref.invalidate(allSeasonsForLeagueProvider(widget.leagueId));
      ref.invalidate(ongoingOrUpcomingSeasonProvider(widget.leagueId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Season ended')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _refreshJoinState() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      final res = await supabase
          .from('league_team_join_requests')
          .select('id')
          .eq('league_id', widget.leagueId)
          .eq('requested_by', userId)
          .inFilter('status', ['pending', 'accepted'])
          .limit(1);
      if (!mounted) return;
      setState(() {
        _hasJoined = (res as List).isNotEmpty;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasJoined = false);
    }
  }

  Future<void> _handleJoinLeague() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to join a league')),
      );
      return;
    }
    final teamsRepo = TeamsRepository();
    final leagueAppsRepo = LeagueApplicationsRepository();
    List<TeamModel> allTeams;
    try {
      allTeams = await teamsRepo.getTeamsByCreator(currentUser.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading teams: $error')));
      return;
    }
    final supabase = Supabase.instance.client;
    final existingRes = await supabase
        .from('league_team_join_requests')
        .select('team_id')
        .eq('league_id', widget.leagueId)
        .eq('requested_by', currentUser.id)
        .inFilter('status', ['pending', 'accepted']);
    final existingTeamIds = (existingRes as List)
        .map((r) => (r as Map)['team_id']?.toString())
        .whereType<String>()
        .toSet();
    final teams = allTeams.where((t) => !existingTeamIds.contains(t.id)).toList();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => _JoinLeagueTeamPicker(
        teams: teams,
        alreadyAppliedCount: existingTeamIds.length,
        onTeamSelected: (team) async {
          Navigator.of(ctx).pop();
          try {
            await leagueAppsRepo.applyToLeague(
              leagueId: widget.leagueId,
              teamId: team.id,
              createdBy: currentUser.id,
            );
            if (!mounted) return;
            _refreshJoinState();
            ref.invalidate(teamsInLeagueProvider(widget.leagueId));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Your application has been sent')),
            );
          } catch (error) {
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Error applying: $error')));
          }
        },
        onCreateTeam: () {
          Navigator.of(ctx).pop();
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const CreateTeamPage()));
        },
      ),
    );
  }

  Future<void> _deleteLeague() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete League'),
        content: const Text(
          'Are you sure you want to delete this league? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('leagues').delete().eq('id', widget.leagueId);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('League deleted')));
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting league: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const SizedBox.shrink(), centerTitle: false),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_league == null) {
      return Scaffold(
        appBar: AppBar(title: const SizedBox.shrink(), centerTitle: false),
        body: const Center(child: Text('League not found')),
      );
    }

    final leagueName = _league!['league_name'] as String? ?? 'Unknown';
    final logoUrl = _league!['logo_id'] as String?;
    final createdBy = _league!['created_by']?.toString();
    final createdAt = _league!['created_at'];
    final createdAtDt = createdAt is DateTime
        ? createdAt
        : (createdAt is String ? DateTime.tryParse(createdAt) : null);
    final estYear = createdAtDt?.year ?? DateTime.now().year;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isOwner = createdBy != null && createdBy == currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: const SizedBox.shrink(),
        centerTitle: false,
        actions: [
          if (!isOwner)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilledButton.icon(
                onPressed: _handleJoinLeague,
                icon: Icon(_hasJoined ? Icons.add : Icons.login),
                label: Text(_hasJoined ? 'Add team' : 'Join league'),
              ),
            )
          else if (_isDeleting)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'More options',
              onSelected: (value) {
                switch (value) {
                  case 'create_match':
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            LeagueCreateMatchesPage(leagueId: widget.leagueId),
                      ),
                    );
                    break;
                  case 'manage_applications':
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            LeagueApplicationsPage(leagueId: widget.leagueId),
                      ),
                    );
                    break;
                  case 'rejected_applications':
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LeagueRejectedApplicationsPage(
                          leagueId: widget.leagueId,
                        ),
                      ),
                    );
                    break;
                  case 'add_teams':
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            LeagueAddTeamsPage(leagueId: widget.leagueId),
                      ),
                    );
                    break;
                  case 'start_season':
                    _handleStartSeason();
                    break;
                  case 'end_season':
                    _handleEndSeason();
                    break;
                  case 'delete':
                    _deleteLeague();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'create_match',
                  child: Row(
                    children: [
                      Icon(Icons.sports_soccer),
                      SizedBox(width: 16),
                      Text('Create matches'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'manage_applications',
                  child: Row(
                    children: [
                      Icon(Icons.pending_actions),
                      SizedBox(width: 16),
                      Text('Manage applications'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'rejected_applications',
                  child: Row(
                    children: [
                      Icon(Icons.cancel),
                      SizedBox(width: 16),
                      Text('Rejected applications'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'add_teams',
                  child: Row(
                    children: [
                      Icon(Icons.group_add),
                      SizedBox(width: 16),
                      Text('Add teams to league'),
                    ],
                  ),
                ),
                ..._buildSeasonMenuItems(colorScheme),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: colorScheme.error),
                      const SizedBox(width: 16),
                      Text(
                        'Delete league',
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: DefaultTabController(
        length: 8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Column(
                children: [
                  // Header (logo + name + est. year)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                        bottomLeft: Radius.circular(0),
                        bottomRight: Radius.circular(0),
                      ),
                    ),
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                              width: 1,
                            ),
                          ),
                          child: logoUrl != null && logoUrl.isNotEmpty
                              ? ClipOval(
                                  child: Image.network(
                                    logoUrl,
                                    width: 96,
                                    height: 96,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(
                                        Icons.emoji_events,
                                        size: 44,
                                        color: colorScheme.onSurfaceVariant,
                                      );
                                    },
                                  ),
                                )
                              : Icon(
                                  Icons.emoji_events,
                                  size: 44,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                leagueName,
                                style: textTheme.titleLarge,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Est. $estYear',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Tab bar (0 spacing, same background as header)
                  Container(
                    width: double.infinity,
                    color: colorScheme.surfaceContainerHigh,
                    child: TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      dividerColor: Colors.transparent,
                      labelColor: colorScheme.onSurface,
                      unselectedLabelColor: colorScheme.onSurfaceVariant,
                      indicatorColor: colorScheme.primary,
                      tabs: const [
                        Tab(text: 'Overview'),
                        Tab(text: 'Matches'),
                        Tab(text: 'Standings'),
                        Tab(text: 'Team stats'),
                        Tab(text: 'Player stats'),
                        Tab(text: 'Teams'),
                        Tab(text: 'Seasons'),
                        Tab(text: 'Videos'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _LeagueOverviewTab(league: _league!),
                  const _LeagueTabPlaceholder(title: 'Matches'),
                  const _LeagueTabPlaceholder(title: 'Standings'),
                  const _LeagueTabPlaceholder(title: 'Team stats'),
                  const _LeagueTabPlaceholder(title: 'Player stats'),
                  _LeagueTeamsTab(leagueId: widget.leagueId),
                  _LeagueSeasonsTab(leagueId: widget.leagueId),
                  const _LeagueTabPlaceholder(title: 'Videos'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JoinLeagueTeamPicker extends StatelessWidget {
  const _JoinLeagueTeamPicker({
    required this.teams,
    required this.onTeamSelected,
    required this.onCreateTeam,
    this.alreadyAppliedCount = 0,
  });

  final List<TeamModel> teams;
  final ValueChanged<TeamModel> onTeamSelected;
  final VoidCallback onCreateTeam;
  final int alreadyAppliedCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            alreadyAppliedCount > 0
                ? 'Select another team to add'
                : 'Select a team to apply',
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          if (teams.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Column(
                children: [
                  Text(
                    alreadyAppliedCount > 0
                        ? 'All your teams have already been applied. Create a new team to add another.'
                        : 'You have no teams yet. Create one to apply to this league.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => onCreateTeam(),
                    icon: const Icon(Icons.add),
                    label: const Text('Create team'),
                  ),
                ],
              ),
            )
          else
            ...teams.map(
              (team) =>
                  _TeamListItem(team: team, onTap: () => onTeamSelected(team)),
            ),
        ],
      ),
    );
  }
}

class _TeamListItem extends StatelessWidget {
  const _TeamListItem({required this.team, required this.onTap});

  final TeamModel team;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final path = team.logoPath;
    final isNetwork = path.startsWith('http://') || path.startsWith('https://');

    return ListTile(
      leading: SizedBox(
        width: 48,
        height: 48,
        child: ClipOval(
          child: isNetwork
              ? Image.network(
                  path,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Icon(Icons.groups, color: colorScheme.onSurfaceVariant),
                )
              : Image.asset(
                  path,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Icon(Icons.groups, color: colorScheme.onSurfaceVariant),
                ),
        ),
      ),
      title: Text(team.displayName),
      onTap: onTap,
    );
  }
}

class _LeagueTeamsTab extends ConsumerWidget {
  const _LeagueTeamsTab({required this.leagueId});

  final String leagueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final asyncTeams = ref.watch(teamsInLeagueProvider(leagueId));

    return asyncTeams.when(
      data: (teams) {
        if (teams.isEmpty) {
          return Center(
            child: Text(
              'No teams in this league yet',
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: teams.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final team = teams[index];
            final path = team.logoPath;
            final isNetwork =
                path.startsWith('http://') || path.startsWith('https://');
            return Material(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(28),
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TeamDetailPage(teamId: team.id),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(28),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: ClipOval(
                          child: isNetwork
                              ? Image.network(
                                  path,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.groups,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                )
                              : Image.asset(
                                  path,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.groups,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          team.displayName,
                          style: textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }
}

class _LeagueSeasonsTab extends ConsumerStatefulWidget {
  const _LeagueSeasonsTab({required this.leagueId});

  final String leagueId;

  @override
  ConsumerState<_LeagueSeasonsTab> createState() => _LeagueSeasonsTabState();
}

class _LeagueSeasonsTabState extends ConsumerState<_LeagueSeasonsTab> {
  Future<void> _showCreateSeasonDialog() async {
    final nameController = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create season'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Season name',
                        hintText: 'e.g. Season 2024',
                        border: OutlineInputBorder(),
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () async {
                        final now = DateTime.now();
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: startDate ?? now,
                          firstDate: now.subtract(const Duration(days: 365)),
                          lastDate: now.add(const Duration(days: 730)),
                        );
                        if (d != null) {
                          setDialogState(() => startDate = d);
                        }
                      },
                      child: Text(
                        startDate == null
                            ? 'Start date'
                            : '${startDate!.day}/${startDate!.month}/${startDate!.year}',
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () async {
                        final now = DateTime.now();
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: endDate ?? startDate ?? now,
                          firstDate: startDate ?? now,
                          lastDate: (startDate ?? now).add(
                            const Duration(days: 730),
                          ),
                        );
                        if (d != null) {
                          setDialogState(() => endDate = d);
                        }
                      },
                      child: Text(
                        endDate == null
                            ? 'End date'
                            : '${endDate!.day}/${endDate!.month}/${endDate!.year}',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty ||
                        startDate == null ||
                        endDate == null ||
                        endDate!.isBefore(startDate!)) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Enter a name and valid date range'),
                        ),
                      );
                      return;
                    }
                    Navigator.of(ctx).pop({
                      'name': name,
                      'startDate': startDate,
                      'endDate': endDate,
                    });
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null || !mounted) return;
    final name = result['name'] as String? ?? '';
    final sd = result['startDate'] as DateTime?;
    final ed = result['endDate'] as DateTime?;
    if (name.isEmpty || sd == null || ed == null) return;
    if (ed.isBefore(sd)) return;

    try {
      final repo = ref.read(seasonsRepositoryProvider);
      await repo.createSeason(
        leagueId: widget.leagueId,
        seasonName: name,
        startDate: sd,
        endDate: ed,
      );
      if (!mounted) return;
      ref.invalidate(allSeasonsForLeagueProvider(widget.leagueId));
      ref.invalidate(ongoingOrUpcomingSeasonProvider(widget.leagueId));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Season created')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error creating season: $error')));
    }
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  void _showSeasonBottomSheet(BuildContext context, SeasonModel season) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isOngoing = season.status == 'ongoing';
    final isUpcoming = season.status == 'upcoming';
    final dateRange =
        '${_formatDate(season.startDate)} – ${_formatDate(season.endDate)}';

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              season.seasonName,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              dateRange,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isOngoing
                    ? colorScheme.tertiaryContainer
                    : isUpcoming
                        ? colorScheme.primaryContainer.withOpacity(0.5)
                        : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                season.status == 'ongoing'
                    ? 'Ongoing'
                    : season.status == 'upcoming'
                        ? 'Upcoming'
                        : 'Ended',
                style: textTheme.labelMedium?.copyWith(
                  color: isOngoing
                      ? colorScheme.onTertiaryContainer
                      : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isUpcoming) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  try {
                    await ref.read(seasonsRepositoryProvider).startSeason(season.id);
                    if (!mounted) return;
                    ref.invalidate(allSeasonsForLeagueProvider(widget.leagueId));
                    ref.invalidate(ongoingOrUpcomingSeasonProvider(widget.leagueId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Season started')),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start season'),
              ),
            ] else if (isOngoing) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  try {
                    await ref.read(seasonsRepositoryProvider).endSeason(season.id);
                    if (!mounted) return;
                    ref.invalidate(allSeasonsForLeagueProvider(widget.leagueId));
                    ref.invalidate(ongoingOrUpcomingSeasonProvider(widget.leagueId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Season ended')),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                },
                icon: const Icon(Icons.stop),
                label: const Text('End season'),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final asyncSeasons = ref.watch(
      allSeasonsForLeagueProvider(widget.leagueId),
    );

    return asyncSeasons.when(
      data: (seasons) {
        final hasUpcoming =
            seasons.any((s) => s.status == 'upcoming');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: hasUpcoming ? null : _showCreateSeasonDialog,
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Create season'),
                  ),
                  if (hasUpcoming) ...[
                    const SizedBox(height: 8),
                    Text(
                      'There is already an upcoming season. End it before creating a new one.',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: seasons.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_month_outlined,
                              size: 48,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No seasons yet',
                              style: textTheme.titleMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create a season to organize matches.',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: seasons.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final season = seasons[index];
                        final isOngoing = season.status == 'ongoing';
                        final isEnded = season.status == 'ended';
                        final dateRange =
                            '${_formatDate(season.startDate)} – ${_formatDate(season.endDate)}';

                        return Material(
                          color: colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(16),
                          elevation: 0,
                          child: InkWell(
                            onTap: () =>
                                _showSeasonBottomSheet(context, season),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: isOngoing
                                        ? colorScheme.tertiary
                                        : isEnded
                                        ? colorScheme.outlineVariant
                                        : colorScheme.primary.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        season.seasonName,
                                        style: textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        dateRange,
                                        style: textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isOngoing)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.tertiaryContainer,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'Ongoing',
                                      style: textTheme.labelMedium?.copyWith(
                                        color: colorScheme.onTertiaryContainer,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  )
                                else if (isEnded)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'Ended',
                                      style: textTheme.labelMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer
                                          .withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'Upcoming',
                                      style: textTheme.labelMedium?.copyWith(
                                        color: colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }
}

class _LeagueOverviewTab extends StatelessWidget {
  const _LeagueOverviewTab({required this.league});

  final Map<String, dynamic> league;

  static const _monthAbbr = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatDateShort(DateTime d) => '${d.day} ${_monthAbbr[d.month - 1]}';

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v.split('T').first);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final leagueName = league['league_name'] as String? ?? 'Unknown';
    final logoUrl = league['logo_id'] as String?;
    final startRaw = league['start_date'];
    final endRaw = league['end_date'];
    final startDate = _parseDate(startRaw);
    final endDate = _parseDate(endRaw);

    double? progress;
    if (startDate != null && endDate != null) {
      final now = DateTime.now();
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      final end = DateTime(endDate.year, endDate.month, endDate.day);
      final today = DateTime(now.year, now.month, now.day);
      final totalDays = end.difference(start).inDays;
      progress = totalDays > 0
          ? (today.difference(start).inDays / totalDays).clamp(0.0, 1.0)
          : 0.0;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (startDate != null && endDate != null) ...[
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(28),
              ),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.outlineVariant,
                            width: 1,
                          ),
                        ),
                        child: logoUrl != null && logoUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: Image.network(
                                  logoUrl,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.emoji_events,
                                    size: 24,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.emoji_events,
                                size: 24,
                                color: colorScheme.onSurfaceVariant,
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              leagueName,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LinearProgressIndicator(
                        year2023: false,
                        value: progress!,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDateShort(startDate),
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            _formatDateShort(endDate),
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Text(
                'Season dates not set for this league.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 16),
          _PlayerOfSeasonSection(leagueId: league['id'] as String? ?? ''),
          const SizedBox(height: 16),
          _TeamOfTheWeekSection(leagueId: league['id'] as String? ?? ''),
        ],
      ),
    );
  }
}

class _PlayerOfSeasonSection extends StatelessWidget {
  const _PlayerOfSeasonSection({required this.leagueId});

  final String leagueId;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: leagueId.isEmpty
          ? Future.value([])
          : LeaguesRepository().getTopPlayersByRating(leagueId, limit: 3),
      builder: (context, snapshot) {
        final players = snapshot.data ?? [];
        if (players.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.emoji_events_outlined,
                      size: 24,
                      color: colorScheme.onSurface,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Player of the Season race',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'No match stats yet. Play matches to see top players.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(28),
          ),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.emoji_events_outlined,
                    size: 24,
                    color: colorScheme.onSurface,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Player of the Season race',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...List.generate(players.length, (i) {
                final p = players[i];
                final rank = i + 1;
                final name = p['player_name'] as String? ?? 'Unknown';
                final teamName = p['team_name'] as String? ?? '—';
                final imageUrl = p['image_url'] as String?;
                final teamLogo = p['team_logo'] as String?;
                final avgRating = (p['avg_rating'] as num?)?.toDouble() ?? 0.0;
                return Padding(
                  padding: EdgeInsets.only(bottom: i < players.length - 1 ? 12 : 0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          '$rank',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _PlayerAvatar(imageUrl: imageUrl),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                if (teamLogo != null && teamLogo.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ClipOval(
                                      child: _isValidUrl(teamLogo)
                                          ? Image.network(
                                              teamLogo,
                                              width: 16,
                                              height: 16,
                                              fit: BoxFit.cover,
                                            )
                                          : Icon(
                                              Icons.groups,
                                              size: 16,
                                              color: colorScheme.onSurfaceVariant,
                                            ),
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    teamName,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star,
                              size: 14,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              avgRating.toStringAsFixed(2),
                              style: textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Full player stats coming soon'),
                      ),
                    );
                  },
                  icon: Icon(Icons.chevron_right, size: 18, color: colorScheme.primary),
                  label: Text(
                    'View top players',
                    style: TextStyle(color: colorScheme.primary),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static bool _isValidUrl(String? s) =>
      s != null &&
      s.isNotEmpty &&
      (s.startsWith('http://') || s.startsWith('https://'));
}

class _PlayerAvatar extends StatelessWidget {
  const _PlayerAvatar({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (imageUrl == null || imageUrl!.isEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: colorScheme.surfaceContainerHighest,
        child: Icon(Icons.person, color: colorScheme.onSurfaceVariant),
      );
    }
    final url = imageUrl!;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: colorScheme.surfaceContainerHighest,
        backgroundImage: NetworkImage(url),
      );
    }
    return CircleAvatar(
      radius: 20,
      backgroundColor: colorScheme.surfaceContainerHighest,
      backgroundImage: AssetImage(url),
    );
  }
}

class _TeamOfTheWeekSection extends StatelessWidget {
  const _TeamOfTheWeekSection({required this.leagueId});

  final String leagueId;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
      future: leagueId.isEmpty
          ? Future.value({})
          : LeaguesRepository().getTeamOfTheWeek(leagueId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final data = snapshot.data ?? {};
        final gk = data['Goalkeeper'] ?? [];
        final def = data['Defender'] ?? [];
        final mid = data['Midfielder'] ?? [];
        final att = data['Attacker'] ?? [];
        final hasPlayers =
            gk.isNotEmpty || def.isNotEmpty || mid.isNotEmpty || att.isNotEmpty;

        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  children: [
                    Icon(Icons.star_rounded,
                        color: colorScheme.primary, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Team of the Week',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (!hasPlayers)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Text(
                    'No match stats yet. Play matches to see the team of the week.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                  child: _TeamOfTheWeekPitch(
                    goalkeepers: gk,
                    defenders: def,
                    midfielders: mid,
                    attackers: att,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TeamOfTheWeekPitch extends StatelessWidget {
  const _TeamOfTheWeekPitch({
    required this.goalkeepers,
    required this.defenders,
    required this.midfielders,
    required this.attackers,
  });

  final List<Map<String, dynamic>> goalkeepers;
  final List<Map<String, dynamic>> defenders;
  final List<Map<String, dynamic>> midfielders;
  final List<Map<String, dynamic>> attackers;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pitchWidth = constraints.maxWidth;
        final pitchHeight = pitchWidth * (274 / 380);
        final bgHeight = pitchWidth;
        final pitchTop = bgHeight - pitchHeight;
        const playerSize = 60.0;

        // Divide pitch into 4 rows: ATT (top), MID, DEF, GK (bottom)
        final rowHeight = pitchHeight / 4;
        final rowCenters = [
          pitchTop + rowHeight * 0.5, // Attackers
          pitchTop + rowHeight * 1.5, // Midfielders
          pitchTop + rowHeight * 2.5, // Defenders
          pitchTop + rowHeight * 3.5, // Goalkeepers
        ];

        List<Positioned> _buildRow(
          List<Map<String, dynamic>> players,
          double rowCenterY,
        ) {
          if (players.isEmpty) return [];
          final count = players.length;
          final spacing = pitchWidth / (count + 1);
          return List.generate(players.length, (i) {
            final p = players[i];
            final x = spacing * (i + 1) - playerSize / 2;
            final y = rowCenterY - playerSize / 2;
            final name = p['player_name'] as String? ?? '';
            final imageUrl = p['image_url'] as String? ?? '';
            final rating = p['rating'];
            double ratingVal = 0.0;
            if (rating is num) ratingVal = rating.toDouble();
            else if (rating is String) ratingVal = double.tryParse(rating) ?? 0;

            return Positioned(
              left: x,
              top: y,
              child: _TeamOfTheWeekPlayer(
                name: name,
                imageAsset: imageUrl,
                rating: ratingVal,
              ),
            );
          });
        }

        return SizedBox(
          width: pitchWidth,
          height: bgHeight,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                width: pitchWidth,
                child: Image.asset(
                  'lib/assets/images/pitch bg.png',
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomCenter,
                  color: const Color(0xFF107F6B),
                  colorBlendMode: BlendMode.color,
                ),
              ),
              Positioned(
                left: 0,
                top: pitchTop,
                width: pitchWidth,
                height: pitchHeight,
                child: SvgPicture.asset(
                  'lib/assets/icons/squad/pitch.svg',
                  fit: BoxFit.contain,
                ),
              ),
              ..._buildRow(attackers, rowCenters[0]),
              ..._buildRow(midfielders, rowCenters[1]),
              ..._buildRow(defenders, rowCenters[2]),
              ..._buildRow(goalkeepers, rowCenters[3]),
            ],
          ),
        );
      },
    );
  }
}

class _TeamOfTheWeekPlayer extends StatelessWidget {
  const _TeamOfTheWeekPlayer({
    required this.name,
    required this.imageAsset,
    required this.rating,
  });

  final String name;
  final String imageAsset;
  final double rating;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final path = imageAsset.trim();
    final isNetwork =
        path.startsWith('http://') || path.startsWith('https://');
    final image = path.isEmpty
        ? Image.asset(AppAssets.playerImage,
            width: 60, height: 60, fit: BoxFit.cover)
        : isNetwork
            ? Image.network(path,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Image.asset(
                      AppAssets.playerImage,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ))
            : Image.asset(path,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Image.asset(
                      AppAssets.playerImage,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ));

    return SizedBox(
      width: 60,
      height: 76,
      child: Column(
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Positioned(
                  top: 0,
                  child: SvgPicture.asset(
                    'lib/assets/icons/squad/back.svg',
                    width: 60,
                    height: 60,
                    fit: BoxFit.contain,
                  ),
                ),
                Positioned(top: 0, child: image),
                Positioned(
                  bottom: 0,
                  child: SizedBox(
                    width: 60,
                    height: 16,
                    child: Stack(
                      children: [
                        SvgPicture.asset(
                          'lib/assets/icons/squad/name.svg',
                          width: 60,
                          height: 16,
                          fit: BoxFit.contain,
                        ),
                        Center(
                          child: Text(
                            name,
                            style: textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimary,
                              fontSize: 9,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              rating.toStringAsFixed(1),
              style: textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onPrimaryContainer,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeagueTabPlaceholder extends StatelessWidget {
  const _LeagueTabPlaceholder({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Text(
        '$title (coming soon)',
        style: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
