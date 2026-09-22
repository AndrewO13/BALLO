import 'package:flutter/foundation.dart';

import '../config/env_config.dart';

/// OAuth / email-confirm redirect for the current platform.
///
/// - **Native:** custom scheme registered in Android/iOS (+ Supabase allow list).
/// - **Web:** HTTPS origin so the browser can complete Google/email auth.
///   Must stay on the Supabase Auth redirect allow list.
String get kOAuthRedirectUrl {
  if (kIsWeb) {
    // Prefer the live public site in release builds; fall back to the current
    // origin for local `flutter run -d chrome`.
    final configured = EnvConfig.publicSiteUrl.trim();
    final origin = configured.isNotEmpty
        ? configured.replaceAll(RegExp(r'/+$'), '')
        : Uri.base.origin;
    return '$origin/login-callback';
  }
  return 'com.ballonetwork.app://login-callback';
}

/// Native custom-scheme redirect (for docs / store listing).
const kNativeOAuthRedirectUrl = 'com.ballonetwork.app://login-callback';
