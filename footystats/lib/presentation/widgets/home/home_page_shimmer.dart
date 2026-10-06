import 'package:flutter/material.dart';

import '../../../core/adaptive/adaptive.dart';
import '../../../core/widgets/app_shimmer.dart';

/// Skeleton layout mirroring the home tab while data loads.
class HomePageShimmer extends StatelessWidget {
  const HomePageShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final matchCardHeight = AppResponsive.homeMatchCarouselHeight(context);

    return AppShimmer(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppResponsive.horizontalInset(context),
          8 * AppResponsive.layoutScaleOf(context),
          AppResponsive.horizontalInset(context),
          26 * AppResponsive.layoutScaleOf(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ShimmerBox(width: 132, height: 28, borderRadius: 8),
            SizedBox(height: 8 * AppResponsive.layoutScaleOf(context)),
            const _GameweekFiltersShimmer(),
            const SizedBox(height: 12),
            const _GameweekHeaderShimmer(),
            const SizedBox(height: 8),
            const _ProgressRingsShimmer(),
            const SizedBox(height: 26),
            _PerformanceChartShimmer(
              width: (screenWidth - AppResponsive.horizontalInset(context) * 2)
                  .clamp(0, double.infinity),
            ),
            const SizedBox(height: 26),
            const ShimmerBox(width: 100, height: 24, borderRadius: 8),
            const SizedBox(height: 16),
            ShimmerBox(
              width: double.infinity,
              height: matchCardHeight,
              borderRadius: 28,
            ),
            const SizedBox(height: 26),
            const ShimmerBox(width: 56, height: 18, borderRadius: 6),
            const SizedBox(height: 16),
            const _TeamCardShimmer(),
            const SizedBox(height: 16),
            const ShimmerBox(width: 120, height: 24, borderRadius: 8),
            const SizedBox(height: 16),
            const _HighlightsRowShimmer(),
          ],
        ),
      ),
    );
  }
}

class _GameweekFiltersShimmer extends StatelessWidget {
  const _GameweekFiltersShimmer();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ShimmerBox(width: 88, height: 36, borderRadius: 18),
            SizedBox(width: 8),
            ShimmerBox(width: 96, height: 36, borderRadius: 18),
            SizedBox(width: 8),
            ShimmerBox(width: 80, height: 36, borderRadius: 18),
          ],
        ),
        SizedBox(height: 8),
        ShimmerBox(width: double.infinity, height: 48, borderRadius: 12),
      ],
    );
  }
}

class _GameweekHeaderShimmer extends StatelessWidget {
  const _GameweekHeaderShimmer();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 48,
      child: Center(
        child: ShimmerBox(width: 160, height: 22, borderRadius: 8),
      ),
    );
  }
}

class _ProgressRingsShimmer extends StatelessWidget {
  const _ProgressRingsShimmer();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Center(
          child: ShimmerBox(width: 163, height: 163, borderRadius: 999),
        ),
        SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ShimmerBox(width: 80, height: 80, borderRadius: 999),
            ShimmerBox(width: 80, height: 80, borderRadius: 999),
          ],
        ),
      ],
    );
  }
}

class _PerformanceChartShimmer extends StatelessWidget {
  const _PerformanceChartShimmer({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ShimmerBox(
        width: width,
        height: 297,
        borderRadius: 28,
      ),
    );
  }
}

class _TeamCardShimmer extends StatelessWidget {
  const _TeamCardShimmer();

  @override
  Widget build(BuildContext context) {
    return const ShimmerBox(
      width: double.infinity,
      height: 320,
      borderRadius: 28,
    );
  }
}

class _HighlightsRowShimmer extends StatelessWidget {
  const _HighlightsRowShimmer();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 204,
      child: Row(
        children: [
          ShimmerBox(width: 116, height: 204, borderRadius: 12),
          SizedBox(width: 8),
          ShimmerBox(width: 116, height: 204, borderRadius: 12),
          SizedBox(width: 8),
          ShimmerBox(width: 116, height: 204, borderRadius: 12),
        ],
      ),
    );
  }
}

/// Shimmer placeholder for the performance chart area when only ratings load.
class HomePerformanceChartShimmer extends StatelessWidget {
  const HomePerformanceChartShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppShimmer(
      child: ShimmerBox(
        width: double.infinity,
        height: 240,
        borderRadius: 16,
      ),
    );
  }
}

/// Shimmer placeholder for the this-week match carousel.
class HomeMatchCarouselShimmer extends StatelessWidget {
  const HomeMatchCarouselShimmer({super.key, required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ShimmerBox(
        width: double.infinity,
        height: height,
        borderRadius: 28,
      ),
    );
  }
}

/// Shimmer placeholder for gameweek team/league filters.
class HomeGameweekFiltersShimmer extends StatelessWidget {
  const HomeGameweekFiltersShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppShimmer(child: _GameweekFiltersShimmer());
  }
}

/// Shimmer placeholder for the team details card.
class HomeTeamSectionShimmer extends StatelessWidget {
  const HomeTeamSectionShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppShimmer(child: _TeamCardShimmer());
  }
}

/// Full guest/staff home skeleton: date filters and match groups.
class GuestHomePageShimmer extends StatelessWidget {
  const GuestHomePageShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: AppShimmer(
            child: Column(
              children: [
                _DateFilterChipsShimmer(),
                SizedBox(height: 12),
                _DateHeaderShimmer(),
              ],
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: const GuestHomeMatchListShimmer(),
          ),
        ),
      ],
    );
  }
}

/// Match-group cards for the guest/staff home list while fixtures load.
class GuestHomeMatchListShimmer extends StatelessWidget {
  const GuestHomeMatchListShimmer({super.key, this.padded = true});

  final bool padded;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padded
          ? EdgeInsets.fromLTRB(
              AppResponsive.horizontalInset(context),
              2,
              AppResponsive.horizontalInset(context),
              16 * AppResponsive.layoutScaleOf(context),
            )
          : EdgeInsets.zero,
      child: const Column(
        children: [
          _MatchGroupCardShimmer(),
          _MatchGroupCardShimmer(matchCount: 2),
        ],
      ),
    );
  }
}

class _DateFilterChipsShimmer extends StatelessWidget {
  const _DateFilterChipsShimmer();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: ShimmerBox(height: 40, borderRadius: 12)),
        SizedBox(width: 8),
        Expanded(child: ShimmerBox(height: 40, borderRadius: 12)),
        SizedBox(width: 8),
        Expanded(child: ShimmerBox(height: 40, borderRadius: 12)),
      ],
    );
  }
}

class _DateHeaderShimmer extends StatelessWidget {
  const _DateHeaderShimmer();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 48,
      child: Row(
        children: [
          ShimmerBox(width: 36, height: 36, borderRadius: 999),
          Spacer(),
          ShimmerBox(width: 88, height: 22, borderRadius: 8),
          Spacer(),
          ShimmerBox(width: 36, height: 36, borderRadius: 999),
        ],
      ),
    );
  }
}

class _MatchGroupCardShimmer extends StatelessWidget {
  const _MatchGroupCardShimmer({this.matchCount = 3});

  final int matchCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: AppShimmer(
        child: Column(
          children: [
            const Row(
              children: [
                ShimmerBox(width: 36, height: 36, borderRadius: 8),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: 140, height: 14, borderRadius: 4),
                      SizedBox(height: 6),
                      ShimmerBox(width: 88, height: 12, borderRadius: 4),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                ShimmerBox(width: 26, height: 26, borderRadius: 6),
              ],
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < matchCount; i++) const _MatchRowShimmer(),
          ],
        ),
      ),
    );
  }
}

class _MatchRowShimmer extends StatelessWidget {
  const _MatchRowShimmer();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: ShimmerBox(height: 14, borderRadius: 6)),
          SizedBox(width: 8),
          ShimmerBox(width: 28, height: 28, borderRadius: 999),
          SizedBox(width: 16),
          ShimmerBox(width: 56, height: 28, borderRadius: 8),
          SizedBox(width: 16),
          ShimmerBox(width: 28, height: 28, borderRadius: 999),
          SizedBox(width: 8),
          Expanded(child: ShimmerBox(height: 14, borderRadius: 6)),
        ],
      ),
    );
  }
}

/// Shimmer placeholder for league standings rows.
class HomeStandingsTableShimmer extends StatelessWidget {
  const HomeStandingsTableShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppShimmer(
      child: Column(
        children: [
          ShimmerBox(width: double.infinity, height: 28, borderRadius: 6),
          SizedBox(height: 8),
          ShimmerBox(width: double.infinity, height: 28, borderRadius: 6),
          SizedBox(height: 8),
          ShimmerBox(width: double.infinity, height: 28, borderRadius: 6),
          SizedBox(height: 8),
          ShimmerBox(width: double.infinity, height: 28, borderRadius: 6),
        ],
      ),
    );
  }
}
