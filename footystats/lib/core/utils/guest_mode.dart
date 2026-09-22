import 'package:supabase_flutter/supabase_flutter.dart';

/// Guest (fan) session helpers, backed by Supabase anonymous sign-in.
///
/// A guest gets a real Supabase session, so every RLS-protected read keeps
/// working, but has no player profile, teams, or stats. `isAnonymous` on the
/// auth user is the single source of truth for "is this a fan or a player".
///
/// Requires "Allow anonymous sign-ins" to be enabled in the Supabase
/// dashboard (Authentication -> Sign In / Up).
class GuestMode {
  const GuestMode._();

  /// True when the active session belongs to a guest (anonymous) user.
  static bool get isGuest =>
      Supabase.instance.client.auth.currentUser?.isAnonymous ?? false;

  /// Starts a guest session.
  static Future<void> signIn() async {
    await Supabase.instance.client.auth.signInAnonymously();
  }

  /// Ends the guest session.
  static Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
  }
}
