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
          'default_venue, default_venue_image_url, country',
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
        .eq('player_id', userId)
        .isFilter('end_date', null);
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

  /// Leagues where a specific [teamId] is a member.
  Future<List<LeagueModel>> getLeaguesForTeam(String teamId) async {
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

    final res = await _client
        .from('leagues')
        .select('id, league_name, logo_id, created_by, created_at')
        .inFilter('id', leagueIds)
        .order('league_name', ascending: true);
    final list = List<Map<String, dynamic>>.from(res as List);
    return list.map(LeagueModel.fromJson).toList();
  }

  Future<String> createLeague({
    required String leagueName,
    String? logoId,
    required String createdBy,
    String? country,
  }) async {
    final res = await _client
        .from('leagues')
        .insert({
          'league_name': leagueName,
          'logo_id': logoId,
          'created_by': createdBy,
          'country': country,
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
    String? socialInstagram,
    String? socialTiktok,
    String? socialX,
    String? country,
  }) async {
    final data = <String, dynamic>{};
    if (leagueName != null) data['league_name'] = leagueName;
    if (logoId != null) data['logo_id'] = logoId;
    if (defaultVenue != null) data['default_venue'] = defaultVenue;
    if (defaultVenueImageUrl != null) {
      data['default_venue_image_url'] = defaultVenueImageUrl;
    }
    if (socialInstagram != null) data['social_instagram'] = socialInstagram;
    if (socialTiktok != null) data['social_tiktok'] = socialTiktok;
    if (socialX != null) data['social_x'] = socialX;
    if (country != null) data['country'] = country;
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

  /// Ongoing → upcoming → most recently ended (by [end_date]).
  Future<String?> _seasonIdForTeamOfTheWeek(String leagueId) async {
    if (leagueId.isEmpty) return null;
    final ongoing = await _client
        .from('seasons')
        .select('id')
        .eq('league_id', leagueId)
        .eq('status', 'ongoing')
        .maybeSingle();
    final oid = ongoing?['id']?.toString();
    if (oid != null && oid.isNotEmpty) return oid;

    final upcoming = await _client
        .from('seasons')
        .select('id')
        .eq('league_id', leagueId)
        .eq('status', 'upcoming')
        .order('start_date', ascending: true)
        .limit(1)
        .maybeSingle();
    final uid = upcoming?['id']?.toString();
    if (uid != null && uid.isNotEmpty) return uid;

    final ended = await _client
        .from('seasons')
        .select('id')
        .eq('league_id', leagueId)
        .eq('status', 'ended')
        .order('end_date', ascending: false)
        .limit(1)
        .maybeSingle();
    return ended?['id']?.toString();
  }

  /// Best XI for the **latest fully completed** gameweek in the league's
  /// current/latest season. Ratings are **averages** of [rating] > 0 across
  /// all matches that player played in that gameweek. GK×1, DEF×4, MID×4, ATT×2.
  Future<Map<String, List<Map<String, dynamic>>>> getTeamOfTheWeek(
    String leagueId,
  ) async {
    if (leagueId.isEmpty) return {};

    final seasonId = await _seasonIdForTeamOfTheWeek(leagueId);
    if (seasonId == null || seasonId.isEmpty) return {};

    final matchesRes = await _client
        .from('matches')
        .select('id, gameweek, status, match_date')
        .eq('league_id', leagueId)
        .eq('season_id', seasonId);
    final allMatches = List<Map<String, dynamic>>.from(matchesRes as List);
    if (allMatches.isEmpty) return {};

    final byGw = <String, List<Map<String, dynamic>>>{};
    for (final m in allMatches) {
      final gw = m['gameweek']?.toString();
      if (gw == null || gw.isEmpty) continue;
      byGw.putIfAbsent(gw, () => []).add(m);
    }
    if (byGw.isEmpty) return {};

    final gwIds = byGw.keys.toList();
    final weekById = <String, int>{};
    if (gwIds.isNotEmpty) {
      final gwMetaRes = await _client
          .from('gameweeks')
          .select('id, week')
          .inFilter('id', gwIds);
      for (final r in gwMetaRes as List) {
        final map = Map<String, dynamic>.from(r as Map);
        final id = map['id']?.toString() ?? '';
        final w = (map['week'] as num?)?.toInt() ?? 0;
        if (id.isNotEmpty) weekById[id] = w;
      }
    }

    DateTime latestKickoffInGw(String gwKey) {
      var maxD = DateTime.fromMillisecondsSinceEpoch(0);
      for (final m in byGw[gwKey]!) {
        final d = DateTime.tryParse(m['match_date']?.toString() ?? '');
        if (d != null && d.isAfter(maxD)) maxD = d;
      }
      return maxD;
    }

    gwIds.sort((a, b) {
      final cmp = (weekById[b] ?? -1).compareTo(weekById[a] ?? -1);
      if (cmp != 0) return cmp;
      return latestKickoffInGw(b).compareTo(latestKickoffInGw(a));
    });

    String? completedLatestGwId;
    for (final gwId in gwIds) {
      final ms = byGw[gwId]!;
      if (ms.isEmpty) continue;
      final allFullTime = ms.every(
        (x) => x['status']?.toString() == 'fullTime',
      );
      if (allFullTime) {
        completedLatestGwId = gwId;
        break;
      }
    }
    if (completedLatestGwId == null) return {};

    final gwMatchIds = byGw[completedLatestGwId]!
        .map((e) => e['id']?.toString())
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

    final byPlayer = <String, _TotwRatingAgg>{};
    for (final row in stats) {
      final pid = row['player_id']?.toString();
      if (pid == null || pid.isEmpty) continue;
      final v = row['rating'];
      double rating = 0.0;
      if (v is num) {
        rating = v.toDouble();
      } else if (v is String) {
        rating = double.tryParse(v) ?? 0.0;
      }
      byPlayer.putIfAbsent(pid, () => _TotwRatingAgg(row));
      byPlayer[pid]!.add(rating);
    }

    final allPlayers =
        byPlayer.entries.where((e) => e.value.count > 0).map((e) {
          final merged = Map<String, dynamic>.from(e.value.sampleRow);
          merged['rating'] = e.value.average;
          return merged;
        }).toList()..sort(
          (a, b) => ((b['rating'] as num?)?.toDouble() ?? 0).compareTo(
            (a['rating'] as num?)?.toDouble() ?? 0,
          ),
        );

    String normalizePosition(String? pos) {
      if (pos == null || pos.isEmpty) return 'Unknown';
      final lc = pos.toLowerCase().trim();
      if (lc.contains('goal') || lc == 'gk') return 'Goalkeeper';
      if (lc.contains('def') ||
          lc == 'cb' ||
          lc == 'lb' ||
          lc == 'rb' ||
          lc == 'wb') {
        return 'Defender';
      }
      if (lc.contains('mid') || lc == 'cm' || lc == 'dm' || lc == 'am') {
        return 'Midfielder';
      }
      if (lc.contains('att') ||
          lc.contains('forward') ||
          lc.contains('strik') ||
          lc == 'cf' ||
          lc == 'st' ||
          lc == 'lw' ||
          lc == 'rw') {
        return 'Attacker';
      }
      return pos;
    }

    Map<String, dynamic> toEntry(Map<String, dynamic> row) {
      final p = row['player'] is Map
          ? Map<String, dynamic>.from(row['player'] as Map)
          : <String, dynamic>{};
      final t = row['team'] is Map
          ? Map<String, dynamic>.from(row['team'] as Map)
          : <String, dynamic>{};
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
  Future<List<Map<String, dynamic>>> getLeagueStandings(String leagueId) async {
    final res = await _client.rpc(
      'get_league_standings',
      params: {'p_league_id': leagueId},
    );
    return List<Map<String, dynamic>>.from(res as List);
  }

  /// Standings for one league, optionally scoped to a single season (all seasons
  /// in that league when [seasonId] is null).
  Future<List<Map<String, dynamic>>> getLeagueStandingsFiltered(
    String leagueId, {
    String? seasonId,
  }) async {
    final params = <String, dynamic>{'p_league_id': leagueId};
    if (seasonId != null && seasonId.isNotEmpty) {
      params['p_season_id'] = seasonId;
    }
    final res = await _client.rpc(
      'get_league_standings_filtered',
      params: params,
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

  static int? _trophyEndYear(Map<String, dynamic>? season) {
    final sEnd = season == null ? null : _parseDateOnly(season['end_date']);
    if (sEnd != null) return sEnd.year;
    return null;
  }

  static bool _isFirstInStandings(
    List<Map<String, dynamic>> standings,
    String teamId,
  ) {
    for (final row in standings) {
      final pos = (row['position'] as num?)?.toInt();
      if (pos == 1 && row['team_id']?.toString() == teamId) return true;
    }
    return false;
  }

  /// For each **ended** season in leagues this team belongs to: if the team
  /// finished 1st in that season's final table (all fullTime matches in the
  /// season), counts one trophy. Multiple seasons in the same league/year each
  /// count separately.
  ///
  /// Returns rows: `league_id`, `league_name`, `logo_id`, `season_id`,
  /// `season_name`, `end_year`, `end_date` (ISO date string for sorting).
  Future<List<Map<String, dynamic>>> getChampionTrophiesForTeam(
    String teamId,
  ) async {
    if (teamId.isEmpty) return [];

    final ltm = await _client
        .from('league_team_memberships')
        .select('league_id')
        .eq('team_id', teamId);
    final allowed = (ltm as List)
        .map((r) => (r as Map)['league_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    if (allowed.isEmpty) return [];

    final partRows = await _client
        .from('matches')
        .select('season_id')
        .eq('status', 'fullTime')
        .or('teamA.eq.$teamId,teamB.eq.$teamId');
    final seasonIdsTeamPlayed = <String>{};
    for (final raw in partRows as List) {
      final sid = Map<String, dynamic>.from(
        raw as Map,
      )['season_id']?.toString();
      if (sid != null && sid.isNotEmpty) seasonIdsTeamPlayed.add(sid);
    }

    final leaguesRes = await _client
        .from('leagues')
        .select('id, league_name, logo_id')
        .inFilter('id', allowed.toList());
    final leaguesById = <String, Map<String, dynamic>>{};
    for (final raw in leaguesRes as List) {
      final row = Map<String, dynamic>.from(raw as Map);
      final id = row['id']?.toString() ?? '';
      if (id.isNotEmpty) leaguesById[id] = row;
    }

    final endedSeasonsRes = await _client
        .from('seasons')
        .select('id, league_id, season_name, end_date, status')
        .eq('status', 'ended')
        .inFilter('league_id', allowed.toList());

    final out = <Map<String, dynamic>>[];

    for (final raw in endedSeasonsRes as List) {
      final season = Map<String, dynamic>.from(raw as Map);
      final seasonId = season['id']?.toString() ?? '';
      final leagueId = season['league_id']?.toString() ?? '';
      if (seasonId.isEmpty || leagueId.isEmpty) continue;
      if (!allowed.contains(leagueId)) continue;
      if (!seasonIdsTeamPlayed.contains(seasonId)) continue;

      final league = leaguesById[leagueId];
      if (league == null) continue;

      List<Map<String, dynamic>> standings;
      try {
        standings = await getLeagueStandingsFiltered(
          leagueId,
          seasonId: seasonId,
        );
      } catch (_) {
        continue;
      }
      if (standings.isEmpty) continue;
      if (!_isFirstInStandings(standings, teamId)) continue;

      final endYear = _trophyEndYear(season);
      final endDateStr = season['end_date']?.toString() ?? '';

      out.add({
        'league_id': leagueId,
        'league_name': league['league_name']?.toString() ?? 'League',
        'logo_id': league['logo_id']?.toString(),
        'season_id': seasonId,
        'season_name': season['season_name']?.toString() ?? '',
        'end_year': endYear,
        'end_date': endDateStr,
      });
    }

    out.sort((a, b) {
      final ln = (a['league_name'] as String).compareTo(
        b['league_name'] as String,
      );
      if (ln != 0) return ln;
      final da = a['end_date'] as String? ?? '';
      final db = b['end_date'] as String? ?? '';
      final c = db.compareTo(da);
      if (c != 0) return c;
      return (a['season_id'] as String).compareTo(b['season_id'] as String);
    });
    return out;
  }

  /// Fetches aggregated team stats for a league via RPC.
  Future<List<Map<String, dynamic>>> getLeagueTeamStats(String leagueId) async {
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

  /// Like [getLeagueTeamStats], optionally restricted to one season.
  Future<List<Map<String, dynamic>>> getLeagueTeamStatsFiltered(
    String leagueId, {
    String? seasonId,
  }) async {
    final params = <String, dynamic>{'p_league_id': leagueId};
    if (seasonId != null && seasonId.isNotEmpty) {
      params['p_season_id'] = seasonId;
    }
    final res = await _client.rpc(
      'get_league_team_stats_filtered',
      params: params,
    );
    return List<Map<String, dynamic>>.from(res as List);
  }

  /// Like [getLeaguePlayerStats], optionally restricted to one season.
  Future<List<Map<String, dynamic>>> getLeaguePlayerStatsFiltered(
    String leagueId, {
    String? seasonId,
  }) async {
    final params = <String, dynamic>{'p_league_id': leagueId};
    if (seasonId != null && seasonId.isNotEmpty) {
      params['p_season_id'] = seasonId;
    }
    final res = await _client.rpc(
      'get_league_player_stats_filtered',
      params: params,
    );
    return List<Map<String, dynamic>>.from(res as List);
  }

  /// Fetches videos uploaded for matches in a given league, newest first.
  ///
  /// [limit]/[offset] page the result (defaults to the first 24) so the
  /// gallery doesn't download metadata for every video ever uploaded.
  Future<List<Map<String, dynamic>>> getLeagueVideos(
    String leagueId, {
    int limit = 24,
    int offset = 0,
  }) async {
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
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return List<Map<String, dynamic>>.from(res as List);
  }

  /// Top leagues by favourite count (for search recommendations).
  Future<List<LeagueModel>> getPopularLeagues({int limit = 10}) async {
    final res = await _client
        .from('leagues')
        .select(
          'id, league_name, logo_id, created_by, created_at, country, '
          'default_venue, default_venue_image_url, favourite_count',
        )
        .order('favourite_count', ascending: false)
        .limit(limit);
    final list = List<Map<String, dynamic>>.from(res as List);
    return list.map(LeagueModel.fromJson).toList();
  }

  /// Favourited leagues for the signed-in user.
  Future<List<LeagueModel>> getFavouritedLeaguesForUser(String userId) async {
    if (userId.isEmpty) return [];
    final res = await _client
        .from('league_favourites')
        .select(
          'leagues(id, league_name, logo_id, created_by, created_at, country, '
          'default_venue, default_venue_image_url, favourite_count)',
        )
        .eq('user_id', userId)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: false);
    final out = <LeagueModel>[];
    for (final row in res as List) {
      final leagues = row['leagues'];
      if (leagues is Map) {
        out.add(LeagueModel.fromJson(Map<String, dynamic>.from(leagues)));
      }
    }
    return out;
  }

  Future<void> addLeagueFavourite(String leagueId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || leagueId.isEmpty) return;
    final nextOrder = await _nextLeagueFavouriteSortOrder(uid);
    await _client.from('league_favourites').insert({
      'user_id': uid,
      'league_id': leagueId,
      'sort_order': nextOrder,
    });
  }

  Future<int> _nextLeagueFavouriteSortOrder(String userId) async {
    final res = await _client
        .from('league_favourites')
        .select('sort_order')
        .eq('user_id', userId)
        .order('sort_order', ascending: false)
        .limit(1)
        .maybeSingle();
    if (res == null) return 0;
    final current = res['sort_order'];
    if (current is int) return current + 1;
    if (current is num) return current.toInt() + 1;
    return 0;
  }

  Future<void> updateLeagueFavouritesOrder(List<String> leagueIdsInOrder) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || leagueIdsInOrder.isEmpty) return;
    for (var i = 0; i < leagueIdsInOrder.length; i++) {
      final leagueId = leagueIdsInOrder[i];
      if (leagueId.isEmpty) continue;
      await _client
          .from('league_favourites')
          .update({'sort_order': i})
          .eq('user_id', uid)
          .eq('league_id', leagueId);
    }
  }

  Future<void> removeLeagueFavourite(String leagueId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || leagueId.isEmpty) return;
    await _client
        .from('league_favourites')
        .delete()
        .eq('user_id', uid)
        .eq('league_id', leagueId);
  }
}

class _TotwRatingAgg {
  _TotwRatingAgg(this.sampleRow);

  final Map<String, dynamic> sampleRow;
  double _sum = 0;
  int count = 0;

  void add(double rating) {
    if (rating > 0) {
      _sum += rating;
      count++;
    }
  }

  double get average => count > 0 ? _sum / count : 0;
}
