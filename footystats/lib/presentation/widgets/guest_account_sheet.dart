import 'package:flutter/material.dart';

import '../pages/login_page.dart';
import '../pages/onboarding_player_name_page.dart';

/// Bottom sheet shown when a guest taps a player-only action
/// (following, liking, creating teams, ...).
///
/// Offers the two ways out of guest mode: create an account or sign in.
Future<void> showGuestAccountSheet(
  BuildContext context, {
  String title = 'Create a free account',
  String message =
      'This is a player feature. Create a free Ballo account to '
      'join teams, track your stats and interact with other players.',
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final textTheme = Theme.of(context).textTheme;

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.sports_soccer,
                size: 40,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const OnboardingPlayerNamePage(),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Text('Create free account'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LoginPage(),
                    ),
                  );
                },
                child: const Text('I already have an account'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
