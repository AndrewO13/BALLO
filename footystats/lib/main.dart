import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'util.dart';
import 'theme.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'pages/matches.dart';
import 'pages/leaderboard.dart';
import 'package:fl_chart/fl_chart.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final brightness = View.of(context).platformDispatcher.platformBrightness;

    // Retrieves the default theme for the platform
    //TextTheme textTheme = Theme.of(context).textTheme;

    // Use with Google Fonts package to use downloadable fonts
    TextTheme textTheme = createTextTheme(context, "Roboto", "Roboto");

    MaterialTheme theme = MaterialTheme(textTheme);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FootyStats',
      theme: brightness == Brightness.light ? theme.light() : theme.dark(),
      home: const MyHomePage(title: 'Home'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;
  String? _selectedTeam;
  final CarouselController _matchCarouselController = CarouselController(
    initialItem: 1,
  );
  final CarouselController _highlightsCarouselController = CarouselController(
    initialItem: 0,
  );

  @override
  void dispose() {
    _matchCarouselController.dispose();
    _highlightsCarouselController.dispose();
    super.dispose();
  }

  Widget _buildChallenge(BuildContext context) {
    // final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 120,
      height: 40,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            width: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(width: 16),
            SvgPicture.asset('lib/assets/challenge.svg', width: 24, height: 24),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('+10', style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(width: 20),
                    Text(
                      '50%',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 60,
                  height: 2,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      year2023: false,
                      value: 0.5,
                      minHeight: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeHeader(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: kToolbarHeight,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(width: 16),
                  _buildChallenge(context),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: IconButton(
                      icon: const Icon(Icons.chat_bubble_outline),
                      onPressed: () {},
                      tooltip: 'Messages',
                    ),
                  ),
                ],
              ),
            ),

            Center(
              child: SizedBox(
                height: 32,
                child: SvgPicture.asset(
                  'lib/assets/footystats logo.svg',
                  height: 32,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  Widget _buildBarChart(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Sample data for GW3-GW10 (ratings)
    final gameweekData = [
      {'week': 'GW3', 'rating': 4.5},
      {'week': 'GW4', 'rating': 6.0},
      {'week': 'GW5', 'rating': 7.5},
      {'week': 'GW6', 'rating': 3.0},
      {'week': 'GW7', 'rating': 10.0}, // Exceptional performance
      {'week': 'GW8', 'rating': 7.0},
      {'week': 'GW9', 'rating': 7.5},
      {'week': 'GW10', 'rating': 5.0},
    ];

    final maxRating = 10.0;

    return SizedBox(
      height: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chart area
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxRating,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < gameweekData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              gameweekData[index]['week'] as String,
                              style: textTheme.labelSmall,
                            ),
                          );
                        }
                        return const Text('');
                      },
                      reservedSize: 40,
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: gameweekData.asMap().entries.map((entry) {
                  final index = entry.key;
                  final data = entry.value;
                  final rating = data['rating'] as double;
                  final isExceptional = rating >= 8.0;
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: rating,
                        color: isExceptional
                            ? const Color(0xff14ff8e)
                            : const Color(0xfff2fff1),
                        width: 38,
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ],
                    barsSpace: 8,
                  );
                }).toList(),
              ),
            ),
          ),
          // Y-axis labels on the right
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: SizedBox(
              height: 163,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [10, 5, 0].map((value) {
                  return Text(value.toString(), style: textTheme.labelSmall);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamDetailsCard(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image header with team info overlay
          Stack(
            children: [
              Container(
                height: 204,
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.grey[800]),
                child: Image.asset(
                  'lib/assets/team banner.JPG',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(color: Colors.grey[800]);
                  },
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lefters F.C',
                      style: textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            offset: const Offset(0, 1),
                            blurRadius: 3,
                            color: Colors.black.withOpacity(0.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Est. 2025',
                      style: textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            offset: const Offset(0, 1),
                            blurRadius: 3,
                            color: Colors.black.withOpacity(0.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Stats row with action chips
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              alignment: WrapAlignment.start,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.sports_soccer, size: 18),
                  label: const Text('2K'),
                  onPressed: () {},
                ),
                ActionChip(
                  avatar: const Icon(Icons.sports_score_outlined, size: 18),
                  label: const Text('340'),
                  onPressed: () {},
                ),
                ActionChip(
                  avatar: const Icon(Icons.emoji_events_outlined, size: 18),
                  label: const Text('10'),
                  onPressed: () {},
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 4.0, start: 16.0),
            child: Text('Table', style: Theme.of(context).textTheme.titleSmall),
          ),
          const SizedBox(height: 8),
          // Standings table
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(0.8), // Pos
                1: FlexColumnWidth(0.6), // Change indicator (up/down/dash)
                2: FlexColumnWidth(2.4), // Team
                3: FlexColumnWidth(0.8),
                4: FlexColumnWidth(0.8),
                5: FlexColumnWidth(0.8),
                6: FlexColumnWidth(0.8),
                7: FlexColumnWidth(0.8),
                8: FlexColumnWidth(0.8),
              },
              children: [
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'Pos',
                        style: textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: SizedBox(
                        height: 20,
                        child: Center(child: Text('')),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('Team', style: textTheme.bodySmall),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'PL',
                        style: textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'W',
                        style: textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'L',
                        style: textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'D',
                        style: textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'GD',
                        style: textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'Pts',
                        style: textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                _buildStandingsRow(
                  context,
                  1,
                  'GAL',
                  23,
                  83,
                  12,
                  10,
                  18,
                  19,
                  1, // moved up
                  true,
                ),
                _buildStandingsRow(
                  context,
                  2,
                  'LFC',
                  23,
                  83,
                  12,
                  10,
                  18,
                  15,
                  -1, // moved down
                  false,
                ),
                _buildStandingsRow(
                  context,
                  3,
                  'DRA',
                  23,
                  83,
                  12,
                  10,
                  18,
                  3,
                  0, // no change
                  false,
                ),
              ],
            ),
          ),
          // Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: () {
                  // Handle button press
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  minimumSize: const Size(99, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Text('View team'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  TableRow _buildStandingsRow(
    BuildContext context,
    int position,
    String team,
    int played,
    int wins,
    int losses,
    int draws,
    int goalDiff,
    int points,
    int positionChange,
    bool isHighlighted,
  ) {
    final textTheme = Theme.of(context).textTheme;
    // final colorScheme = Theme.of(context).colorScheme;

    return TableRow(
      decoration: isHighlighted
          ? BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(30),
            )
          : null,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Text(
            position.toString(),
            style: textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: SizedBox(
            height: 20,
            child: Center(
              child: positionChange > 0
                  ? const Icon(
                      Icons.arrow_drop_up,
                      color: Color(0xff39ff14),
                      size: 18,
                    )
                  : positionChange < 0
                  ? const Icon(
                      Icons.arrow_drop_down,
                      color: Color(0xffff0000),
                      size: 18,
                    )
                  : Icon(
                      Icons.remove,
                      color: Theme.of(context).colorScheme.outline,
                      size: 16,
                    ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Row(
            children: [
              ClipOval(
                child: Image.asset(
                  'lib/assets/team logos/${team == 'LFC'
                      ? 'Lefters'
                      : team == 'GAL'
                      ? 'Galacticos'
                      : 'Dragons'}.png',
                  width: 24,
                  height: 24,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox(width: 24, height: 24);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  team,
                  style: textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Text(
            played.toString(),
            style: textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Text(
            wins.toString(),
            style: textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Text(
            losses.toString(),
            style: textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Text(
            draws.toString(),
            style: textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Text(
            goalDiff.toString(),
            style: textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Text(
            points.toString(),
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildGameweekHeader(BuildContext context) {
    // use titleMedium directly for the Gameweek title
    return SizedBox(
      height: 48, // approximate height for IconButtons
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Row holds left and right items and doesn't affect the centered title
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // chevrons group
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      // navigate to previous week (placeholder)
                    },
                    tooltip: 'Previous',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: null, // disabled but visible
                    tooltip: 'Next (disabled)',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const Spacer(),
              // Edit icon on right
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () {},
                tooltip: 'Edit',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          // Center title relative to the page width
          Center(
            child: Text(
              'Gameweek 11',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    final pageTitles = ['Home', 'Matches', 'Leaderboard', 'Explore', 'Account'];

    final PreferredSizeWidget appBar = _selectedIndex == 0
        ? AppBar(
            automaticallyImplyLeading: false,
            toolbarHeight: kToolbarHeight,
            elevation: 0,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            title: Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  children: [
                    _buildChallenge(context),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline),
                      onPressed: () {},
                      tooltip: 'Messages',
                    ),
                  ],
                ),
                Center(
                  child: SizedBox(
                    height: 32,
                    child: SvgPicture.asset(
                      'lib/assets/footystats logo.svg',
                      height: 32,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
          )
        : (_selectedIndex == 1
              ? AppBar(
                  automaticallyImplyLeading: false,
                  title: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      pageTitles[_selectedIndex],
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () {},
                      tooltip: 'Search',
                    ),
                  ],
                  elevation: 0,
                )
              : AppBar(
                  title: Text(
                    pageTitles[_selectedIndex],
                    style: _selectedIndex == 2
                        ? Theme.of(context).textTheme.headlineMedium
                        : null,
                  ),
                  centerTitle: false,
                  automaticallyImplyLeading: false,
                ));

    return Scaffold(
      appBar: appBar,
      floatingActionButton: _selectedIndex == 1
          ? FloatingActionButton(
              onPressed: () {
                // TODO: implement add-match action
              },
              tooltip: 'Add',
              child: const Icon(Icons.add),
            )
          : null,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // Home content (existing body)
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Home header removed, now in AppBar
                  const SizedBox(height: 8),
                  Text(
                    "What's up Gareth!",
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Let's hit the turf",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildGameweekHeader(context),
                  const SizedBox(height: 0),
                  Column(
                    children: [
                      Center(
                        child: ProgressRing(
                          size: 163,
                          progress: 0.9, // 9 out of 10 tackles won
                          valueText: '9',
                          labelText: 'Tackles won',
                          icon: SvgPicture.asset(
                            'lib/assets/tackle.svg',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ProgressRing(
                            size: 80,
                            progress: 0.0, // 0 assists
                            valueText: '0',
                            labelText: 'assists',
                            icon: SvgPicture.asset(
                              'lib/assets/assist.svg',
                              fit: BoxFit.contain,
                            ),
                          ),
                          ProgressRing(
                            size: 80,
                            progress: 1.0, // 2 clean sheets (at goal)
                            valueText: '2',
                            labelText: 'clean sheets',
                            icon: Image.asset(
                              'lib/assets/clean sheet.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 26),
                  Center(
                    child: Container(
                      width: 380,
                      height: 365,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Performance',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 16),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildTeamChip(
                                    context: context,
                                    teamName: 'Lefters',
                                    logoPath:
                                        'lib/assets/team logos/Lefters.png',
                                    isSelected: _selectedTeam == 'Lefters',
                                    onSelected: (selected) {
                                      setState(() {
                                        _selectedTeam = selected
                                            ? 'Lefters'
                                            : null;
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 5.0),
                                  _buildTeamChip(
                                    context: context,
                                    teamName: 'Galacticos',
                                    logoPath:
                                        'lib/assets/team logos/Galacticos.png',
                                    isSelected: _selectedTeam == 'Galacticos',
                                    onSelected: (selected) {
                                      setState(() {
                                        _selectedTeam = selected
                                            ? 'Galacticos'
                                            : null;
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 5.0),
                                  _buildTeamChip(
                                    context: context,
                                    teamName: 'Dragons FC',
                                    logoPath:
                                        'lib/assets/team logos/Dragons.png',
                                    isSelected: _selectedTeam == 'Dragons FC',
                                    onSelected: (selected) {
                                      setState(() {
                                        _selectedTeam = selected
                                            ? 'Dragons FC'
                                            : null;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildBarChart(context),
                            const SizedBox(height: 0),
                            Text(
                              'Average rating per game week',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 26),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      top: 8.0,
                      start: 0.0,
                    ),
                    child: Text(
                      'This week',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height / 4,
                    ),
                    child: CarouselView.weighted(
                      controller: _matchCarouselController,
                      itemSnapping: true,
                      flexWeights: const <int>[1, 4, 1],
                      children: MatchInfo.values.map((MatchInfo match) {
                        return _MatchCard(matchInfo: match);
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      top: 0.0,
                      start: 308.0,
                    ),
                    child: Text(
                      'Show all',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      top: 8.0,
                      start: 0.0,
                    ),
                    child: Text(
                      'Team',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildTeamDetailsCard(context),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      top: 8.0,
                      start: 0.0,
                    ),
                    child: Text(
                      'Highlights🔥',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Highlights carousel (9:16 thumbnails)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 204),
                    child: CarouselView.weighted(
                      controller: _highlightsCarouselController,
                      itemSnapping: true,
                      consumeMaxWeight: false,
                      flexWeights: const <int>[3, 3, 2, 1],
                      children: List<Widget>.generate(6, (index) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 115.43,
                            height: 204,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Image.asset(
                                    'lib/assets/highlight_placeholder.JPG',
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                      );
                                    },
                                  ),
                                ),
                                Center(
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.play_arrow,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      top: 0.0,
                      start: 308.0,
                    ),
                    child: Text(
                      'Show all',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(height: 26),
                ],
              ),
            ),
          ),
          // Matches and other pages
          const MatchesPage(),
          const LeaderboardPage(),
          Center(
            child: Text(
              'Explore page',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Center(
            child: Text(
              'Account page',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ],
      ),
      bottomNavigationBar: Builder(
        builder: (context) {
          const navDestinations = <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.sports_score_outlined),
              selectedIcon: Icon(Icons.sports_score),
              label: 'Matches',
            ),
            NavigationDestination(
              icon: Icon(Icons.leaderboard_outlined),
              selectedIcon: Icon(Icons.leaderboard),
              label: 'Leaderboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: 'Explore',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_circle_outlined),
              selectedIcon: Icon(Icons.account_circle),
              label: 'Account',
            ),
          ];

          final safeIndex =
              (_selectedIndex >= 0 && _selectedIndex < navDestinations.length)
              ? _selectedIndex
              : 0;

          return NavigationBar(
            selectedIndex: safeIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            destinations: navDestinations,
          );
        },
      ),
    );
  }
}

enum MatchInfo {
  match0(
    'Bugujju league',
    'GW11',
    'LCF',
    'GAL',
    '0',
    '0',
    '49:30',
    'lib/assets/team logos/Lefters.png',
    'lib/assets/team logos/Galacticos.png',
  ),
  match1(
    'Bugujju league',
    'GW11',
    'LCF',
    'LAF',
    '6',
    '1',
    'FT',
    'lib/assets/team logos/Lefters.png',
    'lib/assets/team logos/La Famille.png',
  ),
  match2(
    'Bugujju league',
    'GW11',
    'EFC',
    'GAL',
    '1',
    '2',
    'FT',
    'lib/assets/team logos/Dragons.png',
    'lib/assets/team logos/Galacticos.png',
  );

  const MatchInfo(
    this.league,
    this.gameweek,
    this.team1,
    this.team2,
    this.score1,
    this.score2,
    this.time,
    this.logo1,
    this.logo2,
  );
  final String league;
  final String gameweek;
  final String team1;
  final String team2;
  final String score1;
  final String score2;
  final String time;
  final String logo1;
  final String logo2;
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.matchInfo});

  final MatchInfo matchInfo;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRect(
      child: OverflowBox(
        maxWidth: width * 7 / 8,
        minWidth: width * 7 / 8,
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(28),
          ),
          padding: const EdgeInsetsDirectional.only(
            start: 70.0,
            end: 70.0,
            top: 16.0,
            bottom: 0.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(matchInfo.league, style: textTheme.titleSmall),
                  Text(matchInfo.gameweek, style: textTheme.titleSmall),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        ClipOval(
                          child: Image.asset(
                            matchInfo.logo1,
                            width: 46.4,
                            height: 46.4,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          matchInfo.team1,
                          style: textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            matchInfo.score1,
                            style: textTheme.displayMedium,
                          ),
                          Text(' - ', style: textTheme.displayMedium),
                          Text(
                            matchInfo.score2,
                            style: textTheme.displayMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 0,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          matchInfo.time,
                          style: textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        ClipOval(
                          child: Image.asset(
                            matchInfo.logo2,
                            width: 46.4,
                            height: 46.4,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          matchInfo.team2,
                          style: textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ActionChip(
                    label: Text('1.8'),
                    onPressed: () {
                      // Handle betting odds click
                    },
                    backgroundColor: colorScheme.surfaceContainerHigh,
                  ),
                  ActionChip(
                    label: Text('2.1'),
                    onPressed: () {
                      // Handle betting odds click
                    },
                    backgroundColor: colorScheme.surfaceContainerHigh,
                  ),
                  ActionChip(
                    label: Text('1.3'),
                    onPressed: () {
                      // Handle betting odds click
                    },
                    backgroundColor: colorScheme.surfaceContainerHigh,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.size,
    required this.progress,
    required this.valueText,
    required this.labelText,
    this.icon,
  });

  final double size;
  final double progress; // 0..1
  final String valueText;
  final String labelText;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Separate positioning for large (163) and small (75) rings
    final bool isLarge = size >= 163;
    final double iconSize = isLarge ? 70 : 32;
    final double topOffset = isLarge ? 65 : 52;
    final double bottomOffset = isLarge ? -2 : 6;
    final double extraHeight = isLarge ? 30 : 65;

    // Determine value text style based on ring size
    final valueTextStyle = size >= 163
        ? textTheme.displaySmall?.copyWith(height: 1.0)
        : textTheme.headlineSmall?.copyWith(height: 1.0);

    // Label text style for all rings
    final labelTextStyle = textTheme.labelLarge?.copyWith();

    final defaultIcon = Icon(
      Icons.sports_soccer,
      size: iconSize,
      color: Colors.white,
    );

    return SizedBox(
      width: size,
      height: size + extraHeight, // extra space for label
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(progress: progress, ringSize: size),
          ),
          // Center icon
          Positioned(
            top: topOffset,
            child: icon != null
                ? SizedBox(width: iconSize, height: iconSize, child: icon)
                : defaultIcon,
          ),
          Positioned(
            bottom: bottomOffset,
            child: Column(
              children: [
                Text(valueText, style: valueTextStyle),
                const SizedBox(height: 2),
                Text(labelText, style: labelTextStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.ringSize});

  final double progress;
  final double ringSize;

  // ===== Exact specs you gave =====
  static const double startAngleDeg = 57.75;

  // "ratio of 83.25%" -> used as a multiplier on sweeps (so the arc is not a full 360°)
  static const double ratio = 0.8325;

  // Sweeps are given as percentages (fractions) and are NEGATIVE.
  static const double whiteBaseSweep = 0.005; // -0.5%
  static const double greenBaseSweep = 0.792; // -79.2%
  static const double whiteSweepAt100 = 0.82; // -82% at 100%

  static const double whiteRotationDeg = 158.75;
  static const double greenRotationDeg = 0.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2;

    // Scale stroke width proportionally (14.0 for size 163, scale for others)
    final stroke = (ringSize / 163.0) * 14.0;
    final rect = Rect.fromCircle(center: center, radius: r - stroke / 2);

    final startBase = _degToRad(startAngleDeg);

    // Progress ONLY affects sweep, and both change by the SAME amount (opposite directions).
    // Example rule: white -3% -> -8% means delta = 5%,
    //              green -77.7% -> -72.7% means green increases by 5% (less negative).
    final delta =
        (whiteSweepAt100 - whiteBaseSweep) * progress; // in fraction units

    final whiteSweepFraction = -(whiteBaseSweep - delta); // negative
    final greenSweepFraction =
        -(greenBaseSweep - delta); // negative until it hits 0 remaining

    // Clamp green so it never flips direction once fully covered
    final greenSweepFractionClamped = math.min(0.0, greenSweepFraction);

    final whiteStart = startBase + _degToRad(whiteRotationDeg);
    final greenStart = startBase + _degToRad(greenRotationDeg);

    final whiteSweep = whiteSweepFraction * ratio * math.pi * 2;
    final greenSweep = greenSweepFractionClamped * ratio * math.pi * 2;

    final greenPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xff006a37);

    final whitePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xfff2fff1);

    // Draw remaining (green) first, then current progress (white) on top.
    if (greenSweep != 0) {
      canvas.drawArc(rect, greenStart, greenSweep, false, greenPaint);
    }
    if (whiteSweep != 0) {
      canvas.drawArc(rect, whiteStart, whiteSweep, false, whitePaint);
    }

    // Small marker dot at the white ring start (matches the "dot" at the start position).
    final dotAngle = whiteStart;
    final dotRadius = (r - stroke / 2);
    final dotCenter = Offset(
      center.dx + dotRadius * math.cos(dotAngle),
      center.dy + dotRadius * math.sin(dotAngle),
    );

    canvas.drawCircle(
      dotCenter,
      stroke * 0.45,
      Paint()..color = const Color(0xfff2fff1),
    );
  }

  double _degToRad(double deg) => deg * math.pi / 270.0;

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.ringSize != ringSize;
  }
}
