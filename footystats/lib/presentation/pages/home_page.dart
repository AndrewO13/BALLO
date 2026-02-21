import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/progress_ring.dart';
import '../../data/repositories/user_profile_repository.dart';
import '../../domain/models/user_profile.dart';
import '../widgets/home/challenge_widget.dart';
import '../widgets/home/gameweek_header.dart';
import '../widgets/home/match_card.dart';
import '../widgets/home/team_chip.dart';
import '../widgets/home/performance_chart.dart';
import 'fixture.dart';
import 'matches.dart';
import 'create_team_league_page.dart';
import '../providers/matches_provider.dart';
import 'leaderboard.dart';
import 'explore.dart';
import 'profile.dart';
import 'settings.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _selectedIndex = 0;
  String? _selectedTeam;
  final CarouselController _matchCarouselController = CarouselController();
  final CarouselController _highlightsCarouselController = CarouselController();
  final UserProfileRepository _profileRepository = UserProfileRepository();

  UserProfile? _profile;
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _profileRepository.getCurrentProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _isLoadingProfile = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingProfile = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final PreferredSizeWidget appBar = _buildAppBar(context);

    return Scaffold(
      appBar: appBar,
      floatingActionButton: _selectedIndex == 1
          ? FloatingActionButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CreateTeamOrLeaguePage(),
                  ),
                );
              },
              tooltip: 'Add',
              child: const Icon(Icons.add),
            )
          : null,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeContent(context),
          const MatchesPage(),
          LeaderboardPage(), // Cannot be const due to DefaultTabController
          ExplorePage(), // Cannot be const due to DefaultTabController
          ProfilePage(), // Cannot be const due to DefaultTabController
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    if (_selectedIndex == 0) {
      return AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: kToolbarHeight,
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              children: [
                const ChallengeWidget(),
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
                  AppAssets.footystatsLogo,
                  height: 32,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      );
    } else if (_selectedIndex == 1) {
      return AppBar(
        automaticallyImplyLeading: false,
        title: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            AppConstants.pageTitles[_selectedIndex],
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
      );
    } else if (_selectedIndex == 3) {
      return AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const ExploreSearchBar(),
        centerTitle: false,
      );
    } else if (_selectedIndex == 4) {
      return AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        title: Text(
          'Profile',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.group_outlined),
            onPressed: () {
              // TODO: Implement group functionality
            },
            tooltip: 'Group',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SettingsPage(),
                ),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      );
    } else {
      return AppBar(
        title: Text(
          AppConstants.pageTitles[_selectedIndex],
          style: _selectedIndex == 2
              ? Theme.of(context).textTheme.headlineMedium
              : null,
        ),
        centerTitle: false,
        automaticallyImplyLeading: false,
      );
    }
  }

  Widget _buildHomeContent(BuildContext context) {
    final displayName = _isLoadingProfile
        ? 'Gareth'
        : (_profile?.playerName ?? _profile?.username ?? 'Gareth');

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "What's up $displayName!",
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
            const GameweekHeader(gameweek: 'Gameweek 11'),
            const SizedBox(height: 0),
            Column(
              children: [
                Center(
                  child: ProgressRing(
                    size: 163,
                    progress: 0.9,
                    valueText: '9',
                    labelText: 'Tackles won',
                    icon: SvgPicture.asset(
                      AppAssets.tackleIcon,
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
                      progress: 0.0,
                      valueText: '0',
                      labelText: 'assists',
                      icon: SvgPicture.asset(
                        AppAssets.assistIcon,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 16),
                    ProgressRing(
                      size: 80,
                      progress: 1.0,
                      valueText: '2',
                      labelText: 'clean sheets',
                      icon: Image.asset(
                        AppAssets.cleanSheet,
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
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
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
                            TeamChip(
                              teamName: 'Lefters',
                              logoPath: AppAssets.leftersLogo,
                              isSelected: _selectedTeam == 'Lefters',
                              onSelected: (selected) {
                                setState(() {
                                  _selectedTeam = selected ? 'Lefters' : null;
                                });
                              },
                            ),
                            const SizedBox(width: 5.0),
                            TeamChip(
                              teamName: 'Galacticos',
                              logoPath: AppAssets.galacticosLogo,
                              isSelected: _selectedTeam == 'Galacticos',
                              onSelected: (selected) {
                                setState(() {
                                  _selectedTeam = selected ? 'Galacticos' : null;
                                });
                              },
                            ),
                            const SizedBox(width: 5.0),
                            TeamChip(
                              teamName: 'Dragons FC',
                              logoPath: AppAssets.dragonsLogo,
                              isSelected: _selectedTeam == 'Dragons FC',
                              onSelected: (selected) {
                                setState(() {
                                  _selectedTeam = selected ? 'Dragons FC' : null;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const PerformanceChart(),
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
              padding: const EdgeInsetsDirectional.only(top: 8.0, start: 0.0),
              child: Text(
                'This week',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 16),
            Consumer(
              builder: (context, ref, _) {
                final asyncMatches = ref.watch(homeThisWeekMatchesProvider);
                return asyncMatches.when(
                  data: (matches) {
                    if (matches.isEmpty) {
                      return ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height / 4,
                        ),
                        child: Center(
                          child: Text(
                            'No matches this week',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ),
                      );
                    }
                    return ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height / 4,
                      ),
                      child: CarouselView.weighted(
                        controller: _matchCarouselController,
                        itemSnapping: true,
                        flexWeights: const <int>[1, 4, 1],
                        children: matches.map((match) {
                          return MatchCard(
                            match: match,
                            leagueName: match.leagueName,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      FixturePage(matchId: match.id),
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ),
                    );
                  },
                  loading: () => ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height / 4,
                    ),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, _) => ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height / 4,
                    ),
                    child: Center(
                      child: Text(
                        'Could not load matches',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 0.0, start: 308.0),
              child: Text(
                'Show all',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 8.0, start: 0.0),
              child: Text(
                'Team',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 20),
            _buildTeamDetailsCard(context),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 8.0, start: 0.0),
              child: Text(
                'Highlights🔥',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 16),
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
                              AppAssets.highlightPlaceholder,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHigh,
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
              padding: const EdgeInsetsDirectional.only(top: 0.0, start: 308.0),
              child: Text(
                'Show all',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(height: 26),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamDetailsCard(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

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
          Stack(
            children: [
              Container(
                height: 204,
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.grey[800]),
                child: Image.asset(
                  AppAssets.teamBanner,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(0.8),
                1: FlexColumnWidth(0.6),
                2: FlexColumnWidth(2.4),
                3: FlexColumnWidth(0.8),
                4: FlexColumnWidth(0.8),
                5: FlexColumnWidth(0.8),
                6: FlexColumnWidth(0.8),
                7: FlexColumnWidth(0.8),
                8: FlexColumnWidth(0.8),
              },
              children: [
                _buildTableHeader(context),
                _buildStandingsRow(context, 1, 'GAL', 23, 83, 12, 10, 18, 19, 1, true),
                _buildStandingsRow(context, 2, 'LFC', 23, 83, 12, 10, 18, 15, -1, false),
                _buildStandingsRow(context, 3, 'DRA', 23, 83, 12, 10, 18, 3, 0, false),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: () {},
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

  TableRow _buildTableHeader(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text('Pos', style: textTheme.bodySmall, textAlign: TextAlign.center),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: SizedBox(height: 20, child: Center(child: Text(''))),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text('Team', style: textTheme.bodySmall),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text('PL', style: textTheme.bodySmall, textAlign: TextAlign.center),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text('W', style: textTheme.bodySmall, textAlign: TextAlign.center),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text('L', style: textTheme.bodySmall, textAlign: TextAlign.center),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text('D', style: textTheme.bodySmall, textAlign: TextAlign.center),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text('GD', style: textTheme.bodySmall, textAlign: TextAlign.center),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text('Pts', style: textTheme.bodySmall, textAlign: TextAlign.center),
        ),
      ],
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
    String logoPath = AppAssets.leftersLogo;
    if (team == 'GAL') {
      logoPath = AppAssets.galacticosLogo;
    } else if (team == 'DRA') {
      logoPath = AppAssets.dragonsLogo;
    }

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
                  ? const Icon(Icons.arrow_drop_up, color: Color(0xff39ff14), size: 18)
                  : positionChange < 0
                      ? const Icon(Icons.arrow_drop_down, color: Color(0xffff0000), size: 18)
                      : Icon(Icons.remove, color: Theme.of(context).colorScheme.outline, size: 16),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Row(
            children: [
              ClipOval(
                child: Image.asset(logoPath, width: 24, height: 24, fit: BoxFit.cover),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(team, style: textTheme.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Text(played.toString(), style: textTheme.bodyMedium, textAlign: TextAlign.center),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Text(wins.toString(), style: textTheme.bodyMedium, textAlign: TextAlign.center),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Text(losses.toString(), style: textTheme.bodyMedium, textAlign: TextAlign.center),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Text(draws.toString(), style: textTheme.bodyMedium, textAlign: TextAlign.center),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Text(goalDiff.toString(), style: textTheme.bodyMedium, textAlign: TextAlign.center),
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

  Widget _buildBottomNavigationBar(BuildContext context) {
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

    final safeIndex = (_selectedIndex >= 0 && _selectedIndex < navDestinations.length) ? _selectedIndex : 0;

    return NavigationBar(
      selectedIndex: safeIndex,
      onDestinationSelected: (int index) {
        setState(() {
          _selectedIndex = index;
        });
      },
      destinations: navDestinations,
    );
  }
}
