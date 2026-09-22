import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/scroll_to_top.dart';
import '../providers/main_nav_scroll_provider.dart';
import '../widgets/guest_account_banner.dart';

/// Account tab shown to guests instead of the player profile.
class GuestProfilePage extends ConsumerStatefulWidget {
  const GuestProfilePage({super.key});

  @override
  ConsumerState<GuestProfilePage> createState() => _GuestProfilePageState();
}

class _GuestProfilePageState extends ConsumerState<GuestProfilePage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(
      mainNavScrollToTopProvider.select((m) => m[MainNavTab.account] ?? 0),
      (previous, next) {
        if (previous == next) return;
        animateScrollControllerToTop(_scrollController);
      },
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 48),
                child: const GuestAccountBanner(),
              ),
            ),
          ),
        );
      },
    );
  }
}
