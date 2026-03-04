import 'team_model.dart';

/// Match status as stored in Supabase (upcoming, ongoing, halfTime, fullTime).
enum MatchStatus {
  upcoming,
  ongoing,
  halfTime,
  fullTime,
}

extension MatchStatusX on MatchStatus {
  static MatchStatus fromString(String? value) {
    if (value == null) return MatchStatus.upcoming;
    switch (value.toLowerCase()) {
      case 'upcoming':
        return MatchStatus.upcoming;
      case 'ongoing':
        return MatchStatus.ongoing;
      case 'halftime':
      case 'half_time':
        return MatchStatus.halfTime;
      case 'fulltime':
      case 'full_time':
        return MatchStatus.fullTime;
      default:
        return MatchStatus.upcoming;
    }
  }

  String get dbValue {
    switch (this) {
      case MatchStatus.upcoming:
        return 'upcoming';
      case MatchStatus.ongoing:
        return 'ongoing';
      case MatchStatus.halfTime:
        return 'halfTime';
      case MatchStatus.fullTime:
        return 'fullTime';
    }
  }
}

/// Match model from Supabase matches table with nested teamA/teamB.
class MatchModel {
  const MatchModel({
    required this.id,
    required this.matchDate,
    required this.matchTime,
    required this.status,
    required this.teamA,
    required this.teamB,
    this.teamAScore,
    this.teamBScore,
    this.gameweek,
    this.gameweekNumber,
    this.leagueName,
  });

  final String id;
  final DateTime matchDate;
  final String matchTime;
  final MatchStatus status;
  final TeamModel teamA;
  final TeamModel teamB;
  final int? teamAScore;
  final int? teamBScore;
  final String? gameweek;
  final int? gameweekNumber;
  final String? leagueName;

  factory MatchModel.fromJson(Map<String, dynamic> json) {
    final dateRaw = json['match_date'];
    DateTime date = DateTime.now();
    if (dateRaw != null) {
      if (dateRaw is String) {
        date = DateTime.tryParse(dateRaw) ?? date;
      } else if (dateRaw is DateTime) {
        date = dateRaw;
      }
    }

    final timeRaw = json['match_time'] ?? json['matchTime'];
    final timeStr = timeRaw is String
        ? timeRaw
        : timeRaw?.toString() ?? '';

    // Nested team: support both snake_case (team_a) and camelCase (teamA)
    final teamARaw = json['team_a'] ?? json['teamA'];
    final teamBRaw = json['team_b'] ?? json['teamB'];
    final teamA = teamARaw is Map<String, dynamic>
        ? TeamModel.fromJson(teamARaw)
        : const TeamModel(id: '', shortForm: '—');
    final teamB = teamBRaw is Map<String, dynamic>
        ? TeamModel.fromJson(teamBRaw)
        : const TeamModel(id: '', shortForm: '—');

    final scoreA = json['team_a_score'] ?? json['teamA_score'] ?? json['teamAScore'];
    final scoreB = json['team_b_score'] ?? json['teamB_score'] ?? json['teamBScore'];

    // Gameweek can be nested: gameweek.week
    final gameweekRaw = json['gameweek'];
    final gameweekNumber = gameweekRaw is Map<String, dynamic>
        ? int.tryParse(gameweekRaw['week']?.toString() ?? '')
        : int.tryParse(json['week']?.toString() ?? '');

    final gameweekValue =
        gameweekRaw is Map<String, dynamic> ? null : json['gameweek']?.toString();

    // League can be nested: league.league_name or league_name
    final leagueRaw = json['league'];
    final leagueName = leagueRaw is Map<String, dynamic>
        ? (leagueRaw['league_name']?.toString())
        : (json['league_name']?.toString());

    return MatchModel(
      id: json['id']?.toString() ?? '',
      matchDate: date,
      matchTime: timeStr,
      status: MatchStatusX.fromString(json['status']?.toString()),
      teamA: teamA,
      teamB: teamB,
      teamAScore: scoreA is int ? scoreA : int.tryParse(scoreA?.toString() ?? ''),
      teamBScore: scoreB is int ? scoreB : int.tryParse(scoreB?.toString() ?? ''),
      gameweek: gameweekValue,
      gameweekNumber: gameweekNumber,
      leagueName: leagueName,
    );
  }

  /// Score string for display, e.g. "1 - 2" or null if upcoming.
  String? get scoreText {
    if (teamAScore == null || teamBScore == null) return null;
    return '$teamAScore - $teamBScore';
  }

  /// Time formatted for display: upcoming = 24hr HH:mm, ongoing = mm:ss.
  String get timeDisplay {
    final t = matchTime.trim();
    if (t.isEmpty) {
      return status == MatchStatus.ongoing ? '0:00' : '—';
    }
    switch (status) {
      case MatchStatus.upcoming:
        return _formatTime24hr(t);
      case MatchStatus.ongoing:
        return _formatMinutesSeconds(t);
      case MatchStatus.halfTime:
      case MatchStatus.fullTime:
        return t; // HT/FT can keep raw or use statusText
    }
  }

  /// Status label for UI: time (formatted) for upcoming/ongoing, "HT", "FT".
  String get statusText {
    switch (status) {
      case MatchStatus.upcoming:
        return timeDisplay;
      case MatchStatus.halfTime:
        return 'HT';
      case MatchStatus.fullTime:
        return 'FT';
      case MatchStatus.ongoing:
        return timeDisplay;
    }
  }

  static String _formatTime24hr(String t) {
    // Already HH:mm or HH:mm:ss
    final parts = t.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }
    // ISO or datetime string
    final dt = DateTime.tryParse(t);
    if (dt != null) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return t;
  }

  static String _formatMinutesSeconds(String t) {
    final parts = t.split(':');
    if (parts.length >= 2) {
      final m = int.tryParse(parts[0]) ?? 0;
      final s = int.tryParse(parts[1]) ?? 0;
      return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    final m = int.tryParse(t) ?? 0;
    return '${m.toString().padLeft(2, '0')}:00';
  }
}
