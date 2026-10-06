import 'package:flutter/material.dart';

import '../../core/widgets/app_shimmer.dart';

/// Skeleton for Add to matches: create cards, then leagues and teams lists.
class AddToMatchesPageShimmer extends StatelessWidget {
  const AddToMatchesPageShimmer({
    super.key,
    this.includeStaffSections = false,
  });

  final bool includeStaffSections;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppShimmer(child: ShimmerBox(width: 220, height: 20, borderRadius: 6)),
          const SizedBox(height: 16),
          const _ChoiceCardShimmer(),
          const SizedBox(height: 12),
          const _ChoiceCardShimmer(),
          const SizedBox(height: 12),
          const _ChoiceCardShimmer(),
          if (includeStaffSections) ...[
            const SizedBox(height: 12),
            const _ChoiceCardShimmer(),
          ],
          const SizedBox(height: 32),
          const AppShimmer(child: ShimmerBox(width: 88, height: 20, borderRadius: 6)),
          const SizedBox(height: 16),
          const _ItemCardShimmer(),
          const SizedBox(height: 12),
          const _ItemCardShimmer(),
          const SizedBox(height: 32),
          const AppShimmer(child: ShimmerBox(width: 72, height: 20, borderRadius: 6)),
          const SizedBox(height: 16),
          const _ItemCardShimmer(),
          const SizedBox(height: 12),
          const _ItemCardShimmer(),
          if (includeStaffSections) ...[
            const SizedBox(height: 32),
            const AppShimmer(
              child: ShimmerBox(width: 160, height: 20, borderRadius: 6),
            ),
            const SizedBox(height: 16),
            const _PlayerCardShimmer(),
            const SizedBox(height: 12),
            const _PlayerCardShimmer(),
          ],
        ],
      ),
    );
  }
}

class _ChoiceCardShimmer extends StatelessWidget {
  const _ChoiceCardShimmer();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(16),
      child: const AppShimmer(
        child: Row(
          children: [
            ShimmerBox(width: 40, height: 40, borderRadius: 999),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 120, height: 16, borderRadius: 4),
                  SizedBox(height: 8),
                  ShimmerBox(width: double.infinity, height: 12, borderRadius: 4),
                  SizedBox(height: 4),
                  ShimmerBox(width: 180, height: 12, borderRadius: 4),
                ],
              ),
            ),
            SizedBox(width: 12),
            ShimmerBox(width: 20, height: 20, borderRadius: 4),
          ],
        ),
      ),
    );
  }
}

class _ItemCardShimmer extends StatelessWidget {
  const _ItemCardShimmer();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(16),
      child: const AppShimmer(
        child: Row(
          children: [
            ShimmerBox(width: 48, height: 48, borderRadius: 999),
            SizedBox(width: 16),
            Expanded(child: ShimmerBox(height: 16, borderRadius: 4)),
            SizedBox(width: 12),
            ShimmerBox(width: 20, height: 20, borderRadius: 4),
          ],
        ),
      ),
    );
  }
}

class _PlayerCardShimmer extends StatelessWidget {
  const _PlayerCardShimmer();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(16),
      child: const AppShimmer(
        child: Row(
          children: [
            ShimmerBox(width: 48, height: 48, borderRadius: 999),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 140, height: 16, borderRadius: 4),
                  SizedBox(height: 6),
                  ShimmerBox(width: 110, height: 12, borderRadius: 4),
                  SizedBox(height: 10),
                  ShimmerBox(width: 88, height: 12, borderRadius: 4),
                ],
              ),
            ),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ShimmerBox(width: 48, height: 16, borderRadius: 4),
                SizedBox(height: 12),
                ShimmerBox(width: 72, height: 16, borderRadius: 4),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
