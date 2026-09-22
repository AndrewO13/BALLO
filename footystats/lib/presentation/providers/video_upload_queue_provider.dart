import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/env_config.dart';
import '../../core/utils/picked_video.dart';
import '../../core/utils/video_thumbnail_bytes.dart';
import '../../core/utils/video_upload_prep.dart';
import '../../data/services/content_moderation_service.dart';
import '../../domain/models/match_model.dart';
import 'matches_provider.dart';

enum VideoUploadPhase { preparing, moderating, uploading, finishing, failed }

class VideoUploadJob {
  const VideoUploadJob({
    required this.id,
    required this.matchId,
    required this.uploaderUserId,
    required this.localVideoPath,
    required this.originalFileName,
    this.thumbnailBytes,
    this.progress = 0,
    this.phase = VideoUploadPhase.preparing,
    this.error,
    required this.teamAShort,
    required this.teamBShort,
    required this.teamALogo,
    required this.teamBLogo,
    required this.teamAScore,
    required this.teamBScore,
    this.durationSeconds,
  });

  final String id;
  final String matchId;
  final String uploaderUserId;
  final String localVideoPath;
  final String originalFileName;
  final Uint8List? thumbnailBytes;
  final double progress;
  final VideoUploadPhase phase;
  final String? error;
  final String teamAShort;
  final String teamBShort;
  final String teamALogo;
  final String teamBLogo;
  final int teamAScore;
  final int teamBScore;
  final int? durationSeconds;

  bool get isFailed => phase == VideoUploadPhase.failed;

  VideoUploadJob copyWith({
    Uint8List? thumbnailBytes,
    double? progress,
    VideoUploadPhase? phase,
    String? error,
    int? durationSeconds,
    bool clearError = false,
  }) {
    return VideoUploadJob(
      id: id,
      matchId: matchId,
      uploaderUserId: uploaderUserId,
      localVideoPath: localVideoPath,
      originalFileName: originalFileName,
      thumbnailBytes: thumbnailBytes ?? this.thumbnailBytes,
      progress: progress ?? this.progress,
      phase: phase ?? this.phase,
      error: clearError ? null : (error ?? this.error),
      teamAShort: teamAShort,
      teamBShort: teamBShort,
      teamALogo: teamALogo,
      teamBLogo: teamBLogo,
      teamAScore: teamAScore,
      teamBScore: teamBScore,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }
}

class VideoUploadQueue extends Notifier<List<VideoUploadJob>> {
  static const _bucket = 'Match videos';

  @override
  List<VideoUploadJob> build() => const [];

  Future<void> enqueue({
    required String localVideoPath,
    required String originalFileName,
    required MatchModel match,
    required String uploaderUserId,
    Uint8List? thumbnailBytes,
    int? durationSeconds,
  }) async {
    final job = VideoUploadJob(
      id: const Uuid().v4(),
      matchId: match.id,
      uploaderUserId: uploaderUserId,
      localVideoPath: localVideoPath,
      originalFileName: originalFileName,
      thumbnailBytes: thumbnailBytes,
      durationSeconds: durationSeconds,
      teamAShort: match.teamA.shortForm,
      teamBShort: match.teamB.shortForm,
      teamALogo: match.teamA.logoPath,
      teamBLogo: match.teamB.logoPath,
      teamAScore: match.teamAScore ?? 0,
      teamBScore: match.teamBScore ?? 0,
    );
    state = [job, ...state];
    return _run(job);
  }

  void dismiss(String jobId) {
    state = [for (final job in state) if (job.id != jobId) job];
  }

  void _patch(String jobId, VideoUploadJob Function(VideoUploadJob) update) {
    state = [
      for (final job in state)
        if (job.id == jobId) update(job) else job,
    ];
  }

  Future<void> _run(VideoUploadJob initial) async {
    final jobId = initial.id;
    try {
      _patch(
        jobId,
        (job) => job.copyWith(phase: VideoUploadPhase.preparing, progress: 0.04),
      );

      var thumb = initial.thumbnailBytes;
      if (thumb == null || thumb.isEmpty) {
        try {
          thumb = await generateVideoThumbnailBytes(
            videoPath: initial.localVideoPath,
            maxWidth: 720,
            quality: 75,
            timeMs: 300,
          );
        } catch (_) {
          thumb = null;
        }
        if (thumb != null && thumb.isNotEmpty) {
          _patch(jobId, (job) => job.copyWith(thumbnailBytes: thumb));
        }
      }

      var duration = initial.durationSeconds;
      duration ??= await readVideoDurationSeconds(initial.localVideoPath);
      if (duration != null) {
        _patch(jobId, (job) => job.copyWith(durationSeconds: duration));
      }

      final durationSeconds = duration ?? 0;
      if (durationSeconds > ContentModerationService.maxVideoSeconds) {
        throw StateError(
          'Highlights must be ${ContentModerationService.maxVideoSeconds}s '
          'or shorter.',
        );
      }

      _patch(
        jobId,
        (job) =>
            job.copyWith(phase: VideoUploadPhase.moderating, progress: 0.12),
      );

      final moderation = await ContentModerationService().moderateVideoFile(
        localPath: initial.localVideoPath,
        durationSeconds: durationSeconds <= 0 ? 1 : durationSeconds,
        contentRef: 'pending:${initial.matchId}:${initial.id}',
      );
      if (moderation.isRejected) {
        throw StateError(moderation.userMessage);
      }

      final originalBytes = await XFile(initial.localVideoPath).readAsBytes();
      final prepared = await prepareVideoForUpload(
        path: initial.localVideoPath,
        originalBytes: originalBytes,
      );

      _patch(
        jobId,
        (job) => job.copyWith(phase: VideoUploadPhase.uploading, progress: 0.2),
      );

      final supabase = Supabase.instance.client;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final nameExt = p.extension(initial.originalFileName);
      final videoExt = nameExt.isNotEmpty ? nameExt : '.mp4';
      final videoPath =
          'match-videos/${initial.matchId}/${initial.matchId}_$timestamp$videoExt';

      String? thumbUrl;
      final thumbBytes = thumb;
      if (thumbBytes != null && thumbBytes.isNotEmpty) {
        final thumbStoragePath =
            'match-thumbnails/${initial.matchId}/${initial.matchId}_$timestamp.jpg';
        await supabase.storage
            .from(_bucket)
            .uploadBinary(thumbStoragePath, thumbBytes);
        thumbUrl = supabase.storage.from(_bucket).getPublicUrl(thumbStoragePath);
      }

      await _uploadWithProgress(
        objectPath: videoPath,
        bytes: prepared.bytes,
        contentType: prepared.didCompress
            ? 'video/mp4'
            : _contentType(initial.originalFileName),
        onProgress: (fraction) {
          final mapped = 0.25 + (fraction.clamp(0.0, 1.0) * 0.7);
          _patch(
            jobId,
            (job) => job.copyWith(
              phase: VideoUploadPhase.uploading,
              progress: mapped,
            ),
          );
        },
      );

      _patch(
        jobId,
        (job) => job.copyWith(phase: VideoUploadPhase.finishing, progress: 0.96),
      );

      final url = supabase.storage.from(_bucket).getPublicUrl(videoPath);
      final status =
          moderation.needsReview ? 'pending_review' : 'approved';
      await supabase.from('videos').insert({
        'match_id': initial.matchId,
        'uploader_user_id': initial.uploaderUserId,
        'duration_seconds': duration,
        'video_url': url,
        'thumbnail_url': thumbUrl,
        'moderation_status': status,
        'moderation_scores': moderation.scores,
        'moderated_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (moderation.needsReview) {
        try {
          await supabase.from('moderation_queue').insert({
            'content_type': 'video',
            'content_ref': url,
            'uploader_user_id': initial.uploaderUserId,
            'decision_hint': 'review',
            'scores': moderation.scores,
            'status': 'pending',
          });
        } catch (_) {}
      }

      ref.invalidate(matchVideosProvider(initial.matchId));
      ref.read(matchVideosLookupRevisionProvider.notifier).bump();
      dismiss(jobId);
    } catch (e) {
      _patch(
        jobId,
        (job) => job.copyWith(
          phase: VideoUploadPhase.failed,
          error: e.toString(),
        ),
      );
      rethrow;
    }
  }

  String _contentType(String fileName) {
    switch (p.extension(fileName).toLowerCase()) {
      case '.mov':
        return 'video/quicktime';
      case '.webm':
        return 'video/webm';
      default:
        return 'video/mp4';
    }
  }

  Future<void> _uploadWithProgress({
    required String objectPath,
    required Uint8List bytes,
    required String contentType,
    required void Function(double fraction) onProgress,
  }) async {
    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken;
    if (token == null || token.isEmpty) {
      throw StateError('You must be signed in to upload a video.');
    }

    final encodedBucket = Uri.encodeComponent(_bucket);
    final url =
        '${EnvConfig.supabaseUrl}/storage/v1/object/$encodedBucket/$objectPath';
    final dio = Dio();
    await dio.post<void>(
      url,
      data: bytes,
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'apikey': EnvConfig.supabaseAnonKey,
          'Content-Type': contentType,
          'x-upsert': 'true',
        },
        contentType: contentType,
      ),
      onSendProgress: (sent, total) {
        if (total <= 0) return;
        onProgress(sent / total);
      },
    );
  }
}

final videoUploadQueueProvider =
    NotifierProvider<VideoUploadQueue, List<VideoUploadJob>>(
      VideoUploadQueue.new,
    );
