/// Display model for a row in [match_events].
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
    this.createdAt,
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
  final DateTime? createdAt;
}
