import '../../domain/models/account_type.dart';

/// Onboarding after welcome: profile details → account → verify → photo → team.
enum OnboardingStep {
  playerName,
  username,
  accountType,
  position,
  staffRole,
  country,
  signUp,
  verifyEmail,
  profileImage,
  joinTeam,
}

extension OnboardingStepProgress on OnboardingStep {
  /// Determinate progress for [LinearProgressIndicator] (0–1).
  double progressFor(AccountType? accountType) {
    return stepIndexFor(accountType) / totalStepsFor(accountType);
  }

  int totalStepsFor(AccountType? accountType) {
    if (accountType == AccountType.technicalStaff) return 7;
    return 9;
  }

  int stepIndexFor(AccountType? accountType) {
    if (accountType == AccountType.technicalStaff) {
      return switch (this) {
        OnboardingStep.playerName => 1,
        OnboardingStep.username => 2,
        OnboardingStep.accountType => 3,
        OnboardingStep.staffRole => 4,
        OnboardingStep.signUp => 5,
        OnboardingStep.verifyEmail => 6,
        OnboardingStep.profileImage => 7,
        OnboardingStep.position ||
        OnboardingStep.country ||
        OnboardingStep.joinTeam =>
          4,
      };
    }
    return switch (this) {
      OnboardingStep.playerName => 1,
      OnboardingStep.username => 2,
      OnboardingStep.accountType => 3,
      OnboardingStep.position => 4,
      OnboardingStep.country => 5,
      OnboardingStep.signUp => 6,
      OnboardingStep.verifyEmail => 7,
      OnboardingStep.profileImage => 8,
      OnboardingStep.joinTeam => 9,
      OnboardingStep.staffRole => 4,
    };
  }
}
