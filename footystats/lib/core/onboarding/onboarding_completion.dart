import 'package:supabase_flutter/supabase_flutter.dart';

/// Tracks whether the user finished the post-signup onboarding flow.
class OnboardingCompletion {
  OnboardingCompletion._();

  static const _metadataKey = 'onboarding_complete';

  static bool isCompleteFromUser(User? user) {
    if (user == null) return false;
    return user.userMetadata?[_metadataKey] == true;
  }

  static Future<bool> isComplete() async {
    final user = Supabase.instance.client.auth.currentUser;
    return isCompleteFromUser(user);
  }

  static Future<void> markComplete() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    await Supabase.instance.client.auth.updateUser(
      UserAttributes(
        data: {
          ...?user.userMetadata,
          _metadataKey: true,
        },
      ),
    );
  }
}
