import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/countries.dart';
import '../../core/utils/connection_error.dart';
import '../../core/utils/content_moderation_guards.dart';
import '../../core/utils/username_rules.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_error_state.dart';
import '../../core/widgets/media_placeholders.dart';
import '../../data/repositories/league_applications_repository.dart';
import '../../data/repositories/leagues_repository.dart';
import '../../data/repositories/matches_repository.dart';
import '../../domain/models/match_model.dart';
import '../../domain/models/season_model.dart';
import '../../data/repositories/teams_repository.dart';
import '../../domain/models/team_model.dart';
import 'fixture.dart';
import '../widgets/media_access_sheet.dart';
import 'matches.dart' show DodecagonIndicator;
import 'create_team_league_page.dart';
import '../providers/league_teams_provider.dart';
import '../providers/match_timer_adapter_provider.dart';
import '../providers/matches_provider.dart';
import '../providers/match_video_seen_provider.dart';
import '../providers/seasons_provider.dart';
import 'league_add_teams_page.dart';
import 'league_applications_page.dart';
import 'league_create_matches_page.dart';
import 'league_rejected_applications_page.dart';
import 'league_video_player_page.dart';
import '../widgets/create_season_bottom_sheet.dart';
import '../widgets/home/home_section_empty_state.dart';
import '../widgets/match_date_picker_dialog.dart';
import '../widgets/match_list_score_pill.dart';
import '../widgets/squad/team_player.dart';
import 'team_detail_page.dart';
import 'player_profile_page.dart';
import '../widgets/socials_section_card.dart';
import '../widgets/image_upload_card.dart';
import '../widgets/country_picker_section.dart';

String _leagueDetailSeasonMenuLabel(String name, [int max = 22]) {
  final t = name.trim();
  if (t.length <= max) return t;
  return '${t.substring(0, max - 1)}…';
}

class LeagueDetailPage extends ConsumerStatefulWidget {
  const LeagueDetailPage({super.key, required this.leagueId});

  final String leagueId;

  @override
  ConsumerState<LeagueDetailPage> createState() => _LeagueDetailPageState();
}

class _LeagueDetailPageState extends ConsumerState<LeagueDetailPage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _league;
  Object? _loadError;
  bool _isLoading = true;
  bool _isDeleting = false;
  bool _hasJoined = false;
  late final ScrollController _outerScrollController;
  late final TabController _tabController;
  bool _isHeaderCollapsed = false;
  int _tabViewGeneration = 0;
  int _lastTabIndex = 0;
  Color? _headerToneA;
  Color? _headerToneB;
  Color? _headerToneC;
  Color? _logoRingColor;
  String? _lastHeaderImageKey;

  @override
  void initState() {
    super.initState();
    _outerScrollController = ScrollController()
      ..addListener(_handleOuterScroll);
    _tabController = TabController(length: 8, vsync: this)
      ..addListener(_handleTabIndexChanged);
    _loadLeague();
  }

  void _handleTabIndexChanged() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == _lastTabIndex) return;
    _lastTabIndex = _tabController.index;
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

  Future<void> _loadLeague() async {
    setState(() {
      _loadError = null;
      _isLoading = true;
    });
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('leagues')
          .select()
          .eq('id', widget.leagueId)
          .maybeSingle();

      if (response != null && mounted) {
        final logoUrl = response['logo_id'] as String?;
        setState(() {
          _league = response;
          _isLoading = false;
        });
        await _deriveHeaderGradientFromImage(logoUrl);
        final currentUserId = Supabase.instance.client.auth.currentUser?.id;
        final createdBy = response['created_by']?.toString();
        if (currentUserId != null && createdBy != currentUserId) {
          await _refreshJoinState();
        }
      } else if (mounted) {
        setState(() {
          _league = null;
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

  Future<void> _deriveHeaderGradientFromImage(String? logoUrl) async {
    final imageKey = logoUrl?.trim().isNotEmpty == true
        ? logoUrl!.trim()
        : '__league_fallback__';
    if (_lastHeaderImageKey == imageKey) return;
    _lastHeaderImageKey = imageKey;

    final ImageProvider provider = logoUrl != null && logoUrl.trim().isNotEmpty
        ? appCachedImageProvider(logoUrl.trim())
        : AssetImage(AppAssets.pitchBg);
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
      // If image color extraction fails (e.g. network), keep theme fallback.
    }
  }

  List<PopupMenuItem<String>> _buildSeasonMenuItems(ColorScheme colorScheme) {
    final seasonsAsync = ref.watch(
      allSeasonsForLeagueProvider(widget.leagueId),
    );
    return seasonsAsync.when(
      data: (seasons) {
        final ongoing = seasons.where((s) => s.status == 'ongoing').firstOrNull;
        final upcoming = seasons
            .where((s) => s.status == 'upcoming')
            .firstOrNull;
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
      error: (_, _) => [],
    );
  }

  Future<void> _handleStartSeason() async {
    final seasonsAsync = ref.read(allSeasonsForLeagueProvider(widget.leagueId));
    final seasons = seasonsAsync.value ?? [];
    final upcoming = seasons.where((s) => s.status == 'upcoming').firstOrNull;
    if (upcoming == null) return;
    try {
      await ref.read(seasonsRepositoryProvider).startSeason(upcoming.id);
      if (!mounted) return;
      ref.invalidate(allSeasonsForLeagueProvider(widget.leagueId));
      ref.invalidate(ongoingOrUpcomingSeasonProvider(widget.leagueId));
      ref.invalidate(leagueSeasonFixtureProgressProvider(widget.leagueId));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Season started')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _handleEndSeason() async {
    final seasonsAsync = ref.read(allSeasonsForLeagueProvider(widget.leagueId));
    final seasons = seasonsAsync.value ?? [];
    final ongoing = seasons.where((s) => s.status == 'ongoing').firstOrNull;
    if (ongoing == null) return;
    try {
      await ref.read(seasonsRepositoryProvider).endSeason(ongoing.id);
      if (!mounted) return;
      ref.invalidate(allSeasonsForLeagueProvider(widget.leagueId));
      ref.invalidate(ongoingOrUpcomingSeasonProvider(widget.leagueId));
      ref.invalidate(leagueSeasonFixtureProgressProvider(widget.leagueId));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Season ended')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _refreshJoinState() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        if (!mounted) return;
        setState(() => _hasJoined = false);
        return;
      }

      final userTeamIds = await _getUserTeamIds(supabase, userId);
      if (userTeamIds.isEmpty) {
        if (!mounted) return;
        setState(() => _hasJoined = false);
        return;
      }

      final res = await supabase
          .from('league_team_memberships')
          .select('team_id')
          .eq('league_id', widget.leagueId)
          .inFilter('team_id', userTeamIds.toList())
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

  Future<Set<String>> _getUserTeamIds(
    SupabaseClient client,
    String userId,
  ) async {
    final ids = <String>{};

    final created = await client
        .from('teams')
        .select('id')
        .eq('created_by', userId);
    for (final r in created as List) {
      final id = r['id']?.toString();
      if (id != null && id.isNotEmpty) ids.add(id);
    }

    final memberships = await client
        .from('player_team_memberships')
        .select('team_id')
        .eq('player_id', userId);
    for (final r in memberships as List) {
      final id = r['team_id']?.toString();
      if (id != null && id.isNotEmpty) ids.add(id);
    }

    return ids;
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
    final teams = allTeams
        .where((t) => !existingTeamIds.contains(t.id))
        .toList();
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

  Future<void> _openLeagueOwnerTools() async {
    if (_league == null) return;
    final league = _league!;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Edit league details'),
                  subtitle: const Text(
                    'Name, country, logo and default match background',
                  ),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    final changed = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => _LeagueOwnerSettingsPage(
                          leagueId: widget.leagueId,
                          initialLeagueName:
                              league['league_name']?.toString() ?? '',
                          initialLogoUrl: league['logo_id']?.toString(),
                          initialDefaultVenueImageUrl:
                              league['default_venue_image_url']?.toString(),
                          initialCountry: league['country']?.toString(),
                          initialSocialInstagram: league['social_instagram']
                              ?.toString(),
                          initialSocialTiktok: league['social_tiktok']
                              ?.toString(),
                          initialSocialX: league['social_x']?.toString(),
                        ),
                      ),
                    );
                    if (changed == true && mounted) {
                      await _loadLeague();
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.groups_2_outlined),
                  title: const Text('Kick out teams'),
                  subtitle: const Text(
                    'Remove teams from this league membership',
                  ),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    final changed = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) =>
                            _LeagueOwnerTeamsPage(leagueId: widget.leagueId),
                      ),
                    );
                    if (changed == true && mounted) {
                      ref.invalidate(teamsInLeagueProvider(widget.leagueId));
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.event_note_outlined),
                  title: const Text('Edit fixtures'),
                  subtitle: const Text(
                    'Delete/postpone upcoming or correct ended stats',
                  ),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    final changed = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) =>
                            _LeagueOwnerFixturesPage(leagueId: widget.leagueId),
                      ),
                    );
                    if (changed == true && mounted) {
                      ref.invalidate(matchesProvider);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
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
                : 'Could not load league',
            subtitle: isConnectionError(_loadError)
                ? 'Check your internet connection and try again.'
                : 'Something went wrong while loading this league.',
            onRetry: _loadLeague,
          ),
        ),
      );
    }

    if (_league == null) {
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
            title: 'League not found',
            subtitle: 'This league may have been removed or the link is incorrect.',
          ),
        ),
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
    final countryCode = _league!['country']?.toString();
    final countryLabel = (countryCode == null || countryCode.isEmpty)
        ? null
        : '${countryCodeToFlag(countryCode)} ${countryCodeToName(countryCode)}';
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isOwner = createdBy != null && createdBy == currentUserId;
    final headerToneA = _headerToneA ?? colorScheme.surfaceContainerHigh;
    final headerToneB = _headerToneB ?? colorScheme.surfaceContainer;
    final headerToneC = _headerToneC ?? colorScheme.surfaceContainerLow;
    final logoRingColor = _logoRingColor ?? colorScheme.primaryContainer;
    final seasonAsync = ref.watch(
      ongoingOrUpcomingSeasonProvider(widget.leagueId),
    );
    final season = switch (seasonAsync) {
      AsyncData<SeasonModel?>(:final value) => value,
      _ => null,
    };
    final seasonStatus = season?.status.toLowerCase();
    final (seasonLabel, seasonIcon, seasonTint) = switch (seasonStatus) {
      'ongoing' => (
        'Season Live',
        Icons.play_circle_fill_rounded,
        colorScheme.tertiary,
      ),
      'upcoming' => (
        'Season Upcoming',
        Icons.schedule_rounded,
        colorScheme.primary,
      ),
      _ => (
        'Off Season',
        Icons.pause_circle_filled_rounded,
        colorScheme.onSurfaceVariant,
      ),
    };

    return Scaffold(
      appBar: AppBar(
        title: const SizedBox.shrink(),
        centerTitle: false,
        actions: [
          if (!isOwner)
            IconButton(
              onPressed: _handleJoinLeague,
              icon: Icon(_hasJoined ? Icons.add : Icons.login),
              tooltip: _hasJoined ? 'Add team to league' : 'Join league',
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
        child: NestedScrollView(
          controller: _outerScrollController,
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                pinned: true,
                primary: false,
                toolbarHeight: 0,
                expandedHeight: 200,
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
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 104,
                                        height: 104,
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Container(
                                              width: 96,
                                              height: 96,
                                              decoration: BoxDecoration(
                                                color: logoRingColor,
                                                borderRadius:
                                                    BorderRadius.circular(28),
                                                border: Border.all(
                                                  color: logoRingColor,
                                                  width: 1.2,
                                                ),
                                              ),
                                              child: Center(
                                                child: Container(
                                                  width: 68,
                                                  height: 68,
                                                  decoration: BoxDecoration(
                                                    color: colorScheme
                                                        .surfaceContainerHighest,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: colorScheme.outline
                                                          .withValues(alpha: 0.32),
                                                    ),
                                                  ),
                                                  child:
                                                      logoUrl != null &&
                                                          logoUrl.isNotEmpty
                                                      ? ClipOval(
                                                          child: Image(
                                                            image: appCachedImageProvider(logoUrl),
                                                            width: 68,
                                                            height: 68,
                                                            fit: BoxFit.cover,
                                                            errorBuilder:
                                                                (
                                                                  context,
                                                                  error,
                                                                  stackTrace,
                                                                ) {
                                                                  return Icon(
                                                                    Icons
                                                                        .emoji_events,
                                                                    size: 34,
                                                                    color: colorScheme
                                                                        .onSurfaceVariant,
                                                                  );
                                                                },
                                                          ),
                                                        )
                                                      : Icon(
                                                          Icons.emoji_events,
                                                          size: 34,
                                                          color: colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              right: -2,
                                              top: -2,
                                              child: Container(
                                                width: 30,
                                                height: 30,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: colorScheme.primary,
                                                  border: Border.all(
                                                    color: colorScheme.surface,
                                                    width: 2,
                                                  ),
                                                ),
                                                child: Icon(
                                                  Icons.emoji_events,
                                                  size: 16,
                                                  color: colorScheme.onPrimary,
                                                ),
                                              ),
                                            ),
                                          ],
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
                                              leagueName,
                                              style: textTheme.titleLarge
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              [
                                                'Est. $estYear',
                                                ?countryLabel,
                                              ].join(' Â· '),
                                              style: textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                            const SizedBox(height: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: seasonTint.withValues(
                                                  alpha: 0.14,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                                border: Border.all(
                                                  color: seasonTint.withValues(
                                                    alpha: 0.32,
                                                  ),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    seasonIcon,
                                                    size: 13,
                                                    color: seasonTint,
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    seasonLabel,
                                                    style: textTheme.labelSmall
                                                        ?.copyWith(
                                                          letterSpacing: 0.4,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: seasonTint,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      if (isOwner)
                                        FilledButton(
                                          onPressed: _openLeagueOwnerTools,
                                          style: FilledButton.styleFrom(
                                            shape: const RoundedRectangleBorder(
                                              borderRadius: BorderRadius.all(
                                                Radius.circular(999),
                                              ),
                                            ),
                                            padding: const EdgeInsets.only(
                                              left: 17,
                                              right: 17,
                                              top: 12,
                                              bottom: 12,
                                            ),
                                            minimumSize: const Size(60, 40),
                                          ),
                                          child: const Icon(
                                            Icons.edit_outlined,
                                            size: 20,
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
                        Tab(text: 'Team stats'),
                        Tab(text: 'Player stats'),
                        Tab(text: 'Teams'),
                        Tab(text: 'Seasons'),
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
            children: [
              KeyedSubtree(
                key: ValueKey('league-tab-0-$_tabViewGeneration'),
                child: _LeagueOverviewTab(
                  league: _league!,
                  leagueId: widget.leagueId,
                  showOwnerActions: isOwner,
                  onOpenPlayerStatsTab: () => _tabController.animateTo(4),
                  onOpenSeasonsTab: () => _tabController.animateTo(6),
                  onOpenMatchesTab: () => _tabController.animateTo(1),
                  onCreateMatch: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            LeagueCreateMatchesPage(leagueId: widget.leagueId),
                      ),
                    );
                  },
                ),
              ),
              KeyedSubtree(
                key: ValueKey('league-tab-1-$_tabViewGeneration'),
                child: _LeagueMatchesTab(
                  leagueId: widget.leagueId,
                  showCreateMatchCta: isOwner,
                ),
              ),
              KeyedSubtree(
                key: ValueKey('league-tab-2-$_tabViewGeneration'),
                child: _LeagueStandingsTab(leagueId: widget.leagueId),
              ),
              KeyedSubtree(
                key: ValueKey('league-tab-3-$_tabViewGeneration'),
                child: _LeagueTeamStatsTab(leagueId: widget.leagueId),
              ),
              KeyedSubtree(
                key: ValueKey('league-tab-4-$_tabViewGeneration'),
                child: _LeaguePlayerStatsTab(leagueId: widget.leagueId),
              ),
              KeyedSubtree(
                key: ValueKey('league-tab-5-$_tabViewGeneration'),
                child: _LeagueTeamsTab(
                  leagueId: widget.leagueId,
                  showOwnerActions: isOwner,
                ),
              ),
              KeyedSubtree(
                key: ValueKey('league-tab-6-$_tabViewGeneration'),
                child: _LeagueSeasonsTab(leagueId: widget.leagueId),
              ),
              KeyedSubtree(
                key: ValueKey('league-tab-7-$_tabViewGeneration'),
                child: _LeagueVideosTab(leagueId: widget.leagueId),
              ),
            ],
          ),
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
              ? Image(
                  image: appCachedImageProvider(path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      Icon(Icons.groups, color: colorScheme.onSurfaceVariant),
                )
              : Image.asset(
                  path,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
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
  const _LeagueTeamsTab({
    required this.leagueId,
    this.showOwnerActions = false,
  });

  final String leagueId;
  final bool showOwnerActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final asyncTeams = ref.watch(teamsInLeagueProvider(leagueId));

    return asyncTeams.when(
      data: (teams) {
        if (teams.isEmpty) {
          return Center(
            child: AppEmptyState(
              imageAsset: AppAssets.addTeamsEmpty,
              title: 'No teams yet',
              subtitle: showOwnerActions
                  ? 'Search for teams and add them to this league to get started.'
                  : 'Teams in this league will show up here once they are added.',
              actionLabel: showOwnerActions ? 'Add teams' : null,
              onAction: showOwnerActions
                  ? () async {
                      await Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              LeagueAddTeamsPage(leagueId: leagueId),
                        ),
                      );
                      ref.invalidate(teamsInLeagueProvider(leagueId));
                    }
                  : null,
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: teams.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
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
                              ? Image(
                                  image: appCachedImageProvider(path),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Icon(
                                    Icons.groups,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                )
                              : Image.asset(
                                  path,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Icon(
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
    final result = await showCreateSeasonBottomSheet(
      context,
      helperText:
          'Start and end dates will be filled automatically from the first and last match in this season.',
    );

    if (result == null || !mounted) return;
    final name = result['name'] as String? ?? '';
    if (name.isEmpty) return;

    try {
      final repo = ref.read(seasonsRepositoryProvider);
      await repo.createSeason(leagueId: widget.leagueId, seasonName: name);
      if (!mounted) return;
      ref.invalidate(allSeasonsForLeagueProvider(widget.leagueId));
      ref.invalidate(ongoingOrUpcomingSeasonProvider(widget.leagueId));
      ref.invalidate(leagueSeasonFixtureProgressProvider(widget.leagueId));
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

  String _formatSeasonRange(SeasonModel season) {
    final sd = season.startDate;
    final ed = season.endDate;
    if (sd != null && ed != null) {
      return '${_formatDate(sd)} – ${_formatDate(ed)}';
    }
    if (sd != null) return '${_formatDate(sd)} – TBC';
    if (ed != null) return 'TBC – ${_formatDate(ed)}';
    return 'Date range appears after matches are created';
  }

  void _showSeasonBottomSheet(BuildContext context, SeasonModel season) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isOngoing = season.status == 'ongoing';
    final isUpcoming = season.status == 'upcoming';
    final dateRange = _formatSeasonRange(season);

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
                    ? colorScheme.primaryContainer.withValues(alpha: 0.5)
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
                    await ref
                        .read(seasonsRepositoryProvider)
                        .startSeason(season.id);
                    if (!mounted) return;
                    ref.invalidate(
                      allSeasonsForLeagueProvider(widget.leagueId),
                    );
                    ref.invalidate(
                      ongoingOrUpcomingSeasonProvider(widget.leagueId),
                    );
                    ref.invalidate(
                      leagueSeasonFixtureProgressProvider(widget.leagueId),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Season started')),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
                    await ref
                        .read(seasonsRepositoryProvider)
                        .endSeason(season.id);
                    if (!mounted) return;
                    ref.invalidate(
                      allSeasonsForLeagueProvider(widget.leagueId),
                    );
                    ref.invalidate(
                      ongoingOrUpcomingSeasonProvider(widget.leagueId),
                    );
                    ref.invalidate(
                      leagueSeasonFixtureProgressProvider(widget.leagueId),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Season ended')),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
        final hasUpcoming = seasons.any((s) => s.status == 'upcoming');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: seasons.isEmpty
                  ? const Center(
                      child: AppEmptyState(
                        imageAsset: AppAssets.seasonEmpty,
                        title: 'No seasons yet',
                        subtitle:
                            'Create a season to organize fixtures, standings, and stats for this league.',
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      itemCount: seasons.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final season = seasons[index];
                        final isOngoing = season.status == 'ongoing';
                        final isEnded = season.status == 'ended';
                        final dateRange = _formatSeasonRange(season);

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
                                          : colorScheme.primary.withValues(
                                              alpha: 0.5,
                                            ),
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
                                          style: textTheme.titleMedium
                                              ?.copyWith(
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
                                          color:
                                              colorScheme.onTertiaryContainer,
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
                                            .withValues(alpha: 0.5),
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
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (hasUpcoming) ...[
                      Text(
                        'There is already an upcoming season. End it before creating a new one.',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                    ],
                    FilledButton.icon(
                      onPressed: hasUpcoming ? null : _showCreateSeasonDialog,
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Create season'),
                    ),
                  ],
                ),
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

/// Overview tab section shell (title + body) aligned with profile/home sections.
class _LeagueOverviewSectionCard extends StatelessWidget {
  const _LeagueOverviewSectionCard({
    required this.child,
    this.title,
    this.header,
  });

  final Widget child;
  final String? title;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            header!
          else if (title != null)
            Text(title!, style: textTheme.titleSmall),
          if (header != null || title != null) const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _LeagueOverviewTab extends ConsumerWidget {
  const _LeagueOverviewTab({
    required this.league,
    required this.leagueId,
    required this.onOpenPlayerStatsTab,
    required this.onOpenSeasonsTab,
    required this.onOpenMatchesTab,
    required this.onCreateMatch,
    this.showOwnerActions = false,
  });

  final Map<String, dynamic> league;
  final String leagueId;
  final VoidCallback onOpenPlayerStatsTab;
  final VoidCallback onOpenSeasonsTab;
  final VoidCallback onOpenMatchesTab;
  final VoidCallback onCreateMatch;
  final bool showOwnerActions;

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

  String _formatDateShort(DateTime d) => '${d.day} ${_monthAbbr[d.month - 1]}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final leagueName = league['league_name'] as String? ?? 'Unknown';
    final logoUrl = league['logo_id'] as String?;
    final seasonAsync = ref.watch(ongoingOrUpcomingSeasonProvider(leagueId));
    final fixtureProgressAsync = ref.watch(
      leagueSeasonFixtureProgressProvider(leagueId),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          seasonAsync.when(
            data: (season) {
              final startDate = season?.startDate;
              final endDate = season?.endDate;
              final hasSeasonDates = startDate != null && endDate != null;

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
                                  child: Image(
                                    image: appCachedImageProvider(logoUrl),
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Icon(
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
                              if (season != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  season.seasonName,
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
                    const SizedBox(height: 16),
                    if (season == null)
                      HomeSectionEmptyState(
                        embedded: true,
                        compact: true,
                        message: showOwnerActions
                            ? 'Create a season to organize fixtures and track progress for this league.'
                            : 'This league has not started a season yet.',
                        actionLabel:
                            showOwnerActions ? 'Go to Seasons' : null,
                        actionIcon: Icons.calendar_today_outlined,
                        onAction: showOwnerActions ? onOpenSeasonsTab : null,
                      )
                    else ...[
                      Text(
                        'Season progress',
                        style: textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      fixtureProgressAsync.when(
                        data: (fx) {
                          final total = fx?.totalCount ?? 0;
                          final played = fx?.playedCount ?? 0;
                          final value = total > 0
                              ? (played / total).clamp(0.0, 1.0)
                              : 0.0;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              LinearProgressIndicator(
                                year2023: false,
                                value: total > 0 ? value : 0,
                                backgroundColor:
                                    colorScheme.surfaceContainerHighest,
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              const SizedBox(height: 8),
                              if (total > 0)
                                Text(
                                  '$played / $total matches played',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                )
                              else
                                HomeSectionEmptyState(
                                  embedded: true,
                                  compact: true,
                                  message: showOwnerActions
                                      ? 'Schedule fixtures for this season to start tracking match progress.'
                                      : 'No fixtures have been scheduled for this season yet.',
                                  actionLabel: showOwnerActions
                                      ? 'Create match'
                                      : null,
                                  actionIcon: Icons.add,
                                  onAction: showOwnerActions
                                      ? onCreateMatch
                                      : null,
                                  secondaryActionLabel: showOwnerActions
                                      ? 'View matches'
                                      : null,
                                  onSecondaryAction: showOwnerActions
                                      ? onOpenMatchesTab
                                      : null,
                                ),
                              if (hasSeasonDates) ...[
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
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
                            ],
                          );
                        },
                        loading: () => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            LinearProgressIndicator(
                              year2023: false,
                              backgroundColor:
                                  colorScheme.surfaceContainerHighest,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Loading fixtures…',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        error: (_, _) => const HomeSectionEmptyState(
                          embedded: true,
                          compact: true,
                          message:
                              'Could not load fixture progress. Pull to refresh the league page.',
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
            loading: () => Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => _LeagueOverviewSectionCard(
              title: leagueName,
              child: const HomeSectionEmptyState(
                embedded: true,
                message:
                    'Could not load season details. Pull to refresh and try again.',
              ),
            ),
          ),
          const SizedBox(height: 16),
          _PlayerOfSeasonSection(
            leagueId: league['id'] as String? ?? '',
            onOpenPlayerStatsTab: onOpenPlayerStatsTab,
          ),
          const SizedBox(height: 16),
          _TeamOfTheWeekSection(
            leagueId: league['id'] as String? ?? '',
            onOpenMatchesTab: onOpenMatchesTab,
            showOwnerActions: showOwnerActions,
            onCreateMatch: onCreateMatch,
          ),
          const SizedBox(height: 16),
          _FeaturedMatchSection(
            leagueId: league['id'] as String? ?? '',
            onOpenMatchesTab: onOpenMatchesTab,
            showOwnerActions: showOwnerActions,
            onCreateMatch: onCreateMatch,
          ),
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
  const _PlayerOfSeasonSection({
    required this.leagueId,
    required this.onOpenPlayerStatsTab,
  });

  final String leagueId;
  final VoidCallback onOpenPlayerStatsTab;

  static void _showRaceInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Player of the Season race'),
        content: const SingleChildScrollView(
          child: Text(
            'This preview ranks players by average match rating across league '
            'fixtures that have player stats. Only appearances with a rating '
            'above zero count toward the average.\n\n'
            'Open the Player stats tab for the full leaderboard, filters, and '
            'more detail.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

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
          return _LeagueOverviewSectionCard(
            header: Row(
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
                IconButton(
                  tooltip: 'About this section',
                  onPressed: () => _showRaceInfo(context),
                  icon: Icon(
                    Icons.info_outline,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
              ],
            ),
            child: HomeSectionEmptyState(
              embedded: true,
              message:
                  'Rankings appear once players earn match ratings in finished league fixtures.',
              actionLabel: 'View player stats',
              actionIcon: Icons.leaderboard_outlined,
              onAction: onOpenPlayerStatsTab,
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
                  IconButton(
                    tooltip: 'About this section',
                    onPressed: () => _showRaceInfo(context),
                    icon: Icon(
                      Icons.info_outline,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
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
                  padding: EdgeInsets.only(
                    bottom: i < players.length - 1 ? 12 : 0,
                  ),
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
                                Container(
                                  width: 18,
                                  height: 18,
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: colorScheme.outlineVariant,
                                      width: 1,
                                    ),
                                  ),
                                  child: ClipOval(
                                    child:
                                        teamLogo != null &&
                                            _isValidUrl(teamLogo)
                                        ? Image(
                                            image: appCachedImageProvider(teamLogo),
                                            width: 18,
                                            height: 18,
                                            fit: BoxFit.cover,
                                          )
                                        : Icon(
                                            Icons.groups_2_rounded,
                                            size: 12,
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
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.primaryContainer.withValues(
                                alpha: 0.96,
                              ),
                              colorScheme.primaryContainer.withValues(
                                alpha: 0.9,
                              ),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.55,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.shadow.withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 15,
                              color: const Color(0xFFF4B400),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              avgRating.toStringAsFixed(2),
                              style: textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onPrimaryContainer,
                                letterSpacing: 0.2,
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
                  onPressed: onOpenPlayerStatsTab,
                  icon: Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: colorScheme.primary,
                  ),
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
        backgroundColor: colorScheme.surfaceContainerHighest,
        child: Icon(Icons.person, color: colorScheme.onSurfaceVariant),
      );
    }
    final url = imageUrl!;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return CircleAvatar(
        backgroundColor: colorScheme.surfaceContainerHighest,
        backgroundImage: appCachedImageProvider(url),
      );
    }
    return CircleAvatar(
      backgroundColor: colorScheme.surfaceContainerHighest,
      backgroundImage: AssetImage(url),
    );
  }
}

class _TeamOfTheWeekSection extends StatefulWidget {
  const _TeamOfTheWeekSection({
    required this.leagueId,
    required this.onOpenMatchesTab,
    this.showOwnerActions = false,
    required this.onCreateMatch,
  });

  final String leagueId;
  final VoidCallback onOpenMatchesTab;
  final bool showOwnerActions;
  final VoidCallback onCreateMatch;

  @override
  State<_TeamOfTheWeekSection> createState() => _TeamOfTheWeekSectionState();
}

class _TeamOfTheWeekSectionState extends State<_TeamOfTheWeekSection> {
  Map<String, List<Map<String, dynamic>>>? _data;
  bool _loading = true;
  RealtimeChannel? _matchesChannel;

  @override
  void initState() {
    super.initState();
    _fetch();
    _subscribeToMatchUpdates();
  }

  @override
  void dispose() {
    final ch = _matchesChannel;
    if (ch != null) {
      Supabase.instance.client.removeChannel(ch);
    }
    super.dispose();
  }

  Future<void> _fetch() async {
    if (widget.leagueId.isEmpty) {
      if (mounted) {
        setState(() {
          _data = {};
          _loading = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _loading = true);
    try {
      final d = await LeaguesRepository().getTeamOfTheWeek(widget.leagueId);
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _data = {};
        _loading = false;
      });
    }
  }

  void _subscribeToMatchUpdates() {
    if (widget.leagueId.isEmpty) return;
    final channel = Supabase.instance.client
        .channel('league_totw_${widget.leagueId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'matches',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'league_id',
            value: widget.leagueId,
          ),
          callback: (_) {
            if (mounted) _fetch();
          },
        );
    channel.subscribe();
    _matchesChannel = channel;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final data = _data ?? {};
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
                Icon(Icons.star_rounded, color: colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                Text('Team of the Week', style: textTheme.titleSmall),
              ],
            ),
          ),
          if (!hasPlayers)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
              child: HomeSectionEmptyState(
                embedded: true,
                message:
                    'The best-rated lineup from recent gameweeks will show on the pitch once matches have player stats.',
                actionLabel: widget.showOwnerActions
                    ? 'Create match'
                    : 'View matches',
                actionIcon: widget.showOwnerActions
                    ? Icons.add
                    : Icons.sports_soccer_outlined,
                onAction: widget.showOwnerActions
                    ? widget.onCreateMatch
                    : widget.onOpenMatchesTab,
                secondaryActionLabel:
                    widget.showOwnerActions ? 'View matches' : null,
                onSecondaryAction:
                    widget.showOwnerActions ? widget.onOpenMatchesTab : null,
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
            } else if (rating is String)
              ratingVal = double.tryParse(rating) ?? 0;

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

  /// Same as [TeamPlayer] footprint; rating sits top-right over the card.
  static const double kMarkerWidth = 60;
  static const double kMarkerHeight = 60;

  final String name;
  final String imageAsset;
  final double rating;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: kMarkerWidth,
      height: kMarkerHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          TeamPlayer(name: name, imageAsset: imageAsset),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.12),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
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
  const _FeaturedMatchSection({
    required this.leagueId,
    required this.onOpenMatchesTab,
    this.showOwnerActions = false,
    required this.onCreateMatch,
  });

  final String leagueId;
  final VoidCallback onOpenMatchesTab;
  final bool showOwnerActions;
  final VoidCallback onCreateMatch;

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

  static const _dayAbbr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  String _formatDate(DateTime d) =>
      '${_dayAbbr[d.weekday - 1]} ${d.day} ${_monthAbbr[d.month - 1]}';

  Future<MatchModel?> _fetchFeaturedMatch() async {
    final repo = MatchesRepository();
    final next = await repo.getNextUpcomingMatch(leagueIds: [leagueId]);
    if (next != null) return next;
    final recent = await repo.getRecentCompletedMatches(
      leagueIds: [leagueId],
      limit: 1,
    );
    return recent.isEmpty ? null : recent.first;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return FutureBuilder<MatchModel?>(
      future: _fetchFeaturedMatch(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _LeagueOverviewSectionCard(
            title: 'Featured match',
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
        final match = snapshot.data;
        if (match == null) {
          return _LeagueOverviewSectionCard(
            title: 'Featured match',
            child: HomeSectionEmptyState(
              embedded: true,
              message: showOwnerActions
                  ? 'Highlight a fixture here once you schedule matches for this league.'
                  : 'No league matches to feature yet.',
              actionLabel: showOwnerActions ? 'Create match' : 'View matches',
              actionIcon:
                  showOwnerActions ? Icons.add : Icons.sports_soccer_outlined,
              onAction: showOwnerActions ? onCreateMatch : onOpenMatchesTab,
              secondaryActionLabel:
                  showOwnerActions ? 'View matches' : null,
              onSecondaryAction:
                  showOwnerActions ? onOpenMatchesTab : null,
            ),
          );
        }

        final isFinished = match.status == MatchStatus.fullTime;
        final isLive =
            match.status == MatchStatus.ongoing ||
            match.status == MatchStatus.halfTime;

        final logoA = match.teamA.logoPath;
        final logoB = match.teamB.logoPath;
        final isNetworkA =
            logoA.startsWith('http://') || logoA.startsWith('https://');
        final isNetworkB =
            logoB.startsWith('http://') || logoB.startsWith('https://');

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
                            backgroundColor:
                                colorScheme.surfaceContainerHighest,
                            backgroundImage: isNetworkA
                                ? appCachedImageProvider(logoA)
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
                            backgroundColor:
                                colorScheme.surfaceContainerHighest,
                            backgroundImage: isNetworkB
                                ? appCachedImageProvider(logoB)
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

class _LeagueTeamStatsTab extends ConsumerStatefulWidget {
  const _LeagueTeamStatsTab({required this.leagueId});

  final String leagueId;

  @override
  ConsumerState<_LeagueTeamStatsTab> createState() =>
      _LeagueTeamStatsTabState();
}

class _LeagueTeamStatsTabState extends ConsumerState<_LeagueTeamStatsTab> {
  List<Map<String, dynamic>>? _stats;
  bool _isLoading = true;
  String? _error;
  String _selectedSeasonId = '';

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
      final data = await LeaguesRepository().getLeagueTeamStatsFiltered(
        widget.leagueId,
        seasonId: _selectedSeasonId.isEmpty ? null : _selectedSeasonId,
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

  List<Map<String, dynamic>> _allTopTeams(
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
    final textTheme = Theme.of(context).textTheme;

    final seasons =
        ref.watch(allSeasonsForLeagueProvider(widget.leagueId)).value ?? [];

    final seasonDropdown = DropdownMenu<String>(
      key: ValueKey<String>(
        'league_team_stats_season_${widget.leagueId}_'
        '${_selectedSeasonId}_${seasons.length}',
      ),
      initialSelection: _selectedSeasonId,
      label: const Text('Season'),
      expandedInsets: EdgeInsets.zero,
      dropdownMenuEntries: [
        const DropdownMenuEntry<String>(value: '', label: 'All seasons'),
        ...seasons.map(
          (s) => DropdownMenuEntry<String>(
            value: s.id,
            label: _leagueDetailSeasonMenuLabel(s.seasonName),
          ),
        ),
      ],
      onSelected: (value) {
        if (value == null) return;
        setState(() => _selectedSeasonId = value);
        _load();
      },
    );

    if (_isLoading) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            seasonDropdown,
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
        ),
      );
    }
    if (_error != null) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            seasonDropdown,
            const SizedBox(height: 24),
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
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            seasonDropdown,
            const SizedBox(height: 24),
            Center(
              child: AppEmptyState(
                imageAsset: AppAssets.noStatsEmpty,
                title: 'No team stats yet',
                subtitle:
                    'Team stats will appear once matches are played in this league.',
              ),
            ),
          ],
        ),
      );
    }

    final sections = <_StatSectionData>[
      _StatSectionData(
        title: 'Goals per match',
        teams: _topTeams((r) => _perMatch(r, 'total_goals')),
        allTeams: _allTopTeams((r) => _perMatch(r, 'total_goals')),
        format: (r) => _perMatch(r, 'total_goals').toStringAsFixed(1),
      ),
      _StatSectionData(
        title: 'Goals conceded per match',
        teams: _topTeams((r) => _perMatch(r, 'total_conceded')),
        allTeams: _allTopTeams((r) => _perMatch(r, 'total_conceded')),
        format: (r) => _perMatch(r, 'total_conceded').toStringAsFixed(1),
      ),
      _StatSectionData(
        title: 'Clean sheets',
        teams: _topTeams((r) => (r['clean_sheets'] as num?)?.toDouble() ?? 0),
        allTeams: _allTopTeams(
          (r) => (r['clean_sheets'] as num?)?.toDouble() ?? 0,
        ),
        format: (r) => (r['clean_sheets'] ?? 0).toString(),
      ),
      _StatSectionData(
        title: 'Shots on target per match',
        teams: _topTeams((r) => _perMatch(r, 'shots_on_target')),
        allTeams: _allTopTeams((r) => _perMatch(r, 'shots_on_target')),
        format: (r) => _perMatch(r, 'shots_on_target').toStringAsFixed(1),
      ),
      _StatSectionData(
        title: 'Tackles per match',
        teams: _topTeams((r) => _perMatch(r, 'total_tackles')),
        allTeams: _allTopTeams((r) => _perMatch(r, 'total_tackles')),
        format: (r) => _perMatch(r, 'total_tackles').toStringAsFixed(1),
      ),
      _StatSectionData(
        title: 'Saves per match',
        teams: _topTeams((r) => _perMatch(r, 'total_saves')),
        allTeams: _allTopTeams((r) => _perMatch(r, 'total_saves')),
        format: (r) => _perMatch(r, 'total_saves').toStringAsFixed(1),
      ),
      _StatSectionData(
        title: 'Yellow cards',
        teams: _topTeams(
          (r) => (r['total_yellow_cards'] as num?)?.toDouble() ?? 0,
        ),
        allTeams: _allTopTeams(
          (r) => (r['total_yellow_cards'] as num?)?.toDouble() ?? 0,
        ),
        format: (r) => (r['total_yellow_cards'] ?? 0).toString(),
      ),
      _StatSectionData(
        title: 'Red cards',
        teams: _topTeams(
          (r) => (r['total_red_cards'] as num?)?.toDouble() ?? 0,
        ),
        allTeams: _allTopTeams(
          (r) => (r['total_red_cards'] as num?)?.toDouble() ?? 0,
        ),
        format: (r) => (r['total_red_cards'] ?? 0).toString(),
      ),
    ];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          seasonDropdown,
          const SizedBox(height: 16),
          for (int i = 0; i < sections.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _StatSectionCard(section: sections[i]),
          ],
        ],
      ),
    );
  }
}

class _StatSectionData {
  const _StatSectionData({
    required this.title,
    required this.teams,
    required this.allTeams,
    required this.format,
  });

  final String title;
  final List<Map<String, dynamic>> teams;
  final List<Map<String, dynamic>> allTeams;
  final String Function(Map<String, dynamic>) format;
}

class _StatSectionCard extends StatelessWidget {
  const _StatSectionCard({required this.section});

  final _StatSectionData section;

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
          child: _LeagueTeamStatsFullSheet(
            section: section,
            resolveLogoPath: _resolveLogoPath,
            onTeamTap: (teamId) {
              nav.pop();
              nav.push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => TeamDetailPage(teamId: teamId),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _resolveLogoPath(String raw) {
    return resolveTeamLogoPath(raw) ?? '';
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
          InkWell(
            onTap: section.allTeams.isEmpty
                ? null
                : () => _openFullList(context),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(section.title, style: textTheme.titleSmall),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: section.allTeams.isEmpty
                        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
                        : colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
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
            backgroundColor: colorScheme.surfaceContainerHighest,
            child: Icon(
              Icons.groups,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
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

class _LeagueTeamStatsFullSheet extends StatelessWidget {
  const _LeagueTeamStatsFullSheet({
    required this.section,
    required this.resolveLogoPath,
    required this.onTeamTap,
  });

  final _StatSectionData section;
  final String Function(String raw) resolveLogoPath;
  final void Function(String teamId) onTeamTap;

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
                '${section.allTeams.length} teams Â· ranked by ${section.title.toLowerCase()}',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: section.allTeams.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                ),
                itemBuilder: (context, index) {
                  final rank = index + 1;
                  final row = section.allTeams[index];
                  final shortForm = row['team_short_form']?.toString() ?? '—';
                  final logoRaw = row['team_logo']?.toString() ?? '';
                  final logoPath = resolveLogoPath(logoRaw);
                  final value = section.format(row);
                  final teamId = row['team_id']?.toString() ?? '';

                  return InkWell(
                    onTap: teamId.isEmpty ? null : () => onTeamTap(teamId),
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
                          if (logoPath.isNotEmpty)
                            ClipOval(
                              child: _TeamStatsLogo(path: logoPath, size: 44),
                            )
                          else
                            CircleAvatar(
                              backgroundColor:
                                  colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.groups,
                                size: 22,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              shortForm,
                              style: textTheme.bodyLarge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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

class _TeamStatsLogo extends StatelessWidget {
  const _TeamStatsLogo({required this.path, this.size = 28});

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
// League Standings Tab
// ---------------------------------------------------------------------------

class _LeagueStandingsTab extends ConsumerStatefulWidget {
  const _LeagueStandingsTab({required this.leagueId});

  final String leagueId;

  @override
  ConsumerState<_LeagueStandingsTab> createState() =>
      _LeagueStandingsTabState();
}

class _LeagueStandingsTabState extends ConsumerState<_LeagueStandingsTab> {
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

  List<Map<String, dynamic>>? _standings;
  Set<String> _userTeamIds = {};
  bool _isLoading = true;
  String? _error;

  /// Empty string means all seasons (same convention as league matches tab).
  String _selectedSeasonId = '';

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

      final seasonArg = _selectedSeasonId.isEmpty ? null : _selectedSeasonId;

      // Fetch standings and user's team IDs in parallel.
      final results = await Future.wait([
        LeaguesRepository().getLeagueStandingsFiltered(
          widget.leagueId,
          seasonId: seasonArg,
        ),
        if (userId != null)
          _getUserTeamIds(supabase, userId)
        else
          Future.value(<String>{}),
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

    final standings = _standings ?? [];
    final seasons =
        ref.watch(allSeasonsForLeagueProvider(widget.leagueId)).value ?? [];

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownMenu<String>(
              key: ValueKey<String>(
                'league_standings_season_${widget.leagueId}_'
                '${_selectedSeasonId}_${seasons.length}',
              ),
              initialSelection: _selectedSeasonId,
              label: const Text('Season'),
              expandedInsets: EdgeInsets.zero,
              dropdownMenuEntries: [
                const DropdownMenuEntry<String>(
                  value: '',
                  label: 'All seasons',
                ),
                ...seasons.map(
                  (s) => DropdownMenuEntry<String>(
                    value: s.id,
                    label: _leagueDetailSeasonMenuLabel(s.seasonName),
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == null) return;
                setState(() => _selectedSeasonId = value);
                _load();
              },
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Could not load standings',
                      style: textTheme.bodyLarge,
                    ),
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
              )
            else if (standings.isEmpty)
              Center(
                child: AppEmptyState(
                  imageAsset: AppAssets.noStandingsEmpty,
                  title: 'No standings yet',
                  subtitle:
                      'The table will update once teams play matches in this league.',
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
    } else {
      logoPath = resolveTeamLogoPath(logoRaw) ?? '';
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

class _StandingsTeamLogo extends StatelessWidget {
  const _StandingsTeamLogo({required this.path, this.size = 24});

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
// League Matches Tab
// ---------------------------------------------------------------------------

class _LeagueMatchesTab extends ConsumerStatefulWidget {
  const _LeagueMatchesTab({
    required this.leagueId,
    this.showCreateMatchCta = false,
  });

  final String leagueId;
  final bool showCreateMatchCta;

  @override
  ConsumerState<_LeagueMatchesTab> createState() => _LeagueMatchesTabState();
}

class _LeagueMatchesTabState extends ConsumerState<_LeagueMatchesTab> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _dateGroupKeys = <String, GlobalKey>{};
  String? _selectedSeason;
  String? _selectedGameweek;
  String? _selectedTeam;
  DateTime? _requestedJumpDate;
  String? _lastHandledJumpDateKey;
  bool _showScrollToTop = false;

  List<SeasonModel> _seasons = [];
  List<Map<String, dynamic>> _gameweeks = [];
  List<TeamModel> _teams = [];
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
      final seasonsRepo = ref.read(seasonsRepositoryProvider);
      final seasons = await seasonsRepo.getSeasonsForLeagues([widget.leagueId]);
      List<Map<String, dynamic>> gameweeks = [];
      if (seasons.isNotEmpty) {
        gameweeks = await seasonsRepo.getGameweeksForSeasons(
          seasons.map((s) => s.id).toList(),
        );
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
        seasonIds: _selectedSeason != null ? [_selectedSeason!] : null,
        gameweek: _selectedGameweek,
        teamIds: _selectedTeam != null ? [_selectedTeam!] : null,
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

  Future<void> _onSeasonChanged(String? value) async {
    final v = (value?.isEmpty ?? true) ? null : value;
    setState(() {
      _selectedSeason = v;
      _selectedGameweek = null;
    });

    // Reload gameweeks for the new season selection.
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

  void _onTeamChanged(String? value) {
    setState(() => _selectedTeam = (value?.isEmpty ?? true) ? null : value);
    _loadMatches();
  }

  // Gameweek navigation
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
          onRefresh: () async {
            await _loadFilters();
          },
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
                              // Team filter
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: SizedBox(
                                  width: 130,
                                  child: DropdownMenu<String>(
                                    initialSelection: _selectedTeam ?? '',
                                    label: const Text('Teams'),
                                    dropdownMenuEntries: [
                                      const DropdownMenuEntry(
                                        value: '',
                                        label: 'All teams',
                                      ),
                                      ..._teams.map(
                                        (t) => DropdownMenuEntry(
                                          value: t.id,
                                          label: _truncate(t.displayName),
                                        ),
                                      ),
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
                heroTag: 'league-matches-scroll-top',
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
      _selectedSeason != null ||
      _selectedGameweek != null ||
      _selectedTeam != null;

  void _clearFilters() {
    setState(() {
      _selectedSeason = null;
      _selectedGameweek = null;
      _selectedTeam = null;
    });
    _loadMatches();
  }

  void _openCreateMatch() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LeagueCreateMatchesPage(leagueId: widget.leagueId),
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
                            child: _LeagueMatchTeamLogo(
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
                            child: _LeagueMatchTeamLogo(
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

class _LeagueMatchTeamLogo extends StatelessWidget {
  const _LeagueMatchTeamLogo({required this.path, this.size = 28});

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
// Player stats tab
// ---------------------------------------------------------------------------

class _LeaguePlayerStatsTab extends ConsumerStatefulWidget {
  const _LeaguePlayerStatsTab({required this.leagueId});

  final String leagueId;

  @override
  ConsumerState<_LeaguePlayerStatsTab> createState() =>
      _LeaguePlayerStatsTabState();
}

class _LeaguePlayerStatsTabState extends ConsumerState<_LeaguePlayerStatsTab> {
  List<Map<String, dynamic>>? _stats;
  bool _isLoading = true;
  String? _error;
  String _selectedSeasonId = '';

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
      final data = await LeaguesRepository().getLeaguePlayerStatsFiltered(
        widget.leagueId,
        seasonId: _selectedSeasonId.isEmpty ? null : _selectedSeasonId,
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
    final textTheme = Theme.of(context).textTheme;
    final seasons =
        ref.watch(allSeasonsForLeagueProvider(widget.leagueId)).value ?? [];

    final seasonDropdown = DropdownMenu<String>(
      key: ValueKey<String>(
        'league_player_stats_season_${widget.leagueId}_'
        '${_selectedSeasonId}_${seasons.length}',
      ),
      initialSelection: _selectedSeasonId,
      label: const Text('Season'),
      expandedInsets: EdgeInsets.zero,
      dropdownMenuEntries: [
        const DropdownMenuEntry<String>(value: '', label: 'All seasons'),
        ...seasons.map(
          (s) => DropdownMenuEntry<String>(
            value: s.id,
            label: _leagueDetailSeasonMenuLabel(s.seasonName),
          ),
        ),
      ],
      onSelected: (value) {
        if (value == null) return;
        setState(() => _selectedSeasonId = value);
        _load();
      },
    );

    if (_isLoading) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            seasonDropdown,
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
        ),
      );
    }
    if (_error != null) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            seasonDropdown,
            const SizedBox(height: 24),
            Text('Could not load player stats', style: textTheme.bodyLarge),
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
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            seasonDropdown,
            const SizedBox(height: 24),
            Center(
              child: AppEmptyState(
                imageAsset: AppAssets.noStatsEmpty,
                title: 'No player stats yet',
                subtitle:
                    'Player stats will appear once matches are played in this league.',
              ),
            ),
          ],
        ),
      );
    }

    final sections = <_PlayerStatSectionData>[
      _PlayerStatSectionData(
        title: 'Top scorer',
        players: _topPlayers(
          (r) => (r['total_goals'] as num?)?.toDouble() ?? 0,
        ),
        allPlayers: _allTopPlayers(
          (r) => (r['total_goals'] as num?)?.toDouble() ?? 0,
        ),
        format: (r) => (r['total_goals'] ?? 0).toString(),
      ),
      _PlayerStatSectionData(
        title: 'Assists',
        players: _topPlayers(
          (r) => (r['total_assists'] as num?)?.toDouble() ?? 0,
        ),
        allPlayers: _allTopPlayers(
          (r) => (r['total_assists'] as num?)?.toDouble() ?? 0,
        ),
        format: (r) => (r['total_assists'] ?? 0).toString(),
      ),
      _PlayerStatSectionData(
        title: 'Goals + Assists',
        players: _topPlayers(
          (r) => (r['goals_assists'] as num?)?.toDouble() ?? 0,
        ),
        allPlayers: _allTopPlayers(
          (r) => (r['goals_assists'] as num?)?.toDouble() ?? 0,
        ),
        format: (r) => (r['goals_assists'] ?? 0).toString(),
      ),
      _PlayerStatSectionData(
        title: 'Saves',
        players: _topPlayers(
          (r) => (r['total_saves'] as num?)?.toDouble() ?? 0,
        ),
        allPlayers: _allTopPlayers(
          (r) => (r['total_saves'] as num?)?.toDouble() ?? 0,
        ),
        format: (r) => (r['total_saves'] ?? 0).toString(),
      ),
      _PlayerStatSectionData(
        title: 'Yellow cards',
        players: _topPlayers(
          (r) => (r['total_yellow_cards'] as num?)?.toDouble() ?? 0,
        ),
        allPlayers: _allTopPlayers(
          (r) => (r['total_yellow_cards'] as num?)?.toDouble() ?? 0,
        ),
        format: (r) => (r['total_yellow_cards'] ?? 0).toString(),
      ),
      _PlayerStatSectionData(
        title: 'Red cards',
        players: _topPlayers(
          (r) => (r['total_red_cards'] as num?)?.toDouble() ?? 0,
        ),
        allPlayers: _allTopPlayers(
          (r) => (r['total_red_cards'] as num?)?.toDouble() ?? 0,
        ),
        format: (r) => (r['total_red_cards'] ?? 0).toString(),
      ),
      _PlayerStatSectionData(
        title: 'Tackles',
        players: _topPlayers(
          (r) => (r['total_tackles'] as num?)?.toDouble() ?? 0,
        ),
        allPlayers: _allTopPlayers(
          (r) => (r['total_tackles'] as num?)?.toDouble() ?? 0,
        ),
        format: (r) => (r['total_tackles'] ?? 0).toString(),
      ),
      _PlayerStatSectionData(
        title: 'Missed opportunities',
        players: _topPlayers(
          (r) => (r['missed_opportunities'] as num?)?.toDouble() ?? 0,
        ),
        allPlayers: _allTopPlayers(
          (r) => (r['missed_opportunities'] as num?)?.toDouble() ?? 0,
        ),
        format: (r) => (r['missed_opportunities'] ?? 0).toString(),
      ),
      _PlayerStatSectionData(
        title: 'Ballo rating',
        players: _topPlayers((r) => (r['avg_rating'] as num?)?.toDouble() ?? 0),
        allPlayers: _allTopPlayers(
          (r) => (r['avg_rating'] as num?)?.toDouble() ?? 0,
        ),
        format: (r) =>
            ((r['avg_rating'] as num?)?.toDouble() ?? 0).toStringAsFixed(2),
      ),
      _PlayerStatSectionData(
        title: 'Shots on target',
        players: _topPlayers(
          (r) => (r['total_shots_on_target'] as num?)?.toDouble() ?? 0,
        ),
        allPlayers: _allTopPlayers(
          (r) => (r['total_shots_on_target'] as num?)?.toDouble() ?? 0,
        ),
        format: (r) => (r['total_shots_on_target'] ?? 0).toString(),
      ),
      _PlayerStatSectionData(
        title: 'Goals per match',
        players: _topPlayers((r) => _perMatch(r, 'total_goals')),
        allPlayers: _allTopPlayers((r) => _perMatch(r, 'total_goals')),
        format: (r) => _perMatch(r, 'total_goals').toStringAsFixed(1),
      ),
      _PlayerStatSectionData(
        title: 'Shots per match',
        players: _topPlayers((r) => _perMatch(r, 'total_shots')),
        allPlayers: _allTopPlayers((r) => _perMatch(r, 'total_shots')),
        format: (r) => _perMatch(r, 'total_shots').toStringAsFixed(1),
      ),
      _PlayerStatSectionData(
        title: 'Saves per match',
        players: _topPlayers((r) => _perMatch(r, 'total_saves')),
        allPlayers: _allTopPlayers((r) => _perMatch(r, 'total_saves')),
        format: (r) => _perMatch(r, 'total_saves').toStringAsFixed(1),
      ),
    ];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          seasonDropdown,
          const SizedBox(height: 16),
          for (int i = 0; i < sections.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _PlayerStatSectionCard(section: sections[i]),
          ],
        ],
      ),
    );
  }
}

class _PlayerStatSectionData {
  const _PlayerStatSectionData({
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

class _PlayerStatSectionCard extends StatelessWidget {
  const _PlayerStatSectionCard({required this.section});

  final _PlayerStatSectionData section;

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
          child: _LeaguePlayerStatsFullSheet(
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

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: section.allPlayers.isEmpty
                ? null
                : () => _openFullList(context),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(section.title, style: textTheme.titleSmall),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: section.allPlayers.isEmpty
                        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
                        : colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
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
    final value = section.format(row);
    final isTop = index == 0;

    return Row(
      children: [
        _PlayerStatsAvatar(imageUrl: imageUrl, radius: 18),
        const SizedBox(width: 12),
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

class _LeaguePlayerStatsFullSheet extends StatelessWidget {
  const _LeaguePlayerStatsFullSheet({
    required this.section,
    required this.onPlayerTap,
  });

  final _PlayerStatSectionData section;
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
                  final teamShort = row['team_short_form']?.toString() ?? '';
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
                          _PlayerStatsAvatar(imageUrl: imageUrl, radius: 22),
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
                                if (teamShort.isNotEmpty)
                                  Text(
                                    teamShort,
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

class _PlayerStatsAvatar extends StatelessWidget {
  const _PlayerStatsAvatar({required this.imageUrl, this.radius = 18});

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
  static const int _videosPageSize = 24;

  List<LeagueVideoItem>? _videos;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
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
      final rawVideos = await LeaguesRepository().getLeagueVideos(
        widget.leagueId,
        limit: _videosPageSize,
        offset: 0,
      );
      if (!mounted) return;
      final enriched = await _enrichVideos(rawVideos);
      if (!mounted) return;
      setState(() {
        _videos = enriched;
        _hasMore = rawVideos.length >= _videosPageSize;
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
      final rawVideos = await LeaguesRepository().getLeagueVideos(
        widget.leagueId,
        limit: _videosPageSize,
        offset: _videos?.length ?? 0,
      );
      if (!mounted) return;
      final enriched = await _enrichVideos(rawVideos);
      if (!mounted) return;
      setState(() {
        final existing = {for (final v in _videos ?? <LeagueVideoItem>[]) v.videoId};
        _videos = [
          ...?_videos,
          ...enriched.where((v) => !existing.contains(v.videoId)),
        ];
        _hasMore = rawVideos.length >= _videosPageSize;
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
          .select('id, player_name, image_url, deleted_at')
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
            uploader['deleted_at'] == null &&
            uploaderUserId != null &&
            followsSet.contains(uploaderUserId),
        isUploaderDeleted: uploader['deleted_at'] != null,
        viewCount: viewCountMap[vid] ?? 0,
      );
    }).toList();
  }

  static String _resolveVideoLogoPath(String? raw) {
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
      case _VideoSortOrder.newest:
        list.sort(
          (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
            a.createdAt ?? DateTime(0),
          ),
        );
      case _VideoSortOrder.oldest:
        list.sort(
          (a, b) => (a.createdAt ?? DateTime(0)).compareTo(
            b.createdAt ?? DateTime(0),
          ),
        );
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

          // Content
          if (sorted.isEmpty)
            Expanded(
              child: Center(
                child: AppEmptyState(
                  imageAsset: AppAssets.videosAltEmpty,
                  title: 'No videos yet',
                  subtitle:
                      'Highlights uploaded from league matches will appear here.',
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
                // Match info header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      _FeedTeamLogo(logoPath: v.teamALogo, size: 24),
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
                      _FeedTeamLogo(logoPath: v.teamBLogo, size: 24),
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

class _FeedTeamLogo extends StatelessWidget {
  const _FeedTeamLogo({required this.logoPath, this.size = 24});
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

class _FeedPosterAvatar extends StatelessWidget {
  const _FeedPosterAvatar({this.avatarUrl, required this.name});
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

class _LeagueOwnerSettingsPage extends StatefulWidget {
  const _LeagueOwnerSettingsPage({
    required this.leagueId,
    required this.initialLeagueName,
    this.initialLogoUrl,
    this.initialDefaultVenueImageUrl,
    this.initialCountry,
    this.initialSocialInstagram,
    this.initialSocialTiktok,
    this.initialSocialX,
  });

  final String leagueId;
  final String initialLeagueName;
  final String? initialLogoUrl;
  final String? initialDefaultVenueImageUrl;
  final String? initialCountry;
  final String? initialSocialInstagram;
  final String? initialSocialTiktok;
  final String? initialSocialX;

  @override
  State<_LeagueOwnerSettingsPage> createState() =>
      _LeagueOwnerSettingsPageState();
}

class _LeagueOwnerSettingsPageState extends State<_LeagueOwnerSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _socialInstagramController = TextEditingController();
  final _socialTiktokController = TextEditingController();
  final _socialXController = TextEditingController();
  final _picker = ImagePicker();
  bool _isSaving = false;
  bool _isUploadingLogo = false;
  bool _isUploadingBackground = false;
  String? _logoUrl;
  String? _defaultBackgroundUrl;
  String? _countryCode;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialLeagueName;
    _logoUrl = widget.initialLogoUrl;
    _defaultBackgroundUrl = widget.initialDefaultVenueImageUrl;
    _countryCode = widget.initialCountry;
    _socialInstagramController.text = widget.initialSocialInstagram ?? '';
    _socialTiktokController.text = widget.initialSocialTiktok ?? '';
    _socialXController.text = widget.initialSocialX ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _socialInstagramController.dispose();
    _socialTiktokController.dispose();
    _socialXController.dispose();
    super.dispose();
  }

  Future<String?> _uploadImage({
    required ImageSource source,
    required String folderName,
  }) async {
    final image = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
      maxHeight: 1200,
    );
    if (image == null) return null;
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return null;
    final fileName =
        '${user.id}_${DateTime.now().millisecondsSinceEpoch}${path.extension(image.path)}';
    final filePath = '$folderName/$fileName';
    final bytes = await image.readAsBytes();
    await requireAllowedImage(
      bytes,
      contentRef: 'image:$folderName',
    );
    await supabase.storage.from('Profile images').uploadBinary(filePath, bytes);
    return supabase.storage.from('Profile images').getPublicUrl(filePath);
  }

  Future<void> _pickForField({required bool isLogo}) async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isLogo ? 'Select league logo' : 'Select default match background',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    if (!mounted) return;
    if (!await ensureMediaAccessForImageSource(context, source)) return;
    setState(() {
      if (isLogo) {
        _isUploadingLogo = true;
      } else {
        _isUploadingBackground = true;
      }
    });
    try {
      final url = await _uploadImage(
        source: source,
        folderName: isLogo ? 'league logos' : 'venue images',
      );
      if (!mounted) return;
      if (url == null || url.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not upload image')));
      } else {
        setState(() {
          if (isLogo) {
            _logoUrl = url;
          } else {
            _defaultBackgroundUrl = url;
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (await presentMediaAccessSheetIfNeeded(
        context,
        e,
        mediaAccessKindForImageSource(source),
      )) {
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Image upload failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          if (isLogo) {
            _isUploadingLogo = false;
          } else {
            _isUploadingBackground = false;
          }
        });
      }
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    try {
      final leagueName = _nameController.text.trim();
      final nameBlock = UsernameRules.offensiveContentError(leagueName);
      if (nameBlock != null) {
        throw StateError(nameBlock);
      }
      await requireAllowedText(leagueName, contentRef: 'league_name');

      await LeaguesRepository().updateLeague(
        widget.leagueId,
        leagueName: leagueName,
        logoId: _logoUrl,
        defaultVenueImageUrl: _defaultBackgroundUrl,
        country: _countryCode,
        socialInstagram: _trimOrNull(_socialInstagramController.text),
        socialTiktok: _trimOrNull(_socialTiktokController.text),
        socialX: _trimOrNull(_socialXController.text),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('League details updated')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating league: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit league details'),
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'League name'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Enter a league name'
                  : null,
            ),
            const SizedBox(height: 16),
            FormField<String>(
              validator: (_) {
                if (_countryCode == null || _countryCode!.isEmpty) {
                  return 'Select a country';
                }
                return null;
              },
              builder: (state) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CountryPickerSection(
                      selectedCountryCode: _countryCode,
                      maxListHeight: 220,
                      onCountrySelected: (code) {
                        setState(() => _countryCode = code);
                        state.didChange(code);
                      },
                    ),
                    if (state.hasError) ...[
                      const SizedBox(height: 8),
                      Text(
                        state.errorText!,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Text('League logo', style: textTheme.labelLarge),
            const SizedBox(height: 8),
            ImageUploadCard(
              imageUrl: _logoUrl,
              isUploading: _isUploadingLogo,
              emptyLabel: 'Tap to upload league logo',
              isCircular: true,
              onTap: () => _pickForField(isLogo: true),
              onClear: _logoUrl == null
                  ? null
                  : () => setState(() => _logoUrl = null),
            ),
            const SizedBox(height: 16),
            Text('Default match background', style: textTheme.labelLarge),
            const SizedBox(height: 8),
            ImageUploadCard(
              imageUrl: _defaultBackgroundUrl,
              isUploading: _isUploadingBackground,
              emptyLabel: 'Set a default location background',
              emptySubtitle: 'Used for all matches in this league',
              overlayLabel: 'Default location background',
              onTap: () => _pickForField(isLogo: false),
              onClear: _defaultBackgroundUrl == null
                  ? null
                  : () => setState(() => _defaultBackgroundUrl = null),
            ),
            const SizedBox(height: 8),
            Text(
              'This image is used as the default fixture background for this league.',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Text('Social links (optional)', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Use full URLs starting with https://',
              style: textTheme.bodySmall?.copyWith(
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
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save changes'),
            ),
          ],
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

class _LeagueOwnerTeamsPage extends StatefulWidget {
  const _LeagueOwnerTeamsPage({required this.leagueId});

  final String leagueId;

  @override
  State<_LeagueOwnerTeamsPage> createState() => _LeagueOwnerTeamsPageState();
}

class _LeagueOwnerTeamsPageState extends State<_LeagueOwnerTeamsPage> {
  bool _isLoading = true;
  bool _changed = false;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final res = await supabase
          .from('league_team_memberships')
          .select('id, team_id, end_date, team:teams(id, team_name, logo_id)')
          .eq('league_id', widget.leagueId)
          .isFilter('end_date', null)
          .order('created_at', ascending: true);
      if (!mounted) return;
      setState(() {
        _rows = List<Map<String, dynamic>>.from(res as List);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading teams: $e')));
    }
  }

  Future<void> _kickOut(Map<String, dynamic> row) async {
    final team = row['team'] is Map
        ? Map<String, dynamic>.from(row['team'] as Map)
        : <String, dynamic>{};
    final teamName = team['team_name']?.toString() ?? 'this team';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kick out team'),
        content: Text('Remove $teamName from this league?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Kick out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final id = row['id']?.toString() ?? '';
      if (id.isEmpty) return;
      final today = DateTime.now().toIso8601String().split('T').first;
      await Supabase.instance.client
          .from('league_team_memberships')
          .update({'end_date': today})
          .eq('id', id);
      if (!mounted) return;
      _changed = true;
      await _load();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$teamName removed from league')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not remove team: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kick out teams'),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(_changed),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
          ? Center(
              child: Text(
                'No active teams to remove',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final row = _rows[i];
                final team = row['team'] is Map
                    ? Map<String, dynamic>.from(row['team'] as Map)
                    : <String, dynamic>{};
                final name = team['team_name']?.toString() ?? 'Unknown';
                final logo = team['logo_id']?.toString();
                return Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      backgroundImage:
                          logo != null &&
                              (logo.startsWith('http://') ||
                                  logo.startsWith('https://'))
                          ? appCachedImageProvider(logo)
                          : null,
                      child: logo == null
                          ? Icon(
                              Icons.groups_2_outlined,
                              color: colorScheme.onSurfaceVariant,
                            )
                          : null,
                    ),
                    title: Text(name, style: textTheme.titleSmall),
                    subtitle: Text(
                      'Active in league',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: FilledButton.tonalIcon(
                      onPressed: () => _kickOut(row),
                      icon: const Icon(Icons.person_remove_outlined, size: 18),
                      label: const Text('Kick out'),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _LeagueOwnerFixturesPage extends ConsumerStatefulWidget {
  const _LeagueOwnerFixturesPage({required this.leagueId});

  final String leagueId;

  @override
  ConsumerState<_LeagueOwnerFixturesPage> createState() =>
      _LeagueOwnerFixturesPageState();
}

class _LeagueOwnerFixturesPageState
    extends ConsumerState<_LeagueOwnerFixturesPage> {
  bool _loading = true;
  bool _changed = false;
  List<MatchModel> _matches = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final matches = await MatchesRepository().getMatches(
        leagueIds: [widget.leagueId],
      );
      if (!mounted) return;
      setState(() {
        _matches = matches;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading fixtures: $e')));
    }
  }

  Future<void> _deleteUpcoming(MatchModel match) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete upcoming fixture'),
        content: const Text('This removes the fixture permanently. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await Supabase.instance.client
          .from('matches')
          .delete()
          .eq('id', match.id);
      if (!mounted) return;
      _changed = true;
      ref.invalidate(matchesProvider);
      await _load();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Fixture deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete fixture: $e')));
    }
  }

  Future<void> _postponeUpcoming(MatchModel match) async {
    final parts = match.matchTime.split(':');
    final initialHour = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 15;
    final initialMinute = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: match.matchDate.isAfter(DateTime.now())
          ? match.matchDate
          : DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
    );
    if (pickedTime == null || !mounted) return;
    final date =
        '${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}';
    final time =
        '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';
    try {
      await Supabase.instance.client
          .from('matches')
          .update({'match_date': date, 'match_time': time})
          .eq('id', match.id);
      if (!mounted) return;
      _changed = true;
      ref.invalidate(matchesProvider);
      await _load();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Fixture postponed')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not postpone fixture: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit fixtures'),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(_changed),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _matches.isEmpty
          ? Center(
              child: Text(
                'No fixtures found',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _matches.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final m = _matches[i];
                final isUpcoming = m.status == MatchStatus.upcoming;
                final isEnded = m.status == MatchStatus.fullTime;
                final title = '${m.teamA.shortForm} vs ${m.teamB.shortForm}';
                final dateLabel =
                    '${m.matchDate.year}-${m.matchDate.month.toString().padLeft(2, '0')}-${m.matchDate.day.toString().padLeft(2, '0')}';
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: textTheme.titleSmall),
                                const SizedBox(height: 4),
                                Text(
                                  '$dateLabel • ${m.timeDisplay}',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              m.statusText,
                              style: textTheme.labelMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (isEnded)
                            FilledButton.tonal(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => FixturePage(matchId: m.id),
                                  ),
                                );
                              },
                              child: const Text('Correct stats'),
                            ),
                          if (isUpcoming) ...[
                            FilledButton.tonal(
                              onPressed: () => _postponeUpcoming(m),
                              child: const Text('Postpone'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.tonal(
                              onPressed: () => _deleteUpcoming(m),
                              style: FilledButton.styleFrom(
                                backgroundColor: colorScheme.errorContainer,
                                foregroundColor: colorScheme.onErrorContainer,
                              ),
                              child: const Text('Delete'),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
