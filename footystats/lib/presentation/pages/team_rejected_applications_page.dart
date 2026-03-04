import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_assets.dart';

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
          .eq('status', 'rejected')
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
                filled: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredApplications.isEmpty
                    ? Center(
                        child: Text(
                          'No rejected applications',
                          style: textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredApplications.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final app = _filteredApplications[index];
                          final players =
                              app['players'] as Map<String, dynamic>?;
                          final playerName = players?['player_name'] as String? ??
                              'Unknown';
                          final username =
                              players?['username'] as String? ?? '';
                          final imageUrl = players?['image_url'] as String?;

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
    final path = imageUrl;
    if (path == null || path.isEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.person,
          color: colorScheme.onSurfaceVariant,
          size: 28,
        ),
      );
    }
    final isNetwork = path.startsWith('http://') || path.startsWith('https://');
    final image = isNetwork
        ? Image.network(
            path,
            fit: BoxFit.cover,
            width: 48,
            height: 48,
            errorBuilder: (_, __, ___) => Icon(
              Icons.person,
              color: colorScheme.onSurfaceVariant,
              size: 28,
            ),
          )
        : Image.asset(
            '${AppAssets.teamLogosPath}$path',
            fit: BoxFit.cover,
            width: 48,
            height: 48,
            errorBuilder: (_, __, ___) => Icon(
              Icons.person,
              color: colorScheme.onSurfaceVariant,
              size: 28,
            ),
          );
    return ClipOval(child: SizedBox(width: 48, height: 48, child: image));
  }
}
