import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/adaptive/adaptive.dart';
import '../../core/utils/app_video_cache.dart';
import '../../core/utils/explore_video_controller.dart';
import '../../core/utils/match_squad_pitch_state.dart';
import '../../core/utils/network_quality.dart';
import '../../core/utils/stoppage_alert.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_assets.dart';
import '../../core/utils/guest_mode.dart';
import '../../core/widgets/media_placeholders.dart';
import '../../data/repositories/leagues_repository.dart';
import '../../domain/models/fixture_goal_event.dart';
import '../../domain/models/match_model.dart';
import 'league_detail_page.dart';
import '../providers/fixture_match_lineup_provider.dart';
import '../providers/favourited_matches_provider.dart';
import '../providers/match_events_provider.dart';
import '../providers/fixture_match_ratings_provider.dart';
import '../providers/match_team_stats_provider.dart';
import '../../domain/models/fixture_match_rated_player.dart';
import '../providers/match_timer_adapter_provider.dart';
import '../providers/matches_provider.dart';
import '../providers/server_synced_match_clock_provider.dart';
import '../providers/teams_provider.dart';
import '../providers/video_upload_queue_provider.dart';
import '../widgets/media_access_sheet.dart';
import '../widgets/performance_radar_chart.dart';
import '../widgets/video_upload_progress_overlay.dart';
import '../widgets/match_live_status.dart';
import '../widgets/match_odds_chips.dart';
import '../widgets/squad/squad_pitch_view.dart';
import 'player_profile_page.dart';

class FixturePage extends ConsumerStatefulWidget {
  const FixturePage({super.key, required this.matchId});
  final String matchId;

  @override
  ConsumerState<FixturePage> createState() => _FixturePageState();
}

class _FixtureMatchInfo {
  const _FixtureMatchInfo({
    this.leagueId,
    this.leagueName,
    this.leagueLogoPath,
    this.venue,
    this.creatorName,
    this.defaultVenueImageUrl,
  });

  final String? leagueId;
  final String? leagueName;
  final String? leagueLogoPath;
  final String? venue;
  final String? creatorName;
  final String? defaultVenueImageUrl;
}

class _H2HMatchResult {
  const _H2HMatchResult({
    required this.teamAId,
    required this.teamBId,
    required this.teamAScore,
    required this.teamBScore,
  });

  final String teamAId;
  final String teamBId;
  final int teamAScore;
  final int teamBScore;
}

class _TeamFormMatchResult {
  const _TeamFormMatchResult({
    required this.homeTeamId,
    required this.awayTeamId,
    required this.homeScore,
    required this.awayScore,
  });

  final String homeTeamId;
  final String awayTeamId;
  final int homeScore;
  final int awayScore;
}

Color _matchRatingColor(double rating) {
  if (rating >= 8.0) return const Color(0xFF2ECC71); // green
  if (rating >= 7.0) return const Color(0xFF58D68D); // light green
  if (rating >= 6.0) return const Color(0xFFF4D03F); // yellow
  if (rating >= 5.0) return const Color(0xFFF39C12); // orange
  return const Color(0xFFE74C3C); // red
}

double _normalizedRating(double? rating) {
  if (rating != null && rating > 0.0) return rating;
  return 6.0; // baseline for minimal activity
}

class _FixtureTeamFormData {
  const _FixtureTeamFormData({
    required this.teamARecent,
    required this.teamBRecent,
    required this.logoByTeamId,
  });

  final List<_TeamFormMatchResult> teamARecent;
  final List<_TeamFormMatchResult> teamBRecent;
  final Map<String, String> logoByTeamId;
}

class _FixtureStandingRowData {
  const _FixtureStandingRowData({
    required this.position,
    required this.teamShortName,
    required this.logoPath,
    required this.played,
    required this.goalDiff,
    required this.points,
  });

  final int position;
  final String teamShortName;
  final String logoPath;
  final int played;
  final int goalDiff;
  final int points;
}

class _FixtureStandingsData {
  const _FixtureStandingsData({required this.teamA, required this.teamB});

  final _FixtureStandingRowData? teamA;
  final _FixtureStandingRowData? teamB;
}

class _FeaturedPlayerData {
  const _FeaturedPlayerData({
    required this.playerId,
    required this.name,
    required this.rating,
    this.imageUrl,
  });

  final String playerId;
  final String name;
  final double rating;
  final String? imageUrl;
}

class _FixtureFeaturedPlayersData {
  const _FixtureFeaturedPlayersData({
    required this.teamAPlayer,
    required this.teamBPlayer,
  });

  final _FeaturedPlayerData? teamAPlayer;
  final _FeaturedPlayerData? teamBPlayer;
}

enum _FixtureMenuAction { edit, postpone, delete }

String? _resolveLeagueLogoPath(String? logoId) => resolveTeamLogoPath(logoId);

final fixtureMatchInfoProvider = FutureProvider.autoDispose
    .family<_FixtureMatchInfo?, String>((ref, matchId) async {
      if (matchId.isEmpty) return null;
      final supabase = Supabase.instance.client;

      final matchRes = await supabase
          .from('matches')
          .select('league_id, venue')
          .eq('id', matchId)
          .maybeSingle();
      if (matchRes == null) return null;

      final leagueId = matchRes['league_id']?.toString();
      final venue = matchRes['venue']?.toString();
      if (leagueId == null || leagueId.isEmpty) {
        return _FixtureMatchInfo(venue: venue);
      }

      final leagueRes = await supabase
          .from('leagues')
          .select('id, league_name, logo_id, created_by, default_venue_image_url')
          .eq('id', leagueId)
          .maybeSingle();
      if (leagueRes == null) {
        return _FixtureMatchInfo(leagueId: leagueId, venue: venue);
      }

      final createdBy = leagueRes['created_by']?.toString();
      String? creatorName;
      if (createdBy != null && createdBy.isNotEmpty) {
        final creatorRes = await supabase
            .from('players')
            .select('player_name, username')
            .eq('id', createdBy)
            .maybeSingle();
        if (creatorRes != null) {
          creatorName =
              creatorRes['player_name']?.toString().trim().isNotEmpty == true
              ? creatorRes['player_name']?.toString()
              : creatorRes['username']?.toString();
        }
      }

      return _FixtureMatchInfo(
        leagueId: leagueRes['id']?.toString(),
        leagueName: leagueRes['league_name']?.toString(),
        leagueLogoPath: _resolveLeagueLogoPath(
          leagueRes['logo_id']?.toString(),
        ),
        venue: venue,
        creatorName: creatorName,
        defaultVenueImageUrl: leagueRes['default_venue_image_url']?.toString(),
      );
    });

final fixtureH2HResultsProvider = FutureProvider.autoDispose
    .family<List<_H2HMatchResult>, String>((ref, matchId) async {
      if (matchId.isEmpty) return const [];
      final match = await ref.watch(fixtureMatchProvider(matchId).future);
      if (match == null || match.teamA.id.isEmpty || match.teamB.id.isEmpty) {
        return const [];
      }

      final supabase = Supabase.instance.client;
      final currentDate = DateTime(
        match.matchDate.year,
        match.matchDate.month,
        match.matchDate.day,
      );

      final res = await supabase
          .from('matches')
          .select(
            'id, teamA, teamB, teamA_score, teamB_score, match_date, match_time',
          )
          .or(
            'and(teamA.eq.${match.teamA.id},teamB.eq.${match.teamB.id}),'
            'and(teamA.eq.${match.teamB.id},teamB.eq.${match.teamA.id})',
          )
          .neq('id', match.id)
          .not('teamA_score', 'is', null)
          .not('teamB_score', 'is', null)
          .order('match_date', ascending: false)
          .order('match_time', ascending: false)
          .limit(8);

      final rows = List<Map<String, dynamic>>.from(res as List);
      final results = <_H2HMatchResult>[];
      for (final row in rows) {
        final dateRaw = row['match_date']?.toString();
        if (dateRaw == null || dateRaw.isEmpty) continue;
        final rowDate = DateTime.tryParse(dateRaw);
        if (rowDate == null) continue;
        final rowDateOnly = DateTime(rowDate.year, rowDate.month, rowDate.day);
        if (rowDateOnly.isAfter(currentDate)) continue;

        final scoreA = int.tryParse(row['teamA_score']?.toString() ?? '');
        final scoreB = int.tryParse(row['teamB_score']?.toString() ?? '');
        final teamAId = row['teamA']?.toString() ?? '';
        final teamBId = row['teamB']?.toString() ?? '';
        if (scoreA == null ||
            scoreB == null ||
            teamAId.isEmpty ||
            teamBId.isEmpty) {
          continue;
        }
        results.add(
          _H2HMatchResult(
            teamAId: teamAId,
            teamBId: teamBId,
            teamAScore: scoreA,
            teamBScore: scoreB,
          ),
        );
      }
      return results;
    });

final fixtureTeamFormProvider = FutureProvider.autoDispose
    .family<_FixtureTeamFormData, String>((ref, matchId) async {
      if (matchId.isEmpty) {
        return const _FixtureTeamFormData(
          teamARecent: [],
          teamBRecent: [],
          logoByTeamId: {},
        );
      }
      final currentMatch = await ref.watch(
        fixtureMatchProvider(matchId).future,
      );
      if (currentMatch == null) {
        return const _FixtureTeamFormData(
          teamARecent: [],
          teamBRecent: [],
          logoByTeamId: {},
        );
      }

      final supabase = Supabase.instance.client;
      final currentDateStr = currentMatch.matchDate
          .toIso8601String()
          .split('T')
          .first;
      final currentTimeRaw = currentMatch.matchTime.trim();
      final currentTimeStr = currentTimeRaw.isEmpty
          ? '23:59:59'
          : (currentTimeRaw.length == 5
                ? '$currentTimeRaw:00'
                : currentTimeRaw);

      Future<List<_TeamFormMatchResult>> fetchRecentForTeam(
        String teamId,
      ) async {
        final res = await supabase
            .from('matches')
            .select(
              'id, match_date, match_time, teamA, teamB, teamA_score, teamB_score',
            )
            .or('teamA.eq.$teamId,teamB.eq.$teamId')
            .neq('id', currentMatch.id)
            .not('teamA_score', 'is', null)
            .not('teamB_score', 'is', null)
            .or(
              'match_date.lt.$currentDateStr,'
              'and(match_date.eq.$currentDateStr,match_time.lt.$currentTimeStr)',
            )
            .order('match_date', ascending: false)
            .order('match_time', ascending: false)
            .limit(5);

        final rows = List<Map<String, dynamic>>.from(res as List);
        final output = <_TeamFormMatchResult>[];
        for (final row in rows) {
          final homeScore = int.tryParse(row['teamA_score']?.toString() ?? '');
          final awayScore = int.tryParse(row['teamB_score']?.toString() ?? '');
          final homeTeamId = row['teamA']?.toString() ?? '';
          final awayTeamId = row['teamB']?.toString() ?? '';
          if (homeScore == null ||
              awayScore == null ||
              homeTeamId.isEmpty ||
              awayTeamId.isEmpty) {
            continue;
          }

          output.add(
            _TeamFormMatchResult(
              homeTeamId: homeTeamId,
              awayTeamId: awayTeamId,
              homeScore: homeScore,
              awayScore: awayScore,
            ),
          );
        }
        return output;
      }

      final teamARecent = await fetchRecentForTeam(currentMatch.teamA.id);
      final teamBRecent = await fetchRecentForTeam(currentMatch.teamB.id);

      final allTeamIds = <String>{
        currentMatch.teamA.id,
        currentMatch.teamB.id,
        ...teamARecent.expand((m) => [m.homeTeamId, m.awayTeamId]),
        ...teamBRecent.expand((m) => [m.homeTeamId, m.awayTeamId]),
      }..removeWhere((id) => id.isEmpty);

      final logoByTeamId = <String, String>{
        currentMatch.teamA.id: currentMatch.teamA.logoPath,
        currentMatch.teamB.id: currentMatch.teamB.logoPath,
      };

      if (allTeamIds.isNotEmpty) {
        final teamsRes = await supabase
            .from('teams')
            .select('id, logo_id')
            .inFilter('id', allTeamIds.toList());
        for (final row in List<Map<String, dynamic>>.from(teamsRes as List)) {
          final id = row['id']?.toString();
          if (id == null || id.isEmpty) continue;
          final logoId = row['logo_id']?.toString();
          if (logoId == null || logoId.isEmpty) continue;
          final resolved = _resolveLeagueLogoPath(logoId);
          if (resolved != null && resolved.isNotEmpty) {
            logoByTeamId[id] = resolved;
          }
        }
      }

      return _FixtureTeamFormData(
        teamARecent: teamARecent,
        teamBRecent: teamBRecent,
        logoByTeamId: logoByTeamId,
      );
    });

final fixtureStandingsProvider = FutureProvider.autoDispose
    .family<_FixtureStandingsData?, String>((ref, matchId) async {
      if (matchId.isEmpty) return null;
      final match = await ref.watch(fixtureMatchProvider(matchId).future);
      final matchInfo = await ref.watch(
        fixtureMatchInfoProvider(matchId).future,
      );
      final leagueId = matchInfo?.leagueId;
      if (match == null || leagueId == null || leagueId.isEmpty) return null;

      final standings = await LeaguesRepository().getLeagueStandings(leagueId);

      _FixtureStandingRowData? pickRowForTeam(String teamId) {
        for (var i = 0; i < standings.length; i++) {
          final row = standings[i];
          if (row['team_id']?.toString() != teamId) continue;
          return _FixtureStandingRowData(
            position: i + 1,
            teamShortName: row['team_short_form']?.toString() ?? '—',
            logoPath:
                _resolveLeagueLogoPath(row['team_logo']?.toString()) ?? '',
            played: int.tryParse(row['played']?.toString() ?? '') ?? 0,
            goalDiff:
                int.tryParse(row['goal_difference']?.toString() ?? '') ?? 0,
            points: int.tryParse(row['points']?.toString() ?? '') ?? 0,
          );
        }
        return null;
      }

      return _FixtureStandingsData(
        teamA: pickRowForTeam(match.teamA.id),
        teamB: pickRowForTeam(match.teamB.id),
      );
    });

final fixtureFeaturedPlayersProvider = FutureProvider.autoDispose
    .family<_FixtureFeaturedPlayersData, String>((ref, matchId) async {
      if (matchId.isEmpty) {
        return const _FixtureFeaturedPlayersData(
          teamAPlayer: null,
          teamBPlayer: null,
        );
      }
      final match = await ref.watch(fixtureMatchProvider(matchId).future);
      if (match == null) {
        return const _FixtureFeaturedPlayersData(
          teamAPlayer: null,
          teamBPlayer: null,
        );
      }

      final supabase = Supabase.instance.client;
      final currentDateStr = match.matchDate.toIso8601String().split('T').first;
      final currentTimeRaw = match.matchTime.trim();
      final currentTimeStr = currentTimeRaw.isEmpty
          ? '23:59:59'
          : (currentTimeRaw.length == 5
                ? '$currentTimeRaw:00'
                : currentTimeRaw);

      Future<String?> previousMatchIdForTeam(String teamId) async {
        final res = await supabase
            .from('matches')
            .select('id')
            .or('teamA.eq.$teamId,teamB.eq.$teamId')
            .neq('id', match.id)
            .or(
              'match_date.lt.$currentDateStr,'
              'and(match_date.eq.$currentDateStr,match_time.lt.$currentTimeStr)',
            )
            .order('match_date', ascending: false)
            .order('match_time', ascending: false)
            .limit(1)
            .maybeSingle();
        return res?['id']?.toString();
      }

      Future<_FeaturedPlayerData?> topRatedPlayerForTeamInMatch({
        required String teamId,
        required String? previousMatchId,
      }) async {
        if (previousMatchId == null || previousMatchId.isEmpty) return null;
        final res = await supabase
            .from('match_player_stats')
            .select(
              'player_id, rating, player:players!match_player_stats_player_id_fkey(player_name, image_url)',
            )
            .eq('match_id', previousMatchId)
            .eq('team_id', teamId)
            .order('rating', ascending: false)
            .limit(1)
            .maybeSingle();
        if (res == null) return null;
        final rating = double.tryParse(res['rating']?.toString() ?? '');
        final playerId = res['player_id']?.toString() ?? '';
        if (rating == null || playerId.isEmpty) return null;
        final player = res['player'];
        final playerMap = player is Map<String, dynamic>
            ? player
            : (player is Map
                  ? Map<String, dynamic>.from(player)
                  : <String, dynamic>{});
        final name = playerMap['player_name']?.toString() ?? '—';
        final imageUrl = playerMap['image_url']?.toString();
        return _FeaturedPlayerData(
          playerId: playerId,
          name: name,
          rating: rating,
          imageUrl: imageUrl,
        );
      }

      final teamAPrevious = await previousMatchIdForTeam(match.teamA.id);
      final teamBPrevious = await previousMatchIdForTeam(match.teamB.id);
      final teamAPlayer = await topRatedPlayerForTeamInMatch(
        teamId: match.teamA.id,
        previousMatchId: teamAPrevious,
      );
      final teamBPlayer = await topRatedPlayerForTeamInMatch(
        teamId: match.teamB.id,
        previousMatchId: teamBPrevious,
      );
      return _FixtureFeaturedPlayersData(
        teamAPlayer: teamAPlayer,
        teamBPlayer: teamBPlayer,
      );
    });

class _FixturePageState extends ConsumerState<FixturePage> {
  bool _isUploadingMatchVideo = false;
  bool _showEditOverlay = false;
  @override
  Widget build(BuildContext context) {
    final asyncMatch = ref.watch(fixtureMatchProvider(widget.matchId));
    return asyncMatch.when(
      loading: () => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(child: Text('Could not load match: $err')),
      ),
      data: (match) {
        if (match == null) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            body: const Center(child: Text('Match not found')),
          );
        }
        return _buildFixtureWithMatch(context, match);
      },
    );
  }

  Future<void> _showSetTimerDialog(
    BuildContext context,
    String matchId,
    WidgetRef ref,
  ) async {
    final result = await showDialog<int?>(
      context: context,
      builder: (ctx) => _SetTimerDialog(initialMinutes: 45),
    );

    if (result != null && context.mounted) {
      ref
          .read(matchTimerConfigProvider(matchId).notifier)
          .setHalfDuration(result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Timer set: $result min per half')),
      );
    }
  }

  Future<void> _postponeFixture(BuildContext context, MatchModel match) async {
    if (match.status != MatchStatus.upcoming) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only upcoming fixtures can be postponed')),
      );
      return;
    }
    final parts = match.matchTime.split(':');
    final initialHour = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 15;
    final initialMinute = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: match.matchDate.isAfter(DateTime.now())
          ? match.matchDate
          : DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
    );
    if (pickedTime == null || !mounted) return;
    final time =
        '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';
    try {
      await ref.read(matchesRepositoryProvider).updateMatchSchedule(
            match.id,
            matchDate: pickedDate,
            matchTime: time,
          );
      if (!mounted) return;
      ref.invalidate(fixtureMatchProvider(match.id));
      ref.invalidate(matchesProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fixture postponed')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not postpone fixture: $e')),
      );
    }
  }

  Future<void> _deleteFixture(BuildContext context, MatchModel match) async {
    if (match.status != MatchStatus.upcoming) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only upcoming fixtures can be deleted')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete fixture'),
        content: const Text('This removes the fixture permanently. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(matchesRepositoryProvider).deleteMatch(match.id);
      if (!mounted) return;
      ref.invalidate(matchesProvider);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fixture deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete fixture: $e')),
      );
    }
  }

  void _onFixtureMenuSelected(
    BuildContext context,
    MatchModel match,
    _FixtureMenuAction action,
  ) {
    switch (action) {
      case _FixtureMenuAction.edit:
        if (match.status == MatchStatus.upcoming) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Score can be edited once the match has started'),
            ),
          );
          return;
        }
        setState(() => _showEditOverlay = true);
      case _FixtureMenuAction.postpone:
        _postponeFixture(context, match);
      case _FixtureMenuAction.delete:
        _deleteFixture(context, match);
    }
  }

  /// Picks a clip and queues a background upload so the user can keep using the app.
  Future<void> _pickAndEnqueueMatchVideo(
    BuildContext context,
    MatchModel match,
  ) async {
    try {
      if (!await ensureMediaAccess(context, MediaAccessKind.videos)) return;
      final picker = ImagePicker();
      final xFile = await picker.pickVideo(source: ImageSource.gallery);
      if (xFile == null || !context.mounted) return;

      final fileSizeBytes = await xFile.length();
      if (!context.mounted) return;
      final onCellular = await NetworkQuality.isCellular;
      if (!context.mounted) return;
      const largeUploadThresholdBytes = 15 * 1024 * 1024;
      if (onCellular || fileSizeBytes > largeUploadThresholdBytes) {
        final sizeMb = (fileSizeBytes / (1024 * 1024)).toStringAsFixed(0);
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(onCellular ? 'Upload on mobile data?' : 'Large video'),
            content: Text(
              onCellular
                  ? 'You are on mobile data. This clip is about $sizeMb MB. '
                        'Uploading now can use a lot of your allowance.\n\n'
                        'Wi-Fi is still the better option for longer highlights.'
                  : 'This clip is about $sizeMb MB.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(onCellular ? 'Upload anyway' : 'Upload'),
              ),
            ],
          ),
        );
        if (proceed != true || !context.mounted) return;
      }

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You must be signed in to upload a video.'),
            ),
          );
        }
        return;
      }

      final messenger = ScaffoldMessenger.of(context);
      unawaited(
        ref
            .read(videoUploadQueueProvider.notifier)
            .enqueue(
              localVideoPath: xFile.path,
              originalFileName: xFile.name,
              match: match,
              uploaderUserId: userId,
            )
            .then((_) {
              messenger.showSnackBar(
                const SnackBar(content: Text('Video added')),
              );
            })
            .catchError((Object e) {
              messenger.showSnackBar(
                SnackBar(content: Text('Could not add video: $e')),
              );
            }),
      );
    } catch (e) {
      if (!context.mounted) return;
      if (await presentMediaAccessSheetIfNeeded(
        context,
        e,
        MediaAccessKind.videos,
      )) {
        return;
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not start upload: $e')));
    }
  }

  void _showScorersAssistersDialog(
    BuildContext context,
    WidgetRef ref,
    MatchModel match,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Scorers & Assisters',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Consumer(
                builder: (context, ref, _) {
                  final eventsAsync = ref.watch(matchEventsProvider(match.id));
                  return eventsAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, _) => Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not load scorers',
                        style: textTheme.bodyMedium,
                      ),
                    ),
                    data: (events) {
                      final videosAsync = ref.watch(
                        matchVideosProvider(match.id),
                      );
                      final goals = events.where((e) => _isGoalEventType(e.eventType)).toList();
                      final teamAId = match.teamA.id;
                      final teamAGoals = goals
                          .where((g) => g.teamId == teamAId)
                          .toList();
                      final teamBGoals = goals
                          .where((g) => g.teamId != teamAId)
                          .toList();
                      return videosAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (_, _) => Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildScorersColumns(
                              textTheme,
                              colorScheme,
                              match,
                              teamAGoals,
                              teamBGoals,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Could not load videos',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        data: (videos) => Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildScorersColumns(
                              textTheme,
                              colorScheme,
                              match,
                              teamAGoals,
                              teamBGoals,
                            ),
                            const SizedBox(height: 20),
                            _buildMatchVideosPanel(
                              dialogContext: ctx,
                              ref: ref,
                              match: match,
                              videos: videos,
                              textTheme: textTheme,
                              colorScheme: colorScheme,
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleAddMatchVideoFromDialog(
    BuildContext dialogContext,
    MatchModel match,
  ) async {
    if (_isUploadingMatchVideo) return;
    setState(() {
      _isUploadingMatchVideo = true;
    });
    await _pickAndEnqueueMatchVideo(dialogContext, match);
    if (mounted) {
      setState(() {
        _isUploadingMatchVideo = false;
      });
    }
  }

  Widget _buildMatchVideosPanel({
    required BuildContext dialogContext,
    required WidgetRef ref,
    required MatchModel match,
    required List<MatchVideoItem> videos,
    required TextTheme textTheme,
    required ColorScheme colorScheme,
  }) {
    final uploadJobs = ref
        .watch(videoUploadQueueProvider)
        .where((job) => job.matchId == match.id)
        .toList();
    final hasVideos = videos.isNotEmpty;
    final hasUploads = uploadJobs.isNotEmpty;
    final hasContent = hasVideos || hasUploads;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.video_collection_rounded,
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Match videos',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: hasContent
                      ? colorScheme.secondaryContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  hasVideos
                      ? '${videos.length} added'
                      : (hasUploads ? 'uploading' : 'none yet'),
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: hasContent
                        ? colorScheme.onSecondaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!hasContent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.ondemand_video_outlined,
                    color: colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No highlight uploaded yet. Add the first clip.',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.tonalIcon(
                    onPressed: _isUploadingMatchVideo
                        ? null
                        : () => _handleAddMatchVideoFromDialog(
                            dialogContext,
                            match,
                          ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 130,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (context, index) {
                        if (index < uploadJobs.length) {
                          return _MatchStoryUploadingCircle(
                            job: uploadJobs[index],
                            teamALogo: match.teamA.logoPath,
                            teamBLogo: match.teamB.logoPath,
                            onDismiss: () => ref
                                .read(videoUploadQueueProvider.notifier)
                                .dismiss(uploadJobs[index].id),
                          );
                        }
                        final item = videos[index - uploadJobs.length];
                        return _MatchStoryCircle(
                          url: item.videoUrl,
                          teamALogo: match.teamA.logoPath,
                          teamBLogo: match.teamB.logoPath,
                          uploaderName: item.uploaderName,
                          uploaderImageUrl: item.uploaderImageUrl,
                          addedAt: item.createdAt,
                        );
                      },
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemCount: uploadJobs.length + videos.length,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _MatchStoryAddButton(
                  onPressed: () => _handleAddMatchVideoFromDialog(
                    dialogContext,
                    match,
                  ),
                ),
              ],
            ),
          if (hasVideos) ...[
            const SizedBox(height: 8),
            Text(
              'Tap any clip to watch full screen',
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScorersColumns(
    TextTheme textTheme,
    ColorScheme colorScheme,
    MatchModel match,
    List<MatchEventDisplay> teamAGoals,
    List<MatchEventDisplay> teamBGoals,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildTeamScorersCard(
                textTheme: textTheme,
                colorScheme: colorScheme,
                teamShort: match.teamA.shortForm,
                goals: teamAGoals,
                alignEnd: false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTeamScorersCard(
                textTheme: textTheme,
                colorScheme: colorScheme,
                teamShort: match.teamB.shortForm,
                goals: teamBGoals,
                alignEnd: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTeamScorersCard({
    required TextTheme textTheme,
    required ColorScheme colorScheme,
    required String teamShort,
    required List<MatchEventDisplay> goals,
    required bool alignEnd,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Column(
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!alignEnd) ...[
                Icon(
                  Icons.shield_outlined,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                teamShort,
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              if (alignEnd) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.shield_outlined,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (goals.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'No goals',
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...goals.map(
              (g) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _buildGoalEventChip(
                  textTheme: textTheme,
                  colorScheme: colorScheme,
                  goal: g,
                  alignEnd: alignEnd,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGoalEventChip({
    required TextTheme textTheme,
    required ColorScheme colorScheme,
    required MatchEventDisplay goal,
    required bool alignEnd,
  }) {
    final scorer = goal.scorerName?.trim();
    final assister = goal.assisterName?.trim();
    final scorerLabel = (scorer == null || scorer.isEmpty) ? 'Unknown' : scorer;
    final hasAssister = assister != null && assister.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!alignEnd) ...[
                Text(
                  "${goal.minute}'",
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  scorerLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: alignEnd ? TextAlign.right : TextAlign.left,
                ),
              ),
              if (alignEnd) ...[
                const SizedBox(width: 6),
                Text(
                  "${goal.minute}'",
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          if (hasAssister) ...[
            const SizedBox(height: 3),
            Text(
              'Assist: $assister',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: alignEnd ? TextAlign.right : TextAlign.left,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFixtureWithMatch(BuildContext context, MatchModel match) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final matchInfoAsync = ref.watch(fixtureMatchInfoProvider(match.id));
    final h2hResultsAsync = ref.watch(fixtureH2HResultsProvider(match.id));
    final h2hResults =
        h2hResultsAsync.asData?.value ?? const <_H2HMatchResult>[];

    var teamAWins = 0;
    var draws = 0;
    var teamBWins = 0;
    for (final r in h2hResults) {
      final aPerspective = r.teamAId == match.teamA.id
          ? r.teamAScore
          : (r.teamBId == match.teamA.id ? r.teamBScore : r.teamAScore);
      final bPerspective = r.teamBId == match.teamB.id
          ? r.teamBScore
          : (r.teamAId == match.teamB.id ? r.teamAScore : r.teamBScore);
      if (aPerspective == bPerspective) {
        draws++;
      } else if (aPerspective > bPerspective) {
        teamAWins++;
      } else {
        teamBWins++;
      }
    }
    final clock = ref.watch(matchTimerAdapterProvider(match.id));
    final clockLabel = formatMatchClock(clock);
    final leaguesAsync = ref.watch(matchesFilterLeaguesProvider);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    final bool isLeagueOwner = leaguesAsync.maybeWhen(
      data: (leagues) {
        if (currentUserId == null || match.leagueName == null) {
          return false;
        }
        return leagues.any(
          (l) =>
              l.leagueName == (match.leagueName ?? '') &&
              l.createdBy == currentUserId,
        );
      },
      orElse: () => false,
    );

    // Ensure the match clock is running whenever this fixture is viewed while
    // the match is in an ongoing state (e.g. after navigating back to the page
    // or if the status was updated from another screen/device). This keeps the
    // green pill stopwatch in sync with the global match clock.
    if (match.status == MatchStatus.ongoing && clock == Duration.zero) {
      ref.read(matchTimerAdapterProvider(match.id).notifier).start();
    }

    final timerConfig = ref.watch(matchTimerConfigProvider(match.id));
    final timing = ref
        .watch(fixtureMatchTimelineTimingProvider(match.id))
        .asData
        ?.value;
    final halfPhase = resolveMatchHalfPhase(
      status: match.status,
      resumedFromHalftimeAt: timing?.resumedFromHalftimeAt,
      hasReachedHalfTime: timerConfig.hasReachedHalfTime,
    );

    return Stack(
      children: [
        DefaultTabController(
      length: 4,
      child: Scaffold(
        extendBodyBehindAppBar: false,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => _MatchControlsModal(matchId: match.id),
            );
          },
          elevation: 0,
          child: const Icon(Icons.sports),
        ),
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            if (isLeagueOwner)
              PopupMenuButton<_FixtureMenuAction>(
                icon: const Icon(Icons.more_vert),
                onSelected: (action) =>
                    _onFixtureMenuSelected(context, match, action),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _FixtureMenuAction.edit,
                    enabled: match.status != MatchStatus.upcoming,
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: match.status != MatchStatus.upcoming
                              ? null
                              : Theme.of(context).disabledColor,
                        ),
                        const SizedBox(width: 12),
                        const Text('Edit match'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _FixtureMenuAction.postpone,
                    enabled: match.status == MatchStatus.upcoming,
                    child: Row(
                      children: [
                        Icon(
                          Icons.event_busy_outlined,
                          size: 20,
                          color: match.status == MatchStatus.upcoming
                              ? null
                              : Theme.of(context).disabledColor,
                        ),
                        const SizedBox(width: 12),
                        const Text('Postpone'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _FixtureMenuAction.delete,
                    enabled: match.status == MatchStatus.upcoming,
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: match.status == MatchStatus.upcoming
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).disabledColor,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Delete',
                          style: TextStyle(
                            color: match.status == MatchStatus.upcoming
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context).disabledColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            else if (GuestMode.isGuest)
              Builder(
                builder: (context) {
                  final favourites = ref.watch(favouritedMatchesProvider);
                  final isFavourited = favourites.any((m) => m.id == match.id);
                  return IconButton(
                    icon: Icon(
                      isFavourited
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                    ),
                    color: isFavourited ? colorScheme.primary : null,
                    onPressed: () {
                      ref
                          .read(favouritedMatchesProvider.notifier)
                          .toggle(FavouritedMatch.fromMatchModel(match));
                    },
                  );
                },
              )
            else
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {},
              ),
          ],
        ),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            final bannerWidth = MediaQuery.sizeOf(context).width;
            var bannerHeight = bannerWidth * 305 / AppResponsive.designWidth;
            if (AppResponsive.isLandscapePhone(context)) {
              bannerHeight = bannerHeight.clamp(
                180.0,
                MediaQuery.sizeOf(context).height * 0.5,
              );
            }
            return [
              SliverToBoxAdapter(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: double.infinity,
                    height: bannerHeight,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      child: Stack(
                        children: [
                          (((match.venueImageUrl ?? '').startsWith('http://') ||
                                      (match.venueImageUrl ?? '').startsWith('https://'))
                                  ? match.venueImageUrl
                                  : ((matchInfoAsync.asData?.value?.defaultVenueImageUrl ?? '')
                                              .startsWith('http://') ||
                                          (matchInfoAsync.asData?.value?.defaultVenueImageUrl ??
                                                  '')
                                              .startsWith('https://')
                                      ? matchInfoAsync
                                          .asData
                                          ?.value
                                          ?.defaultVenueImageUrl
                                      : null))
                              !=
                              null
                              ? Image(
                                  image: appCachedImageProvider(
                                    ((match.venueImageUrl ?? '').startsWith('http://') ||
                                            (match.venueImageUrl ?? '')
                                                .startsWith('https://'))
                                        ? match.venueImageUrl!
                                        : matchInfoAsync
                                                .asData
                                                ?.value
                                                ?.defaultVenueImageUrl ??
                                            '',
                                  ),
                                  fit: BoxFit.fill,
                                  errorBuilder: (_, _, _) => Image.asset(
                                    AppAssets.pitchBg,
                                    fit: BoxFit.fill,
                                  ),
                                )
                              : Image.asset(AppAssets.pitchBg, fit: BoxFit.fill),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: const [0.0, 0.36, 0.94],
                                colors: [
                                  const Color(0xFF2D372F).withValues(alpha: 0.1),
                                  const Color(0xFF2D372F).withValues(alpha: 0.25),
                                  colorScheme.surface.withValues(alpha: 1.0),
                                ],
                              ),
                            ),
                          ),
                          Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 45.0,
                              ),
                              padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHigh
                                    .withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (match.status ==
                                              MatchStatus.ongoing) ...[
                                            const MatchLivePulseIndicator(
                                              size: 8,
                                            ),
                                            if (halfPhase != null)
                                              const SizedBox(width: 6),
                                          ],
                                          if (halfPhase != null)
                                            MatchHalfPhaseChip(
                                              phase: halfPhase,
                                            ),
                                        ],
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        icon: const Icon(Icons.open_in_full),
                                        onPressed: () =>
                                            _showScorersAssistersDialog(
                                              context,
                                              ref,
                                              match,
                                            ),
                                        iconSize: 20,
                                        color: colorScheme.onSurface,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          children: [
                                            ClipOval(
                                              child: _FixtureTeamLogo(
                                                path: match.teamA.logoPath,
                                                size: 46.4,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              match.teamA.shortForm,
                                              style: textTheme.bodyLarge
                                                  ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0,
                                        ),
                                        child: Column(
                                          children: [
                                            Text(
                                              match.status ==
                                                      MatchStatus.upcoming
                                                  ? match.timeDisplay
                                                  : (match.scoreText ?? '–'),
                                              style: textTheme.displayMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                            const SizedBox(height: 8),
                                            match.status == MatchStatus.upcoming
                                                ? _BuildUpcomingPill(
                                                    match: match,
                                                    onTap: () =>
                                                        _showSetTimerDialog(
                                                          context,
                                                          match.id,
                                                          ref,
                                                        ),
                                                  )
                                                : _BuildOngoingPill(
                                                    match: match,
                                                    clock: clock,
                                                    clockLabel: clockLabel,
                                                    matchId: match.id,
                                                  ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          children: [
                                            ClipOval(
                                              child: _FixtureTeamLogo(
                                                path: match.teamB.logoPath,
                                                size: 46.4,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              match.teamB.shortForm,
                                              style: textTheme.bodyLarge
                                                  ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Divider(
                                    height: 1,
                                    color: colorScheme.outline,
                                  ),
                                  const SizedBox(height: 12),
                                  Consumer(
                                    builder: (context, ref, _) {
                                      final eventsAsync = ref.watch(
                                        matchEventsProvider(match.id),
                                      );
                                      return eventsAsync.when(
                                        loading: () => const SizedBox.shrink(),
                                        error: (_, _) =>
                                            const SizedBox.shrink(),
                                        data: (events) {
                                          final goals = events
                                              .where(
                                                (e) => _isGoalEventType(
                                                  e.eventType,
                                                ),
                                              )
                                              .toList();
                                          if (goals.isEmpty) {
                                            return const SizedBox.shrink();
                                          }
                                          final teamAId = match.teamA.id;
                                          final teamAGoals = goals
                                              .where((g) => g.teamId == teamAId)
                                              .toList();
                                          final teamBGoals = goals
                                              .where((g) => g.teamId != teamAId)
                                              .toList();
                                          // Only show first goal scorer per team in the header
                                          final firstA = teamAGoals.isNotEmpty
                                              ? teamAGoals.first
                                              : null;
                                          final firstB = teamBGoals.isNotEmpty
                                              ? teamBGoals.first
                                              : null;
                                          return Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: firstA != null
                                                      ? [
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.only(
                                                                  bottom: 4,
                                                                ),
                                                            child: Text.rich(
                                                              TextSpan(
                                                                style:
                                                                    textTheme
                                                                        .bodySmall,
                                                                children: [
                                                                  TextSpan(
                                                                    text: firstA
                                                                            .scorerName ??
                                                                        '?',
                                                                    style: const TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                                  ),
                                                                  TextSpan(
                                                                    text:
                                                                        " ${firstA.minute}'",
                                                                  ),
                                                                ],
                                                              ),
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                            ),
                                                          ),
                                                        ]
                                                      : [],
                                                ),
                                              ),
                                              Consumer(
                                                builder: (context, ref, _) {
                                                  final videosAsync = ref.watch(
                                                    matchVideosProvider(
                                                      match.id,
                                                    ),
                                                  );
                                                  final data =
                                                      videosAsync.asData;
                                                  final hasVideos = data !=
                                                          null &&
                                                      data.value.isNotEmpty;
                                                  const ringGreen =
                                                      Color(0xFF00FF5A);
                                                  final icon = SvgPicture.asset(
                                                    AppAssets.matchGoalIcon,
                                                    width: 15,
                                                    height: 15,
                                                  );
                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                      top: 2,
                                                    ),
                                                    child: hasVideos
                                                        ? Container(
                                                            width: 20,
                                                            height: 20,
                                                            decoration:
                                                                BoxDecoration(
                                                              shape: BoxShape
                                                                  .circle,
                                                              border:
                                                                  Border.all(
                                                                color:
                                                                    ringGreen,
                                                                width: 2,
                                                              ),
                                                            ),
                                                            child: Center(
                                                              child: icon,
                                                            ),
                                                          )
                                                        : Center(child: icon),
                                                  );
                                                },
                                              ),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: firstB != null
                                                      ? [
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.only(
                                                                  bottom: 4,
                                                                ),
                                                            child: Text.rich(
                                                              TextSpan(
                                                                style:
                                                                    textTheme
                                                                        .bodySmall,
                                                                children: [
                                                                  TextSpan(
                                                                    text:
                                                                        "${firstB.minute}' ",
                                                                  ),
                                                                  TextSpan(
                                                                    text: firstB
                                                                            .scorerName ??
                                                                        '?',
                                                                    style: const TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                            ),
                                                          ),
                                                        ]
                                                      : [],
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _FixtureSliverTabBarDelegate(
                  TabBar(
                    labelColor: colorScheme.onSurface,
                    unselectedLabelColor: colorScheme.onSurfaceVariant,
                    indicatorColor: colorScheme.onSurface,
                    indicatorWeight: 2,
                    tabs: const [
                      Tab(text: 'Overview'),
                      Tab(text: 'Timeline'),
                      Tab(text: 'Stats'),
                      Tab(text: 'Line-ups'),
                    ],
                  ),
                  Divider(height: 1, color: colorScheme.outlineVariant),
                ),
              ),
            ];
          },
          body: TabBarView(
            children: [
              // Overview tab content
              SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Match info section
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          Text(
                            'Match info',
                            style: textTheme.titleSmall?.copyWith(
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // League row
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                final leagueId =
                                    matchInfoAsync.asData?.value?.leagueId;
                                if (leagueId == null || leagueId.isEmpty) {
                                  return;
                                }
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        LeagueDetailPage(leagueId: leagueId),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 6,
                                ),
                                child: Row(
                                  children: [
                                    ClipOval(
                                      child: (() {
                                        final logoPath = matchInfoAsync
                                            .asData
                                            ?.value
                                            ?.leagueLogoPath;
                                        if (logoPath == null ||
                                            logoPath.isEmpty) {
                                          return Container(
                                            width: 24,
                                            height: 24,
                                            color: Colors.grey,
                                            child: const Icon(
                                              Icons.sports_soccer,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          );
                                        }
                                        final isNetwork =
                                            logoPath.startsWith('http://') ||
                                            logoPath.startsWith('https://');
                                        return isNetwork
                                            ? Image(
                                                image: appCachedImageProvider(logoPath),
                                                width: 24,
                                                height: 24,
                                                fit: BoxFit.cover,
                                                errorBuilder: (c, e, st) =>
                                                    Container(
                                                      width: 24,
                                                      height: 24,
                                                      color: Colors.grey,
                                                      child: const Icon(
                                                        Icons.sports_soccer,
                                                        color: Colors.white,
                                                        size: 20,
                                                      ),
                                                    ),
                                              )
                                            : Image.asset(
                                                logoPath,
                                                width: 24,
                                                height: 24,
                                                fit: BoxFit.cover,
                                                errorBuilder: (c, e, st) =>
                                                    Container(
                                                      width: 24,
                                                      height: 24,
                                                      color: Colors.grey,
                                                      child: const Icon(
                                                        Icons.sports_soccer,
                                                        color: Colors.white,
                                                        size: 20,
                                                      ),
                                                    ),
                                              );
                                      })(),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        matchInfoAsync
                                                .asData
                                                ?.value
                                                ?.leagueName ??
                                            match.leagueName ??
                                            '—',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurface,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      color: colorScheme.onSurfaceVariant,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Venue row
                          Row(
                            children: [
                              Icon(
                                Icons.stadium,
                                color: colorScheme.onSurface,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  matchInfoAsync.asData?.value?.venue ?? '—',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Referee row
                          Row(
                            children: [
                              Icon(
                                Icons.sports,
                                color: colorScheme.onSurface,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  matchInfoAsync.asData?.value?.creatorName ??
                                      '—',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          MatchOddsChips(
                            match: match,
                            lazyLoad: false,
                            showHeader: true,
                            showDisclaimer: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Pre-match H2H section
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          Text('Pre-match H2H', style: textTheme.titleSmall),
                          const SizedBox(height: 16),
                          // H2H Statistics row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Team A wins (row: logo + count)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ClipOval(
                                    child: _FixtureTeamLogo(
                                      path: match.teamA.logoPath,
                                      size: 36,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    '$teamAWins',
                                    style: textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              // Separator
                              Container(
                                width: 1,
                                height: 24,
                                color: colorScheme.outlineVariant,
                              ),
                              const SizedBox(width: 16),
                              // Draws (center value)
                              Text(
                                '$draws',
                                style: textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Separator
                              Container(
                                width: 1,
                                height: 24,
                                color: colorScheme.outlineVariant,
                              ),
                              const SizedBox(width: 16),
                              // Team B wins (row: count + logo)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$teamBWins',
                                    style: textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  ClipOval(
                                    child: _FixtureTeamLogo(
                                      path: match.teamB.logoPath,
                                      size: 36,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Recent match results - horizontal scrollable
                          SizedBox(
                            height: 40,
                            child: h2hResultsAsync.when(
                              loading: () => const Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                              error: (_, _) => Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Could not load previous results',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              data: (results) {
                                if (results.isEmpty) {
                                  return Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'No previous meetings',
                                      style: textTheme.labelSmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  );
                                }
                                return ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: results.length,
                                  itemBuilder: (context, index) {
                                    final r = results[index];
                                    final leftLogoPath =
                                        r.teamAId == match.teamA.id
                                        ? match.teamA.logoPath
                                        : match.teamB.logoPath;
                                    final rightLogoPath =
                                        r.teamBId == match.teamB.id
                                        ? match.teamB.logoPath
                                        : match.teamA.logoPath;
                                    return Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ClipOval(
                                            child: _FixtureTeamLogo(
                                              path: leftLogoPath,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            '${r.teamAScore} - ${r.teamBScore}',
                                            style: textTheme.labelSmall
                                                ?.copyWith(
                                                  color: colorScheme.onSurface,
                                                ),
                                          ),
                                          const SizedBox(width: 12),
                                          ClipOval(
                                            child: _FixtureTeamLogo(
                                              path: rightLogoPath,
                                              size: 20,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Pre-match form section
                    _PreMatchFormSection(match: match),
                    const SizedBox(height: 16),
                    // Standings section
                    _StandingsSection(match: match),
                    const SizedBox(height: 16),
                    // Featured players section
                    _FeaturedPlayersSection(match: match),
                  ],
                ),
              ),
              // Timeline tab content
              _FixtureTimelineTab(
                match: match,
                canUndo:
                    isLeagueOwner && match.status == MatchStatus.ongoing,
              ),
              // Stats tab content
              SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildFixtureStatsRatingsSections(context, match),
                    const SizedBox(height: 16),
                    _buildMatchStatsSection(context, match),
                    const SizedBox(height: 56),
                  ],
                ),
              ),
              // Line-ups tab content
              _FixtureLineupsTab(match: match),
            ],
          ),
        ),
      ),
        ),
        if (_showEditOverlay)
          _FixtureMatchEditOverlay(
            match: match,
            onClose: () => setState(() => _showEditOverlay = false),
            onSaved: () => setState(() => _showEditOverlay = false),
          ),
      ],
    );
  }

  Widget _buildFixtureStatsRatingsSections(
    BuildContext context,
    MatchModel match,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ratingsAsync = ref.watch(fixtureMatchRatingsProvider(match.id));

    Widget cardShell({required Widget child}) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(28),
        ),
        child: child,
      );
    }

    return ratingsAsync.when(
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          cardShell(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Player of the Match',
                  style: textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 24),
                const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          cardShell(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        'Top rated',
                        style: textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => showMatchPlayerRatingInfo(context),
                      icon: Icon(
                        Icons.info_outline,
                        size: 22,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      tooltip: 'How ratings work',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      error: (_, _) => cardShell(
        child: Text(
          'Could not load player ratings',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      data: (players) {
        final potm = players.isNotEmpty ? players.first : null;
        final teamARanked =
            players.where((p) => p.teamId == match.teamA.id).toList()
              ..sort((a, b) => b.rating.compareTo(a.rating));
        final teamBRanked =
            players.where((p) => p.teamId == match.teamB.id).toList()
              ..sort((a, b) => b.rating.compareTo(a.rating));
        final teamA3 = teamARanked.take(3).toList();
        final teamB3 = teamBRanked.take(3).toList();
        final topOverallRating =
            players.isEmpty ? null : players.first.rating;

        FixtureMatchRatedPlayer? slotForGridIndex(int gridIndex) {
          final row = gridIndex ~/ 2;
          if (gridIndex.isEven) {
            return row < teamA3.length ? teamA3[row] : null;
          }
          return row < teamB3.length ? teamB3[row] : null;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            cardShell(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Player of the Match',
                    style: textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (potm == null)
                    Text(
                      'Ratings appear after the match is finalized.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _potmAvatarStack(context, potm, textTheme, colorScheme),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                potm.name,
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  ClipOval(
                                    child: _FixtureTeamLogo(
                                      path: potm.teamLogoPath(match),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      potm.teamDisplayName(match),
                                      style: textTheme.labelSmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            cardShell(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          'Top rated',
                          style: textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => showMatchPlayerRatingInfo(context),
                        icon: Icon(
                          Icons.info_outline,
                          size: 22,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        tooltip: 'How ratings work',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 2.5,
                        ),
                    itemCount: 6,
                    itemBuilder: (context, index) {
                      final p = slotForGridIndex(index);
                      return _buildTopRatedPlayer(
                        context,
                        index: index,
                        match: match,
                        player: p,
                        showTopRatedStar: p != null &&
                            topOverallRating != null &&
                            p.rating == topOverallRating,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _potmAvatarStack(
    BuildContext context,
    FixtureMatchRatedPlayer potm,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    final normalizedRating = _normalizedRating(potm.rating);
    final badgeColor = _matchRatingColor(normalizedRating);
    final imagePath = potm.imageUrl?.trim();
    final hasImage = imagePath != null && imagePath.isNotEmpty;
    final isNetwork =
        hasImage &&
        (imagePath.startsWith('http://') || imagePath.startsWith('https://'));

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        CircleAvatar(
          backgroundColor: colorScheme.surfaceContainerHighest,
          child: ClipOval(
            child: SizedBox(
              width: 48,
              height: 48,
              child: hasImage
                  ? (isNetwork
                        ? Image(
                            image: appCachedImageProvider(imagePath),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Icon(
                              Icons.person,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          )
                        : Image.asset(
                            imagePath,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Icon(
                              Icons.person,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ))
                  : Icon(Icons.person, color: colorScheme.onSurfaceVariant),
            ),
          ),
        ),
        Positioned(
          bottom: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  normalizedRating.toStringAsFixed(1),
                  style: textTheme.labelSmall?.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.star, size: 12, color: Colors.black),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMatchStatsSection(BuildContext context, MatchModel match) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final statsAsync = ref.watch(matchTeamStatsProvider(match.id));

    Widget shell({required Widget child}) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(28),
        ),
        child: child,
      );
    }

    return statsAsync.when(
      loading: () => shell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Match stats',
              style: textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(),
              ),
            ),
          ],
        ),
      ),
      error: (_, _) => shell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Match stats',
              style: textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Could not load match stats',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      data: (bundle) {
        if (bundle == null) {
          return shell(
            child: Text(
              'Match stats unavailable',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        final a = bundle.teamA;
        final b = bundle.teamB;
        return shell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Match stats',
                style: textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              _buildStatRow(
                context,
                leftValue: a.goals,
                statName: 'Goals',
                rightValue: b.goals,
                highlightLeft: a.goals > b.goals,
                highlightRight: b.goals > a.goals,
              ),
              const SizedBox(height: 12),
              _buildStatRow(
                context,
                leftValue: a.shots,
                statName: 'Total shots',
                rightValue: b.shots,
                highlightLeft: a.shots > b.shots,
                highlightRight: b.shots > a.shots,
              ),
              const SizedBox(height: 12),
              _buildStatRow(
                context,
                leftValue: a.shotsOnTarget,
                statName: 'Shots on target',
                rightValue: b.shotsOnTarget,
                highlightLeft: a.shotsOnTarget > b.shotsOnTarget,
                highlightRight: b.shotsOnTarget > a.shotsOnTarget,
              ),
              const SizedBox(height: 12),
              _buildStatRow(
                context,
                leftValue: a.shotsOffTarget,
                statName: 'Shots off target',
                rightValue: b.shotsOffTarget,
                highlightLeft: a.shotsOffTarget > b.shotsOffTarget,
                highlightRight: b.shotsOffTarget > a.shotsOffTarget,
              ),
              const SizedBox(height: 12),
              _buildStatRow(
                context,
                leftValue: a.assists,
                statName: 'Assists',
                rightValue: b.assists,
                highlightLeft: a.assists > b.assists,
                highlightRight: b.assists > a.assists,
              ),
              const SizedBox(height: 12),
              _buildStatRow(
                context,
                leftValue: a.tackles,
                statName: 'Tackles',
                rightValue: b.tackles,
                highlightLeft: a.tackles > b.tackles,
                highlightRight: b.tackles > a.tackles,
              ),
              const SizedBox(height: 12),
              _buildStatRow(
                context,
                leftValue: a.saves,
                statName: 'Keeper saves',
                rightValue: b.saves,
                highlightLeft: a.saves > b.saves,
                highlightRight: b.saves > a.saves,
              ),
              const SizedBox(height: 12),
              _buildStatRow(
                context,
                leftValue: a.redCards,
                statName: 'Red cards',
                rightValue: b.redCards,
                highlightLeft: a.redCards > b.redCards,
                highlightRight: b.redCards > a.redCards,
              ),
              const SizedBox(height: 12),
              _buildStatRow(
                context,
                leftValue: a.yellowCards,
                statName: 'Yellow cards',
                rightValue: b.yellowCards,
                highlightLeft: a.yellowCards > b.yellowCards,
                highlightRight: b.yellowCards > a.yellowCards,
              ),
            ],
          ),
        );
      },
    );
  }
}

String _formatMatchDate(DateTime d) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return '${weekdays[d.weekday - 1]} ${d.day} ${months[d.month - 1]}';
}

/// Team logo for fixture (asset path or network URL).
class _FixtureTeamLogo extends StatelessWidget {
  const _FixtureTeamLogo({required this.path, this.size = 28});

  final String path;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: buildTeamLogo(
        path.isEmpty ? null : path,
        size: size,
      ),
    );
  }
}

/// Story-style tile for a clip that is still uploading.
class _MatchStoryUploadingCircle extends StatelessWidget {
  const _MatchStoryUploadingCircle({
    required this.job,
    required this.teamALogo,
    required this.teamBLogo,
    required this.onDismiss,
  });

  final VideoUploadJob job;
  final String teamALogo;
  final String teamBLogo;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const width = 110.0;
    const previewHeight = 88.0;
    final thumb = job.thumbnailBytes;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: job.isFailed ? onDismiss : null,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: width,
                height: previewHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.65),
                    width: 1.4,
                  ),
                  color: colorScheme.surface,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (thumb != null && thumb.isNotEmpty)
                        Positioned.fill(
                          child: Image.memory(thumb, fit: BoxFit.cover),
                        )
                      else
                        Positioned.fill(
                          child: Row(
                            children: [
                              Expanded(
                                child: ColoredBox(
                                  color: colorScheme.surfaceContainerHigh,
                                  child: Center(
                                    child: _FixtureTeamLogo(
                                      path: teamALogo,
                                      size: 30,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: ColoredBox(
                                  color: colorScheme.surfaceContainer,
                                  child: Center(
                                    child: _FixtureTeamLogo(
                                      path: teamBLogo,
                                      size: 30,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      VideoUploadProgressOverlay(job: job, compact: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                job.isFailed ? 'Failed' : 'Uploading',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                job.isFailed ? 'Tap to dismiss' : 'Just now',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular story-style tile for a match video (Instagram/Snapchat style).
/// Shows team A and team B logos with a diagonal separator and a ring border.
class _MatchStoryCircle extends StatelessWidget {
  const _MatchStoryCircle({
    required this.url,
    required this.teamALogo,
    required this.teamBLogo,
    this.uploaderName,
    this.uploaderImageUrl,
    this.addedAt,
  });

  final String url;
  final String teamALogo;
  final String teamBLogo;
  final String? uploaderName;
  final String? uploaderImageUrl;
  final DateTime? addedAt;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const width = 110.0;
    const previewHeight = 88.0;
    final uploaderLabel = (uploaderName == null || uploaderName!.trim().isEmpty)
        ? 'Unknown'
        : uploaderName!.trim();
    final resolvedUploaderImage = _resolveUploaderImage(uploaderImageUrl);
    final uploaderHasImage = resolvedUploaderImage != null;
    final uploaderIsNetwork = uploaderHasImage &&
        (resolvedUploaderImage.startsWith('http://') ||
            resolvedUploaderImage.startsWith('https://'));
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _MatchVideoPlayerPage(videoUrl: url),
            ),
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: width,
                height: previewHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.65),
                    width: 1.4,
                  ),
                  color: colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              color: colorScheme.surfaceContainerHigh,
                              child: Center(
                                child: _FixtureTeamLogo(path: teamALogo, size: 30),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              color: colorScheme.surfaceContainer,
                              child: Center(
                                child: _FixtureTeamLogo(path: teamBLogo, size: 30),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          height: 28,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.0),
                                Colors.black.withValues(alpha: 0.5),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Center(
                        child: Icon(
                          Icons.play_circle_fill_rounded,
                          size: 30,
                          color: Colors.white,
                        ),
                      ),
                      Positioned(
                        left: 8,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Highlight',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    child: ClipOval(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: uploaderHasImage
                            ? (uploaderIsNetwork
                                ? Image(
                                    image: appCachedImageProvider(resolvedUploaderImage),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => _uploaderInitial(
                                      context,
                                      uploaderLabel,
                                      colorScheme,
                                    ),
                                  )
                                : Image.asset(
                                    resolvedUploaderImage,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => _uploaderInitial(
                                      context,
                                      uploaderLabel,
                                      colorScheme,
                                    ),
                                  ))
                            : _uploaderInitial(context, uploaderLabel, colorScheme),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      uploaderLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                _formatVideoAddedTime(addedAt),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _resolveUploaderImage(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }
  if (value.startsWith('lib/assets/') || value.startsWith('assets/')) {
    return value;
  }
  // Stored as a bucket path/key (e.g. onboarding/profile uploads).
  return Supabase.instance.client.storage.from('Profile images').getPublicUrl(value);
}

Widget _uploaderInitial(
  BuildContext context,
  String uploaderLabel,
  ColorScheme colorScheme,
) {
  return Center(
    child: Text(
      uploaderLabel.isNotEmpty ? uploaderLabel[0].toUpperCase() : '?',
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurfaceVariant,
          ),
    ),
  );
}

String _formatVideoAddedTime(DateTime? addedAt) {
  if (addedAt == null) return 'Added recently';
  final diff = DateTime.now().difference(addedAt.toLocal());
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  final d = addedAt.toLocal();
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  final hh = d.hour.toString().padLeft(2, '0');
  final mi = d.minute.toString().padLeft(2, '0');
  return '$dd/$mm $hh:$mi';
}

bool _isGoalEventType(String eventType) {
  final normalized = eventType
      .trim()
      .toLowerCase()
      .replaceAll('-', '_')
      .replaceAll(' ', '_');
  return normalized == 'goal' ||
      normalized == 'own_goal' ||
      normalized == 'penalty_goal';
}

/// Full-screen video player for a single match video (reels-style).
class _MatchVideoPlayerPage extends StatefulWidget {
  const _MatchVideoPlayerPage({required this.videoUrl});

  final String videoUrl;

  @override
  State<_MatchVideoPlayerPage> createState() => _MatchVideoPlayerPageState();
}

class _MatchVideoPlayerPageState extends State<_MatchVideoPlayerPage>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _isPlaying = false;
  bool _isPageActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _createController();
  }

  Future<void> _createController() async {
    try {
      // Reuses the shared video disk cache; plays a local file when the clip
      // was cached before instead of re-streaming it.
      final controller = await createExploreVideoController(
        videoUrl: widget.videoUrl,
        videoId: widget.videoUrl,
        cacheManager: AppVideoCache.instance.cacheManager,
      );
      if (!mounted || !_isPageActive) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      await controller.initialize();
      if (!mounted || !_isPageActive) return;
      setState(() {
        _initialized = true;
        _isPlaying = true;
      });
      controller.play();
      controller.setLooping(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not load video')));
    }
  }

  @override
  void dispose() {
    _isPageActive = false;
    _pauseVideo();
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _pauseVideo();
    }
  }

  void _pauseVideo() {
    final controller = _controller;
    if (_initialized && controller != null && controller.value.isPlaying) {
      controller.pause();
    }
    _isPlaying = false;
  }

  void _handleBack() {
    _pauseVideo();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _togglePlay() {
    final controller = _controller;
    if (!_initialized || !_isPageActive || controller == null) return;
    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
        _isPlaying = false;
      } else {
        controller.play();
        _isPlaying = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: _initialized && _controller != null
                ? GestureDetector(
                    onTap: _togglePlay,
                    child: AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    ),
                  )
                : const CircularProgressIndicator(),
          ),
          SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: _handleBack,
                ),
              ],
            ),
          ),
          if (_initialized)
            Positioned(
              right: 16,
              bottom: 32,
              child: IconButton(
                iconSize: 36,
                icon: Icon(
                  _isPlaying ? Icons.pause_circle_filled : Icons.play_circle,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                onPressed: _togglePlay,
              ),
            ),
          Positioned(
            left: 16,
            bottom: 32,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sports_soccer,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Match highlight',
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular add button for adding a new match video (story-style row).
class _MatchStoryAddButton extends StatelessWidget {
  const _MatchStoryAddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const width = 110.0;
    const height = 88.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.surfaceContainerHighest,
                colorScheme.surfaceContainerHigh,
              ],
            ),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_rounded,
                  size: 22,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add clip',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Green pill with stopwatch shown when match is upcoming. Tappable to set timer.
class _BuildUpcomingPill extends StatelessWidget {
  const _BuildUpcomingPill({required this.match, required this.onTap});

  final MatchModel match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF00FF5A).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF00FF5A), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timer_outlined,
                size: 18,
                color: const Color(0xFF00FF5A),
              ),
              const SizedBox(width: 6),
              Text(
                _formatMatchDate(match.matchDate),
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.touch_app,
                size: 14,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pill showing clock when match is ongoing. Green normally, red when past half target.
/// Plays sound and haptics when transitioning to red (stoppage time).
class _BuildOngoingPill extends ConsumerStatefulWidget {
  const _BuildOngoingPill({
    required this.match,
    required this.clock,
    required this.clockLabel,
    required this.matchId,
  });

  final MatchModel match;
  final Duration clock;
  final String clockLabel;
  final String matchId;

  @override
  ConsumerState<_BuildOngoingPill> createState() => _BuildOngoingPillState();
}

class _BuildOngoingPillState extends ConsumerState<_BuildOngoingPill> {
  bool _hasTriggeredStoppageAlert = false;

  void _triggerStoppageAlert() {
    playStoppageAlert();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final config = ref.watch(matchTimerConfigProvider(widget.matchId));
    final isStoppageTime = config.isPastTarget(widget.clock);

    if (isStoppageTime) {
      if (!_hasTriggeredStoppageAlert) {
        _hasTriggeredStoppageAlert = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _triggerStoppageAlert();
        });
      }
    } else {
      _hasTriggeredStoppageAlert = false;
    }

    const greenColor = Color(0xFF00FF5A);
    final pillColor = isStoppageTime
        ? Colors.red.withValues(alpha: 0.2)
        : greenColor.withValues(alpha: 0.2);
    final borderColor = isStoppageTime ? Colors.red : greenColor;
    final textColor = isStoppageTime ? Colors.red : greenColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: pillColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Text(
        widget.match.status == MatchStatus.ongoing
            ? widget.clockLabel
            : widget.match.statusText,
        style: textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: isStoppageTime ? FontWeight.bold : null,
        ),
      ),
    );
  }
}

class _SetTimerDialog extends StatefulWidget {
  const _SetTimerDialog({this.initialMinutes = 45});

  final int initialMinutes;

  @override
  State<_SetTimerDialog> createState() => _SetTimerDialogState();
}

class _SetTimerDialogState extends State<_SetTimerDialog> {
  late int? _selectedMinutes;
  late TextEditingController _customController;

  @override
  void initState() {
    super.initState();
    _selectedMinutes = widget.initialMinutes;
    _customController = TextEditingController();
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  int? get _effectiveMinutes {
    final custom = int.tryParse(_customController.text);
    if (custom != null && custom >= 1 && custom <= 120) return custom;
    return _selectedMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    const presets = [30, 40, 45, 60];

    return AlertDialog(
      title: const Text('Timer per half'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set the duration for each half (minutes). '
            'When time is up, the clock turns red for stoppage time.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: presets.map((m) {
              final isSelected =
                  _selectedMinutes == m && _customController.text.isEmpty;
              return ChoiceChip(
                label: Text('$m min'),
                selected: isSelected,
                onSelected: (s) => setState(() {
                  _selectedMinutes = s ? m : widget.initialMinutes;
                  _customController.clear();
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Custom:',
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _customController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'min',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onChanged: (_) => setState(() {
                    // Clear preset selection when typing custom
                    if (_customController.text.isNotEmpty) {
                      _selectedMinutes = null;
                    } else {
                      _selectedMinutes = widget.initialMinutes;
                    }
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Skip'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(_effectiveMinutes ?? widget.initialMinutes),
          child: const Text('Set'),
        ),
      ],
    );
  }
}

class _FixtureLineupsTab extends StatefulWidget {
  const _FixtureLineupsTab({required this.match});

  final MatchModel match;

  @override
  State<_FixtureLineupsTab> createState() => _FixtureLineupsTabState();
}

class _FixtureLineupsTabState extends State<_FixtureLineupsTab>
    with SingleTickerProviderStateMixin {
  late final TabController _teamTabController;

  @override
  void initState() {
    super.initState();
    _teamTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _teamTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final teamALabel = widget.match.teamA.teamName?.trim().isNotEmpty == true
        ? widget.match.teamA.teamName!.trim()
        : 'Team A';
    final teamBLabel = widget.match.teamB.teamName?.trim().isNotEmpty == true
        ? widget.match.teamB.teamName!.trim()
        : 'Team B';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: colorScheme.surface,
          child: TabBar.secondary(
            controller: _teamTabController,
            labelColor: colorScheme.onSurface,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            indicatorColor: colorScheme.primary,
            indicatorWeight: 2,
            tabs: [
              Tab(text: teamALabel),
              Tab(text: teamBLabel),
            ],
          ),
        ),
        Divider(height: 1, color: colorScheme.outlineVariant),
        Expanded(
          child: TabBarView(
            controller: _teamTabController,
            children: [
              _FixtureTeamLineupPanel(match: widget.match, isTeamA: true),
              _FixtureTeamLineupPanel(match: widget.match, isTeamA: false),
            ],
          ),
        ),
      ],
    );
  }
}

class _FixtureTeamLineupPanel extends ConsumerWidget {
  const _FixtureTeamLineupPanel({
    required this.match,
    required this.isTeamA,
  });

  final MatchModel match;
  final bool isTeamA;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lineupAsync = ref.watch(
      fixtureMatchLineupProvider(
        FixtureMatchLineupRequest(matchId: match.id, isTeamA: isTeamA),
      ),
    );
    final showLiveStats = match.status != MatchStatus.upcoming;
    final playerStatsById = showLiveStats
        ? ref.watch(lineupPlayerStatsProvider(match.id))
        : const <String, LineupPlayerMatchStats>{};

    return lineupAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not load lineup',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      ),
      data: (data) {
        if (data.layout.players.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                match.status == MatchStatus.upcoming
                    ? 'No squad layout saved for this team yet.'
                    : 'No lineup was saved before this match started.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ),
          );
        }

        return SingleChildScrollView(
          child: SquadPitchView(
            layout: data.layout,
            members: data.members,
            captainId: data.captainId,
            playerStatsById: playerStatsById,
            onPlayerTap: (playerId) {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PlayerProfilePage(playerId: playerId),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _FixtureSliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  _FixtureSliverTabBarDelegate(this.tabBar, this.bottomDivider);

  final TabBar tabBar;
  final Divider bottomDivider;

  @override
  double get minExtent => tabBar.preferredSize.height + 1;

  @override
  double get maxExtent => tabBar.preferredSize.height + 1;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: tabBar,
        ),
        bottomDivider,
      ],
    );
  }

  @override
  bool shouldRebuild(covariant _FixtureSliverTabBarDelegate oldDelegate) {
    return false;
  }
}

class _PreMatchFormSection extends ConsumerStatefulWidget {
  const _PreMatchFormSection({required this.match});

  final MatchModel match;

  @override
  ConsumerState<_PreMatchFormSection> createState() =>
      _PreMatchFormSectionState();
}

class _PreMatchFormSectionState extends ConsumerState<_PreMatchFormSection> {
  bool _showLeftersForm = false;
  bool _showGalacticosForm = false;

  String _formLabel(_TeamFormMatchResult result, String teamId) {
    final goalsFor = result.homeTeamId == teamId
        ? result.homeScore
        : result.awayScore;
    final goalsAgainst = result.homeTeamId == teamId
        ? result.awayScore
        : result.homeScore;
    if (goalsFor > goalsAgainst) return 'W';
    if (goalsFor < goalsAgainst) return 'L';
    return 'D';
  }

  Widget _buildTeamFormRow(
    BuildContext context, {
    required String teamId,
    required String teamName,
    required bool expanded,
    required VoidCallback onToggle,
    required List<_TeamFormMatchResult> results,
    required Map<String, String> logosByTeamId,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final labels = results.map((r) => _formLabel(r, teamId)).toList();
    final paddedLabels = labels.length >= 5
        ? labels.take(5).toList()
        : [...labels, ...List.filled(5 - labels.length, '—')];

    Color chipColor(String value) {
      if (value == 'W') return Colors.green;
      if (value == 'L') return Colors.red;
      return colorScheme.outlineVariant;
    }

    Color? chipTextColor(String value) {
      if (value == 'D' || value == '—') return colorScheme.onSurfaceVariant;
      return null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              teamName,
              style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            for (var i = 0; i < paddedLabels.length; i++) ...[
              _buildFormChip(
                context,
                label: paddedLabels[i],
                color: chipColor(paddedLabels[i]),
                textColor: chipTextColor(paddedLabels[i]),
              ),
              if (i != paddedLabels.length - 1) const SizedBox(width: 4),
            ],
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: onToggle,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (expanded)
          SizedBox(
            height: 40,
            child: results.isEmpty
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'No recent completed matches',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final r = results[index];
                      return _buildFormMatchPill(
                        context,
                        homeLogo: logosByTeamId[r.homeTeamId] ?? '',
                        score: '${r.homeScore} - ${r.awayScore}',
                        awayLogo: logosByTeamId[r.awayTeamId] ?? '',
                      );
                    },
                  ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final formAsync = ref.watch(fixtureTeamFormProvider(widget.match.id));
    final formData = formAsync.asData?.value;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pre-match form', style: textTheme.titleSmall),
          const SizedBox(height: 16),
          if (formAsync.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          _buildTeamFormRow(
            context,
            teamId: widget.match.teamA.id,
            teamName: widget.match.teamA.displayName,
            expanded: _showLeftersForm,
            onToggle: () {
              setState(() {
                _showLeftersForm = !_showLeftersForm;
              });
            },
            results: formData?.teamARecent ?? const [],
            logosByTeamId: formData?.logoByTeamId ?? const {},
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: colorScheme.outlineVariant),
          const SizedBox(height: 8),
          _buildTeamFormRow(
            context,
            teamId: widget.match.teamB.id,
            teamName: widget.match.teamB.displayName,
            expanded: _showGalacticosForm,
            onToggle: () {
              setState(() {
                _showGalacticosForm = !_showGalacticosForm;
              });
            },
            results: formData?.teamBRecent ?? const [],
            logosByTeamId: formData?.logoByTeamId ?? const {},
          ),
        ],
      ),
    );
  }
}

class _StandingsSection extends ConsumerWidget {
  const _StandingsSection({required this.match});

  final MatchModel match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final standingsAsync = ref.watch(fixtureStandingsProvider(match.id));
    final standings = standingsAsync.asData?.value;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Standings', style: textTheme.titleSmall),
          const SizedBox(height: 12),
          // Header row
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    'Pos',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Team',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    'PL',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    'GD',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    'Pts',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (standingsAsync.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (standingsAsync.hasError)
            Text(
              'Could not load standings',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            _buildStandingRow(
              context,
              position: standings?.teamA?.position ?? 0,
              shortName:
                  standings?.teamA?.teamShortName ?? match.teamA.displayName,
              logoPath: standings?.teamA?.logoPath ?? match.teamA.logoPath,
              played: standings?.teamA?.played ?? 0,
              goalDiff: standings?.teamA?.goalDiff ?? 0,
              points: standings?.teamA?.points ?? 0,
            ),
            const SizedBox(height: 4),
            _buildStandingRow(
              context,
              position: standings?.teamB?.position ?? 0,
              shortName:
                  standings?.teamB?.teamShortName ?? match.teamB.displayName,
              logoPath: standings?.teamB?.logoPath ?? match.teamB.logoPath,
              played: standings?.teamB?.played ?? 0,
              goalDiff: standings?.teamB?.goalDiff ?? 0,
              points: standings?.teamB?.points ?? 0,
            ),
          ],
        ],
      ),
    );
  }
}

class _FeaturedPlayersSection extends ConsumerWidget {
  const _FeaturedPlayersSection({required this.match});

  final MatchModel match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final featuredAsync = ref.watch(fixtureFeaturedPlayersProvider(match.id));
    final featured = featuredAsync.asData?.value;
    final teamAPlayer = featured?.teamAPlayer;
    final teamBPlayer = featured?.teamBPlayer;
    final year = DateTime.now().year;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Featured players', style: textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Based on past performance',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          if (featuredAsync.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildFeaturedPlayer(
                  context,
                  name: teamAPlayer?.name ?? '—',
                  rating: teamAPlayer?.rating,
                  avatarPath: teamAPlayer?.imageUrl,
                ),
                Text(
                  'VS',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                _buildFeaturedPlayer(
                  context,
                  name: teamBPlayer?.name ?? '—',
                  rating: teamBPlayer?.rating,
                  avatarPath: teamBPlayer?.imageUrl,
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          // Radar chart
          SizedBox(
            height: 220,
            child: teamAPlayer != null && teamBPlayer != null
                ? PerformanceRadarChart(
                    playerId: teamAPlayer.playerId,
                    comparePlayerId: teamBPlayer.playerId,
                    year: year,
                    primaryLabel: teamAPlayer.name,
                    compareLabel: teamBPlayer.name,
                  )
                : Center(
                    child: Text(
                      'Not enough previous-match player ratings to compare',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

Widget _buildStandingRow(
  BuildContext context, {
  required int position,
  required String shortName,
  required String logoPath,
  required int played,
  required int goalDiff,
  required int points,
}) {
  final textTheme = Theme.of(context).textTheme;
  final colorScheme = Theme.of(context).colorScheme;

  return Padding(
    padding: const EdgeInsets.only(right: 8.0),
    child: Row(
      children: [
        SizedBox(
          width: 32,
          child: Text(
            position > 0 ? '$position' : '—',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            children: [
              ClipOval(child: _FixtureTeamLogo(path: logoPath, size: 20)),
              const SizedBox(width: 8),
              Text(
                shortName,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '$played',
            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '$goalDiff',
            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '$points',
            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    ),
  );
}

Widget _buildFeaturedPlayer(
  BuildContext context, {
  required String name,
  required double? rating,
  String? avatarPath,
}) {
  final textTheme = Theme.of(context).textTheme;
  final colorScheme = Theme.of(context).colorScheme;
  final normalized = _normalizedRating(rating);
  final badgeColor = _matchRatingColor(normalized);
  final imagePath = avatarPath?.trim();
  final hasImage = imagePath != null && imagePath.isNotEmpty;
  final isNetwork =
      hasImage &&
      (imagePath.startsWith('http://') || imagePath.startsWith('https://'));

  return Column(
    children: [
      Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            backgroundColor: colorScheme.surfaceContainerHighest,
            child: ClipOval(
              child: SizedBox(
                width: 56,
                height: 56,
                child: hasImage
                    ? (isNetwork
                          ? Image(
                              image: appCachedImageProvider(imagePath),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Icon(
                                Icons.person,
                                size: 28,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            )
                          : Image.asset(
                              imagePath,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Icon(
                                Icons.person,
                                size: 28,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ))
                    : Icon(
                        Icons.person,
                        size: 28,
                        color: colorScheme.onSurfaceVariant,
                      ),
              ),
            ),
          ),
          Positioned(
            bottom: -10,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 2.0,
              ),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                normalized.toStringAsFixed(1),
                style: textTheme.labelSmall?.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Text(
        name,
        style: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  );
}

Widget _buildFormChip(
  BuildContext context, {
  required String label,
  required Color color,
  Color? textColor,
}) {
  final textTheme = Theme.of(context).textTheme;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: Center(
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          color: textColor ?? Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

Widget _buildFormMatchPill(
  BuildContext context, {
  required String homeLogo,
  required String score,
  required String awayLogo,
}) {
  final textTheme = Theme.of(context).textTheme;
  final colorScheme = Theme.of(context).colorScheme;

  return Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    decoration: BoxDecoration(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipOval(child: _FixtureTeamLogo(path: homeLogo, size: 20)),
        const SizedBox(width: 12),
        Text(
          score,
          style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurface),
        ),
        const SizedBox(width: 12),
        ClipOval(child: _FixtureTeamLogo(path: awayLogo, size: 20)),
      ],
    ),
  );
}

void showMatchPlayerRatingInfo(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final colorScheme = Theme.of(ctx).colorScheme;
      final textTheme = Theme.of(ctx).textTheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How match ratings work',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Ratings are on a 0–10 scale (one decimal). Everyone starts from '
                  'a baseline of 6.0. When the match is finalized, events recorded in '
                  'the match feed are rolled into your stats and your rating is computed.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'What usually raises your rating',
                  style: textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Goals — strong positive; also count as a shot and an on-target shot.\n'
                  '• Assists — solid positive; weighted higher for forwards and midfielders.\n'
                  '• Shots — total shots matter; on-target vs off-target affects how much '
                  'they help (saved attempts count as on target).\n'
                  '• Tackles — help defenders and midfielders more than forwards.\n'
                  '• Saves — help goalkeepers.\n'
                  '• Clean sheet — bonus after enough minutes played; biggest for keepers '
                  'and defenders.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'What usually lowers your rating',
                  style: textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Yellow cards — moderate penalty.\n'
                  '• Red cards — large penalty.\n'
                  '• Goals conceded — each goal against your team costs rating (scaled by '
                  'your minutes on the pitch); bench players are not charged. Keepers and '
                  'defenders lose the most per goal.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Minutes on the pitch',
                  style: textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'More minutes generally mean your stats influence the final rating more. '
                  'If minutes are still low or not updated, recorded events (goals, cards, '
                  'shots, tackles, saves) can still move your rating.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Top rated grid: indices 0,2,4 = team A (left column); 1,3,5 = team B (right).
/// Matches the original placeholder layout; [player] null shows the same shell with dashes.
/// [showTopRatedStar] marks the match-wide best rating (ties all get the star).
Widget _buildTopRatedPlayer(
  BuildContext context, {
  required int index,
  required MatchModel match,
  FixtureMatchRatedPlayer? player,
  bool showTopRatedStar = false,
}) {
  final textTheme = Theme.of(context).textTheme;
  final colorScheme = Theme.of(context).colorScheme;
  final isLefters = index.isEven;
  final teamLogoPath = isLefters ? match.teamA.logoPath : match.teamB.logoPath;

  final Widget avatarStack;
  if (player != null) {
    final rating = _normalizedRating(player.rating);
    final badgeColor = _matchRatingColor(rating);
    final posLabel = player.position?.trim().isNotEmpty == true
        ? player.position!
        : '—';
    final imagePath = player.imageUrl?.trim();
    final hasImage = imagePath != null && imagePath.isNotEmpty;
    final isNetwork =
        hasImage &&
        (imagePath.startsWith('http://') || imagePath.startsWith('https://'));

    avatarStack = Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        CircleAvatar(
          backgroundColor: colorScheme.surfaceContainerHighest,
          child: ClipOval(
            child: SizedBox(
              width: 48,
              height: 48,
              child: hasImage
                  ? (isNetwork
                        ? Image(
                            image: appCachedImageProvider(imagePath),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Icon(
                              Icons.person,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          )
                        : Image.asset(
                            imagePath,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Icon(
                              Icons.person,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ))
                  : Icon(Icons.person, color: colorScheme.onSurfaceVariant),
            ),
          ),
        ),
        Positioned(
          top: -4,
          left: isLefters ? -4 : null,
          right: !isLefters ? -4 : null,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: colorScheme.surfaceContainerHigh,
                width: 2,
              ),
            ),
            child: ClipOval(
              child: _FixtureTeamLogo(path: teamLogoPath, size: 18),
            ),
          ),
        ),
        Positioned(
          bottom: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  rating.toStringAsFixed(1),
                  style: textTheme.labelSmall?.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (showTopRatedStar) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.star, size: 12, color: Colors.black),
                ],
              ],
            ),
          ),
        ),
      ],
    );

    final namePositionColumn = Column(
      crossAxisAlignment: isLefters
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          player.name,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
          textAlign: isLefters ? TextAlign.left : TextAlign.right,
        ),
        const SizedBox(height: 4),
        Text(
          posLabel,
          style: textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: isLefters ? TextAlign.left : TextAlign.right,
        ),
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: isLefters
          ? [
              avatarStack,
              const SizedBox(width: 12),
              Expanded(child: namePositionColumn),
            ]
          : [
              Expanded(child: namePositionColumn),
              const SizedBox(width: 16),
              avatarStack,
            ],
    );
  }

  // Placeholder slot (original mock styling): asset avatar + team badge + dash rating.
  avatarStack = Stack(
    clipBehavior: Clip.none,
    alignment: Alignment.center,
    children: [
      CircleAvatar(
        backgroundColor: colorScheme.surfaceContainerHighest,
        backgroundImage: AssetImage(AppAssets.avatar1),
      ),
      Positioned(
        top: -4,
        left: isLefters ? -4 : null,
        right: !isLefters ? -4 : null,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: colorScheme.surfaceContainerHigh,
              width: 2,
            ),
          ),
          child: ClipOval(
            child: _FixtureTeamLogo(path: teamLogoPath, size: 18),
          ),
        ),
      ),
      Positioned(
        bottom: -4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
          decoration: BoxDecoration(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '—',
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ],
  );

  final namePositionColumn = Column(
    crossAxisAlignment: isLefters
        ? CrossAxisAlignment.start
        : CrossAxisAlignment.end,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '—',
        style: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
        textAlign: isLefters ? TextAlign.left : TextAlign.right,
      ),
      const SizedBox(height: 4),
      Text(
        '—',
        style: textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        textAlign: isLefters ? TextAlign.left : TextAlign.right,
      ),
    ],
  );

  return Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: isLefters
        ? [
            avatarStack,
            const SizedBox(width: 12),
            Expanded(child: namePositionColumn),
          ]
        : [
            Expanded(child: namePositionColumn),
            const SizedBox(width: 16),
            avatarStack,
          ],
  );
}

Widget _buildStatRow(
  BuildContext context, {
  required num leftValue,
  required String statName,
  required num rightValue,
  bool highlightLeft = false,
  bool highlightRight = false,
  bool isDecimal = false,
}) {
  final textTheme = Theme.of(context).textTheme;
  final colorScheme = Theme.of(context).colorScheme;

  String formatValue(num value) {
    if (isDecimal) {
      return value.toStringAsFixed(1);
    }
    return value.toString();
  }

  Widget buildValue(num value, bool highlight) {
    final text = Text(
      formatValue(value),
      style: textTheme.bodySmall?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.bold,
      ),
    );

    if (highlight) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.lightBlueAccent.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(999),
        ),
        child: text,
      );
    }

    return text;
  }

  return Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      // Left value
      SizedBox(
        width: 60,
        child: Align(
          alignment: Alignment.centerLeft,
          child: buildValue(leftValue, highlightLeft),
        ),
      ),
      // Stat name (centered)
      Expanded(
        child: Text(
          statName,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ),
      // Right value
      SizedBox(
        width: 60,
        child: Align(
          alignment: Alignment.centerRight,
          child: buildValue(rightValue, highlightRight),
        ),
      ),
    ],
  );
}

bool _fixturePickerIsGoalkeeper(String position) {
  final t = position.trim().toLowerCase();
  return t == 'goalkeeper' || t == 'gk' || t.contains('goalkeeper');
}

class _MatchControlsModal extends ConsumerStatefulWidget {
  const _MatchControlsModal({required this.matchId});

  final String matchId;

  @override
  ConsumerState<_MatchControlsModal> createState() =>
      _MatchControlsModalState();
}

class _MatchControlsModalState extends ConsumerState<_MatchControlsModal> {
  bool _isHalfTime = true;
  bool _isUpdating = false;
  MatchStatus? _overrideStatus;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final asyncMatch = ref.watch(fixtureMatchProvider(widget.matchId));

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          asyncMatch.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(child: Text('Could not load match controls')),
            ),
            data: (match) {
              if (match == null) {
                return const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: Text('Match not found')),
                );
              }
              final status = _overrideStatus ?? match.status;
              return _buildControlsForStatus(
                context,
                colorScheme,
                status,
                match,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildControlsForStatus(
    BuildContext context,
    ColorScheme colorScheme,
    MatchStatus status,
    MatchModel match,
  ) {
    switch (status) {
      case MatchStatus.upcoming:
        return _buildPrimaryActionButton(
          context,
          label: 'Start match',
          onTap: _isUpdating
              ? null
              : () => _changeStatus(MatchStatus.ongoing, resetResumed: true),
        );
      case MatchStatus.halfTime:
        return _buildPrimaryActionButton(
          context,
          label: 'Resume match',
          onTap: _isUpdating
              ? null
              : () => _changeStatus(MatchStatus.ongoing, markResumed: true),
        );
      case MatchStatus.ongoing:
      case MatchStatus.fullTime:
        final allDisabled = status == MatchStatus.fullTime || _isUpdating;
        final timerConfig = ref.watch(matchTimerConfigProvider(widget.matchId));
        final disableHalfTime =
            status == MatchStatus.fullTime || timerConfig.hasReachedHalfTime;
        final textTheme = Theme.of(context).textTheme;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Clear indicator when match has ended — stat tracking is disabled
            if (status == MatchStatus.fullTime) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Material(
                  color: colorScheme.tertiaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.flag,
                          color: colorScheme.onTertiaryContainer,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Full-time',
                                style: textTheme.titleSmall?.copyWith(
                                  color: colorScheme.onTertiaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Match ended — stat tracking is disabled',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onTertiaryContainer
                                      .withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            // Match period selector
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildPeriodButton(
                      context,
                      icon: Icons.pause,
                      label: 'Half-time',
                      isActive: _isHalfTime,
                      backgroundColor: colorScheme.secondaryContainer,
                      foregroundColor: colorScheme.onSecondaryContainer,
                      onTap: (!allDisabled && !disableHalfTime)
                          ? () {
                              setState(() => _isHalfTime = true);
                              _changeStatus(MatchStatus.halfTime);
                            }
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPeriodButton(
                      context,
                      icon: Icons.stop,
                      label: 'Full-time',
                      isActive: !_isHalfTime,
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      onTap: (!allDisabled && status != MatchStatus.fullTime)
                          ? () {
                              setState(() => _isHalfTime = false);
                              _changeStatus(MatchStatus.fullTime);
                            }
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Event controls grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildEventGrid(
                        context,
                        match: match,
                        isLeftTeam: true,
                        enabled: !allDisabled,
                      ),
                    ),
                    const SizedBox(width: 12),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildEventGrid(
                        context,
                        match: match,
                        isLeftTeam: false,
                        enabled: !allDisabled,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
    }
  }

  Widget _buildPrimaryActionButton(
    BuildContext context, {
    required String label,
    required VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Center(
        child: SizedBox(
          width: double.infinity,
          height: 96 * AppResponsive.layoutScaleOf(context),
          child: Material(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(48),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(48),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.sports, // whistle icon
                      color: colorScheme.onPrimaryContainer,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      label,
                      style: textTheme.headlineSmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _changeStatus(
    MatchStatus newStatus, {
    bool markResumed = false,
    bool resetResumed = false,
  }) async {
    if (_isUpdating) return;
    setState(() {
      _isUpdating = true;
    });

    try {
      final repo = ref.read(matchesRepositoryProvider);
      if (newStatus == MatchStatus.ongoing) {
        await repo.initializeMatchStatsViaRpc(widget.matchId);
      }
      await repo.updateMatchStatus(widget.matchId, newStatus);
      if (newStatus == MatchStatus.fullTime) {
        await repo.finalizeMatchViaRpc(widget.matchId);
      }

      final clock = ref.read(matchTimerAdapterProvider(widget.matchId).notifier);
      final timerConfig = ref.read(
        matchTimerConfigProvider(widget.matchId).notifier,
      );
      switch (newStatus) {
        case MatchStatus.upcoming:
          clock.reset();
          timerConfig.reset();
          break;
        case MatchStatus.ongoing:
          if (resetResumed) {
            clock.reset();
            // Keep timer config (half duration) - don't reset
          }
          await clock.start();
          break;
        case MatchStatus.halfTime:
          ref
              .read(serverSyncedMatchClockProvider(widget.matchId).notifier)
              .captureHalftimePause();
          clock.pause();
          timerConfig.markHalfTimeReached();
          break;
        case MatchStatus.fullTime:
          clock.pause();
          timerConfig.reset();
          break;
      }

      final matchSnap = ref.read(fixtureMatchProvider(widget.matchId));
      final leagueIdForProgress = matchSnap.asData?.value?.leagueId;
      ref.invalidate(matchesProvider);
      ref.invalidate(fixtureMatchProvider(widget.matchId));
      ref.invalidate(matchEventsProvider(widget.matchId));
      ref.invalidate(matchTeamStatsProvider(widget.matchId));
      ref.invalidate(fixtureMatchRatingsProvider(widget.matchId));
      if (leagueIdForProgress != null && leagueIdForProgress.isNotEmpty) {
        ref.invalidate(leagueSeasonFixtureProgressProvider(leagueIdForProgress));
      }

      setState(() {
        _overrideStatus = newStatus;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  /// Squad picker used by cards, shots, substitutions, etc.
  Future<MatchSquadPitchState?> _pitchStateForTeam(
    MatchModel match,
    bool isTeamA,
  ) async {
    try {
      final lineupData = await ref.read(
        fixtureMatchLineupProvider(
          FixtureMatchLineupRequest(
            matchId: widget.matchId,
            isTeamA: isTeamA,
          ),
        ).future,
      );
      if (lineupData.layout.players.isEmpty) return null;

      final events = await ref.read(matchEventsProvider(widget.matchId).future);
      final teamId = isTeamA ? match.teamA.id : match.teamB.id;
      return MatchSquadPitchState.fromLineupAndEvents(
        layout: lineupData.layout,
        events: events,
        teamId: teamId.isEmpty ? null : teamId,
      );
    } catch (_) {
      return null;
    }
  }

  List<FixturePickerPlayer> _filterSquadByPitch({
    required List<FixturePickerPlayer> squad,
    required MatchSquadPitchState? pitchState,
    required bool onPitch,
    Set<String> excludeIds = const {},
  }) {
    var list = squad.where((p) => !excludeIds.contains(p.id));
    final hasLineup =
        pitchState != null &&
        (pitchState.onPitch.isNotEmpty || pitchState.onBench.isNotEmpty);
    if (!hasLineup) {
      return onPitch ? list.toList() : <FixturePickerPlayer>[];
    }
    return list
        .where(
          (p) => onPitch
              ? pitchState.isOnPitch(p.id)
              : pitchState.isOnBench(p.id),
        )
        .toList();
  }

  Future<FixturePickerPlayer?> _pickSquadPlayerForMatchControl(
    BuildContext context,
    MatchModel match,
    bool isTeamA, {
    required String title,
    Set<String> excludePlayerIds = const {},
    bool Function(FixturePickerPlayer p)? includeIf,
    bool? onPitch,
  }) async {
    final team = isTeamA ? match.teamA : match.teamB;
    List<FixturePickerPlayer> players = [];
    if (team.id.isNotEmpty) {
      final teamsRepo = ref.read(teamsRepositoryProvider);
      players = await teamsRepo.getActiveSquadForTeam(team.id);
    }
    if (players.isEmpty) {
      players = _mockSquadForTeam(match, isTeamA);
    }
    if (onPitch != null) {
      final pitchState = await _pitchStateForTeam(match, isTeamA);
      players = _filterSquadByPitch(
        squad: players,
        pitchState: pitchState,
        onPitch: onPitch,
        excludeIds: excludePlayerIds,
      );
      if (includeIf != null) {
        players = players.where(includeIf).toList();
      }
    } else if (excludePlayerIds.isNotEmpty || includeIf != null) {
      players = players
          .where((p) => !excludePlayerIds.contains(p.id))
          .where((p) => includeIf == null || includeIf(p))
          .toList();
    }
    if (players.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              onPitch == true
                  ? 'No players on the pitch for this team'
                  : onPitch == false
                  ? 'No players on the bench for this team'
                  : 'No matching players for this team',
            ),
          ),
        );
      }
      return null;
    }

    return showModalBottomSheet<FixturePickerPlayer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        final textTheme = Theme.of(ctx).textTheme;
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            top: 16,
            left: 16,
            right: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: players.length,
                  itemBuilder: (context, index) {
                    final p = players[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        child: p.useNetworkImage && p.imageUrl != null
                            ? ClipOval(
                                child: Image(
                                  image: appCachedImageProvider(p.imageUrl!),
                                  width: 36,
                                  height: 36,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Icon(
                                Icons.person,
                                color: colorScheme.onSurfaceVariant,
                              ),
                      ),
                      title: Text(p.name),
                      subtitle: Text(p.position),
                      onTap: () => Navigator.of(ctx).pop(p),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openCardFlow(
    BuildContext context,
    MatchModel match,
    bool isTeamA,
    String cardType,
  ) async {
    final label = cardType == 'yellow_card' ? 'Yellow card' : 'Red card';
    final player = await _pickSquadPlayerForMatchControl(
      context,
      match,
      isTeamA,
      title: '$label for:',
      onPitch: true,
    );
    if (player == null || !mounted) return;

    final clock = ref.read(matchTimerAdapterProvider(widget.matchId));
    final config = ref.read(matchTimerConfigProvider(widget.matchId));
    final minute = config.getMatchMinute(clock).clamp(0, 120);
    final second = clock.inSeconds % 60;

    final scorerIdIsUuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(player.id);

    if (!scorerIdIsUuid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please use real squad players to record stats.'),
          ),
        );
      }
      return;
    }

    try {
      final repo = ref.read(matchesRepositoryProvider);
      final result = await repo.recordCardViaRpc(
        matchId: widget.matchId,
        playerId: player.id,
        cardType: cardType,
        minute: minute,
        second: second,
      );
      if (result != null) {
        ref.invalidate(matchesProvider);
        ref.invalidate(fixtureMatchProvider(widget.matchId));
        ref.invalidate(matchEventsProvider(widget.matchId));
        ref.invalidate(matchTeamStatsProvider(widget.matchId));
        ref.invalidate(fixtureMatchRatingsProvider(widget.matchId));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$label: ${player.name} ($minute\')')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not record card. Ensure match status is ongoing.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not record card: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _recordTackleEvent(
    BuildContext context,
    MatchModel match,
    bool isTeamA,
  ) async {
    final teamId = isTeamA ? match.teamA.id : match.teamB.id;
    if (teamId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Team not found')));
      return;
    }

    final player = await _pickSquadPlayerForMatchControl(
      context,
      match,
      isTeamA,
      title: 'Tackle by:',
      onPitch: true,
    );
    if (player == null || !mounted) return;

    final uuidRe = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (!uuidRe.hasMatch(player.id)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please use real squad players to record stats.'),
          ),
        );
      }
      return;
    }

    final clock = ref.read(matchTimerAdapterProvider(widget.matchId));
    final config = ref.read(matchTimerConfigProvider(widget.matchId));
    final minute = config.getMatchMinute(clock).clamp(0, 120);
    final second = clock.inSeconds % 60;

    try {
      final repo = ref.read(matchesRepositoryProvider);
      await repo.recordMatchEventViaRpc(
        matchId: widget.matchId,
        eventType: 'tackle',
        teamId: teamId,
        minute: minute,
        second: second,
        playerId: player.id,
      );
      ref.invalidate(matchEventsProvider(widget.matchId));
      ref.invalidate(matchTeamStatsProvider(widget.matchId));
      ref.invalidate(fixtureMatchRatingsProvider(widget.matchId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tackle: ${player.name} ($minute\')')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not record: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _openMissedShotFlow(
    BuildContext context,
    MatchModel match,
    bool isTeamA,
  ) async {
    final shootingTeamId = isTeamA ? match.teamA.id : match.teamB.id;
    final opposingTeamId = isTeamA ? match.teamB.id : match.teamA.id;
    if (shootingTeamId.isEmpty || opposingTeamId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Team not found')));
      return;
    }

    final shooter = await _pickSquadPlayerForMatchControl(
      context,
      match,
      isTeamA,
      title: 'Missed shot — taken by:',
      onPitch: true,
    );
    if (shooter == null || !mounted) return;

    final uuidRe = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (!uuidRe.hasMatch(shooter.id)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please use real squad players to record stats.'),
          ),
        );
      }
      return;
    }

    List<FixturePickerPlayer> opposing = [];
    if (opposingTeamId.isNotEmpty) {
      opposing = await ref
          .read(teamsRepositoryProvider)
          .getActiveSquadForTeam(opposingTeamId);
    }
    if (opposing.isEmpty) {
      opposing = _mockSquadForTeam(match, !isTeamA);
    }
    final opposingPitchState = await _pitchStateForTeam(match, !isTeamA);
    final gks = opposing
        .where((p) => _fixturePickerIsGoalkeeper(p.position))
        .where(
          (p) =>
              opposingPitchState == null ||
              opposingPitchState.isOnPitch(p.id),
        )
        .toList();

    final savePlayerId = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        final textTheme = Theme.of(ctx).textTheme;
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            top: 16,
            left: 16,
            right: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Was it saved?',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose the opposing goalkeeper, or off target / no save.',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      leading: Icon(
                        Icons.close,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      title: const Text('Off target / no save'),
                      onTap: () => Navigator.of(ctx).pop(''),
                    ),
                    if (gks.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No goalkeepers listed for the other team — use “Off target”.',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      ...gks.map(
                        (p) => ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                colorScheme.surfaceContainerHighest,
                            child: p.useNetworkImage && p.imageUrl != null
                                ? ClipOval(
                                    child: Image(
                                      image: appCachedImageProvider(p.imageUrl!),
                                      width: 36,
                                      height: 36,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Icon(
                                    Icons.person,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                          ),
                          title: Text(p.name),
                          subtitle: Text(p.position),
                          onTap: () => Navigator.of(ctx).pop(p.id),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted) return;
    final saveId = savePlayerId ?? '';

    final clock = ref.read(matchTimerAdapterProvider(widget.matchId));
    final config = ref.read(matchTimerConfigProvider(widget.matchId));
    final minute = config.getMatchMinute(clock).clamp(0, 120);
    final second = clock.inSeconds % 60;

    try {
      final repo = ref.read(matchesRepositoryProvider);
      await repo.recordMatchEventViaRpc(
        matchId: widget.matchId,
        eventType: 'shot',
        teamId: shootingTeamId,
        minute: minute,
        second: second,
        playerId: shooter.id,
      );
      if (saveId.isNotEmpty) {
        if (!uuidRe.hasMatch(saveId)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid goalkeeper selection')),
            );
          }
          return;
        }
        await repo.recordMatchEventViaRpc(
          matchId: widget.matchId,
          eventType: 'save',
          teamId: opposingTeamId,
          minute: minute,
          second: second,
          playerId: saveId,
        );
      }
      ref.invalidate(matchEventsProvider(widget.matchId));
      ref.invalidate(matchTeamStatsProvider(widget.matchId));
      ref.invalidate(fixtureMatchRatingsProvider(widget.matchId));
      if (mounted) {
        String? gkLabel;
        for (final g in gks) {
          if (g.id == saveId) {
            gkLabel = g.name;
            break;
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              gkLabel != null
                  ? 'Missed shot: ${shooter.name} Â· save: $gkLabel ($minute\')'
                  : 'Missed shot: ${shooter.name} ($minute\')',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not record: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _openSubstitutionFlow(
    BuildContext context,
    MatchModel match,
    bool isTeamA,
  ) async {
    final team = isTeamA ? match.teamA : match.teamB;
    if (team.id.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Team not found')));
      return;
    }

    List<FixturePickerPlayer> players = [];
    players = await ref
        .read(teamsRepositoryProvider)
        .getActiveSquadForTeam(team.id);
    if (players.isEmpty) {
      players = _mockSquadForTeam(match, isTeamA);
    }
    if (players.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No players available for this team')),
      );
      return;
    }

    final pitchState = await _pitchStateForTeam(match, isTeamA);
    final benchPlayers = _filterSquadByPitch(
      squad: players,
      pitchState: pitchState,
      onPitch: false,
    );
    final onPitchPlayers = _filterSquadByPitch(
      squad: players,
      pitchState: pitchState,
      onPitch: true,
    );
    if (benchPlayers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No players on the bench for this team')),
      );
      return;
    }
    if (onPitchPlayers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No players on the pitch for this team')),
      );
      return;
    }

    final rootContext = context;
    FixturePickerPlayer? subOn;
    FixturePickerPlayer? subOff;
    var step = 0;
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final colorScheme = Theme.of(context).colorScheme;
            final textTheme = Theme.of(context).textTheme;
            final clock = ref.read(matchTimerAdapterProvider(widget.matchId));
            final config = ref.read(matchTimerConfigProvider(widget.matchId));
            final minute = config.getMatchMinute(clock).clamp(0, 120);
            final second = clock.inSeconds % 60;

            Widget playerTile(
              FixturePickerPlayer p,
              String? selectedId,
              VoidCallback onSelect,
            ) {
              return InkWell(
                onTap: onSelect,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 8,
                  ),
                  child: Row(
                    children: [
                      Radio<String>(
                        value: p.id,
                        groupValue: selectedId,
                        onChanged: (_) => onSelect(),
                      ),
                      CircleAvatar(
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        backgroundImage:
                            !p.useNetworkImage && p.imagePath != null
                            ? AssetImage(p.imagePath!)
                            : null,
                        child: p.useNetworkImage && p.imageUrl != null
                            ? ClipOval(
                                child: Image(
                                  image: appCachedImageProvider(p.imageUrl!),
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Icon(
                                    Icons.person,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              )
                            : (!p.useNetworkImage && p.imagePath == null)
                            ? Icon(
                                Icons.person,
                                color: colorScheme.onSurfaceVariant,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              p.position,
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            Future<void> confirmSubstitution() async {
              if (subOn == null || subOff == null || saving) return;
              setModalState(() => saving = true);
              final uuidRe = RegExp(
                r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
                r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
              );
              if (!uuidRe.hasMatch(subOn!.id) || !uuidRe.hasMatch(subOff!.id)) {
                if (sheetContext.mounted) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please use real squad players to record stats.',
                      ),
                    ),
                  );
                }
                setModalState(() => saving = false);
                return;
              }
              try {
                final repo = ref.read(matchesRepositoryProvider);
                await repo.recordMatchEventViaRpc(
                  matchId: widget.matchId,
                  eventType: 'substitution',
                  teamId: team.id,
                  minute: minute,
                  second: second,
                  playerId: subOn!.id,
                  secondaryPlayerId: subOff!.id,
                );
                ref.invalidate(matchEventsProvider(widget.matchId));
                ref.invalidate(matchTeamStatsProvider(widget.matchId));
                ref.invalidate(fixtureMatchRatingsProvider(widget.matchId));
                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                if (rootContext.mounted) Navigator.of(rootContext).pop();
                if (rootContext.mounted) {
                  ScaffoldMessenger.of(rootContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Substitution: ${subOn!.name} on for ${subOff!.name} ($minute\')',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  setModalState(() => saving = false);
                }
                if (rootContext.mounted) {
                  final msg = e is PostgrestException
                      ? e.message
                      : e.toString().replaceFirst('Exception: ', '');
                  ScaffoldMessenger.of(rootContext).showSnackBar(
                    SnackBar(
                      content: Text('Could not record substitution: $msg'),
                      backgroundColor: Theme.of(rootContext).colorScheme.error,
                    ),
                  );
                }
              }
            }

            if (step == 0) {
              return Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  top: 16,
                  left: 16,
                  right: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Player coming on:',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: benchPlayers.length,
                        itemBuilder: (context, index) {
                          final p = benchPlayers[index];
                          return playerTile(p, subOn?.id, () {
                            setModalState(() => subOn = p);
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: subOn == null
                          ? null
                          : () {
                              if (onPitchPlayers.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'No players on the pitch to sub off.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              setModalState(() {
                                subOff = null;
                                step = 1;
                              });
                            },
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Player going off'),
                    ),
                  ],
                ),
              );
            }

            final offCandidates = _filterSquadByPitch(
              squad: players,
              pitchState: pitchState,
              onPitch: true,
              excludeIds: subOn != null ? {subOn!.id} : const {},
            );

            if (offCandidates.isEmpty) {
              return Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  top: 16,
                  left: 16,
                  right: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No other player to sub off',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: saving
                          ? null
                          : () => setModalState(() {
                              step = 0;
                              subOff = null;
                            }),
                      child: const Text('Back'),
                    ),
                  ],
                ),
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 16,
                left: 16,
                right: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: saving
                            ? null
                            : () => setModalState(() {
                                step = 0;
                                subOff = null;
                              }),
                      ),
                      Expanded(
                        child: Text(
                          'Player going off:',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: offCandidates.length,
                      itemBuilder: (context, index) {
                        final p = offCandidates[index];
                        return playerTile(p, subOff?.id, () {
                          if (saving) return;
                          setModalState(() => subOff = p);
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: (subOff == null || saving)
                        ? null
                        : confirmSubstitution,
                    icon: saving
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.check),
                    label: Text(saving ? 'Saving…' : 'Confirm substitution'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Mock squad per team until lineups are loaded from backend.
  List<FixturePickerPlayer> _mockSquadForTeam(MatchModel match, bool isTeamA) {
    final team = isTeamA ? match.teamA : match.teamB;
    final id = team.id;
    // Deterministic mock squads by team id hash so same team gets same list.
    final seed = id.hashCode.abs();
    final names = [
      'Gareth Neville',
      'Hector',
      'Anyaar',
      'Reagan',
      'Aijuka',
      'Crivin',
    ];
    final positions = [
      'Defender',
      'Attacker',
      'Attacker',
      'Midfielder',
      'Defender',
      'Defender',
    ];
    final List<FixturePickerPlayer> out = [];
    for (var i = 0; i < names.length; i++) {
      out.add(
        FixturePickerPlayer(
          id: '${id}_$i',
          name: names[(seed + i) % names.length],
          position: positions[(seed + i) % positions.length],
          imagePath: AppAssets.avatar1,
        ),
      );
    }
    // Dedupe names for display
    final seen = <String>{};
    return out.where((p) => seen.add(p.name)).take(6).toList();
  }

  Future<void> _openGoalScorerFlow(
    BuildContext context,
    MatchModel match,
    bool isTeamA,
  ) async {
    final team = isTeamA ? match.teamA : match.teamB;
    List<FixturePickerPlayer> players = [];
    if (team.id.isNotEmpty) {
      final teamsRepo = ref.read(teamsRepositoryProvider);
      players = await teamsRepo.getActiveSquadForTeam(team.id);
    }
    if (players.isEmpty) {
      players = _mockSquadForTeam(match, isTeamA);
    }
    if (players.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No players available for this team')),
      );
      return;
    }

    final pitchState = await _pitchStateForTeam(match, isTeamA);
    final onPitchPlayers = _filterSquadByPitch(
      squad: players,
      pitchState: pitchState,
      onPitch: true,
    );
    if (onPitchPlayers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No players on the pitch for this team')),
      );
      return;
    }

    final rootContext = context;
    FixturePickerPlayer? scorer;
    FixturePickerPlayer? assist;
    var step = 0; // 0 = scorer, 1 = assist
    var saving = false; // guard against double-submit while score is updating

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final colorScheme = Theme.of(context).colorScheme;
            final textTheme = Theme.of(context).textTheme;
            final clock = ref.read(matchTimerAdapterProvider(widget.matchId));
            final config = ref.read(matchTimerConfigProvider(widget.matchId));
            final minute = config.getMatchMinute(clock).clamp(0, 120);

            Widget playerTile(
              FixturePickerPlayer p,
              String? selectedId,
              VoidCallback onSelect,
            ) {
              return InkWell(
                onTap: onSelect,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 8,
                  ),
                  child: Row(
                    children: [
                      Radio<String>(
                        value: p.id,
                        groupValue: selectedId,
                        onChanged: (_) => onSelect(),
                      ),
                      CircleAvatar(
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        backgroundImage:
                            !p.useNetworkImage && p.imagePath != null
                            ? AssetImage(p.imagePath!)
                            : null,
                        child: p.useNetworkImage && p.imageUrl != null
                            ? ClipOval(
                                child: Image(
                                  image: appCachedImageProvider(p.imageUrl!),
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Icon(
                                    Icons.person,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              )
                            : (!p.useNetworkImage && p.imagePath == null)
                            ? Icon(
                                Icons.person,
                                color: colorScheme.onSurfaceVariant,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              p.position,
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (step == 0) {
              return Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  top: 16,
                  left: 16,
                  right: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Goal scored by:',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: onPitchPlayers.length,
                        itemBuilder: (context, index) {
                          final p = onPitchPlayers[index];
                          return playerTile(p, scorer?.id, () {
                            setModalState(() => scorer = p);
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: scorer == null
                          ? null
                          : () => setModalState(() => step = 1),
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Assist'),
                    ),
                  ],
                ),
              );
            }

            // Assist step (scorer already chosen)
            Future<void> confirmGoal({String? assistName}) async {
              if (scorer == null || saving) return;
              setModalState(() => saving = true);
              try {
                final repo = ref.read(matchesRepositoryProvider);
                final scorerIdIsUuid = RegExp(
                  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
                  r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
                ).hasMatch(scorer!.id);

                if (scorerIdIsUuid) {
                  final assistId =
                      (assist != null &&
                          RegExp(
                            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
                            r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
                          ).hasMatch(assist!.id))
                      ? assist!.id
                      : null;
                  final result = await repo.recordGoalViaRpc(
                    matchId: widget.matchId,
                    scorerPlayerId: scorer!.id,
                    minute: minute,
                    second: clock.inSeconds % 60,
                    assistPlayerId: assistId,
                  );
                  if (result == null) {
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Could not record goal. Ensure match status is ongoing.',
                          ),
                        ),
                      );
                    }
                    setModalState(() => saving = false);
                    return;
                  }
                } else {
                  if (sheetContext.mounted) {
                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please use real squad players to record stats.',
                        ),
                      ),
                    );
                  }
                  setModalState(() => saving = false);
                  return;
                }
                ref.invalidate(matchesProvider);
                ref.invalidate(fixtureMatchProvider(widget.matchId));
                ref.invalidate(matchEventsProvider(widget.matchId));
                ref.invalidate(matchTeamStatsProvider(widget.matchId));
                ref.invalidate(fixtureMatchRatingsProvider(widget.matchId));
                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                if (rootContext.mounted) Navigator.of(rootContext).pop();
                if (rootContext.mounted) {
                  ScaffoldMessenger.of(rootContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        assistName != null
                            ? 'Goal: ${scorer!.name} ($assistName)'
                            : 'Goal: ${scorer!.name}',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  setModalState(() => saving = false);
                }
                if (rootContext.mounted) {
                  final msg = e is PostgrestException
                      ? e.message
                      : e.toString().replaceFirst('Exception: ', '');
                  ScaffoldMessenger.of(rootContext).showSnackBar(
                    SnackBar(
                      content: Text('Could not record goal: $msg'),
                      backgroundColor: Theme.of(rootContext).colorScheme.error,
                    ),
                  );
                }
              }
            }

            final assistCandidates = _filterSquadByPitch(
              squad: players,
              pitchState: pitchState,
              onPitch: true,
              excludeIds: scorer != null ? {scorer!.id} : const {},
            );

            return Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 16,
                left: 16,
                right: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: saving
                            ? null
                            : () => setModalState(() {
                                step = 0;
                                assist = null;
                              }),
                      ),
                      Expanded(
                        child: Text(
                          'Assist by:',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: assistCandidates.length,
                      itemBuilder: (context, index) {
                        final p = assistCandidates[index];
                        return playerTile(p, assist?.id, () {
                          if (saving) return;
                          setModalState(() => assist = p);
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: (scorer == null || saving)
                        ? null
                        : () => confirmGoal(assistName: null),
                    child: const Text('No assist'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: (scorer == null || saving)
                        ? null
                        : () => confirmGoal(assistName: assist?.name),
                    icon: saving
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.check),
                    label: Text(saving ? 'Saving…' : 'Confirm goal'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPeriodButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isActive,
    required Color backgroundColor,
    required Color foregroundColor,
    required VoidCallback? onTap,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final bool isDisabled = onTap == null;
    final Color effectiveBackground = isDisabled
        ? backgroundColor.withValues(alpha: 0.35)
        : backgroundColor;
    final Color effectiveForeground = isDisabled
        ? foregroundColor.withValues(alpha: 0.55)
        : foregroundColor;

    return SizedBox(
      width: 186,
      height: 96,
      child: Material(
        color: effectiveBackground,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: effectiveForeground, size: 32),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: textTheme.headlineSmall?.copyWith(
                    color: effectiveForeground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventGrid(
    BuildContext context, {
    required MatchModel match,
    required bool isLeftTeam,
    bool enabled = true,
  }) {
    // Missed shot (+ optional save), goal, cards, tackle, substitution.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildEventButton(
              context,
              iconPath: AppAssets.missIcon,
              isLeftTile: true,
              enabled: enabled,
              onTap: () => _openMissedShotFlow(context, match, isLeftTeam),
            ),
            _buildEventButton(
              context,
              iconPath: AppAssets.goalIcon,
              isLeftTile: false,
              enabled: enabled,
              onTap: () {
                _openGoalScorerFlow(context, match, isLeftTeam);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildEventButton(
              context,
              iconPath: AppAssets.yellowCardIcon,
              isLeftTile: true,
              enabled: enabled,
              onTap: () =>
                  _openCardFlow(context, match, isLeftTeam, 'yellow_card'),
            ),
            _buildEventButton(
              context,
              iconPath: AppAssets.redCardIcon,
              isLeftTile: false,
              enabled: enabled,
              onTap: () =>
                  _openCardFlow(context, match, isLeftTeam, 'red_card'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildEventButton(
              context,
              iconPath: AppAssets.tackleControlIcon,
              isLeftTile: true,
              enabled: enabled,
              onTap: () => _recordTackleEvent(context, match, isLeftTeam),
            ),
            _buildEventButton(
              context,
              iconPath: AppAssets.substitutionIcon,
              isLeftTile: false,
              enabled: enabled,
              onTap: () => _openSubstitutionFlow(context, match, isLeftTeam),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEventButton(
    BuildContext context, {
    required String iconPath,
    required bool isLeftTile,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final tileRadius = BorderRadius.only(
      topLeft: Radius.circular(isLeftTile ? 28 : 16),
      bottomLeft: Radius.circular(isLeftTile ? 28 : 16),
      topRight: Radius.circular(isLeftTile ? 16 : 28),
      bottomRight: Radius.circular(isLeftTile ? 16 : 28),
    );

    final Color tileColor = enabled
        ? colorScheme.surfaceContainerHighest
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);
    final Color iconColor = colorScheme.onSurface.withValues(
      alpha: enabled ? 1.0 : 0.6,
    );

    return Material(
      color: Colors.transparent,
      borderRadius: tileRadius,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: tileRadius,
        splashColor: colorScheme.primary.withValues(alpha: 0.12),
        highlightColor: colorScheme.primary.withValues(alpha: 0.04),
        child: SizedBox(
          width: 84.75,
          height: 72,
          child: Ink(
            decoration: BoxDecoration(
              color: tileColor,
              borderRadius: tileRadius,
            ),
            child: Center(
              child: enabled
                  ? SvgPicture.asset(
                      iconPath,
                      width: 32,
                      height: 32,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.sports_soccer,
                          size: 32,
                          color: iconColor,
                        );
                      },
                    )
                  : SvgPicture.asset(
                      iconPath,
                      width: 32,
                      height: 32,
                      colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.sports_soccer,
                          size: 32,
                          color: iconColor,
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- Match detail: Timeline tab (custom vertical axis; timelines package dropped — incompatible with current Flutter SDK) ---

class _FixtureTimelineTab extends ConsumerStatefulWidget {
  const _FixtureTimelineTab({required this.match, required this.canUndo});

  final MatchModel match;
  final bool canUndo;

  @override
  ConsumerState<_FixtureTimelineTab> createState() =>
      _FixtureTimelineTabState();
}

class _FixtureTimelineTabState extends ConsumerState<_FixtureTimelineTab> {
  bool _undoing = false;

  MatchEventDisplay? _lastRecordedEvent(List<MatchEventDisplay> events) {
    if (events.isEmpty) return null;
    final withTimestamp = events.where((e) => e.createdAt != null).toList();
    if (withTimestamp.isNotEmpty) {
      withTimestamp.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
      return withTimestamp.first;
    }
    final sorted = [...events]
      ..sort((a, b) {
        final m = a.minute.compareTo(b.minute);
        if (m != 0) return m;
        final s = a.second.compareTo(b.second);
        if (s != 0) return s;
        return a.id.compareTo(b.id);
      });
    return sorted.last;
  }

  Future<void> _undoLastEvent(MatchEventDisplay event) async {
    if (_undoing || event.id.isEmpty) return;
    setState(() => _undoing = true);
    try {
      await ref.read(matchesRepositoryProvider).voidMatchEventViaRpc(event.id);
      ref.invalidate(matchesProvider);
      ref.invalidate(fixtureMatchProvider(widget.match.id));
      ref.invalidate(matchEventsProvider(widget.match.id));
      ref.invalidate(matchTeamStatsProvider(widget.match.id));
      ref.invalidate(fixtureMatchRatingsProvider(widget.match.id));
      ref.invalidate(lineupPlayerStatsProvider(widget.match.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed: ${_formatUndoEventLabel(event)}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not undo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _undoing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final eventsAsync = ref.watch(matchEventsProvider(widget.match.id));

    return eventsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not load events: $e',
            style: textTheme.bodyMedium,
          ),
        ),
      ),
      data: (events) {
        if (events.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No events yet',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }

        final lastEvent =
            widget.canUndo ? _lastRecordedEvent(events) : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (lastEvent != null)
              _FixtureTimelineUndoBar(
                label: _formatUndoEventLabel(lastEvent),
                undoing: _undoing,
                onUndo: () => _undoLastEvent(lastEvent),
              ),
            Expanded(
              child: _FixtureTimelineScrollView(
                match: widget.match,
                events: events,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FixtureTimelineUndoBar extends StatelessWidget {
  const _FixtureTimelineUndoBar({
    required this.label,
    required this.undoing,
    required this.onUndo,
  });

  final String label;
  final bool undoing;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Undo last: $label',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: undoing ? null : onUndo,
              icon: undoing
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    )
                  : const Icon(Icons.undo, size: 18),
              label: Text(undoing ? 'Undoing…' : 'Undo'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatUndoEventLabel(MatchEventDisplay e) {
  final minuteLabel = "${e.minute}'";
  final player = e.scorerName?.trim();
  final secondary = e.assisterName?.trim();
  switch (e.eventType) {
    case 'goal':
    case 'penalty_goal':
      if (player != null && player.isNotEmpty) {
        if (secondary != null && secondary.isNotEmpty) {
          return 'Goal Â· $player ($secondary) Â· $minuteLabel';
        }
        return 'Goal Â· $player Â· $minuteLabel';
      }
      return 'Goal Â· $minuteLabel';
    case 'own_goal':
      return 'Own goal Â· ${player ?? 'Player'} Â· $minuteLabel';
    case 'yellow_card':
      return 'Yellow card Â· ${player ?? 'Player'} Â· $minuteLabel';
    case 'red_card':
      return 'Red card Â· ${player ?? 'Player'} Â· $minuteLabel';
    case 'substitution':
      return 'Substitution Â· ${player ?? 'On'} Â· ${secondary ?? 'Off'} Â· $minuteLabel';
    case 'shot':
      return 'Missed shot Â· ${player ?? 'Player'} Â· $minuteLabel';
    case 'save':
      return 'Save Â· ${player ?? 'Player'} Â· $minuteLabel';
    case 'tackle':
      return 'Tackle Â· ${player ?? 'Player'} Â· $minuteLabel';
    default:
      return '${e.eventType} Â· $minuteLabel';
  }
}

enum _FixtureTimelineKind { start, half, full, event }

class _FixtureTimelineItem {
  const _FixtureTimelineItem._({
    required this.kind,
    this.event,
    this.scoreTeamA,
    this.scoreTeamB,
  });

  const _FixtureTimelineItem.start() : this._(kind: _FixtureTimelineKind.start);

  const _FixtureTimelineItem.half(int a, int b)
    : this._(kind: _FixtureTimelineKind.half, scoreTeamA: a, scoreTeamB: b);

  const _FixtureTimelineItem.full(int a, int b)
    : this._(kind: _FixtureTimelineKind.full, scoreTeamA: a, scoreTeamB: b);

  const _FixtureTimelineItem.event(MatchEventDisplay e)
    : this._(kind: _FixtureTimelineKind.event, event: e);

  final _FixtureTimelineKind kind;
  final MatchEventDisplay? event;
  final int? scoreTeamA;
  final int? scoreTeamB;
}

List<_FixtureTimelineItem> _fixtureTimelineItemsForMatch(
  MatchModel match,
  List<MatchEventDisplay> events,
) {
  final teamAId = match.teamA.id;
  final sorted = [...events]
    ..sort((a, b) {
      final m = a.minute.compareTo(b.minute);
      if (m != 0) return m;
      final s = a.second.compareTo(b.second);
      if (s != 0) return s;
      return a.id.compareTo(b.id);
    });

  final items = <_FixtureTimelineItem>[_FixtureTimelineItem.start()];
  var ra = 0;
  var rb = 0;
  var halfDone = false;

  void bumpScore(MatchEventDisplay e) {
    final isA = e.teamId == teamAId;
    switch (e.eventType) {
      case 'goal':
      case 'penalty_goal':
        if (isA) {
          ra++;
        } else {
          rb++;
        }
        break;
      case 'own_goal':
        if (isA) {
          rb++;
        } else {
          ra++;
        }
        break;
    }
  }

  bool pastFirstHalf() =>
      match.status == MatchStatus.halfTime ||
      match.status == MatchStatus.ongoing ||
      match.status == MatchStatus.fullTime;

  for (final e in sorted) {
    if (!halfDone && e.minute >= 45) {
      items.add(_FixtureTimelineItem.half(ra, rb));
      halfDone = true;
    }
    items.add(_FixtureTimelineItem.event(e));
    bumpScore(e);
  }

  if (!halfDone && pastFirstHalf()) {
    items.add(_FixtureTimelineItem.half(ra, rb));
  }

  if (match.status == MatchStatus.fullTime) {
    final fa = match.teamAScore ?? ra;
    final fb = match.teamBScore ?? rb;
    items.add(_FixtureTimelineItem.full(fa, fb));
  }

  return items;
}

class _FixtureTimelineScrollView extends StatelessWidget {
  const _FixtureTimelineScrollView({required this.match, required this.events});

  final MatchModel match;
  final List<MatchEventDisplay> events;

  @override
  Widget build(BuildContext context) {
    final items = _fixtureTimelineItemsForMatch(match, events);
    final colorScheme = Theme.of(context).colorScheme;
    final lineColor = colorScheme.outlineVariant;
    const milestoneBlue = Color(0xFF5B9FD4);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++)
            _FixtureTimelineTile(
              match: match,
              item: items[i],
              index: i,
              total: items.length,
              lineColor: lineColor,
              milestoneBlue: milestoneBlue,
            ),
        ],
      ),
    );
  }
}

class _FixtureTimelineTile extends StatelessWidget {
  const _FixtureTimelineTile({
    required this.match,
    required this.item,
    required this.index,
    required this.total,
    required this.lineColor,
    required this.milestoneBlue,
  });

  final MatchModel match;
  final _FixtureTimelineItem item;
  final int index;
  final int total;
  final Color lineColor;
  final Color milestoneBlue;

  bool get _drawStart => index > 0;

  bool get _drawEnd => index < total - 1;

  String _milestoneLabel() {
    switch (item.kind) {
      case _FixtureTimelineKind.start:
        return 'START';
      case _FixtureTimelineKind.half:
        return 'HALF TIME (${item.scoreTeamA}-${item.scoreTeamB})';
      case _FixtureTimelineKind.full:
        return 'FULL TIME (${item.scoreTeamA}-${item.scoreTeamB})';
      case _FixtureTimelineKind.event:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    switch (item.kind) {
      case _FixtureTimelineKind.start:
      case _FixtureTimelineKind.half:
      case _FixtureTimelineKind.full:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: SizedBox(
            height: 56,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Expanded(child: SizedBox()),
                _FixtureTimelineAxis(
                  drawTopSegment: _drawStart,
                  drawBottomSegment: _drawEnd,
                  lineColor: lineColor,
                  clipBehavior: Clip.none,
                  node: OverflowBox(
                    maxWidth: 260,
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: milestoneBlue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _milestoneLabel(),
                        textAlign: TextAlign.center,
                        style: textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.35,
                        ),
                      ),
                    ),
                  ),
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        );
      case _FixtureTimelineKind.event:
        final e = item.event!;
        final isTeamA = e.teamId == match.teamA.id;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: isTeamA
                        ? _FixtureTimelineEventSide(event: e, alignEnd: true)
                        : const SizedBox.shrink(),
                  ),
                ),
                _FixtureTimelineAxis(
                  drawTopSegment: _drawStart,
                  drawBottomSegment: _drawEnd,
                  lineColor: lineColor,
                  node: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.surfaceContainerHighest,
                      border: Border.all(color: lineColor, width: 2),
                    ),
                    child: Text(
                      "${e.minute}'",
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: !isTeamA
                        ? _FixtureTimelineEventSide(event: e, alignEnd: false)
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }
}

/// Vertical match timeline axis: line segments + centered node (replaces `timelines` package).
class _FixtureTimelineAxis extends StatelessWidget {
  const _FixtureTimelineAxis({
    required this.drawTopSegment,
    required this.drawBottomSegment,
    required this.lineColor,
    required this.node,
    this.clipBehavior = Clip.hardEdge,
  });

  final bool drawTopSegment;
  final bool drawBottomSegment;
  final Color lineColor;
  final Widget node;
  final Clip clipBehavior;

  static const double _width = 44;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _width,
      child: Stack(
        clipBehavior: clipBehavior,
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _FixtureTimelineLinePainter(
              drawTopSegment: drawTopSegment,
              drawBottomSegment: drawBottomSegment,
              color: lineColor,
              thickness: 2,
            ),
          ),
          Center(child: node),
        ],
      ),
    );
  }
}

class _FixtureTimelineLinePainter extends CustomPainter {
  _FixtureTimelineLinePainter({
    required this.drawTopSegment,
    required this.drawBottomSegment,
    required this.color,
    required this.thickness,
  });

  final bool drawTopSegment;
  final bool drawBottomSegment;
  final Color color;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.square;
    if (drawTopSegment) {
      canvas.drawLine(Offset(cx, 0), Offset(cx, cy), paint);
    }
    if (drawBottomSegment) {
      canvas.drawLine(Offset(cx, cy), Offset(cx, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FixtureTimelineLinePainter oldDelegate) =>
      drawTopSegment != oldDelegate.drawTopSegment ||
      drawBottomSegment != oldDelegate.drawBottomSegment ||
      color != oldDelegate.color ||
      thickness != oldDelegate.thickness;
}

({String primary, String? secondary}) _fixtureEventTitles(MatchEventDisplay e) {
  switch (e.eventType) {
    case 'goal':
      return (primary: e.scorerName ?? 'Goal', secondary: e.assisterName);
    case 'penalty_goal':
      return (primary: e.scorerName ?? 'Penalty', secondary: e.assisterName);
    case 'own_goal':
      return (primary: e.scorerName ?? 'Own goal', secondary: null);
    case 'yellow_card':
      return (primary: e.scorerName ?? 'Yellow card', secondary: null);
    case 'red_card':
      return (primary: e.scorerName ?? 'Red card', secondary: null);
    case 'substitution':
      return (
        primary: e.scorerName ?? 'Substitution',
        secondary: e.assisterName,
      );
    case 'tackle':
      return (primary: e.scorerName ?? 'Tackle', secondary: e.assisterName);
    case 'shot':
      return (primary: e.scorerName ?? 'Shot', secondary: null);
    case 'save':
      return (primary: e.scorerName ?? 'Save', secondary: null);
    case 'corner':
      return (primary: e.scorerName ?? 'Corner', secondary: null);
    default:
      final raw = e.eventType.replaceAll('_', ' ');
      return (primary: raw.isEmpty ? 'Event' : raw, secondary: null);
  }
}

class _FixtureTimelineEventSide extends StatelessWidget {
  const _FixtureTimelineEventSide({
    required this.event,
    required this.alignEnd,
  });

  final MatchEventDisplay event;
  final bool alignEnd;

  Widget _icon(ColorScheme colorScheme) {
    final dim = colorScheme.onSurfaceVariant;
    switch (event.eventType) {
      case 'goal':
      case 'penalty_goal':
      case 'own_goal':
        return SvgPicture.asset(
          AppAssets.matchGoalIcon,
          width: 24,
          height: 24,
          errorBuilder: (_, _, _) => Icon(
            Icons.sports_soccer,
            size: 24,
            color: const Color(0xFF00FF5A),
          ),
        );
      case 'yellow_card':
        return SvgPicture.asset(
          AppAssets.yellowCardIcon,
          width: 22,
          height: 28,
          errorBuilder: (_, _, _) =>
              Icon(Icons.square, size: 22, color: Colors.amber),
        );
      case 'red_card':
        return SvgPicture.asset(
          AppAssets.redCardIcon,
          width: 22,
          height: 28,
          errorBuilder: (_, _, _) =>
              Icon(Icons.square, size: 22, color: Colors.red),
        );
      case 'substitution':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_upward, size: 15, color: Colors.green.shade400),
            Icon(Icons.arrow_downward, size: 15, color: Colors.red.shade400),
          ],
        );
      case 'tackle':
        return SvgPicture.asset(
          AppAssets.tackleControlIcon,
          width: 24,
          height: 24,
          colorFilter: ColorFilter.mode(dim, BlendMode.srcIn),
          errorBuilder: (_, _, _) =>
              Icon(Icons.sports, size: 24, color: dim),
        );
      case 'shot':
        return Icon(Icons.adjust, size: 22, color: dim);
      case 'save':
        return Icon(Icons.back_hand_outlined, size: 22, color: dim);
      case 'corner':
        return Icon(Icons.flag_outlined, size: 22, color: dim);
      default:
        return Icon(Icons.circle, size: 14, color: dim);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final titles = _fixtureEventTitles(event);
    final primaryStyle = textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurface,
      fontWeight: FontWeight.w500,
    );
    final secondaryStyle = textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );

    final textColumn = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          titles.primary,
          style: primaryStyle,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
        ),
        if (titles.secondary != null && titles.secondary!.isNotEmpty)
          Text(
            titles.secondary!,
            style: secondaryStyle,
            textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          ),
      ],
    );

    const gap = SizedBox(width: 10);

    if (alignEnd) {
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(child: textColumn),
            gap,
            _icon(colorScheme),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _icon(colorScheme),
          gap,
          Flexible(child: textColumn),
        ],
      ),
    );
  }
}

class _FixtureMatchEditOverlay extends ConsumerStatefulWidget {
  const _FixtureMatchEditOverlay({
    required this.match,
    required this.onClose,
    required this.onSaved,
  });

  final MatchModel match;
  final VoidCallback onClose;
  final VoidCallback onSaved;

  @override
  ConsumerState<_FixtureMatchEditOverlay> createState() =>
      _FixtureMatchEditOverlayState();
}

class _FixtureMatchEditOverlayState
    extends ConsumerState<_FixtureMatchEditOverlay> {
  late int _teamAScore;
  late int _teamBScore;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _teamAScore = widget.match.teamAScore ?? 0;
    _teamBScore = widget.match.teamBScore ?? 0;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(matchesRepositoryProvider).updateMatchScores(
            widget.match.id,
            teamAScore: _teamAScore,
            teamBScore: _teamBScore,
          );
      ref.invalidate(fixtureMatchProvider(widget.match.id));
      ref.invalidate(matchesProvider);
      if (!mounted) return;
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Score updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update score: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _scoreStepper({
    required BuildContext context,
    required String teamShortForm,
    required String logoPath,
    required int score,
    required ValueChanged<int> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        _FixtureTeamLogo(path: logoPath, size: 48),
        const SizedBox(height: 8),
        Text(
          teamShortForm,
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 16),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                onPressed: score > 0 ? () => onChanged(score - 1) : null,
                icon: const Icon(Icons.remove),
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  minimumSize: const Size(40, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '$score',
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton.filled(
                onPressed: score < 99 ? () => onChanged(score + 1) : null,
                icon: const Icon(Icons.add),
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  minimumSize: const Size(40, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.black54,
      child: GestureDetector(
        onTap: _saving ? null : widget.onClose,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width - 48,
              ),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 24),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Edit match',
                          style: textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        onPressed: _saving ? null : widget.onClose,
                        icon: const Icon(Icons.close),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  Text(
                    'Update the score',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _scoreStepper(
                          context: context,
                          teamShortForm: widget.match.teamA.shortForm,
                          logoPath: widget.match.teamA.logoPath,
                          score: _teamAScore,
                          onChanged: (v) => setState(() => _teamAScore = v),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 56, left: 4, right: 4),
                        child: Text(
                          '–',
                          style: textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _scoreStepper(
                          context: context,
                          teamShortForm: widget.match.teamB.shortForm,
                          logoPath: widget.match.teamB.logoPath,
                          score: _teamBScore,
                          onChanged: (v) => setState(() => _teamBScore = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving ? null : widget.onClose,
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colorScheme.onPrimary,
                                  ),
                                )
                              : const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
