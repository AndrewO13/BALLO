import '../../core/constants/app_assets.dart';
import 'player_year_team_stats.dart';

enum PlayerBadgeMetric { goals, tackles }

/// Milestone badge shown on the profile Overview tab.
///
/// Progress uses career totals from [PlayerAllTimeStats]. Earned badges add
/// [pointsReward] to leaderboard totals (see `player_badge_bonus_points` RPC).
class PlayerBadgeDefinition {
  const PlayerBadgeDefinition({
    required this.id,
    required this.svgPath,
    required this.pointsReward,
    required this.name,
    required this.objective,
    required this.target,
    required this.metric,
  });

  final String id;
  final String svgPath;
  final int pointsReward;
  final String name;
  final String objective;
  final int target;
  final PlayerBadgeMetric metric;

  String get pointsLabel => '+$pointsReward';

  int currentValue(PlayerAllTimeStats? stats) {
    if (stats == null) return 0;
    return switch (metric) {
      PlayerBadgeMetric.goals => stats.goals,
      PlayerBadgeMetric.tackles => stats.tackles,
    };
  }

  /// 0.0–1.0 progress toward [target].
  double progressFor(PlayerAllTimeStats? stats) {
    if (target <= 0) return 0;
    return (currentValue(stats) / target).clamp(0.0, 1.0);
  }

  int progressPercentFor(PlayerAllTimeStats? stats) =>
      (progressFor(stats) * 100).round();

  bool isEarned(PlayerAllTimeStats? stats) => progressFor(stats) >= 1.0;
}

/// Badge catalog — keep in sync with `player_badge_bonus_points` in Supabase.
abstract final class PlayerBadges {
  static const ironFoot = PlayerBadgeDefinition(
    id: 'iron_foot',
    svgPath: AppAssets.proBadge,
    pointsReward: 10,
    name: 'Iron-foot',
    objective: 'Score 100 goals',
    target: 100,
    metric: PlayerBadgeMetric.goals,
  );

  static const lockdownDefender = PlayerBadgeDefinition(
    id: 'lockdown_defender',
    svgPath: AppAssets.masterBadge,
    pointsReward: 10,
    name: 'Lock-down defender 💪',
    objective: 'Make 100 tackles',
    target: 100,
    metric: PlayerBadgeMetric.tackles,
  );

  static const footyMaster = PlayerBadgeDefinition(
    id: 'footy_master',
    svgPath: AppAssets.legendaryBadge,
    pointsReward: 100,
    name: 'Footy Master',
    objective: 'Reach 10K goals',
    target: 10000,
    metric: PlayerBadgeMetric.goals,
  );

  static const List<PlayerBadgeDefinition> all = [
    ironFoot,
    lockdownDefender,
    footyMaster,
  ];

  static int totalBonusPoints(PlayerAllTimeStats? stats) {
    var bonus = 0;
    for (final badge in all) {
      if (badge.isEarned(stats)) bonus += badge.pointsReward;
    }
    return bonus;
  }

  /// Badge for the home challenge tracker: highest progress among incomplete
  /// milestones; if every badge is earned, [footyMaster] at 100%.
  static PlayerBadgeDefinition trackerBadge(PlayerAllTimeStats? stats) {
    PlayerBadgeDefinition? leading;
    var leadingProgress = -1.0;
    for (final badge in all) {
      final progress = badge.progressFor(stats);
      if (progress >= 1.0) continue;
      if (progress > leadingProgress) {
        leadingProgress = progress;
        leading = badge;
      }
    }
    return leading ?? all.last;
  }
}
