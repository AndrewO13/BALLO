import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/onboarding/onboarding_completion.dart';
import '../../domain/models/onboarding_draft.dart';
import 'user_profile_repository.dart';

/// Persists onboarding profile data after the user is authenticated.
class OnboardingRepository {
  OnboardingRepository({UserProfileRepository? profileRepository})
      : _profileRepository = profileRepository ?? UserProfileRepository();

  final UserProfileRepository _profileRepository;

  /// True when Google/Apple signed into an account that already finished (or
  /// started) registration — not a blank new auth user.
  Future<bool> currentUserAlreadyRegistered() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.isAnonymous) return false;
    if (OnboardingCompletion.isCompleteFromUser(user)) return true;
    final profile = await _profileRepository.getCurrentProfile();
    if (profile == null || profile.isDeleted) return profile?.isDeleted == true;
    final hasName = profile.playerName?.trim().isNotEmpty == true;
    final hasUsername = profile.username?.trim().isNotEmpty == true;
    return hasName || hasUsername;
  }

  Future<void> saveDraftProfile(
    OnboardingDraft draft, {
    String? imageUrl,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (OnboardingCompletion.isCompleteFromUser(user)) {
      throw AuthException('An account with this email already exists');
    }
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
