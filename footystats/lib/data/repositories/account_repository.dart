import 'package:supabase_flutter/supabase_flutter.dart';

/// Auth account operations: email, password, and self-service deletion.
class AccountRepository {
  AccountRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _profileImagesBucket = 'Profile images';

  User? get currentUser => _client.auth.currentUser;

  String? get currentEmail => currentUser?.email;

  /// True when the user signed up with email/password (not only OAuth).
  bool get hasEmailPasswordIdentity {
    final identities = currentUser?.identities;
    if (identities == null || identities.isEmpty) return false;
    return identities.any((identity) => identity.provider == 'email');
  }

  Future<void> updateEmail(String newEmail) async {
    final trimmed = newEmail.trim();
    if (trimmed.isEmpty) {
      throw const AuthException('Enter a valid email address');
    }
    await _client.auth.updateUser(UserAttributes(email: trimmed));
  }

  Future<void> updatePassword(String newPassword) async {
    if (newPassword.length < 8) {
      throw const AuthException('Password must be at least 8 characters');
    }
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Removes avatar files only. Team logos, league art, and match videos stay
  /// with the shared history; the RPC clears storage ownership afterwards.
  Future<void> _deleteAvatarUploads() async {
    final userId = currentUser?.id;
    if (userId == null) return;

    final bucket = _client.storage.from(_profileImagesBucket);
    final prefix = '${userId}_';

    try {
      final entries = await bucket.list(path: 'avatars');
      final paths = entries
          .where((entry) => entry.name.startsWith(prefix))
          .map((entry) => 'avatars/${entry.name}')
          .toList();
      if (paths.isNotEmpty) {
        await bucket.remove(paths);
      }
    } catch (_) {
      // Best-effort; remaining objects are detached in the RPC.
    }
  }

  /// Deletes the signed-in account via a privileged Postgres RPC, then signs out.
  Future<void> deleteOwnAccount() async {
    final user = currentUser;
    if (user == null) {
      throw const AuthException('You must be signed in to delete your account');
    }

    await _deleteAvatarUploads();
    await _client.rpc('delete_own_account');
    await _client.auth.signOut();
  }
}
