import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/constants/app_assets.dart';
import 'onboarding_profile_image_page.dart';

const List<String> _positions = [
  'Goalkeeper',
  'Defender',
  'Midfielder',
  'Attacker',
];

class OnboardingPositionPage extends StatefulWidget {
  const OnboardingPositionPage({
    super.key,
    required this.email,
    required this.username,
  });

  final String email;
  final String username;

  @override
  State<OnboardingPositionPage> createState() => _OnboardingPositionPageState();
}

class _OnboardingPositionPageState extends State<OnboardingPositionPage> {
  String? _selectedPosition;

  void _onContinue() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OnboardingProfileImagePage(
          email: widget.email,
          username: widget.username,
          position: _selectedPosition,
        ),
      ),
    );
  }

  void _onSkip() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OnboardingProfileImagePage(
          email: widget.email,
          username: widget.username,
          position: null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return _OnboardingScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _onSkip,
            child: Text(
              'Skip',
              style: TextStyle(color: colorScheme.onSurface),
            ),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Your position',
            style: textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'What position do you usually play? This helps with stats and match reports.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            children: _positions.map((pos) {
              final isSelected = _selectedPosition == pos;
              return ChoiceChip(
                label: Text(pos),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedPosition = selected ? pos : null;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _selectedPosition != null ? _onContinue : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: const Text('Next'),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingScaffold extends StatelessWidget {
  const _OnboardingScaffold({
    required this.appBar,
    required this.child,
  });

  final PreferredSizeWidget appBar;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: appBar,
      body: Stack(
        children: [
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Image.asset(
                AppAssets.onboardingBg,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.black.withOpacity(0.9),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: SingleChildScrollView(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHigh
                            .withOpacity(0.95),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      padding: const EdgeInsets.all(20.0),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
