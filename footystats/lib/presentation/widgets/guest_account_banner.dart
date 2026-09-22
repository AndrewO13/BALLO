import 'package:flutter/material.dart';

import '../pages/login_page.dart';
import '../pages/onboarding_player_name_page.dart';

/// Create-account banner shown on the guest profile tab.
class GuestAccountBanner extends StatelessWidget {
  const GuestAccountBanner({super.key});

  void _openCreateAccount(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const OnboardingPlayerNamePage(),
      ),
    );
  }

  void _openSignIn(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const LoginPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Do you play too?',
            textAlign: TextAlign.start,
            style: textTheme.headlineSmall?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Create a free account to',
            style: textTheme.titleSmall?.copyWith(
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          const _BenefitRow(
            icon: Icons.query_stats,
            text: 'Track your goals, assists and match ratings',
          ),
          const _BenefitRow(
            icon: Icons.groups_outlined,
            text: 'Join your team and play in leagues',
          ),
          const _BenefitRow(
            icon: Icons.leaderboard_outlined,
            text: 'Climb the weekly leaderboard',
          ),
          const _BenefitRow(
            icon: Icons.videocam_outlined,
            text: 'Upload and share your match highlights',
            isLast: true,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => _openCreateAccount(context),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: const Text('Create account'),
          ),
          TextButton(
            onPressed: () => _openSignIn(context),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              foregroundColor: colorScheme.onPrimaryContainer,
              alignment: Alignment.centerLeft,
            ),
            child: const Text('I already have an account'),
          ),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.icon,
    required this.text,
    this.isLast = false,
  });

  final IconData icon;
  final String text;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: colorScheme.onPrimaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
