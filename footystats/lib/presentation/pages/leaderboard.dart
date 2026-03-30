import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_assets.dart';
import '../../data/repositories/leaderboard_repository.dart';
import '../../data/repositories/leagues_repository.dart';
import '../../domain/models/leaderboard_entry.dart';
import 'player_profile_page.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _repo = LeaderboardRepository();
  final _leaguesRepo = LeaguesRepository();

  String? _leagueId;
  String? _teamId;
  bool _scopeLoading = true;

  final Map<int, List<LeaderboardEntry>> _entriesByTab = {};
  final Map<int, String?> _emptyByTab = {};
  final Map<int, bool> _loadingByTab = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final user = Supabase.instance.client.auth.currentUser;
    String? leagueId;
    String? teamId;
    if (user != null) {
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
    await Future.wait([_fetchTab(0), _fetchTab(1), _fetchTab(2)]);
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    final idx = _tabController.index;
    _fetchTab(idx);
  }

  Future<void> _fetchTab(int index) async {
    if (_scopeLoading) return;

    setState(() => _loadingByTab[index] = true);

    String? emptyMsg;
    List<LeaderboardEntry> list = [];

    switch (index) {
      case 0:
        list = await _repo.getOverall();
        if (list.isEmpty) {
          emptyMsg =
              'No points yet. Totals build from every finished match on the app.';
        }
        break;
      case 1:
        if (_leagueId == null) {
          emptyMsg =
              'Join a league to see how you rank against others who play there. '
              'Points still count all your matches app-wide.';
        } else {
          list = await _repo.getForLeague(_leagueId!);
          if (list.isEmpty) {
            emptyMsg =
                'No one has a finished match in this league yet. '
                'Anyone who plays here will appear once they do.';
          }
        }
        break;
      case 2:
        if (_teamId == null) {
          emptyMsg =
              'Join a team to see your squad. Rankings use total points from all '
              'your finished matches, not just one league.';
        } else {
          list = await _repo.getForTeam(_teamId!);
          if (list.isEmpty) {
            emptyMsg = 'No players on this team yet.';
          }
        }
        break;
    }

    if (!mounted) return;
    setState(() {
      _entriesByTab[index] = list;
      _emptyByTab[index] = emptyMsg;
      _loadingByTab[index] = false;
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
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
    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final activeTab = _tabController.index;
    final activeEntries = _entriesFor(activeTab);
    final activeEmpty = _emptyByTab[activeTab];
    final activeLoading = _loadingByTab[activeTab] == true;

    if (_scopeLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PodiumHeader(
          entries: activeEntries,
          loading: activeLoading,
          emptyMessage: activeEmpty,
        ),
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
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _LeaderboardTabBody(
                entries: _entriesFor(0),
                emptyMessage: _emptyByTab[0],
                loading: _loadingByTab[0] == true,
                formatPts: _formatPoints,
                currentUserId: currentUserId,
              ),
              _LeaderboardTabBody(
                entries: _entriesFor(1),
                emptyMessage: _emptyByTab[1],
                loading: _loadingByTab[1] == true,
                formatPts: _formatPoints,
                currentUserId: currentUserId,
              ),
              _LeaderboardTabBody(
                entries: _entriesFor(2),
                emptyMessage: _emptyByTab[2],
                loading: _loadingByTab[2] == true,
                formatPts: _formatPoints,
                currentUserId: currentUserId,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LeaderboardTabBody extends StatelessWidget {
  const _LeaderboardTabBody({
    required this.entries,
    required this.emptyMessage,
    required this.loading,
    required this.formatPts,
    required this.currentUserId,
  });

  final List<LeaderboardEntry> entries;
  final String? emptyMessage;
  final bool loading;
  final String Function(double) formatPts;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (loading && entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (emptyMessage != null && entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            emptyMessage!,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    if (entries.isEmpty) {
      return Center(
        child: Text(
          'No data yet.',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
                  highlight: currentUserId != null && e.playerId == currentUserId,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PodiumHeader extends StatelessWidget {
  const _PodiumHeader({
    required this.entries,
    required this.loading,
    this.emptyMessage,
  });

  final List<LeaderboardEntry> entries;
  final bool loading;
  final String? emptyMessage;

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
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Positioned.fill(
                  child: Image.asset(
                    AppAssets.leaderboardBg,
                    fit: BoxFit.cover,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    emptyMessage ?? 'No players to show yet.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          shadows: const [
                            Shadow(blurRadius: 8, color: Colors.black54),
                          ],
                        ),
                  ),
                ),
              ],
            ),
          );
        }

        final first = entries.length > 0 ? entries[0] : null;
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
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
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
        radius: 16,
        backgroundColor: colorScheme.surfaceContainerHighest,
        child: ClipOval(
          child: Image.network(
            url,
            width: 32,
            height: 32,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Image.asset(
              AppAssets.playerImage,
              width: 32,
              height: 32,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    } else if (url != null &&
        (url.startsWith('lib/assets/') || url.startsWith('assets/'))) {
      avatar = CircleAvatar(
        radius: 16,
        backgroundImage: AssetImage(url),
      );
    } else {
      avatar = CircleAvatar(
        radius: 16,
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
        child: Image.network(
          url,
          width: avatarSize,
          height: avatarSize,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Image.asset(
            AppAssets.playerImage,
            width: avatarSize,
            height: avatarSize,
            fit: BoxFit.cover,
          ),
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
          errorBuilder: (_, __, ___) => Image.asset(
            AppAssets.playerImage,
            width: avatarSize,
            height: avatarSize,
            fit: BoxFit.cover,
          ),
        ),
      );
    } else {
      img = ClipOval(
        child: Image.asset(
          AppAssets.playerImage,
          width: avatarSize,
          height: avatarSize,
          fit: BoxFit.cover,
        ),
      );
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
