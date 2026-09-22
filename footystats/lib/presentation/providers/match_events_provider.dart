import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/matches_repository.dart';
import '../../domain/models/match_event_display.dart';
import '../../domain/models/lineup_player_match_stats.dart';
import '../providers/matches_provider.dart';

export '../../domain/models/match_event_display.dart';
export '../../domain/models/lineup_player_match_stats.dart';

Future<List<MatchEventDisplay>> loadMatchEvents(
  MatchesRepository repo,
  String matchId,
) async {
  if (matchId.isEmpty) return [];
  final raw = await repo.getMatchEvents(matchId);
  final playerIds = <String>{};
  for (final e in raw) {
    final pid = e['player_id']?.toString();
    final sid = e['secondary_player_id']?.toString();
    if (pid != null && pid.isNotEmpty) playerIds.add(pid);
    if (sid != null && sid.isNotEmpty) playerIds.add(sid);
  }

  final namesById = <String, String>{};
  if (playerIds.isNotEmpty) {
    try {
      final client = Supabase.instance.client;
      final res = await client
          .from('players')
          .select('id, player_name')
          .inFilter('id', playerIds.toList());
      for (final row in res as List) {
        final map = Map<String, dynamic>.from(row as Map);
        final id = map['id']?.toString();
        final name = map['player_name']?.toString();
        if (id != null &&
            id.isNotEmpty &&
            name != null &&
            name.trim().isNotEmpty) {
          namesById[id] = name.trim();
        }
      }
    } catch (_) {
      // Keep relation names if direct lookup is not allowed.
    }
  }

  return raw.map((e) {
    final scorer = e['scorer'];
    final assister = e['assister'];
    String? scorerName;
    String? assisterName;
    if (scorer is Map) {
      scorerName = scorer['player_name']?.toString();
    }
    if (assister is Map) {
      assisterName = assister['player_name']?.toString();
    }
    final fallbackScorer = namesById[e['player_id']?.toString() ?? ''];
    final fallbackAssister =
        namesById[e['secondary_player_id']?.toString() ?? ''];
    return MatchEventDisplay(
      id: e['id']?.toString() ?? '',
      eventType: e['event_type']?.toString() ?? '',
      minute: (e['event_minute'] is int)
          ? e['event_minute'] as int
          : int.tryParse(e['event_minute']?.toString() ?? '0') ?? 0,
      second: (e['event_second'] is int)
          ? e['event_second'] as int
          : int.tryParse(e['event_second']?.toString() ?? '0') ?? 0,
      teamId: e['team_id']?.toString() ?? '',
      playerId: e['player_id']?.toString(),
      secondaryPlayerId: e['secondary_player_id']?.toString(),
      scorerName: (scorerName != null && scorerName.trim().isNotEmpty)
          ? scorerName.trim()
          : fallbackScorer,
      assisterName: (assisterName != null && assisterName.trim().isNotEmpty)
          ? assisterName.trim()
          : fallbackAssister,
      createdAt: _parseEventCreatedAt(e['created_at']),
    );
  }).toList();
}

DateTime? _parseEventCreatedAt(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  return DateTime.tryParse(raw.toString());
}

/// Live match events for a match (initial fetch + realtime updates).
final matchEventsProvider = StreamProvider.autoDispose
    .family<List<MatchEventDisplay>, String>((ref, matchId) {
  if (matchId.isEmpty) {
    return Stream.value(const []);
  }

  final repo = ref.watch(matchesRepositoryProvider);
  final controller = StreamController<List<MatchEventDisplay>>();

  Future<void> refresh() async {
    try {
      controller.add(await loadMatchEvents(repo, matchId));
    } catch (error, stackTrace) {
      controller.addError(error, stackTrace);
    }
  }

  unawaited(refresh());

  final channel = Supabase.instance.client
      .channel('match_events_$matchId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'match_events',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'match_id',
          value: matchId,
        ),
        callback: (_) => unawaited(refresh()),
      )
      .subscribe();

  ref.onDispose(() {
    unawaited(channel.unsubscribe());
    unawaited(controller.close());
  });

  return controller.stream;
});

/// Per-player stats derived from live match events (line-up badges).
final lineupPlayerStatsProvider = Provider.autoDispose
    .family<Map<String, LineupPlayerMatchStats>, String>((ref, matchId) {
  final events = ref.watch(matchEventsProvider(matchId)).asData?.value ?? [];
  return aggregateLineupPlayerStats(events);
});
