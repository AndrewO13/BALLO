import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../core/constants/app_assets.dart';
import 'league_detail_page.dart';
import 'team_detail_page.dart';

class ExplorePage extends StatelessWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Single explore feed page (no tabs)
    return const _ExploreTabContent(title: 'For you');
  }
}

class _ExploreTabContent extends StatefulWidget {
  final String title;
  const _ExploreTabContent({required this.title});

  @override
  State<_ExploreTabContent> createState() => _ExploreTabContentState();
}

class _ExploreTabContentState extends State<_ExploreTabContent> {
  late Future<List<_ExploreVideoItem>> _future;
  bool _didPrecacheThumbnails = false;

  /// Overrides follow state per poster (when user toggles). Shared across all videos by same poster.
  final Map<String, bool> _followOverrides = {};

  /// Session ID for feed interaction logging (recommendation system).
  late String _sessionId;

  @override
  void initState() {
    super.initState();
    _sessionId = const Uuid().v4();
    _future = _fetchExploreVideos(_sessionId);
  }

  Future<void> _refresh() async {
    setState(() {
      _sessionId = const Uuid().v4();
      _future = _fetchExploreVideos(_sessionId);
      _didPrecacheThumbnails = false;
      _followOverrides.clear();
    });
    await _future;
  }

  void _onFollowChanged(String? posterUserId, bool isFollowing) {
    if (posterUserId == null || posterUserId.isEmpty) return;
    setState(() {
      _followOverrides[posterUserId] = isFollowing;
    });
  }

  bool _effectiveIsFollowing(_ExploreVideoItem item) {
    final uid = item.uploaderUserId;
    if (uid == null || uid.isEmpty) return item.isFollowing;
    return _followOverrides[uid] ?? item.isFollowing;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<_ExploreVideoItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !(snapshot.hasData && snapshot.data!.isNotEmpty)) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Could not load videos',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ),
              ],
            );
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No videos yet',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ),
              ],
            );
          }
          if (!_didPrecacheThumbnails) {
            _didPrecacheThumbnails = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _precacheThumbnails(context, items);
            });
          }
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _ExploreFeedItem(
                item: item,
                sessionId: _sessionId,
                effectiveIsFollowing: _effectiveIsFollowing(item),
                onFollowChanged: _onFollowChanged,
              );
            },
          );
        },
      ),
    );
  }
}

void _precacheThumbnails(BuildContext context, List<_ExploreVideoItem> items) {
  final count = items.length < 8 ? items.length : 8;
  for (var i = 0; i < count; i++) {
    final url = items[i].thumbnailUrl;
    if (url == null || url.isEmpty) continue;
    precacheImage(NetworkImage(url), context);
  }
}

/// Single feed item with event logging for recommendation system.
class _ExploreFeedItem extends StatefulWidget {
  const _ExploreFeedItem({
    required this.item,
    required this.sessionId,
    required this.effectiveIsFollowing,
    required this.onFollowChanged,
  });

  final _ExploreVideoItem item;
  final String sessionId;
  final bool effectiveIsFollowing;
  final void Function(String? posterUserId, bool isFollowing) onFollowChanged;

  @override
  State<_ExploreFeedItem> createState() => _ExploreFeedItemState();
}

class _ExploreFeedItemState extends State<_ExploreFeedItem> {
  String? _impressionId;

  Future<void> _logImpression() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final res = await client.rpc(
        'log_feed_impression',
        params: {
          'p_user_id': userId,
          'p_video_id': widget.item.videoId,
          'p_session_id': widget.sessionId,
          'p_video_seconds': (widget.item.durationSeconds ?? 0).toDouble(),
        },
      );
      if (mounted && res != null) {
        setState(() => _impressionId = res.toString());
      }
    } catch (_) {}
  }

  Future<void> _updateInteraction({
    double? watchSeconds,
    bool? swipedFast,
    bool? liked,
    bool? shared,
    bool? followedUploader,
  }) async {
    if (_impressionId == null) return;
    try {
      await Supabase.instance.client.rpc(
        'update_feed_interaction',
        params: {
          'p_id': _impressionId,
          if (watchSeconds != null) 'p_watch_seconds': watchSeconds,
          if (swipedFast != null) 'p_swiped_fast': swipedFast,
          if (liked != null) 'p_liked': liked,
          if (shared != null) 'p_shared': shared,
          if (followedUploader != null) 'p_followed_uploader': followedUploader,
        },
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MatchInfoCard(
          team1: {
            'name': widget.item.teamAShort,
            'logo': widget.item.teamALogo,
            'score': widget.item.teamAScore,
          },
          team2: {
            'name': widget.item.teamBShort,
            'logo': widget.item.teamBLogo,
            'score': widget.item.teamBScore,
          },
          league: widget.item.leagueName,
          status: widget.item.statusText,
          result: widget.item.resultText,
        ),
        _VideoPlayerSection(
          videoUrl: widget.item.videoUrl,
          thumbnailUrl: widget.item.thumbnailUrl,
          videoId: widget.item.videoId,
          durationSeconds: widget.item.durationSeconds ?? 0,
          onImpressionShown: _logImpression,
          onWatchEnded: (watchSeconds, swipedFast) {
            _updateInteraction(
              watchSeconds: watchSeconds,
              swipedFast: swipedFast,
            );
          },
        ),
        _PosterInfoSection(
          videoId: widget.item.videoId,
          posterName: widget.item.uploaderName ?? 'Unknown',
          posterAvatar: widget.item.uploaderAvatar,
          posterUserId: widget.item.uploaderUserId,
          isLiked: widget.item.isLiked,
          likeCount: widget.item.likeCount,
          isFollowing: widget.effectiveIsFollowing,
          onFollowChanged: widget.onFollowChanged,
          onLiked: () => _updateInteraction(liked: true),
          onShared: () => _updateInteraction(shared: true),
          onFollowed: () => _updateInteraction(followedUploader: true),
        ),
      ],
    );
  }
}

/// Team logo for match info card - supports asset paths and network URLs.
class _TeamLogoAvatar extends StatelessWidget {
  const _TeamLogoAvatar({this.logoPath});

  final String? logoPath;

  @override
  Widget build(BuildContext context) {
    final path = logoPath?.trim();
    if (path == null || path.isEmpty) {
      return CircleAvatar(
        radius: 31.5,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: Icon(
          Icons.groups,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          size: 36,
        ),
      );
    }
    final isNetwork = path.startsWith('http://') || path.startsWith('https://');
    return CircleAvatar(
      radius: 31.5,
      backgroundColor: Colors.transparent,
      child: ClipOval(
        child: SizedBox(
          width: 63,
          height: 63,
          child: isNetwork
              ? Image.network(
                  path,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildFallback(context),
                )
              : Image.asset(
                  path,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildFallback(context),
                ),
        ),
      ),
    );
  }

  Widget _buildFallback(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Icon(
        Icons.groups,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        size: 36,
      ),
    );
  }
}

class _MatchInfoCard extends StatelessWidget {
  final Map<String, dynamic> team1;
  final Map<String, dynamic> team2;
  final String league;
  final String status;
  final String result;

  const _MatchInfoCard({
    required this.team1,
    required this.team2,
    required this.league,
    required this.status,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          Text(
            league,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Team 1
              Row(
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _TeamLogoAvatar(logoPath: team1['logo'] as String?),
                      const SizedBox(height: 8),
                      Text(
                        team1['name'] as String,
                        style: Theme.of(context).textTheme.titleSmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  const SizedBox(width: 32),
                  Text(
                    (team1['score'] as int).toString(),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              // Status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
              // Team 2
              Row(
                children: [
                  Text(
                    (team2['score'] as int).toString(),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 32),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _TeamLogoAvatar(logoPath: team2['logo'] as String?),
                      const SizedBox(height: 8),
                      Text(
                        team2['name'] as String,
                        style: Theme.of(context).textTheme.titleSmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            result,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

/// Video player section with placeholder support
///
/// OPTIMIZATION TIPS for quick video playback when backend is connected:
/// 1. Use video thumbnails/previews for instant display while video loads
/// 2. Implement video preloading for next items in the list
/// 3. Use HLS/DASH streaming for adaptive bitrate
/// 4. Cache videos locally after first play
/// 5. Use lower quality for initial load, upgrade on user interaction
/// 6. Implement lazy loading - only initialize video when scrolled into view
class _VideoPlayerSection extends StatelessWidget {
  final String? videoUrl;
  final String? thumbnailUrl;
  final String videoId;
  final int durationSeconds;
  final VoidCallback? onImpressionShown;
  final void Function(double watchSeconds, bool swipedFast)? onWatchEnded;

  const _VideoPlayerSection({
    this.videoUrl,
    this.thumbnailUrl,
    required this.videoId,
    this.durationSeconds = 0,
    this.onImpressionShown,
    this.onWatchEnded,
  });

  @override
  Widget build(BuildContext context) {
    if (videoUrl != null && videoUrl!.isNotEmpty) {
      return ClipRect(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: _VideoPlayerWidget(
            videoUrl: videoUrl!,
            thumbnailUrl: thumbnailUrl,
            videoId: videoId,
            durationSeconds: durationSeconds,
            onImpressionShown: onImpressionShown,
            onWatchEnded: onWatchEnded,
          ),
        ),
      );
    }
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.5,
      child: thumbnailUrl != null && thumbnailUrl!.isNotEmpty
          ? Image.network(thumbnailUrl!, fit: BoxFit.cover)
          : Container(color: Colors.black),
    );
  }
}

/// Resolves image path for avatars/logos - bare filenames (e.g. "Lefters.png")
/// become full asset paths.
String? _resolveImagePath(String? raw) {
  final id = raw?.trim();
  if (id == null || id.isEmpty) return null;
  if (id.startsWith('http://') || id.startsWith('https://')) return id;
  if (id.startsWith('lib/assets/') || id.startsWith('assets/')) return id;
  // Bare filename: assume team logos folder (used for player placeholders too)
  final name = id.contains('.') ? id : '$id.png';
  return '${AppAssets.teamLogosPath}$name';
}

/// Circular avatar for poster - supports asset paths and network URLs (e.g. Supabase image_url).
class _PosterAvatar extends StatelessWidget {
  const _PosterAvatar({this.posterAvatar, required this.posterName});

  final String? posterAvatar;
  final String posterName;

  @override
  Widget build(BuildContext context) {
    final path = _resolveImagePath(posterAvatar) ?? posterAvatar?.trim();
    final hasImage = path != null && path.isNotEmpty;
    final isNetwork =
        hasImage && (path.startsWith('http://') || path.startsWith('https://'));

    return CircleAvatar(
      radius: 12,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      backgroundImage: hasImage
          ? (isNetwork ? NetworkImage(path) : AssetImage(path))
          : null,
      child: !hasImage
          ? Text(
              posterName.isNotEmpty ? posterName[0].toUpperCase() : '?',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            )
          : null,
    );
  }
}

/// Like button with scale animation and touch feedback.
class _AnimatedLikeButton extends StatefulWidget {
  const _AnimatedLikeButton({
    required this.isLiked,
    required this.likeCount,
    this.onTap,
  });

  final bool isLiked;
  final int likeCount;
  final VoidCallback? onTap;

  @override
  State<_AnimatedLikeButton> createState() => _AnimatedLikeButtonState();
}

class _AnimatedLikeButtonState extends State<_AnimatedLikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 1.35,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onTap == null) return;
    HapticFeedback.lightImpact();
    _controller.forward().then((_) => _controller.reverse());
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap != null ? _handleTap : null,
        borderRadius: BorderRadius.circular(24),
        splashColor: Colors.red.withOpacity(0.2),
        highlightColor: Colors.red.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: AnimatedBuilder(
            animation: _scale,
            builder: (context, child) {
              return Transform.scale(scale: _scale.value, child: child);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.isLiked ? Icons.favorite : Icons.favorite_border,
                  color: widget.isLiked
                      ? Colors.red
                      : Theme.of(context).colorScheme.onSurface,
                  size: 24,
                ),
                if (widget.likeCount > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    '${widget.likeCount}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Poster info section with profile, follow button, like and share buttons
class _PosterInfoSection extends StatefulWidget {
  const _PosterInfoSection({
    required this.videoId,
    required this.posterName,
    this.posterAvatar,
    this.posterUserId,
    required this.isLiked,
    required this.likeCount,
    required this.isFollowing,
    required this.onFollowChanged,
    this.onLiked,
    this.onShared,
    this.onFollowed,
  });

  final String videoId;
  final String posterName;
  final String? posterAvatar;
  final String? posterUserId;
  final bool isLiked;
  final int likeCount;
  final bool isFollowing;
  final void Function(String? posterUserId, bool isFollowing) onFollowChanged;
  final VoidCallback? onLiked;
  final VoidCallback? onShared;
  final VoidCallback? onFollowed;

  @override
  State<_PosterInfoSection> createState() => _PosterInfoSectionState();
}

class _PosterInfoSectionState extends State<_PosterInfoSection> {
  late bool _isLiked;
  late int _likeCount;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.isLiked;
    _likeCount = widget.likeCount;
  }

  @override
  void didUpdateWidget(_PosterInfoSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      _isLiked = widget.isLiked;
      _likeCount = widget.likeCount;
    }
  }

  bool get _isViewerPoster {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    return currentUserId != null &&
        widget.posterUserId != null &&
        currentUserId == widget.posterUserId;
  }

  bool get _showFollowButton =>
      !_isViewerPoster &&
      widget.posterUserId != null &&
      widget.posterUserId!.isNotEmpty;

  Future<void> _toggleFollow() async {
    final client = Supabase.instance.client;
    final currentUserId = client.auth.currentUser?.id;
    if (currentUserId == null || widget.posterUserId == null) return;

    final newFollowing = !widget.isFollowing;
    widget.onFollowChanged(widget.posterUserId, newFollowing);
    try {
      if (newFollowing) {
        await client.from('user_follows').insert({
          'follower_user_id': currentUserId,
          'following_user_id': widget.posterUserId,
        });
        widget.onFollowed?.call();
      } else {
        await client
            .from('user_follows')
            .delete()
            .eq('follower_user_id', currentUserId)
            .eq('following_user_id', widget.posterUserId!);
      }
    } catch (e) {
      widget.onFollowChanged(widget.posterUserId, !newFollowing);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not update follow: $e')));
      }
    }
  }

  Future<void> _toggleLike() async {
    final client = Supabase.instance.client;
    final currentUserId = client.auth.currentUser?.id;
    if (currentUserId == null) return;

    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });
    try {
      if (_isLiked) {
        await client.from('video_likes').insert({
          'video_id': widget.videoId,
          'user_id': currentUserId,
        });
        widget.onLiked?.call();
      } else {
        await client
            .from('video_likes')
            .delete()
            .eq('video_id', widget.videoId)
            .eq('user_id', currentUserId);
      }
    } catch (e) {
      setState(() {
        _isLiked = !_isLiked;
        _likeCount += _isLiked ? 1 : -1;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not update like: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          _PosterAvatar(
            posterAvatar: widget.posterAvatar,
            posterName: widget.posterName,
          ),
          const SizedBox(width: 8),
          Text(
            widget.posterName,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          if (_showFollowButton) ...[
            const SizedBox(width: 16),
            OutlinedButton(
              onPressed: Supabase.instance.client.auth.currentUser != null
                  ? _toggleFollow
                  : null,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                side: BorderSide(color: Theme.of(context).colorScheme.outline),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                widget.isFollowing ? 'Following' : 'Follow',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
          const Spacer(),
          const SizedBox(width: 8),
          _AnimatedLikeButton(
            isLiked: _isLiked,
            likeCount: _likeCount,
            onTap: Supabase.instance.client.auth.currentUser != null
                ? _toggleLike
                : null,
          ),
          // Share button
          IconButton(
            onPressed: () {
              const shareUrl = 'https://footystats.app';
              Clipboard.setData(const ClipboardData(text: shareUrl));
              widget.onShared?.call();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share link copied')),
              );
            },
            icon: Icon(
              Icons.share_outlined,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

// Video widget for playback when video URL is available.
class _VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final String videoId;
  final int durationSeconds;
  final VoidCallback? onImpressionShown;
  final void Function(double watchSeconds, bool swipedFast)? onWatchEnded;

  const _VideoPlayerWidget({
    required this.videoUrl,
    this.thumbnailUrl,
    this.videoId = '',
    this.durationSeconds = 0,
    this.onImpressionShown,
    this.onWatchEnded,
  });

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget>
    with AutomaticKeepAliveClientMixin {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isInitializing = false;
  bool _impressionLogged = false;
  double _watchSeconds = 0;
  Timer? _watchTimer;

  final String _videoKey = 'video_${UniqueKey()}';

  @override
  bool get wantKeepAlive => true;

  void _startWatchTimer() {
    _watchTimer?.cancel();
    _watchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isPlaying && mounted) {
        setState(() => _watchSeconds += 1);
      }
    });
  }

  void _stopWatchTimerAndReport() {
    _watchTimer?.cancel();
    _watchTimer = null;
    widget.onWatchEnded?.call(_watchSeconds, _watchSeconds < 2);
    _watchSeconds = 0;
  }

  Future<void> _initializeVideo() async {
    if (_isInitializing || _controller != null) return;

    _isInitializing = true;

    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );

      await controller.initialize();
      await controller.setLooping(true);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _isInitialized = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _controller = null;
        _isInitialized = false;
      });
    } finally {
      _isInitializing = false;
    }
  }

  void _playVideo() {
    final controller = _controller;
    if (controller == null || !_isInitialized) return;

    controller.play();
    if (mounted) {
      setState(() => _isPlaying = true);
    }
  }

  void _pauseVideo() {
    final controller = _controller;
    if (controller == null || !_isInitialized) return;

    controller.pause();
    if (mounted) {
      setState(() => _isPlaying = false);
    }
  }

  void _scheduleDispose() {
    _stopWatchTimerAndReport();
  }

  void _cancelScheduledDispose() {
    // Timer keeps running while visible
  }

  @override
  void dispose() {
    _watchTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return VisibilityDetector(
      key: Key(_videoKey),
      onVisibilityChanged: (info) async {
        final visible = info.visibleFraction;

        if (visible > 0.30) {
          if (!_impressionLogged) {
            _impressionLogged = true;
            widget.onImpressionShown?.call();
          }
          _startWatchTimer();

          if (_controller == null) {
            await _initializeVideo();
          }

          if (visible > 0.65) {
            _playVideo();
          } else {
            _pauseVideo();
          }
        } else {
          _pauseVideo();
          _scheduleDispose();
        }
      },
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Always show the thumbnail/placeholder; video overlays when ready.
            _buildPlaceholder(),

            if (_isInitialized && _controller != null)
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller!.value.size.width,
                    height: _controller!.value.size.height,
                    child: VideoPlayer(_controller!),
                  ),
                ),
              ),
            if (_isInitialized)
              Center(
                child: GestureDetector(
                  onTap: () {
                    if (_isPlaying) {
                      _pauseVideo();
                    } else {
                      _playVideo();
                    }
                  },
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    if (widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty) {
      return SizedBox.expand(
        child: Image.network(
          widget.thumbnailUrl!,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.low,
          errorBuilder: (_, __, ___) {
            return Container(color: Colors.black);
          },
        ),
      );
    }

    return Container(color: Colors.black);
  }
}

/// Combined view-model for an explore video row.
class _ExploreVideoItem {
  const _ExploreVideoItem({
    required this.videoId,
    required this.videoUrl,
    required this.durationSeconds,
    required this.teamALogo,
    required this.teamBLogo,
    required this.teamAShort,
    required this.teamBShort,
    required this.teamAScore,
    required this.teamBScore,
    required this.leagueName,
    required this.statusText,
    required this.resultText,
    required this.uploaderName,
    required this.uploaderAvatar,
    required this.uploaderUserId,
    required this.thumbnailUrl,
    required this.isLiked,
    required this.likeCount,
    required this.isFollowing,
  });

  final String videoId;
  final String videoUrl;
  final int? durationSeconds;
  final String teamALogo;
  final String teamBLogo;
  final String teamAShort;
  final String teamBShort;
  final int teamAScore;
  final int teamBScore;
  final String leagueName;
  final String statusText;
  final String resultText;
  final String? uploaderName;
  final String? uploaderAvatar;
  final String? uploaderUserId;
  final String? thumbnailUrl;
  final bool isLiked;
  final int likeCount;
  final bool isFollowing;
}

Future<List<_ExploreVideoItem>> _fetchExploreVideos(String sessionId) async {
  final client = Supabase.instance.client;
  final currentUserId = client.auth.currentUser?.id;

  List<Map<String, dynamic>> videos;
  try {
    final params = <String, dynamic>{
      'p_limit': 500,
      'p_offset': 0,
      'p_exploration_rate': 0.12,
    };
    if (currentUserId != null) params['p_user_id'] = currentUserId;
    params['p_session_id'] = sessionId;
    final rpcRes = await client.rpc('get_recommended_videos', params: params);
    videos = List<Map<String, dynamic>>.from(rpcRes as List);
    if (videos.isEmpty) videos = [];
  } catch (_) {
    videos = [];
  }

  if (videos.isEmpty) {
    final fallbackRes = await client
        .from('videos')
        .select(
          'id, match_id, uploader_user_id, duration_seconds, video_url, thumbnail_url',
        )
        .order('created_at', ascending: false)
        .limit(500);
    videos = List<Map<String, dynamic>>.from(fallbackRes as List);
  }
  if (videos.isEmpty) return const [];

  if (videos.first.containsKey('video_id')) {
    videos = videos.map((r) {
      return {
        'id': r['video_id'],
        'match_id': r['match_id'],
        'uploader_user_id': r['uploader_user_id'],
        'duration_seconds': r['duration_seconds'],
        'video_url': r['video_url'],
        'thumbnail_url': r['thumbnail_url'],
      };
    }).toList();
  }

  final matchIds = <String>{};
  final uploaderIds = <String>{};
  final videoIds = <String>[];
  for (final v in videos) {
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
        .select('''
      id, status, teamA_score, teamB_score, league_id,
      league:leagues!league_id(league_name),
      teamA:teams!teamA(id, logo_id, short_form),
      teamB:teams!teamB(id, logo_id, short_form)
    ''')
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

  // Fetch follow status: does current user follow each poster?
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

  // Fetch like status and counts per video
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

  return videos.map((v) {
    final match = matchesMap[v['match_id']?.toString()] ?? <String, dynamic>{};
    // League can be object {league_name} or array [{league_name}] from Supabase
    final leagueRaw = match['league'];
    final league = leagueRaw is Map<String, dynamic>
        ? leagueRaw
        : (leagueRaw is List &&
              leagueRaw.isNotEmpty &&
              leagueRaw.first is Map<String, dynamic>)
        ? leagueRaw.first as Map<String, dynamic>
        : <String, dynamic>{};
    final teamA = match['teamA'] as Map<String, dynamic>? ?? {};
    final teamB = match['teamB'] as Map<String, dynamic>? ?? {};
    final uploader =
        uploadersMap[v['uploader_user_id']?.toString()] ?? <String, dynamic>{};

    final teamAScore = match['teamA_score'] is int
        ? match['teamA_score'] as int
        : int.tryParse(match['teamA_score']?.toString() ?? '0') ?? 0;
    final teamBScore = match['teamB_score'] is int
        ? match['teamB_score'] as int
        : int.tryParse(match['teamB_score']?.toString() ?? '0') ?? 0;

    String result;
    if (teamAScore > teamBScore) {
      result = '${teamA['short_form'] ?? 'Team A'} wins!';
    } else if (teamBScore > teamAScore) {
      result = '${teamB['short_form'] ?? 'Team B'} wins!';
    } else {
      result = 'Draw';
    }

    final status = match['status']?.toString() ?? '';

    final uploaderUserId = v['uploader_user_id']?.toString();
    final vid = v['id']?.toString() ?? '';

    return _ExploreVideoItem(
      videoId: vid,
      videoUrl: v['video_url']?.toString() ?? '',
      durationSeconds: v['duration_seconds'] as int?,
      teamALogo:
          _resolveLogoPath(teamA['logo_id']?.toString()) ??
          AppAssets.theShieldLogo,
      teamBLogo:
          _resolveLogoPath(teamB['logo_id']?.toString()) ??
          AppAssets.laFamilleLogo,
      teamAShort: teamA['short_form']?.toString() ?? 'Team A',
      teamBShort: teamB['short_form']?.toString() ?? 'Team B',
      teamAScore: teamAScore,
      teamBScore: teamBScore,
      leagueName: league['league_name']?.toString() ?? 'League',
      statusText: status,
      resultText: result,
      uploaderName: uploader['player_name']?.toString(),
      uploaderAvatar: uploader['image_url']?.toString(),
      uploaderUserId: uploaderUserId,
      thumbnailUrl: v['thumbnail_url']?.toString(),
      isLiked: likedVideoIds.contains(vid),
      likeCount: likeCountMap[vid] ?? 0,
      isFollowing:
          uploaderUserId != null && followsSet.contains(uploaderUserId),
    );
  }).toList();
}

class ExploreSearchBar extends StatefulWidget {
  const ExploreSearchBar({super.key});

  @override
  State<ExploreSearchBar> createState() => _ExploreSearchBarState();
}

class _ExploreSearchBarState extends State<ExploreSearchBar> {
  final Map<String, List<_SearchItem>> _cache = {};
  final List<_SearchItem> _suggestions = [];
  Timer? _debounce;
  bool _isLoading = false;
  String _lastQuery = '';
  String? _errorMessage;
  SearchController? _controller;
  int _requestId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller?.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() {
    final controller = _controller;
    if (controller == null) return;
    _onQueryChanged(controller.text);
  }

  void _attachController(SearchController controller) {
    if (_controller == controller) return;
    _controller?.removeListener(_handleControllerChanged);
    _controller = controller;
    _controller?.addListener(_handleControllerChanged);
  }

  void _onQueryChanged(String query) {
    final trimmed = query.trim();
    _lastQuery = trimmed;
    _debounce?.cancel();

    if (trimmed.isEmpty) {
      setState(() {
        _suggestions.clear();
        _isLoading = false;
        _errorMessage = null;
      });
      _controller?.openView();
      return;
    }

    if (trimmed.length < 2) {
      setState(() {
        _suggestions.clear();
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    if (_cache.containsKey(trimmed)) {
      setState(() {
        _suggestions
          ..clear()
          ..addAll(_cache[trimmed]!);
        _isLoading = false;
        _errorMessage = null;
      });
      _controller?.openView();
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 250), () {
      _fetchSuggestions(trimmed);
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    final requestId = ++_requestId;
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final leaguesRes = await supabase
          .from('leagues')
          .select('id, league_name, logo_id')
          .ilike('league_name', '%$query%')
          .limit(10);
      final teamsRes = await supabase
          .from('teams')
          .select('id, team_name, logo_id')
          .ilike('team_name', '%$query%')
          .limit(10);

      final leagues = (leaguesRes as List)
          .map(
            (e) => _SearchItem(
              id: (e['id'] ?? '').toString(),
              label: (e['league_name'] ?? '').toString(),
              type: 'League',
              logoPath: _resolveLogoPath(e['logo_id']?.toString()),
            ),
          )
          .where((item) => item.label.isNotEmpty)
          .toList();
      final teams = (teamsRes as List)
          .map(
            (e) => _SearchItem(
              id: (e['id'] ?? '').toString(),
              label: (e['team_name'] ?? '').toString(),
              type: 'Team',
              logoPath: _resolveLogoPath(e['logo_id']?.toString()),
            ),
          )
          .where((item) => item.label.isNotEmpty)
          .toList();

      final combined = [...leagues, ...teams];
      _cache[query] = combined;
      if (!mounted || _lastQuery != query || requestId != _requestId) return;
      setState(() {
        _suggestions
          ..clear()
          ..addAll(combined);
        _isLoading = false;
        _errorMessage = null;
      });
      _controller?.openView();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Search failed. Please try again.';
      });
      _controller?.openView();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: SearchAnchor(
        builder: (BuildContext context, SearchController controller) {
          _attachController(controller);
          return SearchBar(
            controller: controller,
            padding: const WidgetStatePropertyAll<EdgeInsets>(
              EdgeInsets.symmetric(horizontal: 16.0),
            ),
            onTap: () {
              controller.openView();
              if (controller.text.isNotEmpty) {
                _onQueryChanged(controller.text);
              }
            },
            onChanged: (_) {
              controller.openView();
              _onQueryChanged(controller.text);
            },
            leading: const Icon(Icons.search),
            hintText: 'Search...',
            hintStyle: WidgetStatePropertyAll(
              TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          );
        },
        suggestionsBuilder:
            (BuildContext context, SearchController controller) {
              if (_isLoading) {
                return [
                  const ListTile(
                    leading: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    title: Text('Searching...'),
                  ),
                ];
              }
              if (_errorMessage != null) {
                return [ListTile(title: Text(_errorMessage!))];
              }
              if (_suggestions.isEmpty) {
                return [const ListTile(title: Text('No results'))];
              }
              return _suggestions.map((item) {
                return ListTile(
                  leading: _SearchLogo(
                    logoPath: item.logoPath,
                    fallbackIcon: item.type == 'League'
                        ? Icons.emoji_events
                        : Icons.groups,
                  ),
                  title: Text(item.label),
                  subtitle: Text(item.type),
                  onTap: () {
                    controller.closeView(item.label);
                    if (item.type == 'League') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => LeagueDetailPage(leagueId: item.id),
                        ),
                      );
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TeamDetailPage(teamId: item.id),
                        ),
                      );
                    }
                  },
                );
              }).toList();
            },
      ),
    );
  }
}

class _SearchItem {
  const _SearchItem({
    required this.id,
    required this.label,
    required this.type,
    this.logoPath,
  });

  final String id;
  final String label;
  final String type;
  final String? logoPath;
}

String? _resolveLogoPath(String? logoId) {
  final id = logoId?.trim();
  if (id == null || id.isEmpty) return null;
  if (id.startsWith('http://') || id.startsWith('https://')) return id;
  if (id.startsWith('lib/assets/') || id.startsWith('assets/')) return id;
  // If a filename or key is provided, assume it sits under team logos
  final name = id.contains('.') ? id : '$id.png';
  return '${AppAssets.teamLogosPath}$name';
}

class _SearchLogo extends StatelessWidget {
  const _SearchLogo({this.logoPath, required this.fallbackIcon});

  final String? logoPath;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final path = logoPath;
    if (path == null || path.isEmpty) {
      return CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: Icon(
          fallbackIcon,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    final isNetwork = path.startsWith('http://') || path.startsWith('https://');
    final image = isNetwork
        ? Image.network(
            path,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          )
        : Image.asset(
            path,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          );
    return CircleAvatar(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: ClipOval(child: SizedBox(width: 36, height: 36, child: image)),
    );
  }
}
