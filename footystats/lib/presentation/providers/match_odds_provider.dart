import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/match_odds_repository.dart';
import '../../domain/models/match_odds.dart';

final matchOddsRepositoryProvider = Provider<MatchOddsRepository>((ref) {
  return MatchOddsRepository();
});

/// How long computed predictions stay cached after the last listener goes away.
const _oddsCacheTtl = Duration(minutes: 15);

/// Pre-match win / draw / lose probabilities for a fixture.
///
/// Computing predictions costs ~10 database queries per match, so results are
/// cached per match id and kept alive for [_oddsCacheTtl]. This provider
/// deliberately does NOT watch the home match list: a pull-to-refresh on Home
/// should not recompute for every visible card. Pre-match estimates barely
/// change within minutes; anything needing fresh values can `ref.invalidate`
/// this provider.
final matchOddsProvider = FutureProvider.autoDispose
    .family<MatchOdds, String>((ref, matchId) async {
      final link = ref.keepAlive();
      final expiry = Timer(_oddsCacheTtl, link.close);
      ref.onDispose(expiry.cancel);
      final repo = ref.watch(matchOddsRepositoryProvider);
      return repo.computeForMatch(matchId);
    });
