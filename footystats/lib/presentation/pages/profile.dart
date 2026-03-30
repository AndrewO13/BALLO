import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/countries.dart';
import '../../data/repositories/user_profile_repository.dart';
import '../../domain/models/user_profile.dart';
import 'edit_profile_page.dart';
import 'league_video_player_page.dart';
import '../../data/repositories/leagues_repository.dart';
import '../../data/repositories/matches_repository.dart';
import '../../data/repositories/teams_repository.dart';
import '../../domain/models/match_model.dart';
import '../../domain/models/team_membership_stint.dart';
import '../../domain/models/team_model.dart';
import '../widgets/socials_section_card.dart';
import '../widgets/performance_radar_chart.dart';

/// Profile tabs and scroll layout. When [viewedPlayerId] is null, shows the signed-in user.
class ProfileScrollView extends StatelessWidget {
  const ProfileScrollView({super.key, this.viewedPlayerId});

  /// If null, the current auth user is shown (main Profile tab).
  final String? viewedPlayerId;

  @override
  Widget build(BuildContext context) {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final effectiveId = viewedPlayerId ?? uid;
    if (effectiveId == null || effectiveId.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Sign in to view your profile.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final isOwnProfile = viewedPlayerId == null || viewedPlayerId == uid;

    return DefaultTabController(
      length: 4,
      child: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: _ProfileCard(
                  playerId: effectiveId,
                  showEditButton: isOwnProfile,
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  labelColor: Theme.of(context).colorScheme.onSurface,
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  indicatorWeight: 3,
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Stats'),
                    Tab(text: 'Career'),
                    Tab(text: 'Video'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          children: [
            _ProfileTabContent(
              title: 'Overview',
              profilePlayerId: effectiveId,
              isOwnProfile: isOwnProfile,
            ),
            _ProfileTabContent(
              title: 'Stats',
              profilePlayerId: effectiveId,
              isOwnProfile: isOwnProfile,
            ),
            _ProfileTabContent(
              title: 'Career',
              profilePlayerId: effectiveId,
              isOwnProfile: isOwnProfile,
            ),
            _ProfileTabContent(
              title: 'Video',
              profilePlayerId: effectiveId,
              isOwnProfile: isOwnProfile,
            ),
          ],
        ),
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) => const ProfileScrollView();
}

// Custom delegate for sticky TabBar
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}

class _ProfileTabContent extends StatelessWidget {
  final String title;
  final String profilePlayerId;
  final bool isOwnProfile;

  const _ProfileTabContent({
    required this.title,
    required this.profilePlayerId,
    required this.isOwnProfile,
  });

  @override
  Widget build(BuildContext context) {
    if (title == 'Overview') {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AttributesSection(profilePlayerId: profilePlayerId),
          const SizedBox(height: 16),
          _NextMatchSection(profilePlayerId: profilePlayerId),
          const SizedBox(height: 16),
          _TeamFormSection(),
          const SizedBox(height: 16),
          _ClubHistorySection(
            profilePlayerId: profilePlayerId,
            isOwnProfile: isOwnProfile,
          ),
          const SizedBox(height: 16),
          _TrophiesSection(profilePlayerId: profilePlayerId),
          const SizedBox(height: 16),
          _BadgesSection(),
          const SizedBox(height: 16),
          _ProfileSocialsSection(profilePlayerId: profilePlayerId),
        ],
      );
    }
    if (title == 'Stats') {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SeasonOverallSection(profilePlayerId: profilePlayerId),
          const SizedBox(height: 16),
          _TeamSeasonPerformanceSection(),
        ],
      );
    }
    if (title == 'Career') {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AllTimeStatsSection(),
          const SizedBox(height: 16),
          _TeamStatsSection(),
        ],
      );
    }
    if (title == 'Video') {
      return _ProfileVideosTab(profilePlayerId: profilePlayerId);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        const SizedBox(height: 12),
        Text(
          'Content coming soon.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ProfileSocialsSection extends StatelessWidget {
  const _ProfileSocialsSection({required this.profilePlayerId});

  final String profilePlayerId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: UserProfileRepository().getProfileByPlayerId(profilePlayerId),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        return SocialsSectionCard(
          title: 'Player socials',
          instagramUrl: profile?.socialInstagram,
          tiktokUrl: profile?.socialTiktok,
          xUrl: profile?.socialX,
          emptyHint:
              'Add Instagram, TikTok, or X URLs in Edit profile (https://…).',
        );
      },
    );
  }
}

class _SeasonOverallSection extends StatelessWidget {
  const _SeasonOverallSection({required this.profilePlayerId});

  final String profilePlayerId;

  Future<_SeasonOverallStats?> _loadSeasonOverall() async {
    final client = Supabase.instance.client;

    List<Map<String, dynamic>> normalizeRows(dynamic res) {
      if (res is! List) return const [];
      return res
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    try {
      final totalsRes = await client
          .from('v_player_season_totals')
          .select()
          .eq('player_id', profilePlayerId);
      final totalsRows = normalizeRows(totalsRes);
      if (totalsRows.isNotEmpty) {
        return _SeasonOverallStats.fromRows(totalsRows);
      }
    } catch (_) {
      // Fall back to team-level season totals if this view is unavailable.
    }

    try {
      final teamTotalsRes = await client
          .from('v_player_season_team_totals')
          .select()
          .eq('player_id', profilePlayerId);
      final teamTotalsRows = normalizeRows(teamTotalsRes);
      if (teamTotalsRows.isNotEmpty) {
        return _SeasonOverallStats.fromRows(teamTotalsRows);
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  static String _thousands(int value) {
    return value
        .toString()
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<_SeasonOverallStats?>(
      future: _loadSeasonOverall(),
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final stats = snapshot.data;
        final goalsText = stats == null ? '—' : '${stats.goals}';
        final assistsText = stats == null ? '—' : '${stats.assists}';
        final ratingText = stats == null || stats.rating <= 0
            ? '—'
            : stats.rating.toStringAsFixed(2);
        final matchesText = stats == null ? '—' : '${stats.matches}';
        final tacklesText = stats == null ? '—' : '${stats.tackles}';
        final minutesText = stats == null ? '—' : _thousands(stats.minutesPlayed);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Season overall', style: textTheme.titleSmall),
                  ),
                  if (isLoading)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          goalsText,
                          style: textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Goals',
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          assistsText,
                          style: textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Assists',
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            ratingText,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.surface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Rating',
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          matchesText,
                          style: textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Matches',
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          tacklesText,
                          style: textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tackles',
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          minutesText,
                          style: textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Minutes played',
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SeasonOverallStats {
  const _SeasonOverallStats({
    required this.goals,
    required this.assists,
    required this.rating,
    required this.matches,
    required this.tackles,
    required this.minutesPlayed,
  });

  final int goals;
  final int assists;
  final double rating;
  final int matches;
  final int tackles;
  final int minutesPlayed;

  static int _readInt(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final v = row[key];
      if (v is int) return v;
      if (v is num) return v.round();
      if (v is String) {
        final n = num.tryParse(v.trim());
        if (n != null) return n.round();
      }
    }
    return 0;
  }

  static double _readDouble(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final v = row[key];
      if (v is double) return v;
      if (v is num) return v.toDouble();
      if (v is String) {
        final n = double.tryParse(v.trim());
        if (n != null) return n;
      }
    }
    return 0;
  }

  static int _readSeasonSortKey(Map<String, dynamic> row) {
    return _readInt(row, const [
      'season',
      'season_year',
      'season_start_year',
      'year',
    ]);
  }

  static _SeasonOverallStats fromRows(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return const _SeasonOverallStats(
        goals: 0,
        assists: 0,
        rating: 0,
        matches: 0,
        tackles: 0,
        minutesPlayed: 0,
      );
    }

    final latestSeasonKey = rows
        .map(_readSeasonSortKey)
        .fold<int>(0, (best, value) => value > best ? value : best);
    final seasonRows = latestSeasonKey == 0
        ? rows
        : rows.where((r) => _readSeasonSortKey(r) == latestSeasonKey).toList();

    var goals = 0;
    var assists = 0;
    var matches = 0;
    var tackles = 0;
    var minutesPlayed = 0;
    var weightedRatingSum = 0.0;
    var weightedRatingMatches = 0;

    for (final row in seasonRows) {
      final rowGoals = _readInt(row, const ['goals', 'total_goals']);
      final rowAssists = _readInt(row, const ['assists', 'total_assists']);
      final rowMatches = _readInt(row, const ['matches', 'matches_played']);
      final rowTackles = _readInt(row, const ['tackles', 'total_tackles']);
      final rowMinutes = _readInt(row, const ['minutes_played', 'minutes']);
      final rowRating = _readDouble(row, const ['avg_rating', 'rating']);

      goals += rowGoals;
      assists += rowAssists;
      matches += rowMatches;
      tackles += rowTackles;
      minutesPlayed += rowMinutes;
      if (rowRating > 0) {
        final weight = rowMatches > 0 ? rowMatches : 1;
        weightedRatingSum += rowRating * weight;
        weightedRatingMatches += weight;
      }
    }

    final rating = weightedRatingMatches > 0
        ? (weightedRatingSum / weightedRatingMatches)
        : 0.0;

    return _SeasonOverallStats(
      goals: goals,
      assists: assists,
      rating: rating,
      matches: matches,
      tackles: tackles,
      minutesPlayed: minutesPlayed,
    );
  }
}

class _TeamSeasonPerformanceSection extends StatefulWidget {
  const _TeamSeasonPerformanceSection();

  @override
  State<_TeamSeasonPerformanceSection> createState() =>
      _TeamSeasonPerformanceSectionState();
}

class _TeamSeasonPerformanceSectionState
    extends State<_TeamSeasonPerformanceSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          // Team header - always visible
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Team logo
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.transparent,
                    backgroundImage: const AssetImage(AppAssets.leftersLogo),
                  ),
                  const SizedBox(width: 12),
                  // Team name
                  Expanded(
                    child: Text('Lefters CF', style: textTheme.bodyLarge),
                  ),
                  // Expand/collapse icon
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: colorScheme.onSurface,
                  ),
                ],
              ),
            ),
          ),
          // Expanded content - stats card
          if (_isExpanded) ...[
            Divider(height: 1, thickness: 1, color: colorScheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Season performance', style: textTheme.titleSmall),
                  const SizedBox(height: 16),
                  // Stats list - two columns (label on left, value on right)
                  _buildStatRow('Goals', '35'),
                  const SizedBox(height: 12),
                  _buildStatRow('Expected goals (XG-lite)', '35.4'),
                  const SizedBox(height: 12),
                  _buildStatRow('Shots', '175'),
                  const SizedBox(height: 12),
                  _buildStatRow('Shots on target', '80'),
                  const SizedBox(height: 12),
                  _buildStatRow('Shots off target', '95'),
                  const SizedBox(height: 12),
                  _buildStatRow('Assists', '23'),
                  const SizedBox(height: 12),
                  _buildStatRow('Expected assists (XA-lite)', '17.0'),
                  const SizedBox(height: 12),
                  _buildStatRow('Tackles', '54'),
                  const SizedBox(height: 12),
                  _buildStatRow('Yellow cards', '3'),
                  const SizedBox(height: 12),
                  _buildStatRow('Red cards', '1'),
                  const SizedBox(height: 12),
                  _buildStatRow('Matches', '34'),
                  const SizedBox(height: 12),
                  _buildStatRow('Minutes played', '2,950'),
                  const SizedBox(height: 12),
                  _buildRatingRow('Rating', '8.5'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface),
          ),
        ),
        Text(
          value,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildRatingRow(String label, String value) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            value,
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.surface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _AllTimeStatsSection extends StatelessWidget {
  const _AllTimeStatsSection();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text('All-time stats', style: textTheme.titleSmall),
          const SizedBox(height: 16),
          // Stats grid (3 rows, 3 columns)
          // First row: Goals, Assists, Rating
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '1,290',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Goals',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '540',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Assists',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '8.53',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.surface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rating',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Second row: Tackles, Yellow cards, Red cards
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '173',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tackles',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '23',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Yellow cards',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '12',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Red cards',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Third row: Saves, Matches, Minutes played
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '12',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Saves',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '120',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Matches',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '12,940',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Minutes played',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeamStatsSection extends StatefulWidget {
  const _TeamStatsSection();

  @override
  State<_TeamStatsSection> createState() => _TeamStatsSectionState();
}

class _TeamStatsSectionState extends State<_TeamStatsSection> {
  final Set<int> _expandedIndices = {};

  // Stat keys in display order
  static const List<Map<String, String>> _statCategories = [
    {'key': 'matches', 'label': 'Matches'},
    {'key': 'goals', 'label': 'Goals'},
    {'key': 'assists', 'label': 'Assists'},
    {'key': 'tackles', 'label': 'Tackles'},
    {'key': 'yellowCards', 'label': 'Yellow cards'},
    {'key': 'redCards', 'label': 'Red cards'},
    {'key': 'saves', 'label': 'Saves'},
    {'key': 'minutesPlayed', 'label': 'Minutes played'},
    {'key': 'rating', 'label': 'Rating'},
  ];

  // Sample team stats data
  final List<Map<String, dynamic>> _teamStats = const [
    {
      'logo': AppAssets.leftersLogo,
      'name': 'Lefters CF',
      'year': '2025',
      'matches': 45,
      'goals': 123,
      'assists': 32,
      'tackles': 89,
      'yellowCards': 2,
      'redCards': 1,
      'saves': 0,
      'minutesPlayed': 4050,
      'rating': 8.5,
    },
    {
      'logo': AppAssets.theShieldLogo,
      'name': 'The Shield',
      'year': '2025',
      'matches': 23,
      'goals': 72,
      'assists': 21,
      'tackles': 56,
      'yellowCards': 0,
      'redCards': 0,
      'saves': 0,
      'minutesPlayed': 2070,
      'rating': 7.8,
    },
    {
      'logo': AppAssets.galacticosLogo,
      'name': 'Galacticos',
      'year': '2024',
      'matches': 56,
      'goals': 151,
      'assists': 34,
      'tackles': 124,
      'yellowCards': 5,
      'redCards': 0,
      'saves': 12,
      'minutesPlayed': 5040,
      'rating': 8.9,
    },
  ];

  String _formatValue(dynamic value) {
    // Format rating to 1 decimal place, minutes with comma separator
    if (value is double) {
      return value.toStringAsFixed(1);
    } else if (value is int && value >= 1000) {
      return value.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text('Team stats', style: textTheme.titleSmall),
          const SizedBox(height: 12),
          ..._teamStats.asMap().entries.map((entry) {
            final index = entry.key;
            final team = entry.value;
            final isExpanded = _expandedIndices.contains(index);

            return Container(
              margin: EdgeInsets.only(
                top: index == 0 ? 0 : 12,
                bottom: index == _teamStats.length - 1 ? 0 : 0,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        if (isExpanded) {
                          _expandedIndices.remove(index);
                        } else {
                          _expandedIndices.add(index);
                        }
                      });
                    },
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.transparent,
                            backgroundImage: AssetImage(team['logo'] as String),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  team['name'] as String,
                                  style: textTheme.bodyLarge,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  team['year'] as String,
                                  style: textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: colorScheme.onSurface,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isExpanded) ...[
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: colorScheme.outlineVariant,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Season stats', style: textTheme.titleSmall),
                          const SizedBox(height: 12),
                          ..._statCategories.map((stat) {
                            final key = stat['key']!;
                            final label = stat['label']!;
                            final value = team[key];
                            final isRating = key == 'rating';

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4.0,
                              ),
                              child: _buildStatRow(
                                context,
                                label,
                                value,
                                highlight: isRating,
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatRow(
    BuildContext context,
    String label,
    dynamic value, {
    bool highlight = false,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final displayValue = _formatValue(value);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface),
          ),
        ),
        if (highlight)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              displayValue,
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.surface,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        else
          Text(
            displayValue,
            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface),
          ),
      ],
    );
  }
}

class _AttributesSection extends StatefulWidget {
  const _AttributesSection({required this.profilePlayerId});

  final String profilePlayerId;

  @override
  State<_AttributesSection> createState() => _AttributesSectionState();
}

class _AttributesSectionState extends State<_AttributesSection> {
  double _currentValue = 0; // 0 = latest year, 1 = previous year, ...
  final List<int> _years = List<int>.generate(6, (i) => DateTime.now().year - i);
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final SupabaseClient _client = Supabase.instance.client;

  Timer? _searchDebounce;
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = const [];
  Map<String, dynamic>? _selectedComparisonPlayer;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      _performPlayerSearch(query.trim());
    });
  }

  Future<void> _performPlayerSearch(String query) async {
    if (!mounted) return;
    if (query.isEmpty) {
      setState(() {
        _searchResults = const [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      final res = await _client
          .from('players')
          .select('id, player_name, image_url')
          .ilike('player_name', '%$query%')
          .limit(8);

      if (!mounted) return;
      setState(() {
        _searchResults = List<Map<String, dynamic>>.from(res as List);
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searchResults = const [];
        _isSearching = false;
      });
    }
  }

  void _selectComparisonPlayer(Map<String, dynamic> row) {
    final name = row['player_name']?.toString() ?? '';
    setState(() {
      _selectedComparisonPlayer = row;
      _searchController.text = name;
      _searchResults = const [];
    });
    _searchFocusNode.unfocus();
  }

  Widget _comparisonAvatar(BuildContext context) {
    final selected = _selectedComparisonPlayer;
    final imageUrl = selected?['image_url']?.toString() ?? '';
    if (imageUrl.isNotEmpty &&
        (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'))) {
      return CircleAvatar(radius: 20, backgroundImage: NetworkImage(imageUrl));
    }
    if (imageUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: ClipOval(
          child: Image.asset(
            imageUrl,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Icon(
              Icons.person,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: 20,
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: Icon(
        Icons.person,
        color: Theme.of(context).colorScheme.onPrimary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedYear = _years[_currentValue.round().clamp(0, _years.length - 1)];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and info icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Attributes', style: Theme.of(context).textTheme.titleSmall),
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Attributes'),
                      content: const Text(
                        'The radar chart shows 5 performance attributes (higher is better):\n\n'
                        'ATT (Attacking): goals + assists, plus xG/xA contribution (per 90).\n'
                        'SHT (Shooting): shots volume (per 90) and shots-on-target rate.\n'
                        'DEF (Defending): tackles (per 90).\n'
                        'GKP (Goalkeeping): saves (per 90) — mainly relevant for goalkeepers.\n'
                        'DIS (Discipline): fewer yellow/red cards gives a higher score.\n\n'
                        'Use the year slider to compare different years. '
                        'If there is no data for a selected year, the chart stays at 0.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Radar chart
          SizedBox(
            height: 300,
            child: PerformanceRadarChart(
              playerId: widget.profilePlayerId,
              year: selectedYear,
              comparePlayerId: _selectedComparisonPlayer?['id']?.toString(),
            ),
          ),
          const SizedBox(height: 8),
          // Timeline slider
          _TimelineSlider(
            years: _years,
            value: _currentValue,
            onChanged: (value) => setState(() => _currentValue = value),
          ),
          const SizedBox(height: 16),
          // Profile icon and search field row
          Row(
            children: [
              // Profile icon
              _comparisonAvatar(context),
              const SizedBox(width: 8),
              // Text field
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    labelText: 'Search to compare',
                    filled: true,
                    suffixIcon: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : (_searchController.text.isNotEmpty
                              ? IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchResults = const [];
                                      _selectedComparisonPlayer = null;
                                    });
                                  },
                                  icon: const Icon(Icons.close),
                                )
                              : null),
                  ),
                ),
              ),
            ],
          ),
          if (_searchResults.isNotEmpty) const SizedBox(height: 10),
          if (_searchResults.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _searchResults.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
                ),
                itemBuilder: (context, index) {
                  final row = _searchResults[index];
                  final name = row['player_name']?.toString() ?? 'Unknown';
                  final imageUrl = row['image_url']?.toString() ?? '';
                  Widget leading;
                  if (imageUrl.isNotEmpty &&
                      (imageUrl.startsWith('http://') ||
                          imageUrl.startsWith('https://'))) {
                    leading = CircleAvatar(
                      radius: 16,
                      backgroundImage: NetworkImage(imageUrl),
                    );
                  } else if (imageUrl.isNotEmpty) {
                    leading = CircleAvatar(
                      radius: 16,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: ClipOval(
                        child: Image.asset(
                          imageUrl,
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(Icons.person, size: 16),
                        ),
                      ),
                    );
                  } else {
                    leading = const CircleAvatar(
                      radius: 16,
                      child: Icon(Icons.person, size: 16),
                    );
                  }

                  return ListTile(
                    dense: true,
                    leading: leading,
                    title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => _selectComparisonPlayer(row),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _NextMatchSection extends StatelessWidget {
  const _NextMatchSection({required this.profilePlayerId});

  final String profilePlayerId;

  DateTime? _matchDateTime(MatchModel m) {
    final localDate = m.matchDate.toLocal();
    final t = m.matchTime.trim();
    if (t.isEmpty) {
      return DateTime(localDate.year, localDate.month, localDate.day);
    }
    // HH:mm or HH:mm:ss
    final parts = t.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]) ?? 0;
      final min = int.tryParse(parts[1]) ?? 0;
      return DateTime(localDate.year, localDate.month, localDate.day, h, min);
    }
    return DateTime(localDate.year, localDate.month, localDate.day);
  }

  String _dateLabel(DateTime d) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final wd = weekdays[(d.weekday - 1).clamp(0, 6)];
    final mo = months[(d.month - 1).clamp(0, 11)];
    return '$wd ${d.day} $mo';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return FutureBuilder<Map<String, dynamic>>(
      future: () async {
        final teamsRepo = TeamsRepository();
        final matchRepo = MatchesRepository();
        final teamIds = await teamsRepo.getAllActiveTeamIdsForPlayer(
          profilePlayerId,
        );
        if (teamIds.isEmpty) {
          return {'match': null};
        }

        final all = await matchRepo.getMatches(teamIds: teamIds.toList());
        final now = DateTime.now();
        final upcoming =
            all
                .where((m) => m.status == MatchStatus.upcoming)
                .map((m) => MapEntry(m, _matchDateTime(m)))
                .where((e) => e.value != null)
                .where((e) => !e.value!.isBefore(now))
                .toList()
              ..sort((a, b) => a.value!.compareTo(b.value!));
        return {'match': upcoming.isNotEmpty ? upcoming.first.key : null};
      }(),
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final err = snapshot.error;
        final match = snapshot.data?['match'] as MatchModel?;

        if (isLoading) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (err != null) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Next match', style: textTheme.titleSmall),
                const SizedBox(height: 12),
                Text(
                  'Could not load next match.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        if (match == null) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Next match', style: textTheme.titleSmall),
                const SizedBox(height: 12),
                Text(
                  'No upcoming match scheduled yet.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        ImageProvider teamLogo(TeamModel t) {
          final p = t.logoPath;
          if (p.startsWith('http://') || p.startsWith('https://')) {
            return NetworkImage(p);
          }
          return AssetImage(p);
        }

        final date = match.matchDate.toLocal();
        final league = match.leagueName?.trim().isNotEmpty == true
            ? match.leagueName!.trim()
            : '—';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Next match', style: textTheme.titleSmall),
              const SizedBox(height: 16),
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Text(
                            match.teamA.displayName,
                            style: textTheme.bodySmall,
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.transparent,
                            backgroundImage: teamLogo(match.teamA),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Text(match.timeDisplay, style: textTheme.bodyLarge),
                      const SizedBox(width: 16),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.transparent,
                            backgroundImage: teamLogo(match.teamB),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            match.teamB.displayName,
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(league, style: textTheme.labelSmall),
                      const SizedBox(width: 4),
                      Text('·', style: textTheme.labelSmall),
                      const SizedBox(width: 4),
                      Text(_dateLabel(date), style: textTheme.labelSmall),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TeamFormSection extends StatefulWidget {
  const _TeamFormSection();

  @override
  State<_TeamFormSection> createState() => _TeamFormSectionState();
}

class _TeamFormSectionState extends State<_TeamFormSection> {
  List<TeamModel> _teams = [];
  String? _selectedTeamId;
  List<MatchModel> _recentMatches = [];

  bool _isLoading = true;
  String? _error;

  ImageProvider _logoProvider(String logoPath) {
    if (logoPath.isEmpty) return const AssetImage(AppAssets.playerImage);
    if (logoPath.startsWith('http://') || logoPath.startsWith('https://')) {
      return NetworkImage(logoPath);
    }
    return AssetImage(logoPath);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          _teams = [];
          _selectedTeamId = null;
          _recentMatches = [];
          _isLoading = false;
        });
        return;
      }

      final teams = await TeamsRepository().getTeamsForUser(userId);
      teams.sort((a, b) => a.displayName.compareTo(b.displayName));

      final initialTeamId = teams.isNotEmpty ? teams.first.id : null;
      if (!mounted) return;

      setState(() {
        _teams = teams;
        _selectedTeamId = initialTeamId;
        _isLoading = false;
      });

      if (initialTeamId != null) {
        await _loadMatchesForTeam(initialTeamId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMatchesForTeam(String teamId) async {
    // Keep the UX snappy: show loading indicator only for initial load.
    final repo = MatchesRepository();
    final matches = await repo.getMatches(teamIds: [teamId]);

    final completed =
        matches
            .where(
              (m) =>
                  m.status == MatchStatus.fullTime &&
                  m.teamAScore != null &&
                  m.teamBScore != null,
            )
            .toList()
          ..sort((a, b) => b.matchDate.compareTo(a.matchDate));

    if (!mounted) return;
    setState(() {
      _recentMatches = completed.take(6).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(28),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Text(
          'Could not load team form.',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    if (_teams.isEmpty || _selectedTeamId == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Text(
          'You are not part of any team yet.',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text('Team form', style: textTheme.titleSmall),
          const SizedBox(height: 8),

          if (_teams.length > 1) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _teams.asMap().entries.map((entry) {
                  final i = entry.key;
                  final t = entry.value;
                  return Padding(
                    padding: EdgeInsets.only(
                      right: i < _teams.length - 1 ? 8 : 0,
                    ),
                    child: FilterChip(
                      backgroundColor: colorScheme.surfaceContainerHigh,
                      avatar: ClipOval(
                        child: Image(
                          image: _logoProvider(t.logoPath),
                          width: 24,
                          height: 24,
                          fit: BoxFit.cover,
                        ),
                      ),
                      label: Text(t.displayName),
                      selected: _selectedTeamId == t.id,
                      onSelected: (selected) async {
                        setState(() {
                          _selectedTeamId = t.id;
                        });
                        await _loadMatchesForTeam(t.id);
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          const SizedBox(height: 16),
          // Match results row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _recentMatches.asMap().entries.map((entry) {
                  final index = entry.key;
                  final match = entry.value;

                  final isTeamA = match.teamA.id == _selectedTeamId;
                  final myScore = isTeamA ? match.teamAScore : match.teamBScore;
                  final oppScore = isTeamA
                      ? match.teamBScore
                      : match.teamAScore;
                  final opponent = isTeamA ? match.teamB : match.teamA;

                  Color scoreColor;
                  if (myScore != null && oppScore != null) {
                    if (myScore > oppScore) {
                      scoreColor = Colors.green;
                    } else if (myScore < oppScore) {
                      scoreColor = Colors.red;
                    } else {
                      scoreColor = colorScheme.surfaceContainerHighest;
                    }
                  } else {
                    scoreColor = colorScheme.surfaceContainerHighest;
                  }

                  final isDraw =
                      myScore != null &&
                      oppScore != null &&
                      myScore == oppScore;
                  final scoreText = (myScore != null && oppScore != null)
                      ? '$myScore - $oppScore'
                      : '—';

                  final gwLabel = match.gameweekNumber != null
                      ? 'GW${match.gameweekNumber}'
                      : (match.gameweek ?? '');

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        children: [
                          // Game week
                          Text(
                            gwLabel.isNotEmpty ? gwLabel : '—',
                            style: textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          // Opponent logo
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.transparent,
                            backgroundImage: _logoProvider(opponent.logoPath),
                          ),
                          const SizedBox(height: 8),
                          // Opponent short form
                          Text(
                            opponent.shortForm,
                            style: textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Score pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: scoreColor,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              scoreText,
                              style: textTheme.labelSmall?.copyWith(
                                color: isDraw
                                    ? colorScheme.onSurface
                                    : Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (index < _recentMatches.length - 1)
                        const SizedBox(width: 24),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClubHistorySection extends StatefulWidget {
  const _ClubHistorySection({
    required this.profilePlayerId,
    required this.isOwnProfile,
  });

  final String profilePlayerId;
  final bool isOwnProfile;

  @override
  State<_ClubHistorySection> createState() => _ClubHistorySectionState();
}

class _ClubHistorySectionState extends State<_ClubHistorySection> {
  final _teamsRepo = TeamsRepository();
  List<TeamMembershipStint> _stints = [];
  Set<String> _viewerActiveTeamIds = {};
  Set<String> _viewerPendingTeamIds = {};
  bool _loading = true;
  String? _error;
  final Set<String> _busyTeamIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stints = await _teamsRepo.getMembershipHistoryForPlayer(
        widget.profilePlayerId,
      );
      final viewerId = Supabase.instance.client.auth.currentUser?.id;
      Set<String> active = {};
      Set<String> pending = {};
      if (viewerId != null && stints.isNotEmpty) {
        final ids = stints.map((s) => s.teamId).toList();
        active = await _teamsRepo.getActiveTeamIdsForPlayer(viewerId, ids);
        pending = await _teamsRepo.getPendingJoinRequestTeamIds(viewerId, ids);
      }
      if (!mounted) return;
      setState(() {
        _stints = stints;
        _viewerActiveTeamIds = active;
        _viewerPendingTeamIds = pending;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _yearsLabel(TeamMembershipStint s) {
    final start = s.createdAt?.toLocal();
    final startYear = start?.year;
    if (startYear == null) {
      return s.isCurrent ? '—' : '—';
    }
    if (s.isCurrent) return '$startYear – Now';
    final end = s.endDate?.toLocal().year;
    if (end == null) return '$startYear – —';
    return '$startYear – $end';
  }

  Widget _teamLogoAvatar(TeamMembershipStint s) {
    final m = TeamModel(
      id: s.teamId,
      logoId: s.logoId,
      shortForm: s.shortForm ?? '',
      teamName: s.teamName,
    );
    final path = m.logoPath;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: Colors.transparent,
        child: ClipOval(
          child: Image.network(
            path,
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Image.asset(
              AppAssets.leftersLogo,
              width: 36,
              height: 36,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor: Colors.transparent,
      backgroundImage: AssetImage(path),
    );
  }

  /// Leave / Join / Pending for the signed-in viewer (or profile player when [isOwnProfile]).
  _ClubRowAction _actionForRow(TeamMembershipStint stint) {
    final viewerId = Supabase.instance.client.auth.currentUser?.id;
    if (viewerId == null) {
      return _ClubRowAction.none;
    }
    if (widget.isOwnProfile) {
      if (stint.isCurrent) {
        return _ClubRowAction.leave;
      }
      if (_viewerPendingTeamIds.contains(stint.teamId)) {
        return _ClubRowAction.pending;
      }
      return _ClubRowAction.join;
    }
    if (_viewerActiveTeamIds.contains(stint.teamId)) {
      return _ClubRowAction.leave;
    }
    if (_viewerPendingTeamIds.contains(stint.teamId)) {
      return _ClubRowAction.pending;
    }
    return _ClubRowAction.join;
  }

  Future<void> _onLeavePressed(String teamId) async {
    final viewerId = Supabase.instance.client.auth.currentUser?.id;
    if (viewerId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave team?'),
        content: const Text(
          'You will be removed from the active squad. You can request to join again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busyTeamIds.add(teamId));
    try {
      await _teamsRepo.leaveTeam(playerId: viewerId, teamId: teamId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('You have left the team.')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not leave team: $e')));
    } finally {
      if (mounted) setState(() => _busyTeamIds.remove(teamId));
    }
  }

  Future<void> _onJoinPressed(String teamId) async {
    final viewerId = Supabase.instance.client.auth.currentUser?.id;
    if (viewerId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sign in to join a team.')));
      return;
    }
    setState(() => _busyTeamIds.add(teamId));
    try {
      await _teamsRepo.sendTeamJoinRequest(playerId: viewerId, teamId: teamId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your join request has been sent.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not send request: $e')));
    } finally {
      if (mounted) setState(() => _busyTeamIds.remove(teamId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_loading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(28),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Text(
          'Could not load club history.',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    if (_stints.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Club history', style: textTheme.titleSmall),
            const SizedBox(height: 12),
            Text(
              'No teams yet. Join a team from Explore or a team page.',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Club history', style: textTheme.titleSmall),
          const SizedBox(height: 16),
          ..._stints.asMap().entries.map((entry) {
            final index = entry.key;
            final stint = entry.value;
            final action = _actionForRow(stint);
            final busy = _busyTeamIds.contains(stint.teamId);

            Widget? trailing;
            switch (action) {
              case _ClubRowAction.none:
                trailing = null;
                break;
              case _ClubRowAction.leave:
                trailing = OutlinedButton(
                  onPressed: busy ? null : () => _onLeavePressed(stint.teamId),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    side: BorderSide(color: colorScheme.outline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: busy
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.primary,
                          ),
                        )
                      : Text('Leave', style: textTheme.labelMedium),
                );
                break;
              case _ClubRowAction.join:
                trailing = OutlinedButton(
                  onPressed: busy ? null : () => _onJoinPressed(stint.teamId),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    side: BorderSide(color: colorScheme.outline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: busy
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.primary,
                          ),
                        )
                      : Text('Join', style: textTheme.labelMedium),
                );
                break;
              case _ClubRowAction.pending:
                trailing = OutlinedButton(
                  onPressed: null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    side: BorderSide(color: colorScheme.outlineVariant),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    'Pending',
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
                break;
            }

            return Column(
              children: [
                Row(
                  children: [
                    _teamLogoAvatar(stint),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(stint.displayName, style: textTheme.bodySmall),
                          const SizedBox(height: 4),
                          Text(
                            _yearsLabel(stint),
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (trailing != null) trailing,
                  ],
                ),
                if (index < _stints.length - 1) ...[
                  const SizedBox(height: 8),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }
}

enum _ClubRowAction { none, leave, join, pending }

class _TrophiesSection extends StatefulWidget {
  const _TrophiesSection({required this.profilePlayerId});

  final String profilePlayerId;

  @override
  State<_TrophiesSection> createState() => _TrophiesSectionState();
}

class _TrophiesSectionState extends State<_TrophiesSection> {
  List<TeamModel> _teams = [];
  String? _selectedTeamId;
  List<_ProfileTrophyRow> _rows = [];

  bool _isLoading = true;
  String? _error;

  ImageProvider _teamChipLogo(String logoPath) {
    if (logoPath.isEmpty) return const AssetImage(AppAssets.playerImage);
    if (logoPath.startsWith('http://') || logoPath.startsWith('https://')) {
      return NetworkImage(logoPath);
    }
    return AssetImage(logoPath);
  }

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final playerId = widget.profilePlayerId;
      if (playerId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _teams = [];
          _selectedTeamId = null;
          _rows = [];
          _isLoading = false;
        });
        return;
      }
      final teams = await TeamsRepository().getTeamsForPlayer(playerId);
      teams.sort((a, b) => a.displayName.compareTo(b.displayName));
      final firstId = teams.isNotEmpty ? teams.first.id : null;
      if (!mounted) return;
      setState(() {
        _teams = teams;
        _selectedTeamId = firstId;
        _isLoading = false;
      });
      if (firstId != null) {
        await _loadTrophiesForTeam(firstId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTrophiesForTeam(String teamId) async {
    final raw = await LeaguesRepository().getChampionTrophiesForTeam(teamId);
    final byName = <String, List<Map<String, dynamic>>>{};
    for (final t in raw) {
      final name = t['league_name']?.toString() ?? 'League';
      byName.putIfAbsent(name, () => []).add(t);
    }
    final rows = <_ProfileTrophyRow>[];
    for (final entry in byName.entries) {
      final years =
          entry.value.map((m) => m['end_year'] as int).toSet().toList()
            ..sort((a, b) => b.compareTo(a));
      final logoId = entry.value.first['logo_id']?.toString();
      rows.add(
        _ProfileTrophyRow(
          leagueName: entry.key,
          logoId: logoId,
          yearsLabel: years.join(', '),
          count: years.length,
        ),
      );
    }
    rows.sort((a, b) => a.leagueName.compareTo(b.leagueName));
    if (!mounted) return;
    setState(() => _rows = rows);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(28),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Text(
          'Could not load trophies.',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    if (_teams.isEmpty || _selectedTeamId == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Text(
          'Join a team to see league trophies.',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Trophies', style: textTheme.titleSmall),
          const SizedBox(height: 8),
          if (_teams.length > 1) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _teams.asMap().entries.map((entry) {
                  final i = entry.key;
                  final t = entry.value;
                  return Padding(
                    padding: EdgeInsets.only(
                      right: i < _teams.length - 1 ? 8 : 0,
                    ),
                    child: FilterChip(
                      backgroundColor: colorScheme.surfaceContainerHigh,
                      avatar: ClipOval(
                        child: Image(
                          image: _teamChipLogo(t.logoPath),
                          width: 24,
                          height: 24,
                          fit: BoxFit.cover,
                        ),
                      ),
                      label: Text(t.displayName),
                      selected: _selectedTeamId == t.id,
                      onSelected: (_) async {
                        setState(() => _selectedTeamId = t.id);
                        await _loadTrophiesForTeam(t.id);
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_rows.isEmpty)
            Text(
              'No titles yet — win a league that has finished.',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else
            ..._rows.asMap().entries.map((entry) {
              final index = entry.key;
              final trophy = entry.value;
              return Column(
                children: [
                  Row(
                    children: [
                      _ProfileTrophyLeagueThumb(logoId: trophy.logoId),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(trophy.leagueName, style: textTheme.bodySmall),
                            const SizedBox(height: 4),
                            Text(
                              trophy.yearsLabel,
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        trophy.count.toString(),
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (index < _rows.length - 1) ...[
                    const SizedBox(height: 8),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: colorScheme.outlineVariant,
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              );
            }),
        ],
      ),
    );
  }
}

class _ProfileTrophyRow {
  const _ProfileTrophyRow({
    required this.leagueName,
    required this.logoId,
    required this.yearsLabel,
    required this.count,
  });

  final String leagueName;
  final String? logoId;
  final String yearsLabel;
  final int count;
}

class _ProfileTrophyLeagueThumb extends StatelessWidget {
  const _ProfileTrophyLeagueThumb({this.logoId});

  final String? logoId;

  static String? _resolvedPath(String? raw) {
    final id = raw?.trim();
    if (id == null || id.isEmpty) return null;
    if (id.startsWith('http://') || id.startsWith('https://')) return id;
    if (id.startsWith('lib/assets/') || id.startsWith('assets/')) return id;
    final name = id.contains('.') ? id : '$id.png';
    return '${AppAssets.teamLogosPath}$name';
  }

  @override
  Widget build(BuildContext context) {
    final path = _resolvedPath(logoId);
    final colorScheme = Theme.of(context).colorScheme;
    if (path == null) {
      return SizedBox(
        width: 36,
        height: 36,
        child: Icon(Icons.emoji_events, size: 24, color: colorScheme.primary),
      );
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          path,
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => SizedBox(
            width: 36,
            height: 36,
            child: Icon(
              Icons.emoji_events,
              size: 24,
              color: colorScheme.primary,
            ),
          ),
        ),
      );
    }
    return Image.asset(
      path,
      width: 36,
      height: 36,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => SizedBox(
        width: 36,
        height: 36,
        child: Icon(Icons.emoji_events, size: 24, color: colorScheme.primary),
      ),
    );
  }
}

class _BadgesSection extends StatelessWidget {
  const _BadgesSection();

  // Sample badges data
  final List<Map<String, dynamic>> _badges = const [
    {
      'svgPath': AppAssets.proBadge,
      'points': '+10',
      'name': 'Iron-foot',
      'objective': 'Score 100 goals',
      'progress': 0.5, // 50%
    },
    {
      'svgPath': AppAssets.masterBadge,
      'points': '+10',
      'name': 'Lock-down defender 💪',
      'objective': 'Make 100 tackles',
      'progress': 1.0, // 100%
    },
    {
      'svgPath': AppAssets.legendaryBadge,
      'points': '+100',
      'name': 'Footy Master',
      'objective': 'Reach 10K goals',
      'progress': 0.8, // 80%
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and info icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Badges', style: Theme.of(context).textTheme.titleSmall),
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Badges'),
                      content: const Text(
                        'Earn badges by reaching performance milestones.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Badges list
          ..._badges.asMap().entries.map((entry) {
            final index = entry.key;
            final badge = entry.value;
            final progress = badge['progress'] as double;
            final percentage = (progress * 100).round();

            return Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge icon (SVG from assets)
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: SvgPicture.asset(
                        badge['svgPath'] as String,
                        width: 36,
                        height: 36,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.emoji_events,
                            size: 24,
                            color: Theme.of(context).colorScheme.primary,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Points indicator
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        badge['points'] as String,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Badge name, objective, and progress
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Badge name
                          Text(
                            badge['name'] as String,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          // Objective
                          Text(
                            badge['objective'] as String,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 8),
                          // Progress bar
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 2,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      year2023: false,
                                      value: progress,
                                      minHeight: 2,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Percentage
                              Text(
                                '$percentage%',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Divider between items (except after the last one)
                if (index < _badges.length - 1) ...[
                  const SizedBox(height: 16),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _TimelineSlider extends StatelessWidget {
  const _TimelineSlider({
    required this.years,
    required this.value,
    required this.onChanged,
  });

  final List<int> years;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final maxIndex = (years.length - 1).clamp(0, 1000).toDouble();
    final safeIndex = value.round().clamp(0, years.length - 1);
    return Slider(
      year2023: false,
      value: value.clamp(0.0, maxIndex),
      min: 0,
      max: maxIndex,
      divisions: years.length > 1 ? years.length - 1 : 1,
      label: years[safeIndex].toString(),
      onChanged: onChanged,
    );
  }
}

/// Displays profile image - supports network URL or asset path.
class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Image.asset(
        AppAssets.playerImage,
        width: 248,
        height: 318,
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }
    final url = imageUrl!;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        width: 248,
        height: 318,
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
        errorBuilder: (_, __, ___) => Image.asset(
          AppAssets.playerImage,
          width: 248,
          height: 318,
          fit: BoxFit.contain,
          alignment: Alignment.bottomCenter,
        ),
      );
    }
    // Asset path (e.g. preset avatar from onboarding)
    return Image.asset(
      url,
      width: 248,
      height: 318,
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      errorBuilder: (_, __, ___) => Image.asset(
        AppAssets.playerImage,
        width: 248,
        height: 318,
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
      ),
    );
  }
}

class _ProfileCard extends StatefulWidget {
  const _ProfileCard({required this.playerId, required this.showEditButton});

  final String playerId;
  final bool showEditButton;

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  late Future<UserProfile?> _profileFuture;

  Future<UserProfile?> _fetchProfile() async {
    final repo = UserProfileRepository();
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (widget.showEditButton && uid == widget.playerId) {
      return repo.getCurrentProfile();
    }
    return repo.getProfileByPlayerId(widget.playerId);
  }

  @override
  void initState() {
    super.initState();
    _profileFuture = _fetchProfile();
  }

  @override
  void didUpdateWidget(covariant _ProfileCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playerId != widget.playerId ||
        oldWidget.showEditButton != widget.showEditButton) {
      _profileFuture = _fetchProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final playerName = profile?.playerName ?? 'Player';
        final username =
            profile?.username != null && profile!.username!.isNotEmpty
            ? '@${profile.username}'
            : '@—';

        return SizedBox(
          height: 356,
          child: Stack(
            children: [
              // Background container with primaryContainer color
              Container(
                width: double.infinity,
                height: 356,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              // Background overlay image with multiply blend mode
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Color(0xff81d99a),
                    BlendMode.multiply,
                  ),
                  child: Image.asset(
                    AppAssets.bgOverlay,
                    width: double.infinity,
                    height: 356,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
              // Player image aligned to baseline (bottom) of container
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: _ProfileAvatar(imageUrl: profile?.imageUrl),
                ),
              ),
              // Gradient overlay fading from bottom to top
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Container(
                  width: double.infinity,
                  height: 356,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Text overlay at the bottom
              Positioned(
                bottom: 80,
                left: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playerName,
                      style: Theme.of(context).textTheme.displayMedium
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      username,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              // Action chips at the bottom (horizontally scrollable)
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      _ActionChip(
                        svgPath: AppAssets.positionIcon,
                        label: profile?.position?.isNotEmpty == true
                            ? profile!.position!
                            : '—',
                        context: context,
                      ),
                      const SizedBox(width: 8),
                      _ActionChip(
                        icon: Icons.groups_outlined,
                        label: '12K',
                        context: context,
                      ),
                      const SizedBox(width: 8),
                      _ActionChip(
                        icon: Icons.bar_chart_outlined,
                        label: '3',
                        context: context,
                      ),
                      const SizedBox(width: 8),
                      _ActionChip(
                        icon: Icons.public_outlined,
                        label:
                            profile?.country != null &&
                                profile!.country!.isNotEmpty
                            ? countryCodeToName(profile.country!)
                            : '—',
                        context: context,
                      ),
                    ],
                  ),
                ),
              ),
              // Edit button on top so it receives taps (must be last in Stack)
              if (widget.showEditButton)
                Positioned(
                  top: 16,
                  right: 16,
                  child: FilledButton.tonal(
                    onPressed: profile == null
                        ? null
                        : () async {
                            final saved = await Navigator.of(context)
                                .push<bool>(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        EditProfilePage(profile: profile),
                                  ),
                                );
                            if (saved == true && mounted) {
                              setState(() {
                                _profileFuture = _fetchProfile();
                              });
                            }
                          },
                    style: FilledButton.styleFrom(
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                      ),
                      padding: const EdgeInsets.only(
                        left: 17,
                        right: 17,
                        top: 12,
                        bottom: 12,
                      ),
                      minimumSize: const Size(60, 40),
                    ),
                    child: const Icon(Icons.edit_outlined, size: 20),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Profile videos tab – real user videos with sort + grid/feed toggle
// ---------------------------------------------------------------------------

enum _ProfileVideoSort { newest, oldest, mostLiked, mostViewed }

class _ProfileVideosTab extends StatefulWidget {
  const _ProfileVideosTab({required this.profilePlayerId});

  final String profilePlayerId;

  @override
  State<_ProfileVideosTab> createState() => _ProfileVideosTabState();
}

class _ProfileVideosTabState extends State<_ProfileVideosTab> {
  List<LeagueVideoItem>? _videos;
  bool _isLoading = true;
  String? _error;
  _ProfileVideoSort _sortOrder = _ProfileVideoSort.newest;
  bool _isFeedLayout = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final client = Supabase.instance.client;
      final uploadUserId = widget.profilePlayerId;
      if (uploadUserId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _videos = [];
          _isLoading = false;
        });
        return;
      }
      final rawVideos = await client
          .from('videos')
          .select(
            'id, match_id, uploader_user_id, duration_seconds, '
            'video_url, thumbnail_url, created_at',
          )
          .eq('uploader_user_id', uploadUserId)
          .order('created_at', ascending: false);
      final list = List<Map<String, dynamic>>.from(rawVideos as List);
      if (!mounted) return;
      final enriched = await _enrichVideos(list);
      if (!mounted) return;
      setState(() {
        _videos = enriched;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<List<LeagueVideoItem>> _enrichVideos(
    List<Map<String, dynamic>> rawVideos,
  ) async {
    if (rawVideos.isEmpty) return [];
    final client = Supabase.instance.client;
    final currentUserId = client.auth.currentUser?.id;

    final matchIds = <String>{};
    final uploaderIds = <String>{};
    final videoIds = <String>[];
    for (final v in rawVideos) {
      final mid = v['match_id']?.toString();
      if (mid != null && mid.isNotEmpty) matchIds.add(mid);
      final uid = v['uploader_user_id']?.toString();
      if (uid != null && uid.isNotEmpty) uploaderIds.add(uid);
      final vid = v['id']?.toString();
      if (vid != null && vid.isNotEmpty) videoIds.add(vid);
    }

    final matchesMap = <String, Map<String, dynamic>>{};
    if (matchIds.isNotEmpty) {
      final matchesRes = await client
          .from('matches')
          .select(
            'id, status, "teamA_score", "teamB_score", '
            'teamA:teams!teamA(id, logo_id, short_form), '
            'teamB:teams!teamB(id, logo_id, short_form)',
          )
          .inFilter('id', matchIds.toList());
      for (final m in List<Map<String, dynamic>>.from(matchesRes as List)) {
        final id = m['id']?.toString();
        if (id != null) matchesMap[id] = m;
      }
    }

    final uploadersMap = <String, Map<String, dynamic>>{};
    if (uploaderIds.isNotEmpty) {
      final uploadersRes = await client
          .from('players')
          .select('id, player_name, image_url')
          .inFilter('id', uploaderIds.toList());
      for (final p in List<Map<String, dynamic>>.from(uploadersRes as List)) {
        final id = p['id']?.toString();
        if (id != null) uploadersMap[id] = p;
      }
    }

    final followsSet = <String>{};
    if (currentUserId != null && uploaderIds.isNotEmpty) {
      try {
        final followsRes = await client
            .from('user_follows')
            .select('following_user_id')
            .eq('follower_user_id', currentUserId)
            .inFilter('following_user_id', uploaderIds.toList());
        for (final f in List<Map<String, dynamic>>.from(followsRes as List)) {
          final fid = f['following_user_id']?.toString();
          if (fid != null) followsSet.add(fid);
        }
      } catch (_) {}
    }

    final likedVideoIds = <String>{};
    final likeCountMap = <String, int>{};
    if (videoIds.isNotEmpty) {
      try {
        final likesRes = await client
            .from('video_likes')
            .select('video_id, user_id')
            .inFilter('video_id', videoIds);
        for (final l in List<Map<String, dynamic>>.from(likesRes as List)) {
          final vid = l['video_id']?.toString();
          final uid = l['user_id']?.toString();
          if (vid != null) {
            likeCountMap[vid] = (likeCountMap[vid] ?? 0) + 1;
            if (uid == currentUserId) likedVideoIds.add(vid);
          }
        }
      } catch (_) {}
    }

    final viewCountMap = <String, int>{};
    if (videoIds.isNotEmpty) {
      try {
        final viewRes = await client
            .from('feed_interactions')
            .select('video_id')
            .inFilter('video_id', videoIds);
        for (final row in List<Map<String, dynamic>>.from(viewRes as List)) {
          final vid = row['video_id']?.toString();
          if (vid != null) viewCountMap[vid] = (viewCountMap[vid] ?? 0) + 1;
        }
      } catch (_) {}
    }

    return rawVideos.map((v) {
      final match =
          matchesMap[v['match_id']?.toString()] ?? <String, dynamic>{};
      final teamA = match['teamA'] as Map<String, dynamic>? ?? {};
      final teamB = match['teamB'] as Map<String, dynamic>? ?? {};
      final uploader =
          uploadersMap[v['uploader_user_id']?.toString()] ??
          <String, dynamic>{};
      final vid = v['id']?.toString() ?? '';
      final uploaderUserId = v['uploader_user_id']?.toString();

      final teamAScore = match['teamA_score'] is int
          ? match['teamA_score'] as int
          : int.tryParse(match['teamA_score']?.toString() ?? '0') ?? 0;
      final teamBScore = match['teamB_score'] is int
          ? match['teamB_score'] as int
          : int.tryParse(match['teamB_score']?.toString() ?? '0') ?? 0;

      DateTime? createdAt;
      final raw = v['created_at'];
      if (raw is String) createdAt = DateTime.tryParse(raw);

      return LeagueVideoItem(
        videoId: vid,
        videoUrl: v['video_url']?.toString() ?? '',
        thumbnailUrl: v['thumbnail_url']?.toString(),
        durationSeconds: v['duration_seconds'] as int?,
        createdAt: createdAt,
        teamAShort: teamA['short_form']?.toString() ?? 'Team A',
        teamBShort: teamB['short_form']?.toString() ?? 'Team B',
        teamALogo: _resolveVideoLogo(teamA['logo_id']?.toString()),
        teamBLogo: _resolveVideoLogo(teamB['logo_id']?.toString()),
        teamAScore: teamAScore,
        teamBScore: teamBScore,
        matchStatus: match['status']?.toString() ?? '',
        uploaderName: uploader['player_name']?.toString(),
        uploaderAvatar: uploader['image_url']?.toString(),
        uploaderUserId: uploaderUserId,
        isLiked: likedVideoIds.contains(vid),
        likeCount: likeCountMap[vid] ?? 0,
        isFollowing:
            uploaderUserId != null && followsSet.contains(uploaderUserId),
        viewCount: viewCountMap[vid] ?? 0,
      );
    }).toList();
  }

  static String _resolveVideoLogo(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('lib/assets/') || raw.startsWith('assets/')) return raw;
    final name = raw.contains('.') ? raw : '$raw.png';
    return '${AppAssets.teamLogosPath}$name';
  }

  List<LeagueVideoItem> get _sortedVideos {
    if (_videos == null) return [];
    final list = List<LeagueVideoItem>.from(_videos!);
    switch (_sortOrder) {
      case _ProfileVideoSort.newest:
        list.sort(
          (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
            a.createdAt ?? DateTime(0),
          ),
        );
      case _ProfileVideoSort.oldest:
        list.sort(
          (a, b) => (a.createdAt ?? DateTime(0)).compareTo(
            b.createdAt ?? DateTime(0),
          ),
        );
      case _ProfileVideoSort.mostLiked:
        list.sort((a, b) => b.likeCount.compareTo(a.likeCount));
      case _ProfileVideoSort.mostViewed:
        list.sort((a, b) => b.viewCount.compareTo(a.viewCount));
    }
    return list;
  }

  String get _sortLabel {
    switch (_sortOrder) {
      case _ProfileVideoSort.newest:
        return 'Newest';
      case _ProfileVideoSort.oldest:
        return 'Oldest';
      case _ProfileVideoSort.mostLiked:
        return 'Most liked';
      case _ProfileVideoSort.mostViewed:
        return 'Most viewed';
    }
  }

  void _openVideoPlayer(int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            LeagueVideoPlayerPage(videos: _sortedVideos, initialIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Could not load videos', style: textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final sorted = _sortedVideos;

    return RefreshIndicator(
      onRefresh: _load,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                PopupMenuButton<_ProfileVideoSort>(
                  onSelected: (v) => setState(() => _sortOrder = v),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: _ProfileVideoSort.newest,
                      child: Text('Newest'),
                    ),
                    PopupMenuItem(
                      value: _ProfileVideoSort.oldest,
                      child: Text('Oldest'),
                    ),
                    PopupMenuItem(
                      value: _ProfileVideoSort.mostLiked,
                      child: Text('Most liked'),
                    ),
                    PopupMenuItem(
                      value: _ProfileVideoSort.mostViewed,
                      child: Text('Most viewed'),
                    ),
                  ],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.swap_vert,
                        size: 20,
                        color: colorScheme.onSurface,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _sortLabel,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    _isFeedLayout ? Icons.grid_view : Icons.view_list,
                    size: 20,
                    color: colorScheme.onSurface,
                  ),
                  onPressed: () =>
                      setState(() => _isFeedLayout = !_isFeedLayout),
                ),
              ],
            ),
          ),
          if (sorted.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'No videos yet — upload from a match!',
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else if (_isFeedLayout)
            Expanded(child: _buildFeedView(sorted))
          else
            Expanded(child: _buildGridView(sorted)),
        ],
      ),
    );
  }

  Widget _buildGridView(List<LeagueVideoItem> videos) {
    final colorScheme = Theme.of(context).colorScheme;
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 121.33 / 204,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final v = videos[index];
        return GestureDetector(
          onTap: () => _openVideoPlayer(index),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(28),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildThumbnail(v),
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 12,
                          ),
                          if (v.durationSeconds != null) ...[
                            const SizedBox(width: 2),
                            Text(
                              _formatDuration(v.durationSeconds!),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeedView(List<LeagueVideoItem> videos) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final v = videos[index];
        return GestureDetector(
          onTap: () => _openVideoPlayer(index),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      _ProfileFeedLogo(logoPath: v.teamALogo, size: 24),
                      const SizedBox(width: 6),
                      Text(
                        v.teamAShort,
                        style: textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${v.teamAScore} - ${v.teamBScore}',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        v.teamBShort,
                        style: textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _ProfileFeedLogo(logoPath: v.teamBLogo, size: 24),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          v.matchStatus,
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildThumbnail(v),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Colors.black38,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.favorite,
                        size: 16,
                        color: v.isLiked
                            ? Colors.red
                            : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text('${v.likeCount}', style: textTheme.bodySmall),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.visibility,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text('${v.viewCount}', style: textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThumbnail(LeagueVideoItem v) {
    final url = v.thumbnailUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.asset(
          AppAssets.highlightPlaceholder,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Icon(
              Icons.play_circle_outline,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return Image.asset(
      AppAssets.highlightPlaceholder,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.play_circle_outline,
          size: 48,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _ProfileFeedLogo extends StatelessWidget {
  const _ProfileFeedLogo({required this.logoPath, this.size = 24});
  final String logoPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (logoPath.isEmpty) {
      return Icon(
        Icons.groups,
        size: size,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );
    }
    final isNetwork =
        logoPath.startsWith('http://') || logoPath.startsWith('https://');
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: isNetwork
            ? Image.network(
                logoPath,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.groups,
                  size: size * 0.7,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            : Image.asset(
                logoPath,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.groups,
                  size: size * 0.7,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData? icon;
  final String? svgPath;
  final String label;
  final BuildContext context;

  const _ActionChip({
    this.icon,
    this.svgPath,
    required this.label,
    required this.context,
  }) : assert(
         icon != null || svgPath != null,
         'Either icon or svgPath must be provided',
       );

  @override
  Widget build(BuildContext context) {
    Widget avatar;
    if (svgPath != null) {
      avatar = SvgPicture.asset(
        svgPath!,
        width: 18,
        height: 18,
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      );
    } else {
      avatar = Icon(icon, size: 18, color: Colors.white);
    }

    return ActionChip.elevated(
      avatar: avatar,
      label: Text(label, style: const TextStyle(color: Colors.white)),
      onPressed: () {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$label selected')));
      },
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999), // Fully rounded
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}
