import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/utils/stoppage_alert.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_assets.dart';
import '../../domain/models/fixture_goal_event.dart';
import '../../domain/models/match_model.dart';
import '../providers/match_events_provider.dart';
import '../providers/matches_provider.dart';
import '../providers/teams_provider.dart';

class FixturePage extends ConsumerStatefulWidget {
  const FixturePage({super.key, required this.matchId});
  final String matchId;

  @override
  ConsumerState<FixturePage> createState() => _FixturePageState();
}

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
      final bytes = await xFile.readAsBytes();

      int? durationSeconds;
      if (!kIsWeb) {
        try {
          final file = File(xFile.path);
          final tempController = VideoPlayerController.file(file);
          await tempController.initialize();
          durationSeconds = tempController.value.duration.inSeconds;
          await tempController.dispose();
        } catch (_) {
          durationSeconds = null;
        }
      }

      final supabase = Supabase.instance.client;
      const bucket = 'Match videos';
      final path =
          'match-videos/$matchId/${matchId}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      await supabase.storage.from(bucket).uploadBinary(path, bytes);
      final url = supabase.storage.from(bucket).getPublicUrl(path);
      await supabase.from('videos').insert({
        'match_id': matchId,
        'uploader_user_id': supabase.auth.currentUser?.id,
        'duration_seconds': durationSeconds,
        'video_url': url,
        // thumbnail_url and hls_url can be filled later by a Supabase Edge Function.
        'thumbnail_url': null,
        'hls_url': null,
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
                          Row(
                            children: [
                              ClipOval(
                                child: Image.asset(
                                  AppAssets.interUniLeagueTrophy,
                                  width: 24,
                                  height: 24,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, st) => Container(
                                    width: 24,
                                    height: 24,
                                    color: Colors.grey,
                                    child: const Icon(
                                      Icons.sports_soccer,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Inter-uni league',
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
                                  'Kauga Turf, Mukono',
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
                                  'Fayad Mpanga',
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
                                    '3',
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
                                '1',
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
                                    '0',
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
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                // Match 1
                                Container(
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
                                        child: Image.asset(
                                          AppAssets.leftersLogo,
                                          width: 20,
                                          height: 20,
                                          fit: BoxFit.cover,
                                          errorBuilder: (c, e, st) =>
                                              const SizedBox(
                                                width: 20,
                                                height: 20,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        '1 - 0',
                                        style: textTheme.labelSmall?.copyWith(
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      ClipOval(
                                        child: Image.asset(
                                          AppAssets.galacticosLogo,
                                          width: 20,
                                          height: 20,
                                          fit: BoxFit.cover,
                                          errorBuilder: (c, e, st) =>
                                              const SizedBox(
                                                width: 20,
                                                height: 20,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Match 2
                                Container(
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
                                        child: Image.asset(
                                          AppAssets.galacticosLogo,
                                          width: 20,
                                          height: 20,
                                          fit: BoxFit.cover,
                                          errorBuilder: (c, e, st) =>
                                              const SizedBox(
                                                width: 20,
                                                height: 20,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        '0 - 2',
                                        style: textTheme.labelSmall?.copyWith(
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      ClipOval(
                                        child: Image.asset(
                                          AppAssets.leftersLogo,
                                          width: 20,
                                          height: 20,
                                          fit: BoxFit.cover,
                                          errorBuilder: (c, e, st) =>
                                              const SizedBox(
                                                width: 20,
                                                height: 20,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Match 3
                                Container(
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
                                        child: Image.asset(
                                          AppAssets.leftersLogo,
                                          width: 20,
                                          height: 20,
                                          fit: BoxFit.cover,
                                          errorBuilder: (c, e, st) =>
                                              const SizedBox(
                                                width: 20,
                                                height: 20,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        '1 - 3',
                                        style: textTheme.labelSmall?.copyWith(
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      ClipOval(
                                        child: Image.asset(
                                          AppAssets.galacticosLogo,
                                          width: 20,
                                          height: 20,
                                          fit: BoxFit.cover,
                                          errorBuilder: (c, e, st) =>
                                              const SizedBox(
                                                width: 20,
                                                height: 20,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Pre-match form section
                    const _PreMatchFormSection(),
                    const SizedBox(height: 16),
                    // Standings section
                    const _StandingsSection(),
                    const SizedBox(height: 16),
                    // Featured players section
                    const _FeaturedPlayersSection(),
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
                      final teamAId = match.teamA.id;
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: events.length,
                        itemBuilder: (context, i) {
                          final e = events[i];
                          final isTeamA = e.teamId == teamAId;
                          String label;
                          IconData icon = Icons.circle;
                          Color? iconColor;
                          switch (e.eventType) {
                            case 'goal':
                            case 'own_goal':
                            case 'penalty_goal':
                              label = e.scorerName != null
                                  ? '${e.scorerName!} ${e.assisterName != null ? '(${e.assisterName})' : ''}'
                                  : 'Goal';
                              icon = Icons.sports_soccer;
                              iconColor = const Color(0xFF00FF5A);
                              break;
                            case 'yellow_card':
                              label = e.scorerName ?? 'Yellow card';
                              icon = Icons.square;
                              iconColor = Colors.amber;
                              break;
                            case 'red_card':
                              label = e.scorerName ?? 'Red card';
                              icon = Icons.square;
                              iconColor = Colors.red;
                              break;
                            case 'shot':
                              label = 'Shot';
                              break;
                            case 'corner':
                              label = 'Corner';
                              break;
                            default:
                              label = e.eventType.replaceAll('_', ' ');
                          }
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                if (isTeamA)
                                  Expanded(
                                    child: Text(
                                      label,
                                      style: textTheme.bodyMedium,
                                      textAlign: TextAlign.end,
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Icon(
                                    icon,
                                    size: 20,
                                    color:
                                        iconColor ??
                                        colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                SizedBox(
                                  width: 36,
                                  child: Text(
                                    '${e.minute}\'',
                                    style: textTheme.labelMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Icon(
                                    icon,
                                    size: 20,
                                    color:
                                        iconColor ??
                                        colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                if (!isTeamA)
                                  Expanded(
                                    child: Text(
                                      label,
                                      style: textTheme.bodyMedium,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
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
                    // Player of the Match section
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
                            'Player of the Match',
                            style: textTheme.titleSmall?.copyWith(
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Player info row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Avatar + rating chip
                              Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor:
                                        colorScheme.surfaceContainerHighest,
                                    backgroundImage: const AssetImage(
                                      AppAssets.playerImage,
                                    ),
                                  ),
                                  Positioned(
                                    bottom: -4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00FF5A),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '8.3',
                                            style: textTheme.labelSmall
                                                ?.copyWith(
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.star,
                                            size: 12,
                                            color: Colors.black,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              // Text content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Gareth Neville',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurface,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        ClipOval(
                                          child: Image.asset(
                                            AppAssets.leftersLogo,
                                            width: 18,
                                            height: 18,
                                            fit: BoxFit.cover,
                                            errorBuilder: (c, e, st) =>
                                                const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Lefters CF',
                                          style: textTheme.labelSmall?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
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
                    // Top rated section
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
                            'Top rated',
                            style: textTheme.titleSmall?.copyWith(
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Grid of top-rated players (2 columns, 3 rows)
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
                              return _buildTopRatedPlayer(
                                context,
                                index: index,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Match stats section
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(28),
                      ),
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
                            leftValue: 8,
                            statName: 'Total shots',
                            rightValue: 12,
                            highlightRight: true,
                          ),
                          const SizedBox(height: 12),
                          _buildStatRow(
                            context,
                            leftValue: 5,
                            statName: 'Shots on target',
                            rightValue: 5,
                            highlightLeft: false,
                            highlightRight: false,
                          ),
                          const SizedBox(height: 12),
                          _buildStatRow(
                            context,
                            leftValue: 3,
                            statName: 'Shots off target',
                            rightValue: 7,
                            highlightRight: true,
                          ),
                          const SizedBox(height: 12),
                          _buildStatRow(
                            context,
                            leftValue: 4,
                            statName: 'Assists',
                            rightValue: 2,
                            highlightLeft: true,
                          ),
                          const SizedBox(height: 12),
                          _buildStatRow(
                            context,
                            leftValue: 2.4,
                            statName: 'Expected goals (XG-lite)',
                            rightValue: 1.5,
                            highlightLeft: true,
                            isDecimal: true,
                          ),
                          const SizedBox(height: 12),
                          _buildStatRow(
                            context,
                            leftValue: 13,
                            statName: 'Tackles',
                            rightValue: 21,
                            highlightRight: true,
                          ),
                          const SizedBox(height: 12),
                          _buildStatRow(
                            context,
                            leftValue: 9,
                            statName: 'Keeper saves',
                            rightValue: 3,
                            highlightLeft: true,
                          ),
                          const SizedBox(height: 12),
                          _buildStatRow(
                            context,
                            leftValue: 1,
                            statName: 'Red cards',
                            rightValue: 0,
                            highlightLeft: true,
                          ),
                          const SizedBox(height: 12),
                          _buildStatRow(
                            context,
                            leftValue: 1,
                            statName: 'Yellow cards',
                            rightValue: 2,
                            highlightRight: true,
                          ),
                        ],
                      ),
                    ),
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

class _PreMatchFormSection extends StatefulWidget {
  const _PreMatchFormSection();

  @override
  State<_PreMatchFormSection> createState() => _PreMatchFormSectionState();
}

class _PreMatchFormSectionState extends State<_PreMatchFormSection> {
  bool _showLeftersForm = false;
  bool _showGalacticosForm = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
          // Lefters form
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: team name + form chips + expand button
              Row(
                children: [
                  Text(
                    'Lefters',
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  _buildFormChip(context, label: 'W', color: Colors.green),
                  const SizedBox(width: 4),
                  _buildFormChip(
                    context,
                    label: 'D',
                    color: colorScheme.outlineVariant,
                    textColor: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  _buildFormChip(context, label: 'L', color: Colors.red),
                  const SizedBox(width: 4),
                  _buildFormChip(context, label: 'L', color: Colors.red),
                  const SizedBox(width: 4),
                  _buildFormChip(context, label: 'W', color: Colors.green),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(
                      _showLeftersForm ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      setState(() {
                        _showLeftersForm = !_showLeftersForm;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_showLeftersForm)
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildFormMatchPill(
                        context,
                        homeLogo: AppAssets.leftersLogo,
                        score: '1 - 0',
                        awayLogo: AppAssets.galacticosLogo,
                      ),
                      _buildFormMatchPill(
                        context,
                        homeLogo: AppAssets.leftersLogo,
                        score: '1 - 0',
                        awayLogo: AppAssets.dragonsLogo,
                      ),
                      _buildFormMatchPill(
                        context,
                        homeLogo: AppAssets.leftersLogo,
                        score: '1 - 3',
                        awayLogo: AppAssets.theShieldLogo,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: colorScheme.outlineVariant),
          const SizedBox(height: 8),
          // Galacticos form
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Galacticos',
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  _buildFormChip(context, label: 'L', color: Colors.red),
                  const SizedBox(width: 4),
                  _buildFormChip(context, label: 'W', color: Colors.green),
                  const SizedBox(width: 4),
                  _buildFormChip(context, label: 'L', color: Colors.red),
                  const SizedBox(width: 4),
                  _buildFormChip(context, label: 'L', color: Colors.red),
                  const SizedBox(width: 4),
                  _buildFormChip(context, label: 'L', color: Colors.red),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(
                      _showGalacticosForm
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      setState(() {
                        _showGalacticosForm = !_showGalacticosForm;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_showGalacticosForm)
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildFormMatchPill(
                        context,
                        homeLogo: AppAssets.leftersLogo,
                        score: '1 - 0',
                        awayLogo: AppAssets.galacticosLogo,
                      ),
                      _buildFormMatchPill(
                        context,
                        homeLogo: AppAssets.galacticosLogo,
                        score: '1 - 0',
                        awayLogo: AppAssets.endCareerLogo,
                      ),
                      _buildFormMatchPill(
                        context,
                        homeLogo: AppAssets.theShieldLogo,
                        score: '1 - 0',
                        awayLogo: AppAssets.galacticosLogo,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StandingsSection extends StatelessWidget {
  const _StandingsSection();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
          // GAL row
          _buildStandingRow(
            context,
            position: 1,
            shortName: 'GAL',
            logoAsset: AppAssets.galacticosLogo,
            played: 23,
            goalDiff: 18,
            points: 19,
          ),
          const SizedBox(height: 4),
          // LFC row
          _buildStandingRow(
            context,
            position: 3,
            shortName: 'LFC',
            logoAsset: AppAssets.leftersLogo,
            played: 23,
            goalDiff: 10,
            points: 15,
          ),
        ],
      ),
    );
  }
}

class _FeaturedPlayersSection extends StatelessWidget {
  const _FeaturedPlayersSection();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
          // Players row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFeaturedPlayer(
                context,
                name: 'Certi',
                rating: 9.1,
                avatarAsset: AppAssets.avatar18,
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
                name: 'Gareth',
                rating: 8.2,
                avatarAsset: AppAssets.avatar20,
                ratingColor: Colors.greenAccent,
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Radar chart
          SizedBox(
            height: 220,
            child: RadarChart(
              RadarChartData(
                radarBackgroundColor: Colors.black,
                borderData: FlBorderData(show: false),
                tickCount: 4,
                ticksTextStyle: const TextStyle(color: Colors.transparent),
                radarShape: RadarShape.polygon,
                titleTextStyle: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                titlePositionPercentageOffset: 0.15,
                getTitle: (index, angle) {
                  const labels = [
                    'Goals',
                    'Assists',
                    'Dribbles',
                    'Passing',
                    'Defence',
                  ];
                  return RadarChartTitle(text: labels[index % labels.length]);
                },
                dataSets: [
                  RadarDataSet(
                    fillColor: Colors.green.withOpacity(0.15),
                    borderColor: Colors.greenAccent,
                    entryRadius: 2,
                    borderWidth: 2,
                    dataEntries: const [
                      RadarEntry(value: 0.9),
                      RadarEntry(value: 0.7),
                      RadarEntry(value: 0.8),
                      RadarEntry(value: 0.75),
                      RadarEntry(value: 0.6),
                    ],
                  ),
                  RadarDataSet(
                    fillColor: Colors.blue.withOpacity(0.1),
                    borderColor: Colors.blueAccent,
                    entryRadius: 2,
                    borderWidth: 2,
                    dataEntries: const [
                      RadarEntry(value: 0.7),
                      RadarEntry(value: 0.8),
                      RadarEntry(value: 0.65),
                      RadarEntry(value: 0.7),
                      RadarEntry(value: 0.8),
                    ],
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

Widget _buildStandingRow(
  BuildContext context, {
  required int position,
  required String shortName,
  required String logoAsset,
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
            '$position',
            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            children: [
              ClipOval(
                child: Image.asset(
                  logoAsset,
                  width: 20,
                  height: 20,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, st) =>
                      const SizedBox(width: 20, height: 20),
                ),
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
  required double rating,
  required String avatarAsset,
  required Color ratingColor,
}) {
  final textTheme = Theme.of(context).textTheme;
  final colorScheme = Theme.of(context).colorScheme;

  return Column(
    children: [
      Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: colorScheme.surfaceContainerHighest,
            backgroundImage: AssetImage(avatarAsset),
          ),
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
                rating.toStringAsFixed(1),
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
          child: Image.asset(
            homeLogo,
            width: 20,
            height: 20,
            fit: BoxFit.cover,
            errorBuilder: (c, e, st) => const SizedBox(width: 20, height: 20),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          score,
          style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurface),
        ),
        const SizedBox(width: 12),
        ClipOval(
          child: Image.asset(
            awayLogo,
            width: 20,
            height: 20,
            fit: BoxFit.cover,
            errorBuilder: (c, e, st) => const SizedBox(width: 20, height: 20),
          ),
        ),
      ],
    ),
  );
}

Widget _buildTopRatedPlayer(BuildContext context, {required int index}) {
  final textTheme = Theme.of(context).textTheme;
  final colorScheme = Theme.of(context).colorScheme;

  // Player data based on index
  final players = [
    {
      'name': 'Gareth Neville',
      'position': 'Defender',
      'rating': 8.3,
      'hasStar': true,
      'teamLogo': AppAssets.leftersLogo,
      'logoPosition': Alignment.topLeft,
    },
    {
      'name': 'Hector',
      'position': 'Attacker',
      'rating': 7.6,
      'hasStar': false,
      'teamLogo': AppAssets.galacticosLogo,
      'logoPosition': Alignment.topRight,
    },
    {
      'name': 'Anyaar',
      'position': 'Attacker',
      'rating': 8.2,
      'hasStar': false,
      'teamLogo': AppAssets.leftersLogo,
      'logoPosition': Alignment.topLeft,
    },
    {
      'name': 'Reagan',
      'position': 'Midfielder',
      'rating': 7.4,
      'hasStar': false,
      'teamLogo': AppAssets.galacticosLogo,
      'logoPosition': Alignment.topRight,
    },
    {
      'name': 'Aijuka',
      'position': 'Defender',
      'rating': 8.1,
      'hasStar': false,
      'teamLogo': AppAssets.leftersLogo,
      'logoPosition': Alignment.topLeft,
    },
    {
      'name': 'Crivin',
      'position': 'Defender',
      'rating': 6.9,
      'hasStar': false,
      'teamLogo': AppAssets.galacticosLogo,
      'logoPosition': Alignment.topRight,
    },
  ];

  final player = players[index];
  final rating = player['rating'] as double;
  final badgeColor = rating >= 7.0 ? const Color(0xFF00FF5A) : Colors.orange;
  final isLefters = player['logoPosition'] == Alignment.topLeft;

  // Avatar with team logo overlay and rating badge
  final avatarStack = Stack(
    clipBehavior: Clip.none,
    alignment: Alignment.center,
    children: [
      CircleAvatar(
        radius: 24,
        backgroundColor: colorScheme.surfaceContainerHighest,
        backgroundImage: const AssetImage(AppAssets.playerImage),
      ),
      // Team logo positioned at top-left or top-right
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
            child: Image.asset(
              player['teamLogo'] as String,
              width: 18,
              height: 18,
              fit: BoxFit.cover,
              errorBuilder: (c, e, st) => Container(
                width: 18,
                height: 18,
                color: colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.sports_soccer,
                  size: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
      // Rating badge below avatar
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
              if (player['hasStar'] == true) ...[
                const SizedBox(width: 4),
                const Icon(Icons.star, size: 12, color: Colors.black),
              ],
            ],
          ),
        ),
      ),
    ],
  );

  // Name and position column
  final namePositionColumn = Column(
    crossAxisAlignment: isLefters
        ? CrossAxisAlignment.start
        : CrossAxisAlignment.end,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        player['name'] as String,
        style: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
        textAlign: isLefters ? TextAlign.left : TextAlign.right,
      ),
      const SizedBox(height: 4),
      Text(
        player['position'] as String,
        style: textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        textAlign: isLefters ? TextAlign.left : TextAlign.right,
      ),
    ],
  );

  // Layout: Lefters (left column) = avatar left, text right
  // Galacticos (right column) = text right, avatar right (16dp spacing)
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

  void _logMatchEvent(BuildContext context, String label, bool isLeftTeam) {
    final teamSide = isLeftTeam ? 'Home' : 'Away';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label logged for $teamSide team')));
  }

  Future<void> _openCardFlow(
    BuildContext context,
    MatchModel match,
    bool isTeamA,
    String cardType,
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No players available for this team')),
        );
      }
      return;
    }

    final label = cardType == 'yellow_card' ? 'Yellow card' : 'Red card';
    final player = await showModalBottomSheet<FixturePickerPlayer>(
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
                '$label for:',
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

  Future<void> _recordTeamEvent(
    BuildContext context,
    MatchModel match,
    bool isTeamA,
    String eventType,
  ) async {
    final teamId = isTeamA ? match.teamA.id : match.teamB.id;
    if (teamId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Team not found')));
      return;
    }
    final clock = ref.read(matchClockProvider(widget.matchId));
    final config = ref.read(matchTimerConfigProvider(widget.matchId));
    final minute = config.getMatchMinute(clock).clamp(0, 120);
    try {
      final repo = ref.read(matchesRepositoryProvider);
      await repo.recordMatchEventViaRpc(
        matchId: widget.matchId,
        eventType: eventType,
        teamId: teamId,
        minute: minute,
      );
      ref.invalidate(matchEventsProvider(widget.matchId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$eventType recorded ($minute\')')),
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
    // Event icons: [Shot, Goal, Yellow Card, Red Card, Corner/Throw-in, Substitution]
    final events = [
      {'icon': AppAssets.missIcon, 'label': 'Shot'},
      {'icon': AppAssets.goalIcon, 'label': 'Goal'},
      {'icon': AppAssets.yellowCardIcon, 'label': 'Yellow Card'},
      {'icon': AppAssets.redCardIcon, 'label': 'Red Card'},
      {'icon': AppAssets.tackleControlIcon, 'label': 'Corner'},
      {'icon': AppAssets.substitutionIcon, 'label': 'Substitution'},
    ];

    // 2 columns x 3 rows with fixed-size tiles (84.75 x 72)
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildEventButton(
              context,
              iconPath: events[0]['icon'] as String,
              isLeftTile: true,
              enabled: enabled,
              onTap: () => _recordTeamEvent(context, match, isLeftTeam, 'shot'),
            ),
            _buildEventButton(
              context,
              iconPath: events[1]['icon'] as String,
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
              iconPath: events[2]['icon'] as String,
              isLeftTile: true,
              enabled: enabled,
              onTap: () =>
                  _openCardFlow(context, match, isLeftTeam, 'yellow_card'),
            ),
            _buildEventButton(
              context,
              iconPath: events[3]['icon'] as String,
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
              iconPath: events[4]['icon'] as String,
              isLeftTile: true,
              enabled: enabled,
              onTap: () =>
                  _recordTeamEvent(context, match, isLeftTeam, 'corner'),
            ),
            _buildEventButton(
              context,
              iconPath: events[5]['icon'] as String,
              isLeftTile: false,
              enabled: enabled,
              onTap: () {
                _logMatchEvent(
                  context,
                  events[5]['label'] as String,
                  isLeftTeam,
                );
              },
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
