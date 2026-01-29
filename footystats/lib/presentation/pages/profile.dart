import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fl_chart/fl_chart.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return [
            // Profile card as sliver
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _ProfileCard(),
              ),
            ),
            // TabBar that sticks to top
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  labelColor: Theme.of(context).colorScheme.onSurface,
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  indicatorWeight: 3,
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Stats'),
                    Tab(text: 'Career'),
                    Tab(text: 'Video'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          children: [
            _ProfileTabContent(title: 'Overview'),
            _ProfileTabContent(title: 'Stats'),
            _ProfileTabContent(title: 'Career'),
            _ProfileTabContent(title: 'Video'),
          ],
        ),
      ),
    );
  }
}

// Custom delegate for sticky TabBar
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}

class _ProfileTabContent extends StatelessWidget {
  final String title;
  const _ProfileTabContent({required this.title});

  @override
  Widget build(BuildContext context) {
    if (title == 'Overview') {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AttributesSection(),
          const SizedBox(height: 16),
          _NextMatchSection(),
          const SizedBox(height: 16),
          _TeamFormSection(),
          const SizedBox(height: 16),
          _ClubHistorySection(),
          const SizedBox(height: 16),
          _TrophiesSection(),
          const SizedBox(height: 16),
          _BadgesSection(),
        ],
      );
    }
    if (title == 'Stats') {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SeasonOverallSection(),
          const SizedBox(height: 16),
          _TeamSeasonPerformanceSection(),
        ],
      );
    }
    if (title == 'Career') {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AllTimeStatsSection(),
          const SizedBox(height: 16),
          _TeamStatsSection(),
        ],
      );
    }
    if (title == 'Video') {
      return Column(
        children: [
          Padding(padding: const EdgeInsets.all(16), child: _VideoTabHeader()),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 121.33 / 204,
              ),
              itemCount: 12, // Number of video placeholders
              itemBuilder: (context, index) {
                return _VideoPlaceholder();
              },
            ),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        // TODO: Add content for each tab
      ],
    );
  }
}

class _SeasonOverallSection extends StatelessWidget {
  const _SeasonOverallSection();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text('Season overall', style: textTheme.titleSmall),
          const SizedBox(height: 16),
          // Stats grid (2 rows, 3 columns)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Goals
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '35',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Goals',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Assists
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '23',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Assists',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Rating (in green pill)
              Expanded(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '8.53',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.surface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rating',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Second row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Matches
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '34',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Matches',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Tackles
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '120',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tackles',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Minutes played
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '2,940',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Minutes played',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
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

class _TeamSeasonPerformanceSection extends StatefulWidget {
  const _TeamSeasonPerformanceSection();

  @override
  State<_TeamSeasonPerformanceSection> createState() =>
      _TeamSeasonPerformanceSectionState();
}

class _TeamSeasonPerformanceSectionState
    extends State<_TeamSeasonPerformanceSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          // Team header - always visible
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Team logo
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.transparent,
                    backgroundImage: const AssetImage(
                      'lib/assets/team logos/Lefters.png',
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Team name
                  Expanded(
                    child: Text('Lefters CF', style: textTheme.bodyLarge),
                  ),
                  // Expand/collapse icon
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: colorScheme.onSurface,
                  ),
                ],
              ),
            ),
          ),
          // Expanded content - stats card
          if (_isExpanded) ...[
            Divider(height: 1, thickness: 1, color: colorScheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Season performance', style: textTheme.titleSmall),
                  const SizedBox(height: 16),
                  // Stats list - two columns (label on left, value on right)
                  _buildStatRow('Goals', '35'),
                  const SizedBox(height: 12),
                  _buildStatRow('Expected goals (XG-lite)', '35.4'),
                  const SizedBox(height: 12),
                  _buildStatRow('Shots', '175'),
                  const SizedBox(height: 12),
                  _buildStatRow('Shots on target', '80'),
                  const SizedBox(height: 12),
                  _buildStatRow('Shots off target', '95'),
                  const SizedBox(height: 12),
                  _buildStatRow('Assists', '23'),
                  const SizedBox(height: 12),
                  _buildStatRow('Expected assists (XA-lite)', '17.0'),
                  const SizedBox(height: 12),
                  _buildStatRow('Tackles', '54'),
                  const SizedBox(height: 12),
                  _buildStatRow('Yellow cards', '3'),
                  const SizedBox(height: 12),
                  _buildStatRow('Red cards', '1'),
                  const SizedBox(height: 12),
                  _buildStatRow('Matches', '34'),
                  const SizedBox(height: 12),
                  _buildStatRow('Minutes played', '2,950'),
                  const SizedBox(height: 12),
                  _buildRatingRow('Rating', '8.5'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface),
          ),
        ),
        Text(
          value,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildRatingRow(String label, String value) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            value,
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.surface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _AllTimeStatsSection extends StatelessWidget {
  const _AllTimeStatsSection();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text('All-time stats', style: textTheme.titleSmall),
          const SizedBox(height: 16),
          // Stats grid (3 rows, 3 columns)
          // First row: Goals, Assists, Rating
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '1,290',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Goals',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '540',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Assists',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '8.53',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.surface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rating',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Second row: Tackles, Yellow cards, Red cards
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '173',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tackles',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '23',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Yellow cards',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '12',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Red cards',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Third row: Saves, Matches, Minutes played
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '12',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Saves',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '120',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Matches',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '12,940',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Minutes played',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
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

class _TeamStatsSection extends StatefulWidget {
  const _TeamStatsSection();

  @override
  State<_TeamStatsSection> createState() => _TeamStatsSectionState();
}

class _TeamStatsSectionState extends State<_TeamStatsSection> {
  final ScrollController _scrollController = ScrollController();
  final List<ScrollController> _rowScrollControllers = [];

  @override
  void initState() {
    super.initState();
    // Create a scroll controller for each team row
    _rowScrollControllers.addAll(
      List.generate(_teamStats.length, (index) {
        final controller = ScrollController();
        // Listen to row scroll and sync header and other rows
        controller.addListener(() {
          final offset = controller.offset;
          if (_scrollController.offset != offset) {
            _scrollController.jumpTo(offset);
          }
          for (var otherController in _rowScrollControllers) {
            if (otherController != controller &&
                otherController.offset != offset) {
              otherController.jumpTo(offset);
            }
          }
        });
        return controller;
      }),
    );

    // Listen to header scroll and sync row scrolls
    _scrollController.addListener(() {
      final offset = _scrollController.offset;
      for (var controller in _rowScrollControllers) {
        if (controller.offset != offset) {
          controller.jumpTo(offset);
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (var controller in _rowScrollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // Stat categories in order
  static const List<Map<String, String>> _statCategories = [
    {'key': 'matches', 'svg': 'lib/assets/stats table/matches.svg'},
    {'key': 'goals', 'svg': 'lib/assets/stats table/goals.svg'},
    {'key': 'assists', 'svg': 'lib/assets/stats table/assists.svg'},
    {'key': 'tackles', 'svg': 'lib/assets/stats table/tackles.svg'},
    {'key': 'yellowCards', 'svg': 'lib/assets/stats table/yellow cards.svg'},
    {'key': 'redCards', 'svg': 'lib/assets/stats table/red cards.svg'},
    {'key': 'saves', 'svg': 'lib/assets/stats table/saves.svg'},
    {
      'key': 'minutesPlayed',
      'svg': 'lib/assets/stats table/minutes played.svg',
    },
    {'key': 'rating', 'svg': 'lib/assets/stats table/rating.svg'},
  ];

  // Sample team stats data
  final List<Map<String, dynamic>> _teamStats = const [
    {
      'logo': 'lib/assets/team logos/Lefters.png',
      'name': 'Lefters CF',
      'year': '2025',
      'matches': 45,
      'goals': 123,
      'assists': 32,
      'tackles': 89,
      'yellowCards': 2,
      'redCards': 1,
      'saves': 0,
      'minutesPlayed': 4050,
      'rating': 8.5,
    },
    {
      'logo': 'lib/assets/team logos/The Shield.png',
      'name': 'The Shield',
      'year': '2025',
      'matches': 23,
      'goals': 72,
      'assists': 21,
      'tackles': 56,
      'yellowCards': 0,
      'redCards': 0,
      'saves': 0,
      'minutesPlayed': 2070,
      'rating': 7.8,
    },
    {
      'logo': 'lib/assets/team logos/Galacticos.png',
      'name': 'Galacticos',
      'year': '2024',
      'matches': 56,
      'goals': 151,
      'assists': 34,
      'tackles': 124,
      'yellowCards': 5,
      'redCards': 0,
      'saves': 12,
      'minutesPlayed': 5040,
      'rating': 8.9,
    },
  ];

  Widget _buildStatIcon(String svgPath, BuildContext context) {
    return SizedBox(
      width: 13,
      height: 13,
      child: SvgPicture.asset(svgPath, width: 13, height: 13),
    );
  }

  Widget _buildStatValue(dynamic value, BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    // Format rating to 1 decimal place, minutes with comma separator
    String displayValue;
    if (value is double) {
      displayValue = value.toStringAsFixed(1);
    } else if (value is int && value >= 1000) {
      displayValue = value.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
    } else {
      displayValue = value.toString();
    }

    return Text(
      displayValue,
      style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text('Team stats', style: textTheme.titleSmall),
          const SizedBox(height: 16),
          // Header row with fixed team column and scrollable stats
          Row(
            children: [
              // Fixed team column
              SizedBox(
                width: 120,
                child: Text(
                  'Team',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              // Scrollable stat icons
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: _statCategories.asMap().entries.map((entry) {
                      final index = entry.key;
                      final category = entry.value;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 60,
                            height: 13,
                            child: Center(
                              child: _buildStatIcon(category['svg']!, context),
                            ),
                          ),
                          if (index < _statCategories.length - 1)
                            const SizedBox(width: 8),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Team rows
          ..._teamStats.asMap().entries.map((entry) {
            final index = entry.key;
            final team = entry.value;

            return Column(
              children: [
                Row(
                  children: [
                    // Fixed team info
                    SizedBox(
                      width: 120,
                      child: Row(
                        children: [
                          // Team logo
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.transparent,
                            backgroundImage: AssetImage(team['logo'] as String),
                          ),
                          const SizedBox(width: 12),
                          // Team name and year
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  team['name'] as String,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  team['year'] as String,
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
                    // Scrollable stat values
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _rowScrollControllers[index],
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: _statCategories.asMap().entries.map((
                            catEntry,
                          ) {
                            final catIndex = catEntry.key;
                            final category = catEntry.value;
                            final value = team[category['key']];

                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 60,
                                  child: Center(
                                    child: _buildStatValue(value, context),
                                  ),
                                ),
                                if (catIndex < _statCategories.length - 1)
                                  const SizedBox(width: 8),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
                // Divider between items (except after the last one)
                if (index < _teamStats.length - 1) ...[
                  const SizedBox(height: 12),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _AttributesSection extends StatelessWidget {
  const _AttributesSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and info icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Attributes', style: Theme.of(context).textTheme.titleSmall),
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () {
                  // TODO: Show attributes info
                },
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Radar chart
          SizedBox(height: 300, child: _AttributesRadarChart()),
          const SizedBox(height: 8),
          // Timeline slider
          _TimelineSlider(),
          const SizedBox(height: 16),
          // Profile icon and search field row
          Row(
            children: [
              // Profile icon
              CircleAvatar(
                radius: 20,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Icon(
                  Icons.person,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 8),
              // Text field
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'Search to compare',
                    filled: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NextMatchSection extends StatelessWidget {
  const _NextMatchSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "Next match" title
          Text('Next match', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 16),
          // Match details
          Column(
            children: [
              // Team A, match time, Team B row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Team A with logo
                  Row(
                    children: [
                      Text(
                        'Galacticos',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.transparent,
                        backgroundImage: const AssetImage(
                          'lib/assets/team logos/Galacticos.png',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Match time
                  Text('17:00', style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(width: 16),
                  // Team B with logo
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.transparent,
                        backgroundImage: const AssetImage(
                          'lib/assets/team logos/Lefters.png',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Lefters CF',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // League name and date row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Bugujju league',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(width: 4),
                  Text('·', style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(width: 4),
                  Text(
                    'Mon 15 Dec',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeamFormSection extends StatefulWidget {
  const _TeamFormSection();

  @override
  State<_TeamFormSection> createState() => _TeamFormSectionState();
}

class _TeamFormSectionState extends State<_TeamFormSection> {
  String? _selectedTeam = 'Lefters CF';

  // Sample match results data
  final List<Map<String, dynamic>> _matchResults = [
    {
      'gameweek': 'GW6',
      'opponentLogo': 'lib/assets/team logos/Dragons.png',
      'opponentShort': 'DRA',
      'score': '2-2',
      'result': 'draw', // 'win', 'loss', 'draw'
    },
    {
      'gameweek': 'GW7',
      'opponentLogo': 'lib/assets/team logos/Galacticos.png',
      'opponentShort': 'GAL',
      'score': '1-0',
      'result': 'win',
    },
    {
      'gameweek': 'GW8',
      'opponentLogo': 'lib/assets/team logos/La Famille.png',
      'opponentShort': 'LAF',
      'score': '1-1',
      'result': 'draw',
    },
    {
      'gameweek': 'GW9',
      'opponentLogo': 'lib/assets/team logos/End Career FC.png',
      'opponentShort': 'EFC',
      'score': '0-1',
      'result': 'loss',
    },
    {
      'gameweek': 'GW10',
      'opponentLogo': 'lib/assets/team logos/The Shield.png',
      'opponentShort': 'SHI',
      'score': '4-1',
      'result': 'win',
    },
  ];

  Widget _buildTeamChip({
    required BuildContext context,
    required String teamName,
    required String logoPath,
    required bool isSelected,
    required ValueChanged<bool> onSelected,
  }) {
    return FilterChip(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      avatar: ClipOval(
        child: Image.asset(logoPath, width: 24, height: 24, fit: BoxFit.cover),
      ),
      label: Text(teamName),
      selected: isSelected,
      onSelected: onSelected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text('Team form', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          // Team chips row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTeamChip(
                  context: context,
                  teamName: 'Lefters CF',
                  logoPath: 'lib/assets/team logos/Lefters.png',
                  isSelected: _selectedTeam == 'Lefters CF',
                  onSelected: (selected) {
                    setState(() {
                      _selectedTeam = selected ? 'Lefters CF' : null;
                    });
                  },
                ),
                const SizedBox(width: 8),
                _buildTeamChip(
                  context: context,
                  teamName: 'Galacticos',
                  logoPath: 'lib/assets/team logos/Galacticos.png',
                  isSelected: _selectedTeam == 'Galacticos',
                  onSelected: (selected) {
                    setState(() {
                      _selectedTeam = selected ? 'Galacticos' : null;
                    });
                  },
                ),
                const SizedBox(width: 8),
                _buildTeamChip(
                  context: context,
                  teamName: 'Dragons',
                  logoPath: 'lib/assets/team logos/Dragons.png',
                  isSelected: _selectedTeam == 'Dragons',
                  onSelected: (selected) {
                    setState(() {
                      _selectedTeam = selected ? 'Dragons' : null;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Match results row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _matchResults.asMap().entries.map((entry) {
                  final index = entry.key;
                  final match = entry.value;
                  Color scoreColor;
                  if (match['result'] == 'win') {
                    scoreColor = Colors.green;
                  } else if (match['result'] == 'loss') {
                    scoreColor = Colors.red;
                  } else {
                    scoreColor = Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest;
                  }

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        children: [
                          // Game week
                          Text(
                            match['gameweek'] as String,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          // Team logo
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.transparent,
                            backgroundImage: AssetImage(
                              match['opponentLogo'] as String,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Team short form
                          Text(
                            match['opponentShort'] as String,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          // Score pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: scoreColor,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              match['score'] as String,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: match['result'] == 'draw'
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onSurface
                                        : Colors.white,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      if (index < _matchResults.length - 1)
                        const SizedBox(width: 24),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClubHistorySection extends StatefulWidget {
  const _ClubHistorySection();

  @override
  State<_ClubHistorySection> createState() => _ClubHistorySectionState();
}

class _ClubHistorySectionState extends State<_ClubHistorySection> {
  // Sample club history data
  final List<Map<String, dynamic>> _clubHistory = const [
    {
      'logo': 'lib/assets/team logos/End Career FC.png',
      'name': 'End Career FC',
      'yearsActive': '2025 - Now',
      'isCurrent': true,
    },
    {
      'logo': 'lib/assets/team logos/The Shield.png',
      'name': 'The Shield',
      'yearsActive': '2023 - Now',
      'isCurrent': true,
    },
    {
      'logo': 'lib/assets/team logos/Galacticos.png',
      'name': 'Galacticos',
      'yearsActive': '2022 - 2023',
      'isCurrent': false,
    },
    {
      'logo': 'lib/assets/team logos/La Famille.png',
      'name': 'LaFamille FC',
      'yearsActive': '2020 - 2022',
      'isCurrent': false,
    },
  ];

  // Track button states (true = "Leave", false = "Join")
  late Map<String, bool> _buttonStates;

  @override
  void initState() {
    super.initState();
    // Initialize button states based on initial isCurrent values
    _buttonStates = Map.fromEntries(
      _clubHistory.map(
        (club) => MapEntry(club['name'] as String, club['isCurrent'] as bool),
      ),
    );
  }

  void _toggleButton(String clubName) {
    setState(() {
      _buttonStates[clubName] = !(_buttonStates[clubName] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text('Club history', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 16),
          // Club list
          ..._clubHistory.asMap().entries.map((entry) {
            final index = entry.key;
            final club = entry.value;
            final clubName = club['name'] as String;
            final isLeaveButton = _buttonStates[clubName] ?? false;

            return Column(
              children: [
                Row(
                  children: [
                    // Logo
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.transparent,
                      backgroundImage: AssetImage(club['logo'] as String),
                    ),
                    const SizedBox(width: 16),
                    // Club name and years
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            clubName,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            club['yearsActive'] as String,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    // Leave/Join button
                    OutlinedButton(
                      onPressed: () {
                        _toggleButton(clubName);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        isLeaveButton ? 'Leave' : 'Join',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  ],
                ),
                // Divider between items (except after the last one)
                if (index < _clubHistory.length - 1) ...[
                  const SizedBox(height: 8),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _TrophiesSection extends StatefulWidget {
  const _TrophiesSection();

  @override
  State<_TrophiesSection> createState() => _TrophiesSectionState();
}

class _TrophiesSectionState extends State<_TrophiesSection> {
  String? _selectedTeam = 'Lefters CF';

  // Sample trophies data
  final List<Map<String, dynamic>> _trophies = const [
    {
      'logoPath': 'lib/assets/trophies/bugujju league.png',
      'name': 'Bugujju league',
      'years': '2025',
      'count': 1,
    },
    {
      'logoPath': 'lib/assets/trophies/inter uni league.png',
      'name': 'Inter-uni league',
      'years': '2023, 2024',
      'count': 2,
    },
    {
      'logoPath': 'lib/assets/trophies/budo league.png',
      'name': 'The Budo league',
      'years': '2019, 2020, 2023, 2024',
      'count': 4,
    },
    {
      'logoPath': 'lib/assets/trophies/turf champi.png',
      'name': 'Turf-champi',
      'years': '2016',
      'count': 1,
    },
  ];

  Widget _buildTeamChip({
    required BuildContext context,
    required String teamName,
    required String logoPath,
    required bool isSelected,
    required ValueChanged<bool> onSelected,
  }) {
    return FilterChip(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      avatar: ClipOval(
        child: Image.asset(logoPath, width: 24, height: 24, fit: BoxFit.cover),
      ),
      label: Text(teamName),
      selected: isSelected,
      onSelected: onSelected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text('Trophies', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          // Team chips row (same as team form section)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTeamChip(
                  context: context,
                  teamName: 'Lefters CF',
                  logoPath: 'lib/assets/team logos/Lefters.png',
                  isSelected: _selectedTeam == 'Lefters CF',
                  onSelected: (selected) {
                    setState(() {
                      _selectedTeam = selected ? 'Lefters CF' : null;
                    });
                  },
                ),
                const SizedBox(width: 8),
                _buildTeamChip(
                  context: context,
                  teamName: 'Galacticos',
                  logoPath: 'lib/assets/team logos/Galacticos.png',
                  isSelected: _selectedTeam == 'Galacticos',
                  onSelected: (selected) {
                    setState(() {
                      _selectedTeam = selected ? 'Galacticos' : null;
                    });
                  },
                ),
                const SizedBox(width: 8),
                _buildTeamChip(
                  context: context,
                  teamName: 'Dragons',
                  logoPath: 'lib/assets/team logos/Dragons.png',
                  isSelected: _selectedTeam == 'Dragons',
                  onSelected: (selected) {
                    setState(() {
                      _selectedTeam = selected ? 'Dragons' : null;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Trophies list
          ..._trophies.asMap().entries.map((entry) {
            final index = entry.key;
            final trophy = entry.value;
            return Column(
              children: [
                Row(
                  children: [
                    // Trophy logo (36x36)
                    Image.asset(
                      trophy['logoPath'] as String,
                      width: 36,
                      height: 36,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return SizedBox(
                          width: 36,
                          height: 36,
                          child: Icon(
                            Icons.emoji_events,
                            size: 24,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 16),
                    // Trophy name and years
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trophy['name'] as String,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            trophy['years'] as String,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    // Trophy count (bodyLarge, bold)
                    Text(
                      (trophy['count'] as int).toString(),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                // Divider between items (except after the last one)
                if (index < _trophies.length - 1) ...[
                  const SizedBox(height: 8),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _BadgesSection extends StatelessWidget {
  const _BadgesSection();

  // Sample badges data
  final List<Map<String, dynamic>> _badges = const [
    {
      'svgPath': 'lib/assets/badges/Pro.svg',
      'points': '+10',
      'name': 'Iron-foot',
      'objective': 'Score 100 goals',
      'progress': 0.5, // 50%
    },
    {
      'svgPath': 'lib/assets/badges/Master.svg',
      'points': '+10',
      'name': 'Lock-down defender 💪',
      'objective': 'Make 100 tackles',
      'progress': 1.0, // 100%
    },
    {
      'svgPath': 'lib/assets/badges/Legendary.svg',
      'points': '+100',
      'name': 'Footy Master',
      'objective': 'Reach 10K goals',
      'progress': 0.8, // 80%
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and info icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Badges', style: Theme.of(context).textTheme.titleSmall),
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () {
                  // TODO: Show badges info
                },
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Badges list
          ..._badges.asMap().entries.map((entry) {
            final index = entry.key;
            final badge = entry.value;
            final progress = badge['progress'] as double;
            final percentage = (progress * 100).round();

            return Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge icon (SVG from assets)
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: SvgPicture.asset(
                        badge['svgPath'] as String,
                        width: 36,
                        height: 36,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.emoji_events,
                            size: 24,
                            color: Theme.of(context).colorScheme.primary,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Points indicator
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        badge['points'] as String,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Badge name, objective, and progress
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Badge name
                          Text(
                            badge['name'] as String,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          // Objective
                          Text(
                            badge['objective'] as String,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 8),
                          // Progress bar
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 2,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      year2023: false,
                                      value: progress,
                                      minHeight: 2,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Percentage
                              Text(
                                '$percentage%',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Divider between items (except after the last one)
                if (index < _badges.length - 1) ...[
                  const SizedBox(height: 16),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _TimelineSlider extends StatefulWidget {
  const _TimelineSlider();

  @override
  State<_TimelineSlider> createState() => _TimelineSliderState();
}

class _TimelineSliderState extends State<_TimelineSlider> {
  double _currentValue = 0; // 0 = 2020, 1 = 2021, ..., 5 = 2025
  final List<int> _years = [2020, 2021, 2022, 2023, 2024, 2025];

  @override
  Widget build(BuildContext context) {
    return Slider(
      year2023: false,
      value: _currentValue,
      min: 0,
      max: 5,
      divisions: 5,
      label: _years[_currentValue.round()].toString(),
      onChanged: (double value) {
        setState(() {
          _currentValue = value;
        });
      },
    );
  }
}

class _AttributesRadarChart extends StatelessWidget {
  const _AttributesRadarChart();

  @override
  Widget build(BuildContext context) {
    // Attribute values: SHA, DIS, CAC, DEF, GK
    final attributes = [
      {'name': 'SHA', 'value': 120, 'color': Colors.green},
      {'name': 'DIS', 'value': 47, 'color': Colors.grey},
      {'name': 'CAC', 'value': 62, 'color': Colors.amber},
      {'name': 'DEF', 'value': 36, 'color': Colors.grey},
      {'name': 'GK', 'value': 0, 'color': Colors.red},
    ];

    return RadarChart(
      RadarChartData(
        radarShape: RadarShape.polygon,
        dataSets: [
          RadarDataSet(
            fillColor: Theme.of(
              context,
            ).colorScheme.primaryContainer.withOpacity(0.3),
            borderColor: Theme.of(context).colorScheme.primaryContainer,
            borderWidth: 2,
            dataEntries: attributes
                .map((attr) => RadarEntry(value: attr['value'] as double))
                .toList(),
          ),
        ],
        radarBackgroundColor: Colors.transparent,
        radarBorderData: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          width: 1,
        ),
        tickBorderData: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          width: 1,
        ),
        gridBorderData: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          width: 1,
        ),
        ticksTextStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 10,
        ),
        tickCount: 4,
        getTitle: (index, angle) {
          final attr = attributes[index];
          return RadarChartTitle(
            text: attr['name'] as String,
            angle: angle,
            positionPercentageOffset: 0.15,
          );
        },
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 412,
      height: 356,
      child: Stack(
        children: [
          // Background container with primaryContainer color
          Container(
            width: 412,
            height: 356,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          // Background overlay image with multiply blend mode
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Color(0xff81d99a),
                BlendMode.multiply,
              ),
              child: Image.asset(
                'lib/assets/bg overlay.png',
                width: 412,
                height: 356,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          // Edit button in upper right corner
          Positioned(
            top: 16,
            right: 16,
            child: FilledButton.tonal(
              onPressed: () {
                // TODO: Implement edit profile
              },
              style: FilledButton.styleFrom(
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
                padding: const EdgeInsets.only(
                  left: 17,
                  right: 17,
                  top: 12,
                  bottom: 12,
                ),
                minimumSize: const Size(60, 40),
              ),
              child: const Icon(Icons.edit_outlined, size: 20),
            ),
          ),
          // Player image aligned to baseline (bottom) of container
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset(
                'lib/assets/player.png',
                width: 248,
                height: 318,
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          // Gradient overlay fading from bottom to top
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Container(
              width: 412,
              height: 356,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.2), Colors.transparent],
                ),
              ),
            ),
          ),
          // Text overlay at the bottom
          Positioned(
            bottom: 80,
            left: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gareth',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@gareth_neville3',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          // Action chips at the bottom (horizontally scrollable)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  _ActionChip(
                    svgPath: 'lib/assets/position.svg',
                    label: 'Defender',
                    context: context,
                  ),
                  const SizedBox(width: 8),
                  _ActionChip(
                    icon: Icons.groups_outlined,
                    label: '12K',
                    context: context,
                  ),
                  const SizedBox(width: 8),
                  _ActionChip(
                    icon: Icons.bar_chart_outlined,
                    label: '3',
                    context: context,
                  ),
                  const SizedBox(width: 8),
                  _ActionChip(
                    icon: Icons.public_outlined,
                    label: 'Uganda',
                    context: context,
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

class _VideoTabHeader extends StatelessWidget {
  const _VideoTabHeader();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left side: Sort icon and text
        Row(
          children: [
            Icon(Icons.swap_vert, size: 20, color: colorScheme.onSurface),
            const SizedBox(width: 8),
            Text(
              'Oldest',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        // Right side: View toggle icon
        Icon(Icons.view_list, size: 20, color: colorScheme.onSurface),
      ],
    );
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 121.33,
      height: 204,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Image.asset(
          'lib/assets/highlight_placeholder.jpg',
          width: 121.33,
          height: 204,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 121.33,
              height: 204,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.play_circle_outline,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData? icon;
  final String? svgPath;
  final String label;
  final BuildContext context;

  const _ActionChip({
    this.icon,
    this.svgPath,
    required this.label,
    required this.context,
  }) : assert(
         icon != null || svgPath != null,
         'Either icon or svgPath must be provided',
       );

  @override
  Widget build(BuildContext context) {
    Widget avatar;
    if (svgPath != null) {
      avatar = SvgPicture.asset(
        svgPath!,
        width: 18,
        height: 18,
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      );
    } else {
      avatar = Icon(icon, size: 18, color: Colors.white);
    }

    return ActionChip.elevated(
      avatar: avatar,
      label: Text(label, style: const TextStyle(color: Colors.white)),
      onPressed: () {
        // TODO: Handle chip action
      },
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999), // Fully rounded
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}
