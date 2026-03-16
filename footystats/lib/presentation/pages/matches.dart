import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/match_model.dart';
import '../providers/matches_provider.dart';
import 'fixture.dart';

class MatchesPage extends ConsumerStatefulWidget {
  const MatchesPage({super.key});

  @override
  ConsumerState<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends ConsumerState<MatchesPage> {
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
    bool hasVideo = false,
    String? date,
    String? league,
    String? venue,
    String? matchId,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Home team - expanded to push from left, aligned right
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(homeName, style: textTheme.bodySmall),
                        const SizedBox(width: 8),
                        ClipOval(
                          child: _TeamLogo(
                            path: homeLogo,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Center area: score pill with status text centered below it.
                Builder(
                  builder: (context) {
                    if (status == MatchStatus.upcoming) {
                      // For upcoming matches show the scheduled time centered
                      // in the middle area. No status row below.
                      return Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text(statusText, style: textTheme.titleMedium),
                      );
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: hasVideo && status == MatchStatus.fullTime
                                ? Border.all(
                                    color: Colors.greenAccent.shade400,
                                    width: 2,
                                  )
                                : null,
                          ),
                          child: Text(
                            scoreText ?? '',
                            style: textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (status == MatchStatus.ongoing ||
                                status == MatchStatus.halfTime) ...[
                              Padding(
                                padding: const EdgeInsets.only(right: 6.0),
                                child: DodecagonIndicator(size: 12.0),
                              ),
                            ],
                            Text(statusText, style: textTheme.labelSmall),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(width: 16),

                // Away team - expanded to push from right, aligned left
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipOval(
                          child: _TeamLogo(
                            path: awayLogo,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(awayName, style: textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildDateGroup(
    BuildContext context,
    String date,
    List<Widget> matches, {
    String? firstMatchId,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context).textTheme;
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
          if (firstMatchId != null && firstMatchId.isNotEmpty)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          FixturePage(matchId: firstMatchId),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Text(
                    date,
                    style: theme.titleSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            )
          else
            Text(
              date,
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
    final clock = ref.watch(matchClockProvider(match.id));
    final ongoingTime = formatMatchClock(clock);

    // If this list item is built while the match is already ongoing (for
    // example, after starting the match from the detail modal), make sure the
    // shared match clock is running so the stopwatch stays in sync with the
    // fixture page.
    if (match.status == MatchStatus.ongoing && clock == Duration.zero) {
      ref.read(matchClockProvider(match.id).notifier).start();
    }
    final statusLabel =
        match.status == MatchStatus.ongoing ? ongoingTime : match.statusText;

    return _buildMatchCard(
      context,
      homeName: match.teamA.shortForm,
      homeLogo: match.teamA.logoPath,
      awayName: match.teamB.shortForm,
      awayLogo: match.teamB.logoPath,
      scoreText: match.scoreText,
      statusText: statusLabel,
      status: match.status,
      hasVideo: false,
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
    final asyncMatches = ref.watch(matchesProvider);
    final grouped = ref.watch(matchesGroupedByDateProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(matchesProvider);
        await ref.read(matchesProvider.future);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
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
                  const _MatchesFilterRow(),
                  const SizedBox(height: 12),
                  const _GameweekHeader(),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
            sliver: SliverToBoxAdapter(
              child: asyncMatches.when(
                data: (_) {
                  final dateKeys = grouped.keys.toList()..sort();
                  if (dateKeys.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Center(
                        child: Text(
                          'No matches',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final key in dateKeys) ...[
                        _buildDateGroup(
                          context,
                          formatMatchDateKey(key),
                          grouped[key]!
                              .map((m) => _buildMatchCardFromModel(
                                    context,
                                    m,
                                    formatMatchDateKey(key),
                                  ))
                              .expand((w) => [w, const SizedBox(height: 2)])
                              .toList()
                            ..removeLast(),
                          firstMatchId: grouped[key]!.isNotEmpty
                              ? grouped[key]!.first.id
                              : null,
                        ),
                        const SizedBox(height: 2),
                      ],
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, _) => Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Could not load matches',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          err.toString(),
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
      error: (_, __) => (false, false),
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
  const _MatchesFilterRow();

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
                      ...leagues.map((l) => DropdownMenuEntry(
                            value: l.id,
                            label: _truncateFilterLabel(l.leagueName),
                          )),
                    ];
                    return DropdownMenu<String>(
                    initialSelection: selectedLeague ?? '',
                    label: const Text('League'),
                    dropdownMenuEntries: entries,
                    onSelected: (s) {
                      ref.read(selectedMatchesLeagueProvider.notifier).set(
                            s?.isEmpty == true ? null : s,
                          );
                      ref.read(selectedMatchesSeasonProvider.notifier).set(null);
                      ref.read(selectedGameweekProvider.notifier).set(null);
                      ref.read(selectedMatchesTeamProvider.notifier).set(null);
                    },
                  );
                },
                loading: () => const DropdownMenu<String>(
                  label: Text('League'),
                  dropdownMenuEntries: [],
                ),
                error: (_, __) => const DropdownMenu<String>(
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
                      ...seasons.map((s) => DropdownMenuEntry(
                            value: s.id,
                            label: _truncateFilterLabel(s.seasonName),
                          )),
                    ];
                    return DropdownMenu<String>(
                    initialSelection: selectedSeason ?? '',
                    label: const Text('Season'),
                    dropdownMenuEntries: entries,
                    onSelected: (v) {
                      ref.read(selectedMatchesSeasonProvider.notifier).set(
                            v?.isEmpty == true ? null : v,
                          );
                      ref.read(selectedGameweekProvider.notifier).set(null);
                    },
                  );
                },
                loading: () => const DropdownMenu<String>(
                  label: Text('Season'),
                  dropdownMenuEntries: [],
                ),
                error: (_, __) => const DropdownMenu<String>(
                  label: Text('Season'),
                  dropdownMenuEntries: [],
                ),
              ),
            ),
            ),
            // Gameweek filter
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
                    onSelected: (v) =>
                        ref.read(selectedGameweekProvider.notifier).set(
                              v?.isEmpty == true ? null : v,
                            ),
                  );
                },
                loading: () => const DropdownMenu<String>(
                  label: Text('GW'),
                  dropdownMenuEntries: [],
                ),
                error: (_, __) => const DropdownMenu<String>(
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
                      ...teams.map((t) => DropdownMenuEntry(
                            value: t.id,
                            label: _truncateFilterLabel(t.displayName),
                          )),
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
                error: (_, __) => const DropdownMenu<String>(
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
    final isNetwork = path.startsWith('http://') || path.startsWith('https://');
    return SizedBox(
      width: size,
      height: size,
      child: isNetwork
          ? Image.network(
              path,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            )
          : Image.asset(
              path,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => SizedBox(
                width: size,
                height: size,
                child: Icon(
                  Icons.sports_soccer,
                  size: size * 0.6,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
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
