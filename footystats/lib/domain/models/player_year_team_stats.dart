import '../../core/utils/match_stats_aggregation.dart';

class PlayerYearOverallStats {
  const PlayerYearOverallStats({
    required this.year,
    required this.matches,
    required this.goals,
    required this.assists,
    required this.tackles,
    required this.minutesPlayed,
    required this.avgRating,
  });

  final int year;
  final int matches;
  final int goals;
  final int assists;
  final int tackles;
  final int minutesPlayed;
  final double avgRating;

  static double _asDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static int _asInt(dynamic value) {
    return _asDouble(value).round();
  }

  factory PlayerYearOverallStats.fromJson(
    Map<String, dynamic> json, {
    required int year,
  }) {
    return PlayerYearOverallStats(
      year: _asInt(json['year']) == 0 ? year : _asInt(json['year']),
      matches: _asInt(json['matches']),
      goals: _asInt(json['goals']),
      assists: _asInt(json['assists']),
      tackles: _asInt(json['tackles']),
      minutesPlayed: _asInt(json['minutes_played']),
      avgRating: _asDouble(json['avg_rating']),
    );
  }

  factory PlayerYearOverallStats.fromMatchRows(
    List<Map<String, dynamic>> rows, {
    required int year,
  }) {
    var goals = 0.0;
    var assists = 0.0;
    var tackles = 0.0;
    var minutes = 0.0;
    var ratingSum = 0.0;
    var ratingCount = 0;

    for (final row in rows) {
      goals += _asDouble(row['goals']);
      assists += _asDouble(row['assists']);
      tackles += _asDouble(row['tackles']);
      minutes += MatchStatsAggregation.minutesFromRow(row);
      final rating = _asDouble(row['rating']);
      if (rating > 0 && MatchStatsAggregation.rowCountsAsAppearance(row)) {
        ratingSum += rating;
        ratingCount++;
      }
    }

    return PlayerYearOverallStats(
      year: year,
      matches: MatchStatsAggregation.countAppearances(rows),
      goals: goals.round(),
      assists: assists.round(),
      tackles: tackles.round(),
      minutesPlayed: minutes.round(),
      avgRating: ratingCount > 0 ? ratingSum / ratingCount : 0,
    );
  }
}

class PlayerAllTimeStats {
  const PlayerAllTimeStats({
    required this.matches,
    required this.goals,
    required this.assists,
    required this.tackles,
    required this.saves,
    required this.yellowCards,
    required this.redCards,
    required this.minutesPlayed,
    required this.avgRating,
  });

  final int matches;
  final int goals;
  final int assists;
  final int tackles;
  final int saves;
  final int yellowCards;
  final int redCards;
  final int minutesPlayed;
  final double avgRating;

  static double _asDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static int _asInt(dynamic value) => _asDouble(value).round();

  factory PlayerAllTimeStats.fromJson(Map<String, dynamic> json) {
    return PlayerAllTimeStats(
      matches: _asInt(json['matches']),
      goals: _asInt(json['goals']),
      assists: _asInt(json['assists']),
      tackles: _asInt(json['tackles']),
      saves: _asInt(json['saves']),
      yellowCards: _asInt(json['yellow_cards']),
      redCards: _asInt(json['red_cards']),
      minutesPlayed: _asInt(json['minutes_played']),
      avgRating: _asDouble(json['avg_rating']),
    );
  }

  factory PlayerAllTimeStats.fromMatchRows(List<Map<String, dynamic>> rows) {
    var goals = 0.0;
    var assists = 0.0;
    var tackles = 0.0;
    var saves = 0.0;
    var yellowCards = 0.0;
    var redCards = 0.0;
    var minutes = 0.0;
    var ratingSum = 0.0;
    var ratingCount = 0;

    for (final row in rows) {
      goals += _asDouble(row['goals']);
      assists += _asDouble(row['assists']);
      tackles += _asDouble(row['tackles']);
      saves += _asDouble(row['saves']);
      yellowCards += _asDouble(row['yellow_cards']);
      redCards += _asDouble(row['red_cards']);
      minutes += MatchStatsAggregation.minutesFromRow(row);
      final rating = _asDouble(row['rating']);
      if (rating > 0 && MatchStatsAggregation.rowCountsAsAppearance(row)) {
        ratingSum += rating;
        ratingCount++;
      }
    }

    return PlayerAllTimeStats(
      matches: MatchStatsAggregation.countAppearances(rows),
      goals: goals.round(),
      assists: assists.round(),
      tackles: tackles.round(),
      saves: saves.round(),
      yellowCards: yellowCards.round(),
      redCards: redCards.round(),
      minutesPlayed: minutes.round(),
      avgRating: ratingCount > 0 ? ratingSum / ratingCount : 0,
    );
  }
}

class PlayerYearTeamStats {
  const PlayerYearTeamStats({
    required this.teamId,
    required this.teamName,
    this.logoId,
    required this.year,
    required this.matches,
    required this.goals,
    required this.assists,
    required this.shots,
    required this.shotsOnTarget,
    required this.shotsOffTarget,
    required this.tackles,
    required this.saves,
    required this.yellowCards,
    required this.redCards,
    required this.minutesPlayed,
    required this.avgRating,
  });

  final String teamId;
  final String teamName;
  final String? logoId;
  final int year;
  final int matches;
  final int goals;
  final int assists;
  final int shots;
  final int shotsOnTarget;
  final int shotsOffTarget;
  final int tackles;
  final int saves;
  final int yellowCards;
  final int redCards;
  final int minutesPlayed;
  final double avgRating;

  static double _asDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static int _asInt(dynamic value) => _asDouble(value).round();

  factory PlayerYearTeamStats.fromJson(
    Map<String, dynamic> json, {
    required int year,
  }) {
    return PlayerYearTeamStats(
      teamId: json['team_id']?.toString() ?? '',
      teamName: json['team_name']?.toString() ?? 'Team',
      logoId: json['logo_id']?.toString(),
      year: _asInt(json['year']) == 0 ? year : _asInt(json['year']),
      matches: _asInt(json['matches']),
      goals: _asInt(json['goals']),
      assists: _asInt(json['assists']),
      shots: _asInt(json['shots']),
      shotsOnTarget: _asInt(json['shots_on_target']),
      shotsOffTarget: _asInt(json['shots_off_target']),
      tackles: _asInt(json['tackles']),
      saves: _asInt(json['saves']),
      yellowCards: _asInt(json['yellow_cards']),
      redCards: _asInt(json['red_cards']),
      minutesPlayed: _asInt(json['minutes_played']),
      avgRating: _asDouble(json['avg_rating']),
    );
  }

  factory PlayerYearTeamStats.fromMatchRows({
    required String teamId,
    required String teamName,
    String? logoId,
    required List<Map<String, dynamic>> rows,
    required int year,
  }) {
    var goals = 0.0;
    var assists = 0.0;
    var shots = 0.0;
    var shotsOnTarget = 0.0;
    var tackles = 0.0;
    var saves = 0.0;
    var yellowCards = 0.0;
    var redCards = 0.0;
    var minutes = 0.0;
    var ratingSum = 0.0;
    var ratingCount = 0;

    for (final row in rows) {
      goals += _asDouble(row['goals']);
      assists += _asDouble(row['assists']);
      shots += _asDouble(row['shots']);
      shotsOnTarget += _asDouble(row['shots_on_target']);
      tackles += _asDouble(row['tackles']);
      saves += _asDouble(row['saves']);
      yellowCards += _asDouble(row['yellow_cards']);
      redCards += _asDouble(row['red_cards']);
      minutes += MatchStatsAggregation.minutesFromRow(row);
      final rating = _asDouble(row['rating']);
      if (rating > 0 && MatchStatsAggregation.rowCountsAsAppearance(row)) {
        ratingSum += rating;
        ratingCount++;
      }
    }

    final shotsOffTarget = (shots - shotsOnTarget).clamp(0, double.infinity);

    return PlayerYearTeamStats(
      teamId: teamId,
      teamName: teamName,
      logoId: logoId,
      year: year,
      matches: MatchStatsAggregation.countAppearances(rows),
      goals: goals.round(),
      assists: assists.round(),
      shots: shots.round(),
      shotsOnTarget: shotsOnTarget.round(),
      shotsOffTarget: shotsOffTarget.round(),
      tackles: tackles.round(),
      saves: saves.round(),
      yellowCards: yellowCards.round(),
      redCards: redCards.round(),
      minutesPlayed: minutes.round(),
      avgRating: ratingCount > 0 ? ratingSum / ratingCount : 0,
    );
  }
}
