import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/profile_scout_views_repository.dart';
import '../../data/repositories/user_profile_repository.dart';
import '../../domain/models/user_profile.dart';
import 'player_comparison_page.dart';
import 'profile.dart';
import 'staff_profile_page.dart';

/// Same layout as the main Profile tab, with a standard back [AppBar].
class PlayerProfilePage extends StatefulWidget {
  const PlayerProfilePage({super.key, required this.playerId});

  final String playerId;

  @override
  State<PlayerProfilePage> createState() => _PlayerProfilePageState();
}

class _PlayerProfilePageState extends State<PlayerProfilePage> {
  bool _isUpdatingFollow = false;
  bool _isFollowing = false;
  bool _isDeleted = false;
  bool _isStaff = false;
  int _profileRefreshTick = 0;
  UserProfile? _viewedProfile;

  @override
  void initState() {
    super.initState();
    _loadFollowState();
    _loadAccountKind();
    ProfileScoutViewsRepository().recordViewIfScout(widget.playerId);
  }

  Future<void> _loadAccountKind() async {
    try {
      final profile =
          await UserProfileRepository().getProfileByPlayerId(widget.playerId);
      if (!mounted) return;
      setState(() {
        _viewedProfile = profile;
        _isStaff = profile?.isTechnicalStaff == true;
        _isDeleted = profile?.isDeleted == true;
      });
    } catch (_) {}
  }

  Future<void> _loadFollowState() async {
    final client = Supabase.instance.client;
    try {
      final playerRes = await client
          .from('players')
          .select('deleted_at')
          .eq('id', widget.playerId)
          .maybeSingle();
      if (mounted) {
        setState(() => _isDeleted = playerRes?['deleted_at'] != null);
      }
    } catch (_) {}

    final currentUserId = client.auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) return;
    if (currentUserId == widget.playerId) return;
    try {
      final res = await client
          .from('user_follows')
          .select('following_user_id')
          .eq('follower_user_id', currentUserId)
          .eq('following_user_id', widget.playerId)
          .limit(1);
      if (!mounted) return;
      setState(() => _isFollowing = (res as List).isNotEmpty);
    } catch (_) {}
  }

  Future<void> _toggleFollow() async {
    final client = Supabase.instance.client;
    final currentUserId = client.auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to follow this profile')),
      );
      return;
    }
    if (currentUserId == widget.playerId || _isUpdatingFollow) return;

    final newFollowing = !_isFollowing;
    setState(() {
      _isFollowing = newFollowing;
      _isUpdatingFollow = true;
    });

    try {
      if (newFollowing) {
        await client.from('user_follows').insert({
          'follower_user_id': currentUserId,
          'following_user_id': widget.playerId,
        });
      } else {
        await client
            .from('user_follows')
            .delete()
            .eq('follower_user_id', currentUserId)
            .eq('following_user_id', widget.playerId);
      }
      if (!mounted) return;
      setState(() => _profileRefreshTick++);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isFollowing = !newFollowing);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update follow: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isUpdatingFollow = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final showFollowButton =
        !_isDeleted &&
        currentUserId != null &&
        currentUserId.isNotEmpty &&
        currentUserId != widget.playerId;

    return Scaffold(
      appBar: AppBar(
        title: const SizedBox.shrink(),
        titleSpacing: 0,
        actions: [
          if (!_isStaff)
            IconButton(
              tooltip: 'Compare players',
              icon: const Icon(Icons.group_outlined),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        PlayerComparisonPage(basePlayerId: widget.playerId),
                  ),
                );
              },
            ),
          if (showFollowButton)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                onPressed: _isUpdatingFollow ? null : _toggleFollow,
                style: FilledButton.styleFrom(
                  backgroundColor: _isFollowing
                      ? colorScheme.surfaceContainerHigh
                      : colorScheme.primaryContainer,
                  foregroundColor: _isFollowing
                      ? colorScheme.onSurface
                      : colorScheme.onPrimaryContainer,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  minimumSize: const Size(0, 40),
                ),
                child: Text(_isFollowing ? 'Following' : 'Follow'),
              ),
            ),
        ],
      ),
      body: _isStaff || _viewedProfile?.isTechnicalStaff == true
          ? StaffProfilePage(
              viewedUserId: widget.playerId,
              refreshTick: _profileRefreshTick,
            )
          : ProfileScrollView(
              viewedPlayerId: widget.playerId,
              refreshTick: _profileRefreshTick,
            ),
    );
  }
}
