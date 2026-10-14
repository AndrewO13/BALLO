import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/adaptive/adaptive.dart';
import '../../core/constants/app_assets.dart';
import '../../core/utils/scroll_to_top.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_shimmer.dart';
import '../../core/widgets/media_placeholders.dart';
import '../../data/repositories/leaderboard_repository.dart';
import '../../domain/models/player_stat_ranking.dart';
import '../providers/main_nav_scroll_provider.dart';
import 'player_profile_page.dart';
import '../../core/theme/app_shape.dart';

/// Elite hall: one discipline at a time, a podium for the top three, then the
/// rest of the board. Career and current season, filtered in place by position.
class LeaderboardPage extends ConsumerStatefulWidget {
  const LeaderboardPage({super.key, this.isCurrentNavTab = true});

  final bool isCurrentNavTab;

  @override
  ConsumerState<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends ConsumerState<LeaderboardPage>
    with SingleTickerProviderStateMixin {
  static const _boardLimit = 50;

  final _repo = LeaderboardRepository();
  final _scrollController = ScrollController();
  final _search = TextEditingController();
  TabController? _statTabs;
  final _viewerKey = GlobalKey();
  final Map<String, List<PlayerStatRanking>> _cache = {};

  RankingPeriod _period = RankingPeriod.allTime;
  RankingStat _stat = RankingStat.goals;
  _Scope _scope = _Scope.all;
  String _query = '';
  late final int _year;
  bool _loading = true;
  bool _started = false;

  String? get _viewerId => Supabase.instance.client.auth.currentUser?.id;

  _Discipline get _discipline =>
      _disciplines.firstWhere((discipline) => discipline.stat == _stat);

  String _cacheKey(RankingPeriod period, RankingStat stat) =>
      '${period.rpcValue}|${stat.rpcValue}|$_year';

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().toUtc().year;
    _ensureStatTabs();
    if (widget.isCurrentNavTab) {
      _started = true;
      _load(showLoading: true);
    }
  }

  @override
  void didUpdateWidget(covariant LeaderboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrentNavTab && !oldWidget.isCurrentNavTab && !_started) {
      _started = true;
      _load(showLoading: true);
    }
  }

  TabController _ensureStatTabs() {
    final existing = _statTabs;
    if (existing != null) return existing;
    final tabs = TabController(length: _disciplines.length, vsync: this);
    tabs.addListener(_onStatTab);
    _statTabs = tabs;
    return tabs;
  }

  void _onStatTab() {
    final tabs = _statTabs;
    if (tabs == null || tabs.indexIsChanging) return;
    final stat = _disciplines[tabs.index].stat;
    if (stat == _stat) return;
    _selectStat(stat);
  }

  @override
  void dispose() {
    final tabs = _statTabs;
    if (tabs != null) {
      tabs.removeListener(_onStatTab);
      tabs.dispose();
    }
    _search.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({required bool showLoading}) async {
    final key = _cacheKey(_period, _stat);
    final cached = _cache[key];
    if (cached != null && showLoading) {
      setState(() => _loading = false);
    } else if (showLoading) {
      setState(() => _loading = true);
    }

    final rows = await _repo.getStatRankings(
      period: _period,
      stat: _stat,
      year: _year,
      limit: _boardLimit,
    );
    if (!mounted) return;
    _cache[key] = rows;
    if (key != _cacheKey(_period, _stat)) return;
    setState(() => _loading = false);
    unawaited(_prefetchNeighbors());
  }

  Future<void> _prefetchNeighbors() async {
    final period = _period;
    for (final discipline in _disciplines) {
      if (discipline.stat == _stat && period == _period) continue;
      final key = _cacheKey(period, discipline.stat);
      if (_cache.containsKey(key)) continue;
      final rows = await _repo.getStatRankings(
        period: period,
        stat: discipline.stat,
        year: _year,
        limit: _boardLimit,
      );
      if (!mounted || period != _period) return;
      _cache[key] = rows;
    }
  }

  Future<void> _selectPeriod(RankingPeriod period) async {
    if (period == _period) return;
    setState(() => _period = period);
    _scrollToTop();
    await _load(showLoading: !_cache.containsKey(_cacheKey(_period, _stat)));
  }

  Future<void> _selectStat(RankingStat stat) async {
    if (stat == _stat) return;
    setState(() => _stat = stat);
    _scrollToTop();
    await _load(showLoading: !_cache.containsKey(_cacheKey(_period, _stat)));
  }

  void _selectScope(_Scope scope) {
    if (scope == _scope) return;
    setState(() => _scope = scope);
    _scrollToTop();
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    final motion = _motion(context, 220);
    if (motion == Duration.zero) {
      _scrollController.jumpTo(0);
      return;
    }
    _scrollController.animateTo(
      0,
      duration: motion,
      curve: Curves.easeOutCubic,
    );
  }

  void _openPlayer(String playerId) {
    if (playerId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerProfilePage(playerId: playerId),
      ),
    );
  }

  void _revealViewer() {
    final target = _viewerKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: _motion(context, 280),
      curve: Curves.easeOutCubic,
      alignment: 0.3,
    );
  }

  List<PlayerStatRanking> _visible(List<PlayerStatRanking> rows) {
    final query = _query.trim().toLowerCase();
    return [
      for (final row in rows)
        if (_scope.allows(row.position) &&
            (query.isEmpty || row.playerName.toLowerCase().contains(query)))
          row,
    ];
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(
      mainNavScrollToTopProvider.select((m) => m[MainNavTab.leaderboard] ?? 0),
      (previous, next) {
        if (previous == next) return;
        animateScrollControllerToTop(_scrollController);
      },
    );
    return _buildHall(context);
  }

  Widget _buildHall(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final inset = AppResponsive.horizontalInset(context);
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final titleExtent =
        16 + (40 * 0.95 * textScale) + 6 + (14 * 1.35 * textScale) + 20;
    final rows =
        _cache[_cacheKey(_period, _stat)] ?? const <PlayerStatRanking>[];
    final visible = _visible(rows);
    final spotlight = visible.take(3).toList();
    final rest = visible.skip(3).toList();
    final showShimmer = _loading && rows.isEmpty;
    final note = _discipline.sampleNote(_period);
    PlayerStatRanking? viewerInFeed;
    if (_viewerId != null) {
      for (final entry in rest) {
        if (entry.playerId == _viewerId) {
          viewerInFeed = entry;
          break;
        }
      }
    }

    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: scheme.surface,
        systemNavigationBarIconBrightness: dark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: Stack(
          children: [
            RefreshIndicator(
              color: scheme.primary,
              edgeOffset: top + 8,
              onRefresh: () async {
                _cache.remove(_cacheKey(_period, _stat));
                await _load(showLoading: true);
              },
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _ChromeDelegate(
                      top: top,
                      inset: inset,
                      titleExtent: titleExtent,
                      statTabs: _ensureStatTabs(),
                      scope: _scope,
                      period: _period,
                      year: _year,
                      searchController: _search,
                      onQuery: (value) => setState(() => _query = value),
                      onPeriod: _selectPeriod,
                      onScope: _selectScope,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: _pageMaxWidth,
                        ),
                        child: _BoardBody(
                          inset: inset,
                          year: _year,
                          period: _period,
                          discipline: _discipline,
                          scope: _scope,
                          showShimmer: showShimmer,
                          rowsEmpty: rows.isEmpty,
                          searching: _query.trim().isNotEmpty,
                          visible: visible,
                          spotlight: spotlight,
                          rest: rest,
                          note: note,
                          viewerId: _viewerId,
                          viewerKey: _viewerKey,
                          bottomPadding:
                              bottom + (viewerInFeed == null ? 28 : 96),
                          onOpenPlayer: _openPlayer,
                          onClearScope: () => _selectScope(_Scope.all),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (viewerInFeed != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _YouBar(
                  entry: viewerInFeed,
                  discipline: _discipline,
                  onTap: _revealViewer,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BoardBody extends StatelessWidget {
  const _BoardBody({
    required this.inset,
    required this.year,
    required this.period,
    required this.discipline,
    required this.scope,
    required this.showShimmer,
    required this.rowsEmpty,
    required this.searching,
    required this.visible,
    required this.spotlight,
    required this.rest,
    required this.note,
    required this.viewerId,
    required this.viewerKey,
    required this.bottomPadding,
    required this.onOpenPlayer,
    required this.onClearScope,
  });

  final double inset;
  final int year;
  final RankingPeriod period;
  final _Discipline discipline;
  final _Scope scope;
  final bool showShimmer;
  final bool rowsEmpty;
  final bool searching;
  final List<PlayerStatRanking> visible;
  final List<PlayerStatRanking> spotlight;
  final List<PlayerStatRanking> rest;
  final String? note;
  final String? viewerId;
  final GlobalKey viewerKey;
  final double bottomPadding;
  final ValueChanged<String> onOpenPlayer;
  final VoidCallback onClearScope;

  @override
  Widget build(BuildContext context) {
    final sampleNote = note;
    if (showShimmer) {
      return Padding(
        padding: EdgeInsets.fromLTRB(inset, 16, inset, 24),
        child: const _BoardShimmer(),
      );
    }
    if (rowsEmpty) {
      return AppEmptyState(
        imageAsset: AppAssets.noStatsEmpty,
        title: 'No rankings yet',
        subtitle: period == RankingPeriod.year
            ? 'Finished matches in $year will show who leads ${discipline.tab.toLowerCase()}.'
            : 'Finished matches across Ballo will fill the ${discipline.tab.toLowerCase()} board.',
      );
    }
    if (visible.isEmpty) {
      if (searching) {
        return AppEmptyState(
          imageAsset: AppAssets.searchEmpty,
          title: 'No player on this board',
          subtitle: scope == _Scope.all
              ? 'Try another name, or switch the stat.'
              : 'No ${scope.spoken} match that name.',
        );
      }
      return AppEmptyState(
        imageAsset: AppAssets.noStatsEmpty,
        title: 'No ${scope.spoken} on this board',
        subtitle: 'Clear the position filter to see the full ranking.',
        actionLabel: 'Show all positions',
        onAction: onClearScope,
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(inset, 14, inset, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _podiumMaxWidth),
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: MediaQuery.textScalerOf(
                    context,
                  ).clamp(maxScaleFactor: 1.15),
                ),
                child: _PodiumShowcase(
                  entries: spotlight,
                  discipline: discipline,
                  viewerId: viewerId,
                  onTap: onOpenPlayer,
                ),
              ),
            ),
          ),
          if (rest.isNotEmpty) ...[
            const SizedBox(height: 20),
            _FeedHeader(label: discipline.header),
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: AppShape.mediumRadius,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < rest.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: Theme.of(
                          context,
                        ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    _FeedRow(
                      key: rest[i].playerId == viewerId
                          ? viewerKey
                          : ValueKey(rest[i].playerId),
                      entry: rest[i],
                      discipline: discipline,
                      isViewer: rest[i].playerId == viewerId,
                      onTap: () => onOpenPlayer(rest[i].playerId),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (sampleNote != null) ...[
            const SizedBox(height: 16),
            Text(
              sampleNote,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
          SizedBox(height: bottomPadding),
        ],
      ),
    );
  }
}

class _ChromeDelegate extends SliverPersistentHeaderDelegate {
  _ChromeDelegate({
    required this.top,
    required this.inset,
    required this.titleExtent,
    required this.statTabs,
    required this.scope,
    required this.period,
    required this.year,
    required this.searchController,
    required this.onQuery,
    required this.onPeriod,
    required this.onScope,
  });

  static const searchRow = 48.0;
  static const tabsExtent = kTextTabBarHeight + 2;
  static const chipsExtent = 44.0;
  static const gap = 8.0;
  static const bottomGap = 6.0;

  final double top;
  final double inset;
  final double titleExtent;
  final TabController statTabs;
  final _Scope scope;
  final RankingPeriod period;
  final int year;
  final TextEditingController searchController;
  final ValueChanged<String> onQuery;
  final ValueChanged<RankingPeriod> onPeriod;
  final ValueChanged<_Scope> onScope;

  double get controlsExtent =>
      searchRow + gap + tabsExtent + gap + chipsExtent + bottomGap;

  @override
  double get maxExtent => top + titleExtent + controlsExtent;

  @override
  double get minExtent => top + controlsExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final t = (shrinkOffset / titleExtent).clamp(0.0, 1.0);
    final titleSpace = (titleExtent - shrinkOffset).clamp(0.0, titleExtent);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: overlapsContent
            ? Border(
                bottom: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.65),
                ),
              )
            : null,
        boxShadow: overlapsContent
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: top + titleExtent,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    scheme.primary.withValues(alpha: 0.18 * (1 - t)),
                    scheme.surface.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Column(
            children: [
              SizedBox(height: top),
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _pageMaxWidth),
                  child: Column(
                    children: [
                      SizedBox(
                        height: titleSpace,
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.topCenter,
                            minHeight: titleExtent,
                            maxHeight: titleExtent,
                            child: Opacity(
                              opacity: (1 - t).clamp(0.0, 1.0),
                              child: _Masthead(
                                inset: inset,
                                hideTitle: t > 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      ColoredBox(
                        color: scheme.surface.withValues(alpha: t),
                        child: _ChromeControls(
                          inset: inset,
                          statTabs: statTabs,
                          scope: scope,
                          period: period,
                          year: year,
                          searchController: searchController,
                          onQuery: onQuery,
                          onPeriod: onPeriod,
                          onScope: onScope,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _ChromeDelegate oldDelegate) {
    return top != oldDelegate.top ||
        inset != oldDelegate.inset ||
        titleExtent != oldDelegate.titleExtent ||
        scope != oldDelegate.scope ||
        period != oldDelegate.period ||
        year != oldDelegate.year;
  }
}

class _ChromeControls extends StatelessWidget {
  const _ChromeControls({
    required this.inset,
    required this.statTabs,
    required this.scope,
    required this.period,
    required this.year,
    required this.searchController,
    required this.onQuery,
    required this.onPeriod,
    required this.onScope,
  });

  final double inset;
  final TabController statTabs;
  final _Scope scope;
  final RankingPeriod period;
  final int year;
  final TextEditingController searchController;
  final ValueChanged<String> onQuery;
  final ValueChanged<RankingPeriod> onPeriod;
  final ValueChanged<_Scope> onScope;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: inset),
          child: SizedBox(
            height: _ChromeDelegate.searchRow,
            child: Row(
              children: [
                Expanded(
                  child: _PlayerSearchField(
                    controller: searchController,
                    onChanged: onQuery,
                  ),
                ),
                const SizedBox(width: 8),
                _PeriodButton(period: period, year: year, onChanged: onPeriod),
              ],
            ),
          ),
        ),
        const SizedBox(height: _ChromeDelegate.gap),
        SizedBox(
          height: _ChromeDelegate.tabsExtent,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: scheme.outlineVariant, width: 1),
              ),
            ),
            child: TabBar(
              controller: statTabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              padding: EdgeInsets.symmetric(horizontal: inset),
              dividerHeight: 0,
              dividerColor: Colors.transparent,
              labelColor: scheme.onSurface,
              unselectedLabelColor: scheme.onSurfaceVariant,
              indicatorColor: scheme.primary,
              tabs: [
                for (final discipline in _disciplines)
                  Tab(text: discipline.tab),
              ],
            ),
          ),
        ),
        const SizedBox(height: _ChromeDelegate.gap),
        _ScopeBar(inset: inset, selected: scope, onSelected: onScope),
      ],
    );
  }
}

class _Masthead extends StatelessWidget {
  const _Masthead({required this.inset, required this.hideTitle});

  final double inset;
  final bool hideTitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: inset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                excluding: hideTitle,
                child: Semantics(
                  header: true,
                  child: Text(
                    'RANKINGS',
                    style: GoogleFonts.anton(
                      fontSize: 40,
                      height: 0.95,
                      letterSpacing: 0.6,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Top performers across Ballo.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlayerSearchField extends StatefulWidget {
  const _PlayerSearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  State<_PlayerSearchField> createState() => _PlayerSearchFieldState();
}

class _PlayerSearchFieldState extends State<_PlayerSearchField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
  }

  @override
  void didUpdateWidget(covariant _PlayerSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    super.dispose();
  }

  void _onText() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = OutlineInputBorder(
      borderRadius: AppShape.mediumRadius,
      borderSide: BorderSide(
        color: scheme.outlineVariant.withValues(alpha: 0.7),
      ),
    );
    final hasText = widget.controller.text.isNotEmpty;

    return TextField(
      controller: widget.controller,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.search,
      style: Theme.of(context).textTheme.bodyMedium,
      cursorColor: scheme.primary,
      decoration: InputDecoration(
        hintText: 'Search for player',
        isDense: true,
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        suffixIcon: hasText
            ? IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  widget.controller.clear();
                  widget.onChanged('');
                },
                icon: Icon(Icons.cancel, color: scheme.onSurfaceVariant),
              )
            : Icon(Icons.search, color: scheme.onSurfaceVariant),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: scheme.primary),
        ),
      ),
    );
  }
}

class _PeriodButton extends StatelessWidget {
  const _PeriodButton({
    required this.period,
    required this.year,
    required this.onChanged,
  });

  final RankingPeriod period;
  final int year;
  final ValueChanged<RankingPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final label = period == RankingPeriod.year ? '$year' : 'All time';

    return PopupMenuButton<RankingPeriod>(
      tooltip: 'Change period',
      initialValue: period,
      onSelected: onChanged,
      color: scheme.surfaceContainerHigh,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: RankingPeriod.year,
          child: Text('This year Â· $year'),
        ),
        const PopupMenuItem(
          value: RankingPeriod.allTime,
          child: Text('All time'),
        ),
      ],
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: AppShape.mediumRadius,
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _ScopeBar extends StatelessWidget {
  const _ScopeBar({
    required this.inset,
    required this.selected,
    required this.onSelected,
  });

  final double inset;
  final _Scope selected;
  final ValueChanged<_Scope> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _ChromeDelegate.chipsExtent,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: inset),
        itemCount: _Scope.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final scope = _Scope.values[index];
          return Center(
            child: _ScopeChip(
              label: scope.chip,
              semanticsLabel: scope.semanticsLabel,
              selected: scope == selected,
              onTap: () => onSelected(scope),
            ),
          );
        },
      ),
    );
  }
}

class _ScopeChip extends StatelessWidget {
  const _ScopeChip({
    required this.label,
    required this.semanticsLabel,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String semanticsLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = _motion(context, 160);

    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Material(
        color: selected ? scheme.primary : scheme.surfaceContainerHigh,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected
                ? scheme.primary
                : scheme.outlineVariant.withValues(alpha: 0.85),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: AnimatedContainer(
            duration: motion,
            curve: Curves.easeOut,
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? scheme.onPrimary : scheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PodiumShowcase extends StatelessWidget {
  const _PodiumShowcase({
    required this.entries,
    required this.discipline,
    required this.viewerId,
    required this.onTap,
  });

  final List<PlayerStatRanking> entries;
  final _Discipline discipline;
  final String? viewerId;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final first = entries.first;
    final second = entries.length > 1 ? entries[1] : null;
    final third = entries.length > 2 ? entries[2] : null;
    final stacked =
        AppResponsive.isCompact(context) ||
        AppResponsive.isLandscapePhone(context);

    if (entries.length == 1) {
      return Align(
        child: SizedBox(
          width: 210,
          child: _PodiumCard(
            entry: first,
            discipline: discipline,
            featured: true,
            height: 252,
            isViewer: first.playerId == viewerId,
            onTap: () => onTap(first.playerId),
          ),
        ),
      );
    }

    if (stacked) {
      return Column(
        children: [
          _PodiumCard(
            entry: first,
            discipline: discipline,
            featured: true,
            height: 220,
            isViewer: first.playerId == viewerId,
            onTap: () => onTap(first.playerId),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (second != null)
                Expanded(
                  child: _PodiumCard(
                    entry: second,
                    discipline: discipline,
                    featured: false,
                    height: 200,
                    isViewer: second.playerId == viewerId,
                    onTap: () => onTap(second.playerId),
                  ),
                ),
              if (second != null && third != null) const SizedBox(width: 8),
              if (third != null)
                Expanded(
                  child: _PodiumCard(
                    entry: third,
                    discipline: discipline,
                    featured: false,
                    height: 188,
                    isViewer: third.playerId == viewerId,
                    onTap: () => onTap(third.playerId),
                  ),
                ),
            ],
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (second != null)
          Expanded(
            flex: 5,
            child: _PodiumCard(
              entry: second,
              discipline: discipline,
              featured: false,
              height: 216,
              isViewer: second.playerId == viewerId,
              onTap: () => onTap(second.playerId),
            ),
          ),
        if (second != null) const SizedBox(width: 8),
        Expanded(
          flex: 6,
          child: _PodiumCard(
            entry: first,
            discipline: discipline,
            featured: true,
            height: 252,
            isViewer: first.playerId == viewerId,
            onTap: () => onTap(first.playerId),
          ),
        ),
        if (third != null) ...[
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: _PodiumCard(
              entry: third,
              discipline: discipline,
              featured: false,
              height: 214,
              isViewer: third.playerId == viewerId,
              onTap: () => onTap(third.playerId),
            ),
          ),
        ],
      ],
    );
  }
}

class _PodiumCard extends StatelessWidget {
  const _PodiumCard({
    required this.entry,
    required this.discipline,
    required this.featured,
    required this.height,
    required this.isViewer,
    required this.onTap,
  });

  final PlayerStatRanking entry;
  final _Discipline discipline;
  final bool featured;
  final double height;
  final bool isViewer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final medal = _medalColor(entry.rank);
    final glow = medal ?? scheme.primary;
    final borderColor = isViewer
        ? scheme.primary
        : (medal ??
              (featured
                  ? scheme.primary
                  : scheme.outlineVariant.withValues(alpha: 0.8)));
    final tag = _positionTag(entry.position);
    final meta = [
      if (tag.isNotEmpty) tag,
      if (entry.teamName.isNotEmpty) entry.teamName,
    ].join(' Â· ');
    final value = discipline.stat.formatValue(entry.statValue);
    final roomy = height >= 210;
    final avatarSize = featured
        ? (height >= 240 ? 72.0 : 56.0)
        : (height >= 210 ? 52.0 : 44.0);
    final statSize = featured
        ? (height >= 240 ? 40.0 : 30.0)
        : (height >= 210 ? 28.0 : 24.0);

    return Semantics(
      button: true,
      label: _entryLabel(
        entry: entry,
        discipline: discipline,
        isViewer: isViewer,
      ),
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppShape.largeRadius,
          boxShadow: featured
              ? [
                  BoxShadow(
                    color: glow.withValues(alpha: 0.28),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: AppShape.largeRadius,
            side: BorderSide(color: borderColor, width: featured ? 1.6 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  glow.withValues(alpha: featured ? 0.30 : 0.14),
                  scheme.surfaceContainerHigh,
                ],
                stops: const [0, 0.58],
              ),
            ),
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                height: height,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    8,
                    roomy ? 12 : 8,
                    8,
                    roomy ? 10 : 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: _MedalDisc(rank: entry.rank, color: medal),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: buildPlayerAvatar(
                          imagePath: entry.imageUrl,
                          size: avatarSize,
                          backgroundColor: scheme.surfaceContainerHighest,
                          iconColor: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        entry.playerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const Spacer(),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          value,
                          maxLines: 1,
                          style: GoogleFonts.anton(
                            fontSize: statSize,
                            height: 1,
                            color: featured ? scheme.primary : scheme.onSurface,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isViewer
                            ? '${discipline.caption} Â· You'
                            : discipline.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: textTheme.labelSmall?.copyWith(
                          color: isViewer
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MedalDisc extends StatelessWidget {
  const _MedalDisc({required this.rank, required this.color});

  final int rank;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = color ?? scheme.surfaceContainerHighest;
    final ink = color == null ? scheme.onSurface : const Color(0xFF14120C);

    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
      child: Text(
        '$rank',
        style: TextStyle(
          color: ink,
          fontWeight: FontWeight.w800,
          fontSize: 12,
          height: 1,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _FeedHeader extends StatelessWidget {
  const _FeedHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          SizedBox(width: 32, child: Text('#', style: style)),
          const SizedBox(width: 10),
          const SizedBox(width: 40),
          const SizedBox(width: 10),
          Expanded(child: Text('PLAYER', style: style)),
          Text(label, style: style),
        ],
      ),
    );
  }
}

class _FeedRow extends StatelessWidget {
  const _FeedRow({
    super.key,
    required this.entry,
    required this.discipline,
    required this.isViewer,
    required this.onTap,
  });

  final PlayerStatRanking entry;
  final _Discipline discipline;
  final bool isViewer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tag = _positionTag(entry.position);
    final value = discipline.stat.formatValue(entry.statValue);
    final team = entry.teamName.isEmpty ? discipline.caption : entry.teamName;

    return Semantics(
      button: true,
      label: _entryLabel(
        entry: entry,
        discipline: discipline,
        isViewer: isViewer,
      ),
      excludeSemantics: true,
      child: Material(
        color: isViewer
            ? scheme.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          hoverColor: scheme.onSurface.withValues(alpha: 0.06),
          splashColor: scheme.onSurface.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    entry.rank < 10 ? '0${entry.rank}' : '${entry.rank}',
                    style: textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: entry.rank <= 3
                          ? scheme.onSurface
                          : scheme.outline,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                buildPlayerAvatar(
                  imagePath: entry.imageUrl,
                  size: 40,
                  backgroundColor: scheme.surfaceContainerHighest,
                  iconColor: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              entry.playerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (tag.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            _PositionTag(label: tag),
                          ],
                          if (isViewer) ...[
                            const SizedBox(width: 6),
                            Text(
                              'YOU',
                              style: textTheme.labelSmall?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        team,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      value,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _matchesLabel(entry.matches),
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PositionTag extends StatelessWidget {
  const _PositionTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: AppShape.extraSmallRadius,
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.9)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          height: 1.1,
        ),
      ),
    );
  }
}

class _YouBar extends StatelessWidget {
  const _YouBar({
    required this.entry,
    required this.discipline,
    required this.onTap,
  });

  final PlayerStatRanking entry;
  final _Discipline discipline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final value = discipline.stat.formatValue(entry.statValue);

    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 8,
      child: Semantics(
        button: true,
        label:
            'Your rank, ${entry.rank}, $value ${discipline.caption}. Jump to your row.',
        excludeSemantics: true,
        child: SafeArea(
          top: false,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Text(
                    'Your rank',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '#${entry.rank}',
                    style: textTheme.titleSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    value,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_up, color: scheme.primary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BoardShimmer extends StatelessWidget {
  const _BoardShimmer();

  @override
  Widget build(BuildContext context) {
    return const AppShimmer(
      child: Column(
        children: [
          SizedBox(
            height: 252,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 5,
                  child: ShimmerBox(height: 216, borderRadius: AppShape.large),
                ),
                SizedBox(width: 8),
                Expanded(
                  flex: 6,
                  child: ShimmerBox(height: 252, borderRadius: AppShape.large),
                ),
                SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: ShimmerBox(height: 196, borderRadius: AppShape.large),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          ShimmerBox(height: 64, borderRadius: AppShape.small),
          SizedBox(height: 8),
          ShimmerBox(height: 64, borderRadius: AppShape.small),
          SizedBox(height: 8),
          ShimmerBox(height: 64, borderRadius: AppShape.small),
          SizedBox(height: 8),
          ShimmerBox(height: 64, borderRadius: AppShape.small),
        ],
      ),
    );
  }
}

const _pageMaxWidth = 960.0;
const _podiumMaxWidth = 520.0;

const _gold = Color(0xFFE8C547);
const _silver = Color(0xFFC5CED8);
const _bronze = Color(0xFFC4894A);

const _disciplines = <_Discipline>[
  _Discipline(
    stat: RankingStat.goals,
    tab: 'Goals',
    header: 'GOALS',
    caption: 'Goals',
  ),
  _Discipline(
    stat: RankingStat.assists,
    tab: 'Assists',
    header: 'ASSISTS',
    caption: 'Assists',
  ),
  _Discipline(
    stat: RankingStat.goalContributions,
    tab: 'G+A',
    header: 'CONTRIBUTIONS',
    caption: 'G+A',
  ),
  _Discipline(
    stat: RankingStat.shootingPct,
    tab: 'Shooting %',
    header: 'SH %',
    caption: 'On target',
  ),
  _Discipline(
    stat: RankingStat.avgRating,
    tab: 'Rating',
    header: 'IMPACT',
    caption: 'Rating',
  ),
  _Discipline(
    stat: RankingStat.shotsOnTarget,
    tab: 'On target',
    header: 'ON TGT',
    caption: 'On target',
  ),
  _Discipline(
    stat: RankingStat.goalsPerMatch,
    tab: 'Goals / game',
    header: 'G/GM',
    caption: 'Per game',
  ),
  _Discipline(
    stat: RankingStat.tackles,
    tab: 'Tackles',
    header: 'TACKLES',
    caption: 'Tackles',
  ),
  _Discipline(
    stat: RankingStat.saves,
    tab: 'Saves',
    header: 'SAVES',
    caption: 'Saves',
  ),
];

class _Discipline {
  const _Discipline({
    required this.stat,
    required this.tab,
    required this.header,
    required this.caption,
  });

  final RankingStat stat;
  final String tab;
  final String header;
  final String caption;

  /// Sample floors match `get_player_stat_rankings`.
  String? sampleNote(RankingPeriod period) {
    final shots = period == RankingPeriod.year ? 8 : 15;
    final matches = period == RankingPeriod.year ? 3 : 5;
    return switch (stat) {
      RankingStat.shootingPct =>
        'Shooting percentage includes players with at least $shots shots.',
      RankingStat.avgRating =>
        'Impact is the average match rating for players with at least $matches appearances.',
      RankingStat.goalsPerMatch =>
        'Goals per game includes players with at least $matches appearances.',
      _ => null,
    };
  }
}

enum _Scope { all, gk, def, mid, att }

extension _ScopeX on _Scope {
  String get chip => switch (this) {
    _Scope.all => 'All',
    _Scope.gk => 'GK',
    _Scope.def => 'DEF',
    _Scope.mid => 'MID',
    _Scope.att => 'ATT',
  };

  String get semanticsLabel => switch (this) {
    _Scope.all => 'All positions',
    _Scope.gk => 'Goalkeepers',
    _Scope.def => 'Defenders',
    _Scope.mid => 'Midfielders',
    _Scope.att => 'Attackers',
  };

  String get spoken => switch (this) {
    _Scope.all => 'all positions',
    _Scope.gk => 'goalkeepers',
    _Scope.def => 'defenders',
    _Scope.mid => 'midfielders',
    _Scope.att => 'attackers',
  };

  bool allows(String position) {
    if (this == _Scope.all) return true;
    return _scopeOf(position) == this;
  }
}

_Scope? _scopeOf(String position) {
  switch (position.trim().toLowerCase()) {
    case 'goalkeeper':
    case 'gk':
      return _Scope.gk;
    case 'defender':
    case 'def':
      return _Scope.def;
    case 'midfielder':
    case 'mid':
      return _Scope.mid;
    case 'attacker':
    case 'forward':
    case 'att':
    case 'fwd':
      return _Scope.att;
    default:
      return switch (_positionTag(position)) {
        'GK' => _Scope.gk,
        'DEF' => _Scope.def,
        'MID' => _Scope.mid,
        'ATT' => _Scope.att,
        _ => null,
      };
  }
}

Color? _medalColor(int rank) => switch (rank) {
  1 => _gold,
  2 => _silver,
  3 => _bronze,
  _ => null,
};

Duration _motion(BuildContext context, int milliseconds) {
  if (MediaQuery.disableAnimationsOf(context)) return Duration.zero;
  return Duration(milliseconds: milliseconds);
}

String _positionTag(String position) {
  switch (position.trim().toLowerCase()) {
    case 'goalkeeper':
    case 'gk':
      return 'GK';
    case 'defender':
    case 'def':
      return 'DEF';
    case 'midfielder':
    case 'mid':
      return 'MID';
    case 'attacker':
    case 'forward':
    case 'att':
    case 'fwd':
      return 'ATT';
    case '':
      return '';
    default:
      final trimmed = position.trim();
      if (trimmed.length <= 3) return trimmed.toUpperCase();
      return trimmed.substring(0, 3).toUpperCase();
  }
}

String _matchesLabel(int matches) =>
    matches == 1 ? '1 match' : '$matches matches';

String _entryLabel({
  required PlayerStatRanking entry,
  required _Discipline discipline,
  required bool isViewer,
}) {
  final position = _positionTag(entry.position);
  final value = discipline.stat.formatValue(entry.statValue);
  final parts = <String>[
    'Rank ${entry.rank}',
    entry.playerName,
    if (position.isNotEmpty) position,
    if (entry.teamName.isNotEmpty) entry.teamName,
    '$value ${discipline.caption}',
    _matchesLabel(entry.matches),
    if (isViewer) 'You',
  ];
  return parts.join(', ');
}
