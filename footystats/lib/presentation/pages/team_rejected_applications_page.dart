import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_assets.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/media_placeholders.dart';

class TeamRejectedApplicationsPage extends StatefulWidget {
  const TeamRejectedApplicationsPage({super.key, required this.teamId});

  final String teamId;

  @override
  State<TeamRejectedApplicationsPage> createState() =>
      _TeamRejectedApplicationsPageState();
}

class _TeamRejectedApplicationsPageState
    extends State<TeamRejectedApplicationsPage> {
  List<Map<String, dynamic>> _applications = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final Set<String> _processingInvitePlayerIds = {};
  final Set<String> _pendingInvitePlayerIds = {};

  @override
  void initState() {
    super.initState();
    _loadApplications();
    _loadPendingInvites();
  }

  Future<void> _loadApplications() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('team_join_requests')
          .select(
            '*, players!team_join_requests_player_id_fkey(player_name, username, image_url)',
          )
          .eq('team_id', widget.teamId)
          .eq('status', 'rejected')
          .order('created_at', ascending: false);

      final rows = List<Map<String, dynamic>>.from(response);
      final playerIds = rows
          .map((row) => row['player_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      Set<String> activeMemberIds = {};
      Set<String> acceptedInviteIds = {};

      if (playerIds.isNotEmpty) {
        try {
          final activeMembershipRows = await supabase
              .from('player_team_memberships')
              .select('player_id')
              .eq('team_id', widget.teamId)
              .isFilter('end_date', null)
              .inFilter('player_id', playerIds);
          activeMemberIds = (activeMembershipRows as List)
              .map((row) => (row as Map)['player_id']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toSet();
        } catch (_) {}

        try {
          final acceptedInviteRows = await supabase
              .from('team_player_invites')
              .select('player_id')
              .eq('team_id', widget.teamId)
              .eq('status', 'accepted')
              .inFilter('player_id', playerIds);
          acceptedInviteIds = (acceptedInviteRows as List)
              .map((row) => (row as Map)['player_id']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toSet();
        } catch (_) {}
      }

      final filtered = rows.where((row) {
        final playerId = row['player_id']?.toString() ?? '';
        if (playerId.isEmpty) return true;
        return !activeMemberIds.contains(playerId) &&
            !acceptedInviteIds.contains(playerId);
      }).toList();

      if (mounted) {
        setState(() {
          _applications = filtered;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading applications: $error')),
        );
      }
    }
  }

  Future<void> _loadPendingInvites() async {
    try {
      final response = await Supabase.instance.client
          .from('team_player_invites')
          .select('player_id')
          .eq('team_id', widget.teamId)
          .eq('status', 'pending');

      if (!mounted) return;
      setState(() {
        _pendingInvitePlayerIds
          ..clear()
          ..addAll(
            (response as List)
                .map((row) => (row as Map)['player_id']?.toString() ?? '')
                .where((id) => id.isNotEmpty),
          );
      });
    } catch (_) {
      // Non-blocking: only affects invite button state.
    }
  }

  Future<void> _inviteRejectedPlayer({
    required String playerId,
    required String playerName,
  }) async {
    if (playerId.isEmpty) return;
    if (_pendingInvitePlayerIds.contains(playerId)) return;
    if (_processingInvitePlayerIds.contains(playerId)) return;

    final inviterId = Supabase.instance.client.auth.currentUser?.id;
    if (inviterId == null || inviterId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need to be signed in')),
      );
      return;
    }

    setState(() => _processingInvitePlayerIds.add(playerId));
    try {
      await Supabase.instance.client.from('team_player_invites').insert({
        'team_id': widget.teamId,
        'player_id': playerId,
        'invited_by': inviterId,
      });
      if (!mounted) return;
      setState(() {
        _processingInvitePlayerIds.remove(playerId);
        _pendingInvitePlayerIds.add(playerId);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invite sent to $playerName')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _processingInvitePlayerIds.remove(playerId));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not send invite: $error')));
    }
  }

  List<Map<String, dynamic>> get _filteredApplications {
    if (_searchQuery.trim().isEmpty) return _applications;
    final q = _searchQuery.trim().toLowerCase();
    return _applications.where((a) {
      final players = a['players'];
      if (players == null) return false;
      final playerName = (players['player_name'] as String? ?? '')
          .toLowerCase();
      final username = (players['username'] as String? ?? '').toLowerCase();
      return playerName.contains(q) || username.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Rejected applications', style: textTheme.headlineMedium),
        centerTitle: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name or username',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredApplications.isEmpty
                    ? ScrollableAppEmptyState(
                        imageAsset: AppAssets.rejectedApplicationsEmpty,
                        title: _applications.isEmpty
                            ? 'No rejected applications'
                            : 'No matching applications',
                        subtitle: _applications.isEmpty
                            ? 'Players you decline will appear here so you can invite them again later.'
                            : 'Try a different name or username in your search.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredApplications.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final app = _filteredApplications[index];
                          final players =
                              app['players'] as Map<String, dynamic>?;
                          final playerId = app['player_id']?.toString() ?? '';
                          final playerName = players?['player_name'] as String? ??
                              'Unknown';
                          final username =
                              players?['username'] as String? ?? '';
                          final imageUrl = players?['image_url'] as String?;
                          final isPending = _pendingInvitePlayerIds.contains(
                            playerId,
                          );
                          final isProcessing = _processingInvitePlayerIds
                              .contains(playerId);

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: Row(
                              children: [
                                _PlayerAvatar(imageUrl: imageUrl),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        playerName,
                                        style: textTheme.titleMedium,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (username.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          '@$username',
                                          style: textTheme.bodySmall?.copyWith(
                                            color:
                                                colorScheme.onSurfaceVariant,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                FilledButton.tonalIcon(
                                  onPressed:
                                      (playerId.isEmpty || isPending || isProcessing)
                                      ? null
                                      : () => _inviteRejectedPlayer(
                                          playerId: playerId,
                                          playerName: playerName,
                                        ),
                                  icon: isProcessing
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Icon(
                                          isPending
                                              ? Icons.hourglass_top
                                              : Icons.person_add_alt_1,
                                          size: 18,
                                        ),
                                  label: Text(
                                    isProcessing
                                        ? 'Sending'
                                        : isPending
                                        ? 'Pending'
                                        : 'Invite',
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _PlayerAvatar extends StatelessWidget {
  const _PlayerAvatar({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return buildPlayerAvatar(
      imagePath: imageUrl,
      size: 48,
      backgroundColor: colorScheme.surfaceContainerHighest,
      iconColor: colorScheme.onSurfaceVariant,
    );
  }
}
