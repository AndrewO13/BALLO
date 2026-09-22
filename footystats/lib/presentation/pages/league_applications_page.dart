import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_assets.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/media_placeholders.dart';
import '../providers/league_applications_provider.dart';
import '../providers/league_teams_provider.dart';

class LeagueApplicationsPage extends ConsumerStatefulWidget {
  const LeagueApplicationsPage({super.key, required this.leagueId});

  final String leagueId;

  @override
  ConsumerState<LeagueApplicationsPage> createState() =>
      _LeagueApplicationsPageState();
}

class _LeagueApplicationsPageState extends ConsumerState<LeagueApplicationsPage> {
  String _searchQuery = '';
  final Set<String> _processingIds = {};

  Future<void> _approve({
    required String applicationId,
    required String teamId,
  }) async {
    if (_processingIds.contains(applicationId)) return;
    setState(() => _processingIds.add(applicationId));
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _processingIds.remove(applicationId));
      return;
    }
    try {
      final appsRepo = ref.read(leagueApplicationsRepositoryProvider);
      final teamsRepo = ref.read(leagueTeamsRepositoryProvider);
      await appsRepo.reviewApplication(
        applicationId: applicationId,
        status: 'accepted',
        reviewedBy: userId,
      );
      await teamsRepo.addTeamToLeague(
        leagueId: widget.leagueId,
        teamId: teamId,
        addedBy: userId,
      );
      if (!mounted) return;
      ref.invalidate(leaguePendingApplicationsWithTeamsProvider(widget.leagueId));
      ref.invalidate(teamsInLeagueProvider(widget.leagueId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Application accepted')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error approving: $error')),
      );
    } finally {
      if (mounted) setState(() => _processingIds.remove(applicationId));
    }
  }

  Future<void> _reject(String applicationId) async {
    if (_processingIds.contains(applicationId)) return;
    setState(() => _processingIds.add(applicationId));
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _processingIds.remove(applicationId));
      return;
    }
    try {
      final appsRepo = ref.read(leagueApplicationsRepositoryProvider);
      await appsRepo.reviewApplication(
        applicationId: applicationId,
        status: 'rejected',
        reviewedBy: userId,
      );
      if (!mounted) return;
      ref.invalidate(leaguePendingApplicationsWithTeamsProvider(widget.leagueId));
      ref.invalidate(
        leagueRejectedApplicationsWithTeamsProvider(widget.leagueId),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Application rejected')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error rejecting: $error')),
      );
    } finally {
      if (mounted) setState(() => _processingIds.remove(applicationId));
    }
  }

  List<Map<String, dynamic>> _filter(
    List<Map<String, dynamic>> apps,
  ) {
    if (_searchQuery.trim().isEmpty) return apps;
    final q = _searchQuery.trim().toLowerCase();
    return apps.where((a) {
      final team = a['team'] as Map<String, dynamic>?;
      if (team == null) return false;
      final name = (team['team_name'] as String? ?? '').toLowerCase();
      final short = (team['short_form'] as String? ?? '').toLowerCase();
      return name.contains(q) || short.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final asyncApps =
        ref.watch(leaguePendingApplicationsWithTeamsProvider(widget.leagueId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Manage applications', style: textTheme.headlineMedium),
        centerTitle: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by team name',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          Expanded(
            child: asyncApps.when(
              data: (apps) {
                final filtered = _filter(apps);
                if (filtered.isEmpty) {
                  return ScrollableAppEmptyState(
                    imageAsset: AppAssets.approvedApplicationsEmpty,
                    title: apps.isEmpty
                        ? 'No pending applications'
                        : 'No matching applications',
                    subtitle: apps.isEmpty
                        ? 'When teams apply to join your league, you can review and approve them here.'
                        : 'Try a different team name in your search.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final app = filtered[index];
                    final applicationId = app['id']?.toString() ?? '';
                    final teamId = app['team_id']?.toString() ?? '';
                    final team = app['team'] as Map<String, dynamic>?;
                    final teamName = team?['team_name'] as String? ??
                        team?['short_form'] as String? ??
                        'Unknown';
                    final shortForm = team?['short_form'] as String? ?? '';
                    final logoId = team?['logo_id'] as String?;
                    final isProcessing = _processingIds.contains(applicationId);

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Row(
                        children: [
                          _TeamLogo(logoId: logoId),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  teamName,
                                  style: textTheme.titleMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (shortForm.isNotEmpty &&
                                    shortForm != teamName) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    shortForm,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.check_circle,
                              color: colorScheme.tertiary,
                            ),
                            tooltip: 'Accept',
                            onPressed: applicationId.isEmpty || isProcessing
                                ? null
                                : () => _approve(
                                      applicationId: applicationId,
                                      teamId: teamId,
                                    ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.cancel,
                              color: colorScheme.error,
                            ),
                            tooltip: 'Reject',
                            onPressed: applicationId.isEmpty || isProcessing
                                ? null
                                : () => _reject(applicationId),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamLogo extends StatelessWidget {
  const _TeamLogo({this.logoId});

  final String? logoId;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ClipOval(
      child: SizedBox(
        width: 48,
        height: 48,
        child: buildTeamLogo(
          resolveTeamLogoPath(logoId),
          size: 48,
          placeholderIconColor: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
