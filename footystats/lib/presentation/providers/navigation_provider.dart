import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Simple navigation index state for the bottom navigation / main shell.
class NavigationIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) {
    state = index;
  }
}

/// Navigation state provider.
final navigationIndexProvider =
    NotifierProvider<NavigationIndexNotifier, int>(
  NavigationIndexNotifier.new,
);
