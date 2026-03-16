import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/matches_repository.dart';
import '../../domain/models/league_model.dart';
import '../../domain/models/match_model.dart';
import '../../domain/models/season_model.dart';
import '../../domain/models/team_model.dart';
import 'league_teams_provider.dart';
import 'leagues_provider.dart';
import 'seasons_provider.dart';

final matchesRepositoryProvider = Provider<MatchesRepository>((ref) {
  return MatchesRepository();
});

/// Selected gameweek filter (gameweek id). Null or empty = all.
class SelectedGameweekNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? value) => state = value;
}

final selectedGameweekProvider =
    NotifierProvider<SelectedGameweekNotifier, String?>(
      SelectedGameweekNotifier.new,
    );

/// Selected league filter (league id). Null = all leagues user participates in.
class SelectedMatchesLeagueNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? value) => state = value;
}

final selectedMatchesLeagueProvider =
    NotifierProvider<SelectedMatchesLeagueNotifier, String?>(
      SelectedMatchesLeagueNotifier.new,
    );

/// Selected season filter (season id). Null = all.
class SelectedMatchesSeasonNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? value) => state = value;
}

final selectedMatchesSeasonProvider =
    NotifierProvider<SelectedMatchesSeasonNotifier, String?>(
      SelectedMatchesSeasonNotifier.new,
    );

/// Selected team filter (team id). Null = all teams user participates in.
class SelectedMatchesTeamNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? value) => state = value;
}

final selectedMatchesTeamProvider =
    NotifierProvider<SelectedMatchesTeamNotifier, String?>(
      SelectedMatchesTeamNotifier.new,
    );

/// Label for the selected gameweek (e.g. "Gameweek 5") or null if all.
final selectedGameweekLabelProvider = Provider.autoDispose<String?>((ref) {
  final gwId = ref.watch(selectedGameweekProvider);
  if (gwId == null || gwId.isEmpty) return null;
  final gameweeksAsync = ref.watch(matchesFilterGameweeksProvider);
  return gameweeksAsync.when(
    data: (list) {
      for (final e in list) {
        if (e['id']?.toString() == gwId) {
          final week = e['week']?.toString();
          return week != null ? 'Gameweek $week' : null;
        }
      }
      return null;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Leagues the user participates in (created or has team in).
final matchesFilterLeaguesProvider =
    FutureProvider.autoDispose<List<LeagueModel>>((ref) async {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return [];
      final repo = ref.watch(leaguesRepositoryProvider);
      return repo.getLeaguesForUser(userId);
    });

/// Seasons for matches filter. If league selected, that league's seasons;
/// else seasons from all user's leagues.
final matchesFilterSeasonsProvider =
    FutureProvider.autoDispose<List<SeasonModel>>((ref) async {
      final leagues = await ref.watch(matchesFilterLeaguesProvider.future);
      final selectedLeague = ref.watch(selectedMatchesLeagueProvider);
      if (leagues.isEmpty) return [];
      final leagueIds = selectedLeague != null
          ? [selectedLeague]
          : leagues.map((l) => l.id).toList();
      final seasonsRepo = ref.watch(seasonsRepositoryProvider);
      return seasonsRepo.getSeasonsForLeagues(leagueIds);
    });

/// Gameweeks for matches filter. From selected season or all user's seasons.
final matchesFilterGameweeksProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final seasons = await ref.watch(matchesFilterSeasonsProvider.future);
      final selectedSeason = ref.watch(selectedMatchesSeasonProvider);
      if (seasons.isEmpty) return [];
      final seasonIds = selectedSeason != null
          ? [selectedSeason]
          : seasons.map((s) => s.id).toList();
      final seasonsRepo = ref.watch(seasonsRepositoryProvider);
      return seasonsRepo.getGameweeksForSeasons(seasonIds);
    });

/// Teams in leagues the user participates in. If a league is selected, only
/// teams in that league; otherwise teams from all user's leagues.
final matchesFilterTeamsProvider = FutureProvider.autoDispose<List<TeamModel>>((
  ref,
) async {
  final leagues = await ref.watch(matchesFilterLeaguesProvider.future);
  final selectedLeague = ref.watch(selectedMatchesLeagueProvider);
  if (leagues.isEmpty) return [];
  final leagueIds = selectedLeague != null
      ? [selectedLeague]
      : leagues.map((l) => l.id).toList();
  final leagueTeamsRepo = ref.watch(leagueTeamsRepositoryProvider);
  return leagueTeamsRepo.getTeamsInLeagues(leagueIds);
});

/// Fetches matches from Supabase. Filters by league, season, gameweek, team
/// via the selected filter providers. RLS restricts to user's matches.
final matchesProvider = FutureProvider.autoDispose<List<MatchModel>>((
  ref,
) async {
  final repo = ref.watch(matchesRepositoryProvider);
  final gameweek = ref.watch(selectedGameweekProvider);
  final leagueId = ref.watch(selectedMatchesLeagueProvider);
  final seasonId = ref.watch(selectedMatchesSeasonProvider);
  final teamId = ref.watch(selectedMatchesTeamProvider);

  List<String>? leagueIds;
  if (leagueId != null && leagueId.isNotEmpty) {
    leagueIds = [leagueId];
  }

  List<String>? seasonIds;
  if (seasonId != null && seasonId.isNotEmpty) {
    seasonIds = [seasonId];
  }

  List<String>? teamIds;
  if (teamId != null && teamId.isNotEmpty) {
    teamIds = [teamId];
  }

  return repo.getMatches(
    gameweek: gameweek,
    leagueIds: leagueIds,
    seasonIds: seasonIds,
    teamIds: teamIds,
  );
});

/// Matches for the home page "This week" carousel. Filters by date range
/// (Monday–Sunday of the current week).
final homeThisWeekMatchesProvider =
    FutureProvider.autoDispose<List<MatchModel>>((ref) async {
      final repo = ref.watch(matchesRepositoryProvider);
      return repo.getMatchesThisWeek();
    });

/// Fetches a single match by id for the fixture detail page.
final fixtureMatchProvider = FutureProvider.autoDispose
    .family<MatchModel?, String>((ref, matchId) async {
      if (matchId.isEmpty) return null;
      final repo = ref.watch(matchesRepositoryProvider);
      return repo.getMatchById(matchId);
    });

/// Matches grouped by date for UI. Key: "yyyy-MM-dd", value: list of matches on that date.
final matchesGroupedByDateProvider =
    Provider.autoDispose<Map<String, List<MatchModel>>>((ref) {
      final asyncMatches = ref.watch(matchesProvider);
      return asyncMatches.when(
        data: (list) {
          final map = <String, List<MatchModel>>{};
          for (final m in list) {
            final key = _dateKey(m.matchDate);
            map.putIfAbsent(key, () => []).add(m);
          }
          return map;
        },
        loading: () => <String, List<MatchModel>>{},
        error: (_, __) => <String, List<MatchModel>>{},
      );
    });

/// Simple ticking clock per match, used to keep stopwatch in sync between
/// pages.
///
/// Implemented as a family of [Notifier]s so that each `matchId` gets its own
/// independent clock instance while sharing the same provider base.
class MatchClockNotifier extends Notifier<Duration> {
  MatchClockNotifier(this.matchId);

  final String matchId;
  Timer? _timer;

  @override
  Duration build() => Duration.zero;

  void start() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      state = state + const Duration(seconds: 1);
    });
  }

  void pause() {
    _timer?.cancel();
    _timer = null;
  }

  void reset() {
    pause();
    state = Duration.zero;
  }

  /// Sets the clock to a specific duration (e.g. 45:00 for second half start).
  void setTo(Duration d) {
    state = d;
  }
}

final matchClockProvider =
    NotifierProvider.family<MatchClockNotifier, Duration, String>(
      MatchClockNotifier.new,
    );

/// Timer config per match: half duration and whether we've reached half time.
/// When half duration is set and clock exceeds it (45' or 90'), the pill turns red.
class MatchTimerConfigNotifier extends Notifier<MatchTimerConfig> {
  MatchTimerConfigNotifier(this.matchId);

  final String matchId;

  @override
  MatchTimerConfig build() => const MatchTimerConfig();

  void setHalfDuration(int? minutes) {
    state = state.copyWith(halfDurationMinutes: minutes);
  }

  void markHalfTimeReached() {
    state = state.copyWith(hasReachedHalfTime: true);
  }

  void reset() {
    state = const MatchTimerConfig();
  }
}

class MatchTimerConfig {
  const MatchTimerConfig({
    this.halfDurationMinutes,
    this.hasReachedHalfTime = false,
  });

  final int? halfDurationMinutes;
  final bool hasReachedHalfTime;

  MatchTimerConfig copyWith({
    int? halfDurationMinutes,
    bool? hasReachedHalfTime,
  }) => MatchTimerConfig(
    halfDurationMinutes: halfDurationMinutes ?? this.halfDurationMinutes,
    hasReachedHalfTime: hasReachedHalfTime ?? this.hasReachedHalfTime,
  );

  /// Target minute for red pill. First half: halfDuration. Second half: halfDuration * 2
  /// (clock continues from 45 to 90, etc.).
  int? get targetMinute {
    if (halfDurationMinutes == null) return null;
    return hasReachedHalfTime ? halfDurationMinutes! * 2 : halfDurationMinutes;
  }

  /// True when clock has passed the half target (stoppage time).
  bool isPastTarget(Duration clock) {
    final target = targetMinute;
    if (target == null) return false;
    return clock.inMinutes >= target;
  }

  /// Match minute for recording. Clock shows match time directly (2nd half
  /// starts at 45:00 or 2:00 etc.), so we use clock.inMinutes.
  int getMatchMinute(Duration clock) => clock.inMinutes;
}

final matchTimerConfigProvider =
    NotifierProvider.family<MatchTimerConfigNotifier, MatchTimerConfig, String>(
      MatchTimerConfigNotifier.new,
    );

String formatMatchClock(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// Formatted date for display (e.g. "Tue 2 Dec") from "yyyy-MM-dd".
String formatMatchDateKey(String key) {
  final parts = key.split('-');
  if (parts.length != 3) return key;
  final y = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 1;
  final d = int.tryParse(parts[2]) ?? 1;
  final dt = DateTime(y, m, d);
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
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final wd = weekdays[dt.weekday - 1];
  final mon = months[dt.month - 1];
  return '$wd $d $mon';
}

String _dateKey(DateTime d) {
  final y = d.year;
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

/// Match videos for a given match, loaded from the `videos` table.
/// Returns list of public video URLs.
final matchVideosProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, matchId) async {
      if (matchId.isEmpty) return [];
      final client = Supabase.instance.client;
      final res = await client
          .from('videos')
          .select('video_url')
          .eq('match_id', matchId)
          .order('created_at');
      final list = res as List;
      return list
          .map((row) => row['video_url']?.toString())
          .whereType<String>()
          .toList();
    });
