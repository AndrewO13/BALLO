import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/match_model.dart';
import '../providers/matches_provider.dart';
import '../providers/match_video_seen_provider.dart';
import 'league_video_player_page.dart';

/// Opens match clips in upload order with story-style vertical swipes.
Future<void> openMatchVideosPlayer(
  BuildContext context,
  MatchModel match,
) {
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      fullscreenDialog: true,
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) {
        return MatchVideosPlayerPage(match: match);
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

/// Loads a match's videos, then plays them full-screen in `created_at` order.
class MatchVideosPlayerPage extends ConsumerStatefulWidget {
  const MatchVideosPlayerPage({super.key, required this.match});

  final MatchModel match;

  @override
  ConsumerState<MatchVideosPlayerPage> createState() =>
      _MatchVideosPlayerPageState();
}

class _MatchVideosPlayerPageState extends ConsumerState<MatchVideosPlayerPage> {
  List<LeagueVideoItem>? _videos;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final clips = await ref.read(matchVideosProvider(widget.match.id).future);
      if (!mounted) return;
      final match = widget.match;
      final items = <LeagueVideoItem>[
        for (final clip in clips)
          if (clip.videoUrl.isNotEmpty)
            LeagueVideoItem(
              videoId: clip.id.isNotEmpty ? clip.id : clip.videoUrl,
              videoUrl: clip.videoUrl,
              thumbnailUrl: clip.thumbnailUrl,
              durationSeconds: clip.durationSeconds,
              createdAt: clip.createdAt,
              teamAShort: match.teamA.shortForm,
              teamBShort: match.teamB.shortForm,
              teamALogo: match.teamA.logoPath,
              teamBLogo: match.teamB.logoPath,
              teamAScore: match.teamAScore ?? 0,
              teamBScore: match.teamBScore ?? 0,
              matchStatus: match.statusText,
              uploaderName: clip.uploaderName,
              uploaderAvatar: clip.uploaderImageUrl,
              uploaderUserId: clip.uploaderUserId,
            ),
      ];
      setState(() => _videos = items);
      if (items.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop();
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final videos = _videos;
    if (videos != null && videos.isNotEmpty) {
      return LeagueVideoPlayerPage(
        videos: videos,
        initialIndex: 0,
        storyStyleSwipe: true,
        onVideoViewed: (videoId) {
          ref.read(matchVideoSeenProvider.notifier).markWatched({videoId});
        },
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          color: Colors.white,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: _error == null
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                'Could not load videos',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
