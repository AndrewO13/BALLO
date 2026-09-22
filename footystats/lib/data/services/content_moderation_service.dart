import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/video_thumbnail_bytes.dart';

enum ModerationDecision { allow, review, reject }

class ModerationResult {
  const ModerationResult({
    required this.decision,
    required this.scores,
    this.reasons = const [],
    this.flagged = false,
  });

  final ModerationDecision decision;
  final Map<String, double> scores;
  final List<String> reasons;
  final bool flagged;

  bool get isRejected => decision == ModerationDecision.reject;
  bool get needsReview => decision == ModerationDecision.review;

  String get userMessage {
    switch (decision) {
      case ModerationDecision.reject:
        return 'This content was blocked because it may violate our '
            'Community Guidelines. Please choose something else.';
      case ModerationDecision.review:
        return 'Thanks — your content was posted and may be reviewed '
            'by our team within 24 hours.';
      case ModerationDecision.allow:
        return '';
    }
  }

  factory ModerationResult.fromJson(Map<String, dynamic> json) {
    final rawDecision = (json['decision']?.toString() ?? 'allow').toLowerCase();
    final decision = switch (rawDecision) {
      'reject' => ModerationDecision.reject,
      'review' => ModerationDecision.review,
      _ => ModerationDecision.allow,
    };
    final scoresRaw = json['scores'];
    final scores = <String, double>{};
    if (scoresRaw is Map) {
      for (final entry in scoresRaw.entries) {
        final v = entry.value;
        if (v is num) scores[entry.key.toString()] = v.toDouble();
      }
    }
    final reasonsRaw = json['reasons'];
    final reasons = reasonsRaw is List
        ? reasonsRaw.map((e) => e.toString()).toList()
        : const <String>[];
    return ModerationResult(
      decision: decision,
      scores: scores,
      reasons: reasons,
      flagged: json['flagged'] == true,
    );
  }

  /// Used when remote moderation is temporarily unavailable.
  factory ModerationResult.allowFallback() => const ModerationResult(
        decision: ModerationDecision.allow,
        scores: {},
      );
}

class ContentModerationService {
  ContentModerationService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const maxVideoSeconds = 60;
  static const maxFrames = 15;
  static const frameIntervalSeconds = 2.5;
  static const frameMaxWidth = 640;
  static const frameQuality = 65;

  Future<ModerationResult> moderateText(
    String text, {
    String? contentRef,
    bool softFailOnAuthError = true,
  }) async {
    return _invoke(
      {
        'kind': 'text',
        'text': text.trim(),
        if (contentRef != null) 'contentRef': contentRef,
        'contentType': 'text',
      },
      softFailOnAuthError: softFailOnAuthError,
    );
  }

  Future<ModerationResult> moderateImageBytes(
    Uint8List bytes, {
    String? contentRef,
    bool softFailOnAuthError = false,
  }) async {
    return _invoke(
      {
        'kind': 'image',
        'imageBase64': base64Encode(bytes),
        if (contentRef != null) 'contentRef': contentRef,
        'contentType': 'image',
      },
      softFailOnAuthError: softFailOnAuthError,
    );
  }

  /// Samples frames locally, sends base64 to Edge Function, discards frames.
  Future<ModerationResult> moderateVideoFile({
    required String localPath,
    required int durationSeconds,
    String? contentRef,
  }) async {
    if (durationSeconds > maxVideoSeconds) {
      throw StateError(
        'Highlights must be $maxVideoSeconds seconds or shorter.',
      );
    }

    final frames = await sampleVideoFrames(
      localPath: localPath,
      durationSeconds: durationSeconds,
    );
    if (frames.isEmpty) {
      throw StateError('Could not analyze this video. Try another clip.');
    }

    try {
      return await _invoke({
        'kind': 'video_frames',
        'framesBase64': frames.map(base64Encode).toList(),
        'sportsContext': true,
        if (contentRef != null) 'contentRef': contentRef,
        'contentType': 'video',
      });
    } finally {
      frames.clear();
    }
  }

  static Future<List<Uint8List>> sampleVideoFrames({
    required String localPath,
    required int durationSeconds,
  }) async {
    final durationMs = (durationSeconds <= 0 ? 1 : durationSeconds) * 1000;
    final times = <int>{0, (durationMs - 200).clamp(0, durationMs)};
    final step = (frameIntervalSeconds * 1000).round();
    for (var t = step; t < durationMs; t += step) {
      times.add(t);
      if (times.length >= maxFrames) break;
    }

    final sorted = times.toList()..sort();
    final out = <Uint8List>[];
    for (final timeMs in sorted.take(maxFrames)) {
      try {
        final bytes = await generateVideoThumbnailBytes(
          videoPath: localPath,
          maxWidth: frameMaxWidth,
          quality: frameQuality,
          timeMs: timeMs,
        );
        if (bytes != null && bytes.isNotEmpty) out.add(bytes);
      } catch (_) {
        // Skip bad frames.
      }
    }
    return out;
  }

  Future<String?> _accessToken({bool forceRefresh = false}) async {
    var session = _client.auth.currentSession;
    if (session == null) return null;

    final expiresAt = session.expiresAt;
    final needsRefresh = forceRefresh ||
        (expiresAt != null &&
            DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000)
                .isBefore(DateTime.now().add(const Duration(minutes: 1))));

    if (needsRefresh) {
      try {
        final refreshed = await _client.auth.refreshSession();
        session = refreshed.session ?? _client.auth.currentSession;
      } catch (_) {
        session = _client.auth.currentSession;
      }
    }
    return session?.accessToken;
  }

  Future<ModerationResult> _invoke(
    Map<String, dynamic> body, {
    bool softFailOnAuthError = false,
  }) async {
    // Pre-auth onboarding (player name / username) has no session yet.
    // Local UsernameRules still apply at the call site.
    if (_client.auth.currentSession == null) {
      if (softFailOnAuthError) return ModerationResult.allowFallback();
      throw StateError('Please sign in again to continue.');
    }

    Future<ModerationResult> once({required bool forceRefresh}) async {
      final token = await _accessToken(forceRefresh: forceRefresh);
      if (token == null || token.isEmpty) {
        if (softFailOnAuthError) return ModerationResult.allowFallback();
        throw StateError('Please sign in again to continue.');
      }

      final response = await _client.functions.invoke(
        'moderate-content',
        body: body,
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        if (data['error'] != null) {
          throw StateError(data['error'].toString());
        }
        return ModerationResult.fromJson(data);
      }
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        if (map['error'] != null) {
          throw StateError(map['error'].toString());
        }
        return ModerationResult.fromJson(map);
      }
      throw StateError('Unexpected moderation response');
    }

    try {
      return await once(forceRefresh: false);
    } on FunctionException catch (e) {
      if (e.status == 401) {
        try {
          return await once(forceRefresh: true);
        } on FunctionException catch (retry) {
          if (softFailOnAuthError &&
              (retry.status == 401 || retry.status >= 500)) {
            return ModerationResult.allowFallback();
          }
          throw StateError(
            'Could not verify this content right now. Please try again.',
          );
        } catch (_) {
          if (softFailOnAuthError) return ModerationResult.allowFallback();
          rethrow;
        }
      }
      if (softFailOnAuthError && e.status >= 500) {
        return ModerationResult.allowFallback();
      }
      final details = e.details;
      final message = details is Map && details['error'] != null
          ? details['error'].toString()
          : 'Could not verify this content right now. Please try again.';
      throw StateError(message);
    }
  }
}
