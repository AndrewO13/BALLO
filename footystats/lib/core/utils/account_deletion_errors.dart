import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_constants.dart';

/// Honest copy: identity is removed, shared match history stays.
const accountDeletionSummary =
    'Your login and personal profile are removed. Match history in shared '
    'leagues stays for other players as “Deleted player.”';

/// Maps backend errors to user-facing snackbar / dialog text.
String friendlyDeleteAccountError(Object error) {
  final raw = _extractMessage(error).toLowerCase();

  if (raw.contains('not authenticated') || raw.contains('signed in')) {
    return 'Please sign in again, then try deleting your account.';
  }

  if (raw.contains('storage') && raw.contains('not allowed')) {
    return 'We could not remove all of your uploaded files. Please try again '
        'in a moment or contact ${AppConstants.supportEmail}.';
  }

  if (error is AuthException) {
    return error.message;
  }

  return 'We could not delete your account right now. Please try again, or '
      'contact ${AppConstants.supportEmail} if you need help.';
}

String _extractMessage(Object error) {
  if (error is AuthException) return error.message;
  if (error is PostgrestException) return error.message;

  final text = error.toString();
  final match = RegExp(
    r'PostgrestException\(message:\s*([^,]+)',
  ).firstMatch(text);
  if (match != null) {
    return match.group(1)?.trim() ?? text;
  }

  return text;
}
