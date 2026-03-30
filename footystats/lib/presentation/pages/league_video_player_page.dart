import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import '../../core/constants/app_assets.dart';

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
  final bool isLiked, isFollowing;
  final int likeCount, viewCount;
}

class LeagueVideoPlayerPage extends StatefulWidget {
  const LeagueVideoPlayerPage({
    super.key,
    required this.videos,
    required this.initialIndex,
  });

  final List<LeagueVideoItem> videos;
  final int initialIndex;

  @override
  State<LeagueVideoPlayerPage> createState() => _LeagueVideoPlayerPageState();
}

class _LeagueVideoPlayerPageState extends State<LeagueVideoPlayerPage> {
  late PageController _pageController;
  late int _currentIndex;
  final Map<int, VideoPlayerController> _controllers = {};
  final Map<int, bool> _initialized = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _initController(_currentIndex);
    _preloadNeighbours(_currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _initController(int index) async {
    if (index < 0 || index >= widget.videos.length) return;
    if (_controllers.containsKey(index)) return;
    final url = widget.videos[index].videoUrl;
    if (url.isEmpty) return;
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controllers[index] = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      if (mounted && index == _currentIndex) {
        await controller.play();
      }
      if (mounted) setState(() => _initialized[index] = true);
    } catch (_) {}
  }

  void _preloadNeighbours(int index) {
    if (index + 1 < widget.videos.length) _initController(index + 1);
    if (index - 1 >= 0) _initController(index - 1);
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

  void _onPageChanged(int index) {
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
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
      ),
    );
  }
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

  void _share() {
    const shareUrl = 'https://footystats.app';
    Clipboard.setData(const ClipboardData(text: shareUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share link copied')),
    );
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
              showFollow: !_isViewerPoster &&
                  widget.item.uploaderUserId != null &&
                  widget.item.uploaderUserId!.isNotEmpty,
              onLike: _toggleLike,
              onFollow: _toggleFollow,
              onShare: _share,
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
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => Container(color: Colors.black),
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
    required this.onLike,
    required this.onFollow,
    required this.onShare,
  });

  final bool isLiked;
  final int likeCount;
  final bool isFollowing;
  final bool showFollow;
  final VoidCallback onLike;
  final VoidCallback onFollow;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Like
        _ActionButton(
          icon: isLiked ? Icons.favorite : Icons.favorite_border,
          label: likeCount > 0 ? '$likeCount' : 'Like',
          color: isLiked ? Colors.red : Colors.white,
          onTap: onLike,
        ),
        const SizedBox(height: 20),
        // Share
        _ActionButton(
          icon: Icons.share_outlined,
          label: 'Share',
          color: Colors.white,
          onTap: onShare,
        ),
        if (showFollow) ...[
          const SizedBox(height: 20),
          _ActionButton(
            icon:
                isFollowing ? Icons.person_remove_outlined : Icons.person_add_alt,
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
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11),
          ),
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
        hasAvatar && (avatar.startsWith('http://') || avatar.startsWith('https://'));

    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.white24,
          backgroundImage:
              hasAvatar ? (isNetwork ? NetworkImage(avatar) : null) : null,
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
    if (logoId.isEmpty) {
      return Icon(Icons.groups, size: size, color: Colors.white54);
    }
    final isNetwork =
        logoId.startsWith('http://') || logoId.startsWith('https://');
    final path = isNetwork
        ? logoId
        : (logoId.startsWith('lib/assets/') || logoId.startsWith('assets/'))
            ? logoId
            : '${AppAssets.teamLogosPath}${logoId.contains('.') ? logoId : '$logoId.png'}';

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: isNetwork
            ? Image.network(path, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.groups, size: size * 0.7, color: Colors.white54))
            : Image.asset(path, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.groups, size: size * 0.7, color: Colors.white54)),
      ),
    );
  }
}
