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
  });

  final String playerId;
  final String teamId;
  final String name;
  final double rating;
  final String? imageUrl;
  final String? position;
  final String? teamShortForm;

  String teamLogoPath(MatchModel match) {
    if (teamId == match.teamA.id) return match.teamA.logoPath;
    if (teamId == match.teamB.id) return match.teamB.logoPath;
    return match.teamA.logoPath;
  }

  String teamDisplayName(MatchModel match) {
    if (teamId == match.teamA.id) return match.teamA.displayName;
    if (teamId == match.teamB.id) return match.teamB.displayName;
    return '—';
  }

  bool isTeamA(MatchModel match) => teamId == match.teamA.id;
}
