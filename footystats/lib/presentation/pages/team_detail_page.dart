import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_assets.dart';
import '../../core/utils/content_moderation_guards.dart';
import '../../core/utils/guest_mode.dart';
import '../../core/utils/connection_error.dart';
import '../../core/utils/username_rules.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_error_state.dart';
import '../../core/widgets/media_placeholders.dart';
import 'create_match_entry_page.dart';
import '../widgets/home/home_section_empty_state.dart';
import '../widgets/media_access_sheet.dart';
import '../../data/repositories/leagues_repository.dart';
import '../../data/repositories/teams_repository.dart';
import '../../data/repositories/matches_repository.dart';
import '../../domain/models/match_model.dart';
import '../../domain/models/season_model.dart';
import 'league_detail_page.dart';
import 'fixture.dart';
import 'league_video_player_page.dart';
import 'matches.dart' show DodecagonIndicator;
import '../providers/favourited_teams_provider.dart';
import '../providers/match_timer_adapter_provider.dart';
import 'player_profile_page.dart';
import '../providers/matches_provider.dart';
import '../providers/match_video_seen_provider.dart';
import '../providers/seasons_provider.dart';
import 'team_comparison_page.dart';
import 'team_manage_applications_page.dart';
import '../widgets/socials_section_card.dart';
import '../widgets/match_date_picker_dialog.dart';
import '../widgets/match_list_score_pill.dart';
import '../widgets/squad/team_player.dart';
import '../widgets/image_upload_card.dart';
import 'team_add_players_page.dart';
import 'team_rejected_applications_page.dart';

const String _kTeamDetailAllSeasonsId = '__all_seasons__';

int _parseTeamFavouriteCount(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _formatHeaderCount(int value) {
  final safe = value < 0 ? 0 : value;
  return safe.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (m) => ',',
  );
}

DateTime? _parseTeamDetailMatchDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString());
}

Future<({String? leagueId, String? seasonId})>
_latestLeagueSeasonForTeamMatches(
  SupabaseClient client,
  String teamId,
  Set<String> membershipLeagueIds,
) async {
  if (teamId.isEmpty || membershipLeagueIds.isEmpty) {
    return (leagueId: null, seasonId: null);
  }
  final res = await client
      .from('matches')
      .select('league_id, season_id, match_date')
      .eq('status', 'fullTime')
      .or('teamA.eq.$teamId,teamB.eq.$teamId');

  DateTime? best;
  String? bestLeague;
  String? bestSeason;

  for (final raw in res as List) {
    final m = Map<String, dynamic>.from(raw as Map);
    final lid = m['league_id']?.toString() ?? '';
    if (lid.isEmpty || !membershipLeagueIds.contains(lid)) continue;
    final sidRaw = m['season_id']?.toString();
    final sid = (sidRaw != null && sidRaw.isNotEmpty) ? sidRaw : null;
    final md = _parseTeamDetailMatchDate(m['match_date']);
    if (md == null) continue;
    if (best == null || md.isAfter(best)) {
      best = md;
      bestLeague = lid;
      bestSeason = sid;
    }
  }
  return (leagueId: bestLeague, seasonId: bestSeason);
}

Future<List<DropdownMenuEntry<String>>> _seasonDropdownEntriesForTeamLeague(
  SupabaseClient client,
  String teamId,
  String leagueId,
) async {
  final res = await client
      .from('matches')
      .select('season_id, match_date')
      .eq('status', 'fullTime')
      .eq('league_id', leagueId)
      .or('teamA.eq.$teamId,teamB.eq.$teamId');

  final lastBySeason = <String, DateTime>{};
  for (final raw in res as List) {
    final m = Map<String, dynamic>.from(raw as Map);
    final sid = m['season_id']?.toString() ?? '';
    if (sid.isEmpty) continue;
    final md = _parseTeamDetailMatchDate(m['match_date']);
    if (md == null) continue;
    final prev = lastBySeason[sid];
    if (prev == null || md.isAfter(prev)) lastBySeason[sid] = md;
  }

  final entries = <DropdownMenuEntry<String>>[
    const DropdownMenuEntry<String>(
      value: _kTeamDetailAllSeasonsId,
      label: 'All seasons',
    ),
  ];

  if (lastBySeason.isEmpty) return entries;

  final seasonRows = await client
      .from('seasons')
      .select('id, season_name, end_date')
      .inFilter('id', lastBySeason.keys.toList());

  final labels = <String, String>{};
  for (final raw in (seasonRows as List)) {
    final row = Map<String, dynamic>.from(raw as Map);
    final id = row['id']?.toString() ?? '';
    if (id.isEmpty) continue;
    final seasonName = row['season_name']?.toString() ?? '';
    final endDate = _parseTeamDetailMatchDate(row['end_date']);
    final year = endDate?.year.toString() ?? '';
    labels[id] = seasonName.isNotEmpty
        ? seasonName
        : (year.isNotEmpty ? year : 'Season');
  }

  final sortedIds = lastBySeason.keys.toList()
    ..sort((a, b) => lastBySeason[b]!.compareTo(lastBySeason[a]!));

  for (final sid in sortedIds) {
    entries.add(
      DropdownMenuEntry<String>(value: sid, label: labels[sid] ?? 'Season'),
    );
  }
  return entries;
}

String? _seasonIdForTeamDetailRpc(String selectedSeasonKey) {
  if (selectedSeasonKey == _kTeamDetailAllSeasonsId) return null;
  return selectedSeasonKey;
}

class TeamDetailPage extends StatefulWidget {
  const TeamDetailPage({super.key, required this.teamId});

  final String teamId;

  @override
  State<TeamDetailPage> createState() => _TeamDetailPageState();
}

class _TeamDetailPageState extends State<TeamDetailPage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _team;
  Object? _loadError;
  bool _isLoading = true;
  bool _isDeleting = false;
  bool _hasJoined = false;
  bool _isMember = false;
  bool _isAdmin = false;
  bool _isJoining = false;
  late final ScrollController _outerScrollController;
  late final TabController _tabController;
  bool _isHeaderCollapsed = false;
  int _tabViewGeneration = 0;
  int _lastTabIndex = 0;
  bool _isSquadEditingActive = false;
  Color? _headerToneA;
  Color? _headerToneB;
  Color? _headerToneC;
  Color? _logoRingColor;
  String? _lastHeaderImageKey;
  int? _videoCount;

  @override
  void initState() {
    super.initState();
    _outerScrollController = ScrollController()
      ..addListener(_handleOuterScroll);
    _tabController = TabController(length: 7, vsync: this)
      ..addListener(_handleTabIndexChanged);
    _loadTeam();
  }

  void _handleTabIndexChanged() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == _lastTabIndex) return;
    _lastTabIndex = _tabController.index;
    if (_tabController.index != 5 && _isSquadEditingActive) {
      _isSquadEditingActive = false;
    }
    setState(() {
      _tabViewGeneration++;
    });
    if (_outerScrollController.hasClients) {
      _outerScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  void _handleOuterScroll() {
    final collapsed =
        _outerScrollController.hasClients &&
        _outerScrollController.offset > 0.5;
    if (collapsed == _isHeaderCollapsed) return;
    setState(() {
      _isHeaderCollapsed = collapsed;
    });
  }

  @override
  void dispose() {
    _outerScrollController.removeListener(_handleOuterScroll);
    _outerScrollController.dispose();
    _tabController.removeListener(_handleTabIndexChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTeam() async {
    setState(() {
      _loadError = null;
      _isLoading = true;
    });
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('teams')
          .select()
          .eq('id', widget.teamId)
          .maybeSingle();

      if (response != null && mounted) {
        final logoUrl = response['logo_id'] as String?;
        final videoCount =
            await TeamsRepository().getTeamVideoCount(widget.teamId);
        setState(() {
          _team = response;
          _videoCount = videoCount;
          _isLoading = false;
        });
        await _deriveHeaderGradientFromImage(logoUrl);
        await _refreshJoinState();
      } else if (mounted) {
        setState(() {
          _team = null;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _isLoading = false;
      });
    }
  }

  Future<void> _openEditTeam() async {
    final team = _team;
    if (team == null) return;
    final didUpdate = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _EditTeamPage(
          teamId: widget.teamId,
          initialTeamName: team['team_name']?.toString() ?? '',
          initialShortForm: team['short_form']?.toString() ?? '',
          initialLogoUrl: team['logo_id']?.toString(),
          initialBannerUrl: team['banner_id']?.toString(),
          initialSocialInstagram: team['social_instagram']?.toString(),
          initialSocialTiktok: team['social_tiktok']?.toString(),
          initialSocialX: team['social_x']?.toString(),
        ),
      ),
    );
    if (didUpdate == true) {
      await _loadTeam();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Team updated')));
    }
  }

  Future<void> _deriveHeaderGradientFromImage(String? logoUrl) async {
    if (logoUrl == null || logoUrl.trim().isEmpty) {
      _lastHeaderImageKey = '__team_fallback__';
      if (!mounted) return;
      final scheme = Theme.of(context).colorScheme;
      setState(() {
        _headerToneA = scheme.primaryContainer;
        _headerToneB = scheme.secondaryContainer;
        _headerToneC = scheme.tertiaryContainer;
        _logoRingColor = scheme.primaryContainer;
      });
      return;
    }
    final imageKey = logoUrl.trim();
    if (_lastHeaderImageKey == imageKey) return;
    _lastHeaderImageKey = imageKey;

    final ImageProvider provider = appCachedImageProvider(logoUrl.trim());
    try {
      final scheme = await ColorScheme.fromImageProvider(
        provider: provider,
        brightness: Theme.of(context).brightness,
      );
      if (!mounted || _lastHeaderImageKey != imageKey) return;
      setState(() {
        _headerToneA = Color.alphaBlend(
          scheme.primary.withValues(alpha: 0.18),
          scheme.surfaceContainerHigh,
        );
        _headerToneB = Color.alphaBlend(
          scheme.tertiary.withValues(alpha: 0.16),
          scheme.surfaceContainer,
        );
        _headerToneC = Color.alphaBlend(
          scheme.secondary.withValues(alpha: 0.14),
          scheme.surfaceContainerLow,
        );
        _logoRingColor = scheme.primary.withAlpha(255);
      });
    } catch (_) {
      // Keep fallback colors when extraction fails.
    }
  }

  Future<void> _refreshJoinState() async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      final membership = await supabase
          .from('player_team_memberships')
          .select('id, role')
          .eq('team_id', widget.teamId)
          .eq('player_id', currentUser.id)
          .isFilter('end_date', null)
          .maybeSingle();

      final joinRequest = await supabase
          .from('team_join_requests')
          .select('id, status')
          .eq('team_id', widget.teamId)
          .eq('player_id', currentUser.id)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _isMember = membership != null;
        _isAdmin = membership?['role']?.toString() == 'admin';
        _hasJoined = membership != null || joinRequest != null;
      });
    } catch (_) {
      // Ignore join state errors; keep existing UI state.
    }
  }

  Future<void> _handleLeaveTeam() async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave team?'),
        content: const Text('Are you sure you want to leave this team?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Leave',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await TeamsRepository().leaveTeam(
        playerId: currentUser.id,
        teamId: widget.teamId,
      );

      if (!mounted) return;
      setState(() {
        _isMember = false;
        _hasJoined = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('You have left the team')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error leaving team: $error')));
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

  Future<void> _handleOwnerLeaveTeam() async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      final capRes = await supabase
          .from('teams')
          .select('captain_id')
          .eq('id', widget.teamId)
          .maybeSingle();
      final captainId = capRes?['captain_id']?.toString();

      if (captainId == currentUser.id) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Cannot leave team'),
            content: const Text(
              'As team captain, you must assign another player as captain before leaving.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking team status: $error')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave team?'),
        content: const Text('Are you sure you want to leave this team?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final today = DateTime.now().toIso8601String().split('T').first;

      await supabase
          .from('player_team_memberships')
          .update({'end_date': today})
          .eq('team_id', widget.teamId)
          .eq('player_id', currentUser.id)
          .isFilter('end_date', null);

      if (!mounted) return;
      setState(() {
        _isMember = false;
        _isAdmin = false;
        _hasJoined = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('You have left the team')));
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error leaving team: $error')));
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

    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const SizedBox.shrink(),
          centerTitle: false,
        ),
        body: Center(
          child: AppConnectionErrorState(
            title: isConnectionError(_loadError)
                ? 'No connection'
                : 'Could not load team',
            subtitle: isConnectionError(_loadError)
                ? 'Check your internet connection and try again.'
                : 'Something went wrong while loading this team.',
            onRetry: _loadTeam,
          ),
        ),
      );
    }

    if (_team == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const SizedBox.shrink(),
          centerTitle: false,
        ),
        body: const Center(
          child: AppNotFoundState(
            title: 'Team not found',
            subtitle: 'This team may have been removed or the link is incorrect.',
          ),
        ),
      );
    }

    final teamName = _team!['team_name'] as String? ?? 'Unknown';
    final shortForm = _team!['short_form'] as String? ?? '';
    final logoUrl = _team!['logo_id'] as String?;
    final createdAt = _team!['created_at'];
    final createdAtDt = createdAt is DateTime
        ? createdAt
        : (createdAt is String ? DateTime.tryParse(createdAt) : null);
    final estYear = createdAtDt?.year ?? DateTime.now().year;
    final favouriteCount = _parseTeamFavouriteCount(_team!['favourite_count']);
    final isOwner = _isAdmin;
    final headerToneA = _headerToneA ?? colorScheme.surfaceContainerHigh;
    final headerToneB = _headerToneB ?? colorScheme.surfaceContainer;
    final headerToneC = _headerToneC ?? colorScheme.surfaceContainerLow;
    final logoRingColor = _logoRingColor ?? colorScheme.primaryContainer;

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
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        TeamComparisonPage(baseTeamId: widget.teamId),
                  ),
                );
              },
              tooltip: 'Compare team',
            ),
            if (_isMember)
              IconButton(
                icon: Icon(Icons.logout, color: colorScheme.error),
                onPressed: _handleLeaveTeam,
                tooltip: 'Leave team',
              ),
            if (!_isMember && !_hasJoined)
              if (GuestMode.isGuest)
                Consumer(
                  builder: (context, ref, _) {
                    final isStarred = ref.watch(favouritedTeamsProvider).any(
                      (team) => team.id == widget.teamId,
                    );
                    return IconButton(
                      style: IconButton.styleFrom(
                        fixedSize: const Size(48, 48),
                        padding: EdgeInsets.zero,
                      ),
                      icon: Icon(
                        isStarred
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: isStarred
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                        size: 26,
                      ),
                      onPressed: () async {
                        final wasFavourited = isStarred;
                        await ref.read(favouritedTeamsProvider.notifier).toggle(
                          FavouritedTeam(
                            id: widget.teamId,
                            name: teamName,
                            shortForm: shortForm,
                            logoId: logoUrl,
                            favouriteCount: favouriteCount,
                          ),
                        );
                        if (!mounted) return;
                        setState(() {
                          final nextCount = (favouriteCount + (wasFavourited ? -1 : 1))
                              .clamp(0, 1 << 30);
                          _team = {
                            ...?_team,
                            'favourite_count': nextCount,
                          };
                        });
                      },
                      tooltip: isStarred
                          ? 'Remove from favourites'
                          : 'Add to favourites',
                    );
                  },
                )
              else
                IconButton(
                  onPressed: _isJoining ? null : _handleJoinTeam,
                  icon: _isJoining
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  tooltip: 'Join team',
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
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        TeamComparisonPage(baseTeamId: widget.teamId),
                  ),
                );
              },
              tooltip: 'Compare team',
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'More options',
              onSelected: (value) {
                switch (value) {
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
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) =>
                            TeamAddPlayersPage(teamId: widget.teamId),
                      ),
                    );
                    break;
                  case 'leave_team':
                    _handleOwnerLeaveTeam();
                    break;
                  case 'delete':
                    _deleteTeam();
                    break;
                }
              },
              itemBuilder: (context) => [
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
        child: NestedScrollView(
          controller: _outerScrollController,
          physics: _isSquadEditingActive
              ? const NeverScrollableScrollPhysics()
              : const ClampingScrollPhysics(),
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                pinned: true,
                primary: false,
                toolbarHeight: 0,
                expandedHeight: 230,
                elevation: 0,
                scrolledUnderElevation: 0,
                shadowColor: Colors.transparent,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  background: Builder(
                    builder: (context) {
                      final settings = context
                          .dependOnInheritedWidgetOfExactType<
                            FlexibleSpaceBarSettings
                          >();
                      final minExtent = settings?.minExtent ?? kToolbarHeight;
                      final maxExtent = settings?.maxExtent ?? 240;
                      final currentExtent =
                          settings?.currentExtent ?? maxExtent;
                      final collapseRange = (maxExtent - minExtent).clamp(
                        1.0,
                        double.infinity,
                      );
                      final t = ((currentExtent - minExtent) / collapseRange)
                          .clamp(0.0, 1.0);
                      final fadeOpacity = (0.15 + (0.85 * t)).clamp(0.0, 1.0);
                      return Opacity(
                        opacity: fadeOpacity,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(28),
                              topRight: Radius.circular(28),
                            ),
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    headerToneA,
                                    headerToneB,
                                    headerToneC,
                                  ],
                                  stops: const [0.0, 0.55, 1.0],
                                ),
                              ),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    center: const Alignment(-0.85, -0.65),
                                    colors: [
                                      colorScheme.primary.withValues(alpha: 0.22),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 96,
                                            height: 96,
                                            decoration: BoxDecoration(
                                              color: logoRingColor,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: logoRingColor,
                                                width: 1,
                                              ),
                                            ),
                                            child: Center(
                                              child: Container(
                                                width: 64,
                                                height: 64,
                                                decoration: BoxDecoration(
                                                  color: colorScheme.surface,
                                                  shape: BoxShape.circle,
                                                ),
                                                child:
                                                    logoUrl != null &&
                                                        logoUrl.isNotEmpty
                                                    ? ClipOval(
                                                        child: Image(
                                                          image: appCachedImageProvider(logoUrl),
                                                          width: 64,
                                                          height: 64,
                                                          fit: BoxFit.cover,
                                                          errorBuilder:
                                                              (
                                                                context,
                                                                error,
                                                                stackTrace,
                                                              ) {
                                                                return Icon(
                                                                  Icons.groups,
                                                                  size: 32,
                                                                  color: colorScheme
                                                                      .onSurfaceVariant,
                                                                );
                                                              },
                                                        ),
                                                      )
                                                    : Icon(
                                                        Icons.groups,
                                                        size: 32,
                                                        color: colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  teamName,
                                                  style: textTheme.titleLarge
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                if (shortForm.isNotEmpty)
                                                  Text(
                                                    '($shortForm)',
                                                    style: textTheme.bodySmall
                                                        ?.copyWith(
                                                          color: colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                  ),
                                                Text(
                                                  'Est. $estYear',
                                                  style: textTheme.bodySmall
                                                      ?.copyWith(
                                                        color: colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          if (isOwner)
                                            FilledButton(
                                              onPressed: _openEditTeam,
                                              style: FilledButton.styleFrom(
                                                shape:
                                                    const RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.all(
                                                    Radius.circular(999),
                                                  ),
                                                ),
                                                padding:
                                                    const EdgeInsets.only(
                                                  left: 17,
                                                  right: 17,
                                                  top: 12,
                                                  bottom: 12,
                                                ),
                                                minimumSize:
                                                    const Size(60, 40),
                                              ),
                                              child: const Icon(
                                                Icons.edit_outlined,
                                                size: 20,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          children: [
                                            _TeamHeaderChip(
                                              icon: Icons.star_rounded,
                                              label: _formatHeaderCount(
                                                favouriteCount,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            _TeamHeaderChip(
                                              icon: Icons.play_circle_outline,
                                              label: _videoCount == null
                                                  ? '—'
                                                  : _formatHeaderCount(
                                                      _videoCount!,
                                                    ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(kTextTabBarHeight + 2),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      color: _isHeaderCollapsed
                          ? colorScheme.surface
                          : Colors.transparent,
                      border: Border(
                        bottom: BorderSide(
                          color: colorScheme.outlineVariant,
                          width: 1,
                        ),
                      ),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      dividerHeight: 0,
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
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            physics: _isSquadEditingActive
                ? const NeverScrollableScrollPhysics()
                : null,
            children: [
              KeyedSubtree(
                key: ValueKey('team-tab-0-$_tabViewGeneration'),
                child: _TeamOverviewTab(
                  teamId: widget.teamId,
                  team: _team!,
                  showAdminActions: _isAdmin,
                  onOpenMatchesTab: () => _tabController.animateTo(1),
                  onCreateMatch: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const CreateMatchEntryPage(),
                      ),
                    );
                  },
                ),
              ),
              KeyedSubtree(
                key: ValueKey('team-tab-1-$_tabViewGeneration'),
                child: _TeamMatchesTab(
                  teamId: widget.teamId,
                  showCreateMatchCta: _isAdmin,
                ),
              ),
              KeyedSubtree(
                key: ValueKey('team-tab-2-$_tabViewGeneration'),
                child: _TeamStandingsTab(teamId: widget.teamId),
              ),
              KeyedSubtree(
                key: ValueKey('team-tab-3-$_tabViewGeneration'),
                child: _TeamSummaryStatsTab(teamId: widget.teamId),
              ),
              KeyedSubtree(
                key: ValueKey('team-tab-4-$_tabViewGeneration'),
                child: _TeamStatsTab(teamId: widget.teamId),
              ),
              KeyedSubtree(
                key: ValueKey('team-tab-5-$_tabViewGeneration'),
                child: _SquadTab(
                  teamId: widget.teamId,
                  onEditingChanged: (isEditing) {
                    if (_isSquadEditingActive == isEditing) return;
                    setState(() {
                      _isSquadEditingActive = isEditing;
                    });
                  },
                ),
              ),
              KeyedSubtree(
                key: ValueKey('team-tab-6-$_tabViewGeneration'),
                child: _TeamVideosTab(teamId: widget.teamId),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Team Overview Tab – upcoming match card
// ---------------------------------------------------------------------------
class _TeamOverviewSectionCard extends StatelessWidget {
  const _TeamOverviewSectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _TeamOverviewTab extends StatelessWidget {
  const _TeamOverviewTab({
    required this.teamId,
    required this.team,
    required this.onOpenMatchesTab,
    required this.onCreateMatch,
    this.showAdminActions = false,
  });

  final String teamId;
  final Map<String, dynamic> team;
  final VoidCallback onOpenMatchesTab;
  final VoidCallback onCreateMatch;
  final bool showAdminActions;

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
      return appCachedImageProvider(logoPath);
    }
    return AssetImage(logoPath);
  }

  ImageProvider? _leagueLogoProvider(String? logoId) {
    final lid = (logoId ?? '').trim();
    if (lid.isEmpty) return null;
    try {
      if (lid.startsWith('http://') || lid.startsWith('https://')) {
        return appCachedImageProvider(lid);
      }
      // If it's an asset path (or filename that matches an asset path),
      // AssetImage will work as long as the string points to a valid asset.
      return AssetImage(lid);
    } catch (_) {
      return null;
    }
  }

  Future<_TeamOverviewMatch?> _fetchNextUpcomingMatchCard() async {
    final selected = await MatchesRepository().getNextUpcomingMatch(
      teamIds: [teamId],
    );
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
                return _TeamOverviewSectionCard(
                  title: 'Next match',
                  child: const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                );
              }

              final data = snapshot.data;
              if (data == null) {
                return _TeamOverviewSectionCard(
                  title: 'Next match',
                  child: HomeSectionEmptyState(
                    embedded: true,
                    message: showAdminActions
                        ? 'Schedule a fixture for this team and it will appear here when it is upcoming or live.'
                        : 'This team has no upcoming or live fixtures right now.',
                    actionLabel:
                        showAdminActions ? 'Create match' : 'View matches',
                    actionIcon: showAdminActions
                        ? Icons.add
                        : Icons.calendar_month_outlined,
                    onAction: showAdminActions
                        ? onCreateMatch
                        : onOpenMatchesTab,
                    secondaryActionLabel:
                        showAdminActions ? 'View matches' : null,
                    onSecondaryAction:
                        showAdminActions ? onOpenMatchesTab : null,
                  ),
                );
              }

              final match = data.match;
              final leagueLogoProvider = _leagueLogoProvider(data.leagueLogoId);
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
                                  builder: (_) =>
                                      LeagueDetailPage(leagueId: leagueId),
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
                                      color:
                                          colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: leagueLogoProvider != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
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
                                      backgroundColor:
                                          colorScheme.surfaceContainerHighest,
                                      backgroundImage: _logoProvider(
                                        match.teamA.logoPath,
                                      ),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
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
                                      backgroundColor:
                                          colorScheme.surfaceContainerHighest,
                                      backgroundImage: _logoProvider(
                                        match.teamB.logoPath,
                                      ),
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
          _TeamFormSection(
            teamId: teamId,
            showAdminActions: showAdminActions,
            onOpenMatchesTab: onOpenMatchesTab,
            onCreateMatch: onCreateMatch,
          ),
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
// Trophies — one per ended season where this team finished 1st in that season
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
      final raw = await LeaguesRepository().getChampionTrophiesForTeam(
        widget.teamId,
      );
      final byName = <String, List<Map<String, dynamic>>>{};
      for (final t in raw) {
        final name = t['league_name']?.toString() ?? 'League';
        byName.putIfAbsent(name, () => []).add(t);
      }
      final rows = <_TeamTrophyRow>[];
      for (final entry in byName.entries) {
        final list = List<Map<String, dynamic>>.from(entry.value)
          ..sort((a, b) {
            final da = a['end_date']?.toString() ?? '';
            final db = b['end_date']?.toString() ?? '';
            final c = db.compareTo(da);
            if (c != 0) return c;
            return (a['season_id']?.toString() ?? '').compareTo(
              b['season_id']?.toString() ?? '',
            );
          });
        final subtitle = list
            .map((m) {
              final sn = m['season_name']?.toString().trim() ?? '';
              final y = m['end_year'] as int?;
              if (sn.isNotEmpty) {
                return y != null ? '$sn ($y)' : sn;
              }
              return y != null ? 'Season ($y)' : 'Season';
            })
            .join(' Â· ');
        final logoId = list.first['logo_id']?.toString();
        rows.add(
          _TeamTrophyRow(
            leagueName: entry.key,
            logoId: logoId,
            yearsLabel: subtitle,
            count: list.length,
          ),
        );
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
      return _TeamOverviewSectionCard(
        title: 'Trophies',
        child: const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return _TeamOverviewSectionCard(
        title: 'Trophies',
        child: const HomeSectionEmptyState(
          embedded: true,
          message:
              'Could not load trophies. Pull to refresh the team page and try again.',
        ),
      );
    }

    return _TeamOverviewSectionCard(
      title: 'Trophies',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_rows.isEmpty)
            const HomeSectionEmptyState(
              embedded: true,
              compact: true,
              message:
                  'League titles appear here when this team finishes first in a completed season.',
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
                            Text(trophy.leagueName, style: textTheme.bodySmall),
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
    return resolveTeamLogoPath(raw);
  }

  @override
  Widget build(BuildContext context) {
    final path = _resolvedPath(logoId);
    final colorScheme = Theme.of(context).colorScheme;
    if (path == null) {
      return SizedBox(
        width: 36,
        height: 36,
        child: Icon(Icons.emoji_events, size: 24, color: colorScheme.primary),
      );
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image(
          image: appCachedImageProvider(path),
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => SizedBox(
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
      errorBuilder: (_, _, _) => SizedBox(
        width: 36,
        height: 36,
        child: Icon(Icons.emoji_events, size: 24, color: colorScheme.primary),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Team Form Section (recent results)
// ---------------------------------------------------------------------------
class _TeamFormSection extends StatefulWidget {
  const _TeamFormSection({
    required this.teamId,
    required this.onOpenMatchesTab,
    required this.onCreateMatch,
    this.showAdminActions = false,
  });

  final String teamId;
  final VoidCallback onOpenMatchesTab;
  final VoidCallback onCreateMatch;
  final bool showAdminActions;

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
      return appCachedImageProvider(logoPath);
    }
    return AssetImage(logoPath);
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final recent = await MatchesRepository().getRecentCompletedMatches(
        teamIds: [widget.teamId],
        limit: 6,
      );

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
      return _TeamOverviewSectionCard(
        title: 'Team form',
        child: const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return _TeamOverviewSectionCard(
        title: 'Team form',
        child: const HomeSectionEmptyState(
          embedded: true,
          message:
              'Could not load recent results. Pull to refresh and try again.',
        ),
      );
    }

    if (_recentMatches.isEmpty) {
      return _TeamOverviewSectionCard(
        title: 'Team form',
        child: HomeSectionEmptyState(
          embedded: true,
          message:
              'Recent results from full-time matches will show here as a form guide.',
          actionLabel: widget.showAdminActions ? 'Create match' : 'View matches',
          actionIcon: widget.showAdminActions
              ? Icons.add
              : Icons.calendar_month_outlined,
          onAction: widget.showAdminActions
              ? widget.onCreateMatch
              : widget.onOpenMatchesTab,
          secondaryActionLabel:
              widget.showAdminActions ? 'View matches' : null,
          onSecondaryAction:
              widget.showAdminActions ? widget.onOpenMatchesTab : null,
        ),
      );
    }

    return _TeamOverviewSectionCard(
      title: 'Team form',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_recentMatches.length, (index) {
                  final match = _recentMatches[index];

                  final isTeamA = match.teamA.id == widget.teamId;
                  final myScore = isTeamA ? match.teamAScore : match.teamBScore;
                  final oppScore = isTeamA
                      ? match.teamBScore
                      : match.teamAScore;
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

                  final isDraw =
                      myScore != null &&
                      oppScore != null &&
                      myScore == oppScore;

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
                            backgroundColor: Colors.transparent,
                            backgroundImage: _logoProvider(opponent.logoPath),
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
// Team Stats Tab – summary totals (matches, goals, assists, cards, etc.)
// ---------------------------------------------------------------------------
class _TeamSummaryStatsTab extends StatefulWidget {
  const _TeamSummaryStatsTab({required this.teamId});

  final String teamId;

  @override
  State<_TeamSummaryStatsTab> createState() => _TeamSummaryStatsTabState();
}

class _TeamSummaryStatsTabState extends State<_TeamSummaryStatsTab> {
  List<Map<String, dynamic>> _leagues = [];
  String? _selectedLeague;
  List<DropdownMenuEntry<String>> _seasonEntries = const [
    DropdownMenuEntry<String>(
      value: _kTeamDetailAllSeasonsId,
      label: 'All seasons',
    ),
  ];
  String _selectedSeason = _kTeamDetailAllSeasonsId;

  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLeagues();
  }

  Future<void> _loadLeagues() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
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

      if (leagues.isEmpty) {
        setState(() => _leagues = []);
        await _loadStats();
        return;
      }

      final membershipIds = leagues
          .map((l) => l['id']?.toString())
          .whereType<String>()
          .toSet();
      final defaults = await _latestLeagueSeasonForTeamMatches(
        client,
        widget.teamId,
        membershipIds,
      );
      final fallbackLeagueId = leagues.first['id']?.toString();
      final pickedLeague =
          (defaults.leagueId != null &&
              membershipIds.contains(defaults.leagueId))
          ? defaults.leagueId!
          : fallbackLeagueId;

      setState(() => _leagues = leagues);
      _selectedLeague = pickedLeague;

      await _refreshSeasonMenuAndStats(preferredSeasonId: defaults.seasonId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshSeasonMenuAndStats({String? preferredSeasonId}) async {
    final leagueId = _selectedLeague;
    if (leagueId == null || leagueId.isEmpty) {
      await _loadStats();
      return;
    }

    final client = Supabase.instance.client;
    final entries = await _seasonDropdownEntriesForTeamLeague(
      client,
      widget.teamId,
      leagueId,
    );

    final realSeasonIds = entries
        .map((e) => e.value)
        .where((v) => v != _kTeamDetailAllSeasonsId)
        .toSet();

    String season = _kTeamDetailAllSeasonsId;
    if (preferredSeasonId != null &&
        realSeasonIds.contains(preferredSeasonId)) {
      season = preferredSeasonId;
    } else if (realSeasonIds.isNotEmpty) {
      season = entries
          .firstWhere((e) => e.value != _kTeamDetailAllSeasonsId)
          .value;
    }

    if (!mounted) return;
    setState(() {
      _seasonEntries = entries;
      _selectedSeason = season;
    });
    await _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final String? leagueId = _leagues.isEmpty ? null : _selectedLeague;
      final String? seasonId = _leagues.isEmpty
          ? null
          : _seasonIdForTeamDetailRpc(_selectedSeason);

      final data = await TeamsRepository().getTeamSummaryStatsFiltered(
        widget.teamId,
        leagueId: leagueId,
        seasonId: seasonId,
      );
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

  void _onLeagueChanged(String? value) {
    if (value == null || value.isEmpty) return;
    setState(() => _selectedLeague = value);
    _refreshSeasonMenuAndStats();
  }

  void _onSeasonChanged(String? value) {
    if (value == null || value.isEmpty) return;
    setState(() => _selectedSeason = value);
    _loadStats();
  }

  String _intToString(dynamic v) {
    final n = (v as num?)?.toInt();
    return n == null ? '0' : n.toString();
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
            FilledButton(onPressed: _loadLeagues, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_stats == null || _stats!.isEmpty) {
      return const Center(
        child: AppEmptyState(
          imageAsset: AppAssets.noStatsEmpty,
          title: 'No team stats yet',
          subtitle:
              'Stats for this team will appear once they play matches in a league.',
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
    ];

    return RefreshIndicator(
      onRefresh: _loadLeagues,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_leagues.isNotEmpty) ...[
              DropdownMenu<String>(
                key: ValueKey<String>(
                  'summary_league_${_selectedLeague ?? ''}',
                ),
                initialSelection: _selectedLeague ?? '',
                label: const Text('League'),
                expandedInsets: EdgeInsets.zero,
                dropdownMenuEntries: _leagues.map((l) {
                  final id = l['id']?.toString() ?? '';
                  final name = l['league_name']?.toString() ?? '';
                  return DropdownMenuEntry<String>(value: id, label: name);
                }).toList(),
                onSelected: _onLeagueChanged,
              ),
              const SizedBox(height: 12),
              DropdownMenu<String>(
                key: ValueKey<String>(
                  'summary_season_${_selectedLeague ?? ''}_${_seasonEntries.length}',
                ),
                initialSelection: _selectedSeason,
                label: const Text('Season'),
                expandedInsets: EdgeInsets.zero,
                dropdownMenuEntries: _seasonEntries,
                onSelected: _onSeasonChanged,
              ),
              const SizedBox(height: 16),
            ],
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(28),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Summary', style: textTheme.titleSmall),
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
  const _SquadTab({required this.teamId, required this.onEditingChanged});

  final String teamId;
  final ValueChanged<bool> onEditingChanged;

  @override
  State<_SquadTab> createState() => _SquadTabState();
}

class _SquadTabState extends State<_SquadTab> {
  static const double _canvasWidth = 380;
  static const double _canvasBgHeight = 380;
  static const double _canvasPitchHeight = 274;
  static const double _canvasBenchHeight = 94;
  static const double _canvasTotalHeight = _canvasBgHeight + _canvasBenchHeight;
  static const double _playerSize = 60;

  bool _isEditing = false;
  bool _canEditLineup = false;
  bool _isOwner = false;
  String? _captainId;
  final Map<String, Offset> _playerOffsets = {};
  final Map<String, Offset> _savedOffsets = {};
  final Map<String, Offset> _savedAbsoluteOffsets = {};
  final Map<String, Offset> _savedNormalizedOffsets = {};
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
    _initialize();
  }

  @override
  void dispose() {
    widget.onEditingChanged(false);
    super.dispose();
  }

  Future<void> _loadMembers() async {
    try {
      final supabase = Supabase.instance.client;
      final currentUserId = supabase.auth.currentUser?.id;
      final response = await supabase
          .from('player_team_memberships')
          .select(
            'player_id, players!player_team_memberships_player_id_fkey(player_name, image_url)',
          )
          .eq('team_id', widget.teamId)
          .isFilter('end_date', null);
      if (!mounted) return;
      final members = List<Map<String, dynamic>>.from(response);
      final isMember =
          currentUserId != null &&
          members.any(
            (row) => (row['player_id'] ?? '').toString() == currentUserId,
          );
      setState(() {
        _members = members;
        _canEditLineup = _canEditLineup || isMember;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading squad: $error')));
    }
  }

  Future<void> _initialize() async {
    await _loadSavedLayout();
    await _loadMembers();
  }

  Future<void> _loadSavedLayout() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('teams')
          .select('squad_layout')
          .eq('id', widget.teamId)
          .maybeSingle();
      if (!mounted) return;
      final currentUserId = supabase.auth.currentUser?.id;
      bool isOwner = false;
      if (currentUserId != null) {
        try {
          final roleRes = await supabase
              .from('player_team_memberships')
              .select('role')
              .eq('team_id', widget.teamId)
              .eq('player_id', currentUserId)
              .isFilter('end_date', null)
              .maybeSingle();
          isOwner = roleRes?['role']?.toString() == 'admin';
        } catch (_) {
          // Membership role may not be available yet on older schemas.
        }
      }
      String? captainId;
      try {
        final capRes = await supabase
            .from('teams')
            .select('captain_id')
            .eq('id', widget.teamId)
            .maybeSingle();
        captainId = capRes?['captain_id']?.toString();
      } catch (_) {
        // captain_id column may not exist yet (migration not applied).
      }
      final data = response?['squad_layout'];
      if (data is! Map) {
        setState(() {
          _canEditLineup = _canEditLineup || isOwner;
          _isOwner = isOwner;
          _captainId = captainId;
        });
        return;
      }
      final rawPlayers = data['players'];
      if (rawPlayers is! Map) return;
      final normalized = <String, Offset>{};
      final absolute = <String, Offset>{};
      final resolvedSaved = <String, Offset>{};
      final bench = <String>{};
      rawPlayers.forEach((key, value) {
        if (key is! String || value is! Map) return;
        final absX = (value['abs_x'] as num?)?.toDouble();
        final absY = (value['abs_y'] as num?)?.toDouble();
        final x = (value['x'] as num?)?.toDouble();
        final y = (value['y'] as num?)?.toDouble();
        if (x != null && y != null) {
          final normalizedOffset = Offset(x.clamp(0.0, 1.0), y.clamp(0.0, 1.0));
          normalized[key] = normalizedOffset;
          resolvedSaved[key] = Offset(
            normalizedOffset.dx * (_canvasWidth - _playerSize),
            normalizedOffset.dy * (_canvasTotalHeight - _playerSize),
          );
        }
        if (absX != null && absY != null) {
          final absoluteOffset = Offset(absX, absY);
          absolute[key] = absoluteOffset;
          resolvedSaved[key] = Offset(
            absoluteOffset.dx.clamp(0.0, _canvasWidth - _playerSize),
            absoluteOffset.dy.clamp(0.0, _canvasTotalHeight - _playerSize),
          );
        }
        if (value['bench'] == true) {
          bench.add(key);
        }
      });
      setState(() {
        _canEditLineup = _canEditLineup || isOwner;
        _isOwner = isOwner;
        _captainId = captainId;
        _savedOffsets
          ..clear()
          ..addAll(resolvedSaved);
        _savedAbsoluteOffsets
          ..clear()
          ..addAll(absolute);
        _savedNormalizedOffsets
          ..clear()
          ..addAll(normalized);
        _savedOnBench
          ..clear()
          ..addAll(bench);
      });
    } catch (_) {
      // Ignore when persistence column is not available yet.
    }
  }

  Future<void> _setCaptain(String playerId, String playerName) async {
    if (!_isOwner) return;
    final supabase = Supabase.instance.client;
    await supabase
        .from('teams')
        .update({'captain_id': playerId})
        .eq('id', widget.teamId);
    if (!mounted) return;
    setState(() => _captainId = playerId);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$playerName is now captain')));
  }

  Future<void> _kickPlayer(String playerId, String playerName) async {
    if (!_isOwner) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kick player'),
        content: Text('Remove $playerName from this team?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Kick'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final today = DateTime.now().toIso8601String().split('T').first;
      final supabase = Supabase.instance.client;

      // End the active membership.
      await supabase
          .from('player_team_memberships')
          .update({'end_date': today})
          .eq('team_id', widget.teamId)
          .eq('player_id', playerId)
          .isFilter('end_date', null);

      // Clean up pending invites for this player/team (if any).
      await supabase
          .from('team_player_invites')
          .delete()
          .eq('team_id', widget.teamId)
          .eq('player_id', playerId)
          .eq('status', 'pending');

      // If the kicked player was captain, unset captain.
      if (_captainId == playerId) {
        await supabase
            .from('teams')
            .update({'captain_id': null})
            .eq('id', widget.teamId);
        if (!mounted) return;
        setState(() => _captainId = null);
      }

      // Remove from local layout + persist.
      setState(() {
        _members.removeWhere(
          (row) => (row['player_id'] ?? '').toString() == playerId,
        );
        _playerOffsets.remove(playerId);
        _savedOffsets.remove(playerId);
        _savedAbsoluteOffsets.remove(playerId);
        _savedNormalizedOffsets.remove(playerId);
        _isOnBench.remove(playerId);
        _savedOnBench.remove(playerId);
        _editStartOffsets.remove(playerId);
        _editStartOnBench.remove(playerId);
        _isDragging.remove(playerId);
      });
      await _persistSavedLayout();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$playerName was removed')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not remove player: $e')));
    }
  }

  Future<void> _showPlayerActionsSheet({
    required String playerId,
    required String playerName,
    required String imageUrl,
  }) async {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isCaptain = _captainId == playerId;

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                // Match player tile image behavior: support network and assets.
                // Some player avatars are stored as asset paths, not URLs.
                leading: Builder(
                  builder: (_) {
                    final trimmed = imageUrl.trim();
                    final isNetwork =
                        trimmed.startsWith('http://') ||
                        trimmed.startsWith('https://');
                    final hasImage = trimmed.isNotEmpty;
                    ImageProvider? provider;
                    if (hasImage) {
                      provider = isNetwork
                          ? appCachedImageProvider(trimmed)
                          : AssetImage(trimmed);
                    }
                    return CircleAvatar(
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      backgroundImage: provider,
                      child: hasImage
                          ? null
                          : Icon(
                              Icons.person,
                              size: 28,
                              color: colorScheme.onSurfaceVariant,
                            ),
                    );
                  },
                ),
                title: Text(playerName, style: textTheme.titleMedium),
                subtitle: Text(
                  _isOwner
                      ? 'Team admin actions'
                      : 'Only a team admin can do this',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    ListTile(
                      enabled: _isOwner && !isCaptain,
                      leading: Icon(
                        Icons.military_tech_outlined,
                        color: colorScheme.primary,
                      ),
                      title: Text(isCaptain ? 'Captain' : 'Make captain'),
                      subtitle: isCaptain
                          ? Text(
                              'This player is already captain',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            )
                          : null,
                      onTap: !_isOwner || isCaptain
                          ? null
                          : () async {
                              Navigator.of(ctx).pop();
                              await _setCaptain(playerId, playerName);
                            },
                    ),
                    Divider(height: 1, color: colorScheme.outlineVariant),
                    ListTile(
                      enabled: _isOwner,
                      leading: Icon(
                        Icons.person_remove_outlined,
                        color: colorScheme.error,
                      ),
                      title: Text(
                        'Kick from team',
                        style: TextStyle(color: colorScheme.error),
                      ),
                      onTap: !_isOwner
                          ? null
                          : () async {
                              Navigator.of(ctx).pop();
                              await _kickPlayer(playerId, playerName);
                            },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _persistSavedLayout() async {
    final maxX = (_canvasWidth - _playerSize).clamp(1.0, double.infinity);
    final maxY = (_canvasTotalHeight - _playerSize).clamp(1.0, double.infinity);
    final players = <String, Map<String, dynamic>>{};
    for (final entry in _savedOffsets.entries) {
      final id = entry.key;
      if (id == 'fallback') continue;
      final offset = entry.value;
      players[id] = <String, dynamic>{
        'abs_x': offset.dx,
        'abs_y': offset.dy,
        'x': (offset.dx / maxX).clamp(0.0, 1.0),
        'y': (offset.dy / maxY).clamp(0.0, 1.0),
        'bench': _savedOnBench.contains(id),
      };
    }
    final payload = <String, dynamic>{
      'version': 2,
      'layout': <String, dynamic>{
        'width': _canvasWidth,
        'height': _canvasTotalHeight,
      },
      'players': players,
    };
    final supabase = Supabase.instance.client;
    await supabase
        .from('teams')
        .update({'squad_layout': payload})
        .eq('id', widget.teamId)
        .select('id')
        .single();
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
          const snapZoneHeight = 24.0;
          final canvasPitchTop = _canvasBgHeight - _canvasPitchHeight;
          final canvasPitchBottom = canvasPitchTop + _canvasPitchHeight;
          final maxSavedX = (_canvasWidth - _playerSize).clamp(
            1.0,
            double.infinity,
          );
          final maxSavedY = (_canvasTotalHeight - _playerSize).clamp(
            1.0,
            double.infinity,
          );
          final scaleX = pitchWidth / _canvasWidth;
          final scaleY = (bgHeight + benchHeight) / _canvasTotalHeight;

          final displayMembers = _members.isNotEmpty
              ? _members
              : [
                  {
                    'player_id': 'fallback',
                    'players': {
                      'player_name': 'Wacha',
                      'image_url': null,
                    },
                  },
                ];

          final currentSize = Size(_canvasWidth, _canvasTotalHeight);
          final missingOffsets = displayMembers.any((member) {
            final memberId = (member['player_id'] ?? '').toString();
            return memberId.isNotEmpty && !_playerOffsets.containsKey(memberId);
          });
          if (_lastPitchSize != currentSize || missingOffsets) {
            for (final member in displayMembers) {
              final memberId = (member['player_id'] ?? '').toString();
              if (memberId.isEmpty) continue;
              if (!_playerOffsets.containsKey(memberId)) {
                final fallback = Offset(
                  (_canvasWidth - _playerSize) / 2,
                  canvasPitchTop + (_canvasPitchHeight - _playerSize) / 2,
                );
                final normalized = _savedNormalizedOffsets[memberId];
                final absolute = _savedAbsoluteOffsets[memberId];
                final saved =
                    _savedOffsets[memberId] ??
                    absolute ??
                    (normalized == null
                        ? null
                        : Offset(
                            normalized.dx * maxSavedX,
                            normalized.dy * maxSavedY,
                          ));
                _playerOffsets[memberId] = saved == null
                    ? fallback
                    : Offset(
                        saved.dx.clamp(0.0, _canvasWidth - _playerSize),
                        saved.dy.clamp(0.0, _canvasTotalHeight - _playerSize),
                      );
                if (_savedOnBench.contains(memberId)) {
                  _isOnBench.add(memberId);
                }
              }
            }
            _lastPitchSize = currentSize;
          }

          Offset clampOffset(Offset value) {
            final clampedX = value.dx.clamp(0.0, _canvasWidth - _playerSize);
            final clampedY = value.dy.clamp(
              0.0,
              _canvasTotalHeight - _playerSize,
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
                  if (_isDragging.any(
                    (id) =>
                        (_playerOffsets[id]?.dy ?? 0) >=
                        (pitchBottom - snapZoneHeight),
                  ))
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
                                Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.35),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.6),
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
                        final imageUrl = player?['image_url'] as String? ?? '';
                        final offset =
                            _playerOffsets[memberId] ??
                            Offset(
                              (_canvasWidth - _playerSize) / 2,
                              canvasPitchTop +
                                  (_canvasPitchHeight - _playerSize) / 2,
                            );
                        final isDragging = _isDragging.contains(memberId);
                        return AnimatedPositioned(
                          duration: isDragging
                              ? Duration.zero
                              : const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          left: offset.dx * scaleX,
                          top: offset.dy * scaleY,
                          child: GestureDetector(
                            onTap: () async {
                              if (memberId == 'fallback') return;
                              if (_isEditing) {
                                await _showPlayerActionsSheet(
                                  playerId: memberId,
                                  playerName: name,
                                  imageUrl: imageUrl,
                                );
                                return;
                              }
                              if (!mounted) return;
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PlayerProfilePage(playerId: memberId),
                                ),
                              );
                            },
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
                                        current +
                                            Offset(
                                              details.delta.dx / scaleX,
                                              details.delta.dy / scaleY,
                                            ),
                                      );
                                    });
                                  }
                                : null,
                            onPanEnd: _isEditing
                                ? (_) {
                                    final current =
                                        _playerOffsets[memberId] ?? offset;
                                    setState(() {
                                      _isDragging.remove(memberId);
                                      final shouldBeOnBench =
                                          current.dy >=
                                          (canvasPitchBottom - snapZoneHeight);
                                      if (shouldBeOnBench) {
                                        _isOnBench.add(memberId);
                                      } else {
                                        _isOnBench.remove(memberId);
                                      }
                                    });
                                  }
                                : null,
                            child: TeamPlayer(
                              name: name,
                              imageAsset: imageUrl,
                              showCaptainBadge: _captainId == memberId,
                            ),
                          ),
                        );
                      },
                    ),
                  if (_canEditLineup)
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
                                    widget.onEditingChanged(false);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.check,
                                    color: Colors.green,
                                  ),
                                  tooltip: 'Save',
                                  onPressed: () async {
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
                                    widget.onEditingChanged(false);
                                    try {
                                      await _persistSavedLayout();
                                    } catch (error) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Could not save lineup: $error',
                                          ),
                                        ),
                                      );
                                    }
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
                                widget.onEditingChanged(true);
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

// ---------------------------------------------------------------------------
// Team Matches Tab
// ---------------------------------------------------------------------------

class _TeamMatchesTab extends ConsumerStatefulWidget {
  const _TeamMatchesTab({
    required this.teamId,
    this.showCreateMatchCta = false,
  });

  final String teamId;
  final bool showCreateMatchCta;

  @override
  ConsumerState<_TeamMatchesTab> createState() => _TeamMatchesTabState();
}

class _TeamMatchesTabState extends ConsumerState<_TeamMatchesTab> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _dateGroupKeys = <String, GlobalKey>{};
  String? _selectedLeague;
  String? _selectedSeason;
  String? _selectedGameweek;
  DateTime? _requestedJumpDate;
  String? _lastHandledJumpDateKey;
  bool _showScrollToTop = false;

  List<Map<String, dynamic>> _leagues = [];
  List<SeasonModel> _seasons = [];
  List<Map<String, dynamic>> _gameweeks = [];
  List<MatchModel> _matches = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _loadFilters();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final shouldShow = _scrollController.offset > 280;
    if (shouldShow == _showScrollToTop) return;
    setState(() => _showScrollToTop = shouldShow);
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
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
          gameweeks = await seasonsRepo.getGameweeksForSeasons(
            seasons.map((s) => s.id).toList(),
          );
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
        leagueIds: _selectedLeague != null ? [_selectedLeague!] : null,
        seasonIds: _selectedSeason != null ? [_selectedSeason!] : null,
        gameweek: _selectedGameweek,
        fromDate: _selectedSeason != null
            ? null
            : DateTime.now().subtract(const Duration(days: 180)),
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
          : _leagues
                .map((l) => l['id']?.toString() ?? '')
                .where((id) => id.isNotEmpty)
                .toList();
      if (leagueIds.isNotEmpty) {
        final seasons = await seasonsRepo.getSeasonsForLeagues(leagueIds);
        final gw = seasons.isNotEmpty
            ? await seasonsRepo.getGameweeksForSeasons(
                seasons.map((s) => s.id).toList(),
              )
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
      final seasonIds = v != null ? [v] : _seasons.map((s) => s.id).toList();
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
    final idx = _selectedGameweek != null
        ? ids.indexOf(_selectedGameweek!)
        : -1;
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
    final idx = _selectedGameweek != null
        ? ids.indexOf(_selectedGameweek!)
        : -1;
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
    final idx = _selectedGameweek != null
        ? ids.indexOf(_selectedGameweek!)
        : -1;
    return (
      idx > 0 || idx == -1,
      (idx >= 0 && idx < ids.length - 1) || idx == -1,
    );
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

  String _dateToKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _scrollToDateKey(String dateKey, {int attempt = 0}) {
    if (!mounted) return;
    final key = _dateGroupKeys[dateKey];
    final targetContext = key?.currentContext;
    if (targetContext == null) {
      if (attempt < 6) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToDateKey(dateKey, attempt: attempt + 1);
        });
      }
      return;
    }
    final renderObject = targetContext.findRenderObject();
    final position = Scrollable.of(targetContext).position;
    if (renderObject == null) return;
    final viewport = RenderAbstractViewport.of(renderObject);
    final reveal = viewport.getOffsetToReveal(renderObject, 0.0).offset;
    const topOffset = 12.0;
    final target = (reveal - topOffset).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    position.animateTo(
      target.toDouble(),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollToRequestedDateIfNeeded(List<String> dateKeys) {
    final requestedDate = _requestedJumpDate;
    if (requestedDate == null) return;
    final dateKey = _dateToKey(requestedDate);
    if (_lastHandledJumpDateKey == dateKey) return;
    if (!dateKeys.contains(dateKey)) {
      _lastHandledJumpDateKey = dateKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No matches scheduled for that date')),
        );
        setState(() => _requestedJumpDate = null);
      });
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToDateKey(dateKey);
      setState(() {
        _lastHandledJumpDateKey = dateKey;
        _requestedJumpDate = null;
      });
    });
  }

  Future<void> _pickDateToJump() async {
    final matchDates = _matches
        .map(
          (m) => DateTime(m.matchDate.year, m.matchDate.month, m.matchDate.day),
        )
        .toSet();
    final picked = await showMatchAwareDatePicker(
      context,
      matchDates: matchDates,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _requestedJumpDate = DateTime(picked.year, picked.month, picked.day);
      _lastHandledJumpDateKey = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final (canPrev, canNext) = _gameweekNav;
    final videoKey = matchIdsWithVideosCacheKey(_matches.map((m) => m.id));
    final videosLookup = ref
        .watch(matchVideosLookupByIdsProvider(videoKey))
        .maybeWhen(
          data: (lookup) => lookup,
          orElse: () => const MatchVideosLookup(),
        );
    final matchIdsWithVideo = videosLookup.matchIds;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async => _loadFilters(),
          child: CustomScrollView(
            controller: _scrollController,
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
                              IconButton(
                                icon: const Icon(Icons.calendar_month_outlined),
                                tooltip: 'Go to date',
                                onPressed: _pickDateToJump,
                              ),
                              // League filter
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: SizedBox(
                                  width: 130,
                                  child: DropdownMenu<String>(
                                    initialSelection: _selectedLeague ?? '',
                                    label: const Text('League'),
                                    dropdownMenuEntries: [
                                      const DropdownMenuEntry(
                                        value: '',
                                        label: 'All leagues',
                                      ),
                                      ..._leagues.map(
                                        (l) => DropdownMenuEntry(
                                          value: l['id']?.toString() ?? '',
                                          label: _truncate(
                                            l['league_name']?.toString() ?? '',
                                          ),
                                        ),
                                      ),
                                    ],
                                    onSelected: _onLeagueChanged,
                                  ),
                                ),
                              ),
                              // Season filter
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: SizedBox(
                                  width: 130,
                                  child: DropdownMenu<String>(
                                    initialSelection: _selectedSeason ?? '',
                                    label: const Text('Season'),
                                    dropdownMenuEntries: [
                                      const DropdownMenuEntry(
                                        value: '',
                                        label: 'All seasons',
                                      ),
                                      ..._seasons.map(
                                        (s) => DropdownMenuEntry(
                                          value: s.id,
                                          label: _truncate(s.seasonName),
                                        ),
                                      ),
                                    ],
                                    onSelected: _onSeasonChanged,
                                  ),
                                ),
                              ),
                              // Gameweek filter
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: SizedBox(
                                  width: 100,
                                  child: DropdownMenu<String>(
                                    initialSelection: _selectedGameweek ?? '',
                                    label: const Text('GW'),
                                    dropdownMenuEntries: [
                                      const DropdownMenuEntry(
                                        value: '',
                                        label: 'All GW',
                                      ),
                                      ..._gameweeks.map((g) {
                                        final id = g['id']?.toString() ?? '';
                                        final week =
                                            g['week']?.toString() ?? '?';
                                        return DropdownMenuEntry(
                                          value: id,
                                          label: 'GW $week',
                                        );
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
                                  onPressed: canPrev
                                      ? _goToPreviousGameweek
                                      : null,
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
                                Text(
                                  'Could not load matches',
                                  style: textTheme.bodyLarge,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _error!,
                                  style: textTheme.bodySmall,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : _buildMatchList(context, matchIdsWithVideo),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            offset: _showScrollToTop ? Offset.zero : const Offset(0, 1.4),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _showScrollToTop ? 1 : 0,
              child: FloatingActionButton.small(
                heroTag: 'team-matches-scroll-top',
                onPressed: _showScrollToTop ? _scrollToTop : null,
                tooltip: 'Scroll to top',
                child: const Icon(Icons.arrow_upward_rounded),
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool get _hasActiveFilters =>
      _selectedLeague != null ||
      _selectedSeason != null ||
      _selectedGameweek != null;

  void _clearFilters() {
    setState(() {
      _selectedLeague = null;
      _selectedSeason = null;
      _selectedGameweek = null;
    });
    _loadMatches();
  }

  void _openCreateMatch() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CreateMatchEntryPage(),
      ),
    );
  }

  Widget _buildMatchList(BuildContext context, Set<String> matchIdsWithVideo) {
    final grouped = _grouped;
    final dateKeys = grouped.keys.toList()..sort();
    _scrollToRequestedDateIfNeeded(dateKeys);

    if (dateKeys.isEmpty) {
      return Center(
        child: NoMatchesEmptyState(
          hasActiveFilters: _hasActiveFilters,
          showCreateMatchCta: widget.showCreateMatchCta,
          onClearFilters: _clearFilters,
          onCreateMatch: _openCreateMatch,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final key in dateKeys) ...[
          KeyedSubtree(
            key: _dateGroupKeys.putIfAbsent(key, () => GlobalKey()),
            child: _buildDateGroup(
              context,
              key,
              grouped[key]!,
              matchIdsWithVideo,
            ),
          ),
          const SizedBox(height: 2),
        ],
      ],
    );
  }

  Widget _buildDateGroup(
    BuildContext context,
    String dateKey,
    List<MatchModel> matches,
    Set<String> matchIdsWithVideo,
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
            _buildMatchCard(context, matches[i], matchIdsWithVideo),
            if (i < matches.length - 1) const SizedBox(height: 2),
          ],
        ],
      ),
    );
  }

  Widget _buildMatchCard(
    BuildContext context,
    MatchModel match,
    Set<String> matchIdsWithVideo,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final clock = ref.watch(matchTimerAdapterProvider(match.id));
    final ongoingTime = formatMatchClock(clock);

    if (match.status == MatchStatus.ongoing && clock == Duration.zero) {
      ref.read(matchTimerAdapterProvider(match.id).notifier).start();
    }
    final statusLabel = match.status == MatchStatus.ongoing
        ? ongoingTime
        : match.statusText;
    final seenIds = ref.watch(matchVideoSeenProvider);
    final videoKey = matchIdsWithVideosCacheKey(_matches.map((m) => m.id));
    final videoIdsByMatch = ref
        .watch(matchVideosLookupByIdsProvider(videoKey))
        .maybeWhen(
          data: (lookup) => lookup.videoIdsByMatch,
          orElse: () => const <String, List<String>>{},
        );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => FixturePage(matchId: match.id)),
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
                          Text(
                            match.teamA.shortForm,
                            style: textTheme.bodySmall,
                          ),
                          const SizedBox(width: 8),
                          ClipOval(
                            child: _TeamMatchLogo(
                              path: match.teamA.logoPath,
                              size: 28,
                            ),
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
                          child: Text(
                            statusLabel,
                            style: textTheme.titleMedium,
                          ),
                        );
                      }
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MatchListScorePill(
                            scoreText: match.scoreText ?? '',
                            hasVideo: matchIdsWithVideo.contains(match.id),
                            videoWatched: matchVideoWatchedSegments(
                              match.id,
                              videoIdsByMatch,
                              seenIds,
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
                              Text(statusLabel, style: textTheme.labelSmall),
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
                              path: match.teamB.logoPath,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            match.teamB.shortForm,
                            style: textTheme.bodySmall,
                          ),
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
    final isNetwork = path.startsWith('http://') || path.startsWith('https://');
    return SizedBox(
      width: size,
      height: size,
      child: isNetwork
          ? Image(
              image: appCachedImageProvider(path),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            )
          : Image.asset(
              path,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => SizedBox(
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
    0: FlexColumnWidth(0.8), // Pos
    1: FlexColumnWidth(2.4), // Team
    2: FlexColumnWidth(0.7), // PL
    3: FlexColumnWidth(0.7), // W
    4: FlexColumnWidth(0.7), // D
    5: FlexColumnWidth(0.7), // L
    6: FlexColumnWidth(0.7), // GD
    7: FlexColumnWidth(0.8), // Pts
  };

  List<Map<String, dynamic>> _leagues = [];
  String? _selectedLeague;
  List<DropdownMenuEntry<String>> _seasonEntries = const [
    DropdownMenuEntry<String>(
      value: _kTeamDetailAllSeasonsId,
      label: 'All seasons',
    ),
  ];
  String _selectedSeason = _kTeamDetailAllSeasonsId;
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

      if (leagues.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final membershipIds = leagues
          .map((l) => l['id']?.toString())
          .whereType<String>()
          .toSet();
      final defaults = await _latestLeagueSeasonForTeamMatches(
        client,
        widget.teamId,
        membershipIds,
      );

      final fallbackLeagueId = leagues.first['id']?.toString();
      final pickedLeague =
          (defaults.leagueId != null &&
              membershipIds.contains(defaults.leagueId))
          ? defaults.leagueId!
          : fallbackLeagueId;

      _selectedLeague = pickedLeague;
      await _refreshSeasonMenuAndStandings(
        preferredSeasonId: defaults.seasonId,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshSeasonMenuAndStandings({
    String? preferredSeasonId,
  }) async {
    final leagueId = _selectedLeague;
    if (leagueId == null || leagueId.isEmpty) {
      setState(() {
        _standings = [];
        _isLoading = false;
      });
      return;
    }

    final client = Supabase.instance.client;
    final entries = await _seasonDropdownEntriesForTeamLeague(
      client,
      widget.teamId,
      leagueId,
    );

    final realSeasonIds = entries
        .map((e) => e.value)
        .where((v) => v != _kTeamDetailAllSeasonsId)
        .toSet();

    String season = _kTeamDetailAllSeasonsId;
    if (preferredSeasonId != null &&
        realSeasonIds.contains(preferredSeasonId)) {
      season = preferredSeasonId;
    } else if (realSeasonIds.isNotEmpty) {
      season = entries
          .firstWhere((e) => e.value != _kTeamDetailAllSeasonsId)
          .value;
    }

    if (!mounted) return;
    setState(() {
      _seasonEntries = entries;
      _selectedSeason = season;
    });
    await _loadStandings();
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
      final data = await LeaguesRepository().getLeagueStandingsFiltered(
        _selectedLeague!,
        seasonId: _seasonIdForTeamDetailRpc(_selectedSeason),
      );
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
    _refreshSeasonMenuAndStandings();
  }

  void _onSeasonChanged(String? value) {
    if (value == null || value.isEmpty) return;
    setState(() => _selectedSeason = value);
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
          style: textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
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
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  DropdownMenu<String>(
                    key: ValueKey<String>(
                      'standings_league_${_selectedLeague ?? ''}',
                    ),
                    initialSelection: _selectedLeague ?? '',
                    label: const Text('League'),
                    expandedInsets: EdgeInsets.zero,
                    dropdownMenuEntries: _leagues.map((l) {
                      final id = l['id']?.toString() ?? '';
                      final name = l['league_name']?.toString() ?? '';
                      return DropdownMenuEntry<String>(value: id, label: name);
                    }).toList(),
                    onSelected: _onLeagueChanged,
                  ),
                  const SizedBox(height: 12),
                  DropdownMenu<String>(
                    key: ValueKey<String>(
                      'standings_season_${_selectedLeague ?? ''}_${_seasonEntries.length}',
                    ),
                    initialSelection: _selectedSeason,
                    label: const Text('Season'),
                    expandedInsets: EdgeInsets.zero,
                    dropdownMenuEntries: _seasonEntries,
                    onSelected: _onSeasonChanged,
                  ),
                ],
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
                  Text(
                    _error!,
                    style: textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loadStandings,
                    child: const Text('Retry'),
                  ),
                ],
              )
            else if (standings.isEmpty)
              const Center(
                child: AppEmptyState(
                  imageAsset: AppAssets.noStandingsEmpty,
                  title: 'No standings yet',
                  subtitle:
                      'The table will update once this team plays matches in the league.',
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(28),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
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
      child: Text(
        label,
        style: textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
    );
    return TableRow(
      children: [
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
      ],
    );
  }

  TableRow _buildRow(
    BuildContext context,
    int index,
    Map<String, dynamic> row,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final position = (row['position'] as num?)?.toInt() ?? (index + 1);
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
    if (logoRaw.isNotEmpty) {
      logoPath = resolveTeamLogoPath(logoRaw) ?? logoPath;
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
                ClipOval(child: _TeamStandingsLogo(path: logoPath, size: 24))
              else
                Icon(
                  Icons.groups,
                  size: 24,
                  color: colorScheme.onSurfaceVariant,
                ),
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
    final isNetwork = path.startsWith('http://') || path.startsWith('https://');
    return SizedBox(
      width: size,
      height: size,
      child: isNetwork
          ? Image(
              image: appCachedImageProvider(path),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Icon(
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
              errorBuilder: (_, _, _) => Icon(
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
  List<Map<String, dynamic>> _leagues = [];
  String? _selectedLeague;
  List<DropdownMenuEntry<String>> _seasonEntries = const [
    DropdownMenuEntry<String>(
      value: _kTeamDetailAllSeasonsId,
      label: 'All seasons',
    ),
  ];
  String _selectedSeason = _kTeamDetailAllSeasonsId;

  List<Map<String, dynamic>>? _stats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLeagues();
  }

  Future<void> _loadLeagues() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
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

      if (leagues.isEmpty) {
        setState(() => _leagues = []);
        await _loadPlayerStats();
        return;
      }

      final membershipIds = leagues
          .map((l) => l['id']?.toString())
          .whereType<String>()
          .toSet();
      final defaults = await _latestLeagueSeasonForTeamMatches(
        client,
        widget.teamId,
        membershipIds,
      );
      final fallbackLeagueId = leagues.first['id']?.toString();
      final pickedLeague =
          (defaults.leagueId != null &&
              membershipIds.contains(defaults.leagueId))
          ? defaults.leagueId!
          : fallbackLeagueId;

      setState(() => _leagues = leagues);
      _selectedLeague = pickedLeague;

      await _refreshSeasonMenuAndPlayerStats(
        preferredSeasonId: defaults.seasonId,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshSeasonMenuAndPlayerStats({
    String? preferredSeasonId,
  }) async {
    final leagueId = _selectedLeague;
    if (leagueId == null || leagueId.isEmpty) {
      await _loadPlayerStats();
      return;
    }

    final client = Supabase.instance.client;
    final entries = await _seasonDropdownEntriesForTeamLeague(
      client,
      widget.teamId,
      leagueId,
    );

    final realSeasonIds = entries
        .map((e) => e.value)
        .where((v) => v != _kTeamDetailAllSeasonsId)
        .toSet();

    String season = _kTeamDetailAllSeasonsId;
    if (preferredSeasonId != null &&
        realSeasonIds.contains(preferredSeasonId)) {
      season = preferredSeasonId;
    } else if (realSeasonIds.isNotEmpty) {
      season = entries
          .firstWhere((e) => e.value != _kTeamDetailAllSeasonsId)
          .value;
    }

    if (!mounted) return;
    setState(() {
      _seasonEntries = entries;
      _selectedSeason = season;
    });
    await _loadPlayerStats();
  }

  Future<void> _loadPlayerStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final String? leagueId = _leagues.isEmpty ? null : _selectedLeague;
      final String? seasonId = _leagues.isEmpty
          ? null
          : _seasonIdForTeamDetailRpc(_selectedSeason);

      final data = await TeamsRepository().getTeamPlayerStatsFiltered(
        widget.teamId,
        leagueId: leagueId,
        seasonId: seasonId,
      );
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

  void _onLeagueChanged(String? value) {
    if (value == null || value.isEmpty) return;
    setState(() => _selectedLeague = value);
    _refreshSeasonMenuAndPlayerStats();
  }

  void _onSeasonChanged(String? value) {
    if (value == null || value.isEmpty) return;
    setState(() => _selectedSeason = value);
    _loadPlayerStats();
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

  List<Map<String, dynamic>> _allTopPlayers(
    double Function(Map<String, dynamic>) getValue,
  ) {
    if (_stats == null || _stats!.isEmpty) return [];
    final sorted = List<Map<String, dynamic>>.from(_stats!)
      ..sort((a, b) => getValue(b).compareTo(getValue(a)));
    return sorted;
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
            Text(
              _error!,
              style: textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadLeagues, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_stats == null || _stats!.isEmpty) {
      return const Center(
        child: AppEmptyState(
          imageAsset: AppAssets.noStatsEmpty,
          title: 'No player stats yet',
          subtitle:
              'Top performers will appear once players record stats in matches.',
        ),
      );
    }

    final sections = <_TeamStatSection>[
      _TeamStatSection(
        title: 'Goals',
        players: _topPlayers(
          (r) => (r['total_goals'] as num?)?.toDouble() ?? 0,
        ),
        allPlayers: _allTopPlayers(
          (r) => (r['total_goals'] as num?)?.toDouble() ?? 0,
        ),
        format: (r) => (r['total_goals'] ?? 0).toString(),
      ),
      _TeamStatSection(
        title: 'Assists',
        players: _topPlayers(
          (r) => (r['total_assists'] as num?)?.toDouble() ?? 0,
        ),
        allPlayers: _allTopPlayers(
          (r) => (r['total_assists'] as num?)?.toDouble() ?? 0,
        ),
        format: (r) => (r['total_assists'] ?? 0).toString(),
      ),
      _TeamStatSection(
        title: 'Goals + Assists',
        players: _topPlayers(
          (r) => (r['goals_assists'] as num?)?.toDouble() ?? 0,
        ),
        allPlayers: _allTopPlayers(
          (r) => (r['goals_assists'] as num?)?.toDouble() ?? 0,
        ),
        format: (r) => (r['goals_assists'] ?? 0).toString(),
      ),
      _TeamStatSection(
        title: 'Average rating',
        players: _topPlayers((r) => (r['avg_rating'] as num?)?.toDouble() ?? 0),
        allPlayers: _allTopPlayers(
          (r) => (r['avg_rating'] as num?)?.toDouble() ?? 0,
        ),
        format: (r) =>
            ((r['avg_rating'] as num?)?.toDouble() ?? 0).toStringAsFixed(2),
      ),
      _TeamStatSection(
        title: 'Saves',
        players: _topPlayers(
          (r) => (r['total_saves'] as num?)?.toDouble() ?? 0,
        ),
        allPlayers: _allTopPlayers(
          (r) => (r['total_saves'] as num?)?.toDouble() ?? 0,
        ),
        format: (r) => (r['total_saves'] ?? 0).toString(),
      ),
      _TeamStatSection(
        title: 'Tackles',
        players: _topPlayers(
          (r) => (r['total_tackles'] as num?)?.toDouble() ?? 0,
        ),
        allPlayers: _allTopPlayers(
          (r) => (r['total_tackles'] as num?)?.toDouble() ?? 0,
        ),
        format: (r) => (r['total_tackles'] ?? 0).toString(),
      ),
      _TeamStatSection(
        title: 'Yellow cards',
        players: _topPlayers(
          (r) => (r['total_yellow_cards'] as num?)?.toDouble() ?? 0,
        ),
        allPlayers: _allTopPlayers(
          (r) => (r['total_yellow_cards'] as num?)?.toDouble() ?? 0,
        ),
        format: (r) => (r['total_yellow_cards'] ?? 0).toString(),
      ),
      _TeamStatSection(
        title: 'Red cards',
        players: _topPlayers(
          (r) => (r['total_red_cards'] as num?)?.toDouble() ?? 0,
        ),
        allPlayers: _allTopPlayers(
          (r) => (r['total_red_cards'] as num?)?.toDouble() ?? 0,
        ),
        format: (r) => (r['total_red_cards'] ?? 0).toString(),
      ),
      _TeamStatSection(
        title: 'Shots on target',
        players: _topPlayers(
          (r) => (r['total_shots_on_target'] as num?)?.toDouble() ?? 0,
        ),
        allPlayers: _allTopPlayers(
          (r) => (r['total_shots_on_target'] as num?)?.toDouble() ?? 0,
        ),
        format: (r) => (r['total_shots_on_target'] ?? 0).toString(),
      ),
      _TeamStatSection(
        title: 'Goals per match',
        players: _topPlayers((r) => _perMatch(r, 'total_goals')),
        allPlayers: _allTopPlayers((r) => _perMatch(r, 'total_goals')),
        format: (r) => _perMatch(r, 'total_goals').toStringAsFixed(1),
      ),
      _TeamStatSection(
        title: 'Saves per match',
        players: _topPlayers((r) => _perMatch(r, 'total_saves')),
        allPlayers: _allTopPlayers((r) => _perMatch(r, 'total_saves')),
        format: (r) => _perMatch(r, 'total_saves').toStringAsFixed(1),
      ),
      _TeamStatSection(
        title: 'Missed opportunities',
        players: _topPlayers(
          (r) => (r['missed_opportunities'] as num?)?.toDouble() ?? 0,
        ),
        allPlayers: _allTopPlayers(
          (r) => (r['missed_opportunities'] as num?)?.toDouble() ?? 0,
        ),
        format: (r) => (r['missed_opportunities'] ?? 0).toString(),
      ),
    ];

    final header = _leagues.isNotEmpty
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownMenu<String>(
                key: ValueKey<String>(
                  'players_league_${_selectedLeague ?? ''}',
                ),
                initialSelection: _selectedLeague ?? '',
                label: const Text('League'),
                expandedInsets: EdgeInsets.zero,
                dropdownMenuEntries: _leagues.map((l) {
                  final id = l['id']?.toString() ?? '';
                  final name = l['league_name']?.toString() ?? '';
                  return DropdownMenuEntry<String>(value: id, label: name);
                }).toList(),
                onSelected: _onLeagueChanged,
              ),
              const SizedBox(height: 12),
              DropdownMenu<String>(
                key: ValueKey<String>(
                  'players_season_${_selectedLeague ?? ''}_${_seasonEntries.length}',
                ),
                initialSelection: _selectedSeason,
                label: const Text('Season'),
                expandedInsets: EdgeInsets.zero,
                dropdownMenuEntries: _seasonEntries,
                onSelected: _onSeasonChanged,
              ),
            ],
          )
        : const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: _loadLeagues,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_leagues.isNotEmpty) ...[header, const SizedBox(height: 16)],
          for (int i = 0; i < sections.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _TeamStatSectionCard(section: sections[i]),
          ],
        ],
      ),
    );
  }
}

class _TeamStatSection {
  const _TeamStatSection({
    required this.title,
    required this.players,
    required this.allPlayers,
    required this.format,
  });

  final String title;
  final List<Map<String, dynamic>> players;
  final List<Map<String, dynamic>> allPlayers;
  final String Function(Map<String, dynamic>) format;
}

class _TeamStatSectionCard extends StatelessWidget {
  const _TeamStatSectionCard({required this.section});

  final _TeamStatSection section;

  void _openFullList(BuildContext context) {
    final nav = Navigator.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: _TeamTopPlayersFullSheet(
            section: section,
            onPlayerTap: (playerId) {
              nav.pop();
              nav.push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => PlayerProfilePage(playerId: playerId),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final showSeeAll = section.allPlayers.isNotEmpty;

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
              Expanded(child: Text(section.title, style: textTheme.titleSmall)),
              if (showSeeAll)
                TextButton(
                  onPressed: () => _openFullList(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'See all',
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
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

/// Full leaderboard for one stat category (opened from Top players â†’ See all).
class _TeamTopPlayersFullSheet extends StatelessWidget {
  const _TeamTopPlayersFullSheet({
    required this.section,
    required this.onPlayerTap,
  });

  final _TeamStatSection section;
  final void Function(String playerId) onPlayerTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.72;

    return Material(
      color: colorScheme.surface,
      child: SizedBox(
        height: sheetHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      section.title,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                '${section.allPlayers.length} players Â· ranked by ${section.title.toLowerCase()}',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: section.allPlayers.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                ),
                itemBuilder: (context, index) {
                  final rank = index + 1;
                  final row = section.allPlayers[index];
                  final playerName =
                      row['player_name']?.toString() ?? 'Unknown';
                  final imageUrl = row['image_url']?.toString() ?? '';
                  final position = row['position']?.toString() ?? '';
                  final value = section.format(row);
                  final playerId = row['player_id']?.toString() ?? '';

                  return InkWell(
                    onTap: playerId.isEmpty
                        ? null
                        : () => onPlayerTap(playerId),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 40,
                            child: Text(
                              '$rank',
                              textAlign: TextAlign.center,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: rank <= 3
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          _TeamStatAvatar(imageUrl: imageUrl, radius: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  playerName,
                                  style: textTheme.bodyLarge,
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
                          Text(
                            value,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
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
        backgroundColor: colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.person,
          size: radius,
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return CircleAvatar(
        backgroundColor: colorScheme.surfaceContainerHighest,
        backgroundImage: appCachedImageProvider(imageUrl),
      );
    }
    return CircleAvatar(
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
  static const int _videosPageSize = 24;

  List<LeagueVideoItem>? _videos;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  _TeamVideoSort _sortOrder = _TeamVideoSort.newest;
  bool _isFeedLayout = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Match ids where this team played (either side).
  Future<Set<String>> _fetchTeamMatchIds() async {
    final client = Supabase.instance.client;
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
    return matchIds;
  }

  Future<List<Map<String, dynamic>>> _fetchVideosPage(int offset) async {
    final matchIds = await _fetchTeamMatchIds();
    if (matchIds.isEmpty) return [];
    final rawVideos = await Supabase.instance.client
        .from('videos')
        .select(
          'id, match_id, uploader_user_id, duration_seconds, '
          'video_url, thumbnail_url, created_at',
        )
        .inFilter('match_id', matchIds.toList())
        .order('created_at', ascending: false)
        .range(offset, offset + _videosPageSize - 1);
    return List<Map<String, dynamic>>.from(rawVideos as List);
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await _fetchVideosPage(0);
      if (!mounted) return;
      final enriched = await _enrichVideos(list);
      if (!mounted) return;
      setState(() {
        _videos = enriched;
        _hasMore = list.length >= _videosPageSize;
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

  Future<void> _loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final list = await _fetchVideosPage(_videos?.length ?? 0);
      if (!mounted) return;
      final enriched = await _enrichVideos(list);
      if (!mounted) return;
      setState(() {
        final existing = {for (final v in _videos ?? <LeagueVideoItem>[]) v.videoId};
        _videos = [
          ...?_videos,
          ...enriched.where((v) => !existing.contains(v.videoId)),
        ];
        _hasMore = list.length >= _videosPageSize;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  /// Schedules the next page fetch when the grid/feed renders near its end.
  void _maybeRequestMore(int index, int total) {
    if (!_hasMore || _isLoadingMore) return;
    if (index < total - 6) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadMore();
    });
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
          .select('id, player_name, image_url, deleted_at')
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
          uploadersMap[v['uploader_user_id']?.toString()] ??
          <String, dynamic>{};
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
            uploader['deleted_at'] == null &&
            uploaderUserId != null &&
            followsSet.contains(uploaderUserId),
        isUploaderDeleted: uploader['deleted_at'] != null,
        viewCount: viewCountMap[vid] ?? 0,
      );
    }).toList();
  }

  static String _resolveVideoLogo(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('lib/assets/') || raw.startsWith('assets/')) return raw;
    final name = raw.contains('.') ? raw : '$raw.png';
    return resolveTeamLogoPath(raw) ?? '';
  }

  List<LeagueVideoItem> get _sortedVideos {
    if (_videos == null) return [];
    final list = List<LeagueVideoItem>.from(_videos!);
    switch (_sortOrder) {
      case _TeamVideoSort.newest:
        list.sort(
          (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
            a.createdAt ?? DateTime(0),
          ),
        );
      case _TeamVideoSort.oldest:
        list.sort(
          (a, b) => (a.createdAt ?? DateTime(0)).compareTo(
            b.createdAt ?? DateTime(0),
          ),
        );
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
        builder: (_) =>
            LeagueVideoPlayerPage(videos: _sortedVideos, initialIndex: index),
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
                      Icon(
                        Icons.swap_vert,
                        size: 20,
                        color: colorScheme.onSurface,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _sortLabel,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface,
                        ),
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
                child: AppEmptyState(
                  imageAsset: AppAssets.videosAltEmpty,
                  title: 'No videos yet',
                  subtitle:
                      'Highlights uploaded from this team\'s matches will appear here.',
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
        _maybeRequestMore(index, videos.length);
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
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 12,
                          ),
                          if (v.durationSeconds != null) ...[
                            const SizedBox(width: 2),
                            Text(
                              _formatDuration(v.durationSeconds!),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
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
        _maybeRequestMore(index, videos.length);
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
                      Text(
                        v.teamAShort,
                        style: textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${v.teamAScore} - ${v.teamBScore}',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        v.teamBShort,
                        style: textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _TeamVideoLogo(logoPath: v.teamBLogo, size: 24),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          v.matchStatus,
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSecondaryContainer,
                          ),
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
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 32,
                          ),
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
                      Icon(
                        Icons.favorite,
                        size: 16,
                        color: v.isLiked
                            ? Colors.red
                            : colorScheme.onSurfaceVariant,
                      ),
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
      return Image(
        image: appCachedImageProvider(url),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => videoThumbnailPlaceholder(context),
      );
    }
    return videoThumbnailPlaceholder(context);
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
      return Icon(
        Icons.groups,
        size: size,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );
    }
    final isNetwork =
        logoPath.startsWith('http://') || logoPath.startsWith('https://');
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: isNetwork
            ? Image(
                image: appCachedImageProvider(logoPath),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  Icons.groups,
                  size: size * 0.7,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            : Image.asset(
                logoPath,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  Icons.groups,
                  size: size * 0.7,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
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
        hasImage &&
        (avatarUrl!.startsWith('http://') || avatarUrl!.startsWith('https://'));
    return CircleAvatar(
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      backgroundImage: hasImage
          ? (isNetwork ? appCachedImageProvider(avatarUrl!) : AssetImage(avatarUrl!))
          : null,
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

class _EditTeamPage extends StatefulWidget {
  const _EditTeamPage({
    required this.teamId,
    required this.initialTeamName,
    required this.initialShortForm,
    this.initialLogoUrl,
    this.initialBannerUrl,
    this.initialSocialInstagram,
    this.initialSocialTiktok,
    this.initialSocialX,
  });

  final String teamId;
  final String initialTeamName;
  final String initialShortForm;
  final String? initialLogoUrl;
  final String? initialBannerUrl;
  final String? initialSocialInstagram;
  final String? initialSocialTiktok;
  final String? initialSocialX;

  @override
  State<_EditTeamPage> createState() => _EditTeamPageState();
}

class _EditTeamPageState extends State<_EditTeamPage> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();

  late final TextEditingController _teamNameController;
  late final TextEditingController _shortFormController;
  late final TextEditingController _socialInstagramController;
  late final TextEditingController _socialTiktokController;
  late final TextEditingController _socialXController;

  String? _logoUrl;
  String? _bannerUrl;
  bool _isUploadingLogo = false;
  bool _isUploadingBanner = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _teamNameController = TextEditingController(text: widget.initialTeamName);
    _shortFormController = TextEditingController(text: widget.initialShortForm);
    _socialInstagramController = TextEditingController(
      text: widget.initialSocialInstagram ?? '',
    );
    _socialTiktokController = TextEditingController(
      text: widget.initialSocialTiktok ?? '',
    );
    _socialXController = TextEditingController(
      text: widget.initialSocialX ?? '',
    );
    _logoUrl = widget.initialLogoUrl;
    _bannerUrl = widget.initialBannerUrl;
  }

  @override
  void dispose() {
    _teamNameController.dispose();
    _shortFormController.dispose();
    _socialInstagramController.dispose();
    _socialTiktokController.dispose();
    _socialXController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload({
    required bool isBanner,
    required String folderName,
  }) async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select image source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    if (!mounted) return;

    if (!await ensureMediaAccessForImageSource(context, source)) return;
    if (!mounted) return;

    final XFile? picked;
    try {
      picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: isBanner ? 88 : 85,
        maxWidth: isBanner ? 1800 : 1024,
        maxHeight: isBanner ? 1200 : 1024,
      );
    } catch (error) {
      if (!mounted) return;
      if (await presentMediaAccessSheetIfNeeded(
        context,
        error,
        mediaAccessKindForImageSource(source),
      )) {
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not pick image: $error')));
      return;
    }
    if (picked == null) return;

    if (isBanner) {
      setState(() => _isUploadingBanner = true);
    } else {
      setState(() => _isUploadingLogo = true);
    }

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final fileName =
          '${user.id}_${DateTime.now().millisecondsSinceEpoch}${path.extension(picked.path)}';
      final filePath = '$folderName/$fileName';
      final bytes = await picked.readAsBytes();
      await requireAllowedImage(
        bytes,
        contentRef: 'image:$folderName',
      );
      await supabase.storage
          .from('Profile images')
          .uploadBinary(filePath, bytes);
      final url = supabase.storage
          .from('Profile images')
          .getPublicUrl(filePath);

      if (!mounted) return;
      setState(() {
        if (isBanner) {
          _bannerUrl = url;
        } else {
          _logoUrl = url;
        }
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $error')));
    } finally {
      if (!mounted) return;
      setState(() {
        if (isBanner) {
          _isUploadingBanner = false;
        } else {
          _isUploadingLogo = false;
        }
      });
    }
  }

  Future<void> _save() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;
    if (_bannerUrl == null || _bannerUrl!.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Team banner is required')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final teamName = _teamNameController.text.trim();
      final shortForm = _shortFormController.text.trim();
      final nameBlock = UsernameRules.offensiveContentError(teamName) ??
          UsernameRules.offensiveContentError(shortForm);
      if (nameBlock != null) {
        throw StateError(nameBlock);
      }
      await requireAllowedText(teamName, contentRef: 'team_name');

      await Supabase.instance.client
          .from('teams')
          .update({
            'team_name': teamName,
            'short_form': shortForm,
            'logo_id': _logoUrl,
            'banner_id': _bannerUrl,
            'social_instagram': _trimOrNull(_socialInstagramController.text),
            'social_tiktok': _trimOrNull(_socialTiktokController.text),
            'social_x': _trimOrNull(_socialXController.text),
          })
          .eq('id', widget.teamId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating team: $error')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit team'),
        actions: [
          IconButton(
            tooltip: 'Save',
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _teamNameController,
                decoration: const InputDecoration(labelText: 'Team name'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a team name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _shortFormController,
                decoration: const InputDecoration(labelText: 'Short form'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a short form';
                  }
                  if (value.trim().length > 6) {
                    return 'Keep it short (max 6 characters)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              Text('Team logo', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              ImageUploadCard(
                imageUrl: _logoUrl,
                isUploading: _isUploadingLogo,
                emptyLabel: 'Tap to upload team logo',
                isCircular: true,
                onTap: () =>
                    _pickAndUpload(isBanner: false, folderName: 'team logos'),
                onClear: _logoUrl == null
                    ? null
                    : () => setState(() => _logoUrl = null),
              ),
              const SizedBox(height: 18),
              Text(
                'Team banner *',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _isUploadingBanner
                    ? null
                    : () => _pickAndUpload(
                        isBanner: true,
                        folderName: 'team banners',
                      ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: double.infinity,
                    height: 150,
                    color: colorScheme.surfaceContainerHighest,
                    child: _isUploadingBanner
                        ? const Center(child: CircularProgressIndicator())
                        : (_bannerUrl != null && _bannerUrl!.isNotEmpty)
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              Image(
                                image: appCachedImageProvider(_bannerUrl!),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Icon(
                                      Icons.image_not_supported,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  );
                                },
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: IconButton.filledTonal(
                                  onPressed: () =>
                                      setState(() => _bannerUrl = null),
                                  icon: const Icon(Icons.close),
                                  tooltip: 'Remove banner',
                                ),
                              ),
                            ],
                          )
                        : Center(
                            child: Icon(
                              Icons.add_photo_alternate_outlined,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Social links (optional)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Use full URLs starting with https://',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _socialInstagramController,
                decoration: const InputDecoration(
                  labelText: 'Instagram',
                  hintText: 'https://instagram.com/…',
                ),
                keyboardType: TextInputType.url,
                autocorrect: false,
                validator: _optionalHttpsUrlValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _socialTiktokController,
                decoration: const InputDecoration(
                  labelText: 'TikTok',
                  hintText: 'https://www.tiktok.com/@…',
                ),
                keyboardType: TextInputType.url,
                autocorrect: false,
                validator: _optionalHttpsUrlValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _socialXController,
                decoration: const InputDecoration(
                  labelText: 'X (Twitter)',
                  hintText: 'https://x.com/…',
                ),
                keyboardType: TextInputType.url,
                autocorrect: false,
                validator: _optionalHttpsUrlValidator,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String? _optionalHttpsUrlValidator(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme) {
      return 'Enter a valid URL';
    }
    if (!(uri.isScheme('http') || uri.isScheme('https'))) {
      return 'URL must start with http:// or https://';
    }
    return null;
  }

  static String? _trimOrNull(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _TeamHeaderChip extends StatelessWidget {
  const _TeamHeaderChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ActionChip.elevated(
      avatar: Icon(icon, size: 18, color: colorScheme.onSurface),
      label: Text(label, style: TextStyle(color: colorScheme.onSurface)),
      onPressed: () {},
      backgroundColor: colorScheme.surfaceContainerHighest,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}
