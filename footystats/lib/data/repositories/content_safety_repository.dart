import 'package:supabase_flutter/supabase_flutter.dart';

/// Report + block helpers for Apple Guideline 1.2.
class ContentSafetyRepository {
  ContentSafetyRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const reportReasons = <String, String>{
    'spam': 'Spam or misleading',
    'harassment': 'Harassment or bullying',
    'hate': 'Hate speech',
    'sexual': 'Sexual content',
    'violence': 'Graphic violence (not football)',
    'impersonation': 'Impersonation',
    'other': 'Other',
  };

  Future<void> reportVideo({
    required String videoId,
    required String reason,
    String? details,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw const AuthException('Sign in to report content');
    await _client.from('content_reports').upsert({
      'reporter_user_id': uid,
      'target_type': 'video',
      'target_id': videoId,
      'reason': reason,
      'details': details?.trim().isEmpty == true ? null : details?.trim(),
      'status': 'open',
    }, onConflict: 'reporter_user_id,target_type,target_id');
  }

  Future<void> reportUser({
    required String userId,
    required String reason,
    String? details,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw const AuthException('Sign in to report a user');
    if (uid == userId) {
      throw const AuthException('You cannot report yourself');
    }
    await _client.from('content_reports').upsert({
      'reporter_user_id': uid,
      'target_type': 'user',
      'target_id': userId,
      'reason': reason,
      'details': details?.trim().isEmpty == true ? null : details?.trim(),
      'status': 'open',
    }, onConflict: 'reporter_user_id,target_type,target_id');
  }

  Future<void> blockUser(String blockedUserId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw const AuthException('Sign in to block a user');
    if (uid == blockedUserId) {
      throw const AuthException('You cannot block yourself');
    }
    await _client.from('user_blocks').upsert({
      'blocker_user_id': uid,
      'blocked_user_id': blockedUserId,
    }, onConflict: 'blocker_user_id,blocked_user_id');

    // Also drop follow either direction so blocked content stops circulating.
    await _client
        .from('user_follows')
        .delete()
        .eq('follower_user_id', uid)
        .eq('following_user_id', blockedUserId);
    await _client
        .from('user_follows')
        .delete()
        .eq('follower_user_id', blockedUserId)
        .eq('following_user_id', uid);
  }

  Future<void> unblockUser(String blockedUserId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    await _client
        .from('user_blocks')
        .delete()
        .eq('blocker_user_id', uid)
        .eq('blocked_user_id', blockedUserId);
  }

  Future<Set<String>> blockedUserIds() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return {};
    final rows = await _client
        .from('user_blocks')
        .select('blocked_user_id')
        .eq('blocker_user_id', uid);
    return {
      for (final row in List<Map<String, dynamic>>.from(rows as List))
        if (row['blocked_user_id'] != null) row['blocked_user_id'].toString(),
    };
  }

  Future<void> acceptCommunityGuidelines() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw const AuthException('Sign in required');
    await _client.from('players').update({
      'community_guidelines_accepted_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', uid);
  }

  Future<bool> hasAcceptedCommunityGuidelines() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return false;
    final row = await _client
        .from('players')
        .select('community_guidelines_accepted_at')
        .eq('id', uid)
        .maybeSingle();
    return row?['community_guidelines_accepted_at'] != null;
  }
}
