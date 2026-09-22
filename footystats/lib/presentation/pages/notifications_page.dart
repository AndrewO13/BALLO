import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_assets.dart';
import '../../core/widgets/app_empty_state.dart';
import 'explore.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final SupabaseClient _client = Supabase.instance.client;
  final Set<String> _processingIds = {};
  final Map<String, String> _teamNameById = {};
  final Map<String, String> _inviterNameById = {};

  Future<void> _hydrateMetadata(List<Map<String, dynamic>> invites) async {
    final missingTeamIds = <String>{};
    final missingInviterIds = <String>{};

    for (final invite in invites) {
      final teamId = invite['team_id']?.toString() ?? '';
      final inviterId = invite['invited_by']?.toString() ?? '';
      if (teamId.isNotEmpty && !_teamNameById.containsKey(teamId)) {
        missingTeamIds.add(teamId);
      }
      if (inviterId.isNotEmpty && !_inviterNameById.containsKey(inviterId)) {
        missingInviterIds.add(inviterId);
      }
    }

    if (missingTeamIds.isEmpty && missingInviterIds.isEmpty) return;

    if (missingTeamIds.isNotEmpty) {
      try {
        final rows = await _client
            .from('teams')
            .select('id, team_name, short_form')
            .inFilter('id', missingTeamIds.toList());
        for (final row in (rows as List).whereType<Map>()) {
          final item = Map<String, dynamic>.from(row);
          final id = item['id']?.toString() ?? '';
          if (id.isEmpty) continue;
          final teamName = (item['team_name']?.toString().trim().isNotEmpty ??
                  false)
              ? item['team_name'].toString().trim()
              : (item['short_form']?.toString().trim().isNotEmpty ?? false)
              ? item['short_form'].toString().trim()
              : 'Team';
          _teamNameById[id] = teamName;
        }
      } catch (_) {}
    }

    if (missingInviterIds.isNotEmpty) {
      try {
        final rows = await _client
            .from('players')
            .select('id, player_name, username')
            .inFilter('id', missingInviterIds.toList());
        for (final row in (rows as List).whereType<Map>()) {
          final item = Map<String, dynamic>.from(row);
          final id = item['id']?.toString() ?? '';
          if (id.isEmpty) continue;
          final inviterName = (item['player_name']?.toString().trim().isNotEmpty ??
                  false)
              ? item['player_name'].toString().trim()
              : (item['username']?.toString().trim().isNotEmpty ?? false)
              ? '@${item['username'].toString().trim()}'
              : 'Team admin';
          _inviterNameById[id] = inviterName;
        }
      } catch (_) {}
    }

    if (mounted) setState(() {});
  }

  Future<void> _acceptInvite(String inviteId) async {
    if (_processingIds.contains(inviteId)) return;
    setState(() => _processingIds.add(inviteId));
    try {
      await _client.rpc(
        'accept_team_player_invite',
        params: {'p_invite_id': inviteId},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invite accepted')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not accept invite: $error')));
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(inviteId));
      }
    }
  }

  Future<void> _rejectInvite(String inviteId) async {
    if (_processingIds.contains(inviteId)) return;
    setState(() => _processingIds.add(inviteId));
    try {
      await _client.rpc(
        'reject_team_player_invite',
        params: {'p_invite_id': inviteId},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invite rejected')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not reject invite: $error')));
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(inviteId));
      }
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final updated = await _client.rpc('mark_all_team_invites_read');
      if (!mounted) return;
      final count = int.tryParse(updated?.toString() ?? '0') ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count > 0 ? 'Marked $count invite(s) as read' : 'No unread invites',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not mark invites as read: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Notifications', style: textTheme.headlineMedium)),
        body: Center(
          child: Text(
            'Sign in to view notifications',
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final stream = _client
        .from('team_player_invites')
        .stream(primaryKey: ['id'])
        .map(
          (rows) => rows.where((row) {
            final playerId = row['player_id']?.toString() ?? '';
            return playerId == currentUser.id;
          }).toList()
            ..sort((a, b) {
              final aDate = DateTime.tryParse(
                a['created_at']?.toString() ?? '',
              );
              final bDate = DateTime.tryParse(
                b['created_at']?.toString() ?? '',
              );
              if (aDate == null && bDate == null) return 0;
              if (aDate == null) return 1;
              if (bDate == null) return -1;
              return bDate.compareTo(aDate);
            }),
        );

    return DefaultTabController(
      length: 2,
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return Scaffold(
              appBar: AppBar(
                title: Text('Notifications', style: textTheme.headlineMedium),
              ),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          final allInvites = snapshot.data ?? const <Map<String, dynamic>>[];
          unawaited(_hydrateMetadata(allInvites));
          final pending = allInvites
              .where((invite) => (invite['status']?.toString() ?? '') == 'pending')
              .toList();
          final unreadPending = pending
              .where((invite) => invite['read_at'] == null)
              .toList();
          final history = allInvites.where((invite) {
            final status = invite['status']?.toString() ?? '';
            return status == 'accepted' || status == 'rejected';
          }).toList();

          return Scaffold(
            appBar: AppBar(
              title: Text('Notifications', style: textTheme.headlineMedium),
              centerTitle: false,
              actions: [
                if (unreadPending.isNotEmpty)
                  TextButton(
                    onPressed: _markAllAsRead,
                    child: const Text('Mark all as read'),
                  ),
              ],
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Invites'),
                  Tab(text: 'History'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _buildPendingTab(
                  invites: pending,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                ),
                _buildHistoryTab(
                  invites: history,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPendingTab({
    required List<Map<String, dynamic>> invites,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    if (invites.isEmpty) {
      return Center(
        child: AppEmptyState(
          imageAsset: AppAssets.noInvitesEmpty,
          title: 'No invites yet',
          subtitle:
              'When a team invites you to join their squad, it will show up here.',
          actionLabel: 'Explore teams',
          onAction: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ExplorePage()),
            );
          },
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: invites.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final invite = invites[index];
        final inviteId = invite['id']?.toString() ?? '';
        final teamId = invite['team_id']?.toString() ?? '';
        final invitedBy = invite['invited_by']?.toString() ?? '';
        final teamName = _teamNameById[teamId] ?? 'Team';
        final inviterName = _inviterNameById[invitedBy] ?? 'Team admin';
        final isProcessing = _processingIds.contains(inviteId);
        final isUnread = invite['read_at'] == null;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(24),
            border: isUnread
                ? Border.all(color: colorScheme.primary.withValues(alpha: 0.45))
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.group_add,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$teamName invited you to join', style: textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Invited by $inviterName',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        FilledButton.tonal(
                          onPressed: (inviteId.isEmpty || isProcessing)
                              ? null
                              : () => _rejectInvite(inviteId),
                          child: const Text('Reject'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: (inviteId.isEmpty || isProcessing)
                              ? null
                              : () => _acceptInvite(inviteId),
                          child: Text(isProcessing ? 'Please wait...' : 'Accept'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab({
    required List<Map<String, dynamic>> invites,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    if (invites.isEmpty) {
      return Center(
        child: AppEmptyState(
          imageAsset: AppAssets.noHistoryEmpty,
          title: 'No invite history',
          subtitle:
              'Invites you accept or decline will appear here so you can look back anytime.',
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: invites.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final invite = invites[index];
        final teamId = invite['team_id']?.toString() ?? '';
        final teamName = _teamNameById[teamId] ?? 'Team';
        final status = invite['status']?.toString() ?? '';
        final isAccepted = status == 'accepted';
        final respondedAt =
            DateTime.tryParse(invite['responded_at']?.toString() ?? '');

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Icon(
                isAccepted ? Icons.check_circle : Icons.cancel,
                color: isAccepted ? colorScheme.tertiary : colorScheme.error,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAccepted
                          ? 'You accepted $teamName invite'
                          : 'You rejected $teamName invite',
                      style: textTheme.titleMedium,
                    ),
                    if (respondedAt != null)
                      Text(
                        'Responded ${_friendlyDate(respondedAt)}',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _friendlyDate(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}
