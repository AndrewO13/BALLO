import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_assets.dart';
import 'team_manage_applications_page.dart';
import 'team_rejected_applications_page.dart';

class TeamDetailPage extends StatefulWidget {
  const TeamDetailPage({super.key, required this.teamId});

  final String teamId;

  @override
  State<TeamDetailPage> createState() => _TeamDetailPageState();
}

class _TeamDetailPageState extends State<TeamDetailPage> {
  Map<String, dynamic>? _team;
  bool _isLoading = true;
  bool _isDeleting = false;
  bool _hasJoined = false;
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    _loadTeam();
  }

  Future<void> _loadTeam() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('teams')
          .select()
          .eq('id', widget.teamId)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _team = response;
          _isLoading = false;
        });
        await _refreshJoinState();
      } else if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Team not found')));
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading team: $error')));
    }
  }

  Future<void> _refreshJoinState() async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      final membership = await supabase
          .from('player_team_memberships')
          .select('id')
          .eq('team_id', widget.teamId)
          .eq('player_id', currentUser.id)
          .maybeSingle();

      final joinRequest = await supabase
          .from('team_join_requests')
          .select('id, status')
          .eq('team_id', widget.teamId)
          .eq('player_id', currentUser.id)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _hasJoined = membership != null || joinRequest != null;
      });
    } catch (_) {
      // Ignore join state errors; keep existing UI state.
    }
  }

  Future<void> _handleJoinTeam() async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need to be logged in to join a team'),
        ),
      );
      return;
    }

    if (_hasJoined || _isJoining) return;

    setState(() {
      _isJoining = true;
    });

    try {
      final playerId = currentUser.id;

      // Create a join request (player is added to memberships when accepted)
      await supabase.from('team_join_requests').insert({
        'team_id': widget.teamId,
        'player_id': playerId,
      });

      if (!mounted) return;

      setState(() {
        _hasJoined = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your join request has been sent.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not join team: $error')));
    } finally {
      if (!mounted) return;
      setState(() {
        _isJoining = false;
      });
    }
  }

  Future<void> _deleteTeam() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Team'),
        content: const Text(
          'Are you sure you want to delete this team? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('teams').delete().eq('id', widget.teamId);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Team deleted')));
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting team: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const SizedBox.shrink(), centerTitle: false),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_team == null) {
      return Scaffold(
        appBar: AppBar(title: const SizedBox.shrink(), centerTitle: false),
        body: const Center(child: Text('Team not found')),
      );
    }

    final teamName = _team!['team_name'] as String? ?? 'Unknown';
    final shortForm = _team!['short_form'] as String? ?? '';
    final logoUrl = _team!['logo_id'] as String?;
    final createdBy = _team!['created_by']?.toString();
    final createdAt = _team!['created_at'];
    final createdAtDt = createdAt is DateTime
        ? createdAt
        : (createdAt is String ? DateTime.tryParse(createdAt) : null);
    final estYear = createdAtDt?.year ?? DateTime.now().year;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isOwner = createdBy != null && createdBy == currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: const SizedBox.shrink(),
        centerTitle: false,
        actions: [
          if (!isOwner) ...[
            IconButton(
              icon: SvgPicture.asset(
                AppAssets.teamCompareIcon,
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(
                  colorScheme.onSurface,
                  BlendMode.srcIn,
                ),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Team compare coming soon')),
                );
              },
              tooltip: 'Compare team',
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: _hasJoined
                  ? const FilledButton(
                      onPressed: null,
                      child: Icon(Icons.check),
                    )
                  : FilledButton(
                      onPressed: _isJoining ? null : _handleJoinTeam,
                      child: _isJoining
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Join team'),
                    ),
            ),
          ] else if (_isDeleting)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            IconButton(
              icon: SvgPicture.asset(
                AppAssets.teamCompareIcon,
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(
                  colorScheme.onSurface,
                  BlendMode.srcIn,
                ),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Team compare coming soon')),
                );
              },
              tooltip: 'Compare team',
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'More options',
              onSelected: (value) {
                switch (value) {
                  case 'edit_squad':
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Edit squad (coming soon)')),
                    );
                    break;
                  case 'manage_applications':
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) =>
                            TeamManageApplicationsPage(teamId: widget.teamId),
                      ),
                    );
                    break;
                  case 'rejected_applications':
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) =>
                            TeamRejectedApplicationsPage(teamId: widget.teamId),
                      ),
                    );
                    break;
                  case 'add_players':
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Add players to team (coming soon)'),
                      ),
                    );
                    break;
                  case 'leave_team':
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Leave team (coming soon)')),
                    );
                    break;
                  case 'delete':
                    _deleteTeam();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'edit_squad',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 16),
                      Text('Edit squad'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'manage_applications',
                  child: Row(
                    children: [
                      Icon(Icons.how_to_reg),
                      SizedBox(width: 16),
                      Text('Manage applications'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'rejected_applications',
                  child: Row(
                    children: [
                      Icon(Icons.cancel),
                      SizedBox(width: 16),
                      Text('Rejected applications'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'add_players',
                  child: Row(
                    children: [
                      Icon(Icons.person_add),
                      SizedBox(width: 16),
                      Text('Add players to team'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'leave_team',
                  child: Row(
                    children: [
                      Icon(Icons.exit_to_app),
                      SizedBox(width: 16),
                      Text('Leave team'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: colorScheme.error),
                      const SizedBox(width: 16),
                      Text(
                        'Delete team',
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: DefaultTabController(
        length: 7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Column(
                children: [
                  // Header (logo + name + est. year)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                        bottomLeft: Radius.circular(0),
                        bottomRight: Radius.circular(0),
                      ),
                    ),
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                              width: 1,
                            ),
                          ),
                          child: logoUrl != null && logoUrl.isNotEmpty
                              ? ClipOval(
                                  child: Image.network(
                                    logoUrl,
                                    width: 96,
                                    height: 96,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(
                                        Icons.groups,
                                        size: 44,
                                        color: colorScheme.onSurfaceVariant,
                                      );
                                    },
                                  ),
                                )
                              : Icon(
                                  Icons.groups,
                                  size: 44,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                teamName,
                                style: textTheme.titleLarge,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Est. $estYear',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (shortForm.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  shortForm,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Tab bar (0 spacing, same background as header)
                  Container(
                    width: double.infinity,
                    color: colorScheme.surfaceContainerHigh,
                    child: TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      dividerColor: Colors.transparent,
                      labelColor: colorScheme.onSurface,
                      unselectedLabelColor: colorScheme.onSurfaceVariant,
                      indicatorColor: colorScheme.primary,
                      tabs: const [
                        Tab(text: 'Overview'),
                        Tab(text: 'Matches'),
                        Tab(text: 'Standings'),
                        Tab(text: 'Stats'),
                        Tab(text: 'Top players'),
                        Tab(text: 'Squad'),
                        Tab(text: 'Videos'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _TabPlaceholder(title: 'Overview'),
                  _TabPlaceholder(title: 'Matches'),
                  _TabPlaceholder(title: 'Standings'),
                  _TabPlaceholder(title: 'Stats'),
                  _TabPlaceholder(title: 'Top players'),
                  _SquadTab(teamId: widget.teamId),
                  _TabPlaceholder(title: 'Videos'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabPlaceholder extends StatelessWidget {
  const _TabPlaceholder({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Text(
        '$title (coming soon)',
        style: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SquadTab extends StatefulWidget {
  const _SquadTab({required this.teamId});

  final String teamId;

  @override
  State<_SquadTab> createState() => _SquadTabState();
}

class _SquadTabState extends State<_SquadTab> {
  bool _isEditing = false;
  final Map<String, Offset> _playerOffsets = {};
  final Map<String, Offset> _savedOffsets = {};
  final Map<String, Offset> _editStartOffsets = {};
  final Set<String> _isOnBench = {};
  final Set<String> _savedOnBench = {};
  final Set<String> _editStartOnBench = {};
  final Set<String> _isDragging = {};
  Size? _lastPitchSize;
  List<Map<String, dynamic>> _members = [];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('player_team_memberships')
          .select(
            'player_id, players!player_team_memberships_player_id_fkey(player_name, image_url)',
          )
          .eq('team_id', widget.teamId)
          .isFilter('end_date', null);
      if (!mounted) return;
      setState(() {
        _members = List<Map<String, dynamic>>.from(response);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading squad: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pitchWidth = constraints.maxWidth;
          final pitchHeight = pitchWidth * (274 / 380);
          final benchHeight = pitchWidth * (94 / 380);
          final bgHeight = pitchWidth;
          final pitchTop = bgHeight - pitchHeight;
          final pitchBottom = pitchTop + pitchHeight;
          const playerSize = 60.0;
          const snapZoneHeight = 24.0;

          final displayMembers = _members.isNotEmpty
              ? _members
              : [
                  {
                    'player_id': 'fallback',
                    'players': {
                      'player_name': 'Wacha',
                      'image_url': 'lib/assets/images/player.png',
                    },
                  },
                ];

          final currentSize = Size(pitchWidth, bgHeight + benchHeight);
          if (_lastPitchSize != currentSize) {
            for (final member in displayMembers) {
              final memberId = (member['player_id'] ?? '').toString();
              if (memberId.isEmpty) continue;
              if (!_playerOffsets.containsKey(memberId)) {
                final fallback = Offset(
                  (pitchWidth - playerSize) / 2,
                  pitchTop + (pitchHeight - playerSize) / 2,
                );
                final saved = _savedOffsets[memberId];
                _playerOffsets[memberId] = saved ?? fallback;
                if (_savedOnBench.contains(memberId)) {
                  _isOnBench.add(memberId);
                }
              }
            }
            _lastPitchSize = currentSize;
          }

          Offset clampOffset(Offset value) {
            final clampedX =
                value.dx.clamp(0.0, pitchWidth - playerSize);
            final clampedY = value.dy.clamp(
              0.0,
              (bgHeight + benchHeight) - playerSize,
            );
            return Offset(clampedX, clampedY);
          }

          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: pitchWidth,
              height: bgHeight + benchHeight,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    width: pitchWidth,
                    child: Image.asset(
                      'lib/assets/images/pitch bg.png',
                      fit: BoxFit.contain,
                      alignment: Alignment.bottomCenter,
                      color: const Color(0xFF107F6B),
                      colorBlendMode: BlendMode.color,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: pitchTop,
                    width: pitchWidth,
                    height: pitchHeight,
                    child: SvgPicture.asset(
                      'lib/assets/icons/squad/pitch.svg',
                      fit: BoxFit.contain,
                    ),
                  ),
                  if (_isDragging.any((id) =>
                      (_playerOffsets[id]?.dy ?? 0) >=
                      (pitchBottom - snapZoneHeight)))
                    Positioned(
                      left: 0,
                      top: pitchBottom - snapZoneHeight,
                      width: pitchWidth,
                      height: snapZoneHeight,
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.35),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.6),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    top: bgHeight,
                    width: pitchWidth,
                    height: benchHeight,
                    child: SvgPicture.asset(
                      'lib/assets/icons/squad/bench.svg',
                      fit: BoxFit.contain,
                    ),
                  ),
                  for (final member in displayMembers)
                    Builder(
                      builder: (context) {
                        final memberId = (member['player_id'] ?? '').toString();
                        if (memberId.isEmpty) return const SizedBox.shrink();
                        final player =
                            member['players'] as Map<String, dynamic>?;
                        final name =
                            player?['player_name'] as String? ?? 'Player';
                        final imageUrl =
                            player?['image_url'] as String? ?? '';
                        final offset = _playerOffsets[memberId] ??
                            Offset(
                              (pitchWidth - playerSize) / 2,
                              pitchTop + (pitchHeight - playerSize) / 2,
                            );
                        final isDragging = _isDragging.contains(memberId);
                        return AnimatedPositioned(
                          duration: isDragging
                              ? Duration.zero
                              : const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          left: offset.dx,
                          top: offset.dy,
                          child: GestureDetector(
                            onPanStart: _isEditing
                                ? (_) {
                                    setState(() {
                                      _isDragging.add(memberId);
                                    });
                                  }
                                : null,
                            onPanUpdate: _isEditing
                                ? (details) {
                                    setState(() {
                                      final current =
                                          _playerOffsets[memberId] ?? offset;
                                      _playerOffsets[memberId] = clampOffset(
                                        current + details.delta,
                                      );
                                    });
                                  }
                                : null,
                            onPanEnd: _isEditing
                                ? (_) {
                                    final current =
                                        _playerOffsets[memberId] ?? offset;
                                    final isNearBenchZone =
                                        current.dy >=
                                            (pitchBottom - snapZoneHeight);
                                    final isNearPitchZone =
                                        current.dy <=
                                            (pitchBottom - snapZoneHeight);
                                    setState(() {
                                      _isDragging.remove(memberId);
                                      if (!_isOnBench.contains(memberId) &&
                                          isNearBenchZone) {
                                        _isOnBench.add(memberId);
                                        _playerOffsets[memberId] = Offset(
                                          current.dx,
                                          bgHeight +
                                              (benchHeight - playerSize) / 2,
                                        );
                                      } else if (_isOnBench
                                              .contains(memberId) &&
                                          isNearPitchZone) {
                                        _isOnBench.remove(memberId);
                                        _playerOffsets[memberId] = Offset(
                                          current.dx,
                                          pitchTop +
                                              (pitchHeight - playerSize) / 2,
                                        );
                                      }
                                    });
                                  }
                                : null,
                            child: TeamPlayer(
                              name: name,
                              imageAsset: imageUrl,
                            ),
                          ),
                        );
                      },
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _isEditing
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.close,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                tooltip: 'Cancel',
                                onPressed: () {
                                  setState(() {
                                    _playerOffsets
                                      ..clear()
                                      ..addAll(_editStartOffsets);
                                    _isOnBench
                                      ..clear()
                                      ..addAll(_editStartOnBench);
                                    _isEditing = false;
                                    _isDragging.clear();
                                  });
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.check,
                                  color: Colors.green,
                                ),
                                tooltip: 'Save',
                                onPressed: () {
                                  setState(() {
                                    _savedOffsets
                                      ..clear()
                                      ..addAll(_playerOffsets);
                                    _savedOnBench
                                      ..clear()
                                      ..addAll(_isOnBench);
                                    _isEditing = false;
                                    _isDragging.clear();
                                  });
                                },
                              ),
                            ],
                          )
                        : IconButton(
                            icon: const Icon(Icons.edit),
                            tooltip: 'Edit lineup',
                            onPressed: () {
                              setState(() {
                                _editStartOffsets
                                  ..clear()
                                  ..addAll(_playerOffsets);
                                _editStartOnBench
                                  ..clear()
                                  ..addAll(_isOnBench);
                                _isEditing = true;
                              });
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class TeamPlayer extends StatelessWidget {
  const TeamPlayer({
    super.key,
    required this.name,
    required this.imageAsset,
  });

  final String name;
  final String imageAsset;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final path = imageAsset.trim();
    final isNetwork = path.startsWith('http://') || path.startsWith('https://');
    final image = path.isEmpty
        ? Image.asset(
            AppAssets.playerImage,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
          )
        : isNetwork
            ? Image.network(
                path,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Image.asset(
                  AppAssets.playerImage,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                ),
              )
            : Image.asset(
                path,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Image.asset(
                  AppAssets.playerImage,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                ),
              );
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            top: 0,
            child: SvgPicture.asset(
              'lib/assets/icons/squad/back.svg',
              width: 60,
              height: 60,
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            top: 0,
            child: image,
          ),
          Positioned(
            bottom: 0,
            child: SizedBox(
              width: 60,
              height: 16,
              child: Stack(
                children: [
                  SvgPicture.asset(
                    'lib/assets/icons/squad/name.svg',
                    width: 60,
                    height: 16,
                    fit: BoxFit.contain,
                  ),
                  Center(
                    child: Text(
                      name,
                      style: textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
