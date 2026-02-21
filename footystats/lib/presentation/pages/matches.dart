import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/match_model.dart';
import '../providers/matches_provider.dart';
import 'fixture.dart';

enum MatchesFilter { league, season, gw1, allTeams }

class MatchesPage extends ConsumerStatefulWidget {
  const MatchesPage({super.key});

  @override
  ConsumerState<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends ConsumerState<MatchesPage> {
  // Dropdown entries and selections for the filter menus
  final List<DropdownMenuEntry<String>> _leagueEntries = [
    const DropdownMenuEntry(value: 'Turf Champi', label: 'Turf Champi'),
    const DropdownMenuEntry(value: 'Community Cup', label: 'Community Cup'),
  ];

  final List<DropdownMenuEntry<String>> _seasonEntries = [
    const DropdownMenuEntry(value: 'Season 1', label: 'Season 1'),
    const DropdownMenuEntry(value: 'Season 2', label: 'Season 2'),
  ];

  final List<DropdownMenuEntry<String>> _gwEntries = [
    const DropdownMenuEntry(value: 'GW1', label: 'GW1'),
    const DropdownMenuEntry(value: 'GW2', label: 'GW2'),
  ];

  final List<DropdownMenuEntry<String>> _teamEntries = [
    const DropdownMenuEntry(value: 'All teams', label: 'All teams'),
    const DropdownMenuEntry(value: 'Lefters', label: 'Lefters'),
    const DropdownMenuEntry(value: 'Galacticos', label: 'Galacticos'),
  ];

  String? _selectedLeague;
  String? _selectedSeason;
  String? _selectedGW;
  String? _selectedTeam;

  Widget _buildGameweekHeader(BuildContext context, String? gameweekLabel) {
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
                  onPressed: () {},
                  tooltip: 'Previous',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {},
                  tooltip: 'Next',
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

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => FixturePage(matchId: matchId ?? ''),
          ),
        );
      },
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
    );
  }

  Widget _buildDateGroup(
    BuildContext context,
    String date,
    List<Widget> matches,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
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
          Text(
            date,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  @override
  Widget build(BuildContext context) {
    final asyncMatches = ref.watch(matchesProvider);
    final grouped = ref.watch(matchesGroupedByDateProvider);
    final selectedGw = ref.watch(selectedGameweekProvider);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            SizedBox(
              height: 64,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: DropdownMenu<String>(
                        initialSelection: _selectedLeague,
                        label: const Text('League'),
                        dropdownMenuEntries: _leagueEntries,
                        onSelected: (s) => setState(() => _selectedLeague = s),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: DropdownMenu<String>(
                        initialSelection: _selectedSeason,
                        label: const Text('Season'),
                        dropdownMenuEntries: _seasonEntries,
                        onSelected: (s) => setState(() => _selectedSeason = s),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: DropdownMenu<String>(
                        initialSelection: _selectedGW,
                        label: const Text('GW'),
                        dropdownMenuEntries: _gwEntries,
                        onSelected: (s) => setState(() => _selectedGW = s),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: DropdownMenu<String>(
                        initialSelection: _selectedTeam,
                        label: const Text('Teams'),
                        dropdownMenuEntries: _teamEntries,
                        onSelected: (s) => setState(() => _selectedTeam = s),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildGameweekHeader(
              context,
              selectedGw != null && selectedGw.isNotEmpty
                  ? 'Gameweek ${selectedGw.replaceFirst(RegExp(r'^GW'), '')}'
                  : null,
            ),
            const SizedBox(height: 2),
            asyncMatches.when(
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
