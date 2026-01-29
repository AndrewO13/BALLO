import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase client singleton
class SupabaseClient {
  static SupabaseClient? _instance;
  static SupabaseClient get instance {
    _instance ??= SupabaseClient._();
    return _instance!;
  }

  SupabaseClient._();

  /// Initialize Supabase with your project credentials
  /// Call this in main.dart before runApp()
  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }

  /// Get the Supabase client instance
  SupabaseClient get client => Supabase.instance.client;
}
