import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_assets.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/media_placeholders.dart';

class TeamAddPlayersPage extends StatefulWidget {
  const TeamAddPlayersPage({super.key, required this.teamId});

  final String teamId;

  @override
  State<TeamAddPlayersPage> createState() => _TeamAddPlayersPageState();
}

class _TeamAddPlayersPageState extends State<TeamAddPlayersPage> {
  final SupabaseClient _client = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _existingPlayerIds = {};
  final Set<String> _pendingInvitePlayerIds = {};
  final Set<String> _processingIds = {};
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadExistingTeamPlayers();
    _loadPendingInvites();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingTeamPlayers() async {
    try {
      final response = await _client
          .from('player_team_memberships')
          .select('player_id')
          .eq('team_id', widget.teamId)
          .isFilter('end_date', null);

      if (!mounted) return;
      setState(() {
        _existingPlayerIds
          ..clear()
          ..addAll(
            (response as List)
                .map((row) => (row as Map)['player_id']?.toString() ?? '')
                .where((id) => id.isNotEmpty),
          );
      });
    } catch (_) {
      // Non-blocking: keep flow usable even if filtering cannot be prefetched.
    }
  }

  Future<void> _loadPendingInvites() async {
    try {
      final response = await _client
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
      // Non-blocking: this only affects pending button state.
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final query = _searchController.text.trim();
      if (query.isEmpty) {
        setState(() {
          _searchResults = [];
          _hasSearched = false;
        });
        return;
      }
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      final response = await _client
          .from('players')
          .select('id, player_name, username, image_url, position')
          .or('player_name.ilike.%$query%,username.ilike.%$query%')
          .isFilter('deleted_at', null)
          .order('player_name', ascending: true)
          .limit(30);

      final results = (response as List)
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .where((player) {
            final id = player['id']?.toString() ?? '';
            return id.isNotEmpty && !_existingPlayerIds.contains(id);
          })
          .toList();

      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  Future<void> _addPlayer(Map<String, dynamic> player) async {
    final playerId = player['id']?.toString() ?? '';
    if (playerId.isEmpty || _processingIds.contains(playerId)) return;
    if (_pendingInvitePlayerIds.contains(playerId)) return;

    setState(() => _processingIds.add(playerId));
    try {
      final inviterId = _client.auth.currentUser?.id;
      if (inviterId == null || inviterId.isEmpty) {
        throw Exception('You need to be signed in');
      }
      await _client.from('team_player_invites').insert({
        'team_id': widget.teamId,
        'player_id': playerId,
        'invited_by': inviterId,
      });

      if (!mounted) return;
      final playerName = (player['player_name']?.toString().trim().isNotEmpty ??
              false)
          ? player['player_name'].toString().trim()
          : 'Player';
      setState(() {
        _processingIds.remove(playerId);
        _pendingInvitePlayerIds.add(playerId);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invite sent to $playerName')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _processingIds.remove(playerId));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding player: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Add players', style: textTheme.headlineMedium),
        centerTitle: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by player name or username',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              autofocus: true,
            ),
          ),
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : !_hasSearched
                ? const ScrollableAppEmptyState(
                    imageAsset: AppAssets.addPlayersEmpty,
                    title: 'Add players to your team',
                    subtitle:
                        'Search by name or username to find players and send them an invite.',
                  )
                : _searchResults.isEmpty
                ? const ScrollableAppEmptyState(
                    imageAsset: AppAssets.addPlayersEmpty,
                    title: 'No players found',
                    subtitle:
                        'Try a different name or username, or check the spelling.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _searchResults.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final player = _searchResults[index];
                      final playerId = player['id']?.toString() ?? '';
                      final isProcessing = _processingIds.contains(playerId);
                      final isPendingInvite = _pendingInvitePlayerIds.contains(
                        playerId,
                      );
                      return _PlayerSearchListItem(
                        player: player,
                        onAdd: () => _addPlayer(player),
                        isProcessing: isProcessing,
                        isPendingInvite: isPendingInvite,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PlayerSearchListItem extends StatelessWidget {
  const _PlayerSearchListItem({
    required this.player,
    required this.onAdd,
    required this.isProcessing,
    required this.isPendingInvite,
  });

  final Map<String, dynamic> player;
  final VoidCallback onAdd;
  final bool isProcessing;
  final bool isPendingInvite;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final playerName = (player['player_name']?.toString().trim().isNotEmpty ??
            false)
        ? player['player_name'].toString().trim()
        : 'Unknown player';
    final username = player['username']?.toString().trim() ?? '';
    final position = player['position']?.toString().trim() ?? '';
    final imageUrl = player['image_url']?.toString().trim() ?? '';

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
                if (username.isNotEmpty || position.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (username.isNotEmpty) '@$username',
                      if (position.isNotEmpty) position,
                    ].join(' • '),
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
          FilledButton.icon(
            onPressed: (isProcessing || isPendingInvite) ? null : onAdd,
            icon: isProcessing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    isPendingInvite ? Icons.hourglass_top : Icons.person_add,
                    size: 20,
                  ),
            label: Text(
              isProcessing
                  ? 'Sending'
                  : isPendingInvite
                  ? 'Pending'
                  : 'Invite',
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerAvatar extends StatelessWidget {
  const _PlayerAvatar({required this.imageUrl});

  final String imageUrl;

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
