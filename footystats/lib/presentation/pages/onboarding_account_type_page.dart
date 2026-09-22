import 'package:flutter/material.dart';

import '../../core/constants/onboarding_steps.dart';
import '../../domain/models/account_type.dart';
import '../../domain/models/onboarding_draft.dart';
import '../widgets/onboarding_step_scaffold.dart';
import 'onboarding_position_page.dart';
import 'onboarding_staff_role_page.dart';

class OnboardingAccountTypePage extends StatefulWidget {
  const OnboardingAccountTypePage({super.key, required this.draft});

  final OnboardingDraft draft;

  @override
  State<OnboardingAccountTypePage> createState() =>
      _OnboardingAccountTypePageState();
}

class _OnboardingAccountTypePageState extends State<OnboardingAccountTypePage> {
  AccountType? _selected;

  void _onContinue() {
    if (_selected == null) return;
    final draft = widget.draft.copyWith(accountType: _selected);
    if (_selected == AccountType.technicalStaff) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OnboardingStaffRolePage(draft: draft),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OnboardingPositionPage(draft: draft),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      step: OnboardingStep.accountType,
      accountType: _selected ?? widget.draft.accountType,
      title: 'What brings you to Ballo?',
      subtitle:
          'We’ll tailor the app around how you use it — as a player or as technical staff.',
      bottomBar: OnboardingContinueButton(
        label: 'Continue',
        onPressed: _selected != null ? _onContinue : null,
      ),
      child: Column(
        children: [
          _AccountTypeCard(
            title: 'Player',
            subtitle:
                'I play. Track my matches, stats and career on one card.',
            icon: Icons.sports_soccer,
            selected: _selected == AccountType.player,
            onTap: () => setState(() => _selected = AccountType.player),
          ),
          const SizedBox(height: 12),
          _AccountTypeCard(
            title: 'Technical staff',
            subtitle:
                'I coach, scout or represent players. Follow the talent and run the show.',
            icon: Icons.badge_outlined,
            selected: _selected == AccountType.technicalStaff,
            onTap: () =>
                setState(() => _selected = AccountType.technicalStaff),
          ),
        ],
      ),
    );
  }
}

class _AccountTypeCard extends StatelessWidget {
  const _AccountTypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final background = selected
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHigh;
    final foreground = selected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;
    final muted = selected
        ? colorScheme.onPrimaryContainer.withValues(alpha: 0.75)
        : colorScheme.onSurfaceVariant;

    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? colorScheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: foreground,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: textTheme.bodyMedium?.copyWith(
                        color: muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(icon, size: 36, color: foreground),
            ],
          ),
        ),
      ),
    );
  }
}
