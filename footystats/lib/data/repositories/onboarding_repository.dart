import '../../domain/models/onboarding_draft.dart';
import 'user_profile_repository.dart';

/// Persists onboarding profile data after the user is authenticated.
class OnboardingRepository {
  OnboardingRepository({UserProfileRepository? profileRepository})
      : _profileRepository = profileRepository ?? UserProfileRepository();

  final UserProfileRepository _profileRepository;

  Future<void> saveDraftProfile(
    OnboardingDraft draft, {
    String? imageUrl,
  }) async {
    await _profileRepository.upsertCurrentProfile(
      username: draft.username,
      playerName: draft.playerName,
      position: draft.position.isEmpty ? null : draft.position,
      country: draft.countryCode.isEmpty ? null : draft.countryCode,
      imageUrl: imageUrl ?? draft.imageUrl,
      accountType: draft.accountType.dbValue,
      staffRole: draft.staffRole?.dbValue,
      staffRoleOther: draft.staffRoleOther,
      updateStaffRole: draft.isTechnicalStaff,
    );
  }
}
