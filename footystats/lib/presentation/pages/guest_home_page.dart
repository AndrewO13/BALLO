import 'package:flutter/material.dart';

import '../../core/adaptive/adaptive.dart';
import '../providers/main_nav_scroll_provider.dart';
import 'matches.dart';

/// Home tab shown to guests and technical staff (fans browsing matches by date).
class GuestHomeContent extends StatelessWidget {
  const GuestHomeContent({
    super.key,
    this.activationNonce = 0,
    this.heading = 'Welcome to the stands!',
    this.subtitle = 'All the action, none of the running',
  });

  final int activationNonce;
  final String heading;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return MatchesPage(
      activationNonce: activationNonce,
      mainNavTabIndex: MainNavTab.home,
      useDateNavigation: true,
      header: Padding(
        padding: EdgeInsets.fromLTRB(
          AppResponsive.horizontalInset(context),
          16 * AppResponsive.layoutScaleOf(context),
          AppResponsive.horizontalInset(context),
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              heading,
              style: textTheme.displaySmall,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
