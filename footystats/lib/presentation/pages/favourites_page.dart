import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/countries.dart';
import '../../core/utils/dominant_image_color.dart';
import '../../core/utils/scroll_to_top.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/media_placeholders.dart';
import '../../data/repositories/players_repository.dart';
import '../../domain/models/league_model.dart';
import '../../domain/models/team_model.dart';
import '../providers/favourited_leagues_provider.dart';
import '../providers/favourited_matches_provider.dart';
import '../providers/favourited_players_provider.dart';
import '../providers/favourited_teams_provider.dart';
import '../providers/main_nav_scroll_provider.dart';
import 'league_detail_page.dart';
import 'fixture.dart';
import 'player_profile_page.dart';
import 'team_detail_page.dart';

/// Favourites tab with category tabs for matches, teams, leagues and players.
class FavouritesPage extends ConsumerStatefulWidget {
  const FavouritesPage({super.key});

  @override
  ConsumerState<FavouritesPage> createState() => _FavouritesPageState();
}

class _FavouritesPageState extends ConsumerState<FavouritesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final List<ScrollController> _tabScrollControllers;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabScrollControllers = List.generate(4, (_) => ScrollController());
  }

  @override
  void dispose() {
    for (final controller in _tabScrollControllers) {
      controller.dispose();
    }
    _tabController.dispose();
    super.dispose();
  }

  void _scrollActiveTabToTop() {
    final index = _tabController.index;
    if (index < 0 || index >= _tabScrollControllers.length) return;
    animateScrollControllerToTop(_tabScrollControllers[index]);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(
      mainNavScrollToTopProvider.select((m) => m[MainNavTab.secondary] ?? 0),
      (previous, next) {
        if (previous == next) return;
        _scrollActiveTabToTop();
      },
    );

    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: false,
              tabAlignment: TabAlignment.fill,
              labelPadding: EdgeInsets.zero,
              indicatorPadding: EdgeInsets.zero,
              dividerHeight: 0,
              labelColor: colorScheme.onSurface,
              unselectedLabelColor: colorScheme.onSurfaceVariant,
              indicatorColor: colorScheme.primary,
              indicatorWeight: 3,
              dividerColor: Colors.transparent,
              labelStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: Theme.of(context).textTheme.titleSmall,
              tabs: const [
                Tab(text: 'Matches'),
                Tab(text: 'Teams'),
                Tab(text: 'Competitions'),
                Tab(text: 'Players'),
              ],
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _FavouritedMatchesTab(
                scrollController: _tabScrollControllers[0],
              ),
              _FavouritedTeamsTab(
                scrollController: _tabScrollControllers[1],
              ),
              _FavouritedCompetitionsTab(
                scrollController: _tabScrollControllers[2],
              ),
              _FavouritedPlayersTab(
                scrollController: _tabScrollControllers[3],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

void _reorderItem(
  int oldIndex,
  int newIndex,
  void Function(int, int) reorder,
) {
  reorder(oldIndex, newIndex);
}

class _FavouritedMatchesTab extends ConsumerWidget {
  const _FavouritedMatchesTab({this.scrollController});

  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favourites = ref.watch(favouritedMatchesProvider);
    final isEditMode = ref.watch(favouritesEditModeProvider);

    if (favourites.isEmpty) {
      return ListView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.55,
            child: const Center(
              child: AppEmptyState(
                imageAsset: AppAssets.searchEmpty,
                title: 'No favourite matches yet',
                subtitle:
                    'Tap the star on a match to save it here.',
              ),
            ),
          ),
        ],
      );
    }

    if (isEditMode) {
      return ReorderableListView.builder(
        scrollController: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        buildDefaultDragHandles: false,
        itemCount: favourites.length,
        onReorderItem: (oldIndex, newIndex) => _reorderItem(
          oldIndex,
          newIndex,
          ref.read(favouritedMatchesProvider.notifier).reorder,
        ),
        itemBuilder: (context, index) {
          final match = favourites[index];
          return _FavouritedMatchCard(
            key: ValueKey(match.id),
            match: match,
            index: index,
          );
        },
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: favourites.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return _FavouritedMatchCard(match: favourites[index]);
      },
    );
  }
}

class _FavouritedMatchCard extends ConsumerWidget {
  const _FavouritedMatchCard({
    super.key,
    required this.match,
    this.index,
  });

  final FavouritedMatch match;
  final int? index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditMode = ref.watch(favouritesEditModeProvider);
    final logoPath = resolveTeamLogoPath(match.leagueLogoId);

    void openMatch() {
      if (isEditMode) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FixturePage(matchId: match.id),
        ),
      );
    }

    return _FavouriteListTile(
      isEditMode: isEditMode,
      index: index,
      onTap: openMatch,
      imagePath: logoPath,
      imageShape: _FavouriteImageShape.roundedSquare,
      fallbackIcon: Icons.sports_soccer,
      title: match.title,
      subtitle: match.subtitle,
      onRemove: () {
        ref.read(favouritedMatchesProvider.notifier).remove(match.id);
      },
    );
  }
}

class _FavouritedTeamsTab extends ConsumerWidget {
  const _FavouritedTeamsTab({this.scrollController});

  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favourites = ref.watch(favouritedTeamsProvider);
    final isEditMode = ref.watch(favouritesEditModeProvider);

    if (favourites.isEmpty) {
      return _FavouritedTeamsEmptyState(scrollController: scrollController);
    }

    if (isEditMode) {
      return ReorderableListView.builder(
        scrollController: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        buildDefaultDragHandles: false,
        itemCount: favourites.length,
        onReorderItem: (oldIndex, newIndex) => _reorderItem(
          oldIndex,
          newIndex,
          ref.read(favouritedTeamsProvider.notifier).reorder,
        ),
        itemBuilder: (context, index) {
          final team = favourites[index];
          return _FavouritedTeamCard(
            key: ValueKey(team.id),
            team: team,
            index: index,
          );
        },
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: favourites.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return _FavouritedTeamCard(team: favourites[index]);
      },
    );
  }
}

class _FavouritedTeamCard extends ConsumerWidget {
  const _FavouritedTeamCard({
    super.key,
    required this.team,
    this.index,
  });

  final FavouritedTeam team;
  final int? index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditMode = ref.watch(favouritesEditModeProvider);
    final logoPath = resolveTeamLogoPath(team.logoId);

    void openTeam() {
      if (isEditMode) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TeamDetailPage(teamId: team.id),
        ),
      );
    }

    return _FavouriteListTile(
      isEditMode: isEditMode,
      index: index,
      onTap: openTeam,
      imagePath: logoPath,
      imageShape: _FavouriteImageShape.circle,
      fallbackIcon: Icons.groups,
      title: team.displayName,
      subtitle: team.subtitle,
      onRemove: () {
        ref.read(favouritedTeamsProvider.notifier).remove(team.id);
      },
    );
  }
}

class _FavouritedCompetitionsTab extends ConsumerWidget {
  const _FavouritedCompetitionsTab({this.scrollController});

  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favourites = ref.watch(favouritedLeaguesProvider);
    final isEditMode = ref.watch(favouritesEditModeProvider);

    if (favourites.isEmpty) {
      return _FavouritedCompetitionsEmptyState(
        scrollController: scrollController,
      );
    }

    if (isEditMode) {
      return ReorderableListView.builder(
        scrollController: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        buildDefaultDragHandles: false,
        itemCount: favourites.length,
        onReorderItem: (oldIndex, newIndex) => _reorderItem(
          oldIndex,
          newIndex,
          ref.read(favouritedLeaguesProvider.notifier).reorder,
        ),
        itemBuilder: (context, index) {
          final league = favourites[index];
          return _FavouritedLeagueCard(
            key: ValueKey(league.id),
            league: league,
            index: index,
          );
        },
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: favourites.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return _FavouritedLeagueCard(league: favourites[index]);
      },
    );
  }
}

class _FavouritedLeagueCard extends ConsumerWidget {
  const _FavouritedLeagueCard({
    super.key,
    required this.league,
    this.index,
  });

  final FavouritedLeague league;
  final int? index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditMode = ref.watch(favouritesEditModeProvider);
    final countryCode = league.country?.trim();
    final countryLabel = (countryCode == null || countryCode.isEmpty)
        ? '—'
        : '${countryCodeToFlag(countryCode)} ${countryCodeToName(countryCode)}';
    final logoPath = resolveTeamLogoPath(league.logoId);

    void openLeague() {
      if (isEditMode) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LeagueDetailPage(leagueId: league.id),
        ),
      );
    }

    return _FavouriteListTile(
      isEditMode: isEditMode,
      index: index,
      onTap: openLeague,
      imagePath: logoPath,
      imageShape: _FavouriteImageShape.roundedSquare,
      fallbackIcon: Icons.emoji_events,
      title: league.name,
      subtitle: countryLabel,
      onRemove: () {
        ref.read(favouritedLeaguesProvider.notifier).remove(league.id);
      },
    );
  }
}

class _FavouritedPlayersTab extends ConsumerWidget {
  const _FavouritedPlayersTab({this.scrollController});

  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favourites = ref.watch(favouritedPlayersProvider);
    final isEditMode = ref.watch(favouritesEditModeProvider);

    if (favourites.isEmpty) {
      return _FavouritedPlayersEmptyState(scrollController: scrollController);
    }

    if (isEditMode) {
      return ReorderableListView.builder(
        scrollController: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        buildDefaultDragHandles: false,
        itemCount: favourites.length,
        onReorderItem: (oldIndex, newIndex) => _reorderItem(
          oldIndex,
          newIndex,
          ref.read(favouritedPlayersProvider.notifier).reorder,
        ),
        itemBuilder: (context, index) {
          final player = favourites[index];
          return _FavouritedPlayerCard(
            key: ValueKey(player.id),
            player: player,
            index: index,
          );
        },
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: favourites.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return _FavouritedPlayerCard(player: favourites[index]);
      },
    );
  }
}

class _FavouritesDiscoveryEmptyState extends StatelessWidget {
  const _FavouritesDiscoveryEmptyState({
    required this.title,
    required this.subtitle,
    required this.marquee,
    this.scrollController,
  });

  final String title;
  final String subtitle;
  final Widget marquee;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  title,
                  style: theme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  subtitle,
                  style: theme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 36),
              SizedBox(
                height: _DiscoveryShowcaseCard.size,
                child: marquee,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FavouritedPlayersEmptyState extends ConsumerWidget {
  const _FavouritedPlayersEmptyState({this.scrollController});

  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popularAsync = ref.watch(popularPlayersProvider);

    return _FavouritesDiscoveryEmptyState(
      scrollController: scrollController,
      title: 'Keep up with greatness',
      subtitle: "Get instant updates on your players' key moments",
      marquee: popularAsync.when(
        loading: () => const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (_, _) => const SizedBox.shrink(),
        data: (players) {
          if (players.isEmpty) return const SizedBox.shrink();
          return _DiscoveryMarquee(
            itemCount: players.length,
            itemBuilder: (context, index) {
              final player = players[index];
              return _PopularPlayerShowcaseCard(
                player: player,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PlayerProfilePage(playerId: player.id),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _FavouritedTeamsEmptyState extends ConsumerWidget {
  const _FavouritedTeamsEmptyState({this.scrollController});

  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popularAsync = ref.watch(popularTeamsProvider);

    return _FavouritesDiscoveryEmptyState(
      scrollController: scrollController,
      title: 'Follow the clubs you love',
      subtitle: 'Stay on top of fixtures, squads, and results',
      marquee: popularAsync.when(
        loading: () => const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (_, _) => const SizedBox.shrink(),
        data: (teams) {
          if (teams.isEmpty) return const SizedBox.shrink();
          return _DiscoveryMarquee(
            itemCount: teams.length,
            itemBuilder: (context, index) {
              final team = teams[index];
              return _PopularTeamShowcaseCard(
                team: team,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TeamDetailPage(teamId: team.id),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _FavouritedCompetitionsEmptyState extends ConsumerWidget {
  const _FavouritedCompetitionsEmptyState({this.scrollController});

  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popularAsync = ref.watch(popularLeaguesProvider);

    return _FavouritesDiscoveryEmptyState(
      scrollController: scrollController,
      title: 'Track your favourite leagues',
      subtitle: 'Never miss a kick-off in the competitions you care about',
      marquee: popularAsync.when(
        loading: () => const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (_, _) => const SizedBox.shrink(),
        data: (leagues) {
          if (leagues.isEmpty) return const SizedBox.shrink();
          return _DiscoveryMarquee(
            itemCount: leagues.length,
            itemBuilder: (context, index) {
              final league = leagues[index];
              return _PopularLeagueShowcaseCard(
                league: league,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LeagueDetailPage(leagueId: league.id),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _DiscoveryMarquee extends StatefulWidget {
  const _DiscoveryMarquee({
    required this.itemCount,
    required this.itemBuilder,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;

  @override
  State<_DiscoveryMarquee> createState() => _DiscoveryMarqueeState();
}

class _DiscoveryMarqueeState extends State<_DiscoveryMarquee>
    with SingleTickerProviderStateMixin {
  static const _itemSpacing = 12.0;
  static const _durationPerItem = Duration(seconds: 4);

  late final AnimationController _controller;

  double get _segmentWidth {
    final count = widget.itemCount;
    if (count == 0) return 0;
    return count * (_DiscoveryShowcaseCard.size + _itemSpacing);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _restartAnimation();
  }

  @override
  void didUpdateWidget(covariant _DiscoveryMarquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemCount != widget.itemCount) {
      _restartAnimation();
    }
  }

  void _restartAnimation() {
    final count = widget.itemCount;
    if (count == 0) return;
    _controller.duration = _durationPerItem * count;
    _controller
      ..reset()
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Widget> _buildCards() {
    return [
      for (var i = 0; i < widget.itemCount; i++) ...[
        widget.itemBuilder(context, i),
        const SizedBox(width: _itemSpacing),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount == 0) return const SizedBox.shrink();

    final cards = _buildCards();
    final trackWidth = _segmentWidth * 2;

    return ClipRect(
      child: OverflowBox(
        maxWidth: double.infinity,
        alignment: Alignment.centerLeft,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(-_controller.value * _segmentWidth, 0),
              child: child,
            );
          },
          child: SizedBox(
            width: trackWidth,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...cards,
                ...cards,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscoveryShowcaseCard extends StatefulWidget {
  const _DiscoveryShowcaseCard({
    required this.colorImagePath,
    required this.child,
    this.onTap,
  });

  final String? colorImagePath;
  final Widget child;
  final VoidCallback? onTap;

  static const double size = 112;

  @override
  State<_DiscoveryShowcaseCard> createState() => _DiscoveryShowcaseCardState();
}

class _DiscoveryShowcaseCardState extends State<_DiscoveryShowcaseCard> {
  Color? _dominantColor;

  @override
  void initState() {
    super.initState();
    _loadDominantColor();
  }

  @override
  void didUpdateWidget(covariant _DiscoveryShowcaseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.colorImagePath != widget.colorImagePath) {
      _loadDominantColor();
    }
  }

  Future<void> _loadDominantColor() async {
    final color = await dominantColorForImagePath(widget.colorImagePath);
    if (!mounted) return;
    setState(() => _dominantColor = color);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cardColor = _dominantColor ?? colorScheme.surfaceContainerHigh;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: _DiscoveryShowcaseCard.size,
        height: _DiscoveryShowcaseCard.size,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Center(child: widget.child),
      ),
    );
  }
}

class _PopularPlayerShowcaseCard extends StatelessWidget {
  const _PopularPlayerShowcaseCard({
    required this.player,
    this.onTap,
  });

  final PlayerSearchModel player;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final teamLogoPath = resolveTeamLogoPath(player.teamLogoId);
    const portraitSize = 76.0;
    const badgeSize = 26.0;

    return _DiscoveryShowcaseCard(
      colorImagePath: teamLogoPath,
      onTap: onTap,
      child: SizedBox(
        width: portraitSize,
        height: portraitSize,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            ClipOval(
              child: buildPlayerAvatar(
                imagePath: player.imageUrl,
                size: portraitSize,
              ),
            ),
            if (teamLogoPath != null && teamLogoPath.isNotEmpty)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: badgeSize,
                  height: badgeSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.surface,
                    border: Border.all(
                      color: colorScheme.surface,
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: buildTeamLogo(teamLogoPath, size: badgeSize),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PopularTeamShowcaseCard extends StatelessWidget {
  const _PopularTeamShowcaseCard({
    required this.team,
    this.onTap,
  });

  final TeamModel team;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final logoPath = resolveTeamLogoPath(team.logoId);
    const logoSize = 76.0;

    return _DiscoveryShowcaseCard(
      colorImagePath: logoPath,
      onTap: onTap,
      child: ClipOval(
        child: buildTeamLogo(logoPath, size: logoSize),
      ),
    );
  }
}

class _PopularLeagueShowcaseCard extends StatelessWidget {
  const _PopularLeagueShowcaseCard({
    required this.league,
    this.onTap,
  });

  final LeagueModel league;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final logoPath = resolveTeamLogoPath(league.logoId);
    const logoSize = 76.0;

    return _DiscoveryShowcaseCard(
      colorImagePath: logoPath,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: buildTeamLogo(logoPath, size: logoSize),
      ),
    );
  }
}

class _FavouritedPlayerCard extends ConsumerWidget {
  const _FavouritedPlayerCard({
    super.key,
    required this.player,
    this.index,
  });

  final FavouritedPlayer player;
  final int? index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditMode = ref.watch(favouritesEditModeProvider);

    void openPlayer() {
      if (isEditMode) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PlayerProfilePage(playerId: player.id),
        ),
      );
    }

    return _FavouriteListTile(
      isEditMode: isEditMode,
      index: index,
      onTap: openPlayer,
      imagePath: resolvePlayerImagePath(player.imageUrl),
      imageShape: _FavouriteImageShape.circle,
      fallbackIcon: Icons.person,
      isPlayerAvatar: true,
      rawImagePath: player.imageUrl,
      title: player.displayName,
      subtitle: player.subtitle,
      onRemove: () {
        ref.read(favouritedPlayersProvider.notifier).remove(player.id);
      },
    );
  }
}

enum _FavouriteImageShape { circle, roundedSquare }

class _FavouriteListTile extends StatefulWidget {
  const _FavouriteListTile({
    required this.isEditMode,
    required this.onTap,
    required this.imagePath,
    required this.imageShape,
    required this.fallbackIcon,
    required this.title,
    required this.subtitle,
    required this.onRemove,
    this.isPlayerAvatar = false,
    this.rawImagePath,
    this.index,
  });

  final bool isEditMode;
  final int? index;
  final VoidCallback onTap;
  final String? imagePath;
  final _FavouriteImageShape imageShape;
  final IconData fallbackIcon;
  final bool isPlayerAvatar;
  final String? rawImagePath;
  final String title;
  final String subtitle;
  final VoidCallback onRemove;

  @override
  State<_FavouriteListTile> createState() => _FavouriteListTileState();
}

class _FavouriteListTileState extends State<_FavouriteListTile> {
  Color? _dominantColor;

  @override
  void initState() {
    super.initState();
    _loadDominantColor();
  }

  @override
  void didUpdateWidget(covariant _FavouriteListTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      _loadDominantColor();
    }
  }

  Future<void> _loadDominantColor() async {
    final color = await dominantColorForImagePath(widget.imagePath);
    if (!mounted) return;
    setState(() => _dominantColor = color);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final cardColor = _dominantColor ?? colorScheme.surfaceContainerHigh;
    final onCard = onDominantCardColor(cardColor);
    final onCardMuted = onDominantCardMutedColor(cardColor);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: EdgeInsets.fromLTRB(widget.isEditMode ? 4 : 16, 12, 8, 12),
              child: Row(
                children: [
                  if (widget.isEditMode && widget.index != null) ...[
                    ReorderableDragStartListener(
                      index: widget.index!,
                      child: IconButton(
                        style: IconButton.styleFrom(
                          fixedSize: const Size(40, 40),
                          padding: EdgeInsets.zero,
                        ),
                        icon: Icon(
                          Icons.drag_handle_rounded,
                          color: onCardMuted,
                        ),
                        onPressed: () {},
                        tooltip: 'Drag to reorder',
                      ),
                    ),
                  ],
                  _FavouriteThumbnail(
                    imagePath: widget.isPlayerAvatar
                        ? widget.rawImagePath
                        : widget.imagePath,
                    shape: widget.imageShape,
                    fallbackIcon: widget.fallbackIcon,
                    isPlayerAvatar: widget.isPlayerAvatar,
                    iconColor: onCardMuted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: textTheme.titleSmall?.copyWith(color: onCard),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.subtitle,
                          style: textTheme.bodySmall?.copyWith(
                            color: onCardMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _FavouriteTrailingAction(
                    isEditMode: widget.isEditMode,
                    onRemove: widget.onRemove,
                    cardColor: cardColor,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FavouriteThumbnail extends StatelessWidget {
  const _FavouriteThumbnail({
    required this.imagePath,
    required this.shape,
    required this.fallbackIcon,
    this.isPlayerAvatar = false,
    this.iconColor,
  });

  final String? imagePath;
  final _FavouriteImageShape shape;
  final IconData fallbackIcon;
  final bool isPlayerAvatar;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    const size = 36.0;

    if (isPlayerAvatar) {
      return buildPlayerAvatar(imagePath: imagePath, size: size);
    }

    final path = imagePath?.trim();
    if (path == null || path.isEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: Icon(fallbackIcon, color: iconColor, size: 22),
      );
    }

    final image = SizedBox(
      width: size,
      height: size,
      child: buildTeamLogo(path, size: size),
    );

    if (shape == _FavouriteImageShape.circle) {
      return ClipOval(child: image);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: image,
    );
  }
}

class _FavouriteTrailingAction extends StatelessWidget {
  const _FavouriteTrailingAction({
    required this.isEditMode,
    required this.onRemove,
    this.cardColor,
  });

  final bool isEditMode;
  final VoidCallback onRemove;
  final Color? cardColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = cardColor ?? colorScheme.surfaceContainerHigh;

    final iconColor = isEditMode
        ? colorScheme.error
        : dominantCardStarColor(
            background: background,
            colorScheme: colorScheme,
            isStarred: true,
          );

    return IconButton(
      style: IconButton.styleFrom(
        fixedSize: const Size(48, 48),
        padding: EdgeInsets.zero,
      ),
      icon: Icon(
        isEditMode ? Icons.remove_circle_outline : Icons.star_rounded,
        color: iconColor,
        size: 26,
      ),
      onPressed: onRemove,
      tooltip: 'Remove from favourites',
    );
  }
}
