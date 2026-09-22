import '../../domain/models/match_odds.dart';

/// One finished match from a team's perspective (for form / goal trends).
class TeamRecentMatchSnapshot {
  const TeamRecentMatchSnapshot({
    required this.isWin,
    required this.isDraw,
    required this.goalsFor,
    required this.goalsAgainst,
  });

  final bool isWin;
  final bool isDraw;
  final int goalsFor;
  final int goalsAgainst;
}

/// Inputs derived only from data Ballo already tracks.
class MatchOddsFactors {
  const MatchOddsFactors({
    required this.teamARecent,
    required this.teamBRecent,
    this.teamAStandingPpg,
    this.teamBStandingPpg,
    this.teamASquadRating = 0,
    this.teamBSquadRating = 0,
    this.teamASeasonGoalDiffPerGame = 0,
    this.teamBSeasonGoalDiffPerGame = 0,
    this.h2hTeamAWins = 0,
    this.h2hDraws = 0,
    this.h2hTeamBWins = 0,
  });

  final List<TeamRecentMatchSnapshot> teamARecent;
  final List<TeamRecentMatchSnapshot> teamBRecent;
  final double? teamAStandingPpg;
  final double? teamBStandingPpg;
  final double teamASquadRating;
  final double teamBSquadRating;
  final double teamASeasonGoalDiffPerGame;
  final double teamBSeasonGoalDiffPerGame;
  final int h2hTeamAWins;
  final int h2hDraws;
  final int h2hTeamBWins;
}

/// Converts team strength signals into win / draw / lose probabilities.
///
/// Factor weights and reasoning:
/// - **Recent form (30%)** — Last five results (W/D/L) with recency decay mirror
///   current momentum; streaks are tracked from finished matches in-app.
/// - **Goal balance (25%)** — Goals for/against per game from recent matches plus
///   season summary goal difference; reflects attack and defence quality.
/// - **League standing (20%)** — Points per game from standings when available;
///   captures how often each side wins in their competition.
/// - **Squad rating (15%)** — Average Ballo player ratings in recent
///   appearances; individual performance is tracked per match.
/// - **Head-to-head (10%)** — Historical results between these two teams;
///   rivalry / stylistic matchup from stored H2H fixtures.
/// - **Home edge** — Small boost for team A (left/home in UI), as in real football.
///
/// Output is for entertainment only (in-app “Predictions”), not betting odds.
class MatchOddsCalculator {
  MatchOddsCalculator._();

  static MatchOdds compute(MatchOddsFactors factors) {
    final strengthA = _teamStrength(
      recent: factors.teamARecent,
      standingPpg: factors.teamAStandingPpg,
      squadRating: factors.teamASquadRating,
      seasonGoalDiffPerGame: factors.teamASeasonGoalDiffPerGame,
      h2hShare: _h2hShare(
        wins: factors.h2hTeamAWins,
        draws: factors.h2hDraws,
        total: factors.h2hTeamAWins +
            factors.h2hDraws +
            factors.h2hTeamBWins,
      ),
      homeBoost: 0.06,
    );

    final strengthB = _teamStrength(
      recent: factors.teamBRecent,
      standingPpg: factors.teamBStandingPpg,
      squadRating: factors.teamBSquadRating,
      seasonGoalDiffPerGame: factors.teamBSeasonGoalDiffPerGame,
      h2hShare: _h2hShare(
        wins: factors.h2hTeamBWins,
        draws: factors.h2hDraws,
        total: factors.h2hTeamAWins +
            factors.h2hDraws +
            factors.h2hTeamBWins,
      ),
      homeBoost: 0,
    );

    if (strengthA <= 0 && strengthB <= 0) {
      return MatchOdds.neutral();
    }

    final gap = (strengthA - strengthB).abs();
    final drawBase = 0.22 + 0.18 * (1.0 - gap.clamp(0.0, 1.0));

    final rawHome = strengthA.clamp(0.05, 1.0);
    final rawAway = strengthB.clamp(0.05, 1.0);
    final rawDraw = drawBase * (rawHome + rawAway) * 0.55;

    final sum = rawHome + rawDraw + rawAway;
    return MatchOdds(
      homeWin: rawHome / sum,
      draw: rawDraw / sum,
      awayWin: rawAway / sum,
    );
  }

  static double _teamStrength({
    required List<TeamRecentMatchSnapshot> recent,
    required double? standingPpg,
    required double squadRating,
    required double seasonGoalDiffPerGame,
    required double h2hShare,
    required double homeBoost,
  }) {
    final form = _formScore(recent);
    final goals = _goalBalanceScore(recent, seasonGoalDiffPerGame);
    final standing = standingPpg != null
        ? (standingPpg / 3.0).clamp(0.0, 1.0)
        : form;
    final squad = squadRating > 0
        ? (squadRating / 10.0).clamp(0.0, 1.0)
        : 0.5;

    final blended = 0.30 * form +
        0.25 * goals +
        0.20 * standing +
        0.15 * squad +
        0.10 * h2hShare;

    return (blended + homeBoost).clamp(0.05, 1.0);
  }

  static double _formScore(List<TeamRecentMatchSnapshot> matches) {
    if (matches.isEmpty) return 0.5;
    var sum = 0.0;
    var weightSum = 0.0;
    for (var i = 0; i < matches.length; i++) {
      final weight = 1.0 - i * 0.08;
      final pts = matches[i].isDraw
          ? 0.35
          : (matches[i].isWin ? 1.0 : 0.0);
      sum += pts * weight;
      weightSum += weight;
    }
    return (sum / weightSum).clamp(0.0, 1.0);
  }

  static double _goalBalanceScore(
    List<TeamRecentMatchSnapshot> recent,
    double seasonGoalDiffPerGame,
  ) {
    var score = 0.5;
    if (recent.isNotEmpty) {
      var gf = 0;
      var ga = 0;
      for (final m in recent) {
        gf += m.goalsFor;
        ga += m.goalsAgainst;
      }
      final gdPerGame = (gf - ga) / recent.length;
      score = ((gdPerGame + 2.0) / 4.0).clamp(0.0, 1.0);
    }
    if (seasonGoalDiffPerGame != 0) {
      final seasonPart =
          ((seasonGoalDiffPerGame + 1.5) / 3.0).clamp(0.0, 1.0);
      score = recent.isEmpty ? seasonPart : (score * 0.6 + seasonPart * 0.4);
    }
    return score;
  }

  static double _h2hShare({
    required int wins,
    required int draws,
    required int total,
  }) {
    if (total <= 0) return 0.5;
    return ((wins + draws * 0.35) / total).clamp(0.0, 1.0);
  }
}
