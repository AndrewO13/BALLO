/// Aggregated team row from `match_team_stats` for fixture UI.
class MatchTeamStatsSnapshot {
  const MatchTeamStatsSnapshot({
    this.goals = 0,
    this.shots = 0,
    this.shotsOnTarget = 0,
    this.assists = 0,
    this.tackles = 0,
    this.saves = 0,
    this.yellowCards = 0,
    this.redCards = 0,
    this.xg = 0.0,
  });

  final int goals;
  final int shots;
  final int shotsOnTarget;
  final int assists;
  final int tackles;
  final int saves;
  final int yellowCards;
  final int redCards;
  final double xg;

  /// Best-effort when only total shots and on-target are stored.
  int get shotsOffTarget {
    final d = shots - shotsOnTarget;
    return d < 0 ? 0 : d;
  }

  factory MatchTeamStatsSnapshot.fromRow(Map<String, dynamic>? row) {
    if (row == null) return const MatchTeamStatsSnapshot();

    int i(String k) {
      final v = row[k];
      if (v is int) return v;
      return int.tryParse(v?.toString() ?? '0') ?? 0;
    }

    double d() {
      for (final k in ['XG', 'xG', 'xg']) {
        final v = row[k];
        if (v is double) return v;
        if (v is num) return v.toDouble();
        final p = double.tryParse(v?.toString() ?? '');
        if (p != null) return p;
      }
      return 0.0;
    }

    return MatchTeamStatsSnapshot(
      goals: i('goals'),
      shots: i('shots'),
      shotsOnTarget: i('shots_on_target'),
      assists: i('assists'),
      tackles: i('tackles'),
      saves: i('saves'),
      yellowCards: i('yellow_cards'),
      redCards: i('red_cards'),
      xg: d(),
    );
  }
}
