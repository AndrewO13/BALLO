import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/widgets/media_placeholders.dart';
import '../../../domain/models/lineup_player_match_stats.dart';

class SquadCaptainBadge extends StatelessWidget {
  const SquadCaptainBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          'C',
          style: textTheme.labelMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _LineupStatIcon extends StatelessWidget {
  const _LineupStatIcon(this.assetPath);

  final String assetPath;

  static const _size = 13.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: SvgPicture.asset(
        assetPath,
        fit: BoxFit.contain,
      ),
    );
  }
}

class TeamPlayer extends StatelessWidget {
  const TeamPlayer({
    super.key,
    required this.name,
    required this.imageAsset,
    this.showCaptainBadge = false,
    this.matchStats,
  });

  final String name;
  final String imageAsset;
  final bool showCaptainBadge;
  final LineupPlayerMatchStats? matchStats;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final path = imageAsset.trim();
    final image = buildPlayerAvatar(
      imagePath: path.isEmpty ? null : path,
      size: 57,
      backgroundColor: colorScheme.surfaceContainerHighest,
      iconColor: colorScheme.onSurfaceVariant,
    );

    final stats = matchStats;
    final cardState = stats?.cardState ?? LineupCardState.none;
    final (pillColor, pillTextColor) = switch (cardState) {
      LineupCardState.yellow => (
          const Color(0xFFFBC02D),
          const Color(0xFF3E2723),
        ),
      LineupCardState.red => (
          const Color(0xFFE53935),
          Colors.white,
        ),
      LineupCardState.none => (colorScheme.primary, colorScheme.onPrimary),
    };

    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            top: 0,
            child: Container(
              width: 57,
              height: 57,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.outlineVariant, width: 1),
              ),
              child: ClipOval(child: image),
            ),
          ),
          if (showCaptainBadge)
            const Positioned(top: 0, left: 0, child: SquadCaptainBadge()),
          if (stats != null && stats.hasAnyBadge)
            Positioned(
              top: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (stats.hasGoal) ...[
                    const _LineupStatIcon(AppAssets.matchGoalIcon),
                    if (stats.hasAssist || stats.hasTackle || stats.subbedIn || stats.subbedOut)
                      const SizedBox(height: 1),
                  ],
                  if (stats.hasAssist) ...[
                    const _LineupStatIcon(AppAssets.assistIcon),
                    if (stats.hasTackle || stats.subbedIn || stats.subbedOut)
                      const SizedBox(height: 1),
                  ],
                  if (stats.hasTackle) ...[
                    const _LineupStatIcon(AppAssets.tackleIcon),
                    if (stats.subbedIn || stats.subbedOut)
                      const SizedBox(height: 1),
                  ],
                  if (stats.subbedIn) ...[
                    const _LineupStatIcon(AppAssets.squadSubInIcon),
                    if (stats.subbedOut) const SizedBox(height: 1),
                  ],
                  if (stats.subbedOut)
                    const _LineupStatIcon(AppAssets.squadSubOutIcon),
                ],
              ),
            ),
          Positioned(
            bottom: 0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 56),
              child: Container(
                height: 19,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: pillColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Center(
                  child: Text(
                    name.length > 6 ? '${name.substring(0, 6)}…' : name,
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: pillTextColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
