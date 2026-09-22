import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/match_odds_calculator.dart';
import '../../domain/models/match_odds.dart';
import 'leagues_repository.dart';
import 'teams_repository.dart';

/// Loads match context from Supabase and derives [MatchOdds].
class MatchOddsRepository {
  MatchOddsRepository({
    SupabaseClient? client,
    TeamsRepository? teamsRepository,
    LeaguesRepository? leaguesRepository,
  })  : _client = client ?? Supabase.instance.client,
        _teamsRepository = teamsRepository ?? TeamsRepository(client: client),
        _leaguesRepository =
            leaguesRepository ?? LeaguesRepository(client: client);

  final SupabaseClient _client;
  final TeamsRepository _teamsRepository;
  final LeaguesRepository _leaguesRepository;

  Future<Map<String, MatchOdds>> computeForMatches(List<String> matchIds) async {
    final ids = matchIds.where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return const {};
    try {
      final res = await _client.rpc(
        'get_match_odds_inputs',
        params: {'p_match_ids': ids},
      );
      final rows = List<Map<String, dynamic>>.from(res as List);
      final out = <String, MatchOdds>{};
      for (final row in rows) {
        final id = row['match_id']?.toString();
        if (id == null || id.isEmpty) continue;
        out[id] = MatchOddsCalculator.compute(_factorsFromRpcRow(row));
      }
      for (final id in ids) {
        out.putIfAbsent(id, MatchOdds.neutral);
      }
      return out;
    } catch (_) {
      final out = <String, MatchOdds>{};
      for (final id in ids) {
        out[id] = await _computeForMatchLegacy(id);
      }
      return out;
    }
  }

  MatchOddsFactors _factorsFromRpcRow(Map<String, dynamic> row) {
    List<TeamRecentMatchSnapshot> parseForm(dynamic raw) {
      if (raw is! List) return const [];
      return raw.whereType<Map>().map((item) {
        return TeamRecentMatchSnapshot(
          isWin: item['is_win'] == true,
          isDraw: item['is_draw'] == true,
          goalsFor: (item['goals_for'] as num?)?.toInt() ?? 0,
          goalsAgainst: (item['goals_against'] as num?)?.toInt() ?? 0,
        );
      }).toList();
    }

    return MatchOddsFactors(
      teamARecent: parseForm(row['team_a_form']),
      teamBRecent: parseForm(row['team_b_form']),
      h2hTeamAWins: (row['h2h_a_wins'] as num?)?.toInt() ?? 0,
      h2hDraws: (row['h2h_draws'] as num?)?.toInt() ?? 0,
      h2hTeamBWins: (row['h2h_b_wins'] as num?)?.toInt() ?? 0,
      teamASquadRating: (row['team_a_squad_rating'] as num?)?.toDouble() ?? 0,
      teamBSquadRating: (row['team_b_squad_rating'] as num?)?.toDouble() ?? 0,
      teamASeasonGoalDiffPerGame:
          (row['team_a_gd_per_game'] as num?)?.toDouble() ?? 0,
      teamBSeasonGoalDiffPerGame:
          (row['team_b_gd_per_game'] as num?)?.toDouble() ?? 0,
      teamAStandingPpg: (row['team_a_ppg'] as num?)?.toDouble(),
      teamBStandingPpg: (row['team_b_ppg'] as num?)?.toDouble(),
    );
  }

  Future<MatchOdds> computeForMatch(String matchId) async {
    if (matchId.isEmpty) return MatchOdds.neutral();
    final batch = await computeForMatches([matchId]);
    return batch[matchId] ?? MatchOdds.neutral();
  }

  Future<MatchOdds> _computeForMatchLegacy(String matchId) async {

    final matchRow = await _client
        .from('matches')
        .select(
          'id, match_date, match_time, teamA, teamB, league_id, season_id',
        )
        .eq('id', matchId)
        .maybeSingle();
    if (matchRow == null) return MatchOdds.neutral();

    final teamAId = matchRow['teamA']?.toString() ?? '';
    final teamBId = matchRow['teamB']?.toString() ?? '';
    if (teamAId.isEmpty || teamBId.isEmpty) return MatchOdds.neutral();

    final leagueId = matchRow['league_id']?.toString();
    final seasonId = matchRow['season_id']?.toString();
    final matchDate = DateTime.tryParse(
          matchRow['match_date']?.toString() ?? '',
        ) ??
        DateTime.now();
    final matchTime = matchRow['match_time']?.toString().trim() ?? '';

    final results = await Future.wait([
      _recentFormForTeam(
        teamId: teamAId,
        excludeMatchId: matchId,
        beforeDate: matchDate,
        beforeTime: matchTime,
      ),
      _recentFormForTeam(
        teamId: teamBId,
        excludeMatchId: matchId,
        beforeDate: matchDate,
        beforeTime: matchTime,
      ),
      _headToHead(
        teamAId: teamAId,
        teamBId: teamBId,
        excludeMatchId: matchId,
        beforeDate: matchDate,
      ),
      _averageSquadRating(teamAId),
      _averageSquadRating(teamBId),
      _seasonGoalDiffPerGame(
        teamId: teamAId,
        leagueId: leagueId,
        seasonId: seasonId,
      ),
      _seasonGoalDiffPerGame(
        teamId: teamBId,
        leagueId: leagueId,
        seasonId: seasonId,
      ),
      _standingPpg(
        teamId: teamAId,
        leagueId: leagueId,
        seasonId: seasonId,
      ),
      _standingPpg(
        teamId: teamBId,
        leagueId: leagueId,
        seasonId: seasonId,
      ),
    ]);

    final h2h = results[2] as ({int teamAWins, int draws, int teamBWins});

    final factors = MatchOddsFactors(
      teamARecent: results[0] as List<TeamRecentMatchSnapshot>,
      teamBRecent: results[1] as List<TeamRecentMatchSnapshot>,
      h2hTeamAWins: h2h.teamAWins,
      h2hDraws: h2h.draws,
      h2hTeamBWins: h2h.teamBWins,
      teamASquadRating: results[3] as double,
      teamBSquadRating: results[4] as double,
      teamASeasonGoalDiffPerGame: results[5] as double,
      teamBSeasonGoalDiffPerGame: results[6] as double,
      teamAStandingPpg: results[7] as double?,
      teamBStandingPpg: results[8] as double?,
    );

    return MatchOddsCalculator.compute(factors);
  }

  Future<List<TeamRecentMatchSnapshot>> _recentFormForTeam({
    required String teamId,
    required String excludeMatchId,
    required DateTime beforeDate,
    required String beforeTime,
  }) async {
    final dateStr = beforeDate.toIso8601String().split('T').first;
    final timeRaw = beforeTime.trim();
    final timeStr = timeRaw.isEmpty
        ? '23:59:59'
        : (timeRaw.length == 5 ? '$timeRaw:00' : timeRaw);

    final res = await _client
        .from('matches')
        .select('teamA, teamB, teamA_score, teamB_score')
        .or('teamA.eq.$teamId,teamB.eq.$teamId')
        .neq('id', excludeMatchId)
        .eq('status', 'fullTime')
        .not('teamA_score', 'is', null)
        .not('teamB_score', 'is', null)
        .or(
          'match_date.lt.$dateStr,'
          'and(match_date.eq.$dateStr,match_time.lt.$timeStr)',
        )
        .order('match_date', ascending: false)
        .order('match_time', ascending: false)
        .limit(5);

    final out = <TeamRecentMatchSnapshot>[];
    for (final row in List<Map<String, dynamic>>.from(res as List)) {
      final homeId = row['teamA']?.toString() ?? '';
      final homeScore =
          int.tryParse(row['teamA_score']?.toString() ?? '') ?? 0;
      final awayScore =
          int.tryParse(row['teamB_score']?.toString() ?? '') ?? 0;
      final isHome = homeId == teamId;
      final gf = isHome ? homeScore : awayScore;
      final ga = isHome ? awayScore : homeScore;
      out.add(
        TeamRecentMatchSnapshot(
          isWin: gf > ga,
          isDraw: gf == ga,
          goalsFor: gf,
          goalsAgainst: ga,
        ),
      );
    }
    return out;
  }

  Future<({int teamAWins, int draws, int teamBWins})> _headToHead({
    required String teamAId,
    required String teamBId,
    required String excludeMatchId,
    required DateTime beforeDate,
  }) async {
    final dateStr = beforeDate.toIso8601String().split('T').first;
    final res = await _client
        .from('matches')
        .select('teamA, teamB, teamA_score, teamB_score, match_date')
        .or(
          'and(teamA.eq.$teamAId,teamB.eq.$teamBId),'
          'and(teamA.eq.$teamBId,teamB.eq.$teamAId)',
        )
        .neq('id', excludeMatchId)
        .eq('status', 'fullTime')
        .not('teamA_score', 'is', null)
        .not('teamB_score', 'is', null)
        .lte('match_date', dateStr)
        .order('match_date', ascending: false)
        .limit(8);

    var winsA = 0;
    var draws = 0;
    var winsB = 0;
    for (final row in List<Map<String, dynamic>>.from(res as List)) {
      final homeId = row['teamA']?.toString() ?? '';
      final awayId = row['teamB']?.toString() ?? '';
      final homeScore =
          int.tryParse(row['teamA_score']?.toString() ?? '') ?? 0;
      final awayScore =
          int.tryParse(row['teamB_score']?.toString() ?? '') ?? 0;
      final scoreA = homeId == teamAId
          ? homeScore
          : (awayId == teamAId ? awayScore : homeScore);
      final scoreB = homeId == teamBId
          ? homeScore
          : (awayId == teamBId ? awayScore : homeScore);
      if (scoreA == scoreB) {
        draws++;
      } else if (scoreA > scoreB) {
        winsA++;
      } else {
        winsB++;
      }
    }
    return (teamAWins: winsA, draws: draws, teamBWins: winsB);
  }

  Future<double> _averageSquadRating(String teamId) async {
    if (teamId.isEmpty) return 0;

    final recentMatches = await _client
        .from('matches')
        .select('id')
        .or('teamA.eq.$teamId,teamB.eq.$teamId')
        .eq('status', 'fullTime')
        .order('match_date', ascending: false)
        .order('match_time', ascending: false)
        .limit(5);
    final matchIds = List<Map<String, dynamic>>.from(recentMatches as List)
        .map((r) => r['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();
    if (matchIds.isEmpty) return 0;

    final stats = await _client
        .from('match_player_stats')
        .select('rating')
        .eq('team_id', teamId)
        .inFilter('match_id', matchIds)
        .gt('rating', 0);

    var sum = 0.0;
    var count = 0;
    for (final row in List<Map<String, dynamic>>.from(stats as List)) {
      final rating = (row['rating'] as num?)?.toDouble();
      if (rating != null && rating > 0) {
        sum += rating;
        count++;
      }
    }
    return count > 0 ? sum / count : 0;
  }

  Future<double> _seasonGoalDiffPerGame({
    required String teamId,
    String? leagueId,
    String? seasonId,
  }) async {
    final Map<String, dynamic>? summary;
    if (leagueId != null &&
        leagueId.isNotEmpty &&
        seasonId != null &&
        seasonId.isNotEmpty) {
      summary = await _teamsRepository.getTeamSummaryStatsFiltered(
        teamId,
        leagueId: leagueId,
        seasonId: seasonId,
      );
    } else {
      summary = await _teamsRepository.getTeamSummaryStats(teamId);
    }
    if (summary == null) return 0;
    final played = (summary['matches_played'] as num?)?.toInt() ?? 0;
    if (played <= 0) return 0;
    final scored = (summary['goals_scored'] as num?)?.toInt() ?? 0;
    final conceded = (summary['goals_conceded'] as num?)?.toInt() ?? 0;
    return (scored - conceded) / played;
  }

  Future<double?> _standingPpg({
    required String teamId,
    String? leagueId,
    String? seasonId,
  }) async {
    if (leagueId == null || leagueId.isEmpty) return null;
    final standings = seasonId != null && seasonId.isNotEmpty
        ? await _leaguesRepository.getLeagueStandingsFiltered(
            leagueId,
            seasonId: seasonId,
          )
        : await _leaguesRepository.getLeagueStandings(leagueId);

    for (final row in standings) {
      if (row['team_id']?.toString() != teamId) continue;
      final points = (row['points'] as num?)?.toDouble() ?? 0;
      final played = (row['played'] as num?)?.toInt() ?? 0;
      if (played <= 0) return null;
      return points / played;
    }
    return null;
  }
}
