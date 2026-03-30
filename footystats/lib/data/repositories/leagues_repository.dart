import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/league_model.dart';

class LeaguesRepository {
  LeaguesRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<LeagueModel?> getLeagueById(String id) async {
    if (id.isEmpty) return null;
    final res = await _client
        .from('leagues')
        .select(
          'id, league_name, logo_id, created_by, created_at, '
          'default_venue, default_venue_image_url',
        )
        .eq('id', id)
        .maybeSingle();
    if (res == null) return null;
    return LeagueModel.fromJson(Map<String, dynamic>.from(res));
  }

  Future<List<LeagueModel>> getLeaguesByCreator(String userId) async {
    final res = await _client
        .from('leagues')
        .select('id, league_name, logo_id, created_by, created_at')
        .eq('created_by', userId)
        .order('created_at', ascending: false);
    final list = List<Map<String, dynamic>>.from(res as List);
    return list.map(LeagueModel.fromJson).toList();
  }

  /// Leagues the user participates in: created by user OR has a team in the league
  /// (user is a player on a team that is in the league via league_team_memberships).
  Future<List<LeagueModel>> getLeaguesForUser(String userId) async {
    final leagueIds = <String>{};

    // Leagues created by user
    final created = await getLeaguesByCreator(userId);
    for (final l in created) {
      leagueIds.add(l.id);
    }

    // Leagues where user's team is a member (user -> player_team_memberships -> team -> league_team_memberships)
    final ptm = await _client
        .from('player_team_memberships')
        .select('team_id')
        .eq('player_id', userId);
    final teamIds = (ptm as List)
        .map((r) => (r as Map)['team_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (teamIds.isNotEmpty) {
      final ltm = await _client
          .from('league_team_memberships')
          .select('league_id')
          .inFilter('team_id', teamIds);
      for (final r in ltm as List) {
        final id = (r as Map)['league_id']?.toString();
        if (id != null && id.isNotEmpty) leagueIds.add(id);
      }
    }

    if (leagueIds.isEmpty) return [];
    final res = await _client
        .from('leagues')
        .select('id, league_name, logo_id, created_by, created_at')
        .inFilter('id', leagueIds.toList())
        .order('league_name', ascending: true);
    final list = List<Map<String, dynamic>>.from(res as List);
    return list.map(LeagueModel.fromJson).toList();
  }

  Future<String> createLeague({
    required String leagueName,
    String? logoId,
    required String createdBy,
  }) async {
    final res = await _client
        .from('leagues')
        .insert({
          'league_name': leagueName,
          'logo_id': logoId,
          'created_by': createdBy,
        })
        .select('id')
        .single();
    return res['id']?.toString() ?? '';
  }

  Future<void> updateLeague(
    String leagueId, {
    String? leagueName,
    String? logoId,
    String? defaultVenue,
    String? defaultVenueImageUrl,
  }) async {
    final data = <String, dynamic>{};
    if (leagueName != null) data['league_name'] = leagueName;
    if (logoId != null) data['logo_id'] = logoId;
    if (defaultVenue != null) data['default_venue'] = defaultVenue;
    if (defaultVenueImageUrl != null) {
      data['default_venue_image_url'] = defaultVenueImageUrl;
    }
    if (data.isEmpty) return;
    await _client.from('leagues').update(data).eq('id', leagueId);
  }

  Future<void> deleteLeague(String leagueId) async {
    await _client.from('leagues').delete().eq('id', leagueId);
  }

  /// Top players by average rating in league matches. Returns up to [limit] players
  /// with player_name, image_url, team_name, team_logo, avg_rating.
  Future<List<Map<String, dynamic>>> getTopPlayersByRating(
    String leagueId, {
    int limit = 3,
  }) async {
    final matchesRes = await _client
        .from('matches')
        .select('id')
        .eq('league_id', leagueId);
    final matches = List<Map<String, dynamic>>.from(matchesRes as List);
    if (matches.isEmpty) return [];

    final matchIds = matches
        .map((m) => m['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();
    if (matchIds.isEmpty) return [];

    final statsRes = await _client
        .from('match_player_stats')
        .select(
          'player_id, team_id, rating, '
          'player:players(player_name, image_url), '
          'team:teams(team_name, logo_id)',
        )
        .inFilter('match_id', matchIds);

    final stats = List<Map<String, dynamic>>.from(statsRes as List);
    if (stats.isEmpty) return [];

    // Aggregate by player: avg rating, pick team from best appearance
    final byPlayer = <String, List<Map<String, dynamic>>>{};
    for (final row in stats) {
      final pid = row['player_id']?.toString();
      if (pid == null || pid.isEmpty) continue;
      byPlayer.putIfAbsent(pid, () => []).add(row);
    }

    final aggregated = <Map<String, dynamic>>[];
    for (final entry in byPlayer.entries) {
      final rows = entry.value;
      final ratings = <double>[];
      for (final r in rows) {
        final v = r['rating'];
        double val = 0.0;
        if (v is num) {
          val = v.toDouble();
        } else if (v is String)
          val = double.tryParse(v) ?? 0.0;
        if (val > 0) ratings.add(val);
      }
      if (ratings.isEmpty) continue;

      final avgRating = ratings.reduce((a, b) => a + b) / ratings.length;
      final bestIdx = ratings.indexOf(ratings.reduce((a, b) => a > b ? a : b));
      final bestRow = rows[bestIdx];

      final player = bestRow['player'];
      final team = bestRow['team'];
      final playerMap = player is Map
          ? Map<String, dynamic>.from(player)
          : null;
      final teamMap = team is Map ? Map<String, dynamic>.from(team) : null;

      aggregated.add({
        'player_id': entry.key,
        'player_name': playerMap?['player_name'] ?? 'Unknown',
        'image_url': playerMap?['image_url'],
        'team_name': teamMap?['team_name'] ?? '—',
        'team_logo': teamMap?['logo_id'],
        'avg_rating': avgRating,
      });
    }

    aggregated.sort(
      (a, b) =>
          (b['avg_rating'] as double).compareTo(a['avg_rating'] as double),
    );
    return aggregated.take(limit).toList();
  }

  /// Best XI for the latest completed gameweek: GK×1, DEF×4, MID×4, ATT×2.
  /// Picks the highest-rated players per position from match_player_stats,
  /// joining players for position and image.
  Future<Map<String, List<Map<String, dynamic>>>> getTeamOfTheWeek(
    String leagueId,
  ) async {
    final matchesRes = await _client
        .from('matches')
        .select('id, gameweek')
        .eq('league_id', leagueId)
        .eq('status', 'fullTime')
        .order('match_date', ascending: false);
    final matches = List<Map<String, dynamic>>.from(matchesRes as List);
    if (matches.isEmpty) return {};

    // Pick the latest gameweek
    final latestGw = matches.first['gameweek']?.toString();
    final gwMatchIds = matches
        .where((m) => m['gameweek']?.toString() == latestGw)
        .map((m) => m['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();
    if (gwMatchIds.isEmpty) return {};

    final statsRes = await _client
        .from('match_player_stats')
        .select(
          'player_id, team_id, rating, '
          'player:players(player_name, image_url, position), '
          'team:teams(team_name, logo_id, short_form)',
        )
        .inFilter('match_id', gwMatchIds);

    final stats = List<Map<String, dynamic>>.from(statsRes as List);
    if (stats.isEmpty) return {};

    // Aggregate per player (in case of multiple matches in same GW)
    final byPlayer = <String, Map<String, dynamic>>{};
    for (final row in stats) {
      final pid = row['player_id']?.toString();
      if (pid == null || pid.isEmpty) continue;
      final v = row['rating'];
      double rating = 0.0;
      if (v is num) {
        rating = v.toDouble();
      } else if (v is String) rating = double.tryParse(v) ?? 0.0;
      final existing = byPlayer[pid];
      if (existing == null || rating > (existing['rating'] as double)) {
        byPlayer[pid] = {...row, 'rating': rating};
      }
    }

    final allPlayers = byPlayer.values.toList()
      ..sort((a, b) => (b['rating'] as double).compareTo(a['rating'] as double));

    String normalizePosition(String? pos) {
      if (pos == null || pos.isEmpty) return 'Unknown';
      final lc = pos.toLowerCase().trim();
      if (lc.contains('goal') || lc == 'gk') return 'Goalkeeper';
      if (lc.contains('def') || lc == 'cb' || lc == 'lb' || lc == 'rb' || lc == 'wb') return 'Defender';
      if (lc.contains('mid') || lc == 'cm' || lc == 'dm' || lc == 'am') return 'Midfielder';
      if (lc.contains('att') || lc.contains('forward') || lc.contains('strik') || lc == 'cf' || lc == 'st' || lc == 'lw' || lc == 'rw') return 'Attacker';
      return pos;
    }

    Map<String, dynamic> toEntry(Map<String, dynamic> row) {
      final p = row['player'] is Map ? Map<String, dynamic>.from(row['player'] as Map) : <String, dynamic>{};
      final t = row['team'] is Map ? Map<String, dynamic>.from(row['team'] as Map) : <String, dynamic>{};
      return {
        'player_id': row['player_id']?.toString(),
        'player_name': p['player_name'] ?? 'Unknown',
        'image_url': p['image_url'],
        'position': normalizePosition(p['position']?.toString()),
        'team_name': t['team_name'] ?? '—',
        'team_logo': t['logo_id'],
        'team_short': t['short_form'],
        'rating': row['rating'],
      };
    }

    final gk = <Map<String, dynamic>>[];
    final def = <Map<String, dynamic>>[];
    final mid = <Map<String, dynamic>>[];
    final att = <Map<String, dynamic>>[];

    for (final row in allPlayers) {
      final entry = toEntry(row);
      final pos = entry['position'] as String;
      if (pos == 'Goalkeeper' && gk.isEmpty) {
        gk.add(entry);
      } else if (pos == 'Defender' && def.length < 4) {
        def.add(entry);
      } else if (pos == 'Midfielder' && mid.length < 4) {
        mid.add(entry);
      } else if (pos == 'Attacker' && att.length < 2) {
        att.add(entry);
      }
    }

    return {
      'Goalkeeper': gk,
      'Defender': def,
      'Midfielder': mid,
      'Attacker': att,
    };
  }

  /// Fetches league standings computed from finished matches via RPC.
  Future<List<Map<String, dynamic>>> getLeagueStandings(
    String leagueId,
  ) async {
    final res = await _client.rpc(
      'get_league_standings',
      params: {'p_league_id': leagueId},
    );
    return List<Map<String, dynamic>>.from(res as List);
  }

  static DateTime? _parseDateOnly(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return DateTime(v.year, v.month, v.day);
    if (v is String) {
      final d = DateTime.tryParse(v.split('T').first);
      if (d == null) return null;
      return DateTime(d.year, d.month, d.day);
    }
    return null;
  }

  static bool _leagueSeasonEnded(DateTime endDate) {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final e = DateTime(endDate.year, endDate.month, endDate.day);
    return today.isAfter(e);
  }

  /// Leagues whose `end_date` is in the past where [teamId] is first in
  /// [getLeagueStandings] (champion). Team must appear in
  /// `league_team_memberships` for that league.
  ///
  /// Returns rows: `league_id`, `league_name`, `logo_id`, `end_year`.
  Future<List<Map<String, dynamic>>> getChampionTrophiesForTeam(
    String teamId,
  ) async {
    if (teamId.isEmpty) return [];

    final ltm = await _client
        .from('league_team_memberships')
        .select('league_id')
        .eq('team_id', teamId);
    final leagueIds = (ltm as List)
        .map((r) => (r as Map)['league_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (leagueIds.isEmpty) return [];

    final leaguesRes = await _client
        .from('leagues')
        .select('id, league_name, logo_id, start_date, end_date')
        .inFilter('id', leagueIds);
    final leagues = List<Map<String, dynamic>>.from(leaguesRes as List);

    final out = <Map<String, dynamic>>[];
    for (final row in leagues) {
      final id = row['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final end = _parseDateOnly(row['end_date']);
      if (end == null || !_leagueSeasonEnded(end)) continue;

      List<Map<String, dynamic>> standings;
      try {
        standings = await getLeagueStandings(id);
      } catch (_) {
        continue;
      }
      if (standings.isEmpty) continue;

      final leaderId = standings.first['team_id']?.toString();
      if (leaderId != teamId) continue;

      out.add({
        'league_id': id,
        'league_name': row['league_name']?.toString() ?? 'League',
        'logo_id': row['logo_id']?.toString(),
        'end_year': end.year,
      });
    }

    out.sort((a, b) {
      final ya = a['end_year'] as int;
      final yb = b['end_year'] as int;
      if (ya != yb) return yb.compareTo(ya);
      return (a['league_name'] as String).compareTo(b['league_name'] as String);
    });
    return out;
  }

  /// Fetches aggregated team stats for a league via RPC.
  Future<List<Map<String, dynamic>>> getLeagueTeamStats(
    String leagueId,
  ) async {
    final res = await _client.rpc(
      'get_league_team_stats',
      params: {'p_league_id': leagueId},
    );
    return List<Map<String, dynamic>>.from(res as List);
  }

  /// Fetches aggregated player stats for a league via RPC.
  Future<List<Map<String, dynamic>>> getLeaguePlayerStats(
    String leagueId,
  ) async {
    final res = await _client.rpc(
      'get_league_player_stats',
      params: {'p_league_id': leagueId},
    );
    return List<Map<String, dynamic>>.from(res as List);
  }

  /// Fetches videos uploaded for matches in a given league.
  Future<List<Map<String, dynamic>>> getLeagueVideos(
    String leagueId,
  ) async {
    final matchRes = await _client
        .from('matches')
        .select('id')
        .eq('league_id', leagueId);
    final matchIds = (matchRes as List)
        .map((r) => (r as Map)['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();
    if (matchIds.isEmpty) return [];
    final res = await _client
        .from('videos')
        .select(
          'id, match_id, uploader_user_id, duration_seconds, '
          'video_url, thumbnail_url, created_at',
        )
        .inFilter('match_id', matchIds)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res as List);
  }
}
