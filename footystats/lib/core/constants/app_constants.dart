import '../adaptive/responsive.dart';

/// App-wide constants
class AppConstants {
  // App Info
  static const String appName = 'Ballo';
  static const String appTagline = 'Play like an amateur, Track like a pro.';
  static const String publicSiteUrl = 'https://app.ballonetwork.com';
  static const String shareDescription = 'Now you know.';
  static const String supportEmail = 'info@ballonetwork.com';

  static const String privacyPolicyPath = '/privacy';
  static const String termsOfServicePath = '/terms';
  static const String communityGuidelinesPath = '/community-guidelines';

  static Uri get privacyPolicyUri =>
      Uri.parse('$publicSiteUrl$privacyPolicyPath');
  static Uri get termsOfServiceUri =>
      Uri.parse('$publicSiteUrl$termsOfServicePath');
  static Uri get communityGuidelinesUri =>
      Uri.parse('$publicSiteUrl$communityGuidelinesPath');

  /// Design width used for onboarding edge insets (common Android device).
  static const double onboardingDesignWidth = AppResponsive.designWidth;

  /// Horizontal inset from screen edges for full-width onboarding actions
  /// at [onboardingDesignWidth].
  static const double onboardingDesignEdgeInset = 16;

  /// Scales [onboardingDesignEdgeInset] with [width] (16dp at 412 logical px).
  static double onboardingEdgeInset(double width) =>
      AppResponsive.edgeInsetForWidth(width, design: onboardingDesignEdgeInset);

  // Navigation
  static const List<String> pageTitles = [
    'Home',
    'Matches',
    'Leaderboard',
    'Explore',
    'Account',
  ];
}
