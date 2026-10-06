import 'package:flutter/material.dart';

import '../providers/main_nav_scroll_provider.dart';
import 'matches.dart';

/// Home tab shown to guests and technical staff (fans browsing matches by date).
class GuestHomeContent extends StatelessWidget {
  const GuestHomeContent({
    super.key,
    this.activationNonce = 0,
  });

  final int activationNonce;

  @override
  Widget build(BuildContext context) {
    return MatchesPage(
      activationNonce: activationNonce,
      mainNavTabIndex: MainNavTab.home,
      useDateNavigation: true,
    );
  }
}
