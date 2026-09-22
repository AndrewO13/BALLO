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

/// `fullTime` matches / all fixtures for [ongoingOrUpcomingSeasonProvider].
final leagueSeasonFixtureProgressProvider = FutureProvider.autoDispose
    .family<SeasonFixtureProgress?, String>((ref, leagueId) async {
      if (leagueId.isEmpty) return null;
      final season = await ref.watch(
        ongoingOrUpcomingSeasonProvider(leagueId).future,
      );
      if (season == null || season.id.isEmpty) return null;
      final repo = ref.watch(matchesRepositoryProvider);
      return repo.getSeasonFixtureProgress(
        leagueId: leagueId,
        seasonId: season.id,
      );
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
    error: (_, _) => null,
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

/// How far back the unfiltered matches list reaches. Older matches are still
/// reachable by selecting a season/gameweek filter, which lifts the window.
const _defaultMatchesHistoryWindow = Duration(days: 180);

/// Fetches matches from Supabase. Filters by league, season, gameweek, team
/// via the selected filter providers. RLS restricts to user's matches.
///
/// When no explicit season/gameweek filter is chosen, the fetch is bounded to
/// a rolling window (recent history + all upcoming) instead of the full
/// multi-season history, which keeps payloads small.
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

  final hasExplicitScope = (gameweek != null && gameweek.isNotEmpty) ||
      seasonIds != null;

  return repo.getMatches(
    gameweek: gameweek,
    leagueIds: leagueIds,
    seasonIds: seasonIds,
    teamIds: teamIds,
    fromDate: hasExplicitScope
        ? null
        : DateTime.now().subtract(_defaultMatchesHistoryWindow),
  );
});

/// Matches for the home page "This week" carousel. Filters by date range
/// (Monday–Sunday of the current week).
final homeThisWeekMatchesProvider =
    FutureProvider.autoDispose<List<MatchModel>>((ref) async {
      final repo = ref.watch(matchesRepositoryProvider);
      return repo.getMatchesThisWeek();
    });

/// Requested date jump target for Matches page. Consumed by the matches list UI
/// to scroll to the corresponding date group ("yyyy-MM-dd" key).
class MatchesJumpToDateNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void set(DateTime? value) => state = value;
}

final matchesJumpToDateProvider =
    NotifierProvider<MatchesJumpToDateNotifier, DateTime?>(
      MatchesJumpToDateNotifier.new,
    );

/// Calendar day selected on guest home (date-based match navigation).
class SelectedMatchesCalendarDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => normalizeMatchCalendarDate(DateTime.now());

  void setDate(DateTime date) {
    state = normalizeMatchCalendarDate(date);
  }

  void goToPreviousDay() {
    state = state.subtract(const Duration(days: 1));
  }

  void goToNextDay() {
    state = state.add(const Duration(days: 1));
  }
}

final selectedMatchesCalendarDateProvider =
    NotifierProvider<SelectedMatchesCalendarDateNotifier, DateTime>(
      SelectedMatchesCalendarDateNotifier.new,
    );

DateTime normalizeMatchCalendarDate(DateTime date) =>
    DateTime(date.year, date.month, date.day);

/// Header label for date-based match navigation ("Today" or e.g. "Tue 2 Dec").
String formatMatchesCalendarHeaderLabel(DateTime date) {
  final normalized = normalizeMatchCalendarDate(date);
  final today = normalizeMatchCalendarDate(DateTime.now());
  if (normalized == today) return 'Today';
  return formatMatchDateKey(_dateKey(normalized));
}

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
        error: (_, _) => <String, List<MatchModel>>{},
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
  bool _loadedFromDatabase = false;

  @override
  MatchTimerConfig build() {
    if (!_loadedFromDatabase) {
      _loadedFromDatabase = true;
      _loadPersistedHalfDuration();
    }
    return const MatchTimerConfig();
  }

  Future<void> _loadPersistedHalfDuration() async {
    try {
      final persistedHalfDuration = await ref
          .read(matchesRepositoryProvider)
          .getMatchHalfDurationMinutes(matchId);
      if (persistedHalfDuration == null) return;
      applyHalfDurationFromDatabase(persistedHalfDuration);
    } catch (_) {}
  }

  /// Applies a value loaded from the database without writing back.
  void applyHalfDurationFromDatabase(int minutes) {
    if (state.halfDurationMinutes == minutes) return;
    state = state.copyWith(halfDurationMinutes: minutes);
  }

  Future<void> setHalfDuration(int minutes) async {
    final clamped = minutes.clamp(1, 120);
    state = state.copyWith(halfDurationMinutes: clamped);
    await ref
        .read(matchesRepositoryProvider)
        .setMatchHalfDurationMinutes(matchId, clamped);
  }

  void markHalfTimeReached() {
    state = state.copyWith(hasReachedHalfTime: true);
  }

  void reset() {
    state = state.copyWith(hasReachedHalfTime: false);
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

  /// Target minute for red pill. Each half uses the same threshold and the
  /// clock restarts from 0 when the match resumes after halftime.
  int? get targetMinute {
    if (halfDurationMinutes == null) return null;
    return halfDurationMinutes;
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

/// Halftime boundaries used to place events on the fixture timeline.
class FixtureMatchTimelineTiming {
  const FixtureMatchTimelineTiming({
    this.halftimePausedAt,
    this.resumedFromHalftimeAt,
    this.halfDurationMinutes,
  });

  final DateTime? halftimePausedAt;
  final DateTime? resumedFromHalftimeAt;
  final int? halfDurationMinutes;
}

final fixtureMatchTimelineTimingProvider = FutureProvider.autoDispose
    .family<FixtureMatchTimelineTiming?, String>((ref, matchId) async {
  if (matchId.isEmpty) return null;
  final raw = await ref
      .read(matchesRepositoryProvider)
      .getMatchTimingData(matchId);
  if (raw == null) return null;

  DateTime? parse(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  final halfRaw = raw['half_duration_minutes'];
  final halfDuration = halfRaw is int
      ? halfRaw
      : int.tryParse(halfRaw?.toString() ?? '');

  return FixtureMatchTimelineTiming(
    halftimePausedAt: parse(raw['halftime_paused_at']?.toString()),
    resumedFromHalftimeAt: parse(raw['resumed_from_halftime_at']?.toString()),
    halfDurationMinutes: halfDuration,
  );
});

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
/// Returns public URL + uploader + created timestamp metadata.
class MatchVideoItem {
  const MatchVideoItem({
    required this.id,
    required this.videoUrl,
    this.thumbnailUrl,
    this.durationSeconds,
    this.uploaderName,
    this.uploaderImageUrl,
    this.uploaderUserId,
    this.createdAt,
  });

  final String id;
  final String videoUrl;
  final String? thumbnailUrl;
  final int? durationSeconds;
  final String? uploaderName;
  final String? uploaderImageUrl;
  final String? uploaderUserId;
  final DateTime? createdAt;
}

final matchVideosProvider = FutureProvider.autoDispose
    .family<List<MatchVideoItem>, String>((ref, matchId) async {
      if (matchId.isEmpty) return [];
      final client = Supabase.instance.client;
      final res = await client
          .from('videos')
          .select(
            'id, video_url, thumbnail_url, duration_seconds, '
            'uploader_user_id, created_at',
          )
          .eq('match_id', matchId)
          .order('created_at');
      final list = List<Map<String, dynamic>>.from(res as List);
      final uploaderIds = <String>{
        for (final row in list)
          if (row['uploader_user_id'] != null)
            row['uploader_user_id'].toString(),
      };
      final profilesById = <String, Map<String, dynamic>>{};
      if (uploaderIds.isNotEmpty) {
        final profiles = await client
            .from('players')
            .select('id, player_name, username, image_url')
            .inFilter('id', uploaderIds.toList());
        for (final row in profiles as List) {
          final map = Map<String, dynamic>.from(row as Map);
          final id = map['id']?.toString();
          if (id != null && id.isNotEmpty) {
            profilesById[id] = map;
          }
        }
      }

      final out = <MatchVideoItem>[];
      for (final row in list) {
        final url = row['video_url']?.toString();
        if (url == null || url.isEmpty) continue;
        final uploaderId = row['uploader_user_id']?.toString();
        final profile = uploaderId != null ? profilesById[uploaderId] : null;
        final playerName = profile?['player_name']?.toString().trim();
        final username = profile?['username']?.toString().trim();
        final displayName = (playerName != null && playerName.isNotEmpty)
            ? playerName
            : ((username != null && username.isNotEmpty) ? username : null);
        out.add(
          MatchVideoItem(
            id: row['id']?.toString() ?? '',
            videoUrl: url,
            thumbnailUrl: row['thumbnail_url']?.toString(),
            durationSeconds: (row['duration_seconds'] as num?)?.toInt(),
            uploaderName: displayName,
            uploaderImageUrl: profile?['image_url']?.toString(),
            uploaderUserId: uploaderId,
            createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
          ),
        );
      }
      return out;
    });

/// Videos attached to a set of matches, keyed for list rings and seen-state.
class MatchVideosLookup {
  const MatchVideosLookup({
    this.matchIds = const {},
    this.videoIdsByMatch = const {},
  });

  final Set<String> matchIds;
  final Map<String, List<String>> videoIdsByMatch;
}

/// Increment (e.g. after uploading a clip) so all [matchIdsWithVideosSetProvider] lookups refetch.
class MatchVideosLookupRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final matchVideosLookupRevisionProvider =
    NotifierProvider<MatchVideosLookupRevision, int>(
      MatchVideosLookupRevision.new,
    );

/// Stable cache key for [matchIdsWithVideosSetProvider] (sorted, deduped IDs).
String matchIdsWithVideosCacheKey(Iterable<String> matchIds) {
  final sorted = matchIds.where((id) => id.isNotEmpty).toSet().toList()..sort();
  return sorted.join('\x1e');
}

/// Which of the given match IDs have videos, plus each match's video IDs.
final matchVideosLookupByIdsProvider = FutureProvider.autoDispose
    .family<MatchVideosLookup, String>((ref, cacheKey) async {
      ref.watch(matchVideosLookupRevisionProvider);
      if (cacheKey.isEmpty) return const MatchVideosLookup();
      final ids = cacheKey.split('\x1e').where((s) => s.isNotEmpty).toList();
      if (ids.isEmpty) return const MatchVideosLookup();
      final client = Supabase.instance.client;
      final res = await client
          .from('videos')
          .select('id, match_id, created_at')
          .inFilter('match_id', ids)
          .order('created_at');
      final list = List<Map<String, dynamic>>.from(res as List);
      final matchIds = <String>{};
      final videoIdsByMatch = <String, List<String>>{};
      for (final row in list) {
        final matchId = row['match_id']?.toString() ?? '';
        final videoId = row['id']?.toString() ?? '';
        if (matchId.isEmpty) continue;
        matchIds.add(matchId);
        if (videoId.isEmpty) continue;
        videoIdsByMatch.putIfAbsent(matchId, () => <String>[]).add(videoId);
      }
      return MatchVideosLookup(
        matchIds: matchIds,
        videoIdsByMatch: videoIdsByMatch,
      );
    });

/// Which of the given match IDs have at least one row in `videos`.
final matchIdsWithVideosSetProvider = FutureProvider.autoDispose
    .family<Set<String>, String>((ref, cacheKey) async {
      final lookup = await ref.watch(
        matchVideosLookupByIdsProvider(cacheKey).future,
      );
      return lookup.matchIds;
    });

final matchesVideosLookupProvider =
    FutureProvider.autoDispose<MatchVideosLookup>((ref) async {
      ref.watch(matchVideosLookupRevisionProvider);
      final matches = await ref.watch(matchesProvider.future);
      final key = matchIdsWithVideosCacheKey(matches.map((m) => m.id));
      if (key.isEmpty) return const MatchVideosLookup();
      return ref.watch(matchVideosLookupByIdsProvider(key).future);
    });

/// Match IDs (from the current [matchesProvider] list) that have at least one `videos` row.
final matchesWithVideosIdsProvider = FutureProvider.autoDispose<Set<String>>((
  ref,
) async {
  final lookup = await ref.watch(matchesVideosLookupProvider.future);
  return lookup.matchIds;
});
