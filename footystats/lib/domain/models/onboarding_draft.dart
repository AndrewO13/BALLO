import 'account_type.dart';

/// Profile fields collected before account creation; persisted after verification.
class OnboardingDraft {
  const OnboardingDraft({
    this.playerName = '',
    this.username = '',
    this.position = '',
    this.countryCode = '',
    this.imageUrl,
    this.accountType = AccountType.player,
    this.staffRole,
    this.staffRoleOther = '',
  });

  final String playerName;
  final String username;
  final String position;
  final String countryCode;
  final String? imageUrl;
  final AccountType accountType;
  final StaffRole? staffRole;
  final String staffRoleOther;

  bool get isTechnicalStaff => accountType == AccountType.technicalStaff;

  bool get hasPreAuthProfileData {
    final hasIdentity =
        playerName.trim().isNotEmpty && username.trim().isNotEmpty;
    if (isTechnicalStaff) {
      if (staffRole == StaffRole.other) {
        return hasIdentity && staffRoleOther.trim().isNotEmpty;
      }
      return hasIdentity && staffRole != null;
    }
    return hasIdentity &&
        position.trim().isNotEmpty &&
        countryCode.trim().isNotEmpty;
  }

  OnboardingDraft copyWith({
    String? playerName,
    String? username,
    String? position,
    String? countryCode,
    String? imageUrl,
    bool clearImageUrl = false,
    AccountType? accountType,
    StaffRole? staffRole,
    String? staffRoleOther,
  }) {
    return OnboardingDraft(
      playerName: playerName ?? this.playerName,
      username: username ?? this.username,
      position: position ?? this.position,
      countryCode: countryCode ?? this.countryCode,
      imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
      accountType: accountType ?? this.accountType,
      staffRole: staffRole ?? this.staffRole,
      staffRoleOther: staffRoleOther ?? this.staffRoleOther,
    );
  }
}
