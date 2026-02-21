import 'package:supabase_flutter/supabase_flutter.dart';

/// Simple wrapper around the package Supabase client to avoid name clashes and
/// centralize initialization.
class AppSupabase {
  AppSupabase._();

  /// Initialize Supabase with your project credentials.
  ///
  /// Call this in `main.dart` before `runApp()`.
  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }

  /// Exposes the underlying Supabase client from the package.
  static SupabaseClient get client => Supabase.instance.client;
}
