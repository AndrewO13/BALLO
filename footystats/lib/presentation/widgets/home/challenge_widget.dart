import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/adaptive/adaptive.dart';

import '../../../data/repositories/player_stats_repository.dart';
import '../../../domain/models/player_badge.dart';
import '../../../domain/models/player_year_team_stats.dart';

/// Home app-bar challenge tracker for the active profile badge milestone.
class ChallengeWidget extends StatefulWidget {
  const ChallengeWidget({super.key, this.refreshTick = 0});

  /// Increment to reload career stats (e.g. after home pull-to-refresh).
  final int refreshTick;

  @override
  State<ChallengeWidget> createState() => _ChallengeWidgetState();
}

class _ChallengeWidgetState extends State<ChallengeWidget> {
  Future<PlayerAllTimeStats?>? _statsFuture;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void didUpdateWidget(covariant ChallengeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) {
      _loadStats();
    }
  }

  void _loadStats() {
    final playerId = Supabase.instance.client.auth.currentUser?.id;
    if (playerId == null || playerId.isEmpty) {
      _statsFuture = Future.value(null);
      return;
    }
    _statsFuture = PlayerStatsRepository().getPlayerAllTimeStats(playerId);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return FutureBuilder<PlayerAllTimeStats?>(
      future: _statsFuture,
      builder: (context, snapshot) {
        final stats = snapshot.data;
        final badge = PlayerBadges.trackerBadge(stats);
        final progress = badge.progressFor(stats);
        final percent = badge.progressPercentFor(stats);

        final scale = AppResponsive.layoutScaleOf(context);
        return SizedBox(
          width: 120 * scale,
          height: 40 * scale,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                width: 1,
                color: colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(width: 8),
                SizedBox(
                  width: 24 * scale,
                  height: 24 * scale,
                  child: SvgPicture.asset(
                    badge.svgPath,
                    width: 24 * scale,
                    height: 24 * scale,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.emoji_events_outlined,
                        size: 24 * scale,
                        color: colorScheme.primary,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          badge.pointsLabel,
                          style: textTheme.labelSmall,
                        ),
                        const SizedBox(width: 20),
                        Text(
                          '$percent%',
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.secondaryContainer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 60 * scale,
                      height: 2,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          year2023: false,
                          value: progress,
                          minHeight: 2,
                          color: colorScheme.primary,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
              ],
            ),
          ),
        );
      },
    );
  }
}
