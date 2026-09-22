import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_assets.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/media_placeholders.dart';

class TeamManageApplicationsPage extends StatefulWidget {
  const TeamManageApplicationsPage({super.key, required this.teamId});

  final String teamId;

  @override
  State<TeamManageApplicationsPage> createState() =>
      _TeamManageApplicationsPageState();
}

class _TeamManageApplicationsPageState
    extends State<TeamManageApplicationsPage> {
  List<Map<String, dynamic>> _applications = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final Set<String> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _loadApplications();
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
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _applications = List<Map<String, dynamic>>.from(response);
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

  Future<void> _acceptRequest(String requestId) async {
    if (_processingIds.contains(requestId)) return;
    setState(() => _processingIds.add(requestId));
    try {
      final supabase = Supabase.instance.client;
      await supabase.rpc(
        'accept_team_request',
        params: {'request_id': requestId},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Request accepted')));
      await _loadApplications();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting request: $error')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _processingIds.remove(requestId));
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    if (_processingIds.contains(requestId)) return;
    setState(() => _processingIds.add(requestId));
    try {
      final supabase = Supabase.instance.client;
      await supabase.rpc(
        'reject_team_request',
        params: {'request_id': requestId},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Request rejected')));
      await _loadApplications();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error rejecting request: $error')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _processingIds.remove(requestId));
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
                    imageAsset: AppAssets.approvedApplicationsEmpty,
                    title: _applications.isEmpty
                        ? 'No pending applications'
                        : 'No matching applications',
                    subtitle: _applications.isEmpty
                        ? 'When players apply to join your team, you can review and approve them here.'
                        : 'Try a different name or username in your search.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredApplications.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final app = _filteredApplications[index];
                      final requestId = app['id']?.toString() ?? '';
                      final players = app['players'] as Map<String, dynamic>?;
                      final playerName =
                          players?['player_name'] as String? ?? 'Unknown';
                      final username = players?['username'] as String? ?? '';
                      final imageUrl = players?['image_url'] as String?;
                      final isProcessing = _processingIds.contains(requestId);

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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                              onPressed: requestId.isEmpty || isProcessing
                                  ? null
                                  : () => _acceptRequest(requestId),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.cancel,
                                color: colorScheme.error,
                              ),
                              tooltip: 'Reject',
                              onPressed: requestId.isEmpty || isProcessing
                                  ? null
                                  : () => _rejectRequest(requestId),
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
