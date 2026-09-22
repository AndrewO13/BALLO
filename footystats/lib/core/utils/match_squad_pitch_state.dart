import '../../domain/models/match_event_display.dart';
import '../../domain/models/squad_layout.dart';

/// Tracks who is on the pitch vs bench after kickoff substitutions.
class MatchSquadPitchState {
  const MatchSquadPitchState({
    required this.onPitch,
    required this.onBench,
  });

  final Set<String> onPitch;
  final Set<String> onBench;

  factory MatchSquadPitchState.fromLineupAndEvents({
    required SquadLayoutData layout,
    required List<MatchEventDisplay> events,
    String? teamId,
  }) {
    final pitch = <String>{};
    final bench = <String>{};

    for (final entry in layout.players.entries) {
      if (entry.key.isEmpty || entry.key == 'fallback') continue;
      if (entry.value.onBench) {
        bench.add(entry.key);
      } else {
        pitch.add(entry.key);
      }
    }

    final subs = events.where((e) {
      if (e.eventType != 'substitution') return false;
      if (teamId == null || teamId.isEmpty) return true;
      return e.teamId == teamId;
    });

    for (final sub in subs) {
      final onId = sub.playerId;
      final offId = sub.secondaryPlayerId;
      if (onId != null && onId.isNotEmpty) {
        bench.remove(onId);
        pitch.add(onId);
      }
      if (offId != null && offId.isNotEmpty) {
        pitch.remove(offId);
        bench.add(offId);
      }
    }

    return MatchSquadPitchState(onPitch: pitch, onBench: bench);
  }

  bool isOnPitch(String playerId) => onPitch.contains(playerId);

  bool isOnBench(String playerId) => onBench.contains(playerId);
}
