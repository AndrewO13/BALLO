import 'package:flutter/material.dart';

import '../../core/adaptive/adaptive.dart';
import '../../core/widgets/app_shimmer.dart';
import '../../core/theme/app_shape.dart';

/// Rankings tab: period toggle + stat chips + leader card + list.
class RankingsContentShimmer extends StatelessWidget {
  const RankingsContentShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final inset = AppResponsive.horizontalInset(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(inset, 8, inset, 24),
      child: AppShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            ShimmerBox(height: 148, borderRadius: AppShape.medium),
            SizedBox(height: 12),
            ShimmerBox(height: 280, borderRadius: AppShape.medium),
          ],
        ),
      ),
    );
  }
}

/// Podium + ranked table used while a leaderboard tab loads.
class LeaderboardContentShimmer extends StatelessWidget {
  const LeaderboardContentShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        LeaderboardPodiumShimmer(),
        Expanded(child: LeaderboardTableShimmer()),
      ],
    );
  }
}

class LeaderboardPodiumShimmer extends StatelessWidget {
  const LeaderboardPodiumShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: AppShimmer(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: const [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ShimmerBox(
                      width: 48,
                      height: 48,
                      borderRadius: AppShape.full,
                    ),
                    SizedBox(height: 8),
                    ShimmerBox(
                      width: 64,
                      height: 12,
                      borderRadius: AppShape.extraSmall,
                    ),
                    SizedBox(height: 8),
                    ShimmerBox(
                      width: double.infinity,
                      height: 72,
                      borderRadius: AppShape.medium,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ShimmerBox(
                      width: 56,
                      height: 56,
                      borderRadius: AppShape.full,
                    ),
                    SizedBox(height: 8),
                    ShimmerBox(
                      width: 72,
                      height: 12,
                      borderRadius: AppShape.extraSmall,
                    ),
                    SizedBox(height: 8),
                    ShimmerBox(
                      width: double.infinity,
                      height: 110,
                      borderRadius: AppShape.medium,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ShimmerBox(
                      width: 48,
                      height: 48,
                      borderRadius: AppShape.full,
                    ),
                    SizedBox(height: 8),
                    ShimmerBox(
                      width: 64,
                      height: 12,
                      borderRadius: AppShape.extraSmall,
                    ),
                    SizedBox(height: 8),
                    ShimmerBox(
                      width: double.infinity,
                      height: 56,
                      borderRadius: AppShape.medium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LeaderboardTableShimmer extends StatelessWidget {
  const LeaderboardTableShimmer({super.key, this.rowCount = 8});

  final int rowCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppResponsive.horizontalInset(context),
        16 * AppResponsive.layoutScaleOf(context),
        AppResponsive.horizontalInset(context),
        24 * AppResponsive.layoutScaleOf(context),
      ),
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outlineVariant, width: 1.2),
            borderRadius: AppShape.mediumRadius,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: AppShimmer(
            child: Column(
              children: [
                for (var i = 0; i < rowCount; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  const _LeaderboardRowShimmer(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LeaderboardRowShimmer extends StatelessWidget {
  const _LeaderboardRowShimmer();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          ShimmerBox(width: 24, height: 14, borderRadius: AppShape.extraSmall),
          SizedBox(width: 12),
          ShimmerBox(width: 32, height: 32, borderRadius: AppShape.full),
          SizedBox(width: 12),
          Expanded(
            child: ShimmerBox(height: 14, borderRadius: AppShape.extraSmall),
          ),
          SizedBox(width: 12),
          ShimmerBox(width: 28, height: 14, borderRadius: AppShape.extraSmall),
          SizedBox(width: 12),
          ShimmerBox(width: 36, height: 14, borderRadius: AppShape.extraSmall),
        ],
      ),
    );
  }
}

/// Explore feed cards (match header + video block + poster).
class ExploreFeedShimmer extends StatelessWidget {
  const ExploreFeedShimmer({super.key, this.cardCount = 1});

  final int cardCount;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (var i = 0; i < cardCount; i++) const ExploreFeedCardShimmer(),
      ],
    );
  }
}

class ExploreFeedCardShimmer extends StatelessWidget {
  const ExploreFeedCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final videoHeight = MediaQuery.sizeOf(context).height * 0.5;
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppShape.medium),
              topRight: Radius.circular(AppShape.medium),
            ),
          ),
          child: const AppShimmer(
            child: Column(
              children: [
                ShimmerBox(
                  width: 140,
                  height: 14,
                  borderRadius: AppShape.extraSmall,
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        ShimmerBox(
                          width: 56,
                          height: 56,
                          borderRadius: AppShape.full,
                        ),
                        SizedBox(height: 8),
                        ShimmerBox(
                          width: 48,
                          height: 12,
                          borderRadius: AppShape.extraSmall,
                        ),
                      ],
                    ),
                    ShimmerBox(
                      width: 28,
                      height: 28,
                      borderRadius: AppShape.small,
                    ),
                    ShimmerBox(
                      width: 44,
                      height: 18,
                      borderRadius: AppShape.largeIncreased,
                    ),
                    ShimmerBox(
                      width: 28,
                      height: 28,
                      borderRadius: AppShape.small,
                    ),
                    Column(
                      children: [
                        ShimmerBox(
                          width: 56,
                          height: 56,
                          borderRadius: AppShape.full,
                        ),
                        SizedBox(height: 8),
                        ShimmerBox(
                          width: 48,
                          height: 12,
                          borderRadius: AppShape.extraSmall,
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 8),
                ShimmerBox(
                  width: 88,
                  height: 14,
                  borderRadius: AppShape.extraSmall,
                ),
              ],
            ),
          ),
        ),
        AppShimmer(
          child: ShimmerBox(
            width: double.infinity,
            height: videoHeight,
            borderRadius: 0,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: AppShimmer(
            child: const Row(
              children: [
                ShimmerBox(width: 40, height: 40, borderRadius: AppShape.full),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(
                        width: 120,
                        height: 14,
                        borderRadius: AppShape.extraSmall,
                      ),
                      SizedBox(height: 6),
                      ShimmerBox(
                        width: 72,
                        height: 12,
                        borderRadius: AppShape.extraSmall,
                      ),
                    ],
                  ),
                ),
                ShimmerBox(width: 28, height: 28, borderRadius: AppShape.full),
                SizedBox(width: 12),
                ShimmerBox(
                  width: 64,
                  height: 28,
                  borderRadius: AppShape.medium,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// League / team detail header + tabs + list, used on the initial page load.
class EntityDetailPageShimmer extends StatelessWidget {
  const EntityDetailPageShimmer({super.key, this.circularLogo = false});

  final bool circularLogo;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Container(
              height: circularLogo ? 214 : 184,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppShape.medium),
                  topRight: Radius.circular(AppShape.medium),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: AppShimmer(
                child: Row(
                  children: [
                    ShimmerBox(
                      width: 96,
                      height: 96,
                      borderRadius: circularLogo ? 999 : 28,
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ShimmerBox(
                            width: 180,
                            height: 22,
                            borderRadius: AppShape.small,
                          ),
                          SizedBox(height: 8),
                          ShimmerBox(
                            width: 120,
                            height: 14,
                            borderRadius: AppShape.extraSmall,
                          ),
                          SizedBox(height: 12),
                          ShimmerBox(
                            width: 96,
                            height: 22,
                            borderRadius: AppShape.largeIncreased,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: AppShimmer(
              child: const Row(
                children: [
                  ShimmerBox(
                    width: 78,
                    height: 28,
                    borderRadius: AppShape.largeIncreased,
                  ),
                  SizedBox(width: 8),
                  ShimmerBox(
                    width: 72,
                    height: 28,
                    borderRadius: AppShape.largeIncreased,
                  ),
                  SizedBox(width: 8),
                  ShimmerBox(
                    width: 88,
                    height: 28,
                    borderRadius: AppShape.largeIncreased,
                  ),
                  SizedBox(width: 8),
                  ShimmerBox(
                    width: 64,
                    height: 28,
                    borderRadius: AppShape.largeIncreased,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.all(16),
            child: DetailListShimmer(),
          ),
        ],
      ),
    );
  }
}

class DetailListShimmer extends StatelessWidget {
  const DetailListShimmer({super.key, this.rowCount = 4});

  final int rowCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < rowCount; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          const _DetailListRowShimmer(),
        ],
      ],
    );
  }
}

class _DetailListRowShimmer extends StatelessWidget {
  const _DetailListRowShimmer();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: AppShape.mediumRadius,
      ),
      padding: const EdgeInsets.all(16),
      child: const AppShimmer(
        child: Row(
          children: [
            ShimmerBox(width: 48, height: 48, borderRadius: AppShape.full),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(
                    width: 150,
                    height: 16,
                    borderRadius: AppShape.extraSmall,
                  ),
                  SizedBox(height: 8),
                  ShimmerBox(
                    width: 96,
                    height: 12,
                    borderRadius: AppShape.extraSmall,
                  ),
                ],
              ),
            ),
            SizedBox(width: 12),
            ShimmerBox(
              width: 20,
              height: 20,
              borderRadius: AppShape.extraSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class DetailTableShimmer extends StatelessWidget {
  const DetailTableShimmer({super.key, this.rowCount = 8});

  final int rowCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: AppShape.mediumRadius,
      ),
      padding: const EdgeInsets.all(16),
      child: AppShimmer(
        child: Column(
          children: [
            for (var i = 0; i < rowCount; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              const Row(
                children: [
                  ShimmerBox(
                    width: 22,
                    height: 14,
                    borderRadius: AppShape.extraSmall,
                  ),
                  SizedBox(width: 12),
                  ShimmerBox(
                    width: 32,
                    height: 32,
                    borderRadius: AppShape.full,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ShimmerBox(
                      height: 14,
                      borderRadius: AppShape.extraSmall,
                    ),
                  ),
                  SizedBox(width: 12),
                  ShimmerBox(
                    width: 28,
                    height: 14,
                    borderRadius: AppShape.extraSmall,
                  ),
                  SizedBox(width: 8),
                  ShimmerBox(
                    width: 28,
                    height: 14,
                    borderRadius: AppShape.extraSmall,
                  ),
                  SizedBox(width: 8),
                  ShimmerBox(
                    width: 28,
                    height: 14,
                    borderRadius: AppShape.extraSmall,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class DetailVideoGridShimmer extends StatelessWidget {
  const DetailVideoGridShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: AppShimmer(
        child: GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.75,
          children: const [
            ShimmerBox(borderRadius: AppShape.large),
            ShimmerBox(borderRadius: AppShape.large),
            ShimmerBox(borderRadius: AppShape.large),
            ShimmerBox(borderRadius: AppShape.large),
          ],
        ),
      ),
    );
  }
}

/// Placeholder row used inside an existing section card.
class DetailInlineShimmer extends StatelessWidget {
  const DetailInlineShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: AppShimmer(
        child: Row(
          children: [
            ShimmerBox(width: 40, height: 40, borderRadius: AppShape.full),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(
                    width: 140,
                    height: 14,
                    borderRadius: AppShape.extraSmall,
                  ),
                  SizedBox(height: 8),
                  ShimmerBox(
                    width: 88,
                    height: 12,
                    borderRadius: AppShape.extraSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DetailSectionCardShimmer extends StatelessWidget {
  const DetailSectionCardShimmer({super.key, this.height = 88});

  final double height;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: AppShape.mediumRadius,
      ),
      padding: const EdgeInsets.all(16),
      child: const AppShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerBox(
              width: 120,
              height: 14,
              borderRadius: AppShape.extraSmall,
            ),
            SizedBox(height: 16),
            ShimmerBox(
              width: double.infinity,
              height: 16,
              borderRadius: AppShape.extraSmall,
            ),
          ],
        ),
      ),
    );
  }
}
