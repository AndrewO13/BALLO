import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/matches_provider.dart';

/// Raw match event from DB (match_events table).
class MatchEventDisplay {
  const MatchEventDisplay({
    required this.id,
    required this.eventType,
    required this.minute,
    required this.second,
    required this.teamId,
    this.playerId,
    this.secondaryPlayerId,
    this.scorerName,
    this.assisterName,
  });

  final String id;
  final String eventType;
  final int minute;
  final int second;
  final String teamId;
  final String? playerId;
  final String? secondaryPlayerId;
  final String? scorerName;
  final String? assisterName;
}

/// Fetches match_events for a match and maps to display format.
final matchEventsProvider = FutureProvider.autoDispose
    .family<List<MatchEventDisplay>, String>((ref, matchId) async {
  if (matchId.isEmpty) return [];
  final repo = ref.watch(matchesRepositoryProvider);
  final raw = await repo.getMatchEvents(matchId);
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
      scorerName: scorerName,
      assisterName: assisterName,
    );
  }).toList();
});
