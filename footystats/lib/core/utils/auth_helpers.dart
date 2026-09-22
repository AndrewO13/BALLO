import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/auth_constants.dart';

/// True when sign-in failed because the address is registered but unverified.
bool isEmailNotConfirmedError(AuthException error) {
  final code = error.code?.toLowerCase() ?? '';
  final message = error.message.toLowerCase();
  return code == 'email_not_confirmed' ||
      message.contains('email not confirmed') ||
      message.contains('email_not_confirmed');
}

/// Sends a new signup confirmation email / OTP.
Future<void> resendSignupVerification(String email) async {
  await Supabase.instance.client.auth.resend(
    type: OtpType.signup,
    email: email.trim(),
    emailRedirectTo: kOAuthRedirectUrl,
  );
}
