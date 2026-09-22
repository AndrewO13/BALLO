import 'package:flutter/material.dart';

import '../../core/constants/onboarding_steps.dart';
import '../../domain/models/account_type.dart';

/// App bar with back navigation and a linear onboarding progress indicator.
class OnboardingProgressAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const OnboardingProgressAppBar({
    super.key,
    required this.step,
    this.accountType,
    this.actions,
  });

  final OnboardingStep step;
  final AccountType? accountType;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      actions: actions,
      title: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: step.progressFor(accountType),
            minHeight: 4,
            backgroundColor: colorScheme.secondaryContainer,
            color: colorScheme.primary,
            year2023: false,
          ),
        ),
      ),
    );
  }
}
