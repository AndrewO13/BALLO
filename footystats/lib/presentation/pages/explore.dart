import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  @override
  void initState() {
    super.initState();
    _future = _fetchExploreVideos();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _fetchExploreVideos();
    });
    await _future;
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
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final playUrl = item.hlsUrl ?? item.videoUrl;
              return Column(
                children: [
                  _MatchInfoCard(
                    team1: {
                      'name': item.teamAShort,
                      'logo': item.teamALogo,
                      'score': item.teamAScore,
                    },
                    team2: {
                      'name': item.teamBShort,
                      'logo': item.teamBLogo,
                      'score': item.teamBScore,
                    },
                    league: item.leagueName,
                    status: item.statusText,
                    result: item.resultText,
                  ),
                  _VideoPlayerSection(
                    videoUrl: playUrl,
                    thumbnailUrl: item.thumbnailUrl,
                  ),
                  _PosterInfoSection(
                    posterName: item.uploaderName ?? 'Unknown',
                    posterAvatar: item.uploaderAvatar,
                  ),
                ],
              );
            },
          );
        },
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
  final String? videoUrl; // Video URL from backend (mp4 or HLS)
  final String? thumbnailUrl; // Optional thumbnail URL for faster loading

  const _VideoPlayerSection({this.videoUrl, this.thumbnailUrl});

  @override
  Widget build(BuildContext context) {
    if (videoUrl != null && videoUrl!.isNotEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 0),
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: const BoxDecoration(color: Colors.black),
        child: _VideoPlayerWidget(
          videoUrl: videoUrl!,
          thumbnailUrl: thumbnailUrl,
        ),
      );
    }
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
              const shareUrl = 'https://footystats.app';
              Clipboard.setData(const ClipboardData(text: shareUrl));
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

  const _VideoPlayerWidget({required this.videoUrl, this.thumbnailUrl});

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
  }

  Future<void> _initializeVideo() async {
    try {
      // Use network URL from backend (supabase public URL, ensure download param)
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );

      // OPTIMIZATION: Preload video for faster playback
      await _controller!.initialize();
      _controller!.setLooping(true);

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitialized = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not load video')));
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
        // When scrolled far away, stop and dispose to free resources.
        if (info.visibleFraction < 0.1) {
          _pauseVideo();
          _controller?.dispose();
          _controller = null;
          if (mounted) {
            setState(() {
              _isInitialized = false;
            });
          }
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
                ? Image.network(widget.thumbnailUrl!, fit: BoxFit.cover)
                : const Center(child: CircularProgressIndicator()),
          // Play / pause overlay
          Center(
            child: GestureDetector(
              onTap: () {
                if (!_isInitialized) {
                  _initializeVideo().then((_) {
                    if (mounted && _isInitialized) _playVideo();
                  });
                } else {
                  if (_isPlaying) {
                    _pauseVideo();
                  } else {
                    _playVideo();
                  }
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
                  _isInitialized && _isPlaying ? Icons.pause : Icons.play_arrow,
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

/// Combined view-model for an explore video row.
class _ExploreVideoItem {
  const _ExploreVideoItem({
    required this.videoId,
    required this.videoUrl,
    this.hlsUrl,
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
    this.thumbnailUrl,
  });

  final String videoId;
  final String videoUrl;
  final String? hlsUrl;
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
  final String? thumbnailUrl;
}

Future<List<_ExploreVideoItem>> _fetchExploreVideos() async {
  final client = Supabase.instance.client;

  final videosRes = await client
      .from('videos')
      .select(
        'id, match_id, uploader_user_id, duration_seconds, video_url, thumbnail_url, hls_url',
      )
      .order('created_at', ascending: false);

  final videos = List<Map<String, dynamic>>.from(videosRes as List);
  if (videos.isEmpty) return const [];

  final matchIds = <String>{};
  final uploaderIds = <String>{};
  for (final v in videos) {
    final mid = v['match_id']?.toString();
    if (mid != null && mid.isNotEmpty) matchIds.add(mid);
    final uid = v['uploader_user_id']?.toString();
    if (uid != null && uid.isNotEmpty) uploaderIds.add(uid);
  }

  final matchesMap = <String, Map<String, dynamic>>{};
  if (matchIds.isNotEmpty) {
    final matchesRes = await client
        .from('matches')
        .select('''
      id, status, teamA_score, teamB_score,
      league:leagues(league_name),
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

  return videos.map((v) {
    final match = matchesMap[v['match_id']?.toString()] ?? <String, dynamic>{};
    final league = match['league'] as Map<String, dynamic>? ?? {};
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

    return _ExploreVideoItem(
      videoId: v['id']?.toString() ?? '',
      videoUrl: v['video_url']?.toString() ?? '',
      hlsUrl: v['hls_url']?.toString(),
      durationSeconds: v['duration_seconds'] as int?,
      teamALogo: teamA['logo_id']?.toString() ?? AppAssets.theShieldLogo,
      teamBLogo: teamB['logo_id']?.toString() ?? AppAssets.laFamilleLogo,
      teamAShort: teamA['short_form']?.toString() ?? 'Team A',
      teamBShort: teamB['short_form']?.toString() ?? 'Team B',
      teamAScore: teamAScore,
      teamBScore: teamBScore,
      leagueName: league['league_name']?.toString() ?? 'League',
      statusText: status,
      resultText: result,
      uploaderName: uploader['player_name']?.toString(),
      uploaderAvatar: uploader['image_url']?.toString(),
      thumbnailUrl: v['thumbnail_url']?.toString(),
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
