import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/adaptive/adaptive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../core/constants/app_assets.dart';
import '../../core/utils/app_video_cache.dart';
import '../../core/utils/connection_error.dart';
import '../../core/utils/explore_video_controller.dart';
import '../../core/utils/network_quality.dart';
import '../../core/utils/scroll_to_top.dart';
import '../../core/utils/video_share.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_error_state.dart';
import '../../core/widgets/media_placeholders.dart';
import 'fixture.dart';
import 'league_video_player_page.dart';
import 'player_profile_page.dart';
import '../providers/main_nav_scroll_provider.dart';
import '../widgets/app_search_page.dart';
import '../widgets/content_safety_sheets.dart';
import '../widgets/guest_account_sheet.dart';

class ExplorePage extends StatelessWidget {
  const ExplorePage({super.key, this.isActiveTab = true});

  /// When false (another bottom-nav tab is shown), the feed does not fetch or
  /// preload anything. Data is loaded the first time the tab becomes active.
  final bool isActiveTab;

  @override
  Widget build(BuildContext context) {
    // Single explore feed page (no tabs)
    return _ExploreTabContent(title: 'For you', isActiveTab: isActiveTab);
  }
}

class _ExploreTabContent extends ConsumerStatefulWidget {
  final String title;
  final bool isActiveTab;
  const _ExploreTabContent({required this.title, required this.isActiveTab});

  @override
  ConsumerState<_ExploreTabContent> createState() => _ExploreTabContentState();
}

class _ExploreTabContentState extends ConsumerState<_ExploreTabContent> {
  static const int _pageSize = 30;

  final ScrollController _scrollController = ScrollController();

  final List<_ExploreVideoItem> _items = [];
  final Set<String> _seenVideoIds = {};
  bool _hasLoadedOnce = false;
  bool _isInitialLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  Object? _error;
  int _nextOffset = 0;
  bool _didPrecacheThumbnails = false;

  /// Overrides follow state per poster (when user toggles). Shared across all videos by same poster.
  final Map<String, bool> _followOverrides = {};

  /// Session ID for feed interaction logging (recommendation system).
  String _sessionId = const Uuid().v4();

  @override
  void initState() {
    super.initState();
    // Only fetch when the Explore tab is actually shown; IndexedStack keeps
    // this widget mounted from app launch, and eager fetching wastes data.
    if (widget.isActiveTab) {
      unawaited(_loadInitial());
    }
  }

  @override
  void didUpdateWidget(covariant _ExploreTabContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActiveTab && !oldWidget.isActiveTab && !_hasLoadedOnce) {
      unawaited(_loadInitial());
    }
  }

  Future<void> _loadInitial() async {
    if (_isInitialLoading) return;
    setState(() {
      _hasLoadedOnce = true;
      _isInitialLoading = true;
      _error = null;
    });
    final sessionId = const Uuid().v4();
    try {
      final page = await _fetchExploreVideos(
        sessionId,
        limit: _pageSize,
        offset: 0,
      );
      if (!mounted) return;
      setState(() {
        _sessionId = sessionId;
        _items
          ..clear()
          ..addAll(page);
        _seenVideoIds
          ..clear()
          ..addAll(page.map((e) => e.videoId));
        _nextOffset = page.length;
        _hasMore = page.length >= _pageSize;
        _isInitialLoading = false;
        _didPrecacheThumbnails = false;
        _followOverrides.clear();
      });
      unawaited(_ExploreVideoPreloadCache.instance.preloadThumbnails(page));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _isInitialLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _isInitialLoading || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final page = await _fetchExploreVideos(
        _sessionId,
        limit: _pageSize,
        offset: _nextOffset,
      );
      if (!mounted) return;
      final fresh = page
          .where((e) => e.videoId.isNotEmpty && _seenVideoIds.add(e.videoId))
          .toList();
      setState(() {
        _items.addAll(fresh);
        _nextOffset += page.length;
        _hasMore = page.length >= _pageSize;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Keep already-loaded items; allow retrying on further scroll.
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _refresh() => _loadInitial();

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
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(
      mainNavScrollToTopProvider.select((m) => m[MainNavTab.explore] ?? 0),
      (previous, next) {
        if (previous == next) return;
        animateScrollControllerToTop(_scrollController);
      },
    );

    if (!_hasLoadedOnce || (_isInitialLoading && _items.isEmpty)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: 560,
              child: Center(
                child: AppConnectionErrorState(
                  title: isConnectionError(_error)
                      ? 'No connection'
                      : 'Could not load videos',
                  subtitle: isConnectionError(_error)
                      ? 'Check your internet connection and try again.'
                      : 'Something went wrong while loading the feed.',
                  onRetry: _refresh,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(
              height: 560,
              child: Center(
                child: AppEmptyState(
                  imageAsset: AppAssets.videosEmpty,
                  title: 'No videos to explore yet',
                  subtitle:
                      'Fresh highlights from players and teams will show up here soon.',
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (!_didPrecacheThumbnails) {
      _didPrecacheThumbnails = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _precacheThumbnails(context, _items);
      });
    }
    final items = List<_ExploreVideoItem>.unmodifiable(_items);
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= items.length) {
            // Loading tile at the end triggers the next page.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _loadMore();
            });
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          // Fetch the next page slightly before the user reaches the end.
          if (_hasMore && index >= items.length - 3) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _loadMore();
            });
          }
          final item = items[index];
          return _ExploreFeedItem(
            item: item,
            feedItems: items,
            sessionId: _sessionId,
            effectiveIsFollowing: _effectiveIsFollowing(item),
            onFollowChanged: _onFollowChanged,
          );
        },
      ),
    );
  }
}

void _precacheThumbnails(BuildContext context, List<_ExploreVideoItem> items) {
  unawaited(() async {
    final wifi = await NetworkQuality.allowsVideoAutoplay;
    if (!context.mounted) return;
    final cap = wifi ? 8 : 1;
    final count = items.length < cap ? items.length : cap;
    for (var i = 0; i < count; i++) {
      final url = items[i].thumbnailUrl;
      if (url == null || url.isEmpty) continue;
      precacheImage(CachedNetworkImageProvider(url), context);
    }
  }());
}

/// Single feed item with event logging for recommendation system.
class _ExploreFeedItem extends StatefulWidget {
  const _ExploreFeedItem({
    required this.item,
    required this.feedItems,
    required this.sessionId,
    required this.effectiveIsFollowing,
    required this.onFollowChanged,
  });

  final _ExploreVideoItem item;
  final List<_ExploreVideoItem> feedItems;
  final String sessionId;
  final bool effectiveIsFollowing;
  final void Function(String? posterUserId, bool isFollowing) onFollowChanged;

  @override
  State<_ExploreFeedItem> createState() => _ExploreFeedItemState();
}

class _ExploreFeedItemState extends State<_ExploreFeedItem> {
  String? _impressionId;
  VideoPlayerController? _seededControllerFromFeed;
  VideoPlayerController? _seededControllerFromPreload;

  @override
  void initState() {
    super.initState();
    _seededControllerFromPreload =
        _ExploreVideoPreloadCache.instance.take(widget.item.videoId);
  }

  @override
  void didUpdateWidget(covariant _ExploreFeedItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.videoId != widget.item.videoId) {
      _seededControllerFromPreload =
          _ExploreVideoPreloadCache.instance.take(widget.item.videoId);
    }
  }

  Future<void> _openContinuousFeed(VideoPlayerController? seededController) async {
    final videos = <LeagueVideoItem>[];
    for (final item in widget.feedItems) {
      if (item.videoUrl.isEmpty) continue;
      videos.add(
        LeagueVideoItem(
          videoId: item.videoId,
          videoUrl: item.videoUrl,
          thumbnailUrl: item.thumbnailUrl,
          durationSeconds: item.durationSeconds,
          teamAShort: item.teamAShort,
          teamBShort: item.teamBShort,
          teamALogo: item.teamALogo,
          teamBLogo: item.teamBLogo,
          teamAScore: item.teamAScore,
          teamBScore: item.teamBScore,
          matchStatus: item.statusText,
          uploaderName: item.uploaderName,
          uploaderAvatar: item.uploaderAvatar,
          uploaderUserId: item.uploaderUserId,
          isLiked: item.isLiked,
          isFollowing: item.isFollowing,
          isUploaderDeleted: item.isUploaderDeleted,
          likeCount: item.likeCount,
        ),
      );
    }
    if (videos.isEmpty) return;
    var initialIndex = videos.indexWhere((v) => v.videoId == widget.item.videoId);
    if (initialIndex < 0) initialIndex = 0;
    final handoff = await Navigator.of(context).push<VideoControllerHandoff>(
      MaterialPageRoute(
        builder: (_) => LeagueVideoPlayerPage(
          videos: videos,
          initialIndex: initialIndex,
          seededController: seededController,
          seededVideoId: widget.item.videoId,
        ),
      ),
    );
    if (!mounted || handoff == null) return;
    if (handoff.videoId == widget.item.videoId) {
      setState(() {
        _seededControllerFromFeed = handoff.controller;
      });
    }
  }

  void _openMatchDetails() {
    final matchId = widget.item.matchId;
    if (matchId == null || matchId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FixturePage(matchId: matchId)),
    );
  }

  void _openPosterProfile() {
    final posterId = widget.item.uploaderUserId;
    if (posterId == null || posterId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlayerProfilePage(playerId: posterId)),
    );
  }

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
          'p_watch_seconds': ?watchSeconds,
          'p_swiped_fast': ?swipedFast,
          'p_liked': ?liked,
          'p_shared': ?shared,
          'p_followed_uploader': ?followedUploader,
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
          onTap: _openMatchDetails,
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
          onSurfaceTap: _openContinuousFeed,
          seededController: _seededControllerFromFeed ?? _seededControllerFromPreload,
        ),
        _PosterInfoSection(
          videoId: widget.item.videoId,
          posterName: widget.item.uploaderName ?? 'Unknown',
          posterAvatar: widget.item.uploaderAvatar,
          posterUserId: widget.item.uploaderUserId,
          posterDeleted: widget.item.isUploaderDeleted,
          thumbnailUrl: widget.item.thumbnailUrl,
          shareLabel:
              '${widget.item.teamAShort} vs ${widget.item.teamBShort}',
          isLiked: widget.item.isLiked,
          likeCount: widget.item.likeCount,
          isFollowing: widget.effectiveIsFollowing,
          onFollowChanged: widget.onFollowChanged,
          onLiked: () => _updateInteraction(liked: true),
          onShared: () => _updateInteraction(shared: true),
          onFollowed: () => _updateInteraction(followedUploader: true),
          onPosterTap: _openPosterProfile,
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
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: Icon(
          Icons.groups,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          size: 36,
        ),
      );
    }
    return CircleAvatar(
      backgroundColor: Colors.transparent,
      child: ClipOval(
        child: SizedBox(
          width: 63,
          height: 63,
          child: buildTeamLogo(path, size: 63),
        ),
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
  final VoidCallback? onTap;

  const _MatchInfoCard({
    required this.team1,
    required this.team2,
    required this.league,
    required this.status,
    required this.result,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(28),
        topRight: Radius.circular(28),
      ),
      child: Container(
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
  final ValueChanged<VideoPlayerController?>? onSurfaceTap;
  final VideoPlayerController? seededController;

  const _VideoPlayerSection({
    this.videoUrl,
    this.thumbnailUrl,
    required this.videoId,
    this.durationSeconds = 0,
    this.onImpressionShown,
    this.onWatchEnded,
    this.onSurfaceTap,
    this.seededController,
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
            onSurfaceTap: onSurfaceTap,
            seededController: seededController,
          ),
        ),
      );
    }
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.5,
      child: thumbnailUrl != null && thumbnailUrl!.isNotEmpty
          ? Image(
              image: CachedNetworkImageProvider(thumbnailUrl!),
              fit: BoxFit.cover,
            )
          : Container(color: Colors.black),
    );
  }
}

String? _resolveImagePath(String? raw) => resolvePlayerImagePath(raw);

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
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      backgroundImage: hasImage
          ? (isNetwork
                ? CachedNetworkImageProvider(path) as ImageProvider
                : AssetImage(path))
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
        splashColor: Colors.red.withValues(alpha: 0.2),
        highlightColor: Colors.red.withValues(alpha: 0.1),
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
    this.posterDeleted = false,
    this.shareLabel,
    this.thumbnailUrl,
    required this.isLiked,
    required this.likeCount,
    required this.isFollowing,
    required this.onFollowChanged,
    this.onLiked,
    this.onShared,
    this.onFollowed,
    this.onPosterTap,
  });

  final String videoId;
  final String posterName;
  final String? posterAvatar;
  final String? posterUserId;
  final bool posterDeleted;
  final String? shareLabel;
  final String? thumbnailUrl;
  final bool isLiked;
  final int likeCount;
  final bool isFollowing;
  final void Function(String? posterUserId, bool isFollowing) onFollowChanged;
  final VoidCallback? onLiked;
  final VoidCallback? onShared;
  final VoidCallback? onFollowed;
  final VoidCallback? onPosterTap;

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
      !widget.posterDeleted &&
      widget.posterUserId != null &&
      widget.posterUserId!.isNotEmpty;

  Future<void> _toggleFollow() async {
    final client = Supabase.instance.client;
    final currentUser = client.auth.currentUser;
    if (currentUser == null || widget.posterUserId == null) return;
    if (currentUser.isAnonymous) {
      await showGuestAccountSheet(
        context,
        message: 'Create a free Ballo account to follow players and '
            'keep up with their highlights.',
      );
      return;
    }
    final currentUserId = currentUser.id;

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
    final currentUser = client.auth.currentUser;
    if (currentUser == null) return;
    if (currentUser.isAnonymous) {
      await showGuestAccountSheet(
        context,
        message:
            'Create a free Ballo account to like videos and support '
            'the players behind them.',
      );
      return;
    }
    final currentUserId = currentUser.id;

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
      padding: EdgeInsets.symmetric(
        horizontal: AppResponsive.horizontalInset(context),
        vertical: 12 * AppResponsive.layoutScaleOf(context),
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: widget.onPosterTap,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
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
                ],
              ),
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
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final outcome = await VideoShare.share(
                videoId: widget.videoId,
                matchLabel: widget.shareLabel,
                thumbnailUrl: widget.thumbnailUrl,
              );
              if (outcome == VideoShareOutcome.dismissed) return;
              widget.onShared?.call();
              if (outcome == VideoShareOutcome.copied) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Link copied')),
                );
              }
            },
            icon: Icon(
              Icons.share_outlined,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          if (!_isViewerPoster)
            IconButton(
              tooltip: 'Report',
              onPressed: () async {
                final user = Supabase.instance.client.auth.currentUser;
                if (user == null || user.isAnonymous) {
                  await showGuestAccountSheet(
                    context,
                    message:
                        'Create a free Ballo account to report content and '
                        'help keep the community safe.',
                  );
                  return;
                }
                await showReportContentSheet(
                  context,
                  videoId: widget.videoId,
                  uploaderUserId: widget.posterUserId,
                  uploaderName: widget.posterName,
                );
              },
              icon: Icon(
                Icons.flag_outlined,
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
  final ValueChanged<VideoPlayerController?>? onSurfaceTap;
  final VideoPlayerController? seededController;

  const _VideoPlayerWidget({
    required this.videoUrl,
    this.thumbnailUrl,
    this.videoId = '',
    this.durationSeconds = 0,
    this.onImpressionShown,
    this.onWatchEnded,
    this.onSurfaceTap,
    this.seededController,
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
  Timer? _disposeTimer;
  double _visibleFraction = 0.0;
  int _visibilityEventId = 0;

  final String _videoKey = 'video_${UniqueKey()}';

  @override
  bool get wantKeepAlive => false;

  @override
  void initState() {
    super.initState();
    final seeded = widget.seededController;
    if (seeded != null && seeded.value.isInitialized) {
      _controller = seeded;
      _isInitialized = true;
      _isPlaying = seeded.value.isPlaying;
    }
    // No eager initialization here: the controller is created lazily by the
    // VisibilityDetector callback once the card actually scrolls into view,
    // so off-screen videos never start buffering (saves mobile data).
  }

  @override
  void didUpdateWidget(covariant _VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final seeded = widget.seededController;
    if (seeded != null &&
        !identical(seeded, _controller) &&
        seeded.value.isInitialized) {
      _cancelScheduledDispose();
      _controller = seeded;
      _isInitialized = true;
      _isPlaying = seeded.value.isPlaying;
      if (_visibleFraction > 0.65) {
        _playVideo();
      }
      if (mounted) setState(() {});
    }
  }

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
    _cancelScheduledDispose();

    try {
      final controller = await createExploreVideoController(
        videoUrl: widget.videoUrl,
        videoId: widget.videoId,
        cacheManager: _ExploreVideoPreloadCache.instance.cacheManager,
      );

      await controller.initialize();
      await controller.setLooping(true);

      if (!mounted || _visibleFraction <= 0.01) {
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

  bool _controllerUsable(VideoPlayerController? controller) {
    if (controller == null || !_isInitialized) return false;
    try {
      return controller.value.isInitialized;
    } catch (_) {
      return false;
    }
  }

  void _playVideo() {
    final controller = _controller;
    if (!_controllerUsable(controller)) return;

    try {
      controller!.play();
      if (mounted) setState(() => _isPlaying = true);
    } catch (_) {
      _detachController(disposeNow: true);
    }
  }

  void _pauseVideo() {
    final controller = _controller;
    if (!_controllerUsable(controller)) return;

    try {
      controller!.pause();
      if (mounted) setState(() => _isPlaying = false);
    } catch (_) {
      _detachController(disposeNow: true);
    }
  }

  /// Detach [VideoPlayer] before dispose so listeners are not called on a
  /// disposed controller (common when scrolling Explore cards off-screen).
  void _detachController({
    bool disposeNow = false,
    bool handoff = false,
  }) {
    final controller = _controller;
    _controller = null;
    _isInitialized = false;
    _isPlaying = false;
    if (mounted) setState(() {});
    if (controller == null || handoff) return;

    void disposeController() {
      try {
        controller.dispose();
      } catch (_) {}
    }

    if (disposeNow) {
      disposeController();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => disposeController());
    }
  }

  void _scheduleDispose() {
    _disposeTimer?.cancel();
    _stopWatchTimerAndReport();
    _disposeTimer = Timer(const Duration(seconds: 2), () {
      if (_visibleFraction > 0.01) return;
      _detachController();
    });
  }

  void _cancelScheduledDispose() {
    _disposeTimer?.cancel();
    _disposeTimer = null;
  }

  void _handleSurfaceTap() {
    final callback = widget.onSurfaceTap;
    if (callback == null) return;

    final controller = _controller;
    if (_controllerUsable(controller)) {
      _cancelScheduledDispose();
      _watchTimer?.cancel();
      _watchTimer = null;
      _detachController(handoff: true);
      callback(controller);
      return;
    }

    callback(null);
  }

  @override
  void dispose() {
    _watchTimer?.cancel();
    _disposeTimer?.cancel();
    final controller = _controller;
    _controller = null;
    try {
      controller?.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = _controller;
    final showPlayer = _controllerUsable(controller);

    return VisibilityDetector(
      key: Key(_videoKey),
      onVisibilityChanged: (info) async {
        final visible = info.visibleFraction;
        _visibleFraction = visible;
        final eventId = ++_visibilityEventId;

        // Init and play only when most of the card is on screen. On cellular
        // we keep the thumbnail and wait for an explicit tap (Wi-Fi-only autoplay).
        if (visible > 0.65 && _controller == null) {
          final allowAutoplay = await NetworkQuality.allowsVideoAutoplay;
          if (!mounted || eventId != _visibilityEventId) return;
          if (_visibleFraction <= 0.65) {
            _pauseVideo();
            _scheduleDispose();
            return;
          }
          if (allowAutoplay) {
            _cancelScheduledDispose();
            await _initializeVideo();
            if (!mounted || eventId != _visibilityEventId) return;
            if (_visibleFraction <= 0.65) {
              _pauseVideo();
              _scheduleDispose();
              return;
            }
          }
        }

        if (visible > 0.65) {
          if (!_impressionLogged) {
            _impressionLogged = true;
            widget.onImpressionShown?.call();
          }
          _startWatchTimer();

          if (!mounted || eventId != _visibilityEventId) return;
          if (_visibleFraction <= 0.65) {
            _pauseVideo();
            _scheduleDispose();
            return;
          }

          _playVideo();
        } else {
          _pauseVideo();
          _scheduleDispose();
        }
      },
      child: ClipRect(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleSurfaceTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
            // Always show the thumbnail/placeholder; video overlays when ready.
            _buildPlaceholder(),

            if (showPlayer)
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller!.value.size.width,
                    height: controller.value.size.height,
                    child: VideoPlayer(controller),
                  ),
                ),
              ),
            if (!showPlayer)
              Center(
                child: GestureDetector(
                  onTap: () async {
                    await _initializeVideo();
                    if (mounted && _visibleFraction > 0.01) _playVideo();
                  },
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
            if (showPlayer)
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
                      color: Colors.black.withValues(alpha: 0.45),
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
      ),
    );
  }

  Widget _buildPlaceholder() {
    if (widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty) {
      return SizedBox.expand(
        child: Image(
          image: CachedNetworkImageProvider(widget.thumbnailUrl!),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.low,
          errorBuilder: (_, _, _) {
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
    required this.matchId,
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
    this.isUploaderDeleted = false,
  });

  final String videoId;
  final String? matchId;
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
  final bool isUploaderDeleted;
}

Future<List<_ExploreVideoItem>> _fetchExploreVideos(
  String sessionId, {
  required int limit,
  required int offset,
}) async {
  final client = Supabase.instance.client;
  final currentUserId = client.auth.currentUser?.id;

  List<Map<String, dynamic>> videos;
  try {
    final params = <String, dynamic>{
      'p_limit': limit,
      'p_offset': offset,
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
        .neq('moderation_status', 'rejected')
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    videos = List<Map<String, dynamic>>.from(fallbackRes as List);
  }
  if (videos.isEmpty) return const [];

  if (currentUserId != null) {
    try {
      final blocked = await client
          .from('user_blocks')
          .select('blocked_user_id')
          .eq('blocker_user_id', currentUserId);
      final blockedIds = {
        for (final row in List<Map<String, dynamic>>.from(blocked as List))
          if (row['blocked_user_id'] != null)
            row['blocked_user_id'].toString(),
      };
      if (blockedIds.isNotEmpty) {
        videos = videos.where((v) {
          final uid = v['uploader_user_id']?.toString() ??
              v['uploaderUserId']?.toString();
          // RPC shape uses uploader_user_id; mapped shape uses same later.
          final mapped = v['uploader_user_id']?.toString();
          final id = mapped ?? uid;
          return id == null || id.isEmpty || !blockedIds.contains(id);
        }).toList();
      }
    } catch (_) {}
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
        .select('id, player_name, image_url, deleted_at')
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

  // Aggregated like counts (one row per video) instead of the full likes table.
  final likedVideoIds = <String>{};
  final likeCountMap = <String, int>{};
  if (videoIds.isNotEmpty) {
    try {
      final likesRes = await client.rpc(
        'get_video_like_stats',
        params: {
          'p_video_ids': videoIds,
          'p_user_id': ?currentUserId,
        },
      );
      for (final l in List<Map<String, dynamic>>.from(likesRes as List)) {
        final vid = l['video_id']?.toString();
        if (vid == null) continue;
        likeCountMap[vid] = (l['like_count'] as num?)?.toInt() ?? 0;
        if (l['is_liked'] == true) likedVideoIds.add(vid);
      }
    } catch (_) {
      // Fallback if the RPC is not deployed yet: current user's likes only.
      if (currentUserId != null) {
        try {
          final mine = await client
              .from('video_likes')
              .select('video_id')
              .eq('user_id', currentUserId)
              .inFilter('video_id', videoIds);
          for (final l in List<Map<String, dynamic>>.from(mine as List)) {
            final vid = l['video_id']?.toString();
            if (vid != null) likedVideoIds.add(vid);
          }
        } catch (_) {}
      }
    }
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
    final isUploaderDeleted = uploader['deleted_at'] != null;

    return _ExploreVideoItem(
      videoId: vid,
      matchId: v['match_id']?.toString(),
      videoUrl: v['video_url']?.toString() ?? '',
      durationSeconds: v['duration_seconds'] as int?,
      teamALogo: _resolveLogoPath(teamA['logo_id']?.toString()) ?? '',
      teamBLogo: _resolveLogoPath(teamB['logo_id']?.toString()) ?? '',
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
      isFollowing: !isUploaderDeleted &&
          uploaderUserId != null &&
          followsSet.contains(uploaderUserId),
      isUploaderDeleted: isUploaderDeleted,
    );
  }).toList();
}

class ExploreSearchBar extends StatelessWidget {
  const ExploreSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppResponsive.horizontalInset(context),
      ),
      child: SearchBar(
        readOnly: true,
        padding: const WidgetStatePropertyAll<EdgeInsets>(
          EdgeInsets.symmetric(horizontal: 16.0),
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AppSearchPage()),
          );
        },
        leading: const Icon(Icons.search),
        hintText: 'Search...',
        hintStyle: WidgetStatePropertyAll(
          TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

String? _resolveLogoPath(String? logoId) => resolveTeamLogoPath(logoId);

class _ExploreVideoPreloadCache {
  _ExploreVideoPreloadCache._();
  static final _ExploreVideoPreloadCache instance = _ExploreVideoPreloadCache._();

  final Map<String, VideoPlayerController> _controllers = {};
  bool _isPreloading = false;

  VideoPlayerController? take(String videoId) {
    return _controllers.remove(videoId);
  }

  BaseCacheManager get cacheManager => AppVideoCache.instance.cacheManager;

  /// Drops leftover controllers. Thumbnails are precached separately;
  /// full MP4s are never downloaded until the card is actually watched.
  Future<void> preloadThumbnails(List<_ExploreVideoItem> items) async {
    if (_isPreloading) return;
    _isPreloading = true;
    try {
      for (final id in _controllers.keys.toList()) {
        await _controllers[id]?.dispose();
        _controllers.remove(id);
      }
    } finally {
      _isPreloading = false;
    }
  }
}
