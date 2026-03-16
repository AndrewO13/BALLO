import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/season_model.dart';

class SeasonsRepository {
  SeasonsRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<SeasonModel?> getCurrentSeasonForLeague(String leagueId) async {
    final res = await _client
        .from('seasons')
        .select('id, league_id, season_name, start_date, end_date, status')
        .eq('league_id', leagueId)
        .eq('status', 'ongoing')
        .maybeSingle();
    if (res == null) return null;
    return SeasonModel.fromJson(Map<String, dynamic>.from(res));
  }

  Future<void> startSeason(String seasonId) async {
    await _client
        .from('seasons')
        .update({'status': 'ongoing'})
        .eq('id', seasonId);
  }

  Future<void> endSeason(String seasonId) async {
    await _client
        .from('seasons')
        .update({'status': 'ended'})
        .eq('id', seasonId);
  }

  Future<SeasonModel?> getUpcomingSeasonForLeague(String leagueId) async {
    final res = await _client
        .from('seasons')
        .select('id, league_id, season_name, start_date, end_date, status')
        .eq('league_id', leagueId)
        .eq('status', 'upcoming')
        .order('start_date', ascending: true)
        .maybeSingle();
    if (res == null) return null;
    return SeasonModel.fromJson(Map<String, dynamic>.from(res));
  }

  /// Returns ongoing season, or upcoming if no ongoing.
  Future<SeasonModel?> getOngoingOrUpcomingSeasonForLeague(
    String leagueId,
  ) async {
    final ongoing = await getCurrentSeasonForLeague(leagueId);
    if (ongoing != null) return ongoing;
    return getUpcomingSeasonForLeague(leagueId);
  }

  Future<List<SeasonModel>> getAllSeasonsForLeague(String leagueId) async {
    final res = await _client
        .from('seasons')
        .select('id, league_id, season_name, start_date, end_date, status')
        .eq('league_id', leagueId)
        .order('start_date', ascending: false);
    final list = List<Map<String, dynamic>>.from(res as List);
    return list.map(SeasonModel.fromJson).toList();
  }

  /// Returns seasons for the given league IDs (for matches filter).
  Future<List<SeasonModel>> getSeasonsForLeagues(
    List<String> leagueIds,
  ) async {
    if (leagueIds.isEmpty) return [];
    final res = await _client
        .from('seasons')
        .select('id, league_id, season_name, start_date, end_date, status')
        .inFilter('league_id', leagueIds)
        .order('start_date', ascending: false);
    final list = List<Map<String, dynamic>>.from(res as List);
    return list.map(SeasonModel.fromJson).toList();
  }

  /// Returns gameweeks for the given season IDs. Each item: {id, season_id, week}.
  Future<List<Map<String, dynamic>>> getGameweeksForSeasons(
    List<String> seasonIds,
  ) async {
    if (seasonIds.isEmpty) return [];
    final res = await _client
        .from('gameweeks')
        .select('id, season_id, week')
        .inFilter('season_id', seasonIds)
        .order('week', ascending: true);
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<String> createSeason({
    required String leagueId,
    required String seasonName,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final startStr = startDate.toIso8601String().split('T').first;
    final endStr = endDate.toIso8601String().split('T').first;
    final res = await _client
        .from('seasons')
        .insert({
          'league_id': leagueId,
          'season_name': seasonName,
          'start_date': startStr,
          'end_date': endStr,
          'status': 'upcoming',
        })
        .select('id')
        .single();
    return res['id']?.toString() ?? '';
  }
}
