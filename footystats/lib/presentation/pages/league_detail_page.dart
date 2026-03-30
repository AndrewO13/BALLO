import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_assets.dart';
import '../../data/repositories/league_applications_repository.dart';
import '../../data/repositories/leagues_repository.dart';
import '../../data/repositories/matches_repository.dart';
import '../../domain/models/match_model.dart';
import '../../domain/models/season_model.dart';
import '../../data/repositories/teams_repository.dart';
import '../../domain/models/team_model.dart';
import 'fixture.dart';
import 'matches.dart' show DodecagonIndicator;
import 'create_team_league_page.dart';
import '../providers/league_teams_provider.dart';
import '../providers/matches_provider.dart';
import '../providers/seasons_provider.dart';
import 'league_add_teams_page.dart';
import 'league_applications_page.dart';
import 'league_create_matches_page.dart';
import 'league_rejected_applications_page.dart';
import 'league_video_player_page.dart';
import 'team_detail_page.dart';
import '../widgets/socials_section_card.dart';

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
                  _LeagueMatchesTab(leagueId: widget.leagueId),
                  _LeagueStandingsTab(leagueId: widget.leagueId),
                  _LeagueTeamStatsTab(leagueId: widget.leagueId),
                  _LeaguePlayerStatsTab(leagueId: widget.leagueId),
                  _LeagueTeamsTab(leagueId: widget.leagueId),
                  _LeagueSeasonsTab(leagueId: widget.leagueId),
                  _LeagueVideosTab(leagueId: widget.leagueId),
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
          const SizedBox(height: 16),
          _FeaturedMatchSection(leagueId: league['id'] as String? ?? ''),
          const SizedBox(height: 16),
          SocialsSectionCard(
            title: 'League socials',
            instagramUrl: league['social_instagram']?.toString(),
            tiktokUrl: league['social_tiktok']?.toString(),
            xUrl: league['social_x']?.toString(),
          ),
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
                        style: textTheme.titleSmall,
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
                      style: textTheme.titleSmall,
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
                      style: textTheme.titleSmall,
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
        const playerWidth = _TeamOfTheWeekPlayer.kMarkerWidth;
        const playerHeight = _TeamOfTheWeekPlayer.kMarkerHeight;

        // Divide pitch into 4 rows: ATT (top), MID, DEF, GK (bottom)
        final rowHeight = pitchHeight / 4;
        final rowCenters = [
          pitchTop + rowHeight * 0.5, // Attackers
          pitchTop + rowHeight * 1.5, // Midfielders
          pitchTop + rowHeight * 2.5, // Defenders
          pitchTop + rowHeight * 3.5, // Goalkeepers
        ];

        List<Positioned> buildRow(
          List<Map<String, dynamic>> players,
          double rowCenterY,
        ) {
          if (players.isEmpty) return [];
          final count = players.length;
          final spacing = pitchWidth / (count + 1);
          return List.generate(players.length, (i) {
            final p = players[i];
            final x = spacing * (i + 1) - playerWidth / 2;
            final y = rowCenterY - playerHeight / 2;
            final name = p['player_name'] as String? ?? '';
            final imageUrl = p['image_url'] as String? ?? '';
            final rating = p['rating'];
            double ratingVal = 0.0;
            if (rating is num) {
              ratingVal = rating.toDouble();
            } else if (rating is String) ratingVal = double.tryParse(rating) ?? 0;

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
              ...buildRow(attackers, rowCenters[0]),
              ...buildRow(midfielders, rowCenters[1]),
              ...buildRow(defenders, rowCenters[2]),
              ...buildRow(goalkeepers, rowCenters[3]),
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

  /// Total footprint on the pitch (avatar row + rating chip).
  static const double kMarkerWidth = 60;
  static const double kMarkerHeight = 78;

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
      width: kMarkerWidth,
      height: kMarkerHeight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: kMarkerWidth,
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
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
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
                  height: 1.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedMatchSection extends StatelessWidget {
  const _FeaturedMatchSection({required this.leagueId});

  final String leagueId;

  static const _monthAbbr = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const _dayAbbr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  String _formatDate(DateTime d) =>
      '${_dayAbbr[d.weekday - 1]} ${d.day} ${_monthAbbr[d.month - 1]}';

  Future<MatchModel?> _fetchFeaturedMatch() async {
    final matches = await MatchesRepository().getMatches(leagueIds: [leagueId]);
    if (matches.isEmpty) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Prefer the next upcoming/ongoing match from today onwards.
    final upcoming = matches.where((m) =>
        (m.status == MatchStatus.upcoming || m.status == MatchStatus.ongoing) &&
        !m.matchDate.isBefore(today)).toList();
    if (upcoming.isNotEmpty) return upcoming.first;

    // Fallback: most recent completed match.
    final completed = matches.where((m) => m.status == MatchStatus.fullTime).toList();
    if (completed.isNotEmpty) return completed.last;

    return matches.first;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return FutureBuilder<MatchModel?>(
      future: _fetchFeaturedMatch(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final match = snapshot.data;
        if (match == null) return const SizedBox.shrink();

        final isFinished = match.status == MatchStatus.fullTime;
        final isLive = match.status == MatchStatus.ongoing ||
            match.status == MatchStatus.halfTime;

        final logoA = match.teamA.logoPath;
        final logoB = match.teamB.logoPath;
        final isNetworkA = logoA.startsWith('http://') || logoA.startsWith('https://');
        final isNetworkB = logoB.startsWith('http://') || logoB.startsWith('https://');

        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => FixturePage(matchId: match.id)),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isLive
                          ? 'Live'
                          : isFinished
                              ? 'Latest result'
                              : 'Featured match',
                      style: textTheme.titleSmall,
                    ),
                    if (isLive) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Text(
                              match.teamA.shortForm,
                              style: textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: colorScheme.surfaceContainerHighest,
                            backgroundImage: isNetworkA
                                ? NetworkImage(logoA)
                                : AssetImage(logoA) as ImageProvider,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: isFinished || isLive
                          ? Text(
                              match.scoreText ?? '—',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : Text(
                              match.statusText,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: colorScheme.surfaceContainerHighest,
                            backgroundImage: isNetworkB
                                ? NetworkImage(logoB)
                                : AssetImage(logoB) as ImageProvider,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              match.teamB.shortForm,
                              style: textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    isFinished
                        ? match.statusText
                        : _formatDate(match.matchDate),
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// League Team Stats Tab
// ---------------------------------------------------------------------------

class _LeagueTeamStatsTab extends StatefulWidget {
  const _LeagueTeamStatsTab({required this.leagueId});

  final String leagueId;

  @override
  State<_LeagueTeamStatsTab> createState() => _LeagueTeamStatsTabState();
}

class _LeagueTeamStatsTabState extends State<_LeagueTeamStatsTab> {
  List<Map<String, dynamic>>? _stats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await LeaguesRepository().getLeagueTeamStats(widget.leagueId);
      if (!mounted) return;
      setState(() {
        _stats = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Sorts teams by [getValue] descending and returns top [limit].
  List<Map<String, dynamic>> _topTeams(
    double Function(Map<String, dynamic>) getValue, {
    int limit = 3,
  }) {
    if (_stats == null || _stats!.isEmpty) return [];
    final sorted = List<Map<String, dynamic>>.from(_stats!)
      ..sort((a, b) => getValue(b).compareTo(getValue(a)));
    return sorted.take(limit).toList();
  }

  double _perMatch(Map<String, dynamic> row, String totalKey) {
    final total = (row[totalKey] as num?)?.toDouble() ?? 0;
    final played = (row['matches_played'] as num?)?.toDouble() ?? 0;
    if (played == 0) return 0;
    return total / played;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Could not load team stats', style: textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text(_error!, style: textTheme.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_stats == null || _stats!.isEmpty) {
      return Center(
        child: Text(
          'No team stats yet — play some matches!',
          style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    final sections = <_StatSectionData>[
      _StatSectionData(
        title: 'Goals per match',
        teams: _topTeams((r) => _perMatch(r, 'total_goals')),
        format: (r) => _perMatch(r, 'total_goals').toStringAsFixed(1),
      ),
      _StatSectionData(
        title: 'Goals conceded per match',
        teams: _topTeams((r) => _perMatch(r, 'total_conceded')),
        format: (r) => _perMatch(r, 'total_conceded').toStringAsFixed(1),
      ),
      _StatSectionData(
        title: 'Clean sheets',
        teams: _topTeams((r) => (r['clean_sheets'] as num?)?.toDouble() ?? 0),
        format: (r) => (r['clean_sheets'] ?? 0).toString(),
      ),
      _StatSectionData(
        title: 'Shots on target per match',
        teams: _topTeams((r) => _perMatch(r, 'shots_on_target')),
        format: (r) => _perMatch(r, 'shots_on_target').toStringAsFixed(1),
      ),
      _StatSectionData(
        title: 'Tackles per match',
        teams: _topTeams((r) => _perMatch(r, 'total_tackles')),
        format: (r) => _perMatch(r, 'total_tackles').toStringAsFixed(1),
      ),
      _StatSectionData(
        title: 'Saves per match',
        teams: _topTeams((r) => _perMatch(r, 'total_saves')),
        format: (r) => _perMatch(r, 'total_saves').toStringAsFixed(1),
      ),
      _StatSectionData(
        title: 'Yellow cards',
        teams: _topTeams((r) => (r['total_yellow_cards'] as num?)?.toDouble() ?? 0),
        format: (r) => (r['total_yellow_cards'] ?? 0).toString(),
      ),
      _StatSectionData(
        title: 'Red cards',
        teams: _topTeams((r) => (r['total_red_cards'] as num?)?.toDouble() ?? 0),
        format: (r) => (r['total_red_cards'] ?? 0).toString(),
      ),
      _StatSectionData(
        title: 'Expected goals (xG)',
        teams: _topTeams((_) => 0),
        format: (_) => '0.0',
      ),
      _StatSectionData(
        title: 'Expected assists (xA)',
        teams: _topTeams((_) => 0),
        format: (_) => '0.0',
      ),
    ];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: sections.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) =>
            _StatSectionCard(section: sections[index]),
      ),
    );
  }
}

class _StatSectionData {
  const _StatSectionData({
    required this.title,
    required this.teams,
    required this.format,
  });

  final String title;
  final List<Map<String, dynamic>> teams;
  final String Function(Map<String, dynamic>) format;
}

class _StatSectionCard extends StatelessWidget {
  const _StatSectionCard({required this.section});

  final _StatSectionData section;

  String _resolveLogoPath(String raw) {
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('lib/assets/') || raw.startsWith('assets/')) return raw;
    final name = raw.contains('.') ? raw : '$raw.png';
    return '${AppAssets.teamLogosPath}$name';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(section.title, style: textTheme.titleSmall),
              ),
              Icon(Icons.chevron_right,
                  size: 20, color: colorScheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 12),
          if (section.teams.isEmpty)
            Text(
              'No data yet',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (int i = 0; i < section.teams.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _buildTeamRow(context, i, section.teams[i]),
            ],
        ],
      ),
    );
  }

  Widget _buildTeamRow(
    BuildContext context,
    int index,
    Map<String, dynamic> row,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final shortForm = row['team_short_form']?.toString() ?? '—';
    final logoRaw = row['team_logo']?.toString() ?? '';
    final logoPath = _resolveLogoPath(logoRaw);
    final value = section.format(row);
    final isTop = index == 0;

    return Row(
      children: [
        if (logoPath.isNotEmpty)
          ClipOval(child: _TeamStatsLogo(path: logoPath, size: 28))
        else
          CircleAvatar(
            radius: 14,
            backgroundColor: colorScheme.surfaceContainerHighest,
            child: Icon(Icons.groups, size: 16, color: colorScheme.onSurfaceVariant),
          ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            shortForm,
            style: textTheme.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isTop)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          )
        else
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _TeamStatsLogo extends StatelessWidget {
  const _TeamStatsLogo({required this.path, this.size = 28});

  final String path;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isNetwork =
        path.startsWith('http://') || path.startsWith('https://');
    return SizedBox(
      width: size,
      height: size,
      child: isNetwork
          ? Image.network(
              path,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                Icons.groups,
                size: size * 0.7,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          : Image.asset(
              path,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                Icons.groups,
                size: size * 0.7,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// League Standings Tab
// ---------------------------------------------------------------------------

class _LeagueStandingsTab extends StatefulWidget {
  const _LeagueStandingsTab({required this.leagueId});

  final String leagueId;

  @override
  State<_LeagueStandingsTab> createState() => _LeagueStandingsTabState();
}

class _LeagueStandingsTabState extends State<_LeagueStandingsTab> {
  static const _kColumnWidths = <int, TableColumnWidth>{
    0: FlexColumnWidth(0.8),  // Pos
    1: FlexColumnWidth(2.4),  // Team
    2: FlexColumnWidth(0.7),  // PL
    3: FlexColumnWidth(0.7),  // W
    4: FlexColumnWidth(0.7),  // D
    5: FlexColumnWidth(0.7),  // L
    6: FlexColumnWidth(0.7),  // GD
    7: FlexColumnWidth(0.8),  // Pts
  };

  List<Map<String, dynamic>>? _standings;
  Set<String> _userTeamIds = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      // Fetch standings and user's team IDs in parallel.
      final results = await Future.wait([
        LeaguesRepository().getLeagueStandings(widget.leagueId),
        if (userId != null) _getUserTeamIds(supabase, userId)
        else Future.value(<String>{}),
      ]);

      if (!mounted) return;
      setState(() {
        _standings = results[0] as List<Map<String, dynamic>>;
        _userTeamIds = results[1] as Set<String>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<Set<String>> _getUserTeamIds(
    SupabaseClient client,
    String userId,
  ) async {
    final ids = <String>{};

    // Teams the user created.
    final created = await client
        .from('teams')
        .select('id')
        .eq('created_by', userId);
    for (final r in created as List) {
      final id = r['id']?.toString();
      if (id != null) ids.add(id);
    }

    // Teams the user is a member of.
    final memberships = await client
        .from('player_team_memberships')
        .select('team_id')
        .eq('player_id', userId);
    for (final r in memberships as List) {
      final id = r['team_id']?.toString();
      if (id != null) ids.add(id);
    }

    return ids;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Could not load standings', style: textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text(_error!, style: textTheme.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final standings = _standings ?? [];
    if (standings.isEmpty) {
      return Center(
        child: Text(
          'No standings yet — play some matches!',
          style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(28),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Column(
            children: [
              Table(
                columnWidths: _kColumnWidths,
                children: [_buildHeader(textTheme)],
              ),
              Divider(height: 1, color: colorScheme.outlineVariant),
              Table(
                columnWidths: _kColumnWidths,
                children: [
                  for (int i = 0; i < standings.length; i++)
                    _buildRow(context, i, standings[i]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  TableRow _buildHeader(TextTheme textTheme) {
    Widget cell(String label) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(label, style: textTheme.bodySmall, textAlign: TextAlign.center),
        );
    return TableRow(children: [
      cell('Pos'),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('Team', style: textTheme.bodySmall),
      ),
      cell('PL'),
      cell('W'),
      cell('D'),
      cell('L'),
      cell('GD'),
      cell('Pts'),
    ]);
  }

  TableRow _buildRow(BuildContext context, int index, Map<String, dynamic> row) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final position = index + 1;
    final teamId = row['team_id']?.toString() ?? '';
    final shortForm = row['team_short_form']?.toString() ?? '—';
    final logoRaw = row['team_logo']?.toString() ?? '';
    final played = row['played'] ?? 0;
    final wins = row['wins'] ?? 0;
    final draws = row['draws'] ?? 0;
    final losses = row['losses'] ?? 0;
    final gd = row['goal_difference'] ?? 0;
    final pts = row['points'] ?? 0;

    final isHighlighted = _userTeamIds.contains(teamId);

    Widget statCell(dynamic value, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            value.toString(),
            style: bold
                ? textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)
                : textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        );

    // Resolve logo path (same logic as TeamModel.logoPath)
    String logoPath = logoRaw;
    if (logoRaw.isEmpty) {
      logoPath = '';
    } else if (!logoRaw.startsWith('http://') &&
        !logoRaw.startsWith('https://') &&
        !logoRaw.startsWith('lib/assets/') &&
        !logoRaw.startsWith('assets/')) {
      final name = logoRaw.contains('.') ? logoRaw : '$logoRaw.png';
      logoPath = '${AppAssets.teamLogosPath}$name';
    }

    return TableRow(
      decoration: isHighlighted
          ? BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(30),
            )
          : null,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            position.toString(),
            style: textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              if (logoPath.isNotEmpty)
                ClipOval(child: _StandingsTeamLogo(path: logoPath, size: 24))
              else
                Icon(Icons.groups, size: 24, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  shortForm,
                  style: textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        statCell(played),
        statCell(wins),
        statCell(draws),
        statCell(losses),
        statCell(gd),
        statCell(pts, bold: true),
      ],
    );
  }
}

class _StandingsTeamLogo extends StatelessWidget {
  const _StandingsTeamLogo({required this.path, this.size = 24});

  final String path;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isNetwork =
        path.startsWith('http://') || path.startsWith('https://');
    return SizedBox(
      width: size,
      height: size,
      child: isNetwork
          ? Image.network(
              path,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                Icons.groups,
                size: size * 0.7,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          : Image.asset(
              path,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                Icons.groups,
                size: size * 0.7,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// League Matches Tab
// ---------------------------------------------------------------------------

class _LeagueMatchesTab extends ConsumerStatefulWidget {
  const _LeagueMatchesTab({required this.leagueId});

  final String leagueId;

  @override
  ConsumerState<_LeagueMatchesTab> createState() => _LeagueMatchesTabState();
}

class _LeagueMatchesTabState extends ConsumerState<_LeagueMatchesTab> {
  String? _selectedSeason;
  String? _selectedGameweek;
  String? _selectedTeam;

  List<SeasonModel> _seasons = [];
  List<Map<String, dynamic>> _gameweeks = [];
  List<TeamModel> _teams = [];
  List<MatchModel> _matches = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFilters();
  }

  Future<void> _loadFilters() async {
    try {
      final seasonsRepo = ref.read(seasonsRepositoryProvider);
      final seasons = await seasonsRepo.getSeasonsForLeagues([widget.leagueId]);
      List<Map<String, dynamic>> gameweeks = [];
      if (seasons.isNotEmpty) {
        gameweeks = await seasonsRepo
            .getGameweeksForSeasons(seasons.map((s) => s.id).toList());
      }

      final leagueTeamsRepo = ref.read(leagueTeamsRepositoryProvider);
      final teams = await leagueTeamsRepo.getTeamsInLeagues([widget.leagueId]);

      if (!mounted) return;
      setState(() {
        _seasons = seasons;
        _gameweeks = gameweeks;
        _teams = teams;
      });
      await _loadMatches();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMatches() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(matchesRepositoryProvider);
      final matches = await repo.getMatches(
        leagueIds: [widget.leagueId],
        seasonIds:
            _selectedSeason != null ? [_selectedSeason!] : null,
        gameweek: _selectedGameweek,
        teamIds: _selectedTeam != null ? [_selectedTeam!] : null,
      );
      if (!mounted) return;
      setState(() {
        _matches = matches;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _onSeasonChanged(String? value) async {
    final v = (value?.isEmpty ?? true) ? null : value;
    setState(() {
      _selectedSeason = v;
      _selectedGameweek = null;
    });

    // Reload gameweeks for the new season selection.
    try {
      final seasonsRepo = ref.read(seasonsRepositoryProvider);
      final seasonIds = v != null
          ? [v]
          : _seasons.map((s) => s.id).toList();
      final gw = await seasonsRepo.getGameweeksForSeasons(seasonIds);
      if (!mounted) return;
      setState(() => _gameweeks = gw);
    } catch (_) {}

    await _loadMatches();
  }

  void _onGameweekChanged(String? value) {
    setState(() => _selectedGameweek = (value?.isEmpty ?? true) ? null : value);
    _loadMatches();
  }

  void _onTeamChanged(String? value) {
    setState(() => _selectedTeam = (value?.isEmpty ?? true) ? null : value);
    _loadMatches();
  }

  // Gameweek navigation
  void _goToPreviousGameweek() {
    final ids = _gameweeks.map((e) => e['id']?.toString() ?? '').toList();
    if (ids.isEmpty) return;
    final idx = _selectedGameweek != null ? ids.indexOf(_selectedGameweek!) : -1;
    if (idx > 0) {
      _onGameweekChanged(ids[idx - 1]);
    } else if (idx == -1) {
      _onGameweekChanged(ids.last);
    } else {
      _onGameweekChanged(null);
    }
  }

  void _goToNextGameweek() {
    final ids = _gameweeks.map((e) => e['id']?.toString() ?? '').toList();
    if (ids.isEmpty) return;
    final idx = _selectedGameweek != null ? ids.indexOf(_selectedGameweek!) : -1;
    if (idx >= 0 && idx < ids.length - 1) {
      _onGameweekChanged(ids[idx + 1]);
    } else if (idx == -1) {
      _onGameweekChanged(ids.first);
    } else {
      _onGameweekChanged(null);
    }
  }

  String get _gameweekLabel {
    if (_selectedGameweek == null) return 'All gameweeks';
    for (final g in _gameweeks) {
      if (g['id']?.toString() == _selectedGameweek) {
        return 'Gameweek ${g['week']}';
      }
    }
    return 'All gameweeks';
  }

  (bool, bool) get _gameweekNav {
    final ids = _gameweeks.map((e) => e['id']?.toString() ?? '').toList();
    if (ids.isEmpty) return (false, false);
    final idx = _selectedGameweek != null ? ids.indexOf(_selectedGameweek!) : -1;
    return (idx > 0 || idx == -1, (idx >= 0 && idx < ids.length - 1) || idx == -1);
  }

  Map<String, List<MatchModel>> get _grouped {
    final map = <String, List<MatchModel>>{};
    for (final m in _matches) {
      final key =
          '${m.matchDate.year}-${m.matchDate.month.toString().padLeft(2, '0')}-${m.matchDate.day.toString().padLeft(2, '0')}';
      map.putIfAbsent(key, () => []).add(m);
    }
    return map;
  }

  static String _truncate(String text, [int max = 16]) {
    if (text.length <= max) return text;
    return '${text.substring(0, max)}…';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final (canPrev, canNext) = _gameweekNav;

    return RefreshIndicator(
      onRefresh: () async {
        await _loadFilters();
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            automaticallyImplyLeading: false,
            toolbarHeight: 164.0,
            expandedHeight: 164.0,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  // Filter row
                  SizedBox(
                    height: 64,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          const SizedBox(width: 4),
                          // Season filter
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: SizedBox(
                              width: 130,
                              child: DropdownMenu<String>(
                                initialSelection: _selectedSeason ?? '',
                                label: const Text('Season'),
                                dropdownMenuEntries: [
                                  const DropdownMenuEntry(
                                      value: '', label: 'All seasons'),
                                  ..._seasons.map((s) => DropdownMenuEntry(
                                        value: s.id,
                                        label: _truncate(s.seasonName),
                                      )),
                                ],
                                onSelected: _onSeasonChanged,
                              ),
                            ),
                          ),
                          // Gameweek filter
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: SizedBox(
                              width: 100,
                              child: DropdownMenu<String>(
                                initialSelection: _selectedGameweek ?? '',
                                label: const Text('GW'),
                                dropdownMenuEntries: [
                                  const DropdownMenuEntry(
                                      value: '', label: 'All GW'),
                                  ..._gameweeks.map((g) {
                                    final id = g['id']?.toString() ?? '';
                                    final week = g['week']?.toString() ?? '?';
                                    return DropdownMenuEntry(
                                        value: id, label: 'GW $week');
                                  }),
                                ],
                                onSelected: _onGameweekChanged,
                              ),
                            ),
                          ),
                          // Team filter
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: SizedBox(
                              width: 130,
                              child: DropdownMenu<String>(
                                initialSelection: _selectedTeam ?? '',
                                label: const Text('Teams'),
                                dropdownMenuEntries: [
                                  const DropdownMenuEntry(
                                      value: '', label: 'All teams'),
                                  ..._teams.map((t) => DropdownMenuEntry(
                                        value: t.id,
                                        label: _truncate(t.displayName),
                                      )),
                                ],
                                onSelected: _onTeamChanged,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Gameweek header
                  SizedBox(
                    height: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: canPrev ? _goToPreviousGameweek : null,
                              tooltip: 'Previous gameweek',
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: canNext ? _goToNextGameweek : null,
                              tooltip: 'Next gameweek',
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        Center(
                          child: Text(
                            _gameweekLabel,
                            style: textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Match list
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
            sliver: SliverToBoxAdapter(
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _error != null
                      ? Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Could not load matches',
                                    style: textTheme.bodyLarge),
                                const SizedBox(height: 8),
                                Text(_error!,
                                    style: textTheme.bodySmall,
                                    textAlign: TextAlign.center),
                              ],
                            ),
                          ),
                        )
                      : _buildMatchList(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchList(BuildContext context) {
    final grouped = _grouped;
    final dateKeys = grouped.keys.toList()..sort();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (dateKeys.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Text(
            'No matches',
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final key in dateKeys) ...[
          _buildDateGroup(context, key, grouped[key]!),
          const SizedBox(height: 2),
        ],
      ],
    );
  }

  Widget _buildDateGroup(
    BuildContext context,
    String dateKey,
    List<MatchModel> matches,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final firstId = matches.isNotEmpty ? matches.first.id : null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (firstId != null && firstId.isNotEmpty)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FixturePage(matchId: firstId),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Text(
                    formatMatchDateKey(dateKey),
                    style: textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            )
          else
            Text(
              formatMatchDateKey(dateKey),
              style: textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 8),
          for (int i = 0; i < matches.length; i++) ...[
            _buildMatchCard(context, matches[i]),
            if (i < matches.length - 1) const SizedBox(height: 2),
          ],
        ],
      ),
    );
  }

  Widget _buildMatchCard(BuildContext context, MatchModel match) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final clock = ref.watch(matchClockProvider(match.id));
    final ongoingTime = formatMatchClock(clock);

    if (match.status == MatchStatus.ongoing && clock == Duration.zero) {
      ref.read(matchClockProvider(match.id).notifier).start();
    }
    final statusLabel =
        match.status == MatchStatus.ongoing ? ongoingTime : match.statusText;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => FixturePage(matchId: match.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(match.teamA.shortForm,
                              style: textTheme.bodySmall),
                          const SizedBox(width: 8),
                          ClipOval(
                            child: _LeagueMatchTeamLogo(
                                path: match.teamA.logoPath, size: 28),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Builder(
                    builder: (context) {
                      if (match.status == MatchStatus.upcoming) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text(statusLabel,
                              style: textTheme.titleMedium),
                        );
                      }
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              match.scoreText ?? '',
                              style: textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (match.status == MatchStatus.ongoing ||
                                  match.status == MatchStatus.halfTime) ...[
                                Padding(
                                  padding: const EdgeInsets.only(right: 6.0),
                                  child: DodecagonIndicator(size: 12.0),
                                ),
                              ],
                              Text(statusLabel,
                                  style: textTheme.labelSmall),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipOval(
                            child: _LeagueMatchTeamLogo(
                                path: match.teamB.logoPath, size: 28),
                          ),
                          const SizedBox(width: 8),
                          Text(match.teamB.shortForm,
                              style: textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeagueMatchTeamLogo extends StatelessWidget {
  const _LeagueMatchTeamLogo({required this.path, this.size = 28});

  final String path;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isNetwork =
        path.startsWith('http://') || path.startsWith('https://');
    return SizedBox(
      width: size,
      height: size,
      child: isNetwork
          ? Image.network(
              path,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            )
          : Image.asset(
              path,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => SizedBox(
                width: size,
                height: size,
                child: Icon(
                  Icons.sports_soccer,
                  size: size * 0.6,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Player stats tab
// ---------------------------------------------------------------------------

class _LeaguePlayerStatsTab extends StatefulWidget {
  const _LeaguePlayerStatsTab({required this.leagueId});

  final String leagueId;

  @override
  State<_LeaguePlayerStatsTab> createState() => _LeaguePlayerStatsTabState();
}

class _LeaguePlayerStatsTabState extends State<_LeaguePlayerStatsTab> {
  List<Map<String, dynamic>>? _stats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data =
          await LeaguesRepository().getLeaguePlayerStats(widget.leagueId);
      if (!mounted) return;
      setState(() {
        _stats = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _topPlayers(
    double Function(Map<String, dynamic>) getValue, {
    int limit = 3,
  }) {
    if (_stats == null || _stats!.isEmpty) return [];
    final sorted = List<Map<String, dynamic>>.from(_stats!)
      ..sort((a, b) => getValue(b).compareTo(getValue(a)));
    return sorted.take(limit).toList();
  }

  double _perMatch(Map<String, dynamic> row, String totalKey) {
    final total = (row[totalKey] as num?)?.toDouble() ?? 0;
    final played = (row['matches_played'] as num?)?.toDouble() ?? 0;
    if (played == 0) return 0;
    return total / played;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Could not load player stats', style: textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text(_error!,
                style: textTheme.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_stats == null || _stats!.isEmpty) {
      return Center(
        child: Text(
          'No player stats yet — play some matches!',
          style: textTheme.bodyLarge
              ?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    final sections = <_PlayerStatSectionData>[
      _PlayerStatSectionData(
        title: 'Top scorer',
        players: _topPlayers((r) => (r['total_goals'] as num?)?.toDouble() ?? 0),
        format: (r) => (r['total_goals'] ?? 0).toString(),
      ),
      _PlayerStatSectionData(
        title: 'Assists',
        players:
            _topPlayers((r) => (r['total_assists'] as num?)?.toDouble() ?? 0),
        format: (r) => (r['total_assists'] ?? 0).toString(),
      ),
      _PlayerStatSectionData(
        title: 'Goals + Assists',
        players:
            _topPlayers((r) => (r['goals_assists'] as num?)?.toDouble() ?? 0),
        format: (r) => (r['goals_assists'] ?? 0).toString(),
      ),
      _PlayerStatSectionData(
        title: 'Saves',
        players:
            _topPlayers((r) => (r['total_saves'] as num?)?.toDouble() ?? 0),
        format: (r) => (r['total_saves'] ?? 0).toString(),
      ),
      _PlayerStatSectionData(
        title: 'Yellow cards',
        players: _topPlayers(
            (r) => (r['total_yellow_cards'] as num?)?.toDouble() ?? 0),
        format: (r) => (r['total_yellow_cards'] ?? 0).toString(),
      ),
      _PlayerStatSectionData(
        title: 'Red cards',
        players: _topPlayers(
            (r) => (r['total_red_cards'] as num?)?.toDouble() ?? 0),
        format: (r) => (r['total_red_cards'] ?? 0).toString(),
      ),
      _PlayerStatSectionData(
        title: 'Tackles',
        players:
            _topPlayers((r) => (r['total_tackles'] as num?)?.toDouble() ?? 0),
        format: (r) => (r['total_tackles'] ?? 0).toString(),
      ),
      _PlayerStatSectionData(
        title: 'Missed opportunities',
        players: _topPlayers(
            (r) => (r['missed_opportunities'] as num?)?.toDouble() ?? 0),
        format: (r) => (r['missed_opportunities'] ?? 0).toString(),
      ),
      _PlayerStatSectionData(
        title: 'Footystats rating',
        players:
            _topPlayers((r) => (r['avg_rating'] as num?)?.toDouble() ?? 0),
        format: (r) =>
            ((r['avg_rating'] as num?)?.toDouble() ?? 0).toStringAsFixed(2),
      ),
      _PlayerStatSectionData(
        title: 'Expected goals (xG)',
        players: _topPlayers((r) => (r['total_xg'] as num?)?.toDouble() ?? 0),
        format: (r) =>
            ((r['total_xg'] as num?)?.toDouble() ?? 0).toStringAsFixed(1),
      ),
      _PlayerStatSectionData(
        title: 'Shots on target',
        players: _topPlayers(
            (r) => (r['total_shots_on_target'] as num?)?.toDouble() ?? 0),
        format: (r) => (r['total_shots_on_target'] ?? 0).toString(),
      ),
      _PlayerStatSectionData(
        title: 'Goals per match',
        players: _topPlayers((r) => _perMatch(r, 'total_goals')),
        format: (r) => _perMatch(r, 'total_goals').toStringAsFixed(1),
      ),
      _PlayerStatSectionData(
        title: 'xG per match',
        players: _topPlayers((r) => _perMatch(r, 'total_xg')),
        format: (r) => _perMatch(r, 'total_xg').toStringAsFixed(1),
      ),
      _PlayerStatSectionData(
        title: 'Shots per match',
        players: _topPlayers((r) => _perMatch(r, 'total_shots')),
        format: (r) => _perMatch(r, 'total_shots').toStringAsFixed(1),
      ),
      _PlayerStatSectionData(
        title: 'Expected assists (xA)',
        players: _topPlayers((r) => (r['total_xa'] as num?)?.toDouble() ?? 0),
        format: (r) =>
            ((r['total_xa'] as num?)?.toDouble() ?? 0).toStringAsFixed(1),
      ),
      _PlayerStatSectionData(
        title: 'Saves per match',
        players: _topPlayers((r) => _perMatch(r, 'total_saves')),
        format: (r) => _perMatch(r, 'total_saves').toStringAsFixed(1),
      ),
    ];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: sections.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) =>
            _PlayerStatSectionCard(section: sections[index]),
      ),
    );
  }
}

class _PlayerStatSectionData {
  const _PlayerStatSectionData({
    required this.title,
    required this.players,
    required this.format,
  });

  final String title;
  final List<Map<String, dynamic>> players;
  final String Function(Map<String, dynamic>) format;
}

class _PlayerStatSectionCard extends StatelessWidget {
  const _PlayerStatSectionCard({required this.section});

  final _PlayerStatSectionData section;

  String _resolveLogoPath(String raw) {
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('lib/assets/') || raw.startsWith('assets/')) return raw;
    final name = raw.contains('.') ? raw : '$raw.png';
    return '${AppAssets.teamLogosPath}$name';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(section.title, style: textTheme.titleSmall),
              ),
              Icon(Icons.chevron_right,
                  size: 20, color: colorScheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 12),
          if (section.players.isEmpty)
            Text(
              'No data yet',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (int i = 0; i < section.players.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _buildPlayerRow(context, i, section.players[i]),
            ],
        ],
      ),
    );
  }

  Widget _buildPlayerRow(
    BuildContext context,
    int index,
    Map<String, dynamic> row,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final playerName = row['player_name']?.toString() ?? 'Unknown';
    final imageUrl = row['image_url']?.toString() ?? '';
    final teamLogoRaw = row['team_logo']?.toString() ?? '';
    final teamLogoPath = _resolveLogoPath(teamLogoRaw);
    final value = section.format(row);
    final isTop = index == 0;

    return Row(
      children: [
        _PlayerStatsAvatar(imageUrl: imageUrl, radius: 18),
        const SizedBox(width: 12),
        if (teamLogoPath.isNotEmpty) ...[
          ClipOval(child: _TeamStatsLogo(path: teamLogoPath, size: 20)),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            playerName,
            style: textTheme.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isTop)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          )
        else
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _PlayerStatsAvatar extends StatelessWidget {
  const _PlayerStatsAvatar({required this.imageUrl, this.radius = 18});

  final String imageUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (imageUrl.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: colorScheme.surfaceContainerHighest,
        child:
            Icon(Icons.person, size: radius, color: colorScheme.onSurfaceVariant),
      );
    }
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: colorScheme.surfaceContainerHighest,
        backgroundImage: NetworkImage(imageUrl),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: colorScheme.surfaceContainerHighest,
      backgroundImage: AssetImage(imageUrl),
    );
  }
}

// ---------------------------------------------------------------------------
// Videos tab – real league videos with sort + grid/feed toggle
// ---------------------------------------------------------------------------

enum _VideoSortOrder { newest, oldest, mostLiked, mostViewed }

class _LeagueVideosTab extends StatefulWidget {
  const _LeagueVideosTab({required this.leagueId});

  final String leagueId;

  @override
  State<_LeagueVideosTab> createState() => _LeagueVideosTabState();
}

class _LeagueVideosTabState extends State<_LeagueVideosTab> {
  List<LeagueVideoItem>? _videos;
  bool _isLoading = true;
  String? _error;
  _VideoSortOrder _sortOrder = _VideoSortOrder.newest;
  bool _isFeedLayout = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final rawVideos =
          await LeaguesRepository().getLeagueVideos(widget.leagueId);
      if (!mounted) return;
      final enriched = await _enrichVideos(rawVideos);
      if (!mounted) return;
      setState(() {
        _videos = enriched;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<List<LeagueVideoItem>> _enrichVideos(
    List<Map<String, dynamic>> rawVideos,
  ) async {
    if (rawVideos.isEmpty) return [];
    final client = Supabase.instance.client;
    final currentUserId = client.auth.currentUser?.id;

    final matchIds = <String>{};
    final uploaderIds = <String>{};
    final videoIds = <String>[];
    for (final v in rawVideos) {
      final mid = v['match_id']?.toString();
      if (mid != null && mid.isNotEmpty) matchIds.add(mid);
      final uid = v['uploader_user_id']?.toString();
      if (uid != null && uid.isNotEmpty) uploaderIds.add(uid);
      final vid = v['id']?.toString();
      if (vid != null && vid.isNotEmpty) videoIds.add(vid);
    }

    // Batch fetch matches
    final matchesMap = <String, Map<String, dynamic>>{};
    if (matchIds.isNotEmpty) {
      final matchesRes = await client
          .from('matches')
          .select(
            'id, status, "teamA_score", "teamB_score", '
            'teamA:teams!teamA(id, logo_id, short_form), '
            'teamB:teams!teamB(id, logo_id, short_form)',
          )
          .inFilter('id', matchIds.toList());
      for (final m in List<Map<String, dynamic>>.from(matchesRes as List)) {
        final id = m['id']?.toString();
        if (id != null) matchesMap[id] = m;
      }
    }

    // Batch fetch uploaders
    final uploadersMap = <String, Map<String, dynamic>>{};
    if (uploaderIds.isNotEmpty) {
      final uploadersRes = await client
          .from('players')
          .select('id, player_name, image_url')
          .inFilter('id', uploaderIds.toList());
      for (final p in List<Map<String, dynamic>>.from(uploadersRes as List)) {
        final id = p['id']?.toString();
        if (id != null) uploadersMap[id] = p;
      }
    }

    // Fetch follows
    final followsSet = <String>{};
    if (currentUserId != null && uploaderIds.isNotEmpty) {
      try {
        final followsRes = await client
            .from('user_follows')
            .select('following_user_id')
            .eq('follower_user_id', currentUserId)
            .inFilter('following_user_id', uploaderIds.toList());
        for (final f in List<Map<String, dynamic>>.from(followsRes as List)) {
          final fid = f['following_user_id']?.toString();
          if (fid != null) followsSet.add(fid);
        }
      } catch (_) {}
    }

    // Fetch likes
    final likedVideoIds = <String>{};
    final likeCountMap = <String, int>{};
    if (videoIds.isNotEmpty) {
      try {
        final likesRes = await client
            .from('video_likes')
            .select('video_id, user_id')
            .inFilter('video_id', videoIds);
        for (final l in List<Map<String, dynamic>>.from(likesRes as List)) {
          final vid = l['video_id']?.toString();
          final uid = l['user_id']?.toString();
          if (vid != null) {
            likeCountMap[vid] = (likeCountMap[vid] ?? 0) + 1;
            if (uid == currentUserId) likedVideoIds.add(vid);
          }
        }
      } catch (_) {}
    }

    // Fetch view counts from feed_interactions
    final viewCountMap = <String, int>{};
    if (videoIds.isNotEmpty) {
      try {
        final viewRes = await client
            .from('feed_interactions')
            .select('video_id')
            .inFilter('video_id', videoIds);
        for (final row in List<Map<String, dynamic>>.from(viewRes as List)) {
          final vid = row['video_id']?.toString();
          if (vid != null) {
            viewCountMap[vid] = (viewCountMap[vid] ?? 0) + 1;
          }
        }
      } catch (_) {}
    }

    return rawVideos.map((v) {
      final match =
          matchesMap[v['match_id']?.toString()] ?? <String, dynamic>{};
      final teamA = match['teamA'] as Map<String, dynamic>? ?? {};
      final teamB = match['teamB'] as Map<String, dynamic>? ?? {};
      final uploader =
          uploadersMap[v['uploader_user_id']?.toString()] ?? <String, dynamic>{};
      final vid = v['id']?.toString() ?? '';
      final uploaderUserId = v['uploader_user_id']?.toString();

      final teamAScore = match['teamA_score'] is int
          ? match['teamA_score'] as int
          : int.tryParse(match['teamA_score']?.toString() ?? '0') ?? 0;
      final teamBScore = match['teamB_score'] is int
          ? match['teamB_score'] as int
          : int.tryParse(match['teamB_score']?.toString() ?? '0') ?? 0;

      DateTime? createdAt;
      final raw = v['created_at'];
      if (raw is String) createdAt = DateTime.tryParse(raw);

      return LeagueVideoItem(
        videoId: vid,
        videoUrl: v['video_url']?.toString() ?? '',
        thumbnailUrl: v['thumbnail_url']?.toString(),
        durationSeconds: v['duration_seconds'] as int?,
        createdAt: createdAt,
        teamAShort: teamA['short_form']?.toString() ?? 'Team A',
        teamBShort: teamB['short_form']?.toString() ?? 'Team B',
        teamALogo: _resolveVideoLogoPath(teamA['logo_id']?.toString()),
        teamBLogo: _resolveVideoLogoPath(teamB['logo_id']?.toString()),
        teamAScore: teamAScore,
        teamBScore: teamBScore,
        matchStatus: match['status']?.toString() ?? '',
        uploaderName: uploader['player_name']?.toString(),
        uploaderAvatar: uploader['image_url']?.toString(),
        uploaderUserId: uploaderUserId,
        isLiked: likedVideoIds.contains(vid),
        likeCount: likeCountMap[vid] ?? 0,
        isFollowing:
            uploaderUserId != null && followsSet.contains(uploaderUserId),
        viewCount: viewCountMap[vid] ?? 0,
      );
    }).toList();
  }

  static String _resolveVideoLogoPath(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('lib/assets/') || raw.startsWith('assets/')) return raw;
    final name = raw.contains('.') ? raw : '$raw.png';
    return '${AppAssets.teamLogosPath}$name';
  }

  List<LeagueVideoItem> get _sortedVideos {
    if (_videos == null) return [];
    final list = List<LeagueVideoItem>.from(_videos!);
    switch (_sortOrder) {
      case _VideoSortOrder.newest:
        list.sort((a, b) =>
            (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      case _VideoSortOrder.oldest:
        list.sort((a, b) =>
            (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));
      case _VideoSortOrder.mostLiked:
        list.sort((a, b) => b.likeCount.compareTo(a.likeCount));
      case _VideoSortOrder.mostViewed:
        list.sort((a, b) => b.viewCount.compareTo(a.viewCount));
    }
    return list;
  }

  String get _sortLabel {
    switch (_sortOrder) {
      case _VideoSortOrder.newest:
        return 'Newest';
      case _VideoSortOrder.oldest:
        return 'Oldest';
      case _VideoSortOrder.mostLiked:
        return 'Most liked';
      case _VideoSortOrder.mostViewed:
        return 'Most viewed';
    }
  }

  void _openVideoPlayer(int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LeagueVideoPlayerPage(
          videos: _sortedVideos,
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Could not load videos', style: textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text(_error!,
                style: textTheme.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final sorted = _sortedVideos;

    return RefreshIndicator(
      onRefresh: _load,
      child: Column(
        children: [
          // Header: sort + layout toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                PopupMenuButton<_VideoSortOrder>(
                  onSelected: (v) => setState(() => _sortOrder = v),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: _VideoSortOrder.newest,
                      child: Text('Newest'),
                    ),
                    PopupMenuItem(
                      value: _VideoSortOrder.oldest,
                      child: Text('Oldest'),
                    ),
                    PopupMenuItem(
                      value: _VideoSortOrder.mostLiked,
                      child: Text('Most liked'),
                    ),
                    PopupMenuItem(
                      value: _VideoSortOrder.mostViewed,
                      child: Text('Most viewed'),
                    ),
                  ],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swap_vert,
                          size: 20, color: colorScheme.onSurface),
                      const SizedBox(width: 8),
                      Text(
                        _sortLabel,
                        style: textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurface),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    _isFeedLayout ? Icons.grid_view : Icons.view_list,
                    size: 20,
                    color: colorScheme.onSurface,
                  ),
                  onPressed: () =>
                      setState(() => _isFeedLayout = !_isFeedLayout),
                ),
              ],
            ),
          ),

          // Content
          if (sorted.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'No videos yet — upload from a match!',
                  style: textTheme.bodyLarge
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ),
            )
          else if (_isFeedLayout)
            Expanded(child: _buildFeedView(sorted))
          else
            Expanded(child: _buildGridView(sorted)),
        ],
      ),
    );
  }

  Widget _buildGridView(List<LeagueVideoItem> videos) {
    final colorScheme = Theme.of(context).colorScheme;
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 121.33 / 204,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final v = videos[index];
        return GestureDetector(
          onTap: () => _openVideoPlayer(index),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(28),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildThumbnail(v),
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_arrow,
                              color: Colors.white, size: 12),
                          if (v.durationSeconds != null) ...[
                            const SizedBox(width: 2),
                            Text(
                              _formatDuration(v.durationSeconds!),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 10),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeedView(List<LeagueVideoItem> videos) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final v = videos[index];
        return GestureDetector(
          onTap: () => _openVideoPlayer(index),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Match info header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      _FeedTeamLogo(logoPath: v.teamALogo, size: 24),
                      const SizedBox(width: 6),
                      Text(v.teamAShort,
                          style: textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      Text(
                        '${v.teamAScore} - ${v.teamBScore}',
                        style: textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 6),
                      Text(v.teamBShort,
                          style: textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      _FeedTeamLogo(logoPath: v.teamBLogo, size: 24),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          v.matchStatus,
                          style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSecondaryContainer),
                        ),
                      ),
                    ],
                  ),
                ),
                // Thumbnail
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildThumbnail(v),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Colors.black38,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.play_arrow,
                              color: Colors.white, size: 32),
                        ),
                      ),
                    ],
                  ),
                ),
                // Poster info
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      _FeedPosterAvatar(
                        avatarUrl: v.uploaderAvatar,
                        name: v.uploaderName ?? 'Unknown',
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          v.uploaderName ?? 'Unknown',
                          style: textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.favorite,
                          size: 16,
                          color: v.isLiked
                              ? Colors.red
                              : colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text('${v.likeCount}', style: textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThumbnail(LeagueVideoItem v) {
    final url = v.thumbnailUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.asset(
          AppAssets.highlightPlaceholder,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Icon(Icons.play_circle_outline,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }
    return Image.asset(
      AppAssets.highlightPlaceholder,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(Icons.play_circle_outline,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _FeedTeamLogo extends StatelessWidget {
  const _FeedTeamLogo({required this.logoPath, this.size = 24});
  final String logoPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (logoPath.isEmpty) {
      return Icon(Icons.groups, size: size,
          color: Theme.of(context).colorScheme.onSurfaceVariant);
    }
    final isNetwork =
        logoPath.startsWith('http://') || logoPath.startsWith('https://');
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: isNetwork
            ? Image.network(logoPath, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(Icons.groups,
                    size: size * 0.7,
                    color: Theme.of(context).colorScheme.onSurfaceVariant))
            : Image.asset(logoPath, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(Icons.groups,
                    size: size * 0.7,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ),
    );
  }
}

class _FeedPosterAvatar extends StatelessWidget {
  const _FeedPosterAvatar({this.avatarUrl, required this.name});
  final String? avatarUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final hasImage = avatarUrl != null && avatarUrl!.isNotEmpty;
    final isNetwork =
        hasImage && (avatarUrl!.startsWith('http://') || avatarUrl!.startsWith('https://'));
    return CircleAvatar(
      radius: 12,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      backgroundImage:
          hasImage ? (isNetwork ? NetworkImage(avatarUrl!) : null) : null,
      child: !hasImage
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            )
          : null,
    );
  }
}

