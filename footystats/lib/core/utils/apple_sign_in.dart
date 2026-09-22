import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/auth_constants.dart';

/// True when this platform supports native Sign in with Apple (iOS / macOS).
bool get usesNativeAppleSignIn =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

/// User dismissed the Apple sheet (or equivalent cancel).
bool isAppleSignInCanceled(Object error) {
  if (error is SignInWithAppleAuthorizationException) {
    return error.code == AuthorizationErrorCode.canceled;
  }
  return false;
}

/// Signs in with Apple via native AuthenticationServices on iOS/macOS, or
/// Supabase browser OAuth on Android / other platforms.
///
/// Returns an [AuthResponse] for the native path (session is ready immediately).
/// Returns `null` for the OAuth path (session arrives via deep link / auth stream).
Future<AuthResponse?> signInWithApple() async {
  final supabase = Supabase.instance.client;

  if (!usesNativeAppleSignIn) {
    await supabase.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: kOAuthRedirectUrl,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
    return null;
  }

  final rawNonce = supabase.auth.generateRawNonce();
  final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

  final credential = await SignInWithApple.getAppleIDCredential(
    scopes: [
      AppleIDAuthorizationScopes.email,
      AppleIDAuthorizationScopes.fullName,
    ],
    nonce: hashedNonce,
  );

  final idToken = credential.identityToken;
  if (idToken == null) {
    throw const AuthException(
      'Could not find ID Token from generated credential.',
    );
  }

  final authResponse = await supabase.auth.signInWithIdToken(
    provider: OAuthProvider.apple,
    idToken: idToken,
    nonce: rawNonce,
  );

  // Apple only provides the user's full name on the first authorization.
  if (credential.givenName != null || credential.familyName != null) {
    final nameParts = <String>[
      if (credential.givenName != null) credential.givenName!,
      if (credential.familyName != null) credential.familyName!,
    ];
    await supabase.auth.updateUser(
      UserAttributes(
        data: {
          'full_name': nameParts.join(' '),
          'given_name': credential.givenName,
          'family_name': credential.familyName,
        },
      ),
    );
  }

  return authResponse;
}
