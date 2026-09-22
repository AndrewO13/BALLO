import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/adaptive/adaptive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/countries.dart';
import '../../core/utils/connection_error.dart';
import '../../core/utils/guest_mode.dart';
import '../../core/utils/scroll_to_top.dart';
import '../providers/main_nav_scroll_provider.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_error_state.dart';
import '../../core/widgets/media_placeholders.dart';
import '../../domain/models/match_model.dart';
import '../providers/match_timer_adapter_provider.dart';
import '../providers/favourited_leagues_provider.dart';
import '../providers/matches_provider.dart';
import '../providers/match_video_seen_provider.dart';
import '../widgets/match_list_score_pill.dart';
import '../widgets/match_live_status.dart';
import 'create_match_entry_page.dart';
import 'fixture.dart';
import 'league_detail_page.dart';
import 'match_videos_player_page.dart';

class MatchesPage extends ConsumerStatefulWidget {
  const MatchesPage({
    super.key,
    this.activationNonce = 0,
    this.mainNavTabIndex = MainNavTab.secondary,
    this.header,
    this.useDateNavigation = false,
  });

  final int activationNonce;
  final int mainNavTabIndex;

  /// Optional content above the filter row (e.g. guest home welcome).
  final Widget? header;

  /// Guest home: show a calendar day header (Today) instead of gameweeks.
  final bool useDateNavigation;

  @override
  ConsumerState<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends ConsumerState<MatchesPage> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _dateGroupKeys = <String, GlobalKey>{};
  int _lastHandledActivationNonce = -1;
  String? _lastHandledJumpDateKey;

  @override
  void didUpdateWidget(covariant MatchesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activationNonce != oldWidget.activationNonce) {
      _lastHandledActivationNonce = -1;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToLatestDateIfNeeded(List<String> dateKeys) {
    if (_lastHandledActivationNonce == widget.activationNonce) return;
    if (dateKeys.isEmpty) {
      _lastHandledActivationNonce = widget.activationNonce;
      return;
    }
    final sortedKeys = [...dateKeys]..sort();
    final latestKey = sortedKeys.last;

    final key = _dateGroupKeys[latestKey];
    final ctx = key?.currentContext;
    if (ctx == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = key?.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
      _lastHandledActivationNonce = widget.activationNonce;
    });
  }

  String _dateToKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _scrollToRequestedDateIfNeeded(
    List<String> dateKeys,
    DateTime? requestedDate,
  ) {
    if (requestedDate == null) return;
    final dateKey = _dateToKey(requestedDate);
    if (_lastHandledJumpDateKey == dateKey) return;

    if (!dateKeys.contains(dateKey)) {
      _lastHandledJumpDateKey = dateKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No matches scheduled for that date')),
        );
        ref.read(matchesJumpToDateProvider.notifier).set(null);
      });
      return;
    }

    final key = _dateGroupKeys[dateKey];
    final ctx = key?.currentContext;
    if (ctx == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final targetContext = key?.currentContext;
      if (targetContext == null) return;
      Scrollable.ensureVisible(
        targetContext,
        alignment: 0.0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
      _lastHandledJumpDateKey = dateKey;
      ref.read(matchesJumpToDateProvider.notifier).set(null);
    });
  }

  // Match card body (no date). Date/grouping is handled by `_buildDateGroup`.
  Widget _buildMatchCard(
    BuildContext context, {
    required String homeName,
    required String homeLogo,
    required String awayName,
    required String awayLogo,
    String? scoreText,
    required String statusText,
    required MatchStatus status,
    MatchHalfPhase? halfPhase,
    bool hasVideo = false,
    List<bool> videoWatched = const [],
    VoidCallback? onScorePillTap,
    String? date,
    String? league,
    String? venue,
    String? matchId,
  }) {
    final textTheme = Theme.of(context).textTheme;

    final id = matchId;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: id != null && id.isNotEmpty
            ? () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => FixturePage(matchId: id),
                  ),
                );
              }
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date is shown by the parent date-group container.
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(homeName, style: textTheme.bodySmall),
                        const SizedBox(width: 8),
                        ClipOval(
                          child: _TeamLogo(path: homeLogo, size: 28),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    if (status == MatchStatus.upcoming)
                      Text(statusText, style: textTheme.titleMedium)
                    else
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (halfPhase != null) ...[
                            MatchHalfPhaseChip(phase: halfPhase),
                            const SizedBox(height: 4),
                          ],
                          if (!hasVideo || onScorePillTap == null)
                            MatchListScorePill(
                              scoreText: scoreText ?? '',
                              hasVideo: hasVideo,
                              videoWatched: videoWatched,
                            )
                          else
                            GestureDetector(
                              onTap: onScorePillTap,
                              behavior: HitTestBehavior.opaque,
                              child: MatchListScorePill(
                                scoreText: scoreText ?? '',
                                hasVideo: true,
                                videoWatched: videoWatched,
                              ),
                            ),
                          if (status != MatchStatus.halfTime) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (status == MatchStatus.ongoing)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 6.0),
                                    child: MatchLivePulseIndicator(size: 8),
                                  ),
                                Text(
                                  statusText,
                                  style: textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    const SizedBox(width: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipOval(
                          child: _TeamLogo(path: awayLogo, size: 28),
                        ),
                        const SizedBox(width: 8),
                        Text(awayName, style: textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchListGroup(
    BuildContext context, {
    required List<Widget> matches,
    String? dateLabel,
    String? firstMatchId,
    MatchModel? leagueHeaderMatch,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context).textTheme;
    final useLeagueHeader = leagueHeaderMatch != null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (useLeagueHeader)
            _LeagueGroupHeader(match: leagueHeaderMatch)
          else if (dateLabel != null)
            if (firstMatchId != null && firstMatchId.isNotEmpty)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => FixturePage(matchId: firstMatchId),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text(
                      dateLabel,
                      style: theme.titleSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              )
            else
              Text(
                dateLabel,
                style: theme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          const SizedBox(height: 8),
          ...matches,
        ],
      ),
    );
  }

  Widget _buildMatchCardFromModel(
    BuildContext context,
    MatchModel match,
    String dateLabel,
  ) {
    final clock = ref.watch(matchTimerAdapterProvider(match.id));
    final ongoingTime = formatMatchClock(clock);

    // If this list item is built while the match is already ongoing (for
    // example, after starting the match from the detail modal), make sure the
    // shared match clock is running so the stopwatch stays in sync with the
    // fixture page.
    if (match.status == MatchStatus.ongoing && clock == Duration.zero) {
      ref.read(matchTimerAdapterProvider(match.id).notifier).start();
    }
    final timing = ref
        .watch(fixtureMatchTimelineTimingProvider(match.id))
        .asData
        ?.value;
    final timerConfig = ref.watch(matchTimerConfigProvider(match.id));
    final halfPhase = resolveMatchHalfPhase(
      status: match.status,
      resumedFromHalftimeAt: timing?.resumedFromHalftimeAt,
      hasReachedHalfTime: timerConfig.hasReachedHalfTime,
    );
    final statusLabel = match.status == MatchStatus.ongoing
        ? ongoingTime
        : match.statusText;

    final videosLookup = ref
        .watch(matchesVideosLookupProvider)
        .maybeWhen(data: (lookup) => lookup, orElse: () => const MatchVideosLookup());
    final seenIds = ref.watch(matchVideoSeenProvider);
    final hasVideo = videosLookup.matchIds.contains(match.id);
    final videoWatched = matchVideoWatchedSegments(
      match.id,
      videosLookup.videoIdsByMatch,
      seenIds,
    );

    return _buildMatchCard(
      context,
      homeName: match.teamA.shortForm,
      homeLogo: match.teamA.logoPath,
      awayName: match.teamB.shortForm,
      awayLogo: match.teamB.logoPath,
      scoreText: match.scoreText,
      statusText: statusLabel,
      status: match.status,
      halfPhase: halfPhase,
      hasVideo: hasVideo,
      videoWatched: videoWatched,
      onScorePillTap: hasVideo
          ? () => openMatchVideosPlayer(context, match)
          : null,
      date: dateLabel,
      league: null,
      venue: null,
      matchId: match.id,
    );
  }

  /// Height of the sticky header: top padding + filter row + spacing + gameweek + bottom padding.
  static const double _kStickyHeaderHeight = 164.0;

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(
      mainNavScrollToTopProvider.select(
        (m) => m[widget.mainNavTabIndex] ?? 0,
      ),
      (previous, next) {
        if (previous == next) return;
        animateScrollControllerToTop(_scrollController);
      },
    );

    final asyncMatches = ref.watch(matchesProvider);
    final grouped = ref.watch(matchesGroupedByDateProvider);
    final requestedJumpDate = ref.watch(matchesJumpToDateProvider);
    ref.listen<DateTime?>(matchesJumpToDateProvider, (previous, next) {
      if (next != null) _lastHandledJumpDateKey = null;
    });
    final selectedLeague = ref.watch(selectedMatchesLeagueProvider);
    final selectedSeason = ref.watch(selectedMatchesSeasonProvider);
    final selectedGw = ref.watch(selectedGameweekProvider);
    final selectedTeam = ref.watch(selectedMatchesTeamProvider);
    final selectedCalendarDate = ref.watch(selectedMatchesCalendarDateProvider);
    final hasActiveFilters =
        selectedLeague != null ||
        selectedSeason != null ||
        (!widget.useDateNavigation && selectedGw != null) ||
        selectedTeam != null;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(matchesProvider);
        await ref.read(matchesProvider.future);
      },
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (widget.header != null)
            SliverToBoxAdapter(child: widget.header!),
          SliverAppBar(
            floating: true,
            snap: true,
            automaticallyImplyLeading: false,
            toolbarHeight: _kStickyHeaderHeight,
            expandedHeight: _kStickyHeaderHeight,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  _MatchesFilterRow(
                    hideGameweekFilter: widget.useDateNavigation,
                  ),
                  const SizedBox(height: 12),
                  if (widget.useDateNavigation)
                    const _DateMatchesHeader()
                  else
                    const _GameweekHeader(),
                ],
              ),
            ),
          ),
          asyncMatches.when(
            data: (_) {
              final List<({
                String scrollKey,
                String dateLabel,
                List<MatchModel> matches,
                MatchModel? leagueHeaderMatch,
              })> groups;

              if (widget.useDateNavigation) {
                final dateKey = _dateToKey(selectedCalendarDate);
                final dayMatches = grouped[dateKey] ?? [];
                final byLeague = <String, List<MatchModel>>{};
                for (final match in dayMatches) {
                  final leagueId =
                      match.leagueId != null && match.leagueId!.isNotEmpty
                      ? match.leagueId!
                      : 'unknown';
                  byLeague.putIfAbsent(leagueId, () => []).add(match);
                }
                final leagueIds = byLeague.keys.toList()
                  ..sort(
                    (a, b) => (byLeague[a]!.first.leagueName ?? '')
                        .toLowerCase()
                        .compareTo(
                          (byLeague[b]!.first.leagueName ?? '').toLowerCase(),
                        ),
                  );
                groups = [
                  for (final leagueId in leagueIds)
                    (
                      scrollKey: '${dateKey}_$leagueId',
                      dateLabel: formatMatchDateKey(dateKey),
                      matches: byLeague[leagueId]!,
                      leagueHeaderMatch: byLeague[leagueId]!.first,
                    ),
                ];
              } else {
                final dateKeys = grouped.keys.toList()..sort();
                groups = [
                  for (final key in dateKeys)
                    (
                      scrollKey: key,
                      dateLabel: formatMatchDateKey(key),
                      matches: grouped[key]!,
                      leagueHeaderMatch: null,
                    ),
                ];
                _scrollToLatestDateIfNeeded(dateKeys);
                _scrollToRequestedDateIfNeeded(dateKeys, requestedJumpDate);
              }

              if (groups.isEmpty) {
                if (widget.useDateNavigation) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: AppEmptyState(
                        imageAsset: AppAssets.noMatchesEmpty,
                        title: 'No matches on this date',
                        subtitle: hasActiveFilters
                            ? 'Nothing scheduled for this day with your '
                                'current filters. Try clearing filters or '
                                'pick another date.'
                            : 'No matches scheduled for this day. Use the '
                                'arrows to check another date.',
                      ),
                    ),
                  );
                }
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: NoMatchesEmptyState(
                      hasActiveFilters: hasActiveFilters,
                      // Guests can't organize matches.
                      showCreateMatchCta: !GuestMode.isGuest,
                      onClearFilters: () {
                        ref
                            .read(selectedMatchesLeagueProvider.notifier)
                            .set(null);
                        ref
                            .read(selectedMatchesSeasonProvider.notifier)
                            .set(null);
                        ref.read(selectedGameweekProvider.notifier).set(null);
                        ref.read(selectedMatchesTeamProvider.notifier).set(null);
                      },
                      onCreateMatch: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const CreateMatchEntryPage(),
                          ),
                        );
                      },
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppResponsive.horizontalInset(context),
                  2,
                  AppResponsive.horizontalInset(context),
                  16 * AppResponsive.layoutScaleOf(context),
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final group in groups) ...[
                        KeyedSubtree(
                          key: _dateGroupKeys.putIfAbsent(
                            group.scrollKey,
                            () => GlobalKey(),
                          ),
                          child: _buildMatchListGroup(
                            context,
                            dateLabel: group.leagueHeaderMatch == null
                                ? group.dateLabel
                                : null,
                            leagueHeaderMatch: group.leagueHeaderMatch,
                            matches: group.matches
                                .map(
                                  (m) => _buildMatchCardFromModel(
                                    context,
                                    m,
                                    group.dateLabel,
                                  ),
                                )
                                .expand((w) => [w, const SizedBox(height: 2)])
                                .toList()
                              ..removeLast(),
                            firstMatchId: group.matches.isNotEmpty
                                ? group.matches.first.id
                                : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                    ],
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: AppConnectionErrorState(
                  title: isConnectionError(err)
                      ? 'No connection'
                      : 'Could not load matches',
                  subtitle: isConnectionError(err)
                      ? 'Check your internet connection and try again.'
                      : 'Something went wrong while loading your matches.',
                  onRetry: () {
                    ref.invalidate(matchesProvider);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeagueGroupHeader extends ConsumerStatefulWidget {
  const _LeagueGroupHeader({required this.match});

  final MatchModel match;

  @override
  ConsumerState<_LeagueGroupHeader> createState() =>
      _LeagueGroupHeaderState();
}

class _LeagueGroupHeaderState extends ConsumerState<_LeagueGroupHeader> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final match = widget.match;
    final leagueId = match.leagueId ?? '';
    final isStarred = ref.watch(favouritedLeaguesProvider).any(
      (league) => league.id == leagueId,
    );
    final leagueName = match.leagueName?.trim();
    final countryCode = match.leagueCountry?.trim();
    final countryLabel = (countryCode == null || countryCode.isEmpty)
        ? '—'
        : '${countryCodeToFlag(countryCode)} ${countryCodeToName(countryCode)}';
    final logoPath = resolveTeamLogoPath(match.leagueLogoId);

    void openLeague() {
      if (leagueId.isEmpty) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LeagueDetailPage(leagueId: leagueId),
        ),
      );
    }

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 36,
            height: 36,
            child: buildTeamLogo(logoPath, size: 36),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: openLeague,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    leagueName != null && leagueName.isNotEmpty
                        ? leagueName
                        : '—',
                    style: textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    countryLabel,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          style: IconButton.styleFrom(
            fixedSize: const Size(48, 48),
            padding: EdgeInsets.zero,
          ),
          icon: Icon(
            isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
            color: isStarred
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
            size: 26,
          ),
          onPressed: leagueId.isEmpty
              ? null
              : () {
                  ref.read(favouritedLeaguesProvider.notifier).toggle(
                    FavouritedLeague(
                      id: leagueId,
                      name: leagueName != null && leagueName.isNotEmpty
                          ? leagueName
                          : '—',
                      country: match.leagueCountry,
                      logoId: match.leagueLogoId,
                    ),
                  );
                },
          tooltip: isStarred ? 'Remove from favourites' : 'Add to favourites',
        ),
      ],
    );
  }
}

/// Date header with previous/next chevrons (guest home).
class _DateMatchesHeader extends ConsumerWidget {
  const _DateMatchesHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedMatchesCalendarDateProvider);
    final label = formatMatchesCalendarHeaderLabel(selectedDate);
    final notifier = ref.read(selectedMatchesCalendarDateProvider.notifier);

    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: notifier.goToPreviousDay,
                  tooltip: 'Previous day',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: notifier.goToNextDay,
                  tooltip: 'Next day',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ],
      ),
    );
  }
}

/// Gameweek header with previous/next chevrons to cycle through gameweeks.
class _GameweekHeader extends ConsumerWidget {
  const _GameweekHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameweekLabel = ref.watch(selectedGameweekLabelProvider);
    final gameweeksAsync = ref.watch(matchesFilterGameweeksProvider);
    final selectedGwId = ref.watch(selectedGameweekProvider);
    final notifier = ref.read(selectedGameweekProvider.notifier);

    final (canGoPrev, canGoNext) = gameweeksAsync.when(
      data: (list) {
        if (list.isEmpty) return (false, false);
        final ids = list.map((e) => e['id']?.toString() ?? '').toList();
        final idx = selectedGwId != null ? ids.indexOf(selectedGwId) : -1;
        final canPrev = idx > 0 || idx == -1;
        final canNext = (idx >= 0 && idx < ids.length - 1) || idx == -1;
        return (canPrev, canNext);
      },
      loading: () => (false, false),
      error: (_, _) => (false, false),
    );

    void goPrevious() {
      final list = gameweeksAsync.whenOrNull(data: (l) => l);
      if (list == null || list.isEmpty) return;
      final ids = list.map((e) => e['id']?.toString() ?? '').toList();
      final idx = selectedGwId != null ? ids.indexOf(selectedGwId) : -1;
      if (idx > 0) {
        notifier.set(ids[idx - 1]);
      } else if (idx == -1) {
        notifier.set(ids.last);
      } else {
        notifier.set(null);
      }
    }

    void goNext() {
      final list = gameweeksAsync.whenOrNull(data: (l) => l);
      if (list == null || list.isEmpty) return;
      final ids = list.map((e) => e['id']?.toString() ?? '').toList();
      final idx = selectedGwId != null ? ids.indexOf(selectedGwId) : -1;
      if (idx >= 0 && idx < ids.length - 1) {
        notifier.set(ids[idx + 1]);
      } else if (idx == -1) {
        notifier.set(ids.first);
      } else {
        notifier.set(null);
      }
    }

    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: canGoPrev ? goPrevious : null,
                  tooltip: 'Previous gameweek',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: canGoNext ? goNext : null,
                  tooltip: 'Next gameweek',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Center(
            child: Text(
              gameweekLabel != null && gameweekLabel.isNotEmpty
                  ? gameweekLabel
                  : 'All gameweeks',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ],
      ),
    );
  }
}

/// Truncates [text] to [maxLength] chars with ellipsis if longer.
String _truncateFilterLabel(String text, [int maxLength = 16]) {
  if (text.length <= maxLength) return text;
  return '${text.substring(0, maxLength)}…';
}

/// Filter dropdowns for matches (league, season, gameweek, team).
/// Options are based on user participation: leagues created or with user's team,
/// seasons for those leagues, gameweeks for those seasons, teams created or member of.
class _MatchesFilterRow extends ConsumerWidget {
  const _MatchesFilterRow({this.hideGameweekFilter = false});

  final bool hideGameweekFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaguesAsync = ref.watch(matchesFilterLeaguesProvider);
    final seasonsAsync = ref.watch(matchesFilterSeasonsProvider);
    final gameweeksAsync = ref.watch(matchesFilterGameweeksProvider);
    final teamsAsync = ref.watch(matchesFilterTeamsProvider);
    final selectedLeague = ref.watch(selectedMatchesLeagueProvider);
    final selectedSeason = ref.watch(selectedMatchesSeasonProvider);
    final selectedGw = ref.watch(selectedGameweekProvider);
    final selectedTeam = ref.watch(selectedMatchesTeamProvider);

    return SizedBox(
      height: 64,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 4),
            // League filter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SizedBox(
                width: 130,
                child: leaguesAsync.when(
                  data: (leagues) {
                    final entries = [
                      const DropdownMenuEntry(value: '', label: 'All leagues'),
                      ...leagues.map(
                        (l) => DropdownMenuEntry(
                          value: l.id,
                          label: _truncateFilterLabel(l.leagueName),
                        ),
                      ),
                    ];
                    return DropdownMenu<String>(
                      initialSelection: selectedLeague ?? '',
                      label: const Text('League'),
                      dropdownMenuEntries: entries,
                      onSelected: (s) {
                        ref
                            .read(selectedMatchesLeagueProvider.notifier)
                            .set(s?.isEmpty == true ? null : s);
                        ref
                            .read(selectedMatchesSeasonProvider.notifier)
                            .set(null);
                        ref.read(selectedGameweekProvider.notifier).set(null);
                        ref
                            .read(selectedMatchesTeamProvider.notifier)
                            .set(null);
                      },
                    );
                  },
                  loading: () => const DropdownMenu<String>(
                    label: Text('League'),
                    dropdownMenuEntries: [],
                  ),
                  error: (_, _) => const DropdownMenu<String>(
                    label: Text('League'),
                    dropdownMenuEntries: [],
                  ),
                ),
              ),
            ),
            // Season filter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SizedBox(
                width: 130,
                child: seasonsAsync.when(
                  data: (seasons) {
                    final entries = [
                      const DropdownMenuEntry(value: '', label: 'All seasons'),
                      ...seasons.map(
                        (s) => DropdownMenuEntry(
                          value: s.id,
                          label: _truncateFilterLabel(s.seasonName),
                        ),
                      ),
                    ];
                    return DropdownMenu<String>(
                      initialSelection: selectedSeason ?? '',
                      label: const Text('Season'),
                      dropdownMenuEntries: entries,
                      onSelected: (v) {
                        ref
                            .read(selectedMatchesSeasonProvider.notifier)
                            .set(v?.isEmpty == true ? null : v);
                        ref.read(selectedGameweekProvider.notifier).set(null);
                      },
                    );
                  },
                  loading: () => const DropdownMenu<String>(
                    label: Text('Season'),
                    dropdownMenuEntries: [],
                  ),
                  error: (_, _) => const DropdownMenu<String>(
                    label: Text('Season'),
                    dropdownMenuEntries: [],
                  ),
                ),
              ),
            ),
            // Gameweek filter
            if (!hideGameweekFilter)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: SizedBox(
                  width: 100,
                  child: gameweeksAsync.when(
                    data: (gameweeks) {
                      final entries = [
                        const DropdownMenuEntry(value: '', label: 'All GW'),
                        ...gameweeks.map((g) {
                          final id = g['id']?.toString() ?? '';
                          final week = g['week']?.toString() ?? '?';
                          return DropdownMenuEntry(value: id, label: 'GW $week');
                        }),
                      ];
                      return DropdownMenu<String>(
                        initialSelection: selectedGw ?? '',
                        label: const Text('GW'),
                        dropdownMenuEntries: entries,
                        onSelected: (v) => ref
                            .read(selectedGameweekProvider.notifier)
                            .set(v?.isEmpty == true ? null : v),
                      );
                    },
                    loading: () => const DropdownMenu<String>(
                      label: Text('GW'),
                      dropdownMenuEntries: [],
                    ),
                    error: (_, _) => const DropdownMenu<String>(
                      label: Text('GW'),
                      dropdownMenuEntries: [],
                    ),
                  ),
                ),
              ),
            // Team filter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SizedBox(
                width: 130,
                child: teamsAsync.when(
                  data: (teams) {
                    final entries = [
                      const DropdownMenuEntry(value: '', label: 'All teams'),
                      ...teams.map(
                        (t) => DropdownMenuEntry(
                          value: t.id,
                          label: _truncateFilterLabel(t.displayName),
                        ),
                      ),
                    ];
                    return DropdownMenu<String>(
                      initialSelection: selectedTeam ?? '',
                      label: const Text('Teams'),
                      dropdownMenuEntries: entries,
                      onSelected: (s) => ref
                          .read(selectedMatchesTeamProvider.notifier)
                          .set(s?.isEmpty == true ? null : s),
                    );
                  },
                  loading: () => const DropdownMenu<String>(
                    label: Text('Teams'),
                    dropdownMenuEntries: [],
                  ),
                  error: (_, _) => const DropdownMenu<String>(
                    label: Text('Teams'),
                    dropdownMenuEntries: [],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

/// Shows team logo from asset path or network URL.
class _TeamLogo extends StatelessWidget {
  const _TeamLogo({required this.path, this.size = 28});

  final String path;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: buildTeamLogo(path.isEmpty ? null : path, size: size),
    );
  }
}

class DodecagonIndicator extends StatefulWidget {
  const DodecagonIndicator({super.key, this.size = 12.0, this.color});
  final double size;
  final Color? color;

  @override
  State<DodecagonIndicator> createState() => _DodecagonIndicatorState();
}

class _DodecagonIndicatorState extends State<DodecagonIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          return Transform.rotate(
            angle: _ctrl.value * 2 * math.pi,
            child: CustomPaint(painter: _DodecagonPainter(color)),
          );
        },
      ),
    );
  }
}

class _DodecagonPainter extends CustomPainter {
  _DodecagonPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    const sides = 12;
    for (int i = 0; i < sides; i++) {
      final theta = (i / sides) * 2 * math.pi;
      final x = cx + r * math.cos(theta);
      final y = cy + r * math.sin(theta);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
