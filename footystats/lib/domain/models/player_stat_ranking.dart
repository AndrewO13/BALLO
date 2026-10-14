enum RankingPeriod { year, allTime }

enum RankingStat {
  goals,
  assists,
  goalContributions,
  shootingPct,
  avgRating,
  tackles,
  saves,
  shotsOnTarget,
  goalsPerMatch,
}

extension RankingPeriodX on RankingPeriod {
  String get rpcValue => switch (this) {
    RankingPeriod.year => 'year',
    RankingPeriod.allTime => 'all_time',
  };

  String labelFor(int year) => switch (this) {
    RankingPeriod.year => '$year',
    RankingPeriod.allTime => 'All time',
  };
}

extension RankingStatX on RankingStat {
  String get rpcValue => switch (this) {
    RankingStat.goals => 'goals',
    RankingStat.assists => 'assists',
    RankingStat.goalContributions => 'goal_contributions',
    RankingStat.shootingPct => 'shooting_pct',
    RankingStat.avgRating => 'avg_rating',
    RankingStat.tackles => 'tackles',
    RankingStat.saves => 'saves',
    RankingStat.shotsOnTarget => 'shots_on_target',
    RankingStat.goalsPerMatch => 'goals_per_match',
  };

  String get chipLabel => switch (this) {
    RankingStat.goals => 'Goals',
    RankingStat.assists => 'Assists',
    RankingStat.goalContributions => 'G+A',
    RankingStat.shootingPct => 'Shooting %',
    RankingStat.avgRating => 'Rating',
    RankingStat.tackles => 'Tackles',
    RankingStat.saves => 'Saves',
    RankingStat.shotsOnTarget => 'On target',
    RankingStat.goalsPerMatch => 'Goals / game',
  };

  String get title => switch (this) {
    RankingStat.goals => 'Goals',
    RankingStat.assists => 'Assists',
    RankingStat.goalContributions => 'Goal involvements',
    RankingStat.shootingPct => 'Shooting percentage',
    RankingStat.avgRating => 'Average rating',
    RankingStat.tackles => 'Tackles',
    RankingStat.saves => 'Saves',
    RankingStat.shotsOnTarget => 'Shots on target',
    RankingStat.goalsPerMatch => 'Goals per game',
  };

  String get valueCaption => switch (this) {
    RankingStat.goals => 'Goals',
    RankingStat.assists => 'Assists',
    RankingStat.goalContributions => 'G+A',
    RankingStat.shootingPct => 'On target',
    RankingStat.avgRating => 'Rating',
    RankingStat.tackles => 'Tackles',
    RankingStat.saves => 'Saves',
    RankingStat.shotsOnTarget => 'On target',
    RankingStat.goalsPerMatch => 'Per game',
  };

  bool get isRateStat => switch (this) {
    RankingStat.shootingPct ||
    RankingStat.avgRating ||
    RankingStat.goalsPerMatch => true,
    _ => false,
  };

  String formatValue(double value) {
    switch (this) {
      case RankingStat.shootingPct:
        final rounded = (value * 10).round() / 10;
        return rounded == rounded.roundToDouble()
            ? '${rounded.round()}%'
            : '${rounded.toStringAsFixed(1)}%';
      case RankingStat.avgRating:
      case RankingStat.goalsPerMatch:
        return value.toStringAsFixed(2);
      case RankingStat.goals:
      case RankingStat.assists:
      case RankingStat.goalContributions:
      case RankingStat.tackles:
      case RankingStat.saves:
      case RankingStat.shotsOnTarget:
        return value.round().toString();
    }
  }
}

class PlayerStatRanking {
  const PlayerStatRanking({
    required this.playerId,
    required this.playerName,
    this.imageUrl,
    required this.position,
    required this.teamName,
    required this.matches,
    required this.statValue,
    required this.rank,
  });

  final String playerId;
  final String playerName;
  final String? imageUrl;
  final String position;
  final String teamName;
  final int matches;
  final double statValue;
  final int rank;

  factory PlayerStatRanking.fromRpcRow(Map<String, dynamic> json) {
    double asDouble(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    int asInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.round();
      return int.tryParse(v.toString()) ??
          double.tryParse(v.toString())?.round() ??
          0;
    }

    return PlayerStatRanking(
      playerId: json['player_id']?.toString() ?? '',
      playerName: json['player_name']?.toString().trim().isNotEmpty == true
          ? json['player_name'].toString().trim()
          : 'Player',
      imageUrl: json['image_url']?.toString(),
      position:
          (json['player_position'] ?? json['position'])?.toString().trim() ??
          '',
      teamName: json['team_name']?.toString().trim() ?? '',
      matches: asInt(json['matches']),
      statValue: asDouble(json['stat_value']),
      rank: asInt(json['board_rank']),
    );
  }
}
