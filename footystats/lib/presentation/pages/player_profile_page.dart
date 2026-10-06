import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/guest_mode.dart';
import '../../data/repositories/profile_scout_views_repository.dart';
import '../../data/repositories/user_profile_repository.dart';
import '../../domain/models/user_profile.dart';
import '../providers/favourited_players_provider.dart';
import 'player_comparison_page.dart';
import 'profile.dart';
import 'staff_profile_page.dart';

/// Same layout as the main Profile tab, with a standard back [AppBar].
class PlayerProfilePage extends ConsumerStatefulWidget {
  const PlayerProfilePage({super.key, required this.playerId});

  final String playerId;

  @override
  ConsumerState<PlayerProfilePage> createState() => _PlayerProfilePageState();
}

class _PlayerProfilePageState extends ConsumerState<PlayerProfilePage> {
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

    if (GuestMode.isGuest) return;
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
    if (GuestMode.isGuest) return;
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
        !GuestMode.isGuest &&
        !_isDeleted &&
        currentUserId != null &&
        currentUserId.isNotEmpty &&
        currentUserId != widget.playerId;
    final showFavouriteButton =
        GuestMode.isGuest &&
        !_isDeleted &&
        currentUserId != widget.playerId;
    final isFavourited = showFavouriteButton &&
        ref.watch(favouritedPlayersProvider).any(
          (player) => player.id == widget.playerId,
        );

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
          if (showFavouriteButton)
            IconButton(
              style: IconButton.styleFrom(
                fixedSize: const Size(48, 48),
                padding: EdgeInsets.zero,
              ),
              icon: Icon(
                isFavourited
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                color: isFavourited
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                size: 26,
              ),
              onPressed: () {
                final profile = _viewedProfile;
                final name = profile?.playerName?.trim();
                ref.read(favouritedPlayersProvider.notifier).toggle(
                  FavouritedPlayer(
                    id: widget.playerId,
                    name: (name != null && name.isNotEmpty)
                        ? name
                        : (profile?.username?.trim().isNotEmpty == true
                            ? profile!.username!.trim()
                            : 'Player'),
                    username: profile?.username,
                    imageUrl: profile?.imageUrl,
                    position: profile?.position,
                  ),
                );
              },
              tooltip: isFavourited
                  ? 'Remove from favourites'
                  : 'Add to favourites',
            ),
        ],
      ),
      body: _isStaff || _viewedProfile?.isTechnicalStaff == true
          ? StaffProfilePage(
              viewedUserId: widget.playerId,
              refreshTick: _profileRefreshTick,
              showFollowButton: showFollowButton,
              isFollowing: _isFollowing,
              isUpdatingFollow: _isUpdatingFollow,
              onFollow: _toggleFollow,
            )
          : ProfileScrollView(
              viewedPlayerId: widget.playerId,
              refreshTick: _profileRefreshTick,
              showFollowButton: showFollowButton,
              isFollowing: _isFollowing,
              isUpdatingFollow: _isUpdatingFollow,
              onFollow: _toggleFollow,
            ),
    );
  }
}
