import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import '../../core/adaptive/adaptive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_assets.dart';
import '../../core/utils/scroll_to_top.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/media_placeholders.dart';
import '../providers/main_nav_scroll_provider.dart';
import '../widgets/app_search_page.dart';
import '../../data/repositories/leaderboard_repository.dart';
import '../../data/repositories/leagues_repository.dart';
import '../../domain/models/leaderboard_entry.dart';
import 'player_profile_page.dart';

class LeaderboardPage extends ConsumerStatefulWidget {
  const LeaderboardPage({
    super.key,
    /// When false (e.g. another bottom-nav tab is shown), periodic refresh pauses.
    this.isCurrentNavTab = true,
    /// Guests (fans) only see the overall board: the League and Teammates
    /// tabs scope to the viewer's own memberships, which guests don't have.
    this.isGuest = false,
  });

  final bool isCurrentNavTab;
  final bool isGuest;

  @override
  ConsumerState<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends ConsumerState<LeaderboardPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _autoRefreshInterval = Duration(seconds: 30);

  late final TabController _tabController;
  final _repo = LeaderboardRepository();
  final _leaguesRepo = LeaguesRepository();

  String? _leagueId;
  String? _teamId;
  bool _scopeLoading = true;

  final Map<int, List<LeaderboardEntry>> _entriesByTab = {};
  final Map<int, _LeaderboardEmptyKind?> _emptyByTab = {};
  final Map<int, bool> _loadingByTab = {};

  Timer? _autoRefreshTimer;
  late final List<ScrollController> _listScrollControllers;

  bool get _isGuest => widget.isGuest;

  bool _bootstrapStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: _isGuest ? 1 : 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _listScrollControllers = List.generate(_isGuest ? 1 : 3, (_) => ScrollController());
    // IndexedStack mounts this page from app launch; defer all network work
    // until the Leaderboard tab is actually shown.
    if (widget.isCurrentNavTab) {
      _bootstrap();
    }
  }

  Future<void> _bootstrap() async {
    if (_bootstrapStarted) return;
    _bootstrapStarted = true;
    final user = Supabase.instance.client.auth.currentUser;
    String? leagueId;
    String? teamId;
    if (!_isGuest && user != null) {
      final leagues = await _leaguesRepo.getLeaguesForUser(user.id);
      if (leagues.isNotEmpty) leagueId = leagues.first.id;
      teamId = await _repo.getPrimaryTeamId(user.id);
    }
    if (!mounted) return;
    setState(() {
      _leagueId = leagueId;
      _teamId = teamId;
      _scopeLoading = false;
    });
    // Fetch only the visible sub-tab; the other sub-tabs load on first visit.
    await _fetchTab(_tabController.index);
    if (mounted && widget.isCurrentNavTab) {
      _startAutoRefreshTimer();
    }
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    final idx = _tabController.index;
    _fetchTab(idx);
  }

  void _startAutoRefreshTimer() {
    _autoRefreshTimer?.cancel();
    if (!widget.isCurrentNavTab) return;
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      if (!mounted || !widget.isCurrentNavTab || _scopeLoading) return;
      _fetchTab(_tabController.index, showLoading: false);
    });
  }

  void _stopAutoRefreshTimer() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  Future<void> _fetchTab(int index, {bool showLoading = true}) async {
    if (_scopeLoading) return;

    if (showLoading) {
      setState(() => _loadingByTab[index] = true);
    }

    _LeaderboardEmptyKind? emptyKind;
    List<LeaderboardEntry> list = [];

    switch (index) {
      case 0:
        list = await _repo.getOverall();
        if (list.isEmpty) {
          emptyKind = _LeaderboardEmptyKind.noOverallPoints;
        }
        break;
      case 1:
        if (_leagueId == null) {
          emptyKind = _LeaderboardEmptyKind.noLeagueJoined;
        } else {
          list = await _repo.getForLeague(_leagueId!);
          if (list.isEmpty) {
            emptyKind = _LeaderboardEmptyKind.noLeagueActivity;
          }
        }
        break;
      case 2:
        if (_teamId == null) {
          emptyKind = _LeaderboardEmptyKind.noTeamJoined;
        } else {
          list = await _repo.getForTeam(_teamId!);
          if (list.isEmpty) {
            emptyKind = _LeaderboardEmptyKind.noTeamPlayers;
          }
        }
        break;
    }

    if (!mounted) return;
    setState(() {
      _entriesByTab[index] = list;
      _emptyByTab[index] = emptyKind;
      _loadingByTab[index] = false;
    });
  }

  @override
  void didUpdateWidget(covariant LeaderboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrentNavTab != oldWidget.isCurrentNavTab) {
      if (widget.isCurrentNavTab) {
        if (!_bootstrapStarted) {
          // First time the tab is opened: load scope + visible sub-tab.
          _bootstrap();
          return;
        }
        _startAutoRefreshTimer();
        if (!_scopeLoading) {
          // Refresh only the sub-tab that is actually visible.
          _fetchTab(_tabController.index, showLoading: false);
        }
      } else {
        _stopAutoRefreshTimer();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        mounted &&
        widget.isCurrentNavTab &&
        !_scopeLoading) {
      _fetchTab(_tabController.index, showLoading: false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopAutoRefreshTimer();
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    for (final controller in _listScrollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  static String _formatPoints(double v) {
    if (v.abs() >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    if ((v - v.round()).abs() < 0.05) return v.round().toString();
    return v.toStringAsFixed(1);
  }

  List<LeaderboardEntry> _entriesFor(int tabIndex) =>
      _entriesByTab[tabIndex] ?? [];

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(
      mainNavScrollToTopProvider.select((m) => m[MainNavTab.leaderboard] ?? 0),
      (previous, next) {
        if (previous == next) return;
        final index = _tabController.index.clamp(0, _listScrollControllers.length - 1);
        animateScrollControllerToTop(_listScrollControllers[index]);
      },
    );

    final colorScheme = Theme.of(context).colorScheme;
    // Guests have an anonymous auth id that never appears on the board, so
    // skip the self-highlight entirely.
    final currentUserId =
        _isGuest ? null : Supabase.instance.client.auth.currentUser?.id;
    final activeTab = _tabController.index;
    final activeEntries = _entriesFor(activeTab);
    final activeLoading = _loadingByTab[activeTab] == true;

    if (_scopeLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isGuest)
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppResponsive.horizontalInset(context),
              4,
              AppResponsive.horizontalInset(context),
              12 * AppResponsive.layoutScaleOf(context),
            ),
            child: Text(
              'The best players across all of Ballo',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          )
        else
          Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: TabBar(
              controller: _tabController,
              labelColor: colorScheme.onSurface,
              indicatorColor: colorScheme.primary,
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'Overall'),
                Tab(text: 'League'),
                Tab(text: 'Teammates'),
              ],
            ),
          ),
        _PodiumHeader(
          entries: activeEntries,
          loading: activeLoading,
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              for (var i = 0; i < (_isGuest ? 1 : 3); i++)
                _LeaderboardTabBody(
                  entries: _entriesFor(i),
                  emptyKind: _emptyByTab[i],
                  loading: _loadingByTab[i] == true,
                  formatPts: _formatPoints,
                  currentUserId: currentUserId,
                  scrollController: _listScrollControllers[i],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _LeaderboardEmptyKind {
  noOverallPoints,
  noLeagueJoined,
  noLeagueActivity,
  noTeamJoined,
  noTeamPlayers,
}

extension _LeaderboardEmptyKindCopy on _LeaderboardEmptyKind {
  String get title => switch (this) {
        _LeaderboardEmptyKind.noOverallPoints => 'No rankings yet',
        _LeaderboardEmptyKind.noLeagueJoined => 'Join a league first',
        _LeaderboardEmptyKind.noLeagueActivity => 'No league rankings yet',
        _LeaderboardEmptyKind.noTeamJoined => 'Join a team first',
        _LeaderboardEmptyKind.noTeamPlayers => 'No teammates ranked yet',
      };

  String get subtitle => switch (this) {
        _LeaderboardEmptyKind.noOverallPoints =>
          'Points build from every finished match on the app. Play a match to start climbing the board.',
        _LeaderboardEmptyKind.noLeagueJoined =>
          'League rankings compare you with others in the same league. Search for a league to see where you stand.',
        _LeaderboardEmptyKind.noLeagueActivity =>
          'Players will appear here once someone finishes a match in your league and earns points.',
        _LeaderboardEmptyKind.noTeamJoined =>
          'Teammate rankings show how your squad stacks up. Search for a team to see your place among them.',
        _LeaderboardEmptyKind.noTeamPlayers =>
          'Teammates will show up here once they have points from finished matches.',
      };

  String? get actionLabel => switch (this) {
        _LeaderboardEmptyKind.noLeagueJoined ||
        _LeaderboardEmptyKind.noTeamJoined =>
          'Search',
        _ => null,
      };
}

class _LeaderboardTabBody extends StatefulWidget {
  const _LeaderboardTabBody({
    required this.entries,
    required this.emptyKind,
    required this.loading,
    required this.formatPts,
    required this.currentUserId,
    this.scrollController,
  });

  final List<LeaderboardEntry> entries;
  final _LeaderboardEmptyKind? emptyKind;
  final bool loading;
  final String Function(double) formatPts;
  final String? currentUserId;
  final ScrollController? scrollController;

  @override
  State<_LeaderboardTabBody> createState() => _LeaderboardTabBodyState();
}

class _LeaderboardTabBodyState extends State<_LeaderboardTabBody> {
  double _scrollOffset = 0;

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final next = notification.metrics.pixels.clamp(0.0, double.infinity);
    if ((next - _scrollOffset).abs() > 0.5) {
      setState(() => _scrollOffset = next);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final entries = widget.entries;
    final emptyKind = widget.emptyKind;
    final loading = widget.loading;
    final formatPts = widget.formatPts;
    final currentUserId = widget.currentUserId;

    if (loading && entries.isEmpty) {
      return ListView(
        controller: widget.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(
            height: 240,
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    if (emptyKind != null && entries.isEmpty) {
      return ListView(
        controller: widget.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.55,
            child: Center(
              child: AppEmptyState(
                imageAsset: AppAssets.searchEmpty,
                title: emptyKind.title,
                subtitle: emptyKind.subtitle,
                actionLabel: emptyKind.actionLabel,
                onAction: emptyKind.actionLabel != null
                    ? () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => const AppSearchPage(),
                          ),
                        );
                      }
                    : null,
              ),
            ),
          ),
        ],
      );
    }

    final blurOpacity = (_scrollOffset / 24).clamp(0.0, 1.0);
    final background = Theme.of(context).scaffoldBackgroundColor;

    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ListView(
            controller: widget.scrollController,
            padding: EdgeInsets.fromLTRB(
              AppResponsive.horizontalInset(context),
              16 * AppResponsive.layoutScaleOf(context),
              AppResponsive.horizontalInset(context),
              24 * AppResponsive.layoutScaleOf(context),
            ),
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: colorScheme.outlineVariant,
                    width: 1.2,
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 36,
                            child: Text(
                              'Pos',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 32,
                            child: Text(
                              '',
                              style: textTheme.bodySmall,
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Player',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 44,
                            child: Text(
                              'GW',
                              textAlign: TextAlign.center,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 52,
                            child: Text(
                              'Pts',
                              textAlign: TextAlign.center,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (final e in entries)
                      _LeaderboardRow(
                        entry: e,
                        formatPts: formatPts,
                        highlight:
                            currentUserId != null && e.playerId == currentUserId,
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (blurOpacity > 0)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 56,
              child: IgnorePointer(
                child: ShaderMask(
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: const [
                        Colors.white,
                        Colors.white,
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.35, 1.0],
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.dstIn,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 5 * blurOpacity,
                      sigmaY: 5 * blurOpacity,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            background.withValues(alpha: 0.72 * blurOpacity),
                            background.withValues(alpha: 0.32 * blurOpacity),
                            background.withValues(alpha: 0),
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
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

class _PodiumHeader extends StatelessWidget {
  const _PodiumHeader({
    required this.entries,
    required this.loading,
  });

  final List<LeaderboardEntry> entries;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (loading && entries.isEmpty) {
          return SizedBox(
            height: 200,
            child: Center(
              child: CircularProgressIndicator(
                color: colorScheme.primary,
              ),
            ),
          );
        }

        if (entries.isEmpty) {
          return SizedBox(
            height: 180,
            width: double.infinity,
            child: Image.asset(
              AppAssets.leaderboardBg,
              fit: BoxFit.cover,
            ),
          );
        }

        final first = entries.isNotEmpty ? entries[0] : null;
        final second = entries.length > 1 ? entries[1] : null;
        final third = entries.length > 2 ? entries[2] : null;
        final maxPts = [
          if (first != null) first.totalPoints,
          if (second != null) second.totalPoints,
          if (third != null) third.totalPoints,
        ].fold<double>(0, (a, b) => a > b ? a : b);

        double barH(double pts) {
          if (maxPts <= 0) return 72;
          final t = (pts / maxPts).clamp(0.2, 1.0);
          return 52 + (132 - 52) * t;
        }

        return SizedBox(
          width: double.infinity,
          height: 292,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Positioned.fill(
                child: Image.asset(
                  AppAssets.leaderboardBg,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (second != null) ...[
                      _LeaderboardBar(
                        height: barH(second.totalPoints),
                        color: const Color(0xFFF2FFF1),
                        name: second.playerName,
                        imageUrl: second.imageUrl,
                        points: second.totalPoints,
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (first != null) ...[
                      _LeaderboardBar(
                        height: barH(first.totalPoints),
                        color: const Color(0xFF14FF8E),
                        name: first.playerName,
                        imageUrl: first.imageUrl,
                        points: first.totalPoints,
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (third != null)
                      _LeaderboardBar(
                        height: barH(third.totalPoints),
                        color: const Color(0xFFF2FFF1),
                        name: third.playerName,
                        imageUrl: third.imageUrl,
                        points: third.totalPoints,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Green up = improved rank; red down = worse; grey dash = unchanged.
/// [delta] is `previousRank - rank` (positive means moved up the table).
class _RankMovementIndicator extends StatelessWidget {
  const _RankMovementIndicator({required this.delta});

  final int delta;

  static const _green = Color(0xff39ff14);
  static const _red = Color(0xffff0000);

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    if (delta == 0) {
      return Icon(
        Icons.remove,
        size: 18,
        color: outline,
      );
    }
    if (delta > 0) {
      return const Icon(
        Icons.arrow_drop_up,
        color: _green,
        size: 28,
      );
    }
    return const Icon(
      Icons.arrow_drop_down,
      color: _red,
      size: 28,
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.entry,
    required this.formatPts,
    this.highlight = false,
  });

  final LeaderboardEntry entry;
  final String Function(double) formatPts;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final url = entry.imageUrl?.trim();

    Widget avatar;
    if (url != null &&
        (url.startsWith('http://') || url.startsWith('https://'))) {
      avatar = CircleAvatar(
        backgroundColor: colorScheme.surfaceContainerHighest,
        child: ClipOval(
          child: Image(
            image: appCachedImageProvider(url),
            width: 32,
            height: 32,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => playerAvatarPlaceholder(size: 32),
          ),
        ),
      );
    } else if (url != null &&
        (url.startsWith('lib/assets/') || url.startsWith('assets/'))) {
      avatar = CircleAvatar(
        backgroundImage: AssetImage(url),
      );
    } else {
      avatar = CircleAvatar(
        backgroundColor: colorScheme.surfaceContainerHighest,
        child: Text(
          entry.playerName.isNotEmpty
              ? entry.playerName[0].toUpperCase()
              : '?',
          style: textTheme.labelLarge,
        ),
      );
    }

    final borderRadius = BorderRadius.circular(30);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: entry.playerId.isEmpty
            ? null
            : () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PlayerProfilePage(playerId: entry.playerId),
                  ),
                );
              },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          decoration: highlight
              ? BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: borderRadius,
                )
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Text(
                    '${entry.rank}',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: Center(
                    child: _RankMovementIndicator(delta: entry.rankDelta),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      avatar,
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.playerName,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    formatPts(entry.gwPoints),
                    style: textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 52,
                  child: Text(
                    formatPts(entry.totalPoints),
                    style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
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

class _LeaderboardBar extends StatelessWidget {
  const _LeaderboardBar({
    required this.height,
    required this.color,
    required this.name,
    required this.points,
    this.imageUrl,
  });

  final double height;
  final Color color;
  final String name;
  final double points;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    const double width = 120;
    const double avatarSize = 60;
    final textTheme = Theme.of(context).textTheme;

    final url = imageUrl?.trim();
    Widget img;
    if (url != null &&
        (url.startsWith('http://') || url.startsWith('https://'))) {
      img = ClipOval(
        child: Image(
          image: appCachedImageProvider(url),
          width: avatarSize,
          height: avatarSize,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              playerAvatarPlaceholder(size: avatarSize),
        ),
      );
    } else if (url != null &&
        (url.startsWith('lib/assets/') || url.startsWith('assets/'))) {
      img = ClipOval(
        child: Image.asset(
          url,
          width: avatarSize,
          height: avatarSize,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              playerAvatarPlaceholder(size: avatarSize),
        ),
      );
    } else {
      img = playerAvatarPlaceholder(size: avatarSize);
    }

    final ptsLabel = (points - points.round()).abs() < 0.05
        ? points.round().toString()
        : points.toStringAsFixed(1);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: avatarSize,
          height: avatarSize,
          child: img,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: width,
          child: Text(
            name,
            textAlign: TextAlign.center,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 88,
          height: 32,
          child: FilledButton.icon(
            onPressed: () {},
            icon: const Icon(
              Icons.stars_rounded,
              color: Color(0xff00391b),
              size: 18,
            ),
            label: Text(
              ptsLabel,
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(88, 32),
              side: const BorderSide(color: Color(0xff006a37), width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            color: color,
          ),
        ),
      ],
    );
  }
}
