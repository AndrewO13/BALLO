import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/utils/stoppage_alert.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_assets.dart';
import '../../data/repositories/leagues_repository.dart';
import '../../domain/models/fixture_goal_event.dart';
import '../../domain/models/match_model.dart';
import 'league_detail_page.dart';
import '../providers/match_events_provider.dart';
import '../providers/fixture_match_ratings_provider.dart';
import '../providers/match_team_stats_provider.dart';
import '../../domain/models/fixture_match_rated_player.dart';
import '../providers/matches_provider.dart';
import '../providers/teams_provider.dart';
import '../widgets/performance_radar_chart.dart';

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
  });

  final String? leagueId;
  final String? leagueName;
  final String? leagueLogoPath;
  final String? venue;
  final String? creatorName;
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
  const _FixtureFeaturedPlayersData({required this.teamAPlayer, required this.teamBPlayer});

  final _FeaturedPlayerData? teamAPlayer;
  final _FeaturedPlayerData? teamBPlayer;
}

String? _resolveLeagueLogoPath(String? logoId) {
  final id = logoId?.trim();
  if (id == null || id.isEmpty) return null;
  if (id.startsWith('http://') || id.startsWith('https://')) return id;
  if (id.startsWith('lib/assets/') || id.startsWith('assets/')) return id;
  final name = id.contains('.') ? id : '$id.png';
  return '${AppAssets.teamLogosPath}$name';
}

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
          .select('id, league_name, logo_id, created_by')
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
        leagueLogoPath: _resolveLeagueLogoPath(leagueRes['logo_id']?.toString()),
        venue: venue,
        creatorName: creatorName,
      );
    });

final fixtureH2HResultsProvider =
    FutureProvider.autoDispose.family<List<_H2HMatchResult>, String>((
      ref,
      matchId,
    ) async {
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
        if (scoreA == null || scoreB == null || teamAId.isEmpty || teamBId.isEmpty) {
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
      final currentMatch = await ref.watch(fixtureMatchProvider(matchId).future);
      if (currentMatch == null) {
        return const _FixtureTeamFormData(
          teamARecent: [],
          teamBRecent: [],
          logoByTeamId: {},
        );
      }

      final supabase = Supabase.instance.client;
      final currentDateStr =
          currentMatch.matchDate.toIso8601String().split('T').first;
      final currentTimeRaw = currentMatch.matchTime.trim();
      final currentTimeStr = currentTimeRaw.isEmpty
          ? '23:59:59'
          : (currentTimeRaw.length == 5 ? '$currentTimeRaw:00' : currentTimeRaw);

      Future<List<_TeamFormMatchResult>> fetchRecentForTeam(String teamId) async {
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
      final matchInfo = await ref.watch(fixtureMatchInfoProvider(matchId).future);
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
            logoPath: _resolveLeagueLogoPath(row['team_logo']?.toString()) ?? '',
            played: int.tryParse(row['played']?.toString() ?? '') ?? 0,
            goalDiff: int.tryParse(row['goal_difference']?.toString() ?? '') ?? 0,
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
        return const _FixtureFeaturedPlayersData(teamAPlayer: null, teamBPlayer: null);
      }
      final match = await ref.watch(fixtureMatchProvider(matchId).future);
      if (match == null) {
        return const _FixtureFeaturedPlayersData(teamAPlayer: null, teamBPlayer: null);
      }

      final supabase = Supabase.instance.client;
      final currentDateStr = match.matchDate.toIso8601String().split('T').first;
      final currentTimeRaw = match.matchTime.trim();
      final currentTimeStr = currentTimeRaw.isEmpty
          ? '23:59:59'
          : (currentTimeRaw.length == 5 ? '$currentTimeRaw:00' : currentTimeRaw);

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
            : (player is Map ? Map<String, dynamic>.from(player) : <String, dynamic>{});
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

  /// Picks a video from gallery and uploads to Supabase storage.
  /// Also inserts a row into the `videos` table. Returns public URL or null.
  Future<String?> _pickAndUploadMatchVideo(
    BuildContext context,
    String matchId,
  ) async {
    try {
      final picker = ImagePicker();
      final xFile = await picker.pickVideo(source: ImageSource.gallery);
      if (xFile == null || !context.mounted) return null;
      final supabase = Supabase.instance.client;
      const bucket = 'Match videos';
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Read video file
      final videoFile = File(xFile.path);
      final videoExt = p.extension(videoFile.path);
      final videoPath = 'match-videos/$matchId/${matchId}_$timestamp$videoExt';
      final videoBytes = await videoFile.readAsBytes();

      // Duration
      int? durationSeconds;
      try {
        final tempController = VideoPlayerController.file(videoFile);
        await tempController.initialize();
        durationSeconds = tempController.value.duration.inSeconds;
        await tempController.dispose();
      } catch (_) {
        durationSeconds = null;
      }

      // Thumbnail (mobile/desktop only)
      String? thumbUrl;
      if (!kIsWeb) {
        try {
          final thumbPath = await VideoThumbnail.thumbnailFile(
            video: videoFile.path,
            imageFormat: ImageFormat.JPEG,
            maxWidth: 720,
            quality: 75,
            timeMs: 300,
          );
          if (thumbPath != null) {
            final thumbFile = File(thumbPath);
            final thumbBytes = await thumbFile.readAsBytes();
            final thumbStoragePath =
                'match-thumbnails/$matchId/${matchId}_$timestamp.jpg';
            await supabase.storage
                .from(bucket)
                .uploadBinary(thumbStoragePath, thumbBytes);
            thumbUrl = supabase.storage
                .from(bucket)
                .getPublicUrl(thumbStoragePath);
          }
        } catch (_) {
          thumbUrl = null;
        }
      }

      await supabase.storage.from(bucket).uploadBinary(videoPath, videoBytes);
      final url = supabase.storage.from(bucket).getPublicUrl(videoPath);
      await supabase.from('videos').insert({
        'match_id': matchId,
        'uploader_user_id': supabase.auth.currentUser?.id,
        'duration_seconds': durationSeconds,
        'video_url': url,
        'thumbnail_url': thumbUrl,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Video added')));
      }
      return url;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not add video: $e')));
      }
      return null;
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
                    error: (_, __) => Padding(
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
                      const goalTypes = {'goal', 'own_goal', 'penalty_goal'};
                      final goals = events
                          .where((e) => goalTypes.contains(e.eventType))
                          .toList();
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
                        error: (_, __) => Column(
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
                            Text(
                              'Videos',
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 72,
                              child: Row(
                                children: [
                                  _MatchStoryAddButton(
                                    onPressed: () async {
                                      if (_isUploadingMatchVideo) return;
                                      setState(() {
                                        _isUploadingMatchVideo = true;
                                      });
                                      showDialog<void>(
                                        context: ctx,
                                        barrierDismissible: false,
                                        builder: (_) => const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                      final url =
                                          await _pickAndUploadMatchVideo(
                                            ctx,
                                            match.id,
                                          );
                                      if (ctx.mounted) {
                                        Navigator.of(ctx).pop(); // close loader
                                        if (url != null) {
                                          ref.invalidate(
                                            matchVideosProvider(match.id),
                                          );
                                        }
                                      }
                                      if (mounted) {
                                        setState(() {
                                          _isUploadingMatchVideo = false;
                                        });
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemBuilder: (context, index) =>
                                          _MatchStoryCircle(
                                            url: videos[index],
                                            teamALogo: match.teamA.logoPath,
                                            teamBLogo: match.teamB.logoPath,
                                          ),
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(width: 12),
                                      itemCount: videos.length,
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

  Widget _buildScorersColumns(
    TextTheme textTheme,
    ColorScheme colorScheme,
    MatchModel match,
    List<MatchEventDisplay> teamAGoals,
    List<MatchEventDisplay> teamBGoals,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                match.teamA.shortForm,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (teamAGoals.isEmpty)
                Text(
                  '—',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                )
              else
                ...teamAGoals.map(
                  (g) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '${g.scorerName ?? '?'} ${g.minute}\'',
                          style: textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        if (g.assisterName != null)
                          Text(
                            '(${g.assisterName})',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                match.teamB.shortForm,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (teamBGoals.isEmpty)
                Text(
                  '—',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                )
              else
                ...teamBGoals.map(
                  (g) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '${g.minute}\' ${g.scorerName ?? '?'}',
                          style: textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        if (g.assisterName != null)
                          Text(
                            '(${g.assisterName})',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFixtureWithMatch(BuildContext context, MatchModel match) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final matchInfoAsync = ref.watch(fixtureMatchInfoProvider(match.id));
    final h2hResultsAsync = ref.watch(fixtureH2HResultsProvider(match.id));
    final h2hResults = h2hResultsAsync.asData?.value ?? const <_H2HMatchResult>[];

    var teamAWins = 0;
    var draws = 0;
    var teamBWins = 0;
    for (final r in h2hResults) {
      final aPerspective =
          r.teamAId == match.teamA.id
          ? r.teamAScore
          : (r.teamBId == match.teamA.id ? r.teamBScore : r.teamAScore);
      final bPerspective =
          r.teamBId == match.teamB.id
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
    final clock = ref.watch(matchClockProvider(match.id));
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
      ref.read(matchClockProvider(match.id).notifier).start();
    }

    return DefaultTabController(
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
              PopupMenuButton<int>(
                icon: const Icon(Icons.more_vert),
                itemBuilder: (context) => const <PopupMenuEntry<int>>[],
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
            return [
              SliverToBoxAdapter(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: 412,
                    height: 305,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      child: Stack(
                        children: [
                          Image.asset(AppAssets.fixtureBg, fit: BoxFit.cover),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: const [0.0, 0.36, 0.94],
                                colors: [
                                  const Color(0xFF2D372F).withOpacity(0.1),
                                  const Color(0xFF2D372F).withOpacity(0.25),
                                  colorScheme.surface.withOpacity(1.0),
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
                                    .withOpacity(0.6),
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
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
                                              style: textTheme.bodyLarge,
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
                                              style: textTheme.bodyLarge,
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
                                        error: (_, __) =>
                                            const SizedBox.shrink(),
                                        data: (events) {
                                          final goalTypes = {
                                            'goal',
                                            'own_goal',
                                            'penalty_goal',
                                          };
                                          final goals = events
                                              .where(
                                                (e) => goalTypes.contains(
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
                                                            child: Text(
                                                              '${firstA.scorerName ?? '?'} ${firstA.minute}\'',
                                                              style: textTheme
                                                                  .bodySmall,
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                            ),
                                                          ),
                                                        ]
                                                      : [],
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 2,
                                                ),
                                                child: Container(
                                                  width: 20,
                                                  height: 20,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: colorScheme
                                                          .primaryContainer,
                                                      width: 2,
                                                    ),
                                                  ),
                                                  child: Center(
                                                    child: SvgPicture.asset(
                                                      AppAssets.matchGoalIcon,
                                                      width: 15,
                                                      height: 15,
                                                    ),
                                                  ),
                                                ),
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
                                                            child: Text(
                                                              '${firstB.minute}\' ${firstB.scorerName ?? '?'}',
                                                              style: textTheme
                                                                  .bodySmall,
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
                                final leagueId = matchInfoAsync.asData?.value?.leagueId;
                                if (leagueId == null || leagueId.isEmpty) return;
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => LeagueDetailPage(leagueId: leagueId),
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
                                      child:
                                          (() {
                                            final logoPath =
                                                matchInfoAsync
                                                    .asData
                                                    ?.value
                                                    ?.leagueLogoPath;
                                            if (logoPath == null || logoPath.isEmpty) {
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
                                                ? Image.network(
                                                    logoPath,
                                                    width: 24,
                                                    height: 24,
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (c, e, st) => Container(
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
                                                    errorBuilder:
                                                        (c, e, st) => Container(
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
                                        matchInfoAsync.asData?.value?.leagueName ??
                                            match.leagueName ??
                                            '—',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
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
                                    color: colorScheme.onSurfaceVariant,
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
                                  matchInfoAsync.asData?.value?.creatorName ?? '—',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Odds section
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Odds:', style: textTheme.bodySmall),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  // Team A odds
                                  Expanded(
                                    child: ActionChip(
                                      avatar: ClipOval(
                                        child: _FixtureTeamLogo(
                                          path: match.teamA.logoPath,
                                          size: 20,
                                        ),
                                      ),
                                      label: Text(
                                        '1.8',
                                        style: textTheme.labelLarge?.copyWith(
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      onPressed: () {},
                                      backgroundColor:
                                          colorScheme.surfaceContainerHigh,
                                      side: BorderSide(
                                        color: colorScheme.outlineVariant,
                                      ),
                                    ),
                                  ),
                                  // Draw odds
                                  Expanded(
                                    child: ActionChip(
                                      avatar: Text(
                                        'X',
                                        style: textTheme.bodyLarge?.copyWith(
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      label: Text(
                                        '2.1',
                                        style: textTheme.labelLarge?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      onPressed: () {},
                                      backgroundColor:
                                          colorScheme.surfaceContainerHigh,
                                      side: BorderSide(
                                        color: colorScheme.outlineVariant,
                                      ),
                                    ),
                                  ),
                                  // Team B odds
                                  Expanded(
                                    child: ActionChip(
                                      avatar: ClipOval(
                                        child: _FixtureTeamLogo(
                                          path: match.teamB.logoPath,
                                          size: 20,
                                        ),
                                      ),
                                      label: Text(
                                        '1.3',
                                        style: textTheme.labelLarge?.copyWith(
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      onPressed: () {},
                                      backgroundColor:
                                          colorScheme.surfaceContainerHigh,
                                      side: BorderSide(
                                        color: colorScheme.outlineVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
                                      fontWeight: FontWeight.w500,
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
                                  fontWeight: FontWeight.w500,
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
                                      fontWeight: FontWeight.w500,
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
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                              error: (_, __) => Align(
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
                                    final leftLogoPath = r.teamAId == match.teamA.id
                                        ? match.teamA.logoPath
                                        : match.teamB.logoPath;
                                    final rightLogoPath = r.teamBId == match.teamB.id
                                        ? match.teamB.logoPath
                                        : match.teamA.logoPath;
                                    return Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme.surfaceContainerHighest,
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
                                            style: textTheme.labelSmall?.copyWith(
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
              Consumer(
                builder: (context, ref, _) {
                  final eventsAsync = ref.watch(matchEventsProvider(match.id));
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
                      return _FixtureTimelineScrollView(
                        match: match,
                        events: events,
                      );
                    },
                  );
                },
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
              Center(child: Text('Line-ups', style: textTheme.bodyLarge)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFixtureStatsRatingsSections(BuildContext context, MatchModel match) {
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
                Text(
                  'Top rated',
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
        ],
      ),
      error: (_, __) => cardShell(
        child: Text(
          'Could not load player ratings',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      data: (players) {
        final potm = players.isNotEmpty ? players.first : null;
        final teamARanked = players.where((p) => p.teamId == match.teamA.id).toList()
          ..sort((a, b) => b.rating.compareTo(a.rating));
        final teamBRanked = players.where((p) => p.teamId == match.teamB.id).toList()
          ..sort((a, b) => b.rating.compareTo(a.rating));
        final teamA3 = teamARanked.take(3).toList();
        final teamB3 = teamBRanked.take(3).toList();

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
                                  fontWeight: FontWeight.w500,
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
                  Text(
                    'Top rated',
                    style: textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 2.5,
                    ),
                    itemCount: 6,
                    itemBuilder: (context, index) {
                      return _buildTopRatedPlayer(
                        context,
                        index: index,
                        match: match,
                        player: slotForGridIndex(index),
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
    final imagePath = potm.imageUrl?.trim();
    final hasImage = imagePath != null && imagePath.isNotEmpty;
    final isNetwork = hasImage &&
        (imagePath.startsWith('http://') || imagePath.startsWith('https://'));

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: colorScheme.surfaceContainerHighest,
          child: ClipOval(
            child: SizedBox(
              width: 48,
              height: 48,
              child: hasImage
                  ? (isNetwork
                      ? Image.network(
                          imagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.person,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        )
                      : Image.asset(
                          imagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.person,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ))
                  : Icon(
                      Icons.person,
                      color: colorScheme.onSurfaceVariant,
                    ),
            ),
          ),
        ),
        Positioned(
          bottom: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFF00FF5A),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  potm.rating.toStringAsFixed(1),
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
      error: (_, __) => shell(
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
                leftValue: a.xg,
                statName: 'Expected goals (XG-lite)',
                rightValue: b.xg,
                highlightLeft: a.xg > b.xg,
                highlightRight: b.xg > a.xg,
                isDecimal: true,
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
    final isNetwork = path.startsWith('http://') || path.startsWith('https://');
    return SizedBox(
      width: size,
      height: size,
      child: isNetwork
          ? Image.network(
              path,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(context),
            )
          : Image.asset(
              path,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(context),
            ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      color: colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.sports_soccer,
        size: size * 0.6,
        color: colorScheme.onSurfaceVariant,
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
  });

  final String url;
  final String teamALogo;
  final String teamBLogo;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const size = 64.0;
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
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colorScheme.primary, width: 3),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withOpacity(0.35),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipOval(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    color: colorScheme.surfaceContainerHigh,
                    child: Center(
                      child: _FixtureTeamLogo(path: teamALogo, size: 28),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    color: colorScheme.surfaceContainer,
                    child: Center(
                      child: _FixtureTeamLogo(path: teamBLogo, size: 28),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen video player for a single match video (reels-style).
class _MatchVideoPlayerPage extends StatefulWidget {
  const _MatchVideoPlayerPage({required this.videoUrl});

  final String videoUrl;

  @override
  State<_MatchVideoPlayerPage> createState() => _MatchVideoPlayerPageState();
}

class _MatchVideoPlayerPageState extends State<_MatchVideoPlayerPage> {
  late final VideoPlayerController _controller;
  bool _initialized = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() {
            _initialized = true;
            _isPlaying = true;
          });
          _controller.play();
          _controller.setLooping(true);
        })
        .catchError((e) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Could not load video')));
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (!_initialized) return;
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _isPlaying = false;
      } else {
        _controller.play();
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
            child: _initialized
                ? GestureDetector(
                    onTap: _togglePlay,
                    child: AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
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
                  onPressed: () => Navigator.of(context).pop(),
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
                  color: Colors.white.withOpacity(0.9),
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
                color: Colors.black.withOpacity(0.4),
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
    const size = 64.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.surfaceContainerHigh,
            border: Border.all(color: colorScheme.outline, width: 2),
          ),
          child: Icon(Icons.add, size: 32, color: colorScheme.primary),
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
            color: const Color(0xFF00FF5A).withOpacity(0.2),
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
                color: colorScheme.onSurfaceVariant.withOpacity(0.7),
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
        ? Colors.red.withOpacity(0.2)
        : greenColor.withOpacity(0.2);
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
              shortName: standings?.teamA?.teamShortName ?? match.teamA.displayName,
              logoPath: standings?.teamA?.logoPath ?? match.teamA.logoPath,
              played: standings?.teamA?.played ?? 0,
              goalDiff: standings?.teamA?.goalDiff ?? 0,
              points: standings?.teamA?.points ?? 0,
            ),
            const SizedBox(height: 4),
            _buildStandingRow(
              context,
              position: standings?.teamB?.position ?? 0,
              shortName: standings?.teamB?.teamShortName ?? match.teamB.displayName,
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
                  ratingColor: Colors.blueAccent,
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
                  ratingColor: Colors.greenAccent,
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          // Radar chart
          SizedBox(
            height: 220,
            child:
                teamAPlayer != null && teamBPlayer != null
                    ? PerformanceRadarChart(
                        playerId: teamAPlayer.playerId,
                        comparePlayerId: teamBPlayer.playerId,
                        year: year,
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
            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            children: [
              ClipOval(
                child: _FixtureTeamLogo(path: logoPath, size: 20),
              ),
              const SizedBox(width: 8),
              Text(
                shortName,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface,
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
  required Color ratingColor,
}) {
  final textTheme = Theme.of(context).textTheme;
  final colorScheme = Theme.of(context).colorScheme;
  final resolvedRating = rating;
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
            radius: 28,
            backgroundColor: colorScheme.surfaceContainerHighest,
            child: ClipOval(
              child: SizedBox(
                width: 56,
                height: 56,
                child: hasImage
                    ? (isNetwork
                          ? Image.network(
                              imagePath,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.person,
                                size: 28,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            )
                          : Image.asset(
                              imagePath,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
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
          if (resolvedRating != null)
            Positioned(
              bottom: -10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 2.0,
                ),
                decoration: BoxDecoration(
                  color: ratingColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  resolvedRating.toStringAsFixed(1),
                  style: textTheme.labelSmall?.copyWith(
                    color: Colors.white,
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
        style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface),
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
        ClipOval(
          child: _FixtureTeamLogo(path: homeLogo, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          score,
          style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurface),
        ),
        const SizedBox(width: 12),
        ClipOval(
          child: _FixtureTeamLogo(path: awayLogo, size: 20),
        ),
      ],
    ),
  );
}

/// Top rated grid: indices 0,2,4 = team A (left column); 1,3,5 = team B (right).
/// Matches the original placeholder layout; [player] null shows the same shell with dashes.
Widget _buildTopRatedPlayer(
  BuildContext context, {
  required int index,
  required MatchModel match,
  FixtureMatchRatedPlayer? player,
}) {
  final textTheme = Theme.of(context).textTheme;
  final colorScheme = Theme.of(context).colorScheme;
  final isLefters = index.isEven;
  final teamLogoPath = isLefters ? match.teamA.logoPath : match.teamB.logoPath;

  final Widget avatarStack;
  if (player != null) {
    final rating = player.rating;
    final badgeColor = rating >= 7.0 ? const Color(0xFF00FF5A) : Colors.orange;
    final posLabel =
        player.position?.trim().isNotEmpty == true ? player.position! : '—';
    final imagePath = player.imageUrl?.trim();
    final hasImage = imagePath != null && imagePath.isNotEmpty;
    final isNetwork = hasImage &&
        (imagePath.startsWith('http://') || imagePath.startsWith('https://'));

    avatarStack = Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: colorScheme.surfaceContainerHighest,
          child: ClipOval(
            child: SizedBox(
              width: 48,
              height: 48,
              child: hasImage
                  ? (isNetwork
                      ? Image.network(
                          imagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.person,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        )
                      : Image.asset(
                          imagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.person,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ))
                  : Icon(
                      Icons.person,
                      color: colorScheme.onSurfaceVariant,
                    ),
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
                if (index == 0) ...[
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
            fontWeight: FontWeight.w500,
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
        radius: 24,
        backgroundColor: colorScheme.surfaceContainerHighest,
        backgroundImage: const AssetImage(AppAssets.playerImage),
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
            color: colorScheme.outlineVariant.withOpacity(0.5),
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
        fontWeight: FontWeight.w500,
      ),
    );

    if (highlight) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.lightBlueAccent.withOpacity(0.3),
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
              color: colorScheme.onSurfaceVariant.withOpacity(0.4),
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
                  color: colorScheme.tertiaryContainer.withOpacity(0.6),
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
                                      .withOpacity(0.9),
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
                      color: colorScheme.outlineVariant.withOpacity(0.6),
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
          width: 380,
          height: 96,
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

      final clock = ref.read(matchClockProvider(widget.matchId).notifier);
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
          } else if (markResumed) {
            // Second half: set clock to half duration (e.g. 45:00, 2:00)
            final config = ref.read(matchTimerConfigProvider(widget.matchId));
            final halfMins = config.halfDurationMinutes ?? 45;
            clock.setTo(Duration(minutes: halfMins));
          }
          clock.start();
          break;
        case MatchStatus.halfTime:
          clock.pause();
          timerConfig.markHalfTimeReached();
          break;
        case MatchStatus.fullTime:
          clock.pause();
          timerConfig.reset();
          break;
      }

      ref.invalidate(matchesProvider);
      ref.invalidate(fixtureMatchProvider(widget.matchId));
      ref.invalidate(matchEventsProvider(widget.matchId));
      ref.invalidate(matchTeamStatsProvider(widget.matchId));
      ref.invalidate(fixtureMatchRatingsProvider(widget.matchId));

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
  Future<FixturePickerPlayer?> _pickSquadPlayerForMatchControl(
    BuildContext context,
    MatchModel match,
    bool isTeamA, {
    required String title,
    Set<String> excludePlayerIds = const {},
    bool Function(FixturePickerPlayer p)? includeIf,
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
    if (excludePlayerIds.isNotEmpty || includeIf != null) {
      players = players
          .where((p) => !excludePlayerIds.contains(p.id))
          .where((p) => includeIf == null || includeIf(p))
          .toList();
    }
    if (players.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No matching players for this team')),
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
                        radius: 18,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        child: p.useNetworkImage && p.imageUrl != null
                            ? ClipOval(
                                child: Image.network(
                                  p.imageUrl!,
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
    );
    if (player == null || !mounted) return;

    final clock = ref.read(matchClockProvider(widget.matchId));
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Team not found')),
      );
      return;
    }

    final player = await _pickSquadPlayerForMatchControl(
      context,
      match,
      isTeamA,
      title: 'Tackle by:',
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

    final clock = ref.read(matchClockProvider(widget.matchId));
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Team not found')),
      );
      return;
    }

    final shooter = await _pickSquadPlayerForMatchControl(
      context,
      match,
      isTeamA,
      title: 'Missed shot — taken by:',
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
    final gks =
        opposing.where((p) => _fixturePickerIsGoalkeeper(p.position)).toList();

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
                            radius: 18,
                            backgroundColor:
                                colorScheme.surfaceContainerHighest,
                            child: p.useNetworkImage && p.imageUrl != null
                                ? ClipOval(
                                    child: Image.network(
                                      p.imageUrl!,
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

    final clock = ref.read(matchClockProvider(widget.matchId));
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
                  ? 'Missed shot: ${shooter.name} · save: $gkLabel ($minute\')'
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Team not found')),
      );
      return;
    }

    List<FixturePickerPlayer> players = [];
    players = await ref.read(teamsRepositoryProvider).getActiveSquadForTeam(team.id);
    if (players.isEmpty) {
      players = _mockSquadForTeam(match, isTeamA);
    }
    if (players.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No players available for this team')),
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
            final clock = ref.read(matchClockProvider(widget.matchId));
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
                        radius: 22,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        backgroundImage:
                            !p.useNetworkImage && p.imagePath != null
                            ? AssetImage(p.imagePath!)
                            : null,
                        child: p.useNetworkImage && p.imageUrl != null
                            ? ClipOval(
                                child: Image.network(
                                  p.imageUrl!,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
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
                        itemCount: players.length,
                        itemBuilder: (context, index) {
                          final p = players[index];
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
                              if (players.length < 2) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Need at least two squad players to record a substitution.',
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

            final offCandidates =
                players.where((p) => p.id != subOn?.id).toList();

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
          imagePath: AppAssets.playerImage,
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
            final clock = ref.read(matchClockProvider(widget.matchId));
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
                        radius: 22,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        backgroundImage:
                            !p.useNetworkImage && p.imagePath != null
                            ? AssetImage(p.imagePath!)
                            : null,
                        child: p.useNetworkImage && p.imageUrl != null
                            ? ClipOval(
                                child: Image.network(
                                  p.imageUrl!,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
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
                        itemCount: players.length,
                        itemBuilder: (context, index) {
                          final p = players[index];
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
              } catch (e, _) {
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
                      itemCount: players.length,
                      itemBuilder: (context, index) {
                        final p = players[index];
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
        ? backgroundColor.withOpacity(0.35)
        : backgroundColor;
    final Color effectiveForeground = isDisabled
        ? foregroundColor.withOpacity(0.55)
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
              onTap: () =>
                  _openMissedShotFlow(context, match, isLeftTeam),
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
              onTap: () =>
                  _openSubstitutionFlow(context, match, isLeftTeam),
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
        : colorScheme.surfaceContainerHighest.withOpacity(0.4);
    final Color iconColor = colorScheme.onSurface.withOpacity(
      enabled ? 1.0 : 0.6,
    );

    return Material(
      color: Colors.transparent,
      borderRadius: tileRadius,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: tileRadius,
        splashColor: colorScheme.primary.withOpacity(0.12),
        highlightColor: colorScheme.primary.withOpacity(0.04),
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

enum _FixtureTimelineKind { start, half, full, event }

class _FixtureTimelineItem {
  const _FixtureTimelineItem._({
    required this.kind,
    this.event,
    this.scoreTeamA,
    this.scoreTeamB,
  });

  const _FixtureTimelineItem.start()
    : this._(kind: _FixtureTimelineKind.start);

  const _FixtureTimelineItem.half(int a, int b)
    : this._(
        kind: _FixtureTimelineKind.half,
        scoreTeamA: a,
        scoreTeamB: b,
      );

  const _FixtureTimelineItem.full(int a, int b)
    : this._(
        kind: _FixtureTimelineKind.full,
        scoreTeamA: a,
        scoreTeamB: b,
      );

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
  final sorted = [...events]..sort((a, b) {
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
  const _FixtureTimelineScrollView({
    required this.match,
    required this.events,
  });

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
                        ? _FixtureTimelineEventSide(
                            event: e,
                            alignEnd: true,
                          )
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
                        ? _FixtureTimelineEventSide(
                            event: e,
                            alignEnd: false,
                          )
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
          errorBuilder: (_, __, ___) => Icon(
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
          errorBuilder: (_, __, ___) => Icon(
            Icons.square,
            size: 22,
            color: Colors.amber,
          ),
        );
      case 'red_card':
        return SvgPicture.asset(
          AppAssets.redCardIcon,
          width: 22,
          height: 28,
          errorBuilder: (_, __, ___) => Icon(
            Icons.square,
            size: 22,
            color: Colors.red,
          ),
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
          errorBuilder: (_, __, ___) =>
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
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
