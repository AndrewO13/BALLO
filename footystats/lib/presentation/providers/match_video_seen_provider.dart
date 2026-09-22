import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/guest_mode.dart';

/// Video IDs the current user has already watched in the match score-pill player.
class MatchVideoSeenNotifier extends Notifier<Set<String>> {
  static const _keyPrefix = 'match_video_seen_ids';

  @override
  Set<String> build() {
    _hydrate();
    return {};
  }

  String _storageKey() {
    if (GuestMode.isGuest) return '${_keyPrefix}_guest';
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return '${_keyPrefix}_guest';
    return '${_keyPrefix}_$userId';
  }

  Future<void> _hydrate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_storageKey())?.toSet() ?? {};
      state = ids;
    } catch (_) {}
  }

  Future<void> markWatched(Iterable<String> videoIds) async {
    final incoming = videoIds.where((id) => id.isNotEmpty).toSet();
    if (incoming.isEmpty) return;
    if (incoming.every(state.contains)) return;
    final next = {...state, ...incoming};
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_storageKey(), next.toList());
    } catch (_) {}
  }
}

final matchVideoSeenProvider =
    NotifierProvider<MatchVideoSeenNotifier, Set<String>>(
      MatchVideoSeenNotifier.new,
    );

/// Upload-order watched flags for the score-pill status ring.
List<bool> matchVideoWatchedSegments(
  String matchId,
  Map<String, List<String>> videoIdsByMatch,
  Set<String> seenIds,
) {
  final ids = videoIdsByMatch[matchId];
  if (ids == null || ids.isEmpty) return const [false];
  return [for (final id in ids) seenIds.contains(id)];
}
