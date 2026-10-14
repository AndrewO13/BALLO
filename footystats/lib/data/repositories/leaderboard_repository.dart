import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/match_stats_aggregation.dart';
import '../../domain/models/leaderboard_entry.dart';
import '../../domain/models/player_stat_ranking.dart';

/// Player rankings: statistical leaders plus the legacy points board.
///
/// Statistical ranks use `get_player_stat_rankings` (app-wide, by period and
/// stat). The points board via `get_leaderboard` remains for profile rank
/// fallback. See `20261006140000_get_player_stat_rankings.sql`.
class LeaderboardRepository {
  LeaderboardRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<PlayerStatRanking>> getStatRankings({
    required RankingPeriod period,
    required RankingStat stat,
    int? year,
    int limit = 25,
  }) async {
    final targetYear = year ?? DateTime.now().toUtc().year;
    try {
      final res = await _client.rpc(
        'get_player_stat_rankings',
        params: {
          'p_period': period.rpcValue,
          'p_stat': stat.rpcValue,
          'p_year': targetYear,
          'p_limit': limit,
        },
      );
      return _parseRankingRows(res);
    } catch (_) {
      return _loadStatRankingsFallback(
        period: period,
        stat: stat,
        year: targetYear,
        limit: limit,
      );
    }
  }

  Future<List<LeaderboardEntry>> getOverall({int limit = 200}) async {
    return _call(mode: 'overall', leagueId: null, teamId: null, limit: limit);
  }

  Future<List<LeaderboardEntry>> getForLeague(
    String leagueId, {
    int limit = 200,
  }) async {
    if (leagueId.isEmpty) return [];
    return _call(
      mode: 'league',
      leagueId: leagueId,
      teamId: null,
      limit: limit,
    );
  }

  Future<List<LeaderboardEntry>> getForTeam(
    String teamId, {
    int limit = 200,
  }) async {
    if (teamId.isEmpty) return [];
    return _call(mode: 'team', leagueId: null, teamId: teamId, limit: limit);
  }

  Future<List<LeaderboardEntry>> _call({
    required String mode,
    required String? leagueId,
    required String? teamId,
    required int limit,
  }) async {
    try {
      final res = await _client.rpc(
        'get_leaderboard',
        params: {
          'p_mode': mode,
          'p_league_id': leagueId,
          'p_team_id': teamId,
          'p_limit': limit,
        },
      );
      if (res == null) return [];
      final list = res is List ? res : (res as List<dynamic>? ?? []);
      final out = <LeaderboardEntry>[];
      for (final e in list) {
        if (e == null) continue;
        try {
          final map = e is Map<String, dynamic>
              ? e
              : Map<String, dynamic>.from(e as Map);
          out.add(LeaderboardEntry.fromRpcRow(map));
        } catch (_) {
          continue;
        }
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  /// First team id for the user (active membership), if any.
  Future<String?> getPrimaryTeamId(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final res = await _client
          .from('player_team_memberships')
          .select('team_id')
          .eq('player_id', userId)
          .isFilter('end_date', null)
          .limit(1)
          .maybeSingle();
      return res?['team_id']?.toString();
    } catch (_) {
      return null;
    }
  }

  List<PlayerStatRanking> _parseRankingRows(dynamic res) {
    if (res == null) return const [];
    final list = res is List ? res : const <dynamic>[];
    final out = <PlayerStatRanking>[];
    for (final e in list) {
      if (e == null) continue;
      try {
        final map = e is Map<String, dynamic>
            ? e
            : Map<String, dynamic>.from(e as Map);
        final row = PlayerStatRanking.fromRpcRow(map);
        if (row.playerId.isEmpty) continue;
        out.add(row);
      } catch (_) {
        continue;
      }
    }
    return out;
  }

  Future<List<PlayerStatRanking>> _loadStatRankingsFallback({
    required RankingPeriod period,
    required RankingStat stat,
    required int year,
    required int limit,
  }) async {
    try {
      var query = _client
          .from('match_player_stats')
          .select(
            'player_id, team_id, match_id, minutes_played, goals, assists, '
            'shots, shots_on_target, tackles, saves, rating, '
            'player:players!inner(player_name, image_url, position, '
            'deleted_at, account_type), '
            'match:matches!inner(status, match_date), '
            'team:teams!match_player_stats_team_id_fkey(team_name, short_form)',
          )
          .eq('match.status', 'fullTime');
      if (period == RankingPeriod.year) {
        query = query
            .gte('match.match_date', '$year-01-01')
            .lt('match.match_date', '${year + 1}-01-01');
      }
      final res = await query.limit(4000);
      final rows = (res as List)
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      return _rankFallbackRows(
        rows: rows,
        stat: stat,
        period: period,
        limit: limit,
      );
    } catch (_) {
      return const [];
    }
  }

  List<PlayerStatRanking> _rankFallbackRows({
    required List<Map<String, dynamic>> rows,
    required RankingStat stat,
    required RankingPeriod period,
    required int limit,
  }) {
    final minShots = period == RankingPeriod.year ? 8 : 15;
    final minMatches = period == RankingPeriod.year ? 3 : 5;
    final grouped = <String, _FallbackAgg>{};

    for (final row in rows) {
      final player = row['player'];
      final playerMap = player is Map
          ? Map<String, dynamic>.from(player)
          : const <String, dynamic>{};
      if (playerMap['deleted_at'] != null) continue;
      if ((playerMap['account_type']?.toString() ?? 'player') != 'player') {
        continue;
      }
      final playerId = row['player_id']?.toString() ?? '';
      if (playerId.isEmpty) continue;

      final agg = grouped.putIfAbsent(
        playerId,
        () => _FallbackAgg(
          playerName: playerMap['player_name']?.toString() ?? 'Player',
          imageUrl: playerMap['image_url']?.toString(),
          position: playerMap['position']?.toString() ?? '',
        ),
      );

      agg.goals += _asDouble(row['goals']);
      agg.assists += _asDouble(row['assists']);
      agg.shots += _asDouble(row['shots']);
      agg.shotsOnTarget += _asDouble(row['shots_on_target']);
      agg.tackles += _asDouble(row['tackles']);
      agg.saves += _asDouble(row['saves']);
      if (MatchStatsAggregation.rowCountsAsAppearance(row)) {
        final matchId = row['match_id']?.toString();
        if (matchId != null && matchId.isNotEmpty) {
          agg.matchIds.add(matchId);
        }
        final rating = _asDouble(row['rating']);
        if (rating > 0) {
          agg.ratingSum += rating;
          agg.ratingCount++;
        }
      }

      final match = row['match'];
      final matchMap = match is Map ? Map<String, dynamic>.from(match) : null;
      final matchDate = matchMap?['match_date']?.toString() ?? '';
      if (matchDate.compareTo(agg.latestMatchDate) >= 0) {
        agg.latestMatchDate = matchDate;
        final team = row['team'];
        final teamMap = team is Map ? Map<String, dynamic>.from(team) : null;
        final teamName = teamMap?['team_name']?.toString().trim();
        final shortForm = teamMap?['short_form']?.toString().trim();
        agg.teamName = (teamName != null && teamName.isNotEmpty)
            ? teamName
            : (shortForm ?? '');
      }
    }

    final ranked = <PlayerStatRanking>[];
    for (final entry in grouped.entries) {
      final agg = entry.value;
      final matches = agg.matchIds.length;
      final avgRating = agg.ratingCount > 0
          ? agg.ratingSum / agg.ratingCount
          : 0.0;
      final double? value = switch (stat) {
        RankingStat.goals => agg.goals,
        RankingStat.assists => agg.assists,
        RankingStat.goalContributions => agg.goals + agg.assists,
        RankingStat.shootingPct =>
          agg.shots >= minShots && agg.shots > 0
              ? 100.0 * agg.shotsOnTarget / agg.shots
              : null,
        RankingStat.avgRating => matches >= minMatches ? avgRating : null,
        RankingStat.tackles => agg.tackles,
        RankingStat.saves => agg.saves,
        RankingStat.shotsOnTarget => agg.shotsOnTarget,
        RankingStat.goalsPerMatch =>
          matches >= minMatches ? agg.goals / matches : null,
      };
      if (value == null) continue;
      if (!stat.isRateStat && value <= 0) continue;
      ranked.add(
        PlayerStatRanking(
          playerId: entry.key,
          playerName: agg.playerName,
          imageUrl: agg.imageUrl,
          position: agg.position,
          teamName: agg.teamName,
          matches: matches,
          statValue: value,
          rank: 0,
        ),
      );
    }

    ranked.sort((a, b) {
      final byValue = b.statValue.compareTo(a.statValue);
      if (byValue != 0) return byValue;
      return a.playerName.toLowerCase().compareTo(b.playerName.toLowerCase());
    });

    final capped = ranked.take(limit).toList();
    return [
      for (var i = 0; i < capped.length; i++)
        PlayerStatRanking(
          playerId: capped[i].playerId,
          playerName: capped[i].playerName,
          imageUrl: capped[i].imageUrl,
          position: capped[i].position,
          teamName: capped[i].teamName,
          matches: capped[i].matches,
          statValue: capped[i].statValue,
          rank: i + 1,
        ),
    ];
  }

  static double _asDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}

class _FallbackAgg {
  _FallbackAgg({
    required this.playerName,
    this.imageUrl,
    required this.position,
  });

  final String playerName;
  final String? imageUrl;
  final String position;
  final Set<String> matchIds = {};
  double goals = 0;
  double assists = 0;
  double shots = 0;
  double shotsOnTarget = 0;
  double tackles = 0;
  double saves = 0;
  double ratingSum = 0;
  int ratingCount = 0;
  String latestMatchDate = '';
  String teamName = '';
}
