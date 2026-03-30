import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_assets.dart';
import '../../data/repositories/leagues_repository.dart';
import '../../data/repositories/teams_repository.dart';
import '../../data/repositories/matches_repository.dart';
import '../../domain/models/match_model.dart';
import '../../domain/models/season_model.dart';
import 'league_detail_page.dart';
import 'fixture.dart';
import 'league_video_player_page.dart';
import 'matches.dart' show DodecagonIndicator;
import '../providers/matches_provider.dart';
import '../providers/seasons_provider.dart';
import 'team_manage_applications_page.dart';
import '../widgets/socials_section_card.dart';
import 'team_rejected_applications_page.dart';

class TeamDetailPage extends StatefulWidget {
  const TeamDetailPage({super.key, required this.teamId});

  final String teamId;

  @override
  State<TeamDetailPage> createState() => _TeamDetailPageState();
}

class _TeamDetailPageState extends State<TeamDetailPage> {
  Map<String, dynamic>? _team;
  bool _isLoading = true;
  bool _isDeleting = false;
  bool _hasJoined = false;
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    _loadTeam();
  }

  Future<void> _loadTeam() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('teams')
          .select()
          .eq('id', widget.teamId)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _team = response;
          _isLoading = false;
        });
        await _refreshJoinState();
      } else if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Team not found')));
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading team: $error')));
    }
  }

  Future<void> _refreshJoinState() async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      final membership = await supabase
          .from('player_team_memberships')
          .select('id')
          .eq('team_id', widget.teamId)
          .eq('player_id', currentUser.id)
          .maybeSingle();

      final joinRequest = await supabase
          .from('team_join_requests')
          .select('id, status')
          .eq('team_id', widget.teamId)
          .eq('player_id', currentUser.id)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _hasJoined = membership != null || joinRequest != null;
      });
    } catch (_) {
      // Ignore join state errors; keep existing UI state.
    }
  }

  Future<void> _handleJoinTeam() async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need to be logged in to join a team'),
        ),
      );
      return;
    }

    if (_hasJoined || _isJoining) return;

    setState(() {
      _isJoining = true;
    });

    try {
      final playerId = currentUser.id;

      // Create a join request (player is added to memberships when accepted)
      await supabase.from('team_join_requests').insert({
        'team_id': widget.teamId,
        'player_id': playerId,
      });

      if (!mounted) return;

      setState(() {
        _hasJoined = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your join request has been sent.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not join team: $error')));
    } finally {
      if (!mounted) return;
      setState(() {
        _isJoining = false;
      });
    }
  }

  Future<void> _deleteTeam() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Team'),
        content: const Text(
          'Are you sure you want to delete this team? This action cannot be undone.',
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
      await supabase.from('teams').delete().eq('id', widget.teamId);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Team deleted')));
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting team: $error')));
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

    if (_team == null) {
      return Scaffold(
        appBar: AppBar(title: const SizedBox.shrink(), centerTitle: false),
        body: const Center(child: Text('Team not found')),
      );
    }

    final teamName = _team!['team_name'] as String? ?? 'Unknown';
    final shortForm = _team!['short_form'] as String? ?? '';
    final logoUrl = _team!['logo_id'] as String?;
    final createdBy = _team!['created_by']?.toString();
    final createdAt = _team!['created_at'];
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
          if (!isOwner) ...[
            IconButton(
              icon: SvgPicture.asset(
                AppAssets.teamCompareIcon,
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(
                  colorScheme.onSurface,
                  BlendMode.srcIn,
                ),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Team compare coming soon')),
                );
              },
              tooltip: 'Compare team',
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: _hasJoined
                  ? const FilledButton(
                      onPressed: null,
                      child: Icon(Icons.check),
                    )
                  : FilledButton(
                      onPressed: _isJoining ? null : _handleJoinTeam,
                      child: _isJoining
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Join team'),
                    ),
            ),
          ] else if (_isDeleting)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            IconButton(
              icon: SvgPicture.asset(
                AppAssets.teamCompareIcon,
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(
                  colorScheme.onSurface,
                  BlendMode.srcIn,
                ),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Team compare coming soon')),
                );
              },
              tooltip: 'Compare team',
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'More options',
              onSelected: (value) {
                switch (value) {
                  case 'edit_squad':
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Edit squad (coming soon)')),
                    );
                    break;
                  case 'manage_applications':
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) =>
                            TeamManageApplicationsPage(teamId: widget.teamId),
                      ),
                    );
                    break;
                  case 'rejected_applications':
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) =>
                            TeamRejectedApplicationsPage(teamId: widget.teamId),
                      ),
                    );
                    break;
                  case 'add_players':
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Add players to team (coming soon)'),
                      ),
                    );
                    break;
                  case 'leave_team':
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Leave team (coming soon)')),
                    );
                    break;
                  case 'delete':
                    _deleteTeam();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'edit_squad',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 16),
                      Text('Edit squad'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'manage_applications',
                  child: Row(
                    children: [
                      Icon(Icons.how_to_reg),
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
                  value: 'add_players',
                  child: Row(
                    children: [
                      Icon(Icons.person_add),
                      SizedBox(width: 16),
                      Text('Add players to team'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'leave_team',
                  child: Row(
                    children: [
                      Icon(Icons.exit_to_app),
                      SizedBox(width: 16),
                      Text('Leave team'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: colorScheme.error),
                      const SizedBox(width: 16),
                      Text(
                        'Delete team',
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: DefaultTabController(
        length: 7,
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
                                        Icons.groups,
                                        size: 44,
                                        color: colorScheme.onSurfaceVariant,
                                      );
                                    },
                                  ),
                                )
                              : Icon(
                                  Icons.groups,
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
                                teamName,
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
                              if (shortForm.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  shortForm,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
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
                        Tab(text: 'Stats'),
                        Tab(text: 'Top players'),
                        Tab(text: 'Squad'),
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
                  _TeamOverviewTab(teamId: widget.teamId, team: _team!),
                  _TeamMatchesTab(teamId: widget.teamId),
                  _TeamStandingsTab(teamId: widget.teamId),
                  _TeamSummaryStatsTab(teamId: widget.teamId),
                  _TeamStatsTab(teamId: widget.teamId),
                  _SquadTab(teamId: widget.teamId),
                  _TeamVideosTab(teamId: widget.teamId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Team Overview Tab – upcoming match card
// ---------------------------------------------------------------------------
class _TeamOverviewTab extends StatelessWidget {
  const _TeamOverviewTab({required this.teamId, required this.team});

  final String teamId;
  final Map<String, dynamic> team;

  static const _monthAbbr = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _formatRelativeDay(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(d.year, d.month, d.day);
    final diff = date.difference(today).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';

    final month = _monthAbbr[d.month - 1];
    return '${d.day} $month';
  }

  ImageProvider _logoProvider(String logoPath) {
    if (logoPath.startsWith('http://') || logoPath.startsWith('https://')) {
      return NetworkImage(logoPath);
    }
    return AssetImage(logoPath);
  }

  ImageProvider? _leagueLogoProvider(String? logoId) {
    final lid = (logoId ?? '').trim();
    if (lid.isEmpty) return null;
    try {
      if (lid.startsWith('http://') || lid.startsWith('https://')) {
        return NetworkImage(lid);
      }
      // If it's an asset path (or filename that matches an asset path),
      // AssetImage will work as long as the string points to a valid asset.
      return AssetImage(lid);
    } catch (_) {
      return null;
    }
  }

  Future<_TeamOverviewMatch?> _fetchNextUpcomingMatchCard() async {
    final matches = await MatchesRepository().getMatches(teamIds: [teamId]);
    if (matches.isEmpty) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Prefer the next upcoming match from today onwards.
    final upcoming = matches
        .where((m) =>
            m.status == MatchStatus.upcoming && !m.matchDate.isBefore(today))
        .toList();
    MatchModel? selected;
    if (upcoming.isNotEmpty) selected = upcoming.first;

    // Fallback: ongoing/half-time match (useful if there is nothing upcoming
    // later today).
    final live = matches.where((m) {
      if (m.status != MatchStatus.ongoing && m.status != MatchStatus.halfTime) {
        return false;
      }
      return !m.matchDate.isBefore(today);
    }).toList();
    selected ??= (live.isNotEmpty ? live.first : null);

    if (selected == null) return null;

    // Fetch league logo by league_name.
    final leagueName = (selected.leagueName ?? '').trim();
    String? logoId;
    String? leagueId;
    if (leagueName.isNotEmpty) {
      try {
        final res = await Supabase.instance.client
            .from('leagues')
            .select('id, logo_id')
            .eq('league_name', leagueName)
            .maybeSingle();
        logoId = res?['logo_id']?.toString();
        leagueId = res?['id']?.toString();
      } catch (_) {
        logoId = null;
        leagueId = null;
      }
    }

    return _TeamOverviewMatch(
      match: selected,
      leagueLogoId: logoId,
      leagueId: leagueId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FutureBuilder<_TeamOverviewMatch?>(
            future: _fetchNextUpcomingMatchCard(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox.shrink();
              }

              final data = snapshot.data;
              if (data == null) {
                return Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No upcoming match found.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }

              final match = data.match;
              final leagueLogoProvider =
                  _leagueLogoProvider(data.leagueLogoId);
              final leagueId = data.leagueId;

              final league = (match.leagueName ?? '').trim();
              final topLabel = league.isNotEmpty ? league : '';

              final dayLabel = _formatRelativeDay(match.matchDate);
              final timeLabel = match.timeDisplay;

              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        if (leagueId == null || leagueId.isEmpty) return;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LeagueDetailPage(leagueId: leagueId),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: leagueLogoProvider != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image(
                                        image: leagueLogoProvider,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Icon(
                                      Icons.emoji_events_outlined,
                                      size: 18,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                topLabel.isNotEmpty
                                    ? topLabel
                                    : 'Upcoming match',
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              size: 22,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    borderRadius: BorderRadius.circular(28),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FixturePage(matchId: match.id),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor:
                                    colorScheme.surfaceContainerHighest,
                                backgroundImage:
                                    _logoProvider(match.teamA.logoPath),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                match.teamA.shortForm,
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              Text(
                                timeLabel,
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                dayLabel,
                                style: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor:
                                    colorScheme.surfaceContainerHighest,
                                backgroundImage:
                                    _logoProvider(match.teamB.logoPath),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                match.teamB.shortForm,
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _TeamFormSection(teamId: teamId),
          const SizedBox(height: 16),
          _TeamTrophiesSection(teamId: teamId),
          const SizedBox(height: 16),
          SocialsSectionCard(
            title: 'Team socials',
            instagramUrl: team['social_instagram']?.toString(),
            tiktokUrl: team['social_tiktok']?.toString(),
            xUrl: team['social_x']?.toString(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Trophies — ended leagues where this team finished 1st (no team filters)
// ---------------------------------------------------------------------------
class _TeamTrophiesSection extends StatefulWidget {
  const _TeamTrophiesSection({required this.teamId});

  final String teamId;

  @override
  State<_TeamTrophiesSection> createState() => _TeamTrophiesSectionState();
}

class _TeamTrophiesSectionState extends State<_TeamTrophiesSection> {
  List<_TeamTrophyRow> _rows = [];
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
      final raw =
          await LeaguesRepository().getChampionTrophiesForTeam(widget.teamId);
      final byName = <String, List<Map<String, dynamic>>>{};
      for (final t in raw) {
        final name = t['league_name']?.toString() ?? 'League';
        byName.putIfAbsent(name, () => []).add(t);
      }
      final rows = <_TeamTrophyRow>[];
      for (final entry in byName.entries) {
        final years = entry.value
            .map((m) => m['end_year'] as int)
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
        final logoId = entry.value.first['logo_id']?.toString();
        rows.add(_TeamTrophyRow(
          leagueName: entry.key,
          logoId: logoId,
          yearsLabel: years.join(', '),
          count: years.length,
        ));
      }
      rows.sort((a, b) => a.leagueName.compareTo(b.leagueName));
      if (!mounted) return;
      setState(() {
        _rows = rows;
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(28),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Text(
          'Could not load trophies.',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Trophies', style: textTheme.titleSmall),
          const SizedBox(height: 16),
          if (_rows.isEmpty)
            Text(
              'No titles yet — win a league that has finished.',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else
            ..._rows.asMap().entries.map((entry) {
              final index = entry.key;
              final trophy = entry.value;
              return Column(
                children: [
                  Row(
                    children: [
                      _TeamTrophyLeagueThumb(logoId: trophy.logoId),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trophy.leagueName,
                              style: textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              trophy.yearsLabel,
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        trophy.count.toString(),
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (index < _rows.length - 1) ...[
                    const SizedBox(height: 8),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: colorScheme.outlineVariant,
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              );
            }),
        ],
      ),
    );
  }
}

class _TeamTrophyRow {
  const _TeamTrophyRow({
    required this.leagueName,
    required this.logoId,
    required this.yearsLabel,
    required this.count,
  });

  final String leagueName;
  final String? logoId;
  final String yearsLabel;
  final int count;
}

class _TeamTrophyLeagueThumb extends StatelessWidget {
  const _TeamTrophyLeagueThumb({this.logoId});

  final String? logoId;

  static String? _resolvedPath(String? raw) {
    final id = raw?.trim();
    if (id == null || id.isEmpty) return null;
    if (id.startsWith('http://') || id.startsWith('https://')) return id;
    if (id.startsWith('lib/assets/') || id.startsWith('assets/')) return id;
    final name = id.contains('.') ? id : '$id.png';
    return '${AppAssets.teamLogosPath}$name';
  }

  @override
  Widget build(BuildContext context) {
    final path = _resolvedPath(logoId);
    final colorScheme = Theme.of(context).colorScheme;
    if (path == null) {
      return SizedBox(
        width: 36,
        height: 36,
        child: Icon(
          Icons.emoji_events,
          size: 24,
          color: colorScheme.primary,
        ),
      );
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          path,
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => SizedBox(
            width: 36,
            height: 36,
            child: Icon(
              Icons.emoji_events,
              size: 24,
              color: colorScheme.primary,
            ),
          ),
        ),
      );
    }
    return Image.asset(
      path,
      width: 36,
      height: 36,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => SizedBox(
        width: 36,
        height: 36,
        child: Icon(
          Icons.emoji_events,
          size: 24,
          color: colorScheme.primary,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Team Form Section (recent results)
// ---------------------------------------------------------------------------
class _TeamFormSection extends StatefulWidget {
  const _TeamFormSection({required this.teamId});

  final String teamId;

  @override
  State<_TeamFormSection> createState() => _TeamFormSectionState();
}

class _TeamFormSectionState extends State<_TeamFormSection> {
  List<MatchModel> _recentMatches = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  ImageProvider _logoProvider(String logoPath) {
    if (logoPath.startsWith('http://') || logoPath.startsWith('https://')) {
      return NetworkImage(logoPath);
    }
    return AssetImage(logoPath);
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final matches = await MatchesRepository()
          .getMatches(teamIds: [widget.teamId], leagueIds: null);

      final completed = matches
          .where((m) =>
              m.status == MatchStatus.fullTime &&
              m.teamAScore != null &&
              m.teamBScore != null)
          .toList()
        ..sort((a, b) => b.matchDate.compareTo(a.matchDate));

      final recent = completed.take(6).toList();

      if (!mounted) return;
      setState(() {
        _recentMatches = recent;
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(28),
        ),
        padding: const EdgeInsets.all(16),
        child: Text(
          'Could not load team form.',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Team form', style: textTheme.titleSmall),
          const SizedBox(height: 8),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_recentMatches.length, (index) {
                  final match = _recentMatches[index];

                  final isTeamA = match.teamA.id == widget.teamId;
                  final myScore = isTeamA ? match.teamAScore : match.teamBScore;
                  final oppScore =
                      isTeamA ? match.teamBScore : match.teamAScore;
                  final opponent = isTeamA ? match.teamB : match.teamA;

                  final resultColor = (myScore != null && oppScore != null)
                      ? (myScore > oppScore
                          ? Colors.green
                          : (myScore < oppScore
                              ? Colors.red
                              : colorScheme.surfaceContainerHighest))
                      : colorScheme.surfaceContainerHighest;

                  final scoreText = (myScore != null && oppScore != null)
                      ? '$myScore - $oppScore'
                      : '—';

                  final isDraw = myScore != null && oppScore != null && myScore == oppScore;

                  final gwLabel = match.gameweekNumber != null
                      ? 'GW${match.gameweekNumber}'
                      : (match.gameweek ?? '');

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        children: [
                          Text(
                            gwLabel.isNotEmpty ? gwLabel : '—',
                            style: textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.transparent,
                            backgroundImage:
                                _logoProvider(opponent.logoPath),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            opponent.shortForm,
                            style: textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: resultColor,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              scoreText,
                              style: textTheme.labelSmall?.copyWith(
                                color: isDraw
                                    ? colorScheme.onSurface
                                    : Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (index < _recentMatches.length - 1)
                        const SizedBox(width: 24),
                    ],
                  );
                }),
              ),
            ),
          ),
          if (_recentMatches.isEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'No recent completed matches yet.',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TeamOverviewMatch {
  const _TeamOverviewMatch({
    required this.match,
    required this.leagueLogoId,
    required this.leagueId,
  });

  final MatchModel match;
  final String? leagueLogoId;
  final String? leagueId;
}

// ---------------------------------------------------------------------------
// Team Stats Tab – summary totals (matches, goals, assists, cards, xG/xA, etc.)
// ---------------------------------------------------------------------------
class _TeamSummaryStatsTab extends StatefulWidget {
  const _TeamSummaryStatsTab({required this.teamId});

  final String teamId;

  @override
  State<_TeamSummaryStatsTab> createState() => _TeamSummaryStatsTabState();
}

class _TeamSummaryStatsTabState extends State<_TeamSummaryStatsTab> {
  Map<String, dynamic>? _stats;
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
      final data = await TeamsRepository().getTeamSummaryStats(widget.teamId);
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

  String _intToString(dynamic v) {
    final n = (v as num?)?.toInt();
    return n == null ? '0' : n.toString();
  }

  String _doubleToFixed1(dynamic v) {
    final n = (v as num?)?.toDouble();
    if (n == null) return '0.0';
    return n.toStringAsFixed(1);
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
            Text(
              _error!,
              style: textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_stats == null || _stats!.isEmpty) {
      return Center(
        child: Text(
          'No stats yet — play some matches!',
          style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    final rows = <MapEntry<String, String>>[
      MapEntry('Matches', _intToString(_stats!['matches_played'])),
      MapEntry('Goals scored', _intToString(_stats!['goals_scored'])),
      MapEntry('Goals conceded', _intToString(_stats!['goals_conceded'])),
      MapEntry('Goal difference', _intToString(_stats!['goal_difference'])),
      MapEntry('Assists', _intToString(_stats!['assists'])),
      MapEntry('Clean sheets', _intToString(_stats!['clean_sheets'])),
      MapEntry('Shots on target', _intToString(_stats!['shots_on_target'])),
      MapEntry('Tackles', _intToString(_stats!['tackles'])),
      MapEntry('Saves', _intToString(_stats!['saves'])),
      MapEntry('Yellow cards', _intToString(_stats!['yellow_cards'])),
      MapEntry('Red cards', _intToString(_stats!['red_cards'])),
      MapEntry('Expected goals (xG)', _doubleToFixed1(_stats!['total_xg'])),
      MapEntry('Expected assists (xA)', _doubleToFixed1(_stats!['total_xa'])),
    ];

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(28),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Summary',
                    style: textTheme.titleSmall,
                  ),
                  const SizedBox(height: 14),
                  for (final row in rows) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              row.key,
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Text(
                            row.value,
                            style: textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SquadTab extends StatefulWidget {
  const _SquadTab({required this.teamId});

  final String teamId;

  @override
  State<_SquadTab> createState() => _SquadTabState();
}

class _SquadTabState extends State<_SquadTab> {
  bool _isEditing = false;
  final Map<String, Offset> _playerOffsets = {};
  final Map<String, Offset> _savedOffsets = {};
  final Map<String, Offset> _editStartOffsets = {};
  final Set<String> _isOnBench = {};
  final Set<String> _savedOnBench = {};
  final Set<String> _editStartOnBench = {};
  final Set<String> _isDragging = {};
  Size? _lastPitchSize;
  List<Map<String, dynamic>> _members = [];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('player_team_memberships')
          .select(
            'player_id, players!player_team_memberships_player_id_fkey(player_name, image_url)',
          )
          .eq('team_id', widget.teamId)
          .isFilter('end_date', null);
      if (!mounted) return;
      setState(() {
        _members = List<Map<String, dynamic>>.from(response);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading squad: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pitchWidth = constraints.maxWidth;
          final pitchHeight = pitchWidth * (274 / 380);
          final benchHeight = pitchWidth * (94 / 380);
          final bgHeight = pitchWidth;
          final pitchTop = bgHeight - pitchHeight;
          final pitchBottom = pitchTop + pitchHeight;
          const playerSize = 60.0;
          const snapZoneHeight = 24.0;

          final displayMembers = _members.isNotEmpty
              ? _members
              : [
                  {
                    'player_id': 'fallback',
                    'players': {
                      'player_name': 'Wacha',
                      'image_url': 'lib/assets/images/player.png',
                    },
                  },
                ];

          final currentSize = Size(pitchWidth, bgHeight + benchHeight);
          if (_lastPitchSize != currentSize) {
            for (final member in displayMembers) {
              final memberId = (member['player_id'] ?? '').toString();
              if (memberId.isEmpty) continue;
              if (!_playerOffsets.containsKey(memberId)) {
                final fallback = Offset(
                  (pitchWidth - playerSize) / 2,
                  pitchTop + (pitchHeight - playerSize) / 2,
                );
                final saved = _savedOffsets[memberId];
                _playerOffsets[memberId] = saved ?? fallback;
                if (_savedOnBench.contains(memberId)) {
                  _isOnBench.add(memberId);
                }
              }
            }
            _lastPitchSize = currentSize;
          }

          Offset clampOffset(Offset value) {
            final clampedX =
                value.dx.clamp(0.0, pitchWidth - playerSize);
            final clampedY = value.dy.clamp(
              0.0,
              (bgHeight + benchHeight) - playerSize,
            );
            return Offset(clampedX, clampedY);
          }

          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: pitchWidth,
              height: bgHeight + benchHeight,
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
                  if (_isDragging.any((id) =>
                      (_playerOffsets[id]?.dy ?? 0) >=
                      (pitchBottom - snapZoneHeight)))
                    Positioned(
                      left: 0,
                      top: pitchBottom - snapZoneHeight,
                      width: pitchWidth,
                      height: snapZoneHeight,
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.35),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.6),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    top: bgHeight,
                    width: pitchWidth,
                    height: benchHeight,
                    child: SvgPicture.asset(
                      'lib/assets/icons/squad/bench.svg',
                      fit: BoxFit.contain,
                    ),
                  ),
                  for (final member in displayMembers)
                    Builder(
                      builder: (context) {
                        final memberId = (member['player_id'] ?? '').toString();
                        if (memberId.isEmpty) return const SizedBox.shrink();
                        final player =
                            member['players'] as Map<String, dynamic>?;
                        final name =
                            player?['player_name'] as String? ?? 'Player';
                        final imageUrl =
                            player?['image_url'] as String? ?? '';
                        final offset = _playerOffsets[memberId] ??
                            Offset(
                              (pitchWidth - playerSize) / 2,
                              pitchTop + (pitchHeight - playerSize) / 2,
                            );
                        final isDragging = _isDragging.contains(memberId);
                        return AnimatedPositioned(
                          duration: isDragging
                              ? Duration.zero
                              : const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          left: offset.dx,
                          top: offset.dy,
                          child: GestureDetector(
                            onPanStart: _isEditing
                                ? (_) {
                                    setState(() {
                                      _isDragging.add(memberId);
                                    });
                                  }
                                : null,
                            onPanUpdate: _isEditing
                                ? (details) {
                                    setState(() {
                                      final current =
                                          _playerOffsets[memberId] ?? offset;
                                      _playerOffsets[memberId] = clampOffset(
                                        current + details.delta,
                                      );
                                    });
                                  }
                                : null,
                            onPanEnd: _isEditing
                                ? (_) {
                                    final current =
                                        _playerOffsets[memberId] ?? offset;
                                    final isNearBenchZone =
                                        current.dy >=
                                            (pitchBottom - snapZoneHeight);
                                    final isNearPitchZone =
                                        current.dy <=
                                            (pitchBottom - snapZoneHeight);
                                    setState(() {
                                      _isDragging.remove(memberId);
                                      if (!_isOnBench.contains(memberId) &&
                                          isNearBenchZone) {
                                        _isOnBench.add(memberId);
                                        _playerOffsets[memberId] = Offset(
                                          current.dx,
                                          bgHeight +
                                              (benchHeight - playerSize) / 2,
                                        );
                                      } else if (_isOnBench
                                              .contains(memberId) &&
                                          isNearPitchZone) {
                                        _isOnBench.remove(memberId);
                                        _playerOffsets[memberId] = Offset(
                                          current.dx,
                                          pitchTop +
                                              (pitchHeight - playerSize) / 2,
                                        );
                                      }
                                    });
                                  }
                                : null,
                            child: TeamPlayer(
                              name: name,
                              imageAsset: imageUrl,
                            ),
                          ),
                        );
                      },
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _isEditing
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.close,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                tooltip: 'Cancel',
                                onPressed: () {
                                  setState(() {
                                    _playerOffsets
                                      ..clear()
                                      ..addAll(_editStartOffsets);
                                    _isOnBench
                                      ..clear()
                                      ..addAll(_editStartOnBench);
                                    _isEditing = false;
                                    _isDragging.clear();
                                  });
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.check,
                                  color: Colors.green,
                                ),
                                tooltip: 'Save',
                                onPressed: () {
                                  setState(() {
                                    _savedOffsets
                                      ..clear()
                                      ..addAll(_playerOffsets);
                                    _savedOnBench
                                      ..clear()
                                      ..addAll(_isOnBench);
                                    _isEditing = false;
                                    _isDragging.clear();
                                  });
                                },
                              ),
                            ],
                          )
                        : IconButton(
                            icon: const Icon(Icons.edit),
                            tooltip: 'Edit lineup',
                            onPressed: () {
                              setState(() {
                                _editStartOffsets
                                  ..clear()
                                  ..addAll(_playerOffsets);
                                _editStartOnBench
                                  ..clear()
                                  ..addAll(_isOnBench);
                                _isEditing = true;
                              });
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class TeamPlayer extends StatelessWidget {
  const TeamPlayer({
    super.key,
    required this.name,
    required this.imageAsset,
  });

  final String name;
  final String imageAsset;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final path = imageAsset.trim();
    final isNetwork = path.startsWith('http://') || path.startsWith('https://');
    final image = path.isEmpty
        ? Image.asset(
            AppAssets.playerImage,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
          )
        : isNetwork
            ? Image.network(
                path,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Image.asset(
                  AppAssets.playerImage,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                ),
              )
            : Image.asset(
                path,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Image.asset(
                  AppAssets.playerImage,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                ),
              );
    return SizedBox(
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
          Positioned(
            top: 0,
            child: image,
          ),
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
    );
  }
}

// ---------------------------------------------------------------------------
// Team Matches Tab
// ---------------------------------------------------------------------------

class _TeamMatchesTab extends ConsumerStatefulWidget {
  const _TeamMatchesTab({required this.teamId});

  final String teamId;

  @override
  ConsumerState<_TeamMatchesTab> createState() => _TeamMatchesTabState();
}

class _TeamMatchesTabState extends ConsumerState<_TeamMatchesTab> {
  String? _selectedLeague;
  String? _selectedSeason;
  String? _selectedGameweek;

  List<Map<String, dynamic>> _leagues = [];
  List<SeasonModel> _seasons = [];
  List<Map<String, dynamic>> _gameweeks = [];
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
      final client = Supabase.instance.client;

      // Get leagues this team belongs to via league_team_memberships
      final ltmRes = await client
          .from('league_team_memberships')
          .select('league_id, league:leagues(id, league_name)')
          .eq('team_id', widget.teamId);
      final leagues = <Map<String, dynamic>>[];
      final leagueIds = <String>[];
      for (final r in List<Map<String, dynamic>>.from(ltmRes as List)) {
        final league = r['league'];
        if (league is Map<String, dynamic>) {
          final id = league['id']?.toString();
          if (id != null && id.isNotEmpty && !leagueIds.contains(id)) {
            leagueIds.add(id);
            leagues.add(league);
          }
        }
      }

      // Get seasons for those leagues
      List<SeasonModel> seasons = [];
      List<Map<String, dynamic>> gameweeks = [];
      if (leagueIds.isNotEmpty) {
        final seasonsRepo = ref.read(seasonsRepositoryProvider);
        seasons = await seasonsRepo.getSeasonsForLeagues(leagueIds);
        if (seasons.isNotEmpty) {
          gameweeks = await seasonsRepo
              .getGameweeksForSeasons(seasons.map((s) => s.id).toList());
        }
      }

      if (!mounted) return;
      setState(() {
        _leagues = leagues;
        _seasons = seasons;
        _gameweeks = gameweeks;
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
        teamIds: [widget.teamId],
        leagueIds:
            _selectedLeague != null ? [_selectedLeague!] : null,
        seasonIds:
            _selectedSeason != null ? [_selectedSeason!] : null,
        gameweek: _selectedGameweek,
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

  Future<void> _onLeagueChanged(String? value) async {
    final v = (value?.isEmpty ?? true) ? null : value;
    setState(() {
      _selectedLeague = v;
      _selectedSeason = null;
      _selectedGameweek = null;
    });

    // Reload seasons for the new league selection
    try {
      final seasonsRepo = ref.read(seasonsRepositoryProvider);
      final leagueIds = v != null
          ? [v]
          : _leagues.map((l) => l['id']?.toString() ?? '').where((id) => id.isNotEmpty).toList();
      if (leagueIds.isNotEmpty) {
        final seasons = await seasonsRepo.getSeasonsForLeagues(leagueIds);
        final gw = seasons.isNotEmpty
            ? await seasonsRepo
                .getGameweeksForSeasons(seasons.map((s) => s.id).toList())
            : <Map<String, dynamic>>[];
        if (!mounted) return;
        setState(() {
          _seasons = seasons;
          _gameweeks = gw;
        });
      }
    } catch (_) {}

    await _loadMatches();
  }

  Future<void> _onSeasonChanged(String? value) async {
    final v = (value?.isEmpty ?? true) ? null : value;
    setState(() {
      _selectedSeason = v;
      _selectedGameweek = null;
    });

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
      onRefresh: () async => _loadFilters(),
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
                          // League filter
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: SizedBox(
                              width: 130,
                              child: DropdownMenu<String>(
                                initialSelection: _selectedLeague ?? '',
                                label: const Text('League'),
                                dropdownMenuEntries: [
                                  const DropdownMenuEntry(
                                      value: '', label: 'All leagues'),
                                  ..._leagues.map((l) => DropdownMenuEntry(
                                        value: l['id']?.toString() ?? '',
                                        label: _truncate(
                                            l['league_name']?.toString() ?? ''),
                                      )),
                                ],
                                onSelected: _onLeagueChanged,
                              ),
                            ),
                          ),
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
                          child: Text(_gameweekLabel, style: textTheme.titleLarge),
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
                            child: _TeamMatchLogo(
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
                            child: _TeamMatchLogo(
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

class _TeamMatchLogo extends StatelessWidget {
  const _TeamMatchLogo({required this.path, this.size = 28});

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
// Team Standings Tab
// ---------------------------------------------------------------------------

class _TeamStandingsTab extends StatefulWidget {
  const _TeamStandingsTab({required this.teamId});

  final String teamId;

  @override
  State<_TeamStandingsTab> createState() => _TeamStandingsTabState();
}

class _TeamStandingsTabState extends State<_TeamStandingsTab> {
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

  List<Map<String, dynamic>> _leagues = [];
  String? _selectedLeague;
  List<Map<String, dynamic>>? _standings;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLeagues();
  }

  Future<void> _loadLeagues() async {
    try {
      final client = Supabase.instance.client;
      final ltmRes = await client
          .from('league_team_memberships')
          .select('league_id, league:leagues(id, league_name)')
          .eq('team_id', widget.teamId);
      final leagues = <Map<String, dynamic>>[];
      final seen = <String>{};
      for (final r in List<Map<String, dynamic>>.from(ltmRes as List)) {
        final league = r['league'];
        if (league is Map<String, dynamic>) {
          final id = league['id']?.toString();
          if (id != null && id.isNotEmpty && seen.add(id)) {
            leagues.add(league);
          }
        }
      }

      if (!mounted) return;
      setState(() => _leagues = leagues);

      if (leagues.isNotEmpty) {
        _selectedLeague = leagues.first['id']?.toString();
        await _loadStandings();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStandings() async {
    if (_selectedLeague == null) {
      setState(() {
        _standings = [];
        _isLoading = false;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await LeaguesRepository()
          .getLeagueStandings(_selectedLeague!);
      if (!mounted) return;
      setState(() {
        _standings = data;
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

  void _onLeagueChanged(String? value) {
    if (value == null || value.isEmpty) return;
    setState(() => _selectedLeague = value);
    _loadStandings();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading && _leagues.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_leagues.isEmpty) {
      return Center(
        child: Text(
          'This team is not in any league yet.',
          style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    final standings = _standings ?? [];

    return RefreshIndicator(
      onRefresh: () async {
        await _loadLeagues();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // League picker (if team is in multiple leagues)
            if (_leagues.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: DropdownMenu<String>(
                  initialSelection: _selectedLeague ?? '',
                  label: const Text('League'),
                  expandedInsets: EdgeInsets.zero,
                  dropdownMenuEntries: _leagues.map((l) {
                    final id = l['id']?.toString() ?? '';
                    final name = l['league_name']?.toString() ?? '';
                    return DropdownMenuEntry(value: id, label: name);
                  }).toList(),
                  onSelected: _onLeagueChanged,
                ),
              ),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Could not load standings', style: textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  Text(_error!, style: textTheme.bodySmall,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                      onPressed: _loadStandings, child: const Text('Retry')),
                ],
              )
            else if (standings.isEmpty)
              Text(
                'No standings yet — play some matches!',
                style: textTheme.bodyLarge
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(28),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
          ],
        ),
      ),
    );
  }

  TableRow _buildHeader(TextTheme textTheme) {
    Widget cell(String label) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(label, style: textTheme.bodySmall,
              textAlign: TextAlign.center),
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

  TableRow _buildRow(
      BuildContext context, int index, Map<String, dynamic> row) {
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

    final isHighlighted = teamId == widget.teamId;

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

    String logoPath = logoRaw;
    if (logoRaw.isNotEmpty &&
        !logoRaw.startsWith('http://') &&
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
                ClipOval(
                    child: _TeamStandingsLogo(path: logoPath, size: 24))
              else
                Icon(Icons.groups, size: 24,
                    color: colorScheme.onSurfaceVariant),
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

class _TeamStandingsLogo extends StatelessWidget {
  const _TeamStandingsLogo({required this.path, this.size = 24});

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
// Team Stats Tab – player stats scoped to this team
// ---------------------------------------------------------------------------

class _TeamStatsTab extends StatefulWidget {
  const _TeamStatsTab({required this.teamId});

  final String teamId;

  @override
  State<_TeamStatsTab> createState() => _TeamStatsTabState();
}

class _TeamStatsTabState extends State<_TeamStatsTab> {
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
      final data = await TeamsRepository().getTeamPlayerStats(widget.teamId);
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
            Text('Could not load stats', style: textTheme.bodyLarge),
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
          'No stats yet — play some matches!',
          style: textTheme.bodyLarge
              ?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    final sections = <_TeamStatSection>[
      _TeamStatSection(
        title: 'Goals',
        players: _topPlayers((r) => (r['total_goals'] as num?)?.toDouble() ?? 0),
        format: (r) => (r['total_goals'] ?? 0).toString(),
      ),
      _TeamStatSection(
        title: 'Assists',
        players:
            _topPlayers((r) => (r['total_assists'] as num?)?.toDouble() ?? 0),
        format: (r) => (r['total_assists'] ?? 0).toString(),
      ),
      _TeamStatSection(
        title: 'Goals + Assists',
        players:
            _topPlayers((r) => (r['goals_assists'] as num?)?.toDouble() ?? 0),
        format: (r) => (r['goals_assists'] ?? 0).toString(),
      ),
      _TeamStatSection(
        title: 'Average rating',
        players:
            _topPlayers((r) => (r['avg_rating'] as num?)?.toDouble() ?? 0),
        format: (r) =>
            ((r['avg_rating'] as num?)?.toDouble() ?? 0).toStringAsFixed(2),
      ),
      _TeamStatSection(
        title: 'Saves',
        players:
            _topPlayers((r) => (r['total_saves'] as num?)?.toDouble() ?? 0),
        format: (r) => (r['total_saves'] ?? 0).toString(),
      ),
      _TeamStatSection(
        title: 'Tackles',
        players:
            _topPlayers((r) => (r['total_tackles'] as num?)?.toDouble() ?? 0),
        format: (r) => (r['total_tackles'] ?? 0).toString(),
      ),
      _TeamStatSection(
        title: 'Yellow cards',
        players: _topPlayers(
            (r) => (r['total_yellow_cards'] as num?)?.toDouble() ?? 0),
        format: (r) => (r['total_yellow_cards'] ?? 0).toString(),
      ),
      _TeamStatSection(
        title: 'Red cards',
        players: _topPlayers(
            (r) => (r['total_red_cards'] as num?)?.toDouble() ?? 0),
        format: (r) => (r['total_red_cards'] ?? 0).toString(),
      ),
      _TeamStatSection(
        title: 'Shots on target',
        players: _topPlayers(
            (r) => (r['total_shots_on_target'] as num?)?.toDouble() ?? 0),
        format: (r) => (r['total_shots_on_target'] ?? 0).toString(),
      ),
      _TeamStatSection(
        title: 'Expected goals (xG)',
        players: _topPlayers((r) => (r['total_xg'] as num?)?.toDouble() ?? 0),
        format: (r) =>
            ((r['total_xg'] as num?)?.toDouble() ?? 0).toStringAsFixed(1),
      ),
      _TeamStatSection(
        title: 'Expected assists (xA)',
        players: _topPlayers((r) => (r['total_xa'] as num?)?.toDouble() ?? 0),
        format: (r) =>
            ((r['total_xa'] as num?)?.toDouble() ?? 0).toStringAsFixed(1),
      ),
      _TeamStatSection(
        title: 'Goals per match',
        players: _topPlayers((r) => _perMatch(r, 'total_goals')),
        format: (r) => _perMatch(r, 'total_goals').toStringAsFixed(1),
      ),
      _TeamStatSection(
        title: 'Saves per match',
        players: _topPlayers((r) => _perMatch(r, 'total_saves')),
        format: (r) => _perMatch(r, 'total_saves').toStringAsFixed(1),
      ),
      _TeamStatSection(
        title: 'Missed opportunities',
        players: _topPlayers(
            (r) => (r['missed_opportunities'] as num?)?.toDouble() ?? 0),
        format: (r) => (r['missed_opportunities'] ?? 0).toString(),
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
            _TeamStatSectionCard(section: sections[index]),
      ),
    );
  }
}

class _TeamStatSection {
  const _TeamStatSection({
    required this.title,
    required this.players,
    required this.format,
  });

  final String title;
  final List<Map<String, dynamic>> players;
  final String Function(Map<String, dynamic>) format;
}

class _TeamStatSectionCard extends StatelessWidget {
  const _TeamStatSectionCard({required this.section});

  final _TeamStatSection section;

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
              Text(
                'See all',
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
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
    final position = row['position']?.toString() ?? '';
    final value = section.format(row);

    return Row(
      children: [
        _TeamStatAvatar(imageUrl: imageUrl, radius: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                playerName,
                style: textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (position.isNotEmpty)
                Text(
                  position,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _TeamStatAvatar extends StatelessWidget {
  const _TeamStatAvatar({required this.imageUrl, this.radius = 20});

  final String imageUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (imageUrl.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: colorScheme.surfaceContainerHighest,
        child: Icon(Icons.person,
            size: radius, color: colorScheme.onSurfaceVariant),
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
// Team videos tab – real videos from the team's matches
// ---------------------------------------------------------------------------

enum _TeamVideoSort { newest, oldest, mostLiked, mostViewed }

class _TeamVideosTab extends StatefulWidget {
  const _TeamVideosTab({required this.teamId});

  final String teamId;

  @override
  State<_TeamVideosTab> createState() => _TeamVideosTabState();
}

class _TeamVideosTabState extends State<_TeamVideosTab> {
  List<LeagueVideoItem>? _videos;
  bool _isLoading = true;
  String? _error;
  _TeamVideoSort _sortOrder = _TeamVideoSort.newest;
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
      final client = Supabase.instance.client;

      // Fetch matches where this team played
      final matchARes = await client
          .from('matches')
          .select('id')
          .eq('teamA', widget.teamId);
      final matchBRes = await client
          .from('matches')
          .select('id')
          .eq('teamB', widget.teamId);
      final matchIds = <String>{};
      for (final r in matchARes as List) {
        final id = (r as Map)['id']?.toString();
        if (id != null && id.isNotEmpty) matchIds.add(id);
      }
      for (final r in matchBRes as List) {
        final id = (r as Map)['id']?.toString();
        if (id != null && id.isNotEmpty) matchIds.add(id);
      }

      if (matchIds.isEmpty) {
        if (!mounted) return;
        setState(() {
          _videos = [];
          _isLoading = false;
        });
        return;
      }

      final rawVideos = await client
          .from('videos')
          .select(
            'id, match_id, uploader_user_id, duration_seconds, '
            'video_url, thumbnail_url, created_at',
          )
          .inFilter('match_id', matchIds.toList())
          .order('created_at', ascending: false);
      final list = List<Map<String, dynamic>>.from(rawVideos as List);
      if (!mounted) return;
      final enriched = await _enrichVideos(list);
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

    final viewCountMap = <String, int>{};
    if (videoIds.isNotEmpty) {
      try {
        final viewRes = await client
            .from('feed_interactions')
            .select('video_id')
            .inFilter('video_id', videoIds);
        for (final row in List<Map<String, dynamic>>.from(viewRes as List)) {
          final vid = row['video_id']?.toString();
          if (vid != null) viewCountMap[vid] = (viewCountMap[vid] ?? 0) + 1;
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
        teamALogo: _resolveVideoLogo(teamA['logo_id']?.toString()),
        teamBLogo: _resolveVideoLogo(teamB['logo_id']?.toString()),
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

  static String _resolveVideoLogo(String? raw) {
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
      case _TeamVideoSort.newest:
        list.sort((a, b) =>
            (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      case _TeamVideoSort.oldest:
        list.sort((a, b) =>
            (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));
      case _TeamVideoSort.mostLiked:
        list.sort((a, b) => b.likeCount.compareTo(a.likeCount));
      case _TeamVideoSort.mostViewed:
        list.sort((a, b) => b.viewCount.compareTo(a.viewCount));
    }
    return list;
  }

  String get _sortLabel {
    switch (_sortOrder) {
      case _TeamVideoSort.newest:
        return 'Newest';
      case _TeamVideoSort.oldest:
        return 'Oldest';
      case _TeamVideoSort.mostLiked:
        return 'Most liked';
      case _TeamVideoSort.mostViewed:
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                PopupMenuButton<_TeamVideoSort>(
                  onSelected: (v) => setState(() => _sortOrder = v),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: _TeamVideoSort.newest,
                      child: Text('Newest'),
                    ),
                    PopupMenuItem(
                      value: _TeamVideoSort.oldest,
                      child: Text('Oldest'),
                    ),
                    PopupMenuItem(
                      value: _TeamVideoSort.mostLiked,
                      child: Text('Most liked'),
                    ),
                    PopupMenuItem(
                      value: _TeamVideoSort.mostViewed,
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      _TeamVideoLogo(logoPath: v.teamALogo, size: 24),
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
                      _TeamVideoLogo(logoPath: v.teamBLogo, size: 24),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      _TeamVideoPosterAvatar(
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

class _TeamVideoLogo extends StatelessWidget {
  const _TeamVideoLogo({required this.logoPath, this.size = 24});
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

class _TeamVideoPosterAvatar extends StatelessWidget {
  const _TeamVideoPosterAvatar({this.avatarUrl, required this.name});
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
