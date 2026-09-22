import 'dart:async';

import 'package:riverpod/riverpod.dart';
import 'matches_provider.dart';
import 'server_synced_match_clock_provider.dart';

/// Adapter provider that provides match timing in the format expected by existing code
/// while using the server-synced clock internally for consistency.
///
/// For ongoing matches, this returns elapsed duration from server time.
/// For non-ongoing matches, returns local in-memory timer (for compatibility).
class MatchTimerAdapterNotifier extends Notifier<Duration> {
  MatchTimerAdapterNotifier(this.matchId);

  final String matchId;
  Timer? _mirrorTimer;

  @override
  Duration build() {
    ref.onDispose(() {
      _mirrorTimer?.cancel();
    });
    return Duration.zero;
  }

  /// Check if this match has database timing data
  Future<bool> _hasTimingData() async {
    try {
      final timingData = await ref
          .read(matchesRepositoryProvider)
          .getMatchTimingData(matchId);
      return timingData != null && timingData['started_at'] != null;
    } catch (_) {
      return false;
    }
  }

  /// Sync this timer with the server-synced provider
  Future<void> _syncWithServerClock() async {
    try {
      final hasData = await _hasTimingData();
      if (!hasData) return;

      final timingData = await ref
          .read(matchesRepositoryProvider)
          .getMatchTimingData(matchId);
      if (timingData == null) return;

      final startedAtStr = timingData['started_at'] as String?;
      if (startedAtStr == null) return;

      final startedAt = DateTime.parse(startedAtStr).toUtc();
      final pausedSeconds =
          (timingData['total_paused_duration_seconds'] as int?) ?? 0;

      // Get the server-synced notifier
      final serverClock = ref.read(
        serverSyncedMatchClockProvider(matchId).notifier,
      );

      // Start it with the database timing data
      await serverClock.start(
        matchStartedAt: startedAt,
        totalPausedSeconds: pausedSeconds,
      );

      _startMirroringServerClock();
    } catch (_) {
      // If sync fails, continue with local timer
    }
  }

  void _startMirroringServerClock() {
    _mirrorTimer?.cancel();
    final serverClock = serverSyncedMatchClockProvider(matchId);
    state = ref.read(serverClock).elapsedDuration;
    _mirrorTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = ref.read(serverClock).elapsedDuration;
    });
  }

  /// Start the timer and sync with database
  Future<void> start() async {
    try {
      // Record start in database
      await ref.read(matchesRepositoryProvider).recordMatchStart(matchId);

      // Sync with server clock
      await _syncWithServerClock();
    } catch (_) {
      // Fallback: use old behavior and tick locally so the UI still advances.
      final fallbackClock = ref.read(matchClockProvider(matchId).notifier);
      fallbackClock.start();
      _mirrorTimer?.cancel();
      _mirrorTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        state = ref.read(matchClockProvider(matchId));
      });
    }
  }

  /// Pause the timer
  void pause() {
    ref.read(serverSyncedMatchClockProvider(matchId).notifier).pause();
    // No pause method on old provider - state is preserved
  }

  /// Resume the timer after pause
  void resume() {
    ref.read(serverSyncedMatchClockProvider(matchId).notifier).resume();
    // No resume method on old provider - manually restart if needed
  }

  /// Reset the timer
  void reset() {
    _mirrorTimer?.cancel();
    ref.read(serverSyncedMatchClockProvider(matchId).notifier).reset();
    ref.read(matchClockProvider(matchId).notifier).reset();
    state = Duration.zero;
  }

  /// Set elapsed time to specific duration
  void setTo(Duration d) {
    state = d;
    ref.read(matchClockProvider(matchId).notifier).setTo(d);
  }

  /// Record that match is entering halftime (updates pause duration in database)
  Future<void> recordHalftimePause() async {
    try {
      final elapsedSeconds = state.inSeconds;
      // First half is typically 45 minutes
      const firstHalfSeconds = 2700; // 45 * 60
      final haltimeOvertime = (elapsedSeconds - firstHalfSeconds)
          .clamp(0, double.infinity)
          .toInt();

      // Record the pause (halftime break)
      await ref
          .read(matchesRepositoryProvider)
          .recordPauseDuration(
            matchId,
            haltimeOvertime + 300,
          ); // ~5 min halftime
    } catch (_) {}
  }
}

/// Family provider for match timer adapter (bridges old and new systems)
final matchTimerAdapterProvider =
    NotifierProvider.family<MatchTimerAdapterNotifier, Duration, String>(
      MatchTimerAdapterNotifier.new,
    );

/// Provider that returns both the duration AND sync status
class MatchTimerWithSyncStatusNotifier
    extends Notifier<({Duration duration, bool isSync})> {
  MatchTimerWithSyncStatusNotifier(this.matchId);

  final String matchId;

  @override
  ({Duration duration, bool isSync}) build() {
    // Listen to both providers and combine their states
    final duration = ref.watch(matchTimerAdapterProvider(matchId));
    final serverClock = ref.watch(serverSyncedMatchClockProvider(matchId));

    return (duration: duration, isSync: serverClock.isSync);
  }
}

/// Provider combining duration and sync status for UI
final matchTimerWithSyncStatusProvider =
    NotifierProvider.family<
      MatchTimerWithSyncStatusNotifier,
      ({Duration duration, bool isSync}),
      String
    >(MatchTimerWithSyncStatusNotifier.new);
