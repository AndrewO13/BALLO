import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/guest_mode.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'onboarding_player_name_page.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  static const _logo = 'lib/assets/icons/ballo logo2.svg';

  static const _slides = <_OnboardingSlide>[
    _OnboardingSlide(
      heading: 'Your entire career,\nfrom the first whistle\nto the last',
      imageAsset: 'lib/assets/images/slide 1.png',
      readDuration: Duration(milliseconds: 6000),
    ),
    _OnboardingSlide(
      heading: 'Compare stats.\nStart arguments.\nRepeat.',
      imageAsset: 'lib/assets/images/slide 2.png',
      readDuration: Duration(milliseconds: 4800),
    ),
    _OnboardingSlide(
      heading: 'Watch your numbers\nclimb every week',
      imageAsset: 'lib/assets/images/slide 3.png',
      readDuration: Duration(milliseconds: 4800),
    ),
    _OnboardingSlide(
      heading: "See who's\ncarrying the team",
      imageAsset: 'lib/assets/images/slide 1.png',
      readDuration: Duration(milliseconds: 4200),
    ),
  ];

  int _currentIndex = 0;
  Timer? _advanceTimer;
  bool _isGuestSigningIn = false;

  Future<void> _continueAsGuest() async {
    if (_isGuestSigningIn) return;
    setState(() => _isGuestSigningIn = true);
    try {
      await GuestMode.signIn();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _isGuestSigningIn = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not continue as guest: ${e.message}')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isGuestSigningIn = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not continue as guest. Check your connection.'),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _scheduleAdvance();
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    super.dispose();
  }

  void _scheduleAdvance() {
    _advanceTimer?.cancel();
    _advanceTimer = Timer(_slides[_currentIndex].readDuration, () {
      if (!mounted) return;
      setState(() {
        _currentIndex = (_currentIndex + 1) % _slides.length;
      });
      _scheduleAdvance();
    });
  }

  void _goToSlide(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    _scheduleAdvance();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final slide = _slides[_currentIndex];

    return Scaffold(
      backgroundColor: colorScheme.secondaryFixed,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final metrics = _WelcomeLayoutMetrics.of(constraints);
            final buttonInset =
                AppConstants.onboardingEdgeInset(constraints.maxWidth);
            final contentInset = AppConstants.onboardingEdgeInset(
              constraints.maxWidth.clamp(0.0, 420.0),
            );
            final image = _WelcomeSlideImage(asset: slide.imageAsset);

            final slides = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: SvgPicture.asset(
                    _logo,
                    height: metrics.logoHeight,
                  ),
                ),
                SizedBox(height: metrics.gapAfterLogo),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: FittedBox(
                    key: ValueKey<String>(slide.heading),
                    fit: BoxFit.scaleDown,
                    child: Text(
                      slide.heading,
                      textAlign: TextAlign.center,
                          style: GoogleFonts.anton(
                            fontSize: 32,
                        height: 1.1,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: metrics.gapAfterHeading),
                if (metrics.useFlexImage)
                  Expanded(child: image)
                else
                  SizedBox(
                    height: metrics.fixedImageHeight,
                    child: image,
                  ),
                SizedBox(height: metrics.gapAfterImage),
                _SlideIndicators(
                  count: _slides.length,
                  currentIndex: _currentIndex,
                  activeColor: colorScheme.secondaryContainer,
                  inactiveColor: colorScheme.onSecondaryFixed
                      .withValues(alpha: 0.28),
                  onDotTap: _goToSlide,
                ),
                SizedBox(height: metrics.gapAfterIndicators),
              ],
            );

            final framedSlides = Align(
              alignment: Alignment.topCenter,
              heightFactor: metrics.useFlexImage ? null : 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: contentInset),
                  child: slides,
                ),
              ),
            );

            final buttons = Padding(
              padding: EdgeInsets.fromLTRB(
                buttonInset,
                0,
                buttonInset,
                metrics.bottomPadding,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const OnboardingPlayerNamePage(),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.secondaryContainer,
                      foregroundColor: colorScheme.onSecondaryContainer,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: const Text('Get started'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LoginPage(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: colorScheme.secondaryContainer
                            .withValues(alpha: 0.85),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      foregroundColor: colorScheme.secondaryContainer,
                    ),
                    child: const Text('I already have an account'),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: _isGuestSigningIn ? null : _continueAsGuest,
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.secondaryContainer
                          .withValues(alpha: 0.9),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isGuestSigningIn
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.secondaryContainer,
                            ),
                          )
                        : const Text(
                            'Just here to watch? Continue as a guest',
                            textAlign: TextAlign.center,
                          ),
                  ),
                ],
              ),
            );

            if (metrics.useFlexImage) {
              return Column(
                children: [
                  Expanded(child: framedSlides),
                  buttons,
                ],
              );
            }

            return SingleChildScrollView(
              child: Column(
                children: [
                  framedSlides,
                  buttons,
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WelcomeLayoutMetrics {
  const _WelcomeLayoutMetrics({
    required this.logoHeight,
    required this.gapAfterLogo,
    required this.gapAfterHeading,
    required this.gapAfterImage,
    required this.gapAfterIndicators,
    required this.bottomPadding,
    required this.useFlexImage,
    required this.fixedImageHeight,
  });

  factory _WelcomeLayoutMetrics.of(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    final contentWidth = width.clamp(0.0, 420.0);
    final contentInset = AppConstants.onboardingEdgeInset(contentWidth);
    final innerWidth = (contentWidth - contentInset * 2).clamp(0.0, 420.0);
    final tight = height < 560;
    final compact = height < 680;

    return _WelcomeLayoutMetrics(
      logoHeight: tight ? 22.0 : 28.0,
      gapAfterLogo: tight ? 8.0 : compact ? 12.0 : 20.0,
      gapAfterHeading: tight ? 8.0 : compact ? 12.0 : 20.0,
      gapAfterImage: tight ? 8.0 : compact ? 12.0 : 16.0,
      gapAfterIndicators: tight ? 12.0 : compact ? 16.0 : 24.0,
      bottomPadding: tight ? 4.0 : 8.0,
      useFlexImage: height >= 620,
      fixedImageHeight: (innerWidth * 1.15).clamp(180.0, 320.0),
    );
  }

  final double logoHeight;
  final double gapAfterLogo;
  final double gapAfterHeading;
  final double gapAfterImage;
  final double gapAfterIndicators;
  final double bottomPadding;
  final bool useFlexImage;
  final double fixedImageHeight;
}

class _WelcomeSlideImage extends StatelessWidget {
  const _WelcomeSlideImage({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: ClipRRect(
        key: ValueKey<String>(asset),
        borderRadius: BorderRadius.circular(20),
        child: Image.asset(
          asset,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.contain,
          alignment: Alignment.center,
        ),
      ),
    );
  }
}

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.heading,
    required this.imageAsset,
    required this.readDuration,
  });

  final String heading;
  final String imageAsset;
  final Duration readDuration;
}

class _SlideIndicators extends StatelessWidget {
  const _SlideIndicators({
    required this.count,
    required this.currentIndex,
    required this.activeColor,
    required this.inactiveColor,
    required this.onDotTap,
  });

  final int count;
  final int currentIndex;
  final Color activeColor;
  final Color inactiveColor;
  final ValueChanged<int> onDotTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == currentIndex;
        return GestureDetector(
          onTap: () => onDotTap(index),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? activeColor : inactiveColor,
              ),
            ),
          ),
        );
      }),
    );
  }
}
