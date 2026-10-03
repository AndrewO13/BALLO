import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/device_account.dart';
import 'user_profile_repository.dart';

/// Persists refresh tokens for accounts that have signed in on this device
/// and have not been signed out.
class DeviceAccountsRepository {
  DeviceAccountsRepository({
    SupabaseClient? client,
    UserProfileRepository? profiles,
  }) : _client = client ?? Supabase.instance.client,
       _profiles = profiles ?? UserProfileRepository();

  static const _prefsKey = 'ballo.device_accounts.v1';

  final SupabaseClient _client;
  final UserProfileRepository _profiles;

  Future<List<DeviceAccount>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((row) => DeviceAccount.fromJson(Map<String, dynamic>.from(row)))
          .where(
            (account) =>
                account.userId.isNotEmpty && account.refreshToken.isNotEmpty,
          )
          .toList()
        ..sort((a, b) => b.lastUsedMs.compareTo(a.lastUsedMs));
    } catch (_) {
      return const [];
    }
  }

  Future<void> _save(List<DeviceAccount> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(accounts.map((account) => account.toJson()).toList()),
    );
  }

  /// Stores or updates the active non-guest session so it can be switched back to.
  Future<void> captureCurrent() async {
    final session = _client.auth.currentSession;
    final user = session?.user;
    if (session == null || user == null || user.isAnonymous) return;
    if (session.refreshToken == null || session.refreshToken!.isEmpty) return;

    String? username;
    String? playerName;
    String? imageUrl;
    try {
      final profile = await _profiles.getCurrentProfile();
      username = profile?.username;
      playerName = profile?.playerName;
      imageUrl = profile?.imageUrl;
    } catch (_) {}

    final accounts = await list();
    final next = DeviceAccount(
      userId: user.id,
      refreshToken: session.refreshToken!,
      accessToken: session.accessToken,
      username: username,
      playerName: playerName,
      imageUrl: imageUrl,
      lastUsedMs: DateTime.now().millisecondsSinceEpoch,
    );
    final without = accounts.where((account) => account.userId != user.id);
    await _save([next, ...without]);
  }

  Future<void> remove(String userId) async {
    if (userId.isEmpty) return;
    final accounts = await list();
    await _save(accounts.where((account) => account.userId != userId).toList());
  }

  /// Restores [account] as the active Supabase session.
  Future<void> switchTo(DeviceAccount account) async {
    await captureCurrent();
    try {
      final response = await _client.auth.setSession(account.refreshToken);
      if (response.session == null) {
        throw const AuthException('Could not switch to that account');
      }
    } catch (_) {
      await remove(account.userId);
      rethrow;
    }
    await captureCurrent();
  }

  /// Signs out the current account on this device and returns another stored
  /// account to restore, if any.
  Future<DeviceAccount?> signOutCurrent() async {
    final currentId = _client.auth.currentUser?.id;
    if (currentId != null) {
      await remove(currentId);
    }
    await _client.auth.signOut();
    final remaining = await list();
    return remaining.isEmpty ? null : remaining.first;
  }
}
