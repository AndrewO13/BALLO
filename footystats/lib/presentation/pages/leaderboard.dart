import 'package:flutter/material.dart';
import '../../core/constants/app_assets.dart';

class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: TabBar(
              labelColor: Theme.of(context).colorScheme.onSurface,
              indicatorColor: Theme.of(context).colorScheme.primary,
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'Team'),
                Tab(text: 'League'),
                Tab(text: 'Overall'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _LeaderboardTabContent(),
                _LeaderboardTabContent(),
                _LeaderboardTabContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardTabContent extends StatelessWidget {
  const _LeaderboardTabContent();

  @override
  Widget build(BuildContext context) {
    // Example avatars, update as needed
    final avatars = [
      AppAssets.avatar20,
      AppAssets.avatar18,
      AppAssets.avatar13,
    ];
    // Example leaderboard data
    final leaderboard = [
      {
        'pos': 1,
        'change': 1,
        'name': 'Andrew Ogwang',
        'avatar': AppAssets.avatar18,
        'gw': 19,
        'total': '23.4K',
        'highlight': false,
      },
      {
        'pos': 2,
        'change': -1,
        'name': 'Gareth Neville',
        'avatar': AppAssets.avatar20,
        'gw': 18,
        'total': '15',
        'highlight': true,
      },
      {
        'pos': 3,
        'change': 0,
        'name': 'Katende Derrick',
        'avatar': AppAssets.avatar13,
        'gw': 18,
        'total': '3',
        'highlight': false,
      },
    ];
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 412,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _LeaderboardBar(
                      height: 100,
                      color: const Color(0xFFF2FFF1),
                      avatar: avatars[0],
                      name: 'Gareth Neville',
                      points: 1000,
                    ),
                    const SizedBox(width: 8),
                    _LeaderboardBar(
                      height: 120,
                      color: const Color(0xFF14FF8E),
                      avatar: avatars[1],
                      name: 'Andrew Ogwang',
                      points: 3000,
                    ),
                    const SizedBox(width: 8),
                    _LeaderboardBar(
                      height: 48,
                      color: const Color(0xFFF2FFF1),
                      avatar: avatars[2],
                      name: 'Katende Derrick',
                      points: 290,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
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
                        width: 32,
                        child: Text(
                          'Pos',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.white70),
                        ),
                      ),
                      SizedBox(
                        width: 32,
                        child: Text(
                          '',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        child: Text(
                          'Player',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.white70),
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 32,
                        child: Text(
                          'GW',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.white70),
                        ),
                      ),
                      SizedBox(
                        width: 35,
                        child: Text(
                          'Total',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
                // Table rows
                ...leaderboard.map((row) {
                  final isHighlighted = row['highlight'] == true;
                  final int pos = row['pos'] as int;
                  final int change = row['change'] as int;
                  final String name = row['name'] as String;
                  final String avatar = row['avatar'] as String;
                  final int gw = row['gw'] as int;
                  final String total = row['total'] as String;
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: isHighlighted
                        ? BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(30),
                          )
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 32,
                            child: Text(
                              pos.toString(),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(
                            width: 32,
                            child: Center(
                              child: change > 0
                                  ? const Icon(
                                      Icons.arrow_drop_up,
                                      color: Color(0xff39ff14),
                                      size: 20,
                                    )
                                  : change < 0
                                  ? const Icon(
                                      Icons.arrow_drop_down,
                                      color: Color(0xffff0000),
                                      size: 20,
                                    )
                                  : Icon(
                                      Icons.remove,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.outline,
                                      size: 18,
                                    ),
                            ),
                          ),
                          SizedBox(
                            width: 120,
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundImage: AssetImage(avatar),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    name,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: 32,
                            child: Text(
                              gw.toString(),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(
                            width: 48,
                            child: Text(
                              total,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardBar extends StatelessWidget {
  final double height;
  final Color color;
  final String avatar;
  final String name;
  final int points;
  const _LeaderboardBar({
    required this.height,
    required this.color,
    required this.avatar,
    required this.name,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    const double width = 120;
    const double avatarSize = 60;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: avatarSize,
          height: avatarSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
          ),
          child: ClipOval(
            child: Image.asset(
              avatar,
              width: avatarSize,
              height: avatarSize,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: width,
          child: Text(
            name,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 81,
          height: 32,
          child: FilledButton.icon(
            onPressed: () {},
            icon: const Icon(
              Icons.stars_rounded,
              color: Color(0xff00391b),
              size: 18,
            ),
            label: Text(
              points.toString(),
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(81, 32),
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

// (Removed unused _ButtonHeaderDelegate)
