import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bottom navigation tab indices (matches [HomePage] `_selectedIndex`).
abstract final class MainNavTab {
  static const int home = 0;
  static const int secondary = 1; // Favourites (guest) or Matches (player)
  static const int leaderboard = 2;
  static const int explore = 3;
  static const int account = 4;
}

/// Increments per tab when the user re-taps that nav destination.
class MainNavScrollToTopNotifier extends Notifier<Map<int, int>> {
  @override
  Map<int, int> build() => const {};

  void requestScrollToTop(int tabIndex) {
    state = {
      ...state,
      tabIndex: (state[tabIndex] ?? 0) + 1,
    };
  }
}

final mainNavScrollToTopProvider =
    NotifierProvider<MainNavScrollToTopNotifier, Map<int, int>>(
      MainNavScrollToTopNotifier.new,
    );
