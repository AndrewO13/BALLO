import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/share_boot_overlay.dart';
import '../../core/widgets/app_error_state.dart';
import '../../core/widgets/media_placeholders.dart';
import 'league_video_player_page.dart';

/// Opens a shared highlight by `videos.id`. The file is not copied; this
/// page loads the existing row and streams the original object.
class SharedVideoPage extends StatefulWidget {
  const SharedVideoPage({super.key, required this.videoId});

  final String videoId;

  @override
  State<SharedVideoPage> createState() => _SharedVideoPageState();
}

class _SharedVideoPageState extends State<SharedVideoPage> {
  LeagueVideoItem? _item;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    try {
      final client = Supabase.instance.client;
      final videoRes = await client
          .from('videos')
          .select(
            'id, match_id, uploader_user_id, duration_seconds, video_url, thumbnail_url',
          )
          .eq('id', widget.videoId)
          .maybeSingle();
      if (!mounted) return;

      final videoUrl = videoRes?['video_url']?.toString() ?? '';
      if (videoRes == null || videoUrl.isEmpty) {
        setState(() {
          _item = null;
          _loading = false;
        });
        return;
      }

      final item = LeagueVideoItem(
        videoId: videoRes['id']?.toString() ?? widget.videoId,
        videoUrl: videoUrl,
        thumbnailUrl: videoRes['thumbnail_url']?.toString(),
        durationSeconds: videoRes['duration_seconds'] as int?,
        teamAShort: 'Team A',
        teamBShort: 'Team B',
        teamALogo: '',
        teamBLogo: '',
        teamAScore: 0,
        teamBScore: 0,
        matchStatus: '',
        uploaderUserId: videoRes['uploader_user_id']?.toString(),
      );
      setState(() {
        _item = item;
        _loading = false;
      });
      unawaited(_enrich(item, videoRes));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _item = null;
        _loading = false;
      });
    }
  }

  Future<void> _enrich(
    LeagueVideoItem item,
    Map<String, dynamic> videoRes,
  ) async {
    final client = Supabase.instance.client;
    Map<String, dynamic> match = {};
    Map<String, dynamic> uploader = {};

    final matchId = videoRes['match_id']?.toString();
    final uploaderId = videoRes['uploader_user_id']?.toString();

    final matchFuture = (matchId != null && matchId.isNotEmpty)
        ? client
            .from('matches')
            .select('''
              id, status, teamA_score, teamB_score,
              teamA:teams!teamA(id, logo_id, short_form),
              teamB:teams!teamB(id, logo_id, short_form)
            ''')
            .eq('id', matchId)
            .maybeSingle()
        : Future<Map<String, dynamic>?>.value(null);

    final uploaderFuture = (uploaderId != null && uploaderId.isNotEmpty)
        ? client
            .from('players')
            .select('id, player_name, image_url, deleted_at')
            .eq('id', uploaderId)
            .maybeSingle()
        : Future<Map<String, dynamic>?>.value(null);

    try {
      final results = await Future.wait([matchFuture, uploaderFuture]);
      final matchRes = results[0];
      final uploaderRes = results[1];
      if (matchRes != null) match = Map<String, dynamic>.from(matchRes);
      if (uploaderRes != null) {
        uploader = Map<String, dynamic>.from(uploaderRes);
      }
    } catch (_) {}

    if (!mounted) return;

    final teamA = match['teamA'] as Map<String, dynamic>? ?? {};
    final teamB = match['teamB'] as Map<String, dynamic>? ?? {};
    final teamAScore = match['teamA_score'] is int
        ? match['teamA_score'] as int
        : int.tryParse(match['teamA_score']?.toString() ?? '0') ?? 0;
    final teamBScore = match['teamB_score'] is int
        ? match['teamB_score'] as int
        : int.tryParse(match['teamB_score']?.toString() ?? '0') ?? 0;

    setState(() {
      _item = LeagueVideoItem(
        videoId: item.videoId,
        videoUrl: item.videoUrl,
        thumbnailUrl: item.thumbnailUrl,
        durationSeconds: item.durationSeconds,
        teamAShort: teamA['short_form']?.toString() ?? item.teamAShort,
        teamBShort: teamB['short_form']?.toString() ?? item.teamBShort,
        teamALogo: resolveTeamLogoPath(teamA['logo_id']?.toString()) ?? '',
        teamBLogo: resolveTeamLogoPath(teamB['logo_id']?.toString()) ?? '',
        teamAScore: teamAScore,
        teamBScore: teamBScore,
        matchStatus: match['status']?.toString() ?? '',
        uploaderName: uploader['player_name']?.toString(),
        uploaderAvatar: uploader['image_url']?.toString(),
        uploaderUserId: uploaderId ?? item.uploaderUserId,
        isUploaderDeleted: uploader['deleted_at'] != null,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _item == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final item = _item;
    if (item == null) {
      removeShareBootOverlay();
      return Scaffold(
        appBar: AppBar(title: const Text('Highlight')),
        body: AppNotFoundState(
          title: 'Highlight unavailable',
          subtitle:
              'This video may have been removed, or the link is incorrect.',
          onAction: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
      );
    }

    return LeagueVideoPlayerPage(videos: [item], initialIndex: 0);
  }
}
