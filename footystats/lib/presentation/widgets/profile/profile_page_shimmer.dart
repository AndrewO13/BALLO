import 'package:flutter/material.dart';

import '../../../core/widgets/app_shimmer.dart';

/// Hero header skeleton shown while profile data loads.
class ProfileHeaderShimmer extends StatelessWidget {
  const ProfileHeaderShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppShimmer(
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        child: ColoredBox(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    ShimmerBox(width: 72, height: 72, borderRadius: 999),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(
                            width: double.infinity,
                            height: 28,
                            borderRadius: 8,
                          ),
                          SizedBox(height: 8),
                          ShimmerBox(width: 120, height: 16, borderRadius: 6),
                        ],
                      ),
                    ),
                    SizedBox(width: 12),
                    ShimmerBox(width: 60, height: 40, borderRadius: 999),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    ShimmerBox(width: 88, height: 32, borderRadius: 16),
                    SizedBox(width: 8),
                    ShimmerBox(width: 88, height: 32, borderRadius: 16),
                    SizedBox(width: 8),
                    ShimmerBox(width: 88, height: 32, borderRadius: 16),
                    SizedBox(width: 8),
                    ShimmerBox(width: 88, height: 32, borderRadius: 16),
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

/// Rounded card placeholder used across profile sections.
class ProfileSectionCardShimmer extends StatelessWidget {
  const ProfileSectionCardShimmer({
    super.key,
    this.height = 160,
    this.showTitle = true,
  });

  final double height;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppShimmer(
      child: Container(
        width: double.infinity,
        height: height,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showTitle) ...[
              const ShimmerBox(width: 120, height: 18, borderRadius: 6),
              const SizedBox(height: 16),
            ],
            const Expanded(
              child: ShimmerBox(
                width: double.infinity,
                height: double.infinity,
                borderRadius: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Overview tab skeleton (attributes, next match, form, history, trophies).
class ProfileOverviewTabShimmer extends StatelessWidget {
  const ProfileOverviewTabShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        ProfileSectionCardShimmer(height: 280, showTitle: true),
        SizedBox(height: 16),
        ProfileSectionCardShimmer(height: 120, showTitle: true),
        SizedBox(height: 16),
        ProfileSectionCardShimmer(height: 180, showTitle: true),
        SizedBox(height: 16),
        ProfileSectionCardShimmer(height: 200, showTitle: true),
        SizedBox(height: 16),
        ProfileSectionCardShimmer(height: 160, showTitle: true),
        SizedBox(height: 16),
        ProfileSectionCardShimmer(height: 100, showTitle: true),
        SizedBox(height: 16),
        ProfileSectionCardShimmer(height: 88, showTitle: false),
      ],
    );
  }
}

/// Match list skeleton for the profile Matches tab.
class ProfileMatchListShimmer extends StatelessWidget {
  const ProfileMatchListShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppShimmer(
      child: Column(
        children: [
          _MatchDateGroupShimmer(),
          SizedBox(height: 12),
          _MatchDateGroupShimmer(),
          SizedBox(height: 12),
          _MatchDateGroupShimmer(),
        ],
      ),
    );
  }
}

class _MatchDateGroupShimmer extends StatelessWidget {
  const _MatchDateGroupShimmer();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(width: 100, height: 16, borderRadius: 6),
          SizedBox(height: 12),
          ShimmerBox(width: double.infinity, height: 72, borderRadius: 16),
          SizedBox(height: 8),
          ShimmerBox(width: double.infinity, height: 72, borderRadius: 16),
        ],
      ),
    );
  }
}

/// Video tab skeleton with sort bar and thumbnail grid.
class ProfileVideosTabShimmer extends StatelessWidget {
  const ProfileVideosTabShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ShimmerBox(width: 120, height: 20, borderRadius: 6),
                Spacer(),
                ShimmerBox(width: 40, height: 40, borderRadius: 20),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  Expanded(child: _VideoThumbnailRowShimmer()),
                  SizedBox(height: 8),
                  Expanded(child: _VideoThumbnailRowShimmer()),
                  SizedBox(height: 8),
                  Expanded(child: _VideoThumbnailRowShimmer()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoThumbnailRowShimmer extends StatelessWidget {
  const _VideoThumbnailRowShimmer();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: ShimmerBox(borderRadius: 12)),
        SizedBox(width: 8),
        Expanded(child: ShimmerBox(borderRadius: 12)),
        SizedBox(width: 8),
        Expanded(child: ShimmerBox(borderRadius: 12)),
      ],
    );
  }
}
