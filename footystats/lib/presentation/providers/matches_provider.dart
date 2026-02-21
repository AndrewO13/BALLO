import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/matches_repository.dart';
import '../../domain/models/match_model.dart';

final matchesRepositoryProvider = Provider<MatchesRepository>((ref) {
  return MatchesRepository();
});

/// Selected gameweek filter (e.g. "GW11"). Null or empty = all.
class SelectedGameweekNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? value) => state = value;
}

final selectedGameweekProvider =
    NotifierProvider<SelectedGameweekNotifier, String?>(
  SelectedGameweekNotifier.new,
);

/// Fetches all matches from Supabase. Filter by gameweek via [selectedGameweekProvider].
final matchesProvider =
    FutureProvider.autoDispose<List<MatchModel>>((ref) async {
  final repo = ref.watch(matchesRepositoryProvider);
  final gameweek = ref.watch(selectedGameweekProvider);
  return repo.getMatches(gameweek: gameweek);
});

/// Matches for the home page "This week" carousel. Filters by date range
/// (Monday–Sunday of the current week).
final homeThisWeekMatchesProvider =
    FutureProvider.autoDispose<List<MatchModel>>((ref) async {
  final repo = ref.watch(matchesRepositoryProvider);
  return repo.getMatchesThisWeek();
});

/// Fetches a single match by id for the fixture detail page.
final fixtureMatchProvider =
    FutureProvider.autoDispose.family<MatchModel?, String>((ref, matchId) async {
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
}

final matchClockProvider =
    NotifierProvider.family<MatchClockNotifier, Duration, String>(
  MatchClockNotifier.new,
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
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
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
