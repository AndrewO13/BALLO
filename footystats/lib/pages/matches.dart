import 'dart:math' as math;
import 'package:flutter/material.dart';

enum MatchesFilter { league, season, gw1, allTeams }

enum MatchStatus { upcoming, ongoing, halfTime, fullTime }

class MatchesPage extends StatefulWidget {
  const MatchesPage({super.key});

  @override
  State<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends State<MatchesPage> {
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

  Widget _buildGameweekHeader(BuildContext context) {
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
              'Gameweek 11',
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
  }) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date is shown by the parent date-group container.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Home team
              Row(
                children: [
                  Text(homeName, style: textTheme.bodySmall),
                  const SizedBox(width: 8),
                  ClipOval(
                    child: Image.asset(
                      homeLogo,
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, st) =>
                          const SizedBox(width: 28, height: 28),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),

              // Center area: score pill with status text centered below it.
              Builder(
                builder: (context) {
                  if (status == MatchStatus.upcoming) {
                    // For upcoming matches show the scheduled time centered
                    // in the middle area. No status row below.
                    return SizedBox(
                      width: 96,
                      height: 48,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text(statusText, style: textTheme.titleMedium),
                        ),
                      ),
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

              // Away team
              Row(
                children: [
                  ClipOval(
                    child: Image.asset(
                      awayLogo,
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, st) =>
                          const SizedBox(width: 28, height: 28),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(awayName, style: textTheme.bodySmall),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          SizedBox(
            height: 56,
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
          _buildGameweekHeader(context),
          const SizedBox(height: 2),

          // Sample fixtures demonstrating different states grouped by date
          _buildDateGroup(context, 'Tue 2 Dec', [
            _buildMatchCard(
              context,
              homeName: 'Galacticos',
              homeLogo: 'lib/assets/team logos/Galacticos.png',
              awayName: 'The Shield',
              awayLogo: 'lib/assets/team logos/The Shield.png',
              scoreText: null,
              statusText: '17:30',
              status: MatchStatus.upcoming,
            ),
            const SizedBox(height: 2),
            _buildMatchCard(
              context,
              homeName: 'La Famille FC',
              homeLogo: 'lib/assets/team logos/La Famille.png',
              awayName: 'End Career FC',
              awayLogo: 'lib/assets/team logos/End Career FC.png',
              scoreText: '1 - 2',
              statusText: 'HT',
              status: MatchStatus.halfTime,
            ),
          ]),

          const SizedBox(height: 2),

          _buildDateGroup(context, 'Wed 3 Dec', [
            _buildMatchCard(
              context,
              homeName: 'The Shield',
              homeLogo: 'lib/assets/team logos/The Shield.png',
              awayName: 'End Career FC',
              awayLogo: 'lib/assets/team logos/End Career FC.png',
              scoreText: '6 - 1',
              statusText: 'FT',
              status: MatchStatus.fullTime,
              hasVideo: true,
            ),
          ]),

          const SizedBox(height: 2),

          _buildDateGroup(context, 'Thu 4 Dec', [
            _buildMatchCard(
              context,
              homeName: 'End Career FC',
              homeLogo: 'lib/assets/team logos/End Career FC.png',
              awayName: 'La Famille FC',
              awayLogo: 'lib/assets/team logos/La Famille.png',
              scoreText: '3 - 0',
              statusText: '07:22',
              status: MatchStatus.ongoing,
            ),
          ]),
        ],
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
