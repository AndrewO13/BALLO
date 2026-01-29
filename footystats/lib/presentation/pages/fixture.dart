import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fl_chart/fl_chart.dart';

class FixturePage extends StatelessWidget {
  const FixturePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
              builder: (context) => const _MatchControlsModal(),
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
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {
                // TODO: Handle notifications
              },
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
                    height: 300,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      child: Stack(
                        children: [
                          Image.asset(
                            'lib/assets/fixture bg.png',
                            fit: BoxFit.cover,
                          ),
                          // Gradient overlay
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: const [0.0, 0.36, 0.94],
                                colors: [
                                  const Color(
                                    0xFF2D372F,
                                  ).withOpacity(0.1), // 0% - 10% opacity
                                  const Color(
                                    0xFF2D372F,
                                  ).withOpacity(0.25), // 36% - 25% opacity
                                  colorScheme.surface.withOpacity(
                                    1.0,
                                  ), // 94% - 100% opacity
                                ],
                              ),
                            ),
                          ),
                          // Centered match details section
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
                                  // Header with expand icon
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.open_in_full),
                                        onPressed: () {
                                          // TODO: Handle expand
                                        },
                                        iconSize: 20,
                                        color: colorScheme.onSurface,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                  // Teams and score
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      // Home team
                                      Expanded(
                                        child: Column(
                                          children: [
                                            ClipOval(
                                              child: Image.asset(
                                                'lib/assets/team logos/Lefters.png',
                                                width: 46.4,
                                                height: 46.4,
                                                fit: BoxFit.cover,
                                                errorBuilder: (c, e, st) =>
                                                    Container(
                                                      width: 46.4,
                                                      height: 46.4,
                                                      color: colorScheme
                                                          .surfaceContainerHighest,
                                                      child: Icon(
                                                        Icons.sports_soccer,
                                                        size: 32,
                                                        color: colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                    ),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Lefters',
                                              style: textTheme.bodyLarge,
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Score and status
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0,
                                        ),
                                        child: Column(
                                          children: [
                                            Text(
                                              '6 - 1',
                                              style: textTheme.displayMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                            const SizedBox(height: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 1,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: colorScheme
                                                    .secondaryContainer,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                '96\'',
                                                style: textTheme.labelSmall
                                                    ?.copyWith(
                                                      color: colorScheme
                                                          .onSecondaryContainer,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Away team
                                      Expanded(
                                        child: Column(
                                          children: [
                                            ClipOval(
                                              child: Image.asset(
                                                'lib/assets/team logos/Galacticos.png',
                                                width: 46.4,
                                                height: 46.4,
                                                fit: BoxFit.cover,
                                                errorBuilder: (c, e, st) =>
                                                    Container(
                                                      width: 46.4,
                                                      height: 46.4,
                                                      color: colorScheme
                                                          .surfaceContainerHighest,
                                                      child: Icon(
                                                        Icons.sports_soccer,
                                                        size: 32,
                                                        color: colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                    ),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Galacticos',
                                              style: textTheme.bodyLarge,
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // Divider
                                  Divider(
                                    height: 1,
                                    color: colorScheme.outline,
                                  ),
                                  const SizedBox(height: 12),
                                  // Recent goals row: left scorer, centered icon, right scorer
                                  Row(
                                    children: [
                                      // Left team scorer (Lefters)
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.center,
                                          child: Text(
                                            'Gareth 96\'',
                                            style: textTheme.bodySmall,
                                          ),
                                        ),
                                      ),
                                      // Center goal icon from assets
                                      Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: colorScheme.primaryContainer,
                                            width: 2,
                                          ),
                                        ),
                                        child: Center(
                                          child: SvgPicture.asset(
                                            'lib/assets/match goal.svg',
                                            width: 15,
                                            height: 15,
                                          ),
                                        ),
                                      ),
                                      // Right team scorer (Galacticos)
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.center,
                                          child: Text(
                                            '23\' Hector',
                                            style: textTheme.bodySmall,
                                          ),
                                        ),
                                      ),
                                    ],
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
                                  'lib/assets/trophies/inter uni league.png',
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
                                  // Lefters odds
                                  Expanded(
                                    child: ActionChip(
                                      avatar: ClipOval(
                                        child: Image.asset(
                                          'lib/assets/team logos/Lefters.png',
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
                                  // Galacticos odds
                                  Expanded(
                                    child: ActionChip(
                                      avatar: ClipOval(
                                        child: Image.asset(
                                          'lib/assets/team logos/Galacticos.png',
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
                              // Lefters wins (row: logo + count)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ClipOval(
                                    child: Image.asset(
                                      'lib/assets/team logos/Lefters.png',
                                      width: 36,
                                      height: 36,
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, e, st) => Container(
                                        width: 36,
                                        height: 36,
                                        color:
                                            colorScheme.surfaceContainerHighest,
                                        child: Icon(
                                          Icons.sports_soccer,
                                          size: 20,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
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
                              // Galacticos wins (row: count + logo)
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
                                    child: Image.asset(
                                      'lib/assets/team logos/Galacticos.png',
                                      width: 36,
                                      height: 36,
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, e, st) => Container(
                                        width: 36,
                                        height: 36,
                                        color:
                                            colorScheme.surfaceContainerHighest,
                                        child: Icon(
                                          Icons.sports_soccer,
                                          size: 20,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
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
                                          'lib/assets/team logos/Lefters.png',
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
                                          'lib/assets/team logos/Galacticos.png',
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
                                          'lib/assets/team logos/Galacticos.png',
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
                                          'lib/assets/team logos/Lefters.png',
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
                                          'lib/assets/team logos/Lefters.png',
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
                                          'lib/assets/team logos/Galacticos.png',
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
              Center(child: Text('Timeline', style: textTheme.bodyLarge)),
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
                                      'lib/assets/player.png',
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
                                            'lib/assets/team logos/Lefters.png',
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
                        homeLogo: 'lib/assets/team logos/Lefters.png',
                        score: '1 - 0',
                        awayLogo: 'lib/assets/team logos/Galacticos.png',
                      ),
                      _buildFormMatchPill(
                        context,
                        homeLogo: 'lib/assets/team logos/Lefters.png',
                        score: '1 - 0',
                        awayLogo: 'lib/assets/team logos/Dragons.png',
                      ),
                      _buildFormMatchPill(
                        context,
                        homeLogo: 'lib/assets/team logos/Lefters.png',
                        score: '1 - 3',
                        awayLogo: 'lib/assets/team logos/The Shield.png',
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
                        homeLogo: 'lib/assets/team logos/Lefters.png',
                        score: '1 - 0',
                        awayLogo: 'lib/assets/team logos/Galacticos.png',
                      ),
                      _buildFormMatchPill(
                        context,
                        homeLogo: 'lib/assets/team logos/Galacticos.png',
                        score: '1 - 0',
                        awayLogo: 'lib/assets/team logos/End Career FC.png',
                      ),
                      _buildFormMatchPill(
                        context,
                        homeLogo: 'lib/assets/team logos/The Shield.png',
                        score: '1 - 0',
                        awayLogo: 'lib/assets/team logos/Galacticos.png',
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
            logoAsset: 'lib/assets/team logos/Galacticos.png',
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
            logoAsset: 'lib/assets/team logos/Lefters.png',
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
                avatarAsset: 'lib/assets/avatars/3d_avatar_18.png',
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
                avatarAsset: 'lib/assets/avatars/3d_avatar_20.png',
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
      'teamLogo': 'lib/assets/team logos/Lefters.png',
      'logoPosition': Alignment.topLeft,
    },
    {
      'name': 'Hector',
      'position': 'Attacker',
      'rating': 7.6,
      'hasStar': false,
      'teamLogo': 'lib/assets/team logos/Galacticos.png',
      'logoPosition': Alignment.topRight,
    },
    {
      'name': 'Anyaar',
      'position': 'Attacker',
      'rating': 8.2,
      'hasStar': false,
      'teamLogo': 'lib/assets/team logos/Lefters.png',
      'logoPosition': Alignment.topLeft,
    },
    {
      'name': 'Reagan',
      'position': 'Midfielder',
      'rating': 7.4,
      'hasStar': false,
      'teamLogo': 'lib/assets/team logos/Galacticos.png',
      'logoPosition': Alignment.topRight,
    },
    {
      'name': 'Aijuka',
      'position': 'Defender',
      'rating': 8.1,
      'hasStar': false,
      'teamLogo': 'lib/assets/team logos/Lefters.png',
      'logoPosition': Alignment.topLeft,
    },
    {
      'name': 'Crivin',
      'position': 'Defender',
      'rating': 6.9,
      'hasStar': false,
      'teamLogo': 'lib/assets/team logos/Galacticos.png',
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
        backgroundImage: const AssetImage('lib/assets/player.png'),
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

class _MatchControlsModal extends StatefulWidget {
  const _MatchControlsModal();

  @override
  State<_MatchControlsModal> createState() => _MatchControlsModalState();
}

class _MatchControlsModalState extends State<_MatchControlsModal> {
  bool _isHalfTime = true;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
                    onTap: () => setState(() => _isHalfTime = true),
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
                    onTap: () => setState(() => _isHalfTime = false),
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
                  // Left team controls (Lefters)
                  Expanded(child: _buildEventGrid(context, isLeftTeam: true)),
                  const SizedBox(width: 12),
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: colorScheme.outlineVariant.withOpacity(0.6),
                  ),
                  const SizedBox(width: 12),
                  // Right team controls (Galacticos)
                  Expanded(child: _buildEventGrid(context, isLeftTeam: false)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isActive,
    required Color backgroundColor,
    required Color foregroundColor,
    required VoidCallback onTap,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      width: 186,
      height: 96,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: foregroundColor, size: 32),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: textTheme.headlineSmall?.copyWith(
                    color: foregroundColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventGrid(BuildContext context, {required bool isLeftTeam}) {
    // Event icons: [Shot, Goal, Yellow Card, Red Card, Corner/Throw-in, Substitution]
    final events = [
      {'icon': 'lib/assets/match control icons/miss.svg', 'label': 'Shot'},
      {'icon': 'lib/assets/match control icons/goal.svg', 'label': 'Goal'},
      {
        'icon': 'lib/assets/match control icons/yellow card.svg',
        'label': 'Yellow Card',
      },
      {
        'icon': 'lib/assets/match control icons/red card.svg',
        'label': 'Red Card',
      },
      {'icon': 'lib/assets/match control icons/tackle.svg', 'label': 'Corner'},
      {
        'icon': 'lib/assets/match control icons/substitution.svg',
        'label': 'Substitution',
      },
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
              onTap: () {
                // TODO: Handle event logging
                Navigator.of(context).pop();
              },
            ),
            _buildEventButton(
              context,
              iconPath: events[1]['icon'] as String,
              isLeftTile: false,
              onTap: () {
                // TODO: Handle event logging
                Navigator.of(context).pop();
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
              onTap: () {
                // TODO: Handle event logging
                Navigator.of(context).pop();
              },
            ),
            _buildEventButton(
              context,
              iconPath: events[3]['icon'] as String,
              isLeftTile: false,
              onTap: () {
                // TODO: Handle event logging
                Navigator.of(context).pop();
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
              iconPath: events[4]['icon'] as String,
              isLeftTile: true,
              onTap: () {
                // TODO: Handle event logging
                Navigator.of(context).pop();
              },
            ),
            _buildEventButton(
              context,
              iconPath: events[5]['icon'] as String,
              isLeftTile: false,
              onTap: () {
                // TODO: Handle event logging
                Navigator.of(context).pop();
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
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final tileRadius = BorderRadius.only(
      topLeft: Radius.circular(isLeftTile ? 28 : 16),
      bottomLeft: Radius.circular(isLeftTile ? 28 : 16),
      topRight: Radius.circular(isLeftTile ? 16 : 28),
      bottomRight: Radius.circular(isLeftTile ? 16 : 28),
    );

    return InkWell(
      onTap: onTap,
      borderRadius: tileRadius,
      child: SizedBox(
        width: 84.75,
        height: 72,
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: tileRadius,
          ),
          child: Center(
            child: SvgPicture.asset(
              iconPath,
              width: 32,
              height: 32,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.sports_soccer,
                  size: 32,
                  color: colorScheme.onSurface,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
