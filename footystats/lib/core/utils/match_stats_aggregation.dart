/// Helpers for aggregating [match_player_stats] rows (minutes from lineups/subs).
class MatchStatsAggregation {
  MatchStatsAggregation._();

  static double minutesFromRow(Map<String, dynamic> row) {
    final raw = row['minutes_played'] ?? row['minutes'];
    if (raw == null) return 0;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString()) ?? 0;
  }

  /// True when the player actually appeared on the pitch (non-zero scaled minutes).
  static bool rowCountsAsAppearance(Map<String, dynamic> row) =>
      minutesFromRow(row) > 0;

  static int countAppearances(Iterable<Map<String, dynamic>> rows) {
    final matchIds = <String>{};
    for (final row in rows) {
      if (!rowCountsAsAppearance(row)) continue;
      final matchId = row['match_id']?.toString();
      if (matchId != null && matchId.isNotEmpty) {
        matchIds.add(matchId);
      }
    }
    return matchIds.length;
  }
}
