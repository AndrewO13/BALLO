import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/adaptive/adaptive.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/onboarding_steps.dart';
import '../../domain/models/account_type.dart';
import 'onboarding_progress_app_bar.dart';

/// Shared primary action styling for onboarding steps.
class OnboardingContinueButton extends StatelessWidget {
  const OnboardingContinueButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.symmetric(
            vertical: 14 * AppResponsive.layoutScaleOf(context),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.onPrimary,
                ),
              )
            : Text(label),
      ),
    );
  }
}

/// Sign-up-style layout: progress app bar, scroll content, pinned bottom action.
class OnboardingStepScaffold extends StatelessWidget {
  const OnboardingStepScaffold({
    super.key,
    required this.step,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.bottomBar,
    this.accountType,
    this.actions,
    this.showLogo = true,
  });

  final OnboardingStep step;
  final AccountType? accountType;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget bottomBar;
  final List<Widget>? actions;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final inset = AppResponsive.horizontalInset(context, design: 24);
    final scale = AppResponsive.layoutScaleOf(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: OnboardingProgressAppBar(
        step: step,
        accountType: accountType,
        actions: actions,
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(inset, 8 * scale, inset, 16 * scale),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showLogo) ...[
                          Center(
                            child: SvgPicture.asset(
                              AppAssets.balloLogo,
                              height: 36 * scale,
                              semanticsLabel: 'Ballo',
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 28),
                        child,
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(inset, 8 * scale, inset, 16 * scale),
                  child: bottomBar,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pinned bottom layout for onboarding pages without [OnboardingStepScaffold].
class OnboardingPinnedBottomLayout extends StatelessWidget {
  const OnboardingPinnedBottomLayout({
    super.key,
    required this.scrollContent,
    required this.bottomBar,
  });

  final Widget scrollContent;
  final Widget bottomBar;

  @override
  Widget build(BuildContext context) {
    final inset = AppResponsive.horizontalInset(context, design: 24);
    final scale = AppResponsive.layoutScaleOf(context);

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(inset, 8 * scale, inset, 16 * scale),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: scrollContent,
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(inset, 8 * scale, inset, 16 * scale),
                child: bottomBar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
