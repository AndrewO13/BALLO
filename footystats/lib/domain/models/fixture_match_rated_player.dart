import 'match_model.dart';

/// One player row from `match_player_stats` with rating for a finished match.
class FixtureMatchRatedPlayer {
  const FixtureMatchRatedPlayer({
    required this.playerId,
    required this.teamId,
    required this.name,
    required this.rating,
    this.imageUrl,
    this.position,
    this.teamShortForm,
    this.teamTeamName,
  });

  final String playerId;
  final String teamId;
  final String name;
  final double rating;
  final String? imageUrl;
  final String? position;
  final String? teamShortForm;
  /// From `teams.team_name` when loading ratings (fixture match may omit full name).
  final String? teamTeamName;

  String teamLogoPath(MatchModel match) {
    if (teamId == match.teamA.id) return match.teamA.logoPath;
    if (teamId == match.teamB.id) return match.teamB.logoPath;
    return match.teamA.logoPath;
  }

  String teamDisplayName(MatchModel match) {
    final t = teamId == match.teamA.id
        ? match.teamA
        : teamId == match.teamB.id
            ? match.teamB
            : null;
    final fromMatch = t?.teamName?.trim();
    if (fromMatch != null && fromMatch.isNotEmpty) return fromMatch;
    final fromRow = teamTeamName?.trim();
    if (fromRow != null && fromRow.isNotEmpty) return fromRow;
    if (t != null) return t.displayName;
    return '—';
  }

  bool isTeamA(MatchModel match) => teamId == match.teamA.id;
}
