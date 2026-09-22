import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import '../../core/utils/app_video_cache.dart';
import '../../core/utils/explore_video_controller.dart';
import '../../core/utils/share_boot_overlay.dart';
import '../../core/utils/video_share.dart';
import '../../core/widgets/media_placeholders.dart';
import '../widgets/content_safety_sheets.dart';
import '../widgets/guest_account_sheet.dart';

class LeagueVideoItem {
  const LeagueVideoItem({
    required this.videoId,
    required this.videoUrl,
    this.thumbnailUrl,
    this.durationSeconds,
    this.createdAt,
    required this.teamAShort,
    required this.teamBShort,
    required this.teamALogo,
    required this.teamBLogo,
    required this.teamAScore,
    required this.teamBScore,
    required this.matchStatus,
    this.uploaderName,
    this.uploaderAvatar,
    this.uploaderUserId,
    this.isLiked = false,
    this.isFollowing = false,
    this.isUploaderDeleted = false,
    this.likeCount = 0,
    this.viewCount = 0,
  });

  final String videoId;
  final String videoUrl;
  final String? thumbnailUrl;
  final int? durationSeconds;
  final DateTime? createdAt;
  final String teamAShort, teamBShort;
  final String teamALogo, teamBLogo;
  final int teamAScore, teamBScore;
  final String matchStatus;
  final String? uploaderName, uploaderAvatar, uploaderUserId;
  final bool isLiked, isFollowing, isUploaderDeleted;
  final int likeCount, viewCount;
}

class VideoControllerHandoff {
  const VideoControllerHandoff({
    required this.videoId,
    required this.controller,
  });

  final String videoId;
  final VideoPlayerController controller;
}

class LeagueVideoPlayerPage extends StatefulWidget {
  const LeagueVideoPlayerPage({
    super.key,
    required this.videos,
    required this.initialIndex,
    this.seededController,
    this.seededVideoId,
    this.storyStyleSwipe = false,
    this.onVideoViewed,
  });

  final List<LeagueVideoItem> videos;
  final int initialIndex;
  final VideoPlayerController? seededController;
  final String? seededVideoId;

  /// Swipe up for the next clip; swipe down on the first clip closes
  /// the player with a slide-off animation.
  final bool storyStyleSwipe;

  /// Called when a clip becomes the current full-screen video.
  final ValueChanged<String>? onVideoViewed;

  @override
  State<LeagueVideoPlayerPage> createState() => _LeagueVideoPlayerPageState();
}

class _LeagueVideoPlayerPageState extends State<LeagueVideoPlayerPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;
  final Map<int, VideoPlayerController> _controllers = {};
  final Map<int, bool> _initialized = {};
  VideoPlayerController? _handoffController;
  bool _popHandled = false;
  bool _isPageActive = true;
  late final AnimationController _dismissController;
  int? _dismissPointer;
  double _dismissPointerStartDy = 0;
  bool _trackingDismiss = false;
  bool _isDismissing = false;

  bool get _storyStyleSwipe => widget.storyStyleSwipe;

  double get _dismissOffset => _dismissController.value;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dismissController = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        if (mounted) setState(() {});
      });
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    final initialVideo = widget.videos[_currentIndex];
    final seeded = widget.seededController;
    if (seeded != null &&
        widget.seededVideoId != null &&
        widget.seededVideoId == initialVideo.videoId &&
        seeded.value.isInitialized) {
      _controllers[_currentIndex] = seeded;
      _initialized[_currentIndex] = true;
      seeded.setLooping(true);
      seeded.play();
    } else {
      _initController(_currentIndex);
    }
    _preloadNeighbours(_currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyVideoViewed(_currentIndex);
    });
  }

  @override
  void dispose() {
    _isPageActive = false;
    _pauseAllControllers();
    WidgetsBinding.instance.removeObserver(this);
    _dismissController.dispose();
    _pageController.dispose();
    for (final c in _controllers.values) {
      if (identical(c, _handoffController)) continue;
      c.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _pauseAllControllers();
    }
  }

  VideoControllerHandoff? _buildHandoff() {
    final index = _currentIndex;
    final controller = _controllers[index];
    if (controller == null || !(_initialized[index] ?? false)) return null;
    final item = widget.videos[index];
    _handoffController = controller;
    return VideoControllerHandoff(
      videoId: item.videoId,
      controller: controller,
    );
  }

  Future<bool> _handleBackNavigation() async {
    if (_storyStyleSwipe) {
      await _runDismissAnimation();
      return false;
    }
    return _popNow();
  }

  Future<bool> _popNow() async {
    if (_popHandled) return false;
    _popHandled = true;
    _pauseAllControllers();
    if (!mounted) return false;
    Navigator.of(context).pop(_buildHandoff());
    return false;
  }

  Future<void> _runDismissAnimation() async {
    if (_popHandled) return;
    if (_isDismissing) return;
    _isDismissing = true;
    _pauseAllControllers();
    final height = MediaQuery.sizeOf(context).height;
    try {
      await _dismissController.animateTo(
        height,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeIn,
      );
    } catch (_) {}
    if (!mounted) return;
    await _popNow();
  }

  void _snapDismissBack() {
    _dismissController.animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
  }

  bool get _canStartDismiss =>
      _storyStyleSwipe && _currentIndex == 0 && !_isDismissing && !_popHandled;

  void _onDismissPointerDown(PointerDownEvent event) {
    if (!_canStartDismiss) return;
    if (_dismissPointer != null) return;
    _dismissPointer = event.pointer;
    _dismissPointerStartDy = event.position.dy;
    _trackingDismiss = false;
  }

  void _onDismissPointerMove(PointerMoveEvent event) {
    if (event.pointer != _dismissPointer) return;
    final dy = event.position.dy - _dismissPointerStartDy;
    if (!_trackingDismiss) {
      if (dy < -10) {
        _dismissPointer = null;
        return;
      }
      if (dy < 10) return;
      _trackingDismiss = true;
      _dismissController.stop();
    }
    final offset = dy.clamp(0.0, MediaQuery.sizeOf(context).height);
    _dismissController.value = offset;
  }

  void _onDismissPointerEnd(PointerEvent event) {
    if (event.pointer != _dismissPointer) return;
    _dismissPointer = null;
    if (!_trackingDismiss) return;
    _trackingDismiss = false;
    final threshold = MediaQuery.sizeOf(context).height * 0.16;
    if (_dismissOffset > threshold) {
      unawaited(_runDismissAnimation());
    } else {
      _snapDismissBack();
    }
  }

  Future<void> _initController(int index) async {
    if (index < 0 || index >= widget.videos.length) return;
    if (_controllers.containsKey(index)) return;
    // The HTML share player is already streaming this clip. Starting a second
    // download here fights it for bandwidth and restarts playback from zero.
    if (kIsWeb && shareBootHasVideo()) {
      return;
    }
    final item = widget.videos[index];
    final url = item.videoUrl;
    if (url.isEmpty) return;
    // Plays from the shared disk cache when the clip was downloaded before;
    // otherwise streams from the network.
    final controller = await createExploreVideoController(
      videoUrl: url,
      videoId: item.videoId.isNotEmpty ? item.videoId : url,
      cacheManager: AppVideoCache.instance.cacheManager,
    );
    if (_controllers.containsKey(index)) {
      await controller.dispose();
      return;
    }
    _controllers[index] = controller;
    try {
      await controller.initialize();
      if (!_isPageActive || !mounted) {
        if (!identical(_handoffController, controller)) {
          await controller.dispose();
        }
        _controllers.remove(index);
        _initialized.remove(index);
        return;
      }
      await controller.setLooping(true);
      if (_isPageActive && mounted && index == _currentIndex) {
        await controller.play();
      }
      if (mounted) {
        removeShareBootOverlay();
        setState(() => _initialized[index] = true);
      }
    } catch (_) {
      removeShareBootOverlay();
    }
  }

  /// Warm neighbour thumbnails without touching [BuildContext], which avoids
  /// inherited-widget dependency errors during page transitions.
  void _preloadNeighbours(int index) {
    for (final i in [index - 1, index + 1]) {
      if (i < 0 || i >= widget.videos.length) continue;
      final thumb = widget.videos[i].thumbnailUrl;
      if (thumb == null || thumb.isEmpty) continue;
      unawaited(_preloadThumbnailUrl(thumb));
    }
  }

  void _disposeDistant(int index) {
    final toRemove = <int>[];
    for (final key in _controllers.keys) {
      if ((key - index).abs() > 2) toRemove.add(key);
    }
    for (final key in toRemove) {
      _controllers[key]?.dispose();
      _controllers.remove(key);
      _initialized.remove(key);
    }
  }

  void _notifyVideoViewed(int index) {
    final callback = widget.onVideoViewed;
    if (callback == null) return;
    if (index < 0 || index >= widget.videos.length) return;
    final id = widget.videos[index].videoId;
    if (id.isEmpty) return;
    callback(id);
  }

  void _onPageChanged(int index) {
    if (!_isPageActive) return;
    _controllers[_currentIndex]?.pause();
    setState(() => _currentIndex = index);
    final c = _controllers[index];
    if (c != null && (_initialized[index] ?? false)) {
      c.play();
    } else {
      _initController(index);
    }
    _preloadNeighbours(index);
    _disposeDistant(index);
    _notifyVideoViewed(index);
  }

  void _pauseAllControllers() {
    for (final controller in _controllers.values) {
      if (controller.value.isInitialized && controller.value.isPlaying) {
        controller.pause();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final dismissProgress =
        height <= 0 ? 0.0 : (_dismissOffset / height).clamp(0.0, 1.0);
    final pageView = PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      physics: !_storyStyleSwipe
          ? null
          : (_trackingDismiss || _isDismissing || _dismissOffset > 0)
              ? const NeverScrollableScrollPhysics()
              : const ClampingScrollPhysics(),
      itemCount: widget.videos.length,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        return _VideoPage(
          item: widget.videos[index],
          controller: _controllers[index],
          isInitialized: _initialized[index] ?? false,
          isCurrent: index == _currentIndex,
          onTogglePlay: () {
            final c = _controllers[index];
            if (c == null) return;
            if (c.value.isPlaying) {
              c.pause();
            } else {
              c.play();
            }
            setState(() {});
          },
        );
      },
    );

    final scaffold = Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          color: Colors.white,
          // Chevron on iOS, arrow elsewhere (adapts via theme platform).
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _handleBackNavigation(),
        ),
      ),
      body: pageView,
    );

    Widget child = scaffold;
    if (_storyStyleSwipe) {
      child = Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onDismissPointerDown,
        onPointerMove: _onDismissPointerMove,
        onPointerUp: _onDismissPointerEnd,
        onPointerCancel: _onDismissPointerEnd,
        child: Transform.translate(
          offset: Offset(0, _dismissOffset),
          child: Opacity(
            opacity: (1 - dismissProgress * 0.35).clamp(0.4, 1),
            child: scaffold,
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_handleBackNavigation());
      },
      child: child,
    );
  }
}

Future<void> _preloadThumbnailUrl(String url) async {
  final provider = appCachedImageProvider(url);
  final stream = provider.resolve(const ImageConfiguration());
  final completer = Completer<void>();
  late ImageStreamListener listener;
  listener = ImageStreamListener(
    (ImageInfo _, bool _) {
      stream.removeListener(listener);
      if (!completer.isCompleted) completer.complete();
    },
    onError: (Object error, StackTrace? stackTrace) {
      stream.removeListener(listener);
      if (!completer.isCompleted) completer.complete();
    },
  );
  stream.addListener(listener);
  await completer.future;
}

class _VideoPage extends StatefulWidget {
  const _VideoPage({
    required this.item,
    required this.controller,
    required this.isInitialized,
    required this.isCurrent,
    required this.onTogglePlay,
  });

  final LeagueVideoItem item;
  final VideoPlayerController? controller;
  final bool isInitialized;
  final bool isCurrent;
  final VoidCallback onTogglePlay;

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  late bool _isLiked;
  late int _likeCount;
  late bool _isFollowing;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.item.isLiked;
    _likeCount = widget.item.likeCount;
    _isFollowing = widget.item.isFollowing;
  }

  bool get _isViewerPoster {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    return uid != null && uid == widget.item.uploaderUserId;
  }

  Future<void> _toggleLike() async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });
    try {
      if (_isLiked) {
        await client.from('video_likes').insert({
          'video_id': widget.item.videoId,
          'user_id': uid,
        });
      } else {
        await client
            .from('video_likes')
            .delete()
            .eq('video_id', widget.item.videoId)
            .eq('user_id', uid);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLiked = !_isLiked;
        _likeCount += _isLiked ? 1 : -1;
      });
    }
  }

  Future<void> _toggleFollow() async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null || widget.item.uploaderUserId == null) return;
    final newVal = !_isFollowing;
    setState(() => _isFollowing = newVal);
    try {
      if (newVal) {
        await client.from('user_follows').insert({
          'follower_user_id': uid,
          'following_user_id': widget.item.uploaderUserId,
        });
      } else {
        await client
            .from('user_follows')
            .delete()
            .eq('follower_user_id', uid)
            .eq('following_user_id', widget.item.uploaderUserId!);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isFollowing = !newVal);
    }
  }

  Future<void> _share() async {
    final item = widget.item;
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await VideoShare.share(
      videoId: item.videoId,
      matchLabel: '${item.teamAShort} vs ${item.teamBShort}',
      thumbnailUrl: item.thumbnailUrl,
    );
    if (!mounted || outcome == VideoShareOutcome.dismissed) return;
    if (outcome == VideoShareOutcome.copied) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Link copied')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying =
        widget.controller != null && widget.controller!.value.isPlaying;

    return GestureDetector(
      onTap: widget.onTogglePlay,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video or thumbnail
          if (widget.isInitialized && widget.controller != null)
            Center(
              child: AspectRatio(
                aspectRatio: widget.controller!.value.aspectRatio,
                child: VideoPlayer(widget.controller!),
              ),
            )
          else
            _buildThumbnail(),

          // Play/pause indicator
          if (!isPlaying && widget.isCurrent)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),

          // Top overlay: match info
          Positioned(
            top: MediaQuery.of(context).padding.top + 48,
            left: 16,
            right: 72,
            child: _MatchOverlay(item: widget.item),
          ),

          // Right-side action buttons
          Positioned(
            right: 12,
            bottom: MediaQuery.of(context).padding.bottom + 100,
            child: _ActionColumn(
              isLiked: _isLiked,
              likeCount: _likeCount,
              isFollowing: _isFollowing,
              showFollow:
                  !_isViewerPoster &&
                  !widget.item.isUploaderDeleted &&
                  widget.item.uploaderUserId != null &&
                  widget.item.uploaderUserId!.isNotEmpty,
              showReport: !_isViewerPoster,
              onLike: _toggleLike,
              onFollow: _toggleFollow,
              onShare: _share,
              onReport: () async {
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
                  videoId: widget.item.videoId,
                  uploaderUserId: widget.item.uploaderUserId,
                  uploaderName: widget.item.uploaderName,
                );
              },
            ),
          ),

          // Bottom overlay: uploader info
          Positioned(
            left: 16,
            right: 72,
            bottom: MediaQuery.of(context).padding.bottom + 24,
            child: _UploaderOverlay(item: widget.item),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail() {
    final url = widget.item.thumbnailUrl;
    if (url != null && url.isNotEmpty) {
      return Image(
        image: appCachedImageProvider(url),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => Container(color: Colors.black),
      );
    }
    return Container(
      color: Colors.black,
      child: const Center(
        child: Icon(Icons.play_circle_outline, size: 64, color: Colors.white38),
      ),
    );
  }
}

class _MatchOverlay extends StatelessWidget {
  const _MatchOverlay({required this.item});
  final LeagueVideoItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _OverlayLogo(logoId: item.teamALogo, size: 24),
          const SizedBox(width: 6),
          Text(
            item.teamAShort,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${item.teamAScore} - ${item.teamBScore}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            item.teamBShort,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 6),
          _OverlayLogo(logoId: item.teamBLogo, size: 24),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              item.matchStatus,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionColumn extends StatelessWidget {
  const _ActionColumn({
    required this.isLiked,
    required this.likeCount,
    required this.isFollowing,
    required this.showFollow,
    required this.showReport,
    required this.onLike,
    required this.onFollow,
    required this.onShare,
    required this.onReport,
  });

  final bool isLiked;
  final int likeCount;
  final bool isFollowing;
  final bool showFollow;
  final bool showReport;
  final VoidCallback onLike;
  final VoidCallback onFollow;
  final VoidCallback onShare;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(
          icon: isLiked ? Icons.favorite : Icons.favorite_border,
          label: likeCount > 0 ? '$likeCount' : 'Like',
          color: isLiked ? Colors.red : Colors.white,
          onTap: onLike,
        ),
        const SizedBox(height: 20),
        _ActionButton(
          icon: Icons.share_outlined,
          label: 'Share',
          color: Colors.white,
          onTap: onShare,
        ),
        if (showReport) ...[
          const SizedBox(height: 20),
          _ActionButton(
            icon: Icons.flag_outlined,
            label: 'Report',
            color: Colors.white,
            onTap: onReport,
          ),
        ],
        if (showFollow) ...[
          const SizedBox(height: 20),
          _ActionButton(
            icon: isFollowing
                ? Icons.person_remove_outlined
                : Icons.person_add_alt,
            label: isFollowing ? 'Unfollow' : 'Follow',
            color: Colors.white,
            onTap: onFollow,
          ),
        ],
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black38,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
    );
  }
}

class _UploaderOverlay extends StatelessWidget {
  const _UploaderOverlay({required this.item});
  final LeagueVideoItem item;

  @override
  Widget build(BuildContext context) {
    final name = item.uploaderName ?? 'Unknown';
    final avatar = item.uploaderAvatar;
    final hasAvatar = avatar != null && avatar.isNotEmpty;
    final isNetwork =
        hasAvatar &&
        (avatar.startsWith('http://') || avatar.startsWith('https://'));

    return Row(
      children: [
        CircleAvatar(
          backgroundColor: Colors.white24,
          backgroundImage: hasAvatar
              ? (isNetwork ? appCachedImageProvider(avatar) : AssetImage(avatar))
              : null,
          child: !hasAvatar
              ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                )
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _OverlayLogo extends StatelessWidget {
  const _OverlayLogo({required this.logoId, this.size = 24});
  final String logoId;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: buildTeamLogo(
          resolveTeamLogoPath(logoId) ??
              (logoId.startsWith('lib/assets/') || logoId.startsWith('assets/')
                  ? logoId
                  : null),
          size: size,
          placeholderIconColor: Colors.white54,
        ),
      ),
    );
  }
}
