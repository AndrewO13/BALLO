import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/username_rules.dart';
import '../../core/utils/username_suggestions.dart';

enum UsernameAvailability { idle, checking, available, taken, invalid }

class UsernameCheckResult {
  const UsernameCheckResult({
    required this.status,
    this.suggestions = const [],
  });

  final UsernameAvailability status;
  final List<String> suggestions;

  bool get canUse => status == UsernameAvailability.available;
}

class UsernameRepository {
  UsernameRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<bool> isAvailable(
    String username, {
    String? excludePlayerId,
  }) async {
    final normalized = UsernameRules.normalize(username);
    if (!UsernameRules.isValidFormat(normalized) ||
        UsernameRules.offensiveContentError(normalized) != null) {
      return false;
    }

    final result = await _client.rpc(
      'is_username_available',
      params: {
        'p_username': normalized,
        'p_exclude_player_id': excludePlayerId,
      },
    );
    return result == true;
  }

  Future<UsernameCheckResult> check(
    String username, {
    String? excludePlayerId,
  }) async {
    final normalized = UsernameRules.normalize(username);
    if (normalized.isEmpty) {
      return const UsernameCheckResult(status: UsernameAvailability.idle);
    }
    if (!UsernameRules.isValidFormat(normalized) ||
        UsernameRules.offensiveContentError(normalized) != null) {
      return const UsernameCheckResult(status: UsernameAvailability.invalid);
    }

    final available = await isAvailable(
      normalized,
      excludePlayerId: excludePlayerId,
    );
    if (available) {
      return const UsernameCheckResult(status: UsernameAvailability.available);
    }

    final suggestions = await _firstAvailableSuggestions(
      normalized,
      excludePlayerId: excludePlayerId,
    );
    return UsernameCheckResult(
      status: UsernameAvailability.taken,
      suggestions: suggestions,
    );
  }

  Future<List<String>> _firstAvailableSuggestions(
    String base, {
    String? excludePlayerId,
    int limit = 3,
  }) async {
    final picks = <String>[];
    for (final candidate in UsernameSuggestions.candidates(base)) {
      if (picks.length >= limit) break;
      final ok = await isAvailable(
        candidate,
        excludePlayerId: excludePlayerId,
      );
      if (ok) picks.add(candidate);
    }
    return picks;
  }
}
