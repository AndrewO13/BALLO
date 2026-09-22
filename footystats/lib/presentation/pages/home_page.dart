import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/adaptive/adaptive.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/guest_mode.dart';
import '../../core/utils/scroll_to_top.dart';
import '../../core/widgets/progress_ring.dart';
import '../../data/repositories/leagues_repository.dart';
import '../../data/repositories/profile_scout_views_repository.dart';
import '../../data/repositories/teams_repository.dart';
import '../../data/repositories/user_profile_repository.dart';
import '../../domain/models/league_model.dart';
import '../../domain/models/team_model.dart';
import '../../domain/models/user_profile.dart';
import '../widgets/app_search_page.dart';
import '../widgets/home/challenge_widget.dart';
import '../widgets/home/gameweek_header.dart';
import '../widgets/home/home_page_shimmer.dart';
import '../widgets/home/home_section_empty_state.dart';
import '../widgets/home/match_card.dart';
import '../widgets/home/team_chip.dart';
import '../widgets/home/performance_chart.dart';
import '../widgets/match_date_picker_dialog.dart';
import 'fixture.dart';
import 'guest_home_page.dart';
import 'guest_profile_page.dart';
import 'favourites_page.dart';
import 'matches.dart';
import 'create_team_league_page.dart';
import '../providers/favourited_leagues_provider.dart';
import '../providers/main_nav_scroll_provider.dart';
import '../providers/matches_provider.dart';
import 'leaderboard.dart';
import 'explore.dart';
import 'player_comparison_page.dart';
import 'profile.dart';
import 'settings.dart';
import 'staff_profile_page.dart';
import 'scout_views_page.dart';
import 'team_detail_page.dart';
import 'notifications_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver {
  static const Map<String, String> _attributeLabels = {
    'tackles': 'Tackles won',
    'assists': 'Assists',
    'clean_sheets': 'Clean sheets',
    'goals': 'Goals',
    'shots_on_target': 'Shots on target',
    'saves': 'Saves',
  };

  /// Position-specific metrics for progress rings
  static const Map<String, List<String>> _positionMetrics = {
    'defender': ['tackles', 'assists', 'clean_sheets'],
    'attacker': ['goals', 'assists', 'shots_on_target'],
    'midfielder': ['assists', 'goals', 'tackles'],
    'goalkeeper': ['saves', 'clean_sheets', 'assists'],
  };

  int _selectedIndex = 0;
  int _matchesActivationNonce = 0;
  int _badgeTrackerRefreshTick = 0;
  final ScrollController _playerHomeScrollController = ScrollController();
  final CarouselController _matchCarouselController = CarouselController();
  final UserProfileRepository _profileRepository = UserProfileRepository();

  UserProfile? _profile;
  String? _playerPosition;
  bool _isLoadingProfile = true;
  bool _isLoadingFocus = true;
  bool _isLoadingPerformanceRatings = false;
  _FocusRingConfig _focusConfig = _FocusRingConfig.defaults();
  _WeeklyAttributeStats _weeklyStats = _WeeklyAttributeStats.empty();
  List<PerformanceGameweekRating> _performanceGameweekRatings = [];
  bool _isLoadingGameweekContext = false;
  List<_GameweekOption> _homeGameweeks = [];
  String? _selectedHomeGameweekId;

  bool _isLoadingUserTeams = true;
  List<TeamModel> _userTeams = [];
  String? _homeSelectedTeamId;
  final TeamsRepository _teamsRepository = TeamsRepository();
  final LeaguesRepository _leaguesRepository = LeaguesRepository();

  bool _isLoadingTeamStandings = false;
  List<LeagueModel> _selectedTeamLeagues = [];
  String? _selectedTeamLeagueId;
  List<_TeamStandingRow> _selectedLeagueStandings = [];
  final Map<String, Future<_HomeTeamSummary>> _teamSummaryFutures = {};

  static const _homeRingsPollInterval = Duration(seconds: 25);
  static const _ringsRealtimeDebounce = Duration(milliseconds: 450);

  Timer? _homeRingsPollTimer;
  Timer? _ringsRealtimeDebounceTimer;
  StreamSubscription<List<Map<String, dynamic>>>? _matchPlayerStatsSub;
  String? _matchPlayerStatsStreamPlayerId;

  Stream<List<Map<String, dynamic>>> _pendingInvitesStream() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      return Stream<List<Map<String, dynamic>>>.value(const []);
    }
    return Supabase.instance.client
        .from('team_player_invites')
        .stream(primaryKey: ['id'])
        .map(
          (rows) => rows.where((row) {
            final playerId = row['player_id']?.toString() ?? '';
            final status = row['status']?.toString() ?? '';
            final readAt = row['read_at'];
            return playerId == userId && status == 'pending' && readAt == null;
          }).toList(),
        );
  }

  Stream<int> _unreadScoutViewsStream() {
    return ProfileScoutViewsRepository().unreadCountForCurrentUser();
  }

  /// Guests (anonymous sessions) are fans: no profile, focus rings or teams.
  bool get _isGuest => GuestMode.isGuest;

  bool get _isStaff => _profile?.isTechnicalStaff == true;

  /// Guest and technical-staff shells share Home / Favourites instead of Matches.
  bool get _useFanShell => _isGuest || _isStaff;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_isGuest) {
      _isLoadingProfile = false;
      _isLoadingFocus = false;
      _isLoadingUserTeams = false;
    } else {
      _loadProfile();
    }
  }

  /// Get the available metrics for the player's position
  List<String> _getAvailableMetrics(String? position) {
    final pos = (position ?? '').toLowerCase();
    return _positionMetrics[pos] ?? _positionMetrics['defender']!;
  }

  void _cancelMatchPlayerStatsSubscription() {
    _matchPlayerStatsSub?.cancel();
    _matchPlayerStatsSub = null;
    _matchPlayerStatsStreamPlayerId = null;
  }

  void _scheduleRingsRefreshFromRealtime() {
    _ringsRealtimeDebounceTimer?.cancel();
    _ringsRealtimeDebounceTimer = Timer(_ringsRealtimeDebounce, () {
      if (!mounted || _selectedIndex != 0) return;
      _loadWeeklyStatsForCurrentSelection();
      _loadPerformanceRatingsForCurrentSelection();
    });
  }

  void _ensureMatchPlayerStatsLiveSubscription() {
    final user = Supabase.instance.client.auth.currentUser;
    final teamId = _homeSelectedTeamId;
    if (user == null || teamId == null || teamId.isEmpty || user.id.isEmpty) {
      _cancelMatchPlayerStatsSubscription();
      return;
    }
    if (_matchPlayerStatsSub != null &&
        _matchPlayerStatsStreamPlayerId == user.id) {
      return;
    }
    _cancelMatchPlayerStatsSubscription();
    _matchPlayerStatsStreamPlayerId = user.id;
    try {
      _matchPlayerStatsSub = Supabase.instance.client
          .from('match_player_stats')
          .stream(primaryKey: ['match_id', 'player_id'])
          .eq('player_id', user.id)
          .listen(
            (_) {
              if (!mounted || _selectedIndex != 0) return;
              _scheduleRingsRefreshFromRealtime();
            },
            onError: (_) {
              // Realtime may be off for this table; polling still updates rings.
            },
          );
    } catch (_) {
      _matchPlayerStatsStreamPlayerId = null;
    }
  }

  void _startHomeRingsPolling() {
    _homeRingsPollTimer?.cancel();
    _homeRingsPollTimer = Timer.periodic(_homeRingsPollInterval, (_) {
      if (!mounted || _selectedIndex != 0) return;
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null || _homeSelectedTeamId == null) return;
      _loadWeeklyStatsForCurrentSelection();
      _loadPerformanceRatingsForCurrentSelection();
    });
  }

  void _stopHomeRingsPolling() {
    _homeRingsPollTimer?.cancel();
    _homeRingsPollTimer = null;
  }

  /// Attach Supabase stream; start poll timer only when Home tab is selected.
  void _startHomeRingsLiveUpdates() {
    _ensureMatchPlayerStatsLiveSubscription();
    if (_selectedIndex == 0) {
      _startHomeRingsPolling();
    }
  }

  void _onHomeTabBecameVisible() {
    if (_isGuest || _isStaff) return;
    _ensureMatchPlayerStatsLiveSubscription();
    _startHomeRingsPolling();
    _loadWeeklyStatsForCurrentSelection();
    _loadPerformanceRatingsForCurrentSelection();
  }

  /// Minimum time between automatic full refreshes when returning to Home.
  /// Pull-to-refresh always refreshes regardless of this throttle.
  static const _homeTabRefreshThrottle = Duration(minutes: 2);
  DateTime? _lastHomeTabAutoRefreshAt;

  Future<void> _onHomeTabBecameVisibleWithRefresh() async {
    if (_isGuest || _isStaff) return;
    // Refresh home data when returning to the home tab, but throttle so that
    // quick tab hopping doesn't refetch everything each time.
    final now = DateTime.now();
    final last = _lastHomeTabAutoRefreshAt;
    if (last == null || now.difference(last) >= _homeTabRefreshThrottle) {
      _lastHomeTabAutoRefreshAt = now;
      await _refreshHomePage();
    }
    _onHomeTabBecameVisible();
  }

  void _onHomeTabBecameHidden() {
    _stopHomeRingsPolling();
    _ringsRealtimeDebounceTimer?.cancel();
    _ringsRealtimeDebounceTimer = null;
    _cancelMatchPlayerStatsSubscription();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isGuest || _isStaff) return;
    if (state == AppLifecycleState.resumed && mounted && _selectedIndex == 0) {
      _loadWeeklyStatsForCurrentSelection();
      _loadPerformanceRatingsForCurrentSelection();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _onHomeTabBecameHidden();
    _ringsRealtimeDebounceTimer?.cancel();
    _playerHomeScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _profileRepository.getCurrentProfile();
      if (!mounted) return;
      final staff = profile?.isTechnicalStaff == true;
      setState(() {
        _profile = profile;
        _playerPosition = profile?.position;
        _isLoadingProfile = false;
        if (staff) {
          _isLoadingFocus = false;
          _isLoadingUserTeams = false;
        }
      });
      if (!staff) {
        _loadFocusRingData();
        _loadUserTeams();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _loadFocusRingData() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() => _isLoadingFocus = false);
      return;
    }

    try {
      final row = await client
          .from('players')
          .select('focus_ring_config, position')
          .eq('id', user.id)
          .maybeSingle();
      final position = row is Map<String, dynamic>
          ? row['position']?.toString()
          : null;
      final config = _FocusRingConfig.fromMetadata(
        row is Map<String, dynamic> ? row['focus_ring_config'] : null,
        position: position ?? _playerPosition ?? _profile?.position,
      );

      if (!mounted) return;
      setState(() {
        _focusConfig = config;
        _playerPosition = position ?? _playerPosition;
        _isLoadingFocus = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoadingFocus = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load focus settings: $error')),
      );
    }
  }

  double _ringProgressFor(String key) {
    final target = _focusConfig.targets[key] ?? 1;
    final value = _weeklyStats.valueFor(key);
    if (target <= 0) return 0;
    return (value / target).clamp(0.0, 1.0);
  }

  Widget _attributeIcon(String key) {
    switch (key) {
      case 'assists':
        return SvgPicture.asset(AppAssets.assistIcon, fit: BoxFit.contain);
      case 'clean_sheets':
        return Image.asset(AppAssets.cleanSheet, fit: BoxFit.contain);
      case 'goals':
        return SvgPicture.asset(AppAssets.goalIcon, fit: BoxFit.contain);
      case 'shots_on_target':
        return const Icon(Icons.sports_soccer_outlined);
      case 'saves':
        return const Icon(Icons.pan_tool_outlined);
      case 'tackles':
      default:
        return SvgPicture.asset(AppAssets.tackleIcon, fit: BoxFit.contain);
    }
  }

  Future<void> _openFocusCustomization() async {
    final availableMetrics = _getAvailableMetrics(
      _playerPosition ?? _profile?.position,
    );
    final updated = await Navigator.of(context).push<_FocusRingConfig>(
      MaterialPageRoute(
        builder: (_) => _FocusCustomizationPage(
          config: _focusConfig,
          availableMetrics: availableMetrics,
        ),
      ),
    );
    if (updated == null) return;
    setState(() {
      _focusConfig = updated;
    });
    await _saveFocusRingConfig(updated);
  }

  Future<void> _saveFocusRingConfig(_FocusRingConfig config) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;
    try {
      final updated = await client
          .from('players')
          .update({'focus_ring_config': config.toMetadata()})
          .eq('id', user.id)
          .select('id')
          .maybeSingle();
      if (updated == null) {
        await client.from('players').insert({
          'id': user.id,
          'focus_ring_config': config.toMetadata(),
        });
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save focus targets: $error')),
      );
    }
  }

  Future<void> _loadUserTeams() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      _cancelMatchPlayerStatsSubscription();
      _stopHomeRingsPolling();
      setState(() {
        _isLoadingUserTeams = false;
        _userTeams = const [];
        _homeSelectedTeamId = null;
        _selectedTeamLeagues = [];
        _selectedTeamLeagueId = null;
        _selectedLeagueStandings = [];
      });
      return;
    }

    setState(() {
      _isLoadingUserTeams = true;
    });

    try {
      var teams = await _teamsRepository.getTeamsForUser(user.id);
      teams = List<TeamModel>.of(teams)
        ..sort(
          (a, b) => a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          ),
        );
      if (!mounted) return;
      setState(() {
        _userTeams = teams;
        final valid =
            _homeSelectedTeamId != null &&
            teams.any((t) => t.id == _homeSelectedTeamId);
        if (!valid) {
          _homeSelectedTeamId = teams.isNotEmpty ? teams.first.id : null;
        }
        _isLoadingUserTeams = false;
      });
      final selectedTeamId = _homeSelectedTeamId;
      if (selectedTeamId != null) {
        await _loadTeamStandingsContext(teamId: selectedTeamId);
      } else {
        _cancelMatchPlayerStatsSubscription();
        _stopHomeRingsPolling();
      }
    } catch (_) {
      if (!mounted) return;
      _cancelMatchPlayerStatsSubscription();
      _stopHomeRingsPolling();
      setState(() {
        _isLoadingUserTeams = false;
        _userTeams = const [];
        _homeSelectedTeamId = null;
        _selectedTeamLeagues = [];
        _selectedTeamLeagueId = null;
        _selectedLeagueStandings = [];
      });
    }
  }

  Future<void> _loadTeamStandingsContext({
    required String teamId,
    String? preferredLeagueId,
  }) async {
    setState(() {
      _isLoadingTeamStandings = true;
    });
    try {
      final leagues = await _leaguesRepository.getLeaguesForTeam(teamId);
      final bool canKeepCurrentLeague =
          preferredLeagueId != null &&
          leagues.any((league) => league.id == preferredLeagueId);
      final String? nextLeagueId = canKeepCurrentLeague
          ? preferredLeagueId
          : (leagues.isNotEmpty ? leagues.first.id : null);

      List<_TeamStandingRow> standings = [];
      if (nextLeagueId != null) {
        final rows = await _leaguesRepository.getLeagueStandings(nextLeagueId);
        standings = _normalizeStandingsRows(
          rows.map(_TeamStandingRow.fromStandingsRpc).toList(),
        );
      }

      if (!mounted) return;
      setState(() {
        _selectedTeamLeagues = leagues;
        _selectedTeamLeagueId = nextLeagueId;
        _selectedLeagueStandings = standings;
        _isLoadingTeamStandings = false;
      });
      await _loadHomeGameweekContext(
        teamId: teamId,
        preferredLeagueId: nextLeagueId,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _selectedTeamLeagues = [];
        _selectedTeamLeagueId = null;
        _selectedLeagueStandings = [];
        _isLoadingTeamStandings = false;
      });
      await _loadHomeGameweekContext(teamId: teamId, preferredLeagueId: null);
    }
  }

  Future<void> _loadHomeGameweekContext({
    required String teamId,
    String? preferredLeagueId,
  }) async {
    final client = Supabase.instance.client;
    setState(() => _isLoadingGameweekContext = true);
    try {
      var query = client
          .from('matches')
          .select('gameweek, status, gameweek_rel:gameweeks!inner(id, week)')
          .or('teamA.eq.$teamId,teamB.eq.$teamId');
      if (preferredLeagueId != null && preferredLeagueId.isNotEmpty) {
        query = query.eq('league_id', preferredLeagueId);
      }
      final res = await query;
      final list = List<Map<String, dynamic>>.from(res as List);

      // Separate into finished and all gameweeks
      final finishedByIdMap = <String, _GameweekOption>{};
      final allByIdMap = <String, _GameweekOption>{};

      for (final row in list) {
        final rel = row['gameweek_rel'];
        final relMap = rel is Map
            ? Map<String, dynamic>.from(rel)
            : <String, dynamic>{};
        final id =
            relMap['id']?.toString() ?? row['gameweek']?.toString() ?? '';
        final week = int.tryParse(relMap['week']?.toString() ?? '');
        if (id.isEmpty || week == null) continue;

        final gameweekOption = _GameweekOption(id: id, week: week);
        allByIdMap[id] = gameweekOption;

        // Only add to finished if match status is 'fullTime'
        final status = row['status']?.toString() ?? '';
        if (status == 'fullTime') {
          finishedByIdMap[id] = gameweekOption;
        }
      }

      final gameweeks = allByIdMap.values.toList()
        ..sort((a, b) => a.week.compareTo(b.week));

      // Select the last finished gameweek, or fall back to last gameweek if none are finished
      String? selected;
      if (finishedByIdMap.isNotEmpty) {
        final finishedGameweeks = finishedByIdMap.values.toList()
          ..sort((a, b) => a.week.compareTo(b.week));
        selected = finishedGameweeks.last.id;
      } else if (gameweeks.isNotEmpty) {
        selected = gameweeks.last.id;
      }

      if (!mounted) return;
      setState(() {
        _homeGameweeks = gameweeks;
        _selectedHomeGameweekId = selected;
        _isLoadingGameweekContext = false;
      });
      await _loadWeeklyStatsForCurrentSelection();
      await _loadPerformanceRatingsForCurrentSelection();
      if (mounted) {
        _startHomeRingsLiveUpdates();
      }
    } catch (_) {
      if (!mounted) return;
      _cancelMatchPlayerStatsSubscription();
      setState(() {
        _homeGameweeks = const [];
        _selectedHomeGameweekId = null;
        _weeklyStats = _WeeklyAttributeStats.empty();
        _performanceGameweekRatings = const [];
        _isLoadingGameweekContext = false;
      });
    }
  }

  Future<void> _loadWeeklyStatsForCurrentSelection() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    final teamId = _homeSelectedTeamId;
    if (user == null || teamId == null || teamId.isEmpty) {
      if (!mounted) return;
      setState(() => _weeklyStats = _WeeklyAttributeStats.empty());
      return;
    }

    try {
      var query = client
          .from('match_player_stats')
          .select(
            'tackles, assists, clean_sheets, goals, shots_on_target, saves, match:matches!inner(gameweek, league_id, status)',
          )
          .eq('player_id', user.id)
          .eq('team_id', teamId)
          .eq('match.status', 'fullTime');
      final leagueId = _selectedTeamLeagueId;
      if (leagueId != null && leagueId.isNotEmpty) {
        query = query.eq('match.league_id', leagueId);
      }
      final gameweekId = _selectedHomeGameweekId;
      if (gameweekId != null && gameweekId.isNotEmpty) {
        query = query.eq('match.gameweek', gameweekId);
      }
      final rows = await query;
      final stats = _WeeklyAttributeStats.fromRows(rows);
      if (!mounted) return;
      setState(() => _weeklyStats = stats);
    } catch (_) {
      if (!mounted) return;
      setState(() => _weeklyStats = _WeeklyAttributeStats.empty());
    }
  }

  Future<void> _loadPerformanceRatingsForCurrentSelection() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    final teamId = _homeSelectedTeamId;
    if (user == null || teamId == null || teamId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _performanceGameweekRatings = const [];
      });
      return;
    }

    setState(() => _isLoadingPerformanceRatings = true);
    try {
      var query = client
          .from('match_player_stats')
          .select(
            'rating, match:matches!inner(gameweek, league_id, status, gameweek_rel:gameweeks!inner(week))',
          )
          .eq('player_id', user.id)
          .eq('team_id', teamId)
          .eq('match.status', 'fullTime')
          .not('rating', 'is', null);
      final leagueId = _selectedTeamLeagueId;
      if (leagueId != null && leagueId.isNotEmpty) {
        query = query.eq('match.league_id', leagueId);
      }
      final rows = await query;
      final ratingBuckets = <int, List<double>>{};
      for (final row in List<Map<String, dynamic>>.from(rows as List)) {
        final match = row['match'];
        if (match is! Map) continue;
        final matchMap = Map<String, dynamic>.from(match);
        final gwRel = matchMap['gameweek_rel'];
        if (gwRel is! Map) continue;
        final gwMap = Map<String, dynamic>.from(gwRel);
        final week = int.tryParse(gwMap['week']?.toString() ?? '');
        final rating = double.tryParse(row['rating']?.toString() ?? '');
        if (week == null || rating == null) continue;
        ratingBuckets.putIfAbsent(week, () => <double>[]).add(rating);
      }

      final sortedWeeks = ratingBuckets.keys.toList()..sort();
      final selectedWeeks = sortedWeeks.length > 8
          ? sortedWeeks.sublist(sortedWeeks.length - 8)
          : sortedWeeks;
      final data = selectedWeeks
          .map((week) {
            final values = ratingBuckets[week] ?? const <double>[];
            if (values.isEmpty) return null;
            final sum = values.fold<double>(0, (acc, v) => acc + v);
            final avg = sum / values.length;
            return PerformanceGameweekRating(
              gameweek: week,
              rating: avg.clamp(0.0, 10.0),
            );
          })
          .whereType<PerformanceGameweekRating>()
          .toList();

      if (!mounted) return;
      setState(() {
        _performanceGameweekRatings = data;
        _isLoadingPerformanceRatings = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _performanceGameweekRatings = const [];
        _isLoadingPerformanceRatings = false;
      });
    }
  }

  _GameweekOption? get _selectedGameweekOption {
    final id = _selectedHomeGameweekId;
    if (id == null) return null;
    for (final option in _homeGameweeks) {
      if (option.id == id) return option;
    }
    return null;
  }

  String get _gameweekHeaderText {
    if (_isLoadingGameweekContext) return 'Gameweek —';
    final selected = _selectedGameweekOption;
    if (selected == null) return 'Gameweek —';
    return 'Gameweek ${selected.week}';
  }

  void _onPreviousGameweek() {
    final selectedId = _selectedHomeGameweekId;
    if (selectedId == null) return;
    final index = _homeGameweeks.indexWhere((gw) => gw.id == selectedId);
    if (index <= 0) return;
    setState(() => _selectedHomeGameweekId = _homeGameweeks[index - 1].id);
    _loadWeeklyStatsForCurrentSelection();
  }

  void _onNextGameweek() {
    final selectedId = _selectedHomeGameweekId;
    if (selectedId == null) return;
    final index = _homeGameweeks.indexWhere((gw) => gw.id == selectedId);
    if (index < 0 || index >= _homeGameweeks.length - 1) return;
    setState(() => _selectedHomeGameweekId = _homeGameweeks[index + 1].id);
    _loadWeeklyStatsForCurrentSelection();
  }

  bool get _canGoToPreviousGameweek {
    final selectedId = _selectedHomeGameweekId;
    if (selectedId == null) return false;
    final index = _homeGameweeks.indexWhere((gw) => gw.id == selectedId);
    return index > 0;
  }

  bool get _canGoToNextGameweek {
    final selectedId = _selectedHomeGameweekId;
    if (selectedId == null) return false;
    final index = _homeGameweeks.indexWhere((gw) => gw.id == selectedId);
    return index >= 0 && index < _homeGameweeks.length - 1;
  }

  List<_TeamStandingRow> _normalizeStandingsRows(List<_TeamStandingRow> input) {
    if (input.isEmpty) return input;
    if (input.isNotEmpty && input.every((r) => r.position > 0)) {
      return List<_TeamStandingRow>.of(input)
        ..sort((a, b) => a.position.compareTo(b.position));
    }
    // Older RPC: no [position] column; derive rank from sort order and drop movement.
    final copy = List<_TeamStandingRow>.of(input);
    copy.sort((a, b) {
      if (a.points != b.points) {
        return b.points.compareTo(a.points);
      }
      if (a.goalDiff != b.goalDiff) {
        return b.goalDiff.compareTo(a.goalDiff);
      }
      return a.teamId.compareTo(b.teamId);
    });
    return [
      for (var i = 0; i < copy.length; i++)
        copy[i].withPosition(i + 1, positionChange: 0),
    ];
  }

  List<_TeamStandingRow> _contextRowsForTeam(
    List<_TeamStandingRow> rows,
    String teamId,
  ) {
    if (rows.length <= 3) return rows;
    final index = rows.indexWhere((row) => row.teamId == teamId);
    if (index < 0) return rows.take(3).toList();
    if (index <= 2) return rows.take(3).toList();
    if (index >= rows.length - 3) return rows.sublist(rows.length - 3);
    return rows.sublist(index - 1, index + 2);
  }

  TeamModel? get _homeSelectedTeam {
    final id = _homeSelectedTeamId;
    if (id == null) return null;
    for (final t in _userTeams) {
      if (t.id == id) return t;
    }
    return null;
  }

  Future<_HomeTeamSummary> _loadHomeTeamSummary(String teamId) async {
    final client = Supabase.instance.client;

    final teamRes = await client
        .from('teams')
        .select('created_at')
        .eq('id', teamId)
        .maybeSingle();
    final createdAt = DateTime.tryParse(
      teamRes?['created_at']?.toString() ?? '',
    );
    final estYear = createdAt?.year;

    final matchesRes = await client
        .from('matches')
        .select('teamA, teamB, teamA_score, teamB_score')
        .eq('status', 'fullTime')
        .or('teamA.eq.$teamId,teamB.eq.$teamId');
    final matchRows = List<Map<String, dynamic>>.from(matchesRes as List);
    final totalMatchesPlayed = matchRows.length;
    var totalGoalsScored = 0;
    for (final row in matchRows) {
      final teamA = row['teamA']?.toString();
      final teamB = row['teamB']?.toString();
      final scoreA = (row['teamA_score'] as num?)?.toInt() ?? 0;
      final scoreB = (row['teamB_score'] as num?)?.toInt() ?? 0;
      if (teamA == teamId) totalGoalsScored += scoreA;
      if (teamB == teamId) totalGoalsScored += scoreB;
    }

    var totalTrophies = 0;
    final membershipsRes = await client
        .from('league_team_memberships')
        .select('league_id')
        .eq('team_id', teamId);
    final leagueIds = (membershipsRes as List)
        .map((r) => (r as Map)['league_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (leagueIds.isNotEmpty) {
      final seasonsRes = await client
          .from('seasons')
          .select('id, league_id')
          .inFilter('league_id', leagueIds)
          .eq('status', 'ended');
      final seasons = List<Map<String, dynamic>>.from(seasonsRes as List);
      for (final season in seasons) {
        final seasonId = season['id']?.toString() ?? '';
        if (seasonId.isEmpty) continue;
        final winner = await _didTeamWinSeason(
          teamId: teamId,
          seasonId: seasonId,
        );
        if (winner) totalTrophies++;
      }
    }

    return _HomeTeamSummary(
      estYear: estYear,
      totalGoalsScored: totalGoalsScored,
      totalMatchesPlayed: totalMatchesPlayed,
      totalTrophies: totalTrophies,
    );
  }

  Future<bool> _didTeamWinSeason({
    required String teamId,
    required String seasonId,
  }) async {
    final client = Supabase.instance.client;
    final matchesRes = await client
        .from('matches')
        .select('teamA, teamB, teamA_score, teamB_score')
        .eq('season_id', seasonId)
        .eq('status', 'fullTime');
    final rows = List<Map<String, dynamic>>.from(matchesRes as List);
    if (rows.isEmpty) return false;

    final byTeam = <String, _HomeTeamStandingsAgg>{};
    _HomeTeamStandingsAgg aggFor(String id) =>
        byTeam.putIfAbsent(id, () => _HomeTeamStandingsAgg());

    for (final row in rows) {
      final aId = row['teamA']?.toString();
      final bId = row['teamB']?.toString();
      if (aId == null || aId.isEmpty || bId == null || bId.isEmpty) continue;
      final aScore = (row['teamA_score'] as num?)?.toInt() ?? 0;
      final bScore = (row['teamB_score'] as num?)?.toInt() ?? 0;
      final a = aggFor(aId);
      final b = aggFor(bId);
      a.played++;
      b.played++;
      a.gf += aScore;
      a.ga += bScore;
      b.gf += bScore;
      b.ga += aScore;
      if (aScore > bScore) {
        a.points += 3;
      } else if (bScore > aScore) {
        b.points += 3;
      } else {
        a.points += 1;
        b.points += 1;
      }
    }

    if (byTeam.isEmpty) return false;
    final sorted = byTeam.entries.toList()
      ..sort((a, b) {
        final points = b.value.points.compareTo(a.value.points);
        if (points != 0) return points;
        final gd = b.value.goalDiff.compareTo(a.value.goalDiff);
        if (gd != 0) return gd;
        final gf = b.value.gf.compareTo(a.value.gf);
        if (gf != 0) return gf;
        return a.key.compareTo(b.key);
      });
    return sorted.first.key == teamId;
  }

  Future<_HomeTeamSummary> _summaryForTeam(String teamId) {
    return _teamSummaryFutures.putIfAbsent(
      teamId,
      () => _loadHomeTeamSummary(teamId),
    );
  }

  Future<void> _openFindTeamSearch() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const AppSearchPage()),
    );
    if (!mounted) return;
    await _loadUserTeams();
  }

  Future<void> _openCreateTeam() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const CreateTeamOrLeaguePage()),
    );
    if (!mounted) return;
    await _loadUserTeams();
  }

  Future<void> _refreshHomePage() async {
    if (_isGuest || _isStaff) {
      await _loadProfile();
      return;
    }
    await Future.wait([
      _loadProfile(),
      _loadFocusRingData(),
      _loadUserTeams(),
      ref.refresh(homeThisWeekMatchesProvider.future),
    ]);
    if (mounted) {
      setState(() => _badgeTrackerRefreshTick++);
    }
  }

  bool get _showHomeShimmer =>
      _isLoadingProfile ||
      _isLoadingFocus ||
      _isLoadingUserTeams ||
      _isLoadingGameweekContext;

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(
      mainNavScrollToTopProvider.select((m) => m[MainNavTab.home] ?? 0),
      (previous, next) {
        if (previous == next || _useFanShell || _selectedIndex != MainNavTab.home) {
          return;
        }
        animateScrollControllerToTop(_playerHomeScrollController);
      },
    );

    final PreferredSizeWidget appBar = _buildAppBar(context);

    return Scaffold(
      appBar: appBar,
      floatingActionButton: ((_isStaff && _selectedIndex == 0) ||
              (!_useFanShell && _selectedIndex == 1))
          ? FloatingActionButton(
              onPressed: _openCreateTeamOrLeague,
              tooltip: 'Add',
              child: const Icon(Icons.add),
            )
          : null,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          if (_useFanShell)
            GuestHomeContent(
              activationNonce: _matchesActivationNonce,
              heading: _isStaff
                  ? 'Welcome to the sidelines!'
                  : 'Welcome to the stands!',
              subtitle: _isStaff
                  ? 'Create teams, run leagues, and keep an eye on the players that matter'
                  : 'All the action, none of the running',
            )
          else
            _buildHomeContent(context),
          if (_useFanShell)
            const FavouritesPage()
          else
            MatchesPage(
              activationNonce: _matchesActivationNonce,
              mainNavTabIndex: MainNavTab.secondary,
            ),
          LeaderboardPage(
            isCurrentNavTab: _selectedIndex == 2,
            isGuest: _useFanShell,
          ),
          ExplorePage(isActiveTab: _selectedIndex == 3),
          if (_isGuest)
            const GuestProfilePage()
          else if (_isStaff)
            const StaffProfilePage()
          else
            ProfilePage(), // Cannot be const due to DefaultTabController
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  void _openCreateTeamOrLeague() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CreateTeamOrLeaguePage(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    if (_selectedIndex == 0 && _useFanShell) {
      return AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        centerTitle: false,
        title: SizedBox(
          height: 32,
          child: SvgPicture.asset(
            AppAssets.balloLogo,
            height: 32,
            fit: BoxFit.contain,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Go to date',
            onPressed: () async {
              final matchDates = <DateTime>{};
              try {
                final matches = await ref.read(matchesProvider.future);
                for (final match in matches) {
                  matchDates.add(
                    DateTime(
                      match.matchDate.year,
                      match.matchDate.month,
                      match.matchDate.day,
                    ),
                  );
                }
              } catch (_) {}
              final picked = await showMatchAwareDatePicker(
                context,
                matchDates: matchDates,
              );
              if (picked == null || !context.mounted) return;
              ref
                  .read(selectedMatchesCalendarDateProvider.notifier)
                  .setDate(DateTime(picked.year, picked.month, picked.day));
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AppSearchPage(),
                ),
              );
            },
          ),
        ],
      );
    }
    if (_selectedIndex == 4 && _isGuest) {
      // No settings or player comparison for guests; the page body carries
      // the create-account and exit actions.
      return AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        title: Text(
          'Profile',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        centerTitle: false,
      );
    }
    if (_selectedIndex == 0) {
      return AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              children: [
                ChallengeWidget(refreshTick: _badgeTrackerRefreshTick),
                const Spacer(),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _pendingInvitesStream(),
                  builder: (context, snapshot) {
                    final count = (snapshot.data ?? const []).length;
                    return IconButton(
                      icon: Badge(
                        isLabelVisible: count > 0,
                        label: Text(count > 99 ? '99+' : '$count'),
                        child: const Icon(Icons.chat_bubble_outline),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const NotificationsPage(),
                          ),
                        );
                      },
                      tooltip: 'Notifications',
                    );
                  },
                ),
              ],
            ),
            Center(
              child: SizedBox(
                height: 32,
                child: SvgPicture.asset(
                  AppAssets.balloLogo,
                  height: 32,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      );
    } else if (_selectedIndex == 1) {
      if (_useFanShell) {
        final isFavouritesEditMode = ref.watch(favouritesEditModeProvider);
        return AppBar(
          automaticallyImplyLeading: false,
          title: Text(
            'Favourites',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          actions: [
            TextButton(
              onPressed: () {
                ref.read(favouritesEditModeProvider.notifier).toggle();
              },
              child: Text(isFavouritesEditMode ? 'Done' : 'Edit'),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add favourite',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AppSearchPage(),
                  ),
                );
              },
            ),
          ],
          elevation: 0,
        );
      }
      return AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Matches',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Go to date',
            onPressed: () async {
              final matchDates = <DateTime>{};
              try {
                final matches = await ref.read(matchesProvider.future);
                for (final match in matches) {
                  matchDates.add(
                    DateTime(
                      match.matchDate.year,
                      match.matchDate.month,
                      match.matchDate.day,
                    ),
                  );
                }
              } catch (_) {}
              final picked = await showMatchAwareDatePicker(
                context,
                matchDates: matchDates,
              );
              if (picked == null || !context.mounted) return;
              ref.read(matchesJumpToDateProvider.notifier).set(
                    DateTime(picked.year, picked.month, picked.day),
                  );
            },
          ),
        ],
        elevation: 0,
      );
    } else if (_selectedIndex == 3) {
      return AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const ExploreSearchBar(),
        centerTitle: false,
      );
    } else if (_selectedIndex == 4) {
      return AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        title: Text(
          'Profile',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        centerTitle: false,
        actions: [
          if (!_isStaff)
            IconButton(
              tooltip: 'Scout views',
              icon: StreamBuilder<int>(
                stream: _unreadScoutViewsStream(),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  return Badge(
                    isLabelVisible: count > 0,
                    label: Text(count > 99 ? '99+' : '$count'),
                    child: const FaIcon(FontAwesomeIcons.shoePrints, size: 18),
                  );
                },
              ),
              onPressed: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const ScoutViewsPage(),
                  ),
                );
                if (mounted) setState(() {});
              },
            ),
          if (!_isStaff)
            IconButton(
              icon: const Icon(Icons.group_outlined),
              onPressed: () {
                final playerId = Supabase.instance.client.auth.currentUser?.id;
                if (playerId == null || playerId.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sign in to compare players')),
                  );
                  return;
                }
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PlayerComparisonPage(basePlayerId: playerId),
                  ),
                );
              },
              tooltip: 'Compare players',
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      );
    } else {
      return AppBar(
        title: Text(
          AppConstants.pageTitles[_selectedIndex],
          style: _selectedIndex == 2
              ? Theme.of(context).textTheme.headlineMedium
              : null,
        ),
        centerTitle: false,
        automaticallyImplyLeading: false,
      );
    }
  }

  Widget _buildHomeContent(BuildContext context) {
    if (_showHomeShimmer) {
      return RefreshIndicator(
        onRefresh: _refreshHomePage,
        child: SingleChildScrollView(
          controller: _playerHomeScrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: const HomePageShimmer(),
        ),
      );
    }

    final displayName =
        _profile?.playerName ?? _profile?.username ?? 'Gareth';
    final allAttributes = _getAvailableMetrics(
      _playerPosition ?? _profile?.position,
    );
    final secondaryAttributes = allAttributes
        .where((key) => key != _focusConfig.primaryAttribute)
        .toList();

    return RefreshIndicator(
      onRefresh: _refreshHomePage,
      child: SingleChildScrollView(
        controller: _playerHomeScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppResponsive.horizontalInset(context),
            16 * AppResponsive.layoutScaleOf(context),
            AppResponsive.horizontalInset(context),
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "What's up $displayName!",
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 6),
              Text(
                "Let's hit the turf",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              _buildGameweekFilters(context),
              const SizedBox(height: 12),
              GameweekHeader(
                gameweek: _gameweekHeaderText,
                onPreviousGameweek: _onPreviousGameweek,
                onNextGameweek: _onNextGameweek,
                canGoToPreviousGameweek: _canGoToPreviousGameweek,
                canGoToNextGameweek: _canGoToNextGameweek,
                onCustomizeTargets: _openFocusCustomization,
              ),
              const SizedBox(height: 0),
              Column(
                children: [
                  Center(
                    child: ProgressRing(
                      size: 163,
                      progress: _isLoadingFocus
                          ? 0
                          : _ringProgressFor(_focusConfig.primaryAttribute),
                      valueText: _isLoadingFocus
                          ? '—'
                          : _weeklyStats
                                .valueFor(_focusConfig.primaryAttribute)
                                .toString(),
                      labelText:
                          _attributeLabels[_focusConfig.primaryAttribute] ??
                          'Tackles won',
                      icon: _attributeIcon(_focusConfig.primaryAttribute),
                      ringToTextSpacing: 4,
                      valueToLabelSpacing: 2,
                      textAreaHeight: 72,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ProgressRing(
                        size: 80,
                        progress: _isLoadingFocus
                            ? 0
                            : _ringProgressFor(secondaryAttributes.first),
                        valueText: _isLoadingFocus
                            ? '—'
                            : _weeklyStats
                                  .valueFor(secondaryAttributes.first)
                                  .toString(),
                        labelText:
                            _attributeLabels[secondaryAttributes.first] ?? '',
                        icon: _attributeIcon(secondaryAttributes.first),
                        ringToTextSpacing: 4,
                        valueToLabelSpacing: 2,
                        textAreaHeight: 66,
                      ),
                      const SizedBox(width: 16),
                      ProgressRing(
                        size: 80,
                        progress: _isLoadingFocus
                            ? 0
                            : _ringProgressFor(secondaryAttributes.last),
                        valueText: _isLoadingFocus
                            ? '—'
                            : _weeklyStats
                                  .valueFor(secondaryAttributes.last)
                                  .toString(),
                        labelText:
                            _attributeLabels[secondaryAttributes.last] ?? '',
                        icon: _attributeIcon(secondaryAttributes.last),
                        ringToTextSpacing: 4,
                        valueToLabelSpacing: 2,
                        textAreaHeight: 66,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Center(
                child: Container(
                  width: double.infinity,
                  height: 365 * AppResponsive.layoutScaleOf(context),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Performance',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 24),
                        if (_isLoadingPerformanceRatings)
                          const Expanded(child: HomePerformanceChartShimmer())
                        else
                          Expanded(
                            child: _performanceGameweekRatings.isEmpty
                                ? Center(
                                    child: HomeSectionEmptyState(
                                      embedded: true,
                                      message:
                                          'Your average rating chart fills in once you finish a gameweek in your league.',
                                    ),
                                  )
                                : PerformanceChart(
                                    gameweekRatings:
                                        _performanceGameweekRatings,
                                  ),
                          ),
                        const SizedBox(height: 0),
                        Text(
                          'Average rating per game week',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 8.0, start: 0.0),
                child: Text(
                  'This week',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 16),
              Consumer(
                builder: (context, ref, _) {
                  final asyncMatches = ref.watch(homeThisWeekMatchesProvider);
                  return asyncMatches.when(
                    data: (matches) {
                      final selectedTeamId = _homeSelectedTeamId;
                      final selectedLeagueId = _selectedTeamLeagueId;
                      final visibleMatches = matches.where((match) {
                        final belongsToTeam =
                            selectedTeamId == null ||
                            match.teamA.id == selectedTeamId ||
                            match.teamB.id == selectedTeamId;
                        final belongsToLeague =
                            selectedLeagueId == null ||
                            selectedLeagueId.isEmpty ||
                            match.leagueId == selectedLeagueId;
                        return belongsToTeam && belongsToLeague;
                      }).toList();
                      if (visibleMatches.isEmpty) {
                        return HomeSectionEmptyState(
                          message:
                              'No matches scheduled for your team this week.',
                        );
                      }
                      return ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height / 4,
                        ),
                        child: CarouselView.weighted(
                          controller: _matchCarouselController,
                          itemSnapping: true,
                          flexWeights: const <int>[1, 4, 1],
                          children: visibleMatches.map((match) {
                            return MatchCard(
                              match: match,
                              leagueName: match.leagueName,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        FixturePage(matchId: match.id),
                                  ),
                                );
                              },
                            );
                          }).toList(),
                        ),
                      );
                    },
                    loading: () => HomeMatchCarouselShimmer(
                      height: MediaQuery.sizeOf(context).height / 4,
                    ),
                    error: (err, _) => ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height / 4,
                      ),
                      child: Center(
                        child: Text(
                          'Could not load matches',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 8.0, start: 0.0),
                child: Text(
                  'Team',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 20),
              _buildHomeTeamSection(context),
              const SizedBox(height: 26),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameweekFilters(BuildContext context) {
    if (_isLoadingUserTeams) {
      return const HomeGameweekFiltersShimmer();
    }
    if (_userTeams.isEmpty) {
      return HomeSectionEmptyState(
        compact: true,
        message:
            'Join a team to filter stats and gameweeks by your squad and league.',
        actionLabel: 'Find a team',
        actionIcon: Icons.search,
        onAction: _openFindTeamSearch,
        secondaryActionLabel: 'Create team',
        onSecondaryAction: _openCreateTeam,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < _userTeams.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                TeamChip(
                  teamName: _userTeams[i].displayName,
                  logoPath: _userTeams[i].logoPath,
                  isSelected: _homeSelectedTeamId == _userTeams[i].id,
                  onSelected: (selected) {
                    if (!selected) return;
                    final teamId = _userTeams[i].id;
                    setState(() => _homeSelectedTeamId = teamId);
                    _loadTeamStandingsContext(
                      teamId: teamId,
                      preferredLeagueId: null,
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: ValueKey(
            'home_league_${_homeSelectedTeamId ?? ''}_${_selectedTeamLeagues.length}',
          ),
          initialValue:
              _selectedTeamLeagues.any((l) => l.id == _selectedTeamLeagueId)
              ? _selectedTeamLeagueId
              : (_selectedTeamLeagues.isNotEmpty
                    ? _selectedTeamLeagues.first.id
                    : null),
          decoration: const InputDecoration(
            labelText: 'League',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          hint: const Text('Select league'),
          items: _selectedTeamLeagues
              .map(
                (league) => DropdownMenuItem<String>(
                  value: league.id,
                  child: Text(
                    league.leagueName,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: _selectedTeamLeagues.isEmpty
              ? null
              : (leagueId) {
                  final teamId = _homeSelectedTeamId;
                  if (teamId == null || leagueId == null || leagueId.isEmpty) {
                    return;
                  }
                  _loadTeamStandingsContext(
                    teamId: teamId,
                    preferredLeagueId: leagueId,
                  );
                },
        ),
      ],
    );
  }

  Widget _buildHomeTeamSection(BuildContext context) {
    if (_isLoadingUserTeams) {
      return const HomeTeamSectionShimmer();
    }

    if (_userTeams.isEmpty) {
      return HomeSectionEmptyState(
        message:
            'You are not on a team yet. Find a squad to join or create your own to see standings and stats here.',
        actionLabel: 'Find a team',
        actionIcon: Icons.search,
        onAction: _openFindTeamSearch,
        secondaryActionLabel: 'Create team',
        onSecondaryAction: _openCreateTeam,
      );
    }

    final selected = _homeSelectedTeam;
    if (selected == null) {
      return const SizedBox.shrink();
    }

    return _buildTeamDetailsCard(context, selected);
  }

  Widget _buildTeamDetailsCard(BuildContext context, TeamModel team) {
    final textTheme = Theme.of(context).textTheme;
    String? selectedLeagueName;
    final leagueId = _selectedTeamLeagueId;
    if (leagueId != null) {
      for (final league in _selectedTeamLeagues) {
        if (league.id == leagueId) {
          selectedLeagueName = league.leagueName;
          break;
        }
      }
    }

    return FutureBuilder<_HomeTeamSummary>(
      future: _summaryForTeam(team.id),
      builder: (context, snapshot) {
        final summary = snapshot.data;
        final estText = summary?.estYear != null
            ? 'Est. ${summary!.estYear}'
            : 'Est. —';
        final goalsText = _formatCount(summary?.totalGoalsScored ?? 0);
        final matchesText = _formatCount(summary?.totalMatchesPlayed ?? 0);
        final trophiesText = _formatCount(summary?.totalTrophies ?? 0);

        return Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  Container(
                    height: 204,
                    width: double.infinity,
                    color: Colors.grey[800],
                    child: _teamDetailsHeroImage(team),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.6),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          team.displayName,
                          style: textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                offset: const Offset(0, 1),
                                blurRadius: 3,
                                color: Colors.black.withValues(alpha: 0.5),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          estText,
                          style: textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                offset: const Offset(0, 1),
                                blurRadius: 3,
                                color: Colors.black.withValues(alpha: 0.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.sports_soccer, size: 18),
                        label: Text('$goalsText Goals'),
                        onPressed: () {},
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(
                          Icons.sports_score_outlined,
                          size: 18,
                        ),
                        label: Text('$matchesText Matches'),
                        onPressed: () {},
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(
                          Icons.emoji_events_outlined,
                          size: 18,
                        ),
                        label: Text('$trophiesText Trophies'),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  top: 4.0,
                  start: 16.0,
                  end: 12.0,
                ),
                child: Row(
                  children: [
                    Text(
                      'Table',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const Spacer(),
                    if (selectedLeagueName != null)
                      Flexible(
                        child: Text(
                          selectedLeagueName,
                          style: Theme.of(context).textTheme.labelSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Builder(
                  builder: (context) {
                    if (_isLoadingTeamStandings) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: HomeStandingsTableShimmer(),
                      );
                    }
                    if (_selectedTeamLeagues.isEmpty ||
                        _selectedLeagueStandings.isEmpty) {
                      return HomeSectionEmptyState(
                        embedded: true,
                        compact: true,
                        message: _selectedTeamLeagues.isEmpty
                            ? 'This team is not in a league yet. Join a league to see the table here.'
                            : 'The league table will appear once teams play matches in this league.',
                      );
                    }

                    final visibleRows = _contextRowsForTeam(
                      _selectedLeagueStandings,
                      team.id,
                    );
                    return Table(
                      columnWidths: const {
                        0: FlexColumnWidth(0.8),
                        1: FlexColumnWidth(0.6),
                        2: FlexColumnWidth(2.4),
                        3: FlexColumnWidth(0.8),
                        4: FlexColumnWidth(0.8),
                        5: FlexColumnWidth(0.8),
                        6: FlexColumnWidth(0.8),
                        7: FlexColumnWidth(0.8),
                        8: FlexColumnWidth(0.8),
                      },
                      children: [
                        _buildTableHeader(context),
                        for (final row in visibleRows)
                          _buildStandingsRow(
                            context,
                            row,
                            isHighlighted: row.teamId == team.id,
                          ),
                      ],
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => TeamDetailPage(teamId: team.id),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      minimumSize: const Size(99, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: const Text('View team'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatCount(int value) {
    final safe = value < 0 ? 0 : value;
    return safe.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => ',',
    );
  }

  /// Banner image: team banner (network/asset), otherwise themed graphic.
  Widget _teamDetailsHeroImage(TeamModel team) {
    final p = team.bannerPath;
    if (p.isEmpty) {
      return _teamBannerGraphicPlaceholder(context);
    }
    if (p.startsWith('http://') || p.startsWith('https://')) {
      return Image(
        image: CachedNetworkImageProvider(p),
        fit: BoxFit.cover,
        width: double.infinity,
        height: 204,
        errorBuilder: (context, error, stackTrace) {
          return _teamBannerGraphicPlaceholder(context);
        },
      );
    }
    return Image.asset(
      p,
      fit: BoxFit.cover,
      width: double.infinity,
      height: 204,
      errorBuilder: (context, error, stackTrace) {
        return _teamBannerGraphicPlaceholder(context);
      },
    );
  }

  Widget _teamBannerGraphicPlaceholder(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      height: 204,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primaryContainer,
            cs.secondaryContainer,
            cs.tertiaryContainer,
          ],
        ),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_outlined, color: cs.onPrimaryContainer, size: 26),
            const SizedBox(width: 8),
            Text(
              'Team Banner',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  TableRow _buildTableHeader(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'Pos',
            style: textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: SizedBox(height: 20, child: Center(child: Text(''))),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text('Team', style: textTheme.bodySmall),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'PL',
            style: textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'W',
            style: textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'L',
            style: textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'D',
            style: textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'GD',
            style: textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'Pts',
            style: textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  TableRow _buildStandingsRow(
    BuildContext context,
    _TeamStandingRow row, {
    required bool isHighlighted,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final model = TeamModel(
      id: row.teamId,
      logoId: row.logoId.isNotEmpty ? row.logoId : null,
      shortForm: row.shortForm,
      teamName: null,
    );
    final logoPath = model.logoPath;

    return TableRow(
      decoration: isHighlighted
          ? BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(30),
            )
          : null,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Text(
            row.position > 0 ? row.position.toString() : '—',
            style: textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: SizedBox(
            height: 36,
            child: _standingsMovementCell(context, row.positionChange),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Row(
            children: [
              ClipOval(child: TeamChip.logoImage(logoPath, size: 24)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  row.shortForm.isNotEmpty ? row.shortForm : '—',
                  style: textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Text(
            row.played.toString(),
            style: textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Text(
            row.wins.toString(),
            style: textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Text(
            row.losses.toString(),
            style: textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Text(
            row.draws.toString(),
            style: textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Text(
            row.goalDiff.toString(),
            style: textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Text(
            row.points.toString(),
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  /// [delta] = previous rank − current rank: positive = moved up the table.
  Widget _standingsMovementCell(BuildContext context, int delta) {
    final outline = Theme.of(context).colorScheme.outline;
    if (delta == 0) {
      return Center(child: Icon(Icons.remove, color: outline, size: 16));
    }
    final isUp = delta > 0;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isUp ? Icons.arrow_drop_up : Icons.arrow_drop_down,
            color: isUp ? const Color(0xff39ff14) : const Color(0xffff0000),
            size: 20,
          ),
          Text(
            delta.abs().toString(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    final navDestinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Home',
      ),
      if (_useFanShell)
        const NavigationDestination(
          icon: Icon(Icons.star_outline_rounded),
          selectedIcon: Icon(Icons.star_rounded),
          label: 'Favourites',
        )
      else
        const NavigationDestination(
          icon: Icon(Icons.sports_score_outlined),
          selectedIcon: Icon(Icons.sports_score),
          label: 'Matches',
        ),
      const NavigationDestination(
        icon: Icon(Icons.leaderboard_outlined),
        selectedIcon: Icon(Icons.leaderboard),
        label: 'Leaderboard',
      ),
      const NavigationDestination(
        icon: Icon(Icons.explore_outlined),
        selectedIcon: Icon(Icons.explore),
        label: 'Explore',
      ),
      const NavigationDestination(
        icon: Icon(Icons.account_circle_outlined),
        selectedIcon: Icon(Icons.account_circle),
        label: 'Account',
      ),
    ];

    final safeIndex =
        (_selectedIndex >= 0 && _selectedIndex < navDestinations.length)
        ? _selectedIndex
        : 0;

    return NavigationBar(
      selectedIndex: safeIndex,
      onDestinationSelected: _onNavDestinationSelected,
      destinations: navDestinations,
    );
  }

  void _onNavDestinationSelected(int index) {
    if (index == _selectedIndex) {
      ref.read(mainNavScrollToTopProvider.notifier).requestScrollToTop(index);
      return;
    }
    final wasHome = _selectedIndex == 0;
    setState(() {
      _selectedIndex = index;
      if (index == 0 && _useFanShell) {
        _matchesActivationNonce++;
      }
      if (index == 1 && !_useFanShell) {
        _matchesActivationNonce++;
      }
    });
    if (index == 0) {
      _onHomeTabBecameVisibleWithRefresh();
    } else if (wasHome) {
      _onHomeTabBecameHidden();
    }
    if ((index == 0 && _useFanShell) || (index == 1 && !_useFanShell)) {
      // Guest home and player Matches share the list; refresh at most every 2 min.
      final now = DateTime.now();
      final last = _lastHomeTabAutoRefreshAt;
      if (last == null ||
          now.difference(last) >= _homeTabRefreshThrottle) {
        _lastHomeTabAutoRefreshAt = now;
        ref.invalidate(matchesProvider);
      }
    }
  }
}

class _TeamStandingRow {
  const _TeamStandingRow({
    required this.position,
    required this.teamId,
    required this.shortForm,
    required this.logoId,
    required this.played,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.goalDiff,
    required this.points,
    required this.positionChange,
  });

  final int position;
  final String teamId;
  final String shortForm;
  final String logoId;
  final int played;
  final int wins;
  final int losses;
  final int draws;
  final int goalDiff;
  final int points;
  final int positionChange;

  _TeamStandingRow withPosition(int newPosition, {int positionChange = 0}) {
    return _TeamStandingRow(
      position: newPosition,
      teamId: teamId,
      shortForm: shortForm,
      logoId: logoId,
      played: played,
      wins: wins,
      losses: losses,
      draws: draws,
      goalDiff: goalDiff,
      points: points,
      positionChange: positionChange,
    );
  }

  factory _TeamStandingRow.fromStandingsRpc(Map<String, dynamic> row) {
    int readInt(List<String> keys, {int fallback = 0}) {
      for (final key in keys) {
        final value = row[key];
        if (value is int) return value;
        if (value is num) return value.round();
        if (value is String) {
          final parsed = int.tryParse(value.trim());
          if (parsed != null) return parsed;
        }
      }
      return fallback;
    }

    String readString(List<String> keys, {String fallback = ''}) {
      for (final key in keys) {
        final value = row[key];
        if (value == null) continue;
        final s = value.toString().trim();
        if (s.isNotEmpty) return s;
      }
      return fallback;
    }

    // movement = previous rank − current rank: positive = climbed the table
    int readMovement() {
      if (row.containsKey('position_change')) {
        return readInt([
          'position_change',
          'pos_change',
          'rank_change',
        ], fallback: 0);
      }
      final prev = readInt(['previous_position', 'prev_position'], fallback: 0);
      final pos = readInt([
        'position',
        'rank',
        'board_rank',
        'league_position',
      ], fallback: 0);
      if (prev > 0 && pos > 0) {
        return prev - pos;
      }
      return 0;
    }

    return _TeamStandingRow(
      position: readInt([
        'position',
        'rank',
        'board_rank',
        'league_position',
      ], fallback: 0),
      teamId: readString(['team_id', 'id']),
      shortForm: readString([
        'team_short_form',
        'team_short',
        'short_form',
      ], fallback: ''),
      logoId: readString(['team_logo', 'logo_id'], fallback: ''),
      played: readInt(['played', 'pl', 'matches_played'], fallback: 0),
      wins: readInt(['wins', 'w']),
      draws: readInt(['draws', 'd']),
      losses: readInt(['losses', 'l']),
      goalDiff: readInt(['goal_difference', 'goal_diff', 'gd'], fallback: 0),
      points: readInt(['points', 'pts'], fallback: 0),
      positionChange: readMovement(),
    );
  }
}

class _WeeklyAttributeStats {
  const _WeeklyAttributeStats({required this.stats});

  final Map<String, int> stats;

  factory _WeeklyAttributeStats.empty() {
    return const _WeeklyAttributeStats(stats: {});
  }

  int valueFor(String key) {
    return stats[key] ?? 0;
  }

  static _WeeklyAttributeStats fromRows(dynamic rowsRaw) {
    if (rowsRaw is! List || rowsRaw.isEmpty) {
      return _WeeklyAttributeStats.empty();
    }
    final aggregated = <String, int>{};
    const allMetrics = [
      'tackles',
      'assists',
      'clean_sheets',
      'goals',
      'shots_on_target',
      'saves',
    ];

    for (final row in rowsRaw) {
      final map = row is Map<String, dynamic>
          ? row
          : Map<String, dynamic>.from(row as Map);
      for (final metric in allMetrics) {
        aggregated[metric] = (aggregated[metric] ?? 0) + _toInt(map[metric]);
      }
    }

    return _WeeklyAttributeStats(stats: aggregated);
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }
}

class _GameweekOption {
  const _GameweekOption({required this.id, required this.week});

  final String id;
  final int week;
}

class _HomeTeamSummary {
  const _HomeTeamSummary({
    required this.estYear,
    required this.totalGoalsScored,
    required this.totalMatchesPlayed,
    required this.totalTrophies,
  });

  final int? estYear;
  final int totalGoalsScored;
  final int totalMatchesPlayed;
  final int totalTrophies;
}

class _HomeTeamStandingsAgg {
  int played = 0;
  int points = 0;
  int gf = 0;
  int ga = 0;

  int get goalDiff => gf - ga;
}

class _FocusRingConfig {
  const _FocusRingConfig({
    required this.primaryAttribute,
    required this.targets,
  });

  final String primaryAttribute;
  final Map<String, int> targets;

  factory _FocusRingConfig.defaults() {
    return const _FocusRingConfig(
      primaryAttribute: 'tackles',
      targets: {'tackles': 10, 'assists': 5, 'clean_sheets': 3},
    );
  }

  factory _FocusRingConfig.fromMetadata(
    dynamic metadataValue, {
    String? position,
  }) {
    final fallback = _FocusRingConfig.defaults();
    if (metadataValue is! Map) return fallback;
    final map = Map<String, dynamic>.from(metadataValue);
    final rawTargets = map['targets'];
    final targetsMap = rawTargets is Map
        ? Map<String, dynamic>.from(rawTargets)
        : const <String, dynamic>{};
    final primary = map['primary_attribute']?.toString();

    // Validate primary attribute against position-specific metrics
    final availableMetrics =
        _HomePageState._positionMetrics[(position ?? '').toLowerCase()] ??
        _HomePageState._positionMetrics['defender']!;
    final safePrimary = availableMetrics.contains(primary)
        ? primary!
        : fallback.primaryAttribute;

    // Build targets map with all metrics
    final targets = <String, int>{};
    for (final metric in availableMetrics) {
      targets[metric] = _toPositiveInt(
        targetsMap[metric],
        fallback.targets[metric] ?? 10,
      );
    }

    return _FocusRingConfig(primaryAttribute: safePrimary, targets: targets);
  }

  Map<String, dynamic> toMetadata() {
    return {'primary_attribute': primaryAttribute, 'targets': targets};
  }

  _FocusRingConfig copyWith({
    String? primaryAttribute,
    Map<String, int>? targets,
  }) {
    return _FocusRingConfig(
      primaryAttribute: primaryAttribute ?? this.primaryAttribute,
      targets: targets ?? this.targets,
    );
  }

  static int _toPositiveInt(dynamic value, int fallback) {
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed == null || parsed <= 0) return fallback;
    return parsed;
  }
}

class _FocusCustomizationPage extends StatefulWidget {
  const _FocusCustomizationPage({
    required this.config,
    required this.availableMetrics,
  });

  final _FocusRingConfig config;
  final List<String> availableMetrics;

  @override
  State<_FocusCustomizationPage> createState() =>
      _FocusCustomizationPageState();
}

class _FocusCustomizationPageState extends State<_FocusCustomizationPage> {
  static const _labelMap = {
    'tackles': 'Tackles won',
    'assists': 'Assists',
    'clean_sheets': 'Clean sheets',
    'goals': 'Goals',
    'shots_on_target': 'Shots on target',
    'saves': 'Saves',
  };

  late String _primary;
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _primary = widget.config.primaryAttribute;
    _controllers = {};
    for (final metric in widget.availableMetrics) {
      _controllers[metric] = TextEditingController(
        text: (widget.config.targets[metric] ?? 10).toString(),
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int _readTarget(TextEditingController controller, int fallback) {
    final value = int.tryParse(controller.text.trim());
    if (value == null || value <= 0) return fallback;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customize Targets'),
        actions: [
          TextButton(
            onPressed: () {
              final targets = <String, int>{};
              for (final metric in widget.availableMetrics) {
                targets[metric] = _readTarget(_controllers[metric]!, 10);
              }
              final config = _FocusRingConfig(
                primaryAttribute: _primary,
                targets: targets,
              );
              Navigator.of(context).pop(config);
            },
            child: const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Set your focus metric', style: textTheme.titleLarge),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: const Color(0xff63ead7),
                    width: 1.6,
                  ),
                  color: cs.surfaceContainerLow,
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    for (final key in widget.availableMetrics)
                      RadioListTile<String>(
                        value: key,
                        groupValue: _primary,
                        activeColor: const Color(0xff63ead7),
                        title: Text(_labelMap[key] ?? key),
                        subtitle: const Text('Shown as your main ring metric'),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _primary = value);
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text('Set your gameweek targets', style: textTheme.titleMedium),
              const SizedBox(height: 10),
              for (final metric in widget.availableMetrics) ...[
                _targetField(
                  context: context,
                  label: '${_labelMap[metric] ?? metric} target',
                  controller: _controllers[metric]!,
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _targetField({
    required BuildContext context,
    required String label,
    required TextEditingController controller,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'Enter weekly target',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
