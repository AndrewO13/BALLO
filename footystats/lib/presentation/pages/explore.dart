import 'package:flutter/material.dart';
import '../../core/constants/app_assets.dart';
// TODO: Uncomment when adding video support
// import 'package:video_player/video_player.dart';
// import 'package:visibility_detector/visibility_detector.dart';

class ExplorePage extends StatelessWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Single explore feed page (no tabs)
    return const _ExploreTabContent(title: 'For you');
  }
}

class _ExploreTabContent extends StatelessWidget {
  final String title;
  const _ExploreTabContent({required this.title});

  @override
  Widget build(BuildContext context) {
    // Sample match data - replace with actual data from backend
    // When backend is connected, videoUrl will be provided from API
    final matches = List.generate(
      3,
      (index) => {
        'team1': {
          'name': 'SHI',
          'logo': AppAssets.theShieldLogo,
          'score': 2,
        },
        'team2': {
          'name': 'LAF',
          'logo': AppAssets.laFamilleLogo,
          'score': 0,
        },
        'league': 'The Budo League',
        'status': 'Final',
        'result': 'The Shield wins!',
        'videoUrl':
            null, // Will be provided from backend: e.g., 'https://example.com/video.mp4'
        'thumbnailUrl': null, // Optional: thumbnail for faster loading
        'posterName': 'LukoFafa', // Name of person who posted
        'posterAvatar': null, // Optional: profile picture URL or asset path
      },
    );

    return ListView.builder(
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final match = matches[index];
        return Column(
          children: [
            _MatchInfoCard(
              team1: match['team1'] as Map<String, dynamic>,
              team2: match['team2'] as Map<String, dynamic>,
              league: match['league'] as String,
              status: match['status'] as String,
              result: match['result'] as String,
            ),
            _VideoPlayerSection(
              videoUrl: match['videoUrl'] as String?,
              thumbnailUrl: match['thumbnailUrl'] as String?,
            ),
            _PosterInfoSection(
              posterName: match['posterName'] as String,
              posterAvatar: match['posterAvatar'] as String?,
            ),
          ],
        );
      },
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
                      CircleAvatar(
                        radius: 31.5,
                        backgroundColor: Colors.transparent,
                        backgroundImage: AssetImage(team1['logo'] as String),
                      ),
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
                      CircleAvatar(
                        radius: 31.5,
                        backgroundColor: Colors.transparent,
                        backgroundImage: AssetImage(team2['logo'] as String),
                      ),
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
  final String? videoUrl; // Video URL from backend
  final String? thumbnailUrl; // Optional thumbnail URL for faster loading

  const _VideoPlayerSection({this.videoUrl, this.thumbnailUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: BoxDecoration(color: Colors.black),
      child: ClipRRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Placeholder image or video thumbnail
            Image.asset(
              thumbnailUrl ?? AppAssets.highlightPlaceholder,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Center(
                    child: Icon(
                      Icons.video_library_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
            // Play button overlay
            Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
            // TODO: When videoUrl is available, replace this with actual video player
            // Example implementation:
            // if (videoUrl != null)
            //   _VideoPlayerWidget(
            //     videoUrl: videoUrl!,
            //     thumbnailUrl: thumbnailUrl,
            //   )
            // else
            //   [current placeholder implementation]
          ],
        ),
      ),
    );
  }
}

/// Poster info section with profile, follow button, like and share buttons
class _PosterInfoSection extends StatefulWidget {
  final String posterName;
  final String? posterAvatar;

  const _PosterInfoSection({required this.posterName, this.posterAvatar});

  @override
  State<_PosterInfoSection> createState() => _PosterInfoSectionState();
}

class _PosterInfoSectionState extends State<_PosterInfoSection> {
  bool _isFollowing = false;
  bool _isLiked = false;

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
          // Profile icon
          CircleAvatar(
            radius: 12,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            backgroundImage: widget.posterAvatar != null
                ? AssetImage(widget.posterAvatar!)
                : null,
            child: widget.posterAvatar == null
                ? Text(
                    widget.posterName.isNotEmpty
                        ? widget.posterName[0].toUpperCase()
                        : '?',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          // Poster name
          Text(
            widget.posterName,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 16),
          // Follow button
          OutlinedButton(
            onPressed: () {
              setState(() {
                _isFollowing = !_isFollowing;
              });
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              side: BorderSide(color: Theme.of(context).colorScheme.outline),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              _isFollowing ? 'Following' : 'Follow',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          // Spacer to push like and share buttons to the right
          const Spacer(),
          const SizedBox(width: 8),
          // Like button
          IconButton(
            onPressed: () {
              setState(() {
                _isLiked = !_isLiked;
              });
            },
            icon: Icon(
              _isLiked ? Icons.favorite : Icons.favorite_border,
              color: _isLiked
                  ? Colors.red
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          // Share button
          IconButton(
            onPressed: () {
              // TODO: Implement share functionality
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

// TODO: Uncomment and implement when backend provides video URLs
// This widget will handle video playback with optimizations
/*
class _VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;

  const _VideoPlayerWidget({
    required this.videoUrl,
    this.thumbnailUrl,
  });

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  final String _videoKey = 'video_${DateTime.now().millisecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    // Use network URL from backend
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    
    // OPTIMIZATION: Preload video for faster playback
    await _controller!.initialize();
    _controller!.setLooping(true);
    
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _playVideo() {
    if (_controller != null && _isInitialized) {
      _controller!.play();
      setState(() {
        _isPlaying = true;
      });
    }
  }

  void _pauseVideo() {
    if (_controller != null && _isInitialized) {
      _controller!.pause();
      setState(() {
        _isPlaying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key(_videoKey),
      onVisibilityChanged: (VisibilityInfo info) {
        // Play when more than 50% visible, pause otherwise (Instagram-like)
        if (info.visibleFraction > 0.5) {
          _playVideo();
        } else {
          _pauseVideo();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_isInitialized && _controller != null)
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            )
          else
            // Show thumbnail while loading
            widget.thumbnailUrl != null
                ? Image.network(
                    widget.thumbnailUrl!,
                    fit: BoxFit.cover,
                  )
                : const Center(
                    child: CircularProgressIndicator(),
                  ),
          // Play/Pause overlay
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
                    color: Colors.black.withOpacity(0.5),
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
    );
  }
}
*/

class ExploreSearchBar extends StatefulWidget {
  const ExploreSearchBar({super.key});

  @override
  State<ExploreSearchBar> createState() => _ExploreSearchBarState();
}

class _ExploreSearchBarState extends State<ExploreSearchBar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: SearchAnchor(
        builder: (BuildContext context, SearchController controller) {
          return SearchBar(
            controller: controller,
            padding: const WidgetStatePropertyAll<EdgeInsets>(
              EdgeInsets.symmetric(horizontal: 16.0),
            ),
            onTap: () {
              controller.openView();
            },
            onChanged: (_) {
              controller.openView();
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
              // TODO: Replace with actual search suggestions
              return List<ListTile>.generate(5, (int index) {
                final String item = 'item $index';
                return ListTile(
                  title: Text(item),
                  onTap: () {
                    setState(() {
                      controller.closeView(item);
                    });
                  },
                );
              });
            },
      ),
    );
  }
}
