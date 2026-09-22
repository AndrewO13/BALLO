import 'dart:async';
import 'package:riverpod/riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'matches_provider.dart';

/// Represents the synchronized match clock state and server time info
class ServerSyncedMatchClock {
  const ServerSyncedMatchClock({
    required this.elapsedDuration,
    required this.isSync,
    required this.lastSyncTime,
    required this.timeDriftSeconds,
  });

  /// The current elapsed time in the match
  final Duration elapsedDuration;

  /// Whether this clock is currently synced with server
  final bool isSync;

  /// Last time we synced with the server
  final DateTime? lastSyncTime;

  /// Drift from server in seconds (negative = behind, positive = ahead)
  final int timeDriftSeconds;

  ServerSyncedMatchClock copyWith({
    Duration? elapsedDuration,
    bool? isSync,
    DateTime? lastSyncTime,
    int? timeDriftSeconds,
  }) => ServerSyncedMatchClock(
    elapsedDuration: elapsedDuration ?? this.elapsedDuration,
    isSync: isSync ?? this.isSync,
    lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    timeDriftSeconds: timeDriftSeconds ?? this.timeDriftSeconds,
  );
}

/// Notifier for a match clock synced with database timestamps
///
/// This replaces the in-memory MatchClockNotifier for ongoing matches.
/// It calculates elapsed time from database instead of local device clock.
class ServerSyncedMatchClockNotifier extends Notifier<ServerSyncedMatchClock> {
  ServerSyncedMatchClockNotifier(this.matchId);

  final String matchId;
  Timer? _localTimer;
  Timer? _syncTimer;

  // Store match timing data locally to reduce queries
  DateTime? _matchStartedAt;
  DateTime? _halftimePausedAt;
  DateTime? _resumedFromHalftimeAt;
  int _totalPausedSeconds = 0;
  String? _matchStatus;

  @override
  ServerSyncedMatchClock build() {
    ref.onDispose(() {
      _localTimer?.cancel();
      _syncTimer?.cancel();
    });
    return const ServerSyncedMatchClock(
      elapsedDuration: Duration.zero,
      isSync: false,
      lastSyncTime: null,
      timeDriftSeconds: 0,
    );
  }

  /// Start the synced timer and periodically sync with server
  Future<void> start({
    required DateTime matchStartedAt,
    required int totalPausedSeconds,
  }) async {
    _matchStartedAt = matchStartedAt;
    _totalPausedSeconds = totalPausedSeconds;

    // Initialize with current elapsed time
    _updateElapsedTime();

    // Update locally every second
    _localTimer?.cancel();
    _localTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateElapsedTime();
    });

    // Sync with server every 15 seconds to catch drift
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      await _syncWithServer();
    });

    // Initial sync with server
    await _syncWithServer();
  }

  /// Pause the timer
  void pause() {
    _localTimer?.cancel();
    _localTimer = null;
  }

  /// Freezes the clock at the moment the user confirms half-time (before DB sync).
  void captureHalftimePause() {
    _matchStatus = 'halfTime';
    _halftimePausedAt = DateTime.now().toUtc();
    pause();
    _updateElapsedTime();
  }

  /// Resume the timer from a pause
  void resume() {
    if (_matchStartedAt == null) return;
    _localTimer?.cancel();
    _localTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateElapsedTime();
    });
  }

  /// Reset to initial state
  void reset() {
    _localTimer?.cancel();
    _syncTimer?.cancel();
    _localTimer = null;
    _syncTimer = null;
    _matchStartedAt = null;
    _halftimePausedAt = null;
    _resumedFromHalftimeAt = null;
    _totalPausedSeconds = 0;
    _matchStatus = null;
    state = const ServerSyncedMatchClock(
      elapsedDuration: Duration.zero,
      isSync: false,
      lastSyncTime: null,
      timeDriftSeconds: 0,
    );
  }

  /// Update elapsed time based on stored start time
  void _updateElapsedTime() {
    final now = DateTime.now().toUtc();
    final elapsedSeconds = _calculateElapsedSeconds(now);
    final elapsed = Duration(
      seconds: elapsedSeconds.clamp(0, double.infinity).toInt(),
    );

    state = state.copyWith(
      elapsedDuration: elapsed,
      // Mark as out-of-sync after 5 seconds without explicit sync
      isSync:
          state.lastSyncTime != null &&
          now.difference(state.lastSyncTime!).inSeconds < 5,
    );
  }

  int _calculateElapsedSeconds(DateTime now) {
    final startedAt = _matchStartedAt;
    if (startedAt == null) return 0;

    if (_matchStatus == 'halfTime' && _halftimePausedAt != null) {
      return _halftimePausedAt!.difference(startedAt).inSeconds -
          _totalPausedSeconds;
    }

    if (_matchStatus == 'ongoing' && _resumedFromHalftimeAt != null) {
      return now.difference(_resumedFromHalftimeAt!).inSeconds;
    }

    return now.difference(startedAt).inSeconds - _totalPausedSeconds;
  }

  /// Sync with server to check for drift and get latest paused duration
  Future<void> _syncWithServer() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('matches')
          .select(
            'started_at, halftime_paused_at, resumed_from_halftime_at, half_duration_minutes, total_paused_duration_seconds, status',
          )
          .eq('id', matchId)
          .maybeSingle();

      if (response == null) return;

      final startedAt = response['started_at'] as String?;
      if (startedAt == null) return;

      final newStartedAt = DateTime.parse(startedAt).toUtc();
      final halftimePausedAt = response['halftime_paused_at'] as String?;
      final resumedFromHalftimeAt =
          response['resumed_from_halftime_at'] as String?;
      final newPausedSeconds =
          response['total_paused_duration_seconds'] as int? ?? 0;
      final status = response['status'] as String?;
      final halfDurationRaw = response['half_duration_minutes'];
      final halfDuration = halfDurationRaw is int
          ? halfDurationRaw
          : int.tryParse(halfDurationRaw?.toString() ?? '');

      // Calculate current server time (approximately)
      final now = DateTime.now().toUtc();
      final serverElapsed = _calculateServerElapsedSeconds(
        now: now,
        startedAt: newStartedAt,
        halftimePausedAt: halftimePausedAt == null
            ? null
            : DateTime.parse(halftimePausedAt).toUtc(),
        resumedFromHalftimeAt: resumedFromHalftimeAt == null
            ? null
            : DateTime.parse(resumedFromHalftimeAt).toUtc(),
        pausedSeconds: newPausedSeconds,
        status: status,
      );

      // Calculate local elapsed
      final localElapsed = state.elapsedDuration.inSeconds;

      // Calculate drift
      final drift = serverElapsed - localElapsed;

      // Update state with sync info
      _matchStartedAt = newStartedAt;
      _halftimePausedAt = halftimePausedAt == null
          ? null
          : DateTime.parse(halftimePausedAt).toUtc();
      _resumedFromHalftimeAt = resumedFromHalftimeAt == null
          ? null
          : DateTime.parse(resumedFromHalftimeAt).toUtc();
      _totalPausedSeconds = newPausedSeconds;
      _matchStatus = status;

      if (halfDuration != null) {
        ref
            .read(matchTimerConfigProvider(matchId).notifier)
            .applyHalfDurationFromDatabase(halfDuration);
      }

      _updateElapsedTime();

      state = state.copyWith(
        isSync: true,
        lastSyncTime: now,
        timeDriftSeconds: drift,
      );

      // If drift is significant (> 2 seconds), resync immediately
      if (drift.abs() > 2) {
        _updateElapsedTime();
      }
    } catch (e) {
      // Network error or query failed - keep using local time
      state = state.copyWith(isSync: false);
    }
  }

  int _calculateServerElapsedSeconds({
    required DateTime now,
    required DateTime startedAt,
    required DateTime? halftimePausedAt,
    required DateTime? resumedFromHalftimeAt,
    required int pausedSeconds,
    required String? status,
  }) {
    if (status == 'halfTime' && halftimePausedAt != null) {
      return halftimePausedAt.difference(startedAt).inSeconds - pausedSeconds;
    }

    if (status == 'ongoing' && resumedFromHalftimeAt != null) {
      return now.difference(resumedFromHalftimeAt).inSeconds;
    }

    return now.difference(startedAt).inSeconds - pausedSeconds;
  }

  /// Set the paused duration (called when status changes)
  void setPausedDuration(int pausedSeconds) {
    _totalPausedSeconds = pausedSeconds;
    _updateElapsedTime();
  }
}

/// Family provider for server-synced match clocks
final serverSyncedMatchClockProvider =
    NotifierProvider.family<
      ServerSyncedMatchClockNotifier,
      ServerSyncedMatchClock,
      String
    >(ServerSyncedMatchClockNotifier.new);
