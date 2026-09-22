import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_assets.dart';
import '../../core/utils/scroll_to_top.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/media_placeholders.dart';
import '../../core/constants/countries.dart';
import '../../data/repositories/leaderboard_repository.dart';
import '../../data/repositories/player_stats_repository.dart';
import '../../data/repositories/user_profile_repository.dart';
import '../../domain/models/player_badge.dart';
import '../../domain/models/player_year_team_stats.dart';
import '../../domain/models/user_profile.dart';
import 'edit_profile_page.dart';
import 'league_video_player_page.dart';
import '../../data/repositories/leagues_repository.dart';
import '../../data/repositories/matches_repository.dart';
import '../../data/repositories/teams_repository.dart';
import '../../domain/models/match_model.dart';
import '../../domain/models/season_model.dart';
import '../../domain/models/team_membership_stint.dart';
import '../../domain/models/team_model.dart';
import '../providers/main_nav_scroll_provider.dart';
import '../providers/match_timer_adapter_provider.dart';
import '../providers/matches_provider.dart';
import '../providers/match_video_seen_provider.dart';
import '../providers/seasons_provider.dart';
import '../providers/video_upload_queue_provider.dart';
import '../widgets/video_upload_progress_overlay.dart';
import '../widgets/socials_section_card.dart';
import '../widgets/performance_radar_chart.dart';
import '../widgets/profile/profile_page_shimmer.dart';
import '../widgets/app_search_page.dart';
import '../widgets/home/home_section_empty_state.dart';
import '../widgets/match_date_picker_dialog.dart';
import '../widgets/match_list_score_pill.dart';
import 'create_match_entry_page.dart';
import 'create_team_league_page.dart';
import 'fixture.dart';
import 'matches.dart' show DodecagonIndicator;

/// Profile tabs and scroll layout. When [viewedPlayerId] is null, shows the signed-in user.
class ProfileScrollView extends ConsumerStatefulWidget {
  const ProfileScrollView({
    super.key,
    this.viewedPlayerId,
    this.refreshTick = 0,
  });

  /// If null, the current auth user is shown (main Profile tab).
  final String? viewedPlayerId;
  final int refreshTick;

  @override
  ConsumerState<ProfileScrollView> createState() => _ProfileScrollViewState();
}

class _ProfileScrollViewState extends ConsumerState<ProfileScrollView>
    with SingleTickerProviderStateMixin {
  late final ScrollController _outerScrollController;
  late final TabController _tabController;
  late final bool _showMatchesTab;
  bool _isHeaderCollapsed = false;
  int _tabViewGeneration = 0;
  int _lastTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _showMatchesTab = true;
    _outerScrollController = ScrollController()
      ..addListener(_handleOuterScroll);
    _tabController = TabController(length: _showMatchesTab ? 5 : 4, vsync: this)
      ..addListener(_handleTabIndexChanged);
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

  @override
  Widget build(BuildContext context) {
    if (widget.viewedPlayerId == null) {
      ref.listen<int>(
        mainNavScrollToTopProvider.select((m) => m[MainNavTab.account] ?? 0),
        (previous, next) {
          if (previous == next) return;
          animateScrollControllerToTop(_outerScrollController);
        },
      );
    }

    final uid = Supabase.instance.client.auth.currentUser?.id;
    final effectiveId = widget.viewedPlayerId ?? uid;
    if (effectiveId == null || effectiveId.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Sign in to view your profile.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final isOwnProfile =
        widget.viewedPlayerId == null || widget.viewedPlayerId == uid;
    final colorScheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: _showMatchesTab ? 5 : 4,
      child: NestedScrollView(
        controller: _outerScrollController,
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return [
            SliverAppBar(
              pinned: true,
              primary: false,
              toolbarHeight: 0,
              expandedHeight: 240,
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
                    final currentExtent = settings?.currentExtent ?? maxExtent;
                    final collapseRange = (maxExtent - minExtent).clamp(
                      1.0,
                      double.infinity,
                    );
                    final t = ((currentExtent - minExtent) / collapseRange)
                        .clamp(0.0, 1.0);
                    // Keep a little opacity near collapsed state for smoother transition.
                    final fadeOpacity = (0.15 + (0.85 * t)).clamp(0.0, 1.0);
                    return Opacity(
                      opacity: fadeOpacity,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: _ProfileCard(
                          playerId: effectiveId,
                          showEditButton: isOwnProfile,
                          refreshTick: widget.refreshTick,
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
                    isScrollable: false,
                    tabAlignment: TabAlignment.fill,
                    labelPadding: EdgeInsets.zero,
                    indicatorPadding: EdgeInsets.zero,
                    dividerHeight: 0,
                    labelColor: colorScheme.onSurface,
                    unselectedLabelColor: colorScheme.onSurfaceVariant,
                    indicatorColor: colorScheme.primary,
                    indicatorWeight: 3,
                    dividerColor: Colors.transparent,
                    tabs: _showMatchesTab
                        ? const [
                            Tab(text: 'Overview'),
                            Tab(text: 'Matches'),
                            Tab(text: 'Stats'),
                            Tab(text: 'Career'),
                            Tab(text: 'Video'),
                          ]
                        : const [
                            Tab(text: 'Overview'),
                            Tab(text: 'Stats'),
                            Tab(text: 'Career'),
                            Tab(text: 'Video'),
                          ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: _showMatchesTab
              ? [
                  KeyedSubtree(
                    key: ValueKey('profile-tab-0-$_tabViewGeneration'),
                    child: _ProfileTabContent(
                      title: 'Overview',
                      profilePlayerId: effectiveId,
                      isOwnProfile: isOwnProfile,
                      onGoToMatchesTab: () => _tabController.animateTo(1),
                    ),
                  ),
                  KeyedSubtree(
                    key: ValueKey('profile-tab-1-$_tabViewGeneration'),
                    child: _ProfileTabContent(
                      title: 'Matches',
                      profilePlayerId: effectiveId,
                      isOwnProfile: isOwnProfile,
                    ),
                  ),
                  KeyedSubtree(
                    key: ValueKey('profile-tab-2-$_tabViewGeneration'),
                    child: _ProfileTabContent(
                      title: 'Stats',
                      profilePlayerId: effectiveId,
                      isOwnProfile: isOwnProfile,
                    ),
                  ),
                  KeyedSubtree(
                    key: ValueKey('profile-tab-3-$_tabViewGeneration'),
                    child: _ProfileTabContent(
                      title: 'Career',
                      profilePlayerId: effectiveId,
                      isOwnProfile: isOwnProfile,
                    ),
                  ),
                  KeyedSubtree(
                    key: ValueKey('profile-tab-4-$_tabViewGeneration'),
                    child: _ProfileTabContent(
                      title: 'Video',
                      profilePlayerId: effectiveId,
                      isOwnProfile: isOwnProfile,
                    ),
                  ),
                ]
              : [
                  KeyedSubtree(
                    key: ValueKey('profile-tab-0-$_tabViewGeneration'),
                    child: _ProfileTabContent(
                      title: 'Overview',
                      profilePlayerId: effectiveId,
                      isOwnProfile: isOwnProfile,
                      onGoToMatchesTab: () => _tabController.animateTo(1),
                    ),
                  ),
                  KeyedSubtree(
                    key: ValueKey('profile-tab-1-$_tabViewGeneration'),
                    child: _ProfileTabContent(
                      title: 'Stats',
                      profilePlayerId: effectiveId,
                      isOwnProfile: isOwnProfile,
                    ),
                  ),
                  KeyedSubtree(
                    key: ValueKey('profile-tab-2-$_tabViewGeneration'),
                    child: _ProfileTabContent(
                      title: 'Career',
                      profilePlayerId: effectiveId,
                      isOwnProfile: isOwnProfile,
                    ),
                  ),
                  KeyedSubtree(
                    key: ValueKey('profile-tab-3-$_tabViewGeneration'),
                    child: _ProfileTabContent(
                      title: 'Video',
                      profilePlayerId: effectiveId,
                      isOwnProfile: isOwnProfile,
                    ),
                  ),
                ],
        ),
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) => const ProfileScrollView();
}

class _ProfileTabContent extends StatelessWidget {
  final String title;
  final String profilePlayerId;
  final bool isOwnProfile;
  final VoidCallback? onGoToMatchesTab;

  const _ProfileTabContent({
    required this.title,
    required this.profilePlayerId,
    required this.isOwnProfile,
    this.onGoToMatchesTab,
  });

  @override
  Widget build(BuildContext context) {
    if (title == 'Overview') {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AttributesSection(profilePlayerId: profilePlayerId),
          const SizedBox(height: 16),
          _NextMatchSection(
            profilePlayerId: profilePlayerId,
            isOwnProfile: isOwnProfile,
            onGoToMatchesTab: onGoToMatchesTab,
          ),
          const SizedBox(height: 16),
          _TeamFormSection(onGoToMatchesTab: onGoToMatchesTab),
          const SizedBox(height: 16),
          _ClubHistorySection(
            profilePlayerId: profilePlayerId,
            isOwnProfile: isOwnProfile,
          ),
          const SizedBox(height: 16),
          _TrophiesSection(
            profilePlayerId: profilePlayerId,
            isOwnProfile: isOwnProfile,
          ),
          const SizedBox(height: 16),
          _BadgesSection(profilePlayerId: profilePlayerId),
          const SizedBox(height: 16),
          _ProfileSocialsSection(profilePlayerId: profilePlayerId),
        ],
      );
    }
    if (title == 'Matches') {
      return _ProfileMatchesTab(profilePlayerId: profilePlayerId);
    }
    if (title == 'Stats') {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SeasonOverallSection(profilePlayerId: profilePlayerId),
          const SizedBox(height: 16),
          _PlayerYearTeamStatsSection(profilePlayerId: profilePlayerId),
        ],
      );
    }
    if (title == 'Career') {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AllTimeStatsSection(profilePlayerId: profilePlayerId),
          const SizedBox(height: 16),
          _CareerTeamStatsSection(profilePlayerId: profilePlayerId),
        ],
      );
    }
    if (title == 'Video') {
      return ProfileVideosTab(
        profilePlayerId: profilePlayerId,
        isOwnProfile: isOwnProfile,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        const SizedBox(height: 12),
        Text(
          'Content coming soon.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ProfileMatchesTab extends ConsumerStatefulWidget {
  const _ProfileMatchesTab({required this.profilePlayerId});

  final String profilePlayerId;

  @override
  ConsumerState<_ProfileMatchesTab> createState() => _ProfileMatchesTabState();
}

class _ProfileMatchesTabState extends ConsumerState<_ProfileMatchesTab> {
  final ScrollController _scrollController = ScrollController();
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
    if (renderObject == null) {
      if (attempt < 6) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToDateKey(dateKey, attempt: attempt + 1);
        });
      }
      return;
    }

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

  final Map<String, GlobalKey> _dateGroupKeys = <String, GlobalKey>{};
  String? _selectedLeague;
  String? _selectedSeason;
  String? _selectedGameweek;
  String? _selectedTeam;
  DateTime? _requestedJumpDate;
  String? _lastHandledJumpDateKey;
  bool _showScrollToTop = false;

  List<String> _teamIds = [];
  List<TeamModel> _teams = [];
  List<Map<String, dynamic>> _leagues = [];
  List<SeasonModel> _seasons = [];
  List<Map<String, dynamic>> _gameweeks = [];
  bool _isLoading = true;
  String? _error;
  List<MatchModel> _matches = [];

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
      final teamIds = await TeamsRepository().getAllActiveTeamIdsForPlayer(
        widget.profilePlayerId,
      );
      final teams = await TeamsRepository().getTeamsForPlayer(
        widget.profilePlayerId,
      );
      final activeTeamSet = teamIds.toSet();
      final activeTeams =
          teams.where((t) => activeTeamSet.contains(t.id)).toList()..sort(
            (a, b) => a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            ),
          );
      if (teamIds.isEmpty) {
        if (!mounted) return;
        setState(() {
          _teamIds = [];
          _teams = [];
          _leagues = [];
          _seasons = [];
          _gameweeks = [];
          _matches = [];
          _isLoading = false;
          _error = null;
        });
        return;
      }

      final client = Supabase.instance.client;
      final ltmRes = await client
          .from('league_team_memberships')
          .select('league_id, league:leagues(id, league_name)')
          .inFilter('team_id', teamIds.toList());

      final leagues = <Map<String, dynamic>>[];
      final leagueIds = <String>[];
      final seen = <String>{};
      for (final row in List<Map<String, dynamic>>.from(ltmRes as List)) {
        final league = row['league'];
        if (league is Map<String, dynamic>) {
          final id = league['id']?.toString();
          if (id != null && id.isNotEmpty && seen.add(id)) {
            leagueIds.add(id);
            leagues.add(league);
          }
        }
      }

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
        _teamIds = teamIds.toList();
        _teams = activeTeams;
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
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      if (_teamIds.isEmpty) {
        if (!mounted) return;
        setState(() {
          _matches = [];
          _isLoading = false;
        });
        return;
      }
      final repo = ref.read(matchesRepositoryProvider);
      final matches = await repo.getMatches(
        teamIds: _selectedTeam != null ? [_selectedTeam!] : _teamIds,
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
    final selected = (value?.isEmpty ?? true) ? null : value;
    setState(() {
      _selectedLeague = selected;
      _selectedSeason = null;
      _selectedGameweek = null;
      _selectedTeam = null;
    });

    try {
      final seasonsRepo = ref.read(seasonsRepositoryProvider);
      final leagueIds = selected != null
          ? [selected]
          : _leagues
                .map((l) => l['id']?.toString() ?? '')
                .where((id) => id.isNotEmpty)
                .toList();
      if (leagueIds.isNotEmpty) {
        final seasons = await seasonsRepo.getSeasonsForLeagues(leagueIds);
        final gameweeks = seasons.isNotEmpty
            ? await seasonsRepo.getGameweeksForSeasons(
                seasons.map((s) => s.id).toList(),
              )
            : <Map<String, dynamic>>[];
        if (!mounted) return;
        setState(() {
          _seasons = seasons;
          _gameweeks = gameweeks;
        });
      }
    } catch (_) {}

    await _loadMatches();
  }

  Future<void> _onSeasonChanged(String? value) async {
    final selected = (value?.isEmpty ?? true) ? null : value;
    setState(() {
      _selectedSeason = selected;
      _selectedGameweek = null;
    });
    try {
      final seasonsRepo = ref.read(seasonsRepositoryProvider);
      final seasonIds = selected != null
          ? [selected]
          : _seasons.map((s) => s.id).toList();
      final gameweeks = await seasonsRepo.getGameweeksForSeasons(seasonIds);
      if (!mounted) return;
      setState(() => _gameweeks = gameweeks);
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
    for (final gw in _gameweeks) {
      if (gw['id']?.toString() == _selectedGameweek) {
        return 'Gameweek ${gw['week']}';
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

  static String _truncate(String text, [int max = 16]) {
    if (text.length <= max) return text;
    return '${text.substring(0, max)}...';
  }

  String _dateToKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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

  Map<String, List<MatchModel>> get _grouped {
    final grouped = <String, List<MatchModel>>{};
    for (final match in _matches) {
      final key =
          '${match.matchDate.year}-${match.matchDate.month.toString().padLeft(2, '0')}-${match.matchDate.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(match);
    }
    return grouped;
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
          onRefresh: _loadFilters,
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
                                        (league) => DropdownMenuEntry(
                                          value: league['id']?.toString() ?? '',
                                          label: _truncate(
                                            league['league_name']?.toString() ??
                                                '',
                                          ),
                                        ),
                                      ),
                                    ],
                                    onSelected: _onLeagueChanged,
                                  ),
                                ),
                              ),
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
                                        (season) => DropdownMenuEntry(
                                          value: season.id,
                                          label: _truncate(season.seasonName),
                                        ),
                                      ),
                                    ],
                                    onSelected: _onSeasonChanged,
                                  ),
                                ),
                              ),
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
                                      ..._gameweeks.map((gw) {
                                        final id = gw['id']?.toString() ?? '';
                                        final week =
                                            gw['week']?.toString() ?? '?';
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
                                        (team) => DropdownMenuEntry(
                                          value: team.id,
                                          label: _truncate(team.displayName),
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
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
                sliver: SliverToBoxAdapter(
                  child: _isLoading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: ProfileMatchListShimmer(),
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
                heroTag: 'player-profile-matches-scroll-top',
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
      _selectedGameweek != null ||
      _selectedTeam != null;

  bool get _showCreateMatchCta {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    return uid != null && uid == widget.profilePlayerId;
  }

  void _clearFilters() {
    setState(() {
      _selectedLeague = null;
      _selectedSeason = null;
      _selectedGameweek = null;
      _selectedTeam = null;
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
          showCreateMatchCta: _showCreateMatchCta,
          onClearFilters: _clearFilters,
          onCreateMatch: _openCreateMatch,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final dateKey in dateKeys) ...[
          KeyedSubtree(
            key: _dateGroupKeys.putIfAbsent(dateKey, () => GlobalKey()),
            child: _buildDateGroup(
              context,
              dateKey,
              grouped[dateKey]!,
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
                            child: _ProfileMatchLogo(
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
                                const Padding(
                                  padding: EdgeInsets.only(right: 6.0),
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
                            child: _ProfileMatchLogo(
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
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileMatchLogo extends StatelessWidget {
  const _ProfileMatchLogo({required this.path, this.size = 28});

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

class _ProfileSocialsSection extends StatelessWidget {
  const _ProfileSocialsSection({required this.profilePlayerId});

  final String profilePlayerId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: UserProfileRepository().getProfileByPlayerId(profilePlayerId),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        return SocialsSectionCard(
          title: 'Player socials',
          instagramUrl: profile?.socialInstagram,
          tiktokUrl: profile?.socialTiktok,
          xUrl: profile?.socialX,
          emptyHint:
              'Add Instagram, TikTok, or X URLs in Edit profile (https://…).',
        );
      },
    );
  }
}

class _SeasonOverallSection extends StatelessWidget {
  const _SeasonOverallSection({required this.profilePlayerId});

  final String profilePlayerId;

  Future<PlayerYearOverallStats?> _loadSeasonOverall() {
    return PlayerStatsRepository().getPlayerYearOverall(profilePlayerId);
  }

  static String _thousands(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => ',',
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final currentYear = DateTime.now().year;

    return FutureBuilder<PlayerYearOverallStats?>(
      future: _loadSeasonOverall(),
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final stats = snapshot.data;
        final goalsText = stats == null ? '—' : '${stats.goals}';
        final assistsText = stats == null ? '—' : '${stats.assists}';
        final ratingText = stats == null || stats.avgRating <= 0
            ? '—'
            : stats.avgRating.toStringAsFixed(2);
        final matchesText = stats == null ? '—' : '${stats.matches}';
        final tacklesText = stats == null ? '—' : '${stats.tackles}';
        final minutesText = stats == null
            ? '—'
            : _thousands(stats.minutesPlayed);

        return Container(
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Season overall', style: textTheme.titleSmall),
                        Text(
                          '$currentYear',
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isLoading)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          goalsText,
                          style: textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Goals',
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
                        Text(
                          assistsText,
                          style: textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Assists',
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            ratingText,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.surface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Rating',
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          matchesText,
                          style: textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Matches',
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
                        Text(
                          tacklesText,
                          style: textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tackles',
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
                        Text(
                          minutesText,
                          style: textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Minutes played',
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PlayerYearTeamStatsSection extends StatefulWidget {
  const _PlayerYearTeamStatsSection({required this.profilePlayerId});

  final String profilePlayerId;

  @override
  State<_PlayerYearTeamStatsSection> createState() =>
      _PlayerYearTeamStatsSectionState();
}

class _PlayerYearTeamStatsSectionState
    extends State<_PlayerYearTeamStatsSection> {
  final Set<String> _expandedTeamIds = {};
  late Future<List<PlayerYearTeamStats>> _teamsFuture;

  @override
  void initState() {
    super.initState();
    _teamsFuture = PlayerStatsRepository().getPlayerYearTeamStats(
      widget.profilePlayerId,
    );
  }

  static String _formatInt(int value) {
    if (value >= 1000) {
      return value.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (m) => ',',
      );
    }
    return value.toString();
  }

  Widget _buildStatRow(
    BuildContext context,
    String label,
    String value, {
    bool highlight = false,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface),
          ),
        ),
        if (highlight)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              value,
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.surface,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        else
          Text(
            value,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }

  List<Widget> _buildExpandedStats(
    BuildContext context,
    PlayerYearTeamStats team,
  ) {
    final ratingText = team.avgRating > 0
        ? team.avgRating.toStringAsFixed(1)
        : '—';

    return [
      _buildStatRow(context, 'Goals', _formatInt(team.goals)),
      const SizedBox(height: 12),
      _buildStatRow(context, 'Shots', _formatInt(team.shots)),
      const SizedBox(height: 12),
      _buildStatRow(
        context,
        'Shots on target',
        _formatInt(team.shotsOnTarget),
      ),
      const SizedBox(height: 12),
      _buildStatRow(
        context,
        'Shots off target',
        _formatInt(team.shotsOffTarget),
      ),
      const SizedBox(height: 12),
      _buildStatRow(context, 'Assists', _formatInt(team.assists)),
      const SizedBox(height: 12),
      _buildStatRow(context, 'Tackles', _formatInt(team.tackles)),
      const SizedBox(height: 12),
      _buildStatRow(context, 'Yellow cards', _formatInt(team.yellowCards)),
      const SizedBox(height: 12),
      _buildStatRow(context, 'Red cards', _formatInt(team.redCards)),
      const SizedBox(height: 12),
      _buildStatRow(context, 'Saves', _formatInt(team.saves)),
      const SizedBox(height: 12),
      _buildStatRow(context, 'Matches', _formatInt(team.matches)),
      const SizedBox(height: 12),
      _buildStatRow(
        context,
        'Minutes played',
        _formatInt(team.minutesPlayed),
      ),
      const SizedBox(height: 12),
      _buildStatRow(context, 'Rating', ratingText, highlight: true),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final currentYear = DateTime.now().year;

    return FutureBuilder<List<PlayerYearTeamStats>>(
      future: _teamsFuture,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final teams = snapshot.data ?? const <PlayerYearTeamStats>[];

        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Team performance', style: textTheme.titleSmall),
                          Text(
                            '$currentYear',
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isLoading)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
              if (!isLoading && teams.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    'No completed match stats for $currentYear yet.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                )
              else
                ...teams.asMap().entries.map((entry) {
                  final index = entry.key;
                  final team = entry.value;
                  final isExpanded = _expandedTeamIds.contains(team.teamId);
                  final isFirst = index == 0;
                  final isLast = index == teams.length - 1;
                  final logoPath = resolveTeamLogoPath(team.logoId);

                  return Column(
                    children: [
                      if (!isFirst)
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: colorScheme.outlineVariant,
                        ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            if (isExpanded) {
                              _expandedTeamIds.remove(team.teamId);
                            } else {
                              _expandedTeamIds.add(team.teamId);
                            }
                          });
                        },
                        borderRadius: BorderRadius.vertical(
                          bottom: isLast && !isExpanded
                              ? const Radius.circular(28)
                              : Radius.zero,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.transparent,
                                child: buildTeamLogo(
                                  logoPath?.trim().isNotEmpty == true
                                      ? logoPath
                                      : null,
                                  size: 40,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  team.teamName,
                                  style: textTheme.bodyLarge,
                                ),
                              ),
                              Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: colorScheme.onSurface,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isExpanded) ...[
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: colorScheme.outlineVariant,
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(16, 16, 16, isLast ? 16 : 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Season performance',
                                style: textTheme.titleSmall,
                              ),
                              const SizedBox(height: 16),
                              ..._buildExpandedStats(context, team),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

class _AllTimeStatsSection extends StatelessWidget {
  const _AllTimeStatsSection({required this.profilePlayerId});

  final String profilePlayerId;

  static String _formatInt(int? value) {
    if (value == null) return '—';
    if (value >= 1000) {
      return value.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (m) => ',',
      );
    }
    return value.toString();
  }

  static String _formatRating(double? value) {
    if (value == null || value <= 0) return '—';
    return value.toStringAsFixed(2);
  }

  Widget _gridCell(
    BuildContext context, {
    required String label,
    required String value,
    bool highlight = false,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: Column(
        children: [
          if (highlight)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                value,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.surface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            Text(
              value,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<PlayerAllTimeStats?>(
      future: PlayerStatsRepository().getPlayerAllTimeStats(profilePlayerId),
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final stats = snapshot.data;

        return Container(
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
                  Expanded(
                    child: Text('All-time stats', style: textTheme.titleSmall),
                  ),
                  if (isLoading)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _gridCell(
                    context,
                    label: 'Goals',
                    value: _formatInt(stats?.goals),
                  ),
                  _gridCell(
                    context,
                    label: 'Assists',
                    value: _formatInt(stats?.assists),
                  ),
                  _gridCell(
                    context,
                    label: 'Rating',
                    value: _formatRating(stats?.avgRating),
                    highlight: stats != null && stats.avgRating > 0,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  _gridCell(
                    context,
                    label: 'Tackles',
                    value: _formatInt(stats?.tackles),
                  ),
                  _gridCell(
                    context,
                    label: 'Yellow cards',
                    value: _formatInt(stats?.yellowCards),
                  ),
                  _gridCell(
                    context,
                    label: 'Red cards',
                    value: _formatInt(stats?.redCards),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  _gridCell(
                    context,
                    label: 'Saves',
                    value: _formatInt(stats?.saves),
                  ),
                  _gridCell(
                    context,
                    label: 'Matches',
                    value: _formatInt(stats?.matches),
                  ),
                  _gridCell(
                    context,
                    label: 'Minutes played',
                    value: _formatInt(stats?.minutesPlayed),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CareerTeamStatsSection extends StatefulWidget {
  const _CareerTeamStatsSection({required this.profilePlayerId});

  final String profilePlayerId;

  @override
  State<_CareerTeamStatsSection> createState() => _CareerTeamStatsSectionState();
}

class _CareerTeamStatsSectionState extends State<_CareerTeamStatsSection> {
  final Set<String> _expandedKeys = {};
  late Future<List<PlayerYearTeamStats>> _careerFuture;

  @override
  void initState() {
    super.initState();
    _careerFuture = PlayerStatsRepository().getPlayerCareerTeamStats(
      widget.profilePlayerId,
    );
  }

  String _entryKey(PlayerYearTeamStats team) => '${team.teamId}_${team.year}';

  static String _formatInt(int value) {
    if (value >= 1000) {
      return value.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (m) => ',',
      );
    }
    return value.toString();
  }

  Widget _buildStatRow(
    BuildContext context,
    String label,
    String value, {
    bool highlight = false,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface),
          ),
        ),
        if (highlight)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              value,
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.surface,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        else
          Text(
            value,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }

  List<Widget> _buildExpandedStats(
    BuildContext context,
    PlayerYearTeamStats team,
  ) {
    final ratingText = team.avgRating > 0
        ? team.avgRating.toStringAsFixed(1)
        : '—';

    return [
      _buildStatRow(context, 'Matches', _formatInt(team.matches)),
      const SizedBox(height: 12),
      _buildStatRow(context, 'Goals', _formatInt(team.goals)),
      const SizedBox(height: 12),
      _buildStatRow(context, 'Assists', _formatInt(team.assists)),
      const SizedBox(height: 12),
      _buildStatRow(context, 'Tackles', _formatInt(team.tackles)),
      const SizedBox(height: 12),
      _buildStatRow(context, 'Yellow cards', _formatInt(team.yellowCards)),
      const SizedBox(height: 12),
      _buildStatRow(context, 'Red cards', _formatInt(team.redCards)),
      const SizedBox(height: 12),
      _buildStatRow(context, 'Saves', _formatInt(team.saves)),
      const SizedBox(height: 12),
      _buildStatRow(
        context,
        'Minutes played',
        _formatInt(team.minutesPlayed),
      ),
      const SizedBox(height: 12),
      _buildStatRow(context, 'Rating', ratingText, highlight: true),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<List<PlayerYearTeamStats>>(
      future: _careerFuture,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final teams = snapshot.data ?? const <PlayerYearTeamStats>[];

        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Team stats', style: textTheme.titleSmall),
                    ),
                    if (isLoading)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
              if (!isLoading && teams.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    'No completed match stats yet.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                )
              else
                ...teams.asMap().entries.map((entry) {
                  final index = entry.key;
                  final team = entry.value;
                  final key = _entryKey(team);
                  final isExpanded = _expandedKeys.contains(key);
                  final isLast = index == teams.length - 1;
                  final logoPath = resolveTeamLogoPath(team.logoId);

                  return Column(
                    children: [
                      if (index > 0)
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: colorScheme.outlineVariant,
                        ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            if (isExpanded) {
                              _expandedKeys.remove(key);
                            } else {
                              _expandedKeys.add(key);
                            }
                          });
                        },
                        borderRadius: BorderRadius.vertical(
                          bottom: isLast && !isExpanded
                              ? const Radius.circular(28)
                              : Radius.zero,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.transparent,
                                child: buildTeamLogo(
                                  logoPath?.trim().isNotEmpty == true
                                      ? logoPath
                                      : null,
                                  size: 36,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      team.teamName,
                                      style: textTheme.bodyLarge,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${team.year}',
                                      style: textTheme.labelSmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: colorScheme.onSurface,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isExpanded) ...[
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: colorScheme.outlineVariant,
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(16, 16, 16, isLast ? 16 : 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Season stats', style: textTheme.titleSmall),
                              const SizedBox(height: 12),
                              ..._buildExpandedStats(context, team),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

class _AttributesSection extends StatefulWidget {
  const _AttributesSection({required this.profilePlayerId});

  final String profilePlayerId;

  @override
  State<_AttributesSection> createState() => _AttributesSectionState();
}

class _AttributesSectionState extends State<_AttributesSection> {
  double _currentValue = 0; // 0 = latest year, 1 = previous year, ...
  final List<int> _years = List<int>.generate(
    6,
    (i) => DateTime.now().year - i,
  );
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final SupabaseClient _client = Supabase.instance.client;

  Timer? _searchDebounce;
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = const [];
  Map<String, dynamic>? _selectedComparisonPlayer;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      _performPlayerSearch(query.trim());
    });
  }

  Future<void> _performPlayerSearch(String query) async {
    if (!mounted) return;
    if (query.isEmpty) {
      setState(() {
        _searchResults = const [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      final res = await _client
          .from('players')
          .select('id, player_name, image_url')
          .ilike('player_name', '%$query%')
          .isFilter('deleted_at', null)
          .limit(8);

      if (!mounted) return;
      setState(() {
        _searchResults = List<Map<String, dynamic>>.from(res as List);
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searchResults = const [];
        _isSearching = false;
      });
    }
  }

  void _selectComparisonPlayer(Map<String, dynamic> row) {
    final name = row['player_name']?.toString() ?? '';
    setState(() {
      _selectedComparisonPlayer = row;
      _searchController.text = name;
      _searchResults = const [];
    });
    _searchFocusNode.unfocus();
  }

  Widget _comparisonAvatar(BuildContext context) {
    final selected = _selectedComparisonPlayer;
    final imageUrl = selected?['image_url']?.toString() ?? '';
    if (imageUrl.isNotEmpty &&
        (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'))) {
      return CircleAvatar(radius: 20, backgroundImage: appCachedImageProvider(imageUrl));
    }
    if (imageUrl.isNotEmpty) {
      return CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: ClipOval(
          child: Image.asset(
            imageUrl,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Icon(
              Icons.person,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      );
    }
    return CircleAvatar(
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: Icon(Icons.person, color: Theme.of(context).colorScheme.onPrimary),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedYear =
        _years[_currentValue.round().clamp(0, _years.length - 1)];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and info icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Attributes', style: Theme.of(context).textTheme.titleSmall),
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Attributes'),
                      content: const Text(
                        'The radar chart shows 5 performance attributes, each scored from 0 to 10 (higher is better). '
                        'Scores average only matches where you had minutes on the pitch (from the locked line-up and substitutions), '
                        'weighted like match ratings:\n\n'
                        'ATT (Attacking): goals and assists.\n'
                        'SHT (Shooting): shots and shots on target.\n'
                        'DEF (Defending): tackles.\n'
                        'GKP (Goalkeeping): saves — mainly relevant for goalkeepers.\n'
                        'DIS (Discipline): fewer yellow/red cards gives a higher score.\n\n'
                        'An average performance sits around the middle rings (~6). '
                        'Use the year slider to compare different years.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Radar chart
          SizedBox(
            height: 300,
            child: PerformanceRadarChart(
              key: ValueKey(
                'attrs-${widget.profilePlayerId}-$selectedYear-'
                '${_selectedComparisonPlayer?['id'] ?? ''}',
              ),
              playerId: widget.profilePlayerId,
              year: selectedYear,
              comparePlayerId: _selectedComparisonPlayer?['id']?.toString(),
            ),
          ),
          const SizedBox(height: 8),
          // Timeline slider
          _TimelineSlider(
            years: _years,
            value: _currentValue,
            onChanged: (value) => setState(() => _currentValue = value),
          ),
          const SizedBox(height: 16),
          // Profile icon and search field row
          Row(
            children: [
              // Profile icon
              _comparisonAvatar(context),
              const SizedBox(width: 8),
              // Text field
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    labelText: 'Search to compare',
                    suffixIcon: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : (_searchController.text.isNotEmpty
                              ? IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchResults = const [];
                                      _selectedComparisonPlayer = null;
                                    });
                                  },
                                  icon: const Icon(Icons.close),
                                )
                              : null),
                  ),
                ),
              ),
            ],
          ),
          if (_searchResults.isNotEmpty) const SizedBox(height: 10),
          if (_searchResults.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _searchResults.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.15),
                ),
                itemBuilder: (context, index) {
                  final row = _searchResults[index];
                  final name = row['player_name']?.toString() ?? 'Unknown';
                  final imageUrl = row['image_url']?.toString() ?? '';
                  Widget leading;
                  if (imageUrl.isNotEmpty &&
                      (imageUrl.startsWith('http://') ||
                          imageUrl.startsWith('https://'))) {
                    leading = CircleAvatar(
                      backgroundImage: appCachedImageProvider(imageUrl),
                    );
                  } else if (imageUrl.isNotEmpty) {
                    leading = CircleAvatar(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: ClipOval(
                        child: Image.asset(
                          imageUrl,
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.person, size: 16),
                        ),
                      ),
                    );
                  } else {
                    leading = const CircleAvatar(
                      child: Icon(Icons.person, size: 16),
                    );
                  }

                  return ListTile(
                    dense: true,
                    leading: leading,
                    title: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _selectComparisonPlayer(row),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Overview tab section shell (title + body) matching home section cards.
class _ProfileOverviewSectionCard extends StatelessWidget {
  const _ProfileOverviewSectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
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

Future<void> _profileOpenFindTeam(BuildContext context) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => const AppSearchPage()),
  );
}

Future<void> _profileOpenCreateTeam(BuildContext context) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => const CreateTeamOrLeaguePage()),
  );
}

class _NextMatchSection extends StatelessWidget {
  const _NextMatchSection({
    required this.profilePlayerId,
    required this.isOwnProfile,
    this.onGoToMatchesTab,
  });

  final String profilePlayerId;
  final bool isOwnProfile;
  final VoidCallback? onGoToMatchesTab;

  DateTime? _matchDateTime(MatchModel m) {
    final localDate = m.matchDate.toLocal();
    final t = m.matchTime.trim();
    if (t.isEmpty) {
      return DateTime(localDate.year, localDate.month, localDate.day);
    }
    // HH:mm or HH:mm:ss
    final parts = t.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]) ?? 0;
      final min = int.tryParse(parts[1]) ?? 0;
      return DateTime(localDate.year, localDate.month, localDate.day, h, min);
    }
    return DateTime(localDate.year, localDate.month, localDate.day);
  }

  String _dateLabel(DateTime d) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
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
    final wd = weekdays[(d.weekday - 1).clamp(0, 6)];
    final mo = months[(d.month - 1).clamp(0, 11)];
    return '$wd ${d.day} $mo';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return FutureBuilder<Map<String, dynamic>>(
      future: () async {
        final teamsRepo = TeamsRepository();
        final matchRepo = MatchesRepository();
        final teamIds = await teamsRepo.getAllActiveTeamIdsForPlayer(
          profilePlayerId,
        );
        if (teamIds.isEmpty) {
          return {'match': null, 'hasTeams': false};
        }

        final next = await matchRepo.getNextUpcomingMatch(
          teamIds: teamIds.toList(),
        );
        return {
          'match': next,
          'hasTeams': true,
        };
      }(),
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final err = snapshot.error;
        final match = snapshot.data?['match'] as MatchModel?;
        final hasTeams = snapshot.data?['hasTeams'] as bool? ?? false;

        if (isLoading) {
          return const ProfileSectionCardShimmer(height: 120);
        }

        if (err != null) {
          return _ProfileOverviewSectionCard(
            title: 'Next match',
            child: const HomeSectionEmptyState(
              embedded: true,
              message:
                  'We could not load the next fixture. Pull to refresh on your profile and try again.',
            ),
          );
        }

        if (match == null) {
          final message = !hasTeams
              ? (isOwnProfile
                  ? 'Join a team to see your next scheduled fixture here.'
                  : 'This player is not on a team, so there is no upcoming fixture to show.')
              : (isOwnProfile
                  ? 'Nothing is on the calendar yet. Your next league fixture will show up here once it is scheduled.'
                  : 'This player has no upcoming matches scheduled right now.');
          return _ProfileOverviewSectionCard(
            title: 'Next match',
            child: HomeSectionEmptyState(
              embedded: true,
              message: message,
              actionLabel: isOwnProfile && hasTeams && onGoToMatchesTab != null
                  ? 'View matches'
                  : (isOwnProfile && !hasTeams ? 'Find a team' : null),
              actionIcon: isOwnProfile && hasTeams
                  ? Icons.calendar_month_outlined
                  : Icons.search,
              onAction: isOwnProfile && hasTeams
                  ? onGoToMatchesTab
                  : (isOwnProfile && !hasTeams
                      ? () => _profileOpenFindTeam(context)
                      : null),
              secondaryActionLabel:
                  isOwnProfile && !hasTeams ? 'Create team' : null,
              onSecondaryAction: isOwnProfile && !hasTeams
                  ? () => _profileOpenCreateTeam(context)
                  : null,
            ),
          );
        }

        ImageProvider teamLogo(TeamModel t) {
          final p = t.logoPath;
          if (p.startsWith('http://') || p.startsWith('https://')) {
            return appCachedImageProvider(p);
          }
          return AssetImage(p);
        }

        final date = match.matchDate.toLocal();
        final league = match.leagueName?.trim().isNotEmpty == true
            ? match.leagueName!.trim()
            : '—';

        return _ProfileOverviewSectionCard(
          title: 'Next match',
          child: Column(
            children: [
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Text(
                            match.teamA.displayName,
                            style: textTheme.bodySmall,
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            backgroundColor: Colors.transparent,
                            backgroundImage: teamLogo(match.teamA),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Text(match.timeDisplay, style: textTheme.bodyLarge),
                      const SizedBox(width: 16),
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.transparent,
                            backgroundImage: teamLogo(match.teamB),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            match.teamB.displayName,
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(league, style: textTheme.labelSmall),
                      const SizedBox(width: 4),
                      Text('Â·', style: textTheme.labelSmall),
                      const SizedBox(width: 4),
                      Text(_dateLabel(date), style: textTheme.labelSmall),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TeamFormSection extends StatefulWidget {
  const _TeamFormSection({this.onGoToMatchesTab});

  final VoidCallback? onGoToMatchesTab;

  @override
  State<_TeamFormSection> createState() => _TeamFormSectionState();
}

class _TeamFormSectionState extends State<_TeamFormSection> {
  List<TeamModel> _teams = [];
  String? _selectedTeamId;
  List<MatchModel> _recentMatches = [];

  bool _isLoading = true;
  String? _error;

  ImageProvider _logoProvider(String logoPath) {
    if (logoPath.isEmpty) return AssetImage(AppAssets.pitchBg);
    if (logoPath.startsWith('http://') || logoPath.startsWith('https://')) {
      return appCachedImageProvider(logoPath);
    }
    return AssetImage(logoPath);
  }

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
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          _teams = [];
          _selectedTeamId = null;
          _recentMatches = [];
          _isLoading = false;
        });
        return;
      }

      final teams = await TeamsRepository().getTeamsForUser(userId);
      teams.sort((a, b) => a.displayName.compareTo(b.displayName));

      final initialTeamId = teams.isNotEmpty ? teams.first.id : null;
      if (!mounted) return;

      setState(() {
        _teams = teams;
        _selectedTeamId = initialTeamId;
        _isLoading = false;
      });

      if (initialTeamId != null) {
        await _loadMatchesForTeam(initialTeamId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMatchesForTeam(String teamId) async {
    // Keep the UX snappy: show loading indicator only for initial load.
    final repo = MatchesRepository();
    final recent = await repo.getRecentCompletedMatches(
      teamIds: [teamId],
      limit: 6,
    );

    if (!mounted) return;
    setState(() {
      _recentMatches = recent;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return const ProfileSectionCardShimmer(height: 180);
    }

    if (_error != null) {
      return _ProfileOverviewSectionCard(
        title: 'Team form',
        child: const HomeSectionEmptyState(
          embedded: true,
          message:
              'We could not load recent results. Pull to refresh and try again.',
        ),
      );
    }

    if (_teams.isEmpty || _selectedTeamId == null) {
      return _ProfileOverviewSectionCard(
        title: 'Team form',
        child: HomeSectionEmptyState(
          embedded: true,
          message:
              'Join a team to track your last six results with scores and gameweeks.',
          actionLabel: 'Find a team',
          actionIcon: Icons.search,
          onAction: () async {
            await _profileOpenFindTeam(context);
            if (!mounted) return;
            await _load();
          },
          secondaryActionLabel: 'Create team',
          onSecondaryAction: () async {
            await _profileOpenCreateTeam(context);
            if (!mounted) return;
            await _load();
          },
        ),
      );
    }

    return _ProfileOverviewSectionCard(
      title: 'Team form',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_teams.length > 1) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _teams.asMap().entries.map((entry) {
                  final i = entry.key;
                  final t = entry.value;
                  return Padding(
                    padding: EdgeInsets.only(
                      right: i < _teams.length - 1 ? 8 : 0,
                    ),
                    child: FilterChip(
                      backgroundColor: colorScheme.surfaceContainerHigh,
                      avatar: ClipOval(
                        child: Image(
                          image: _logoProvider(t.logoPath),
                          width: 24,
                          height: 24,
                          fit: BoxFit.cover,
                        ),
                      ),
                      label: Text(t.displayName),
                      selected: _selectedTeamId == t.id,
                      onSelected: (selected) async {
                        setState(() {
                          _selectedTeamId = t.id;
                        });
                        await _loadMatchesForTeam(t.id);
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          const SizedBox(height: 16),
          if (_recentMatches.isEmpty)
            const HomeSectionEmptyState(
              embedded: true,
              compact: true,
              message:
                  'No completed matches for this team yet. Recent form appears after full-time results are recorded.',
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _recentMatches.asMap().entries.map((entry) {
                  final index = entry.key;
                  final match = entry.value;

                  final isTeamA = match.teamA.id == _selectedTeamId;
                  final myScore = isTeamA ? match.teamAScore : match.teamBScore;
                  final oppScore = isTeamA
                      ? match.teamBScore
                      : match.teamAScore;
                  final opponent = isTeamA ? match.teamB : match.teamA;

                  Color scoreColor;
                  if (myScore != null && oppScore != null) {
                    if (myScore > oppScore) {
                      scoreColor = Colors.green;
                    } else if (myScore < oppScore) {
                      scoreColor = Colors.red;
                    } else {
                      scoreColor = colorScheme.surfaceContainerHighest;
                    }
                  } else {
                    scoreColor = colorScheme.surfaceContainerHighest;
                  }

                  final isDraw =
                      myScore != null &&
                      oppScore != null &&
                      myScore == oppScore;
                  final scoreText = (myScore != null && oppScore != null)
                      ? '$myScore - $oppScore'
                      : '—';

                  final gwLabel = match.gameweekNumber != null
                      ? 'GW${match.gameweekNumber}'
                      : (match.gameweek ?? '');

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        children: [
                          // Game week
                          Text(
                            gwLabel.isNotEmpty ? gwLabel : '—',
                            style: textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          // Opponent logo
                          CircleAvatar(
                            backgroundColor: Colors.transparent,
                            backgroundImage: _logoProvider(opponent.logoPath),
                          ),
                          const SizedBox(height: 8),
                          // Opponent short form
                          Text(
                            opponent.shortForm,
                            style: textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Score pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: scoreColor,
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
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ClubHistorySection extends StatefulWidget {
  const _ClubHistorySection({
    required this.profilePlayerId,
    required this.isOwnProfile,
  });

  final String profilePlayerId;
  final bool isOwnProfile;

  @override
  State<_ClubHistorySection> createState() => _ClubHistorySectionState();
}

class _ClubHistorySectionState extends State<_ClubHistorySection> {
  final _teamsRepo = TeamsRepository();
  List<TeamMembershipStint> _stints = [];
  Set<String> _viewerActiveTeamIds = {};
  Set<String> _viewerPendingTeamIds = {};
  bool _loading = true;
  String? _error;
  final Set<String> _busyTeamIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stints = await _teamsRepo.getMembershipHistoryForPlayer(
        widget.profilePlayerId,
      );
      final viewerId = Supabase.instance.client.auth.currentUser?.id;
      Set<String> active = {};
      Set<String> pending = {};
      if (viewerId != null && stints.isNotEmpty) {
        final ids = stints.map((s) => s.teamId).toList();
        active = await _teamsRepo.getActiveTeamIdsForPlayer(viewerId, ids);
        pending = await _teamsRepo.getPendingJoinRequestTeamIds(viewerId, ids);
      }
      if (!mounted) return;
      setState(() {
        _stints = stints;
        _viewerActiveTeamIds = active;
        _viewerPendingTeamIds = pending;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _yearsLabel(TeamMembershipStint s) {
    final start = s.createdAt?.toLocal();
    final startYear = start?.year;
    if (startYear == null) {
      return s.isCurrent ? '—' : '—';
    }
    if (s.isCurrent) return '$startYear – Now';
    final end = s.endDate?.toLocal().year;
    if (end == null) return '$startYear – —';
    return '$startYear – $end';
  }

  Widget _teamLogoAvatar(TeamMembershipStint s) {
    final m = TeamModel(
      id: s.teamId,
      logoId: s.logoId,
      shortForm: s.shortForm ?? '',
      teamName: s.teamName,
    );
    return CircleAvatar(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: buildTeamLogo(m.logoPath.isEmpty ? null : m.logoPath, size: 36),
    );
  }

  /// Leave / Join / Pending for the signed-in viewer (or profile player when [isOwnProfile]).
  _ClubRowAction _actionForRow(TeamMembershipStint stint) {
    final viewerId = Supabase.instance.client.auth.currentUser?.id;
    if (viewerId == null) {
      return _ClubRowAction.none;
    }
    if (widget.isOwnProfile) {
      if (stint.isCurrent) {
        return _ClubRowAction.leave;
      }
      if (_viewerPendingTeamIds.contains(stint.teamId)) {
        return _ClubRowAction.pending;
      }
      return _ClubRowAction.join;
    }
    if (_viewerActiveTeamIds.contains(stint.teamId)) {
      return _ClubRowAction.leave;
    }
    if (_viewerPendingTeamIds.contains(stint.teamId)) {
      return _ClubRowAction.pending;
    }
    return _ClubRowAction.join;
  }

  Future<void> _onLeavePressed(String teamId) async {
    final viewerId = Supabase.instance.client.auth.currentUser?.id;
    if (viewerId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave team?'),
        content: const Text(
          'You will be removed from the active squad. You can request to join again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busyTeamIds.add(teamId));
    try {
      await _teamsRepo.leaveTeam(playerId: viewerId, teamId: teamId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('You have left the team.')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not leave team: $e')));
    } finally {
      if (mounted) setState(() => _busyTeamIds.remove(teamId));
    }
  }

  Future<void> _onJoinPressed(String teamId) async {
    final viewerId = Supabase.instance.client.auth.currentUser?.id;
    if (viewerId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sign in to join a team.')));
      return;
    }
    setState(() => _busyTeamIds.add(teamId));
    try {
      await _teamsRepo.sendTeamJoinRequest(playerId: viewerId, teamId: teamId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your join request has been sent.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not send request: $e')));
    } finally {
      if (mounted) setState(() => _busyTeamIds.remove(teamId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_loading) {
      return const ProfileSectionCardShimmer(height: 200);
    }

    if (_error != null) {
      return _ProfileOverviewSectionCard(
        title: 'Club history',
        child: const HomeSectionEmptyState(
          embedded: true,
          message:
              'We could not load club history. Pull to refresh and try again.',
        ),
      );
    }

    if (_stints.isEmpty) {
      return _ProfileOverviewSectionCard(
        title: 'Club history',
        child: HomeSectionEmptyState(
          embedded: true,
          message: widget.isOwnProfile
              ? 'Teams you join or leave will be listed here with dates and quick actions.'
              : 'This player has not been linked to any teams yet.',
          actionLabel: widget.isOwnProfile ? 'Find a team' : null,
          actionIcon: Icons.search,
          onAction: widget.isOwnProfile
              ? () async {
                  await _profileOpenFindTeam(context);
                  if (!mounted) return;
                  await _load();
                }
              : null,
          secondaryActionLabel: widget.isOwnProfile ? 'Create team' : null,
          onSecondaryAction: widget.isOwnProfile
              ? () async {
                  await _profileOpenCreateTeam(context);
                  if (!mounted) return;
                  await _load();
                }
              : null,
        ),
      );
    }

    return _ProfileOverviewSectionCard(
      title: 'Club history',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          ..._stints.asMap().entries.map((entry) {
            final index = entry.key;
            final stint = entry.value;
            final action = _actionForRow(stint);
            final busy = _busyTeamIds.contains(stint.teamId);

            Widget? trailing;
            switch (action) {
              case _ClubRowAction.none:
                trailing = null;
                break;
              case _ClubRowAction.leave:
                trailing = OutlinedButton(
                  onPressed: busy ? null : () => _onLeavePressed(stint.teamId),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    side: BorderSide(color: colorScheme.outline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: busy
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.primary,
                          ),
                        )
                      : Text('Leave', style: textTheme.labelMedium),
                );
                break;
              case _ClubRowAction.join:
                trailing = OutlinedButton(
                  onPressed: busy ? null : () => _onJoinPressed(stint.teamId),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    side: BorderSide(color: colorScheme.outline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: busy
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.primary,
                          ),
                        )
                      : Text('Join', style: textTheme.labelMedium),
                );
                break;
              case _ClubRowAction.pending:
                trailing = OutlinedButton(
                  onPressed: null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    side: BorderSide(color: colorScheme.outlineVariant),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    'Pending',
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
                break;
            }

            return Column(
              children: [
                Row(
                  children: [
                    _teamLogoAvatar(stint),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(stint.displayName, style: textTheme.bodySmall),
                          const SizedBox(height: 4),
                          Text(
                            _yearsLabel(stint),
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ?trailing,
                  ],
                ),
                if (index < _stints.length - 1) ...[
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

enum _ClubRowAction { none, leave, join, pending }

class _TrophiesSection extends StatefulWidget {
  const _TrophiesSection({
    required this.profilePlayerId,
    required this.isOwnProfile,
  });

  final String profilePlayerId;
  final bool isOwnProfile;

  @override
  State<_TrophiesSection> createState() => _TrophiesSectionState();
}

class _TrophiesSectionState extends State<_TrophiesSection> {
  List<TeamModel> _teams = [];
  String? _selectedTeamId;
  List<_ProfileTrophyRow> _rows = [];

  bool _isLoading = true;
  String? _error;

  ImageProvider _teamChipLogo(String logoPath) {
    if (logoPath.isEmpty) return AssetImage(AppAssets.pitchBg);
    if (logoPath.startsWith('http://') || logoPath.startsWith('https://')) {
      return appCachedImageProvider(logoPath);
    }
    return AssetImage(logoPath);
  }

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final playerId = widget.profilePlayerId;
      if (playerId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _teams = [];
          _selectedTeamId = null;
          _rows = [];
          _isLoading = false;
        });
        return;
      }
      final teams = await TeamsRepository().getTeamsForPlayer(playerId);
      teams.sort((a, b) => a.displayName.compareTo(b.displayName));
      final firstId = teams.isNotEmpty ? teams.first.id : null;
      if (!mounted) return;
      setState(() {
        _teams = teams;
        _selectedTeamId = firstId;
        _isLoading = false;
      });
      if (firstId != null) {
        await _loadTrophiesForTeam(firstId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTrophiesForTeam(String teamId) async {
    final raw = await LeaguesRepository().getChampionTrophiesForTeam(teamId);
    final byName = <String, List<Map<String, dynamic>>>{};
    for (final t in raw) {
      final name = t['league_name']?.toString() ?? 'League';
      byName.putIfAbsent(name, () => []).add(t);
    }
    final rows = <_ProfileTrophyRow>[];
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
        _ProfileTrophyRow(
          leagueName: entry.key,
          logoId: logoId,
          yearsLabel: subtitle,
          count: list.length,
        ),
      );
    }
    rows.sort((a, b) => a.leagueName.compareTo(b.leagueName));
    if (!mounted) return;
    setState(() => _rows = rows);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return const ProfileSectionCardShimmer(height: 160);
    }

    if (_error != null) {
      return _ProfileOverviewSectionCard(
        title: 'Trophies',
        child: const HomeSectionEmptyState(
          embedded: true,
          message:
              'We could not load trophies. Pull to refresh and try again.',
        ),
      );
    }

    if (_teams.isEmpty || _selectedTeamId == null) {
      return _ProfileOverviewSectionCard(
        title: 'Trophies',
        child: HomeSectionEmptyState(
          embedded: true,
          message: widget.isOwnProfile
              ? 'League titles your teams have won will show here once a season ends.'
              : 'This player is not on a team, so there are no trophies to display.',
          actionLabel: widget.isOwnProfile ? 'Find a team' : null,
          actionIcon: Icons.search,
          onAction: widget.isOwnProfile
              ? () async {
                  await _profileOpenFindTeam(context);
                  if (!mounted) return;
                  await _loadTeams();
                }
              : null,
        ),
      );
    }

    return _ProfileOverviewSectionCard(
      title: 'Trophies',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_teams.length > 1) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _teams.asMap().entries.map((entry) {
                  final i = entry.key;
                  final t = entry.value;
                  return Padding(
                    padding: EdgeInsets.only(
                      right: i < _teams.length - 1 ? 8 : 0,
                    ),
                    child: FilterChip(
                      backgroundColor: colorScheme.surfaceContainerHigh,
                      avatar: ClipOval(
                        child: Image(
                          image: _teamChipLogo(t.logoPath),
                          width: 24,
                          height: 24,
                          fit: BoxFit.cover,
                        ),
                      ),
                      label: Text(t.displayName),
                      selected: _selectedTeamId == t.id,
                      onSelected: (_) async {
                        setState(() => _selectedTeamId = t.id);
                        await _loadTrophiesForTeam(t.id);
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_rows.isEmpty)
            HomeSectionEmptyState(
              embedded: true,
              compact: true,
              message: widget.isOwnProfile
                  ? 'No league titles yet. Trophies are added when your team tops the table in a finished season.'
                  : 'This team has not won a finished league season yet.',
            )
          else
            ..._rows.asMap().entries.map((entry) {
              final index = entry.key;
              final trophy = entry.value;
              return Column(
                children: [
                  Row(
                    children: [
                      _ProfileTrophyLeagueThumb(logoId: trophy.logoId),
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

class _ProfileTrophyRow {
  const _ProfileTrophyRow({
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

class _ProfileTrophyLeagueThumb extends StatelessWidget {
  const _ProfileTrophyLeagueThumb({this.logoId});

  final String? logoId;

  static String? _resolvedPath(String? raw) => resolveTeamLogoPath(raw);

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

class _BadgesSection extends StatefulWidget {
  const _BadgesSection({required this.profilePlayerId});

  final String profilePlayerId;

  @override
  State<_BadgesSection> createState() => _BadgesSectionState();
}

class _BadgesSectionState extends State<_BadgesSection> {
  late Future<PlayerAllTimeStats?> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = PlayerStatsRepository().getPlayerAllTimeStats(
      widget.profilePlayerId,
    );
  }

  @override
  void didUpdateWidget(covariant _BadgesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profilePlayerId != widget.profilePlayerId) {
      _statsFuture = PlayerStatsRepository().getPlayerAllTimeStats(
        widget.profilePlayerId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PlayerAllTimeStats?>(
      future: _statsFuture,
      builder: (context, snapshot) {
        final stats = snapshot.data;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Badges', style: Theme.of(context).textTheme.titleSmall),
                  IconButton(
                    icon: const Icon(Icons.info_outline),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Badges'),
                          content: const Text(
                            'Earn badges by reaching career milestones in finished '
                            'matches. Each earned badge adds bonus points to your '
                            'leaderboard total.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...PlayerBadges.all.asMap().entries.map((entry) {
                final index = entry.key;
                final badge = entry.value;
                final progress = badge.progressFor(stats);
                final percentage = badge.progressPercentFor(stats);
                final earned = badge.isEarned(stats);

                return Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: SvgPicture.asset(
                            badge.svgPath,
                            width: 36,
                            height: 36,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.emoji_events,
                                size: 24,
                                color: Theme.of(context).colorScheme.primary,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            badge.pointsLabel,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: earned
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                badge.name,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                badge.objective,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 2,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(2),
                                        child: LinearProgressIndicator(
                                          year2023: false,
                                          value: progress,
                                          minHeight: 2,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$percentage%',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (index < PlayerBadges.all.length - 1) ...[
                      const SizedBox(height: 16),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _TimelineSlider extends StatelessWidget {
  const _TimelineSlider({
    required this.years,
    required this.value,
    required this.onChanged,
  });

  final List<int> years;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final maxIndex = (years.length - 1).clamp(0, 1000).toDouble();
    final safeIndex = value.round().clamp(0, years.length - 1);
    return Slider(
      year2023: false,
      value: value.clamp(0.0, maxIndex),
      min: 0,
      max: maxIndex,
      divisions: years.length > 1 ? years.length - 1 : 1,
      label: years[safeIndex].toString(),
      onChanged: onChanged,
    );
  }
}

class _ProfileCard extends StatefulWidget {
  const _ProfileCard({
    required this.playerId,
    required this.showEditButton,
    this.refreshTick = 0,
  });

  final String playerId;
  final bool showEditButton;
  final int refreshTick;

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  late Future<UserProfile?> _profileFuture;
  late Future<int> _followersFuture;
  late Future<int?> _overallRankFuture;
  Color? _heroToneA;
  Color? _heroToneB;
  Color? _heroToneC;
  String? _lastHeroImageKey;

  Future<UserProfile?> _fetchProfile() async {
    final repo = UserProfileRepository();
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (widget.showEditButton && uid == widget.playerId) {
      return repo.getCurrentProfile();
    }
    return repo.getProfileByPlayerId(widget.playerId);
  }

  @override
  void initState() {
    super.initState();
    _profileFuture = _fetchProfile();
    _followersFuture = _fetchFollowersCount();
    _overallRankFuture = _fetchOverallRank();
  }

  @override
  void didUpdateWidget(covariant _ProfileCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playerId != widget.playerId ||
        oldWidget.showEditButton != widget.showEditButton ||
        oldWidget.refreshTick != widget.refreshTick) {
      _profileFuture = _fetchProfile();
      _followersFuture = _fetchFollowersCount();
      _overallRankFuture = _fetchOverallRank();
    }
  }

  Future<int> _fetchFollowersCount() async {
    try {
      // Server-side count: transfers a single number instead of every row.
      final res = await Supabase.instance.client
          .from('user_follows')
          .select('follower_user_id')
          .eq('following_user_id', widget.playerId)
          .limit(1)
          .count(CountOption.exact);
      return res.count;
    } catch (_) {
      return 0;
    }
  }

  Future<int?> _fetchOverallRank() async {
    try {
      // Single-row RPC instead of downloading the whole leaderboard.
      final res = await Supabase.instance.client.rpc(
        'get_player_rank',
        params: {'p_player_id': widget.playerId},
      );
      if (res == null) return null;
      final rank = res is int ? res : int.tryParse(res.toString());
      return (rank != null && rank > 0) ? rank : null;
    } catch (_) {
      // Fallback (e.g. RPC not deployed yet): scan the capped leaderboard.
      try {
        final rows = await LeaderboardRepository().getOverall(limit: 500);
        for (final row in rows) {
          if (row.playerId == widget.playerId) {
            return row.rank > 0 ? row.rank : null;
          }
        }
        return null;
      } catch (_) {
        return null;
      }
    }
  }

  String _formatCount(int value) {
    final safe = value < 0 ? 0 : value;
    return safe.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => ',',
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const ProfileHeaderShimmer();
        }

        final profile = snapshot.data;
        final playerName = profile?.playerName ?? 'Player';
        final username =
            profile?.username != null && profile!.username!.isNotEmpty
            ? '@${profile.username}'
            : '@—';
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;
        final imagePath = profile?.imageUrl;
        final imageKey = imagePath?.trim().isNotEmpty == true
            ? imagePath!.trim()
            : '__profile_fallback__';
        if (_lastHeroImageKey != imageKey) {
          _lastHeroImageKey = imageKey;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _deriveHeroColorsFromImage(imagePath);
          });
        }
        final toneA =
            _heroToneA ??
            Color.alphaBlend(
              colorScheme.primary.withValues(alpha: 0.22),
              colorScheme.surfaceContainerHigh,
            );
        final toneB =
            _heroToneB ??
            Color.alphaBlend(
              colorScheme.secondary.withValues(alpha: 0.18),
              colorScheme.surfaceContainer,
            );
        final toneC =
            _heroToneC ??
            Color.alphaBlend(
              colorScheme.tertiary.withValues(alpha: 0.16),
              colorScheme.surfaceContainerLow,
            );

        return ClipRRect(
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
                colors: [toneA, toneB, toneC],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.85, -0.65),
                  colors: [
                    Color.alphaBlend(
                      colorScheme.primary.withValues(alpha: 0.26),
                      toneA,
                    ),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _ProfileHeroAvatar(
                          imageUrl: profile?.imageUrl,
                          heroTag: 'profile-photo-${widget.playerId}',
                          onTap: profile?.imageUrl != null
                              ? () => _openProfilePhoto(
                                  context,
                                  profile!.imageUrl!,
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                playerName,
                                style: textTheme.displayMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                username,
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.showEditButton) ...[
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: profile == null
                                ? null
                                : () async {
                                    final saved = await Navigator.of(context)
                                        .push<bool>(
                                          MaterialPageRoute(
                                            builder: (_) => EditProfilePage(
                                              profile: profile,
                                            ),
                                          ),
                                        );
                                    if (saved == true && mounted) {
                                      setState(() {
                                        _profileFuture = _fetchProfile();
                                      });
                                    }
                                  },
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
                            child: const Icon(Icons.edit_outlined, size: 20),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ActionChip(
                            svgPath: AppAssets.positionIcon,
                            label: profile?.position?.isNotEmpty == true
                                ? profile!.position!
                                : '—',
                            context: context,
                          ),
                          const SizedBox(width: 8),
                          FutureBuilder<int>(
                            future: _followersFuture,
                            builder: (context, followersSnapshot) {
                              return _ActionChip(
                                icon: Icons.groups_outlined,
                                label: followersSnapshot.hasData
                                    ? _formatCount(followersSnapshot.data!)
                                    : '—',
                                context: context,
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          FutureBuilder<int?>(
                            future: _overallRankFuture,
                            builder: (context, rankSnapshot) {
                              return _ActionChip(
                                icon: Icons.bar_chart_outlined,
                                label:
                                    rankSnapshot.hasData &&
                                        rankSnapshot.data != null
                                    ? '${rankSnapshot.data}'
                                    : '—',
                                context: context,
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          _ActionChip(
                            icon: Icons.public_outlined,
                            label:
                                profile?.country != null &&
                                    profile!.country!.isNotEmpty
                                ? countryCodeToName(profile.country!)
                                : '—',
                            context: context,
                          ),
                        ],
                      ),
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

  Future<void> _openProfilePhoto(BuildContext context, String imageUrl) async {
    final resolved = resolvePlayerImagePath(imageUrl);
    if (resolved == null) return;

    final isNetwork =
        resolved.startsWith('http://') || resolved.startsWith('https://');
    if (isNetwork) {
      await precacheImage(playerProfileFullImageProvider(resolved), context);
    }

    if (!context.mounted) return;

    Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black87,
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) {
          return _ProfilePhotoViewerPage(
            heroTag: 'profile-photo-${widget.playerId}',
            imagePath: resolved,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Future<void> _deriveHeroColorsFromImage(String? imagePath) async {
    final key = imagePath?.trim().isNotEmpty == true
        ? imagePath!.trim()
        : '__profile_fallback__';
    final provider =
        (imagePath != null &&
            imagePath.trim().isNotEmpty &&
            (imagePath.startsWith('http://') ||
                imagePath.startsWith('https://')))
        ? appCachedImageProvider(imagePath.trim())
        : (imagePath != null && imagePath.trim().isNotEmpty
              ? AssetImage(imagePath.trim())
              : AssetImage(AppAssets.pitchBg));
    try {
      final scheme = await ColorScheme.fromImageProvider(
        provider: provider,
        brightness: Theme.of(context).brightness,
      );
      if (!mounted || _lastHeroImageKey != key) return;
      setState(() {
        _heroToneA = Color.alphaBlend(
          scheme.primary.withValues(alpha: 0.32),
          scheme.surfaceContainerHigh,
        );
        _heroToneB = Color.alphaBlend(
          scheme.secondary.withValues(alpha: 0.24),
          scheme.surfaceContainer,
        );
        _heroToneC = Color.alphaBlend(
          scheme.tertiary.withValues(alpha: 0.22),
          scheme.surfaceContainerLow,
        );
      });
    } catch (_) {}
  }
}

class _ProfilePhotoViewerPage extends StatelessWidget {
  const _ProfilePhotoViewerPage({
    required this.heroTag,
    required this.imagePath,
  });

  final Object heroTag;
  final String imagePath;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Hero(
            tag: heroTag,
            flightShuttleBuilder: (
              flightContext,
              animation,
              flightDirection,
              fromHeroContext,
              toHeroContext,
            ) {
              final shuttleHero = flightDirection == HeroFlightDirection.push
                  ? toHeroContext.widget as Hero
                  : fromHeroContext.widget as Hero;
              return shuttleHero.child;
            },
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: size.width,
                  maxHeight: size.height,
                ),
                child: buildPlayerProfileFullImage(imagePath: imagePath),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileHeroAvatar extends StatelessWidget {
  const _ProfileHeroAvatar({
    this.imageUrl,
    required this.heroTag,
    this.onTap,
  });

  final String? imageUrl;
  final Object heroTag;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolved = resolvePlayerImagePath(imageUrl);
    final hasImage = resolved != null;

    Widget avatar = Container(
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
      child: ClipOval(
        child: buildPlayerAvatar(
          imagePath: hasImage ? imageUrl : null,
          size: 96,
          backgroundColor: colorScheme.surfaceContainerHighest,
          iconColor: colorScheme.onSurfaceVariant,
        ),
      ),
    );

    if (hasImage) {
      avatar = Hero(
        tag: heroTag,
        flightShuttleBuilder: (
          flightContext,
          animation,
          flightDirection,
          fromHeroContext,
          toHeroContext,
        ) {
          final shuttleHero = flightDirection == HeroFlightDirection.push
              ? toHeroContext.widget as Hero
              : fromHeroContext.widget as Hero;
          return shuttleHero.child;
        },
        child: Material(
          color: Colors.transparent,
          child: avatar,
        ),
      );
      if (onTap != null) {
        avatar = GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: avatar,
        );
      }
    }

    return avatar;
  }
}

// ---------------------------------------------------------------------------
// Profile videos tab – real user videos with sort + grid/feed toggle
// ---------------------------------------------------------------------------

enum _ProfileVideoSort { newest, oldest, mostLiked, mostViewed }

class ProfileVideosTab extends ConsumerStatefulWidget {
  const ProfileVideosTab({
    super.key,
    required this.profilePlayerId,
    required this.isOwnProfile,
  });

  final String profilePlayerId;
  final bool isOwnProfile;

  @override
  ConsumerState<ProfileVideosTab> createState() => _ProfileVideosTabState();
}

class _ProfileVideosTabState extends ConsumerState<ProfileVideosTab> {
  static const int _videosPageSize = 24;

  List<LeagueVideoItem>? _videos;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  _ProfileVideoSort _sortOrder = _ProfileVideoSort.newest;
  bool _isFeedLayout = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<List<Map<String, dynamic>>> _fetchVideosPage(int offset) async {
    final rawVideos = await Supabase.instance.client
        .from('videos')
        .select(
          'id, match_id, uploader_user_id, duration_seconds, '
          'video_url, thumbnail_url, created_at',
        )
        .eq('uploader_user_id', widget.profilePlayerId)
        .order('created_at', ascending: false)
        .range(offset, offset + _videosPageSize - 1);
    return List<Map<String, dynamic>>.from(rawVideos as List);
  }

  Future<void> _load() async {
    final showFullLoader = _videos == null;
    setState(() {
      if (showFullLoader) _isLoading = true;
      _error = null;
    });
    try {
      if (widget.profilePlayerId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _videos = [];
          _hasMore = false;
          _isLoading = false;
        });
        return;
      }
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

  static String _resolveVideoLogo(String? raw) =>
      resolveTeamLogoPath(raw) ?? '';

  List<LeagueVideoItem> get _sortedVideos {
    if (_videos == null) return [];
    final list = List<LeagueVideoItem>.from(_videos!);
    switch (_sortOrder) {
      case _ProfileVideoSort.newest:
        list.sort(
          (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
            a.createdAt ?? DateTime(0),
          ),
        );
      case _ProfileVideoSort.oldest:
        list.sort(
          (a, b) => (a.createdAt ?? DateTime(0)).compareTo(
            b.createdAt ?? DateTime(0),
          ),
        );
      case _ProfileVideoSort.mostLiked:
        list.sort((a, b) => b.likeCount.compareTo(a.likeCount));
      case _ProfileVideoSort.mostViewed:
        list.sort((a, b) => b.viewCount.compareTo(a.viewCount));
    }
    return list;
  }

  String get _sortLabel {
    switch (_sortOrder) {
      case _ProfileVideoSort.newest:
        return 'Newest';
      case _ProfileVideoSort.oldest:
        return 'Oldest';
      case _ProfileVideoSort.mostLiked:
        return 'Most liked';
      case _ProfileVideoSort.mostViewed:
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
    final uploadJobs = ref
        .watch(videoUploadQueueProvider)
        .where((job) => job.uploaderUserId == widget.profilePlayerId)
        .toList();

    ref.listen<List<VideoUploadJob>>(videoUploadQueueProvider, (previous, next) {
      final prevIds = {
        for (final job in previous ?? const <VideoUploadJob>[])
          if (job.uploaderUserId == widget.profilePlayerId) job.id,
      };
      final nextIds = {
        for (final job in next)
          if (job.uploaderUserId == widget.profilePlayerId) job.id,
      };
      if (prevIds.difference(nextIds).isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _load();
        });
      }
    });

    if (_isLoading && uploadJobs.isEmpty) {
      return const ProfileVideosTabShimmer();
    }
    if (_error != null && uploadJobs.isEmpty) {
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
    final hasContent = uploadJobs.isNotEmpty || sorted.isNotEmpty;

    return RefreshIndicator(
      onRefresh: _load,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                PopupMenuButton<_ProfileVideoSort>(
                  onSelected: (v) => setState(() => _sortOrder = v),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: _ProfileVideoSort.newest,
                      child: Text('Newest'),
                    ),
                    PopupMenuItem(
                      value: _ProfileVideoSort.oldest,
                      child: Text('Oldest'),
                    ),
                    PopupMenuItem(
                      value: _ProfileVideoSort.mostLiked,
                      child: Text('Most liked'),
                    ),
                    PopupMenuItem(
                      value: _ProfileVideoSort.mostViewed,
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
          if (!hasContent)
            Expanded(
              child: Center(
                child: AppEmptyState(
                  imageAsset: AppAssets.videosAltEmpty,
                  title: 'No videos yet',
                  subtitle: widget.isOwnProfile
                      ? 'Upload your first highlight from a completed match to build your video profile.'
                      : 'This player has not uploaded any highlights yet.',
                ),
              ),
            )
          else if (_isFeedLayout)
            Expanded(child: _buildFeedView(sorted, uploadJobs))
          else
            Expanded(child: _buildGridView(sorted, uploadJobs)),
        ],
      ),
    );
  }

  Widget _buildGridView(
    List<LeagueVideoItem> videos,
    List<VideoUploadJob> uploadJobs,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final jobCount = uploadJobs.length;
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 121.33 / 204,
      ),
      itemCount: jobCount + videos.length,
      itemBuilder: (context, index) {
        if (index < jobCount) {
          return _buildUploadingGridTile(uploadJobs[index]);
        }
        final videoIndex = index - jobCount;
        _maybeRequestMore(videoIndex, videos.length);
        final v = videos[videoIndex];
        return GestureDetector(
          onTap: () => _openVideoPlayer(videoIndex),
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

  Widget _buildUploadingGridTile(VideoUploadJob job) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: job.isFailed
          ? () => ref.read(videoUploadQueueProvider.notifier).dismiss(job.id)
          : null,
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
              _buildJobThumbnail(job),
              VideoUploadProgressOverlay(job: job, compact: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedView(
    List<LeagueVideoItem> videos,
    List<VideoUploadJob> uploadJobs,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final jobCount = uploadJobs.length;
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: jobCount + videos.length,
      itemBuilder: (context, index) {
        if (index < jobCount) {
          return _buildUploadingFeedTile(uploadJobs[index]);
        }
        final videoIndex = index - jobCount;
        _maybeRequestMore(videoIndex, videos.length);
        final v = videos[videoIndex];
        return GestureDetector(
          onTap: () => _openVideoPlayer(videoIndex),
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
                      _ProfileFeedLogo(logoPath: v.teamALogo, size: 24),
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
                      _ProfileFeedLogo(logoPath: v.teamBLogo, size: 24),
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
                      Icon(
                        Icons.favorite,
                        size: 16,
                        color: v.isLiked
                            ? Colors.red
                            : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text('${v.likeCount}', style: textTheme.bodySmall),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.visibility,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text('${v.viewCount}', style: textTheme.bodySmall),
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

  Widget _buildUploadingFeedTile(VideoUploadJob job) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: job.isFailed
          ? () => ref.read(videoUploadQueueProvider.notifier).dismiss(job.id)
          : null,
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
                  _ProfileFeedLogo(logoPath: job.teamALogo, size: 24),
                  const SizedBox(width: 6),
                  Text(
                    job.teamAShort,
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${job.teamAScore} - ${job.teamBScore}',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    job.teamBShort,
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  _ProfileFeedLogo(logoPath: job.teamBLogo, size: 24),
                ],
              ),
            ),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildJobThumbnail(job),
                    VideoUploadProgressOverlay(job: job),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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

  Widget _buildJobThumbnail(VideoUploadJob job) {
    final bytes = job.thumbnailBytes;
    if (bytes != null && bytes.isNotEmpty) {
      return Positioned.fill(
        child: Image.memory(bytes, fit: BoxFit.cover),
      );
    }
    return Positioned.fill(child: videoThumbnailPlaceholder(context));
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _ProfileFeedLogo extends StatelessWidget {
  const _ProfileFeedLogo({required this.logoPath, this.size = 24});
  final String logoPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: buildTeamLogo(
          logoPath.isEmpty ? null : logoPath,
          size: size,
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData? icon;
  final String? svgPath;
  final String label;
  final BuildContext context;

  const _ActionChip({
    this.icon,
    this.svgPath,
    required this.label,
    required this.context,
  }) : assert(
         icon != null || svgPath != null,
         'Either icon or svgPath must be provided',
       );

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Color foreground = colorScheme.onSurface;

    Widget avatar;
    if (svgPath != null) {
      avatar = SvgPicture.asset(
        svgPath!,
        width: 18,
        height: 18,
        colorFilter: ColorFilter.mode(foreground, BlendMode.srcIn),
      );
    } else {
      avatar = Icon(icon, size: 18, color: foreground);
    }

    return ActionChip.elevated(
      avatar: avatar,
      label: Text(label, style: TextStyle(color: foreground)),
      onPressed: () {},
      backgroundColor: colorScheme.surfaceContainerHighest,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999), // Fully rounded
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}
