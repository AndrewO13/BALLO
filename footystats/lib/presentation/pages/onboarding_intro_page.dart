import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/adaptive/adaptive.dart';
import '../../core/constants/app_constants.dart';
import 'welcome_page.dart';

class OnboardingIntroPage extends StatelessWidget {
  const OnboardingIntroPage({super.key});

  static const _onboardingBg = 'lib/assets/images/onboarding bg.png';
  static const _ball = 'lib/assets/images/ball.png';
  static const _fox = 'lib/assets/images/fox.png';
  static const _emoji = 'lib/assets/images/emoji.png';
  static const _goalTag = 'lib/assets/icons/onboarding/goal tag.svg';
  static const _foxBg = 'lib/assets/icons/onboarding/fox bg.svg';
  static const _track = 'lib/assets/icons/onboarding/track.svg';
  static const _midLeft = 'lib/assets/icons/onboarding/mid left.svg';
  static const _midRight = 'lib/assets/icons/onboarding/mid right.svg';

  Future<void> _openLegalUrl(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $uri')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final secondary = colorScheme.inversePrimary;
    final Size size = MediaQuery.sizeOf(context);
    final double sx = AppResponsive.isMobile(size)
        ? size.width / AppResponsive.designWidth
        : 1;
    final double sy = AppResponsive.isMobile(size)
        ? size.height / AppResponsive.designHeight
        : 1;
    final bool showSideArt = size.height >= 560;

    return Scaffold(
      body: MediaQuery.removePadding(
        context: context,
        removeLeft: true,
        child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          Image.asset(
            _onboardingBg,
            fit: BoxFit.cover,
          ),
          Positioned(
            left: 0,
            top: 0,
            child: _BallGoalTagGroup(scale: sx),
          ),
          Positioned(
            right: 20 * sx,
            top: 27 * sy,
            child: _FoxTrackGroup(scale: sx),
          ),
          if (showSideArt)
            Positioned(
              left: 8 * sx,
              top: 284 * sy,
              child: _MidLeftDecoration(scale: sx),
            ),
          if (showSideArt)
            Positioned(
              right: 16 * sx,
              top: 516 * sy,
              child: _MidRightDecoration(scale: sx),
            ),
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32 * sx),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Your\nfootball life\nin numbers',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.anton(
                    fontSize: 65,
                    height: 1.25,
                    color: Colors.black,
                    letterSpacing: -2.39,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final inset =
                    AppConstants.onboardingEdgeInset(constraints.maxWidth);
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(inset, 0, inset, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => const WelcomePage(),
                                ),
                              );
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: colorScheme.secondaryContainer,
                              foregroundColor:
                                  colorScheme.onSecondaryContainer,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            child: const Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _LegalNotice(
                          linkColor: secondary,
                          onTermsTap: () => _openLegalUrl(
                            context,
                            AppConstants.termsOfServiceUri,
                          ),
                          onPrivacyTap: () => _openLegalUrl(
                            context,
                            AppConstants.privacyPolicyUri,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _BallGoalTagGroup extends StatelessWidget {
  const _BallGoalTagGroup({this.scale = 1});

  final double scale;

  static const _ballSize = 165.0;
  static const _goalTagWidth = 130.0;
  static const _goalTagHeight = 96.0;

  @override
  Widget build(BuildContext context) {
    final ballSize = _ballSize * scale;
    final goalTagWidth = _goalTagWidth * scale;
    final goalTagHeight = _goalTagHeight * scale;
    return SizedBox(
      width: ballSize + (goalTagWidth - ballSize / 2),
      height: ballSize,
      child: _OnboardingGlow(
        shadowDiameter: 120 * scale,
        alignment: Alignment.centerLeft,
        child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRect(
            child: SizedBox(
              width: ballSize,
              height: ballSize,
              child: Image.asset(
                OnboardingIntroPage._ball,
                width: ballSize,
                height: ballSize,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
              ),
            ),
          ),
          Positioned(
            left: ballSize / 3,
            top: (ballSize - goalTagHeight) / 2,
            child: SvgPicture.asset(
              OnboardingIntroPage._goalTag,
              width: goalTagWidth,
              height: goalTagHeight,
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _FoxTrackGroup extends StatelessWidget {
  const _FoxTrackGroup({this.scale = 1});

  final double scale;

  static const _foxBgSize = 80.0;
  static const _foxSize = 72.0;
  static const _emojiSize = 31.0;

  @override
  Widget build(BuildContext context) {
    final foxBgSize = _foxBgSize * scale;
    final foxSize = _foxSize * scale;
    final emojiSize = _emojiSize * scale;
    final foxInset = (foxBgSize - foxSize) / 6;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: foxBgSize,
          height: foxBgSize,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              SvgPicture.asset(
                OnboardingIntroPage._foxBg,
                width: foxBgSize,
                height: foxBgSize,
              ),
              Image.asset(
                OnboardingIntroPage._fox,
                width: foxSize,
                height: foxSize,
                fit: BoxFit.contain,
              ),
              Positioned(
                top: foxInset,
                right: foxInset,
                child: Image.asset(
                  OnboardingIntroPage._emoji,
                  width: emojiSize,
                  height: emojiSize,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 4 * scale),
        SvgPicture.asset(OnboardingIntroPage._track),
      ],
    );
  }
}

class _MidLeftDecoration extends StatelessWidget {
  const _MidLeftDecoration({this.scale = 1});

  final double scale;

  static const _size = 133.0;

  @override
  Widget build(BuildContext context) {
    final size = _size * scale;
    return SizedBox(
      width: size,
      height: size,
      child: _OnboardingGlow(
        shadowDiameter: 60 * scale,
        child: SvgPicture.asset(
          OnboardingIntroPage._midLeft,
          width: size,
          height: size,
        ),
      ),
    );
  }
}

class _MidRightDecoration extends StatelessWidget {
  const _MidRightDecoration({this.scale = 1});

  final double scale;

  static const _size = 253.0;

  @override
  Widget build(BuildContext context) {
    final size = _size * scale;
    return SizedBox(
      width: size,
      height: size,
      child: _OnboardingGlow(
        shadowDiameter: 128 * scale,
        child: SvgPicture.asset(
          OnboardingIntroPage._midRight,
          width: size,
          height: size,
        ),
      ),
    );
  }
}

class _OnboardingGlow extends StatelessWidget {
  const _OnboardingGlow({
    required this.shadowDiameter,
    required this.child,
    this.alignment = Alignment.center,
  });

  final double shadowDiameter;
  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final shadowColor = Theme.of(context).colorScheme.secondary;

    return Stack(
      alignment: alignment,
      clipBehavior: Clip.none,
      children: [
        Container(
          width: shadowDiameter,
          height: shadowDiameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 40,
                spreadRadius: 18,
              ),
            ],
          ),
        ),
        child,
      ],
    );
  }
}

class _LegalNotice extends StatelessWidget {
  const _LegalNotice({
    required this.linkColor,
    required this.onTermsTap,
    required this.onPrivacyTap,
  });

  final Color linkColor;
  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyTap;

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.black.withValues(alpha: 0.55),
          height: 1.4,
        );
    final linkStyle = baseStyle?.copyWith(
      color: linkColor,
      fontWeight: FontWeight.w700,
    );

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('By continuing you agree to our ', style: baseStyle),
        GestureDetector(
          onTap: onTermsTap,
          child: Text('Terms', style: linkStyle),
        ),
        Text(' and ', style: baseStyle),
        GestureDetector(
          onTap: onPrivacyTap,
          child: Text('Privacy Policy', style: linkStyle),
        ),
        Text('.', style: baseStyle),
      ],
    );
  }
}
